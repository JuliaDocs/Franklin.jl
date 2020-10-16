"""
$(SIGNATURES)

Convert a Franklin-Markdown file read as `mds` into a Franklin HTML string.
Returns the html string as well as a dictionary of page variables.

**Arguments**

* `mds`:         the markdown string to process
* `pre_lxdefs`:  a vector of `LxDef` that are already available.

**Keyword arguments**

* `isrecursive=false`: a bool indicating whether the call is the parent call or
                        a child call
* `isinternal=false`:  a bool indicating whether the call stems from `fd2html`
                        in internal mode
* `isconfig=false`:    a bool indicating whether the file to convert is the
                        configuration file
* `has_mddefs=true`:   a bool indicating whether to look for definitions of
                        page variables
"""
function convert_md(mds::AbstractString,
                    pre_lxdefs=collect(values(GLOBAL_LXDEFS));
                    isrecursive::Bool=false,
                    isinternal::Bool=false,
                    isconfig::Bool=false,
                    has_mddefs::Bool=true,
                    pagevar::Bool=false, # whether it's called from pagevar
                    nostripp::Bool=false
                    )::String
    # instantiate page dictionaries
    isrecursive || isinternal || set_page_env()
    # if we're given a substring, force it to a string
    mds = String(mds)

    #
    # Parsing of the markdown string
    # (to find latex command, latex definitions, math envs etc.)
    #

    # ------------------------------------------------------------------------
    #> 1. Tokenize
    tokens = find_tokens(mds, MD_TOKENS, MD_1C_TOKENS)
    (:convert_md, "convert_md: '$([t.name for t in tokens])'") |> logger

    # validate toml open/close
    validate_start_of_line!(tokens, (:MD_DEF_TOML, MD_HEADER_OPEN...))
    # distinguish fnref/fndef
    validate_footnotes!(tokens)
    # validate emojis
    validate_emojis!(tokens)
    # capture some hrule (see issue #432)
    hrules = find_hrules!(tokens)

    #> 1b. Find indented blocks (ONLY if not recursive to avoid ambiguities!)
    if !isrecursive
        find_indented_blocks!(tokens, mds)
        if has_mddefs
            # look for multi-line definitions, for those that meet the
            # requirements, discard *all* tokens in the span leaving only
            # the opening and closing one. Note: expressions will be parsed
            # twice as a result but really it's negligible time.
            preprocess_candidate_mddefs!(tokens)
        end
        # any remaining indented lines that don't meet the requirements for
        # an indented code block get removed here
        filter_lr_indent!(tokens, mds)
    end

    # ------------------------------------------------------------------------
    #> 2. Open-Close blocks (OCBlocks)
    #>> a. find them
    blocks, tokens  = find_all_ocblocks(tokens, MD_OCB)
    toks_pre_ocb    = deepcopy(tokens) # see find_double_brace_blocks
    #>> a'. find LXB, DIV and Maths
    blocks2, tokens = find_all_ocblocks(tokens, vcat(MD_OCB2, MD_OCB_MATH))
    #>> a''. find LX_BEGIN/END tokens
    find_lxenv_delims!(tokens, blocks2)
    # aggregate blocks
    append!(blocks, blocks2)
    ranges = deactivate_inner_blocks!(blocks)
    #>> b. merge CODE_BLOCK_IND which are separated by emptyness
    merge_indented_blocks!(blocks, mds)
    #>> b'. only keep indented code blocks which are not contained in larger
    # blocks (#285)
    filter_indented_blocks!(blocks)
    #>> c. now that blocks have been found, line-returns can be dropped
    filter!(τ -> τ.name ∉ L_RETURNS, tokens)
    #>> e. keep track of literal content of possible link definitions to use
    validate_and_store_link_defs!(blocks)

    if globvar("autocode") && any(b -> b.name in CODE_BLOCKS_NAMES, blocks)
        set_var!(LOCAL_VARS, "hascode", true)
    end
    if globvar("automath") && any(b -> b.name in MATH_BLOCKS_NAMES, blocks)
        set_var!(LOCAL_VARS, "hasmath", true)
    end

    # ------------------------------------------------------------------------
    #> 3. LaTeX commands
    #>> a. find "newcommands", update active blocks/braces
    lxdefs, tokens, braces, blocks = find_lxdefs(tokens, blocks)

    #>> b. if any lxdefs are given in the context, merge them. `pastdef` specifies
    # that the definitions appeared "earlier"
    lprelx = length(pre_lxdefs)
    (lprelx > 0) && (lxdefs = cat(pastdef.(pre_lxdefs), lxdefs, dims=1))
    #>> c. find latex environments
    lxenvs, tokens = find_lxenvs(tokens, lxdefs, braces)
    #>> d. find latex commands
    lxcoms, _ = find_lxcoms(tokens, lxdefs, braces)

    #> 3[ex]. find double brace blocks, note we do it on pre_ocb tokens
    # as the step `find_all_ocblocks` possibly found and deactivated {...}.
    dbb = find_double_brace_blocks(toks_pre_ocb)
    deactivate_inner_dbb!(dbb, ranges)

    # ------------------------------------------------------------------------
    #> 4. Page variable definition (mddefs), also if in config, update lxdefs
    if has_mddefs
        process_mddefs(blocks, isconfig, pagevar)
    end

    #> 4.b if config, update global lxdefs as well
    if isconfig
        for lxd ∈ lxdefs
            GLOBAL_LXDEFS[lxd.name] = pastdef(lxd)
        end
        # if it's the config file we don't need to go further
        return ""
    end

    # ------------------------------------------------------------------------
    #> 5. Process special characters, emojis and html entities so that they
    # can be injected as they are in the HTML later
    sp_chars = find_special_chars(tokens)

    # ========================================================================
    #
    # Forming of the html string
    #
    # filter out the fnrefs that are left (still active)
    # and add them to the blocks to insert
    fnrefs = filter(τ -> τ.name == :FOOTNOTE_REF, tokens)

    # Discard indented blocks unless locvar(:indented_code)
    if !locvar(:indented_code)
        filter!(b -> b.name != :CODE_BLOCK_IND, blocks)
    end

    #> 1. Merge all the blocks that will need further processing before
    # insertion
    b2insert = merge_blocks(lxenvs, lxcoms,
                            deactivate_divs(vcat(blocks, dbb)),
                            sp_chars, fnrefs, hrules)

    #> 2. Form intermediate markdown + html
    inter_md, mblocks = form_inter_md(mds, b2insert, lxdefs)
    inter_html = md2html(inter_md; stripp=isrecursive && !nostripp)

    (:convert_md, "inter_md: '$inter_md'")     |> logger
    (:convert_md, "inter_html: '$inter_html'") |> logger

    #> 3. Plug resolved blocks in partial html to form the final html
    hstring = convert_inter_html(inter_html, mblocks, lxdefs)

    (:convert_md, "hstring: '$hstring'") |> logger

    # final var adjustment, infer title if not given
    if isnothing(locvar(:title)) && !isempty(PAGE_HEADERS)
        title = first(values(PAGE_HEADERS))[1]
        set_var!(LOCAL_VARS, "title", title)
        ALL_PAGE_VARS[splitext(locvar(:fd_rpath))[1]]["title"] =
            deepcopy(LOCAL_VARS["title"])
    end

    # Return the string
    return hstring
end


"""
$(SIGNATURES)

Same as `convert_md` except tailored for conversion of the inside of a math
block (no command definitions, restricted tokenisation to latex tokens). The
offset keeps track of where the math block was, which is useful to check
whether any of the latex command used in the block have not yet been defined.

**Arguments**

* `ms`:     the string to convert
* `lxdefs`: existing latex definitions prior to the math block
* `offset`: where the mathblock is with respect to the parent string
"""
function convert_md_math(ms::AS, lxdefs::Vector{LxDef}=Vector{LxDef}(),
                         offset::Int=0)::String
    # if a substring is given, copy it as string
    ms = String(ms)
    #
    # Parsing of the markdown string
    # (to find latex command, latex definitions, math envs etc.)
    #

    #> 1. Tokenize (with restricted set)
    tokens = find_tokens(ms, MD_TOKENS_LX, MD_1C_TOKENS_LX)

    #> 2. Find braces and drop line returns thereafter
    blocks, tokens = find_all_ocblocks(tokens, MD_OCB_ALL, inmath=true)
    braces = filter(β -> β.name == :LXB, blocks)

    #> 3. Find latex envs and commands (indicate we're in a math environment + offset)
    lxenvs, tokens = find_lxenvs(tokens, lxdefs, braces, offset; inmath=true)
    lxcoms, _      = find_lxcoms(tokens, lxdefs,  braces, offset; inmath=true)

    #
    # Forming of the html string
    # (see `form_inter_md`, it's similar but simplified since there are fewer
    # conditions)
    #
    htmls = IOBuffer()

    strlen   = lastindex(ms)
    len_lxc  = length(lxcoms)
    next_lxc = iszero(len_lxc) ? BIG_INT : from(lxcoms[1])

    # counters to keep track of where we are and which command we're looking at
    head, lxc_idx = 1, 1
    while (next_lxc < BIG_INT) && (head < strlen)
        # add anything that may occur before the first command
        (head < next_lxc) && write(htmls, subs(ms, head, prevind(ms, next_lxc)))
        # add the first command after resolving, bool to indicate that we're in
        # a math env
        write(htmls, resolve_lxobj(lxcoms[lxc_idx], lxdefs, inmath=true))
        # move the head to after the lxcom and increment the com counter
        head     = nextind(ms, to(lxcoms[lxc_idx]))
        lxc_idx += 1
        next_lxc = from_ifsmaller(lxcoms, lxc_idx, len_lxc)
    end
    # add anything after the last command
    (head <= strlen) && write(htmls, subs(ms, head, strlen))
    return String(take!(htmls))
end


"""
INSERT

String that is plugged as a placeholder of blocks that need further processing.
Note: left space in the pattern is to preserve lists.
"""
const INSERT     = " ##FDINSERT##"
const INSERT_PAT = Regex("((?<!<li>)<p>)?(\\s*)$(strip(INSERT))(</p>)?")


"""
CLOSE_INSERT

String that is plugged as a placeholder of blocks that need further processing in a place
where any open paragraph must be closed first. For instance this will be the replacement
for a header.
"""
const CLOSEP_INSERT = "\n\n##FDINSERT##\n\n"


"""
$SIGNATURES

Form an intermediate MD file where special blocks are replaced by a marker
(`INSERT`) indicating that a piece will need to be plugged in there later.

**Arguments**

* `mds`:    the (sub)string to convert
* `blocks`: vector of blocks
* `lxdefs`: existing latex definitions prior to the math block
"""
function form_inter_md(mds::AS, blocks::Vector{<:AbstractBlock},
                       lxdefs::Vector{LxDef}
                       )::Tuple{String, Vector{AbstractBlock}}
    strlen  = lastindex(mds)
    intermd = IOBuffer()
    # keep track of the matching blocks for each insert
    mblocks = Vector{AbstractBlock}()

    len_b   = length(blocks)
    len_lxd = length(lxdefs)

    # check when the next block is
    next_b = iszero(len_b) ? BIG_INT : from(blocks[1])

    # check when the next lxblock is, extra work because there may be lxdefs
    # passed through in *context* (i.e. that do not appear in mds) therefore
    # search first lxdef actually in mds (nothing if lxdefs is empty)
    first_lxd = findfirst(δ -> (from(δ) > 0), lxdefs)
    next_lxd  = isnothing(first_lxd) ? BIG_INT : from(lxdefs[first_lxd])

    # check what's next: a block or a lxdef
    b_or_lxd = (next_b < next_lxd)
    nxtidx = min(next_b, next_lxd)

    # keep track of a few counters (where we are, which block, which command)
    head, b_idx, lxd_idx = 1, 1, first_lxd

    while (nxtidx < BIG_INT) & (head < strlen)
        # check if there's anything before head and next block and write it
        (head < nxtidx) && write(intermd, subs(mds, head, prevind(mds, nxtidx)))
        # check whether it's a block first or a newcommand first
        if b_or_lxd # it's a block, check if should be written
            β = blocks[b_idx]
            # check whether the block should be skipped
            if isa(β, OCBlock) && β.name ∈ MD_OCB_IGNORE
                head = nextind(mds, to(β))
            else
                if isa(β, OCBlock) && β.name ∈ MD_CLOSEP
                    write(intermd, CLOSEP_INSERT)
                else
                    write(intermd, INSERT)
                end
                push!(mblocks, β)
                head = nextind(mds, to(blocks[b_idx]))
            end
            b_idx += 1
            next_b = from_ifsmaller(blocks, b_idx, len_b)
        else
            # newcommand or ignore --> skip, increase counters, move head
            head     = nextind(mds, to(lxdefs[lxd_idx]))
            lxd_idx += 1
            next_lxd = from_ifsmaller(lxdefs, lxd_idx, len_lxd)
        end
        # check which block is next
        b_or_lxd = (next_b < next_lxd)
        nxtidx = min(next_b, next_lxd)
    end
    # add whatever is after the last block
    (head <= strlen) && write(intermd, subs(mds, head, strlen))

    # combine everything and return
    return String(take!(intermd)), mblocks
end


"""
$(SIGNATURES)

Take a partial markdown string with the `INSERT` markers and
plug in the appropriately processed block.

**Arguments**

* `ihtml`:  the intermediary html string (with `INSERT` markers)
* `blocks`: vector of blocks
* `lxdefs`: latex context
"""
function convert_inter_html(ihtml::AS,
                            blocks::Vector{<:AbstractBlock},
                            lxdefs::Vector{LxDef})::String

    (:convert_inter_html, "ihtml: '$ihtml'") |> logger

    # Find the INSERT indicators
    allmatches = collect(eachmatch(INSERT_PAT, ihtml))
    isempty(allmatches) && return ihtml

    strlen = lastindex(ihtml)
    # write the pieces of the final html in order, gradually processing the
    # blocks to insert
    htmls = IOBuffer()
    head  = 1
    for (i, m) ∈ enumerate(allmatches)
        # check whether there's <p> or </p> around the insert
        leftp  = !isnothing(m.captures[1])
        lefts  = ifelse(length(m.captures[2])>1, " ", "")
        rightp = !isnothing(m.captures[3])
        prev   = prevind(ihtml, m.offset)
        write(htmls, subs(ihtml, head:prev))
        if leftp && !rightp
            write(htmls, "<p>")
        end
        write(htmls, lefts)
        resolved = convert_block(blocks[i], lxdefs)
        write(htmls, resolved)
        if rightp && !leftp
            write(htmls, "</p>")
        end
        head = nextind(ihtml, m.offset, length(m.match))
    end
    # store whatever is after the last INSERT if anything
    (head ≤ strlen) && write(htmls, subs(ihtml, head:strlen))
    # return the full string
    return String(take!(htmls))
end
