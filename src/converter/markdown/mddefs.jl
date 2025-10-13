"""
$(SIGNATURES)

Convenience function to process markdown definitions `@def ...` as appropriate.
Depending on `isconfig`, will update `GLOBAL_VARS` or `LOCAL_VARS`.

**Arguments**

* `blocks`:    vector of active docs
* `isconfig`:  whether the file being processed is the config file
                (--> global page variables)
* `isinternal`: whether the call is internal (e.g. within hfun). In that case skip tags.
"""
function process_mddefs(blocks::Vector{OCBlock}, isconfig::Bool,
                        pagevar::Bool=false, isinternal::Bool=false)::Nothing

    (:process_mddefs, "config: $isconfig, pagevar: $pagevar") |> logger

    # Blocks of definitions just get evaluated in an anonymous Module
    curdict = ifelse(isconfig, GLOBAL_VARS, LOCAL_VARS)
    for mdb in filter(β -> (β.name == :MD_DEF_BLOCK), blocks)
        inner = stent(mdb)
        exs = parse_code(inner)
        mdl = newmodule("MD_DEFINITIONS")
        try
            foreach(ex -> Core.eval(mdl, ex), exs)
        catch
            error("Encountered an error on $(locvar(:fd_rpath)) while trying to " *
                  "evaluate a block of definitions (`+++...+++`).")
        end
        # get the variable names (from all assignments)
        vnames = [ex.args[1] for ex in exs if ex.head == :(=)]
        filter!(v -> v isa Symbol, vnames)
        for vname in vnames
            key    = String(vname)
            value  = @invokelatest getglobal(mdl, vname)
            set_var!(curdict, key, value; isglobal=isconfig)
        end
    end

    # Find all markdown definitions (MD_DEF) blocks
    mddefs = filter(β -> (β.name == :MD_DEF), blocks)
    # empty container for the assignments
    assignments = Vector{Pair{String, String}}()
    # go over the blocks, and extract the assignment
    for (i, mdd) ∈ enumerate(mddefs)
        inner = stent(mdd)
        m = match(ASSIGN_PAT, inner)
        if isnothing(m)
            print_warning("""
                Delimiters for an '@def ...' environment were found but at
                least one assignment does not have the proper syntax. That
                assignment will be ignored.
                \nRelevant pointers:
                $POINTER_PV
                """)
            continue
        end
        vname, vdef = m.captures[1:2]
        push!(assignments, (String(vname) => String(vdef)))
    end

    # if in config file, update `GLOBAL_VARS` and return
    rpath = splitext(locvar(:fd_rpath)::String)[1]
    if isconfig
        set_vars!(GLOBAL_VARS, assignments, isglobal=true)
        return nothing
    end

    # otherwise set local vars
    set_vars!(LOCAL_VARS, assignments)
    rpath = splitext(locvar(:fd_rpath)::String)[1]

    hasmath = locvar(:hasmath)::Bool
    hascode = locvar(:hascode)::Bool
    if !hascode && globvar("autocode")::Bool
        # check and set hascode automatically
        code = any(b -> startswith(string(b.name), "CODE_BLOCK"), blocks)
        set_var!(LOCAL_VARS, "hascode", code)
    end
    if !hasmath && globvar("automath")::Bool
        # check and set hasmath automatically
        math = any(b -> b.name in MATH_BLOCKS_NAMES, blocks)
        set_var!(LOCAL_VARS, "hasmath", math)
    end

    (:process_mddefs, "assignments done") |> logger

    isinternal && return nothing

    # TAGS
    tags = Set(refstring.(locvar(:tags)::Vector{String}))
    # Cases:
    # 0. there was no page tags before
    #   a. tags is empty --> do nothing
    #   b. tags is not empty --> initialise global page tags + add rpath=>tags
    # 1. that page did not have tags
    #   a. tags is empty --> do nothing
    #   b. tags is not empty register them and update all
    # 2. that page did have tags
    #   a. tags are unchanged --> do nothing
    #   b. check which ones change and update those
    PAGE_TAGS = globvar("fd_page_tags")
    if isnothing(PAGE_TAGS)
        isempty(tags) && return nothing
        set_var!(GLOBAL_VARS, "fd_page_tags", DTAG((rpath => tags,)); check=false)
    elseif !haskey(PAGE_TAGS, rpath)
        isempty(tags) && return nothing
        PAGE_TAGS[rpath] = tags
    else
        old_tags = PAGE_TAGS[rpath]
        if isempty(tags)
            delete!(PAGE_TAGS, rpath)
        else
            PAGE_TAGS[rpath] = tags
        end
        # we will need to update all tag pages that were or are related to
        # the current rpath, indeed properties of the page may have changed
        # and affect these derived pages (that's why it's a union here
        # and not a setdiff).
        tags = union(old_tags, tags)
    end
    # In the full pass each page is processed first (without generating tag
    # pages) and then, when all tags have been gathered, generate_tag_pages
    # is called (see `fd_fullpass`).
    # During the serve loop, we want to trigger on page change.
    pagevar || FD_ENV[:FULL_PASS] || generate_tag_pages(tags)
    return nothing
end
