"""
$(SIGNATURES)

Helper function to process an individual block when it's a `HFun` such as
`{{ fill author }}`. See also [`convert_html`](@ref).
"""
function convert_html_fblock(β::HFun)::String
    fun = Symbol("hfun_" * lowercase(β.fname))
    ex  = isempty(β.params) ? :($fun()) : :($fun($β.params))
    # see if a hfun was defined in utils
    if isdefined(Main, :Utils) && isdefined(Main.Utils, fun)
        # skip eval if the page is delayed
        FD_ENV[:SOURCE] in DELAYED && return ""
        res = Core.eval(Main.Utils, ex)
        return string(res)
    end
    # see if a hfun was defined internally
    isdefined(Franklin, fun) && return eval(ex)
    # if zero parameters, see if can fill (case: {{vname}})
    if isempty(β.params) &&
        (!isnothing(locvar(β.fname)) || β.fname in UTILS_NAMES)
        return hfun_fill([β.fname])
    end
    # if we get here, then the function name is unknown, warn and ignore
    print_warning("""
        A block '{{$(β.fname) ...}}' was found but the name '$(β.fname)' does
        not correspond to a built-in block or hfun nor does it match anything
        defined in 'utils.jl'. It might have been misspelled.
        \nRelevant pointers:
        $POINTER_PV
        $POINTER_HFUN
        """)
    # returning empty
    return ""
end


"""
$(SIGNATURES)

H-Function of the form `{{ fill vname }}` or `{{ fill vname rpath}}` to plug in
the content of a franklin-var `vname` (assuming it can be represented as a
string).
"""
function hfun_fill(params::Vector{String})::String
    # check params
    if length(params) > 2 || isempty(params)
        throw(HTMLFunctionError("{{fill ...}} should have one or two " *
                                "($(length(params)) given). Verify."))
    end
    # form the fill
    repl  = ""
    vname = params[1]
    if length(params) == 1
        if vname in UTILS_NAMES
            repl = string(getfield(Main.Utils, Symbol(vname)))
        else
            tmp_repl = locvar(vname)
            if isnothing(tmp_repl)
                hfun_unknown_arg1_warn(:fill, vname)
            else
                repl = string(tmp_repl)
            end
        end
    else # two parameters, look in a path
        rpath = params[2]
        tmp_repl = pagevar(rpath, vname)
        if isnothing(tmp_repl)
            hfun_misc_warn(:fill, """
                The arguments '$vname' and '$rpath' cannot be resolved. It may
                be that the path doesn't exist or that the variable '$vname'
                is not defined on the page at that path.
                \nRelevant pointers:
                $POINTER_PV
                """)
        else
            repl = string(tmp_repl)
        end
    end
    return repl
end


"""
$(SIGNATURES)

H-Function of the form `{{ insert fpath }}` to plug in the content of a file at
`fpath`. Note that the base path is assumed to be `PATHS[:layout]` and so paths
have to be expressed relative to that.
"""
function hfun_insert(params::Vector{String})::String
    # check params
    if length(params) != 1
        throw(HTMLFunctionError("I found a {{insert ...}} with more than one parameter. Verify."))
    end
    # apply
    repl   = ""
    layout = path(:layout)
    fpath  = joinpath(layout, split(params[1], "/")...)
    if isfile(fpath)
        repl = convert_html(read(fpath, String))
    else
        hfun_misc_warn(:insert, """
            Couldn't find the file '$fpath' to resolve the insertion.
            """)
    end
    return repl
end


"""
$(SIGNATURES)

H-Function of the form `{{href ... }}`.
"""
function hfun_href(params::Vector{String})::String
    # check params
    if length(params) != 2
        throw(HTMLFunctionError("I found an {{href ...}} block and expected 2 parameters" *
                                "but got $(length(params)). Verify."))
    end
    # apply
    repl = "<b>??</b>"
    dname, hkey = params[1], params[2]
    if params[1] == "EQR"
        haskey(PAGE_EQREFS, hkey) || return repl
        repl = html_ahref_key(hkey, PAGE_EQREFS[hkey])
    elseif params[1] == "BIBR"
        haskey(PAGE_BIBREFS, hkey) || return repl
        repl = html_ahref_key(hkey, PAGE_BIBREFS[hkey])
    else
        hfun_misc_warn(:href, """
            Unknown reference dictionary '$dname'.
            """)
    end
    return repl
end


"""
$(SIGNATURES)

H-Function of the form `{{toc min max}}` (table of contents). Where `min` and
`max` control the minimum level and maximum level of  the table of content.
The split is as follows:

* key is the refstring
* f[1] is the title (header text)
* f[2] is irrelevant (occurence, used for numbering)
* f[3] is the level
"""
function hfun_toc(params::Vector{String})::String
    if length(params) != 2
        throw(HTMLFunctionError("I found a {{toc ...}} block and expected 2 " *
                              "parameters but got $(length(params)). Verify."))
    end
    isempty(PAGE_HEADERS) && return ""

    # try to parse min-max level
    min = 0
    max = 100
    try
        min = parse(Int, params[1])
        max = parse(Int, params[2])
    catch
        throw(HTMLFunctionError("I found a {{toc min max}} but couldn't " *
                                "parse min/max. Verify."))
    end

    inner   = ""
    headers = filter(p -> min ≤ p.second[3] ≤ max, PAGE_HEADERS)
    isempty(headers) && return ""
    baselvl = minimum(h[3] for h in values(headers)) - 1
    curlvl  = baselvl
    for (rs, h) ∈ headers
        lvl = h[3]
        if lvl ≤ curlvl
            # Close previous list item
            inner *= "</li>"
            # Close additional sublists for each level eliminated
            for i = curlvl-1:-1:lvl
                inner *= "</ol></li>"
            end
            # Reopen for this list item
            inner *= "<li>"
        elseif lvl > curlvl
            # Open additional sublists for each level added
            for i = curlvl+1:lvl
                inner *= "<ol><li>"
            end
        end
        inner *= html_ahref_key(rs, h[1])
        curlvl = lvl
        # At this point, number of sublists (<ol><li>) open equals curlvl
    end
    # Close remaining lists, as if going down to the base level
    for i = curlvl-1:-1:baselvl
        inner *= "</li></ol>"
    end
    toc = "<div class=\"franklin-toc\">" * inner * "</div>"
end


"""
$(SIGNATURES)

H-Function of the form `{{taglist}}`.
"""
function hfun_taglist()::String
    tag = locvar(:fd_tag)

    c = IOBuffer()
    write(c, "<ul>")

    rpaths = globvar("fd_tag_pages")[tag]
    sorter(p) = begin
        pvd = pagevar(p, "date")
        if isnothing(pvd)
            return Date(Dates.unix2datetime(stat(p * ".md").ctime))
        end
        return pvd
    end
    sort!(rpaths, by=sorter, rev=true)

    (:hfun_list, "tag: $tag, loop over $rpaths") |> logger

    for rpath in rpaths
        title = pagevar(rpath, "title")
        if isnothing(title)
            title = "/$rpath/"
        end
        url = get_url(rpath)
        write(c, "<li><a href=\"$url\">$title</a></li>")
    end
    write(c, "</ul>")
    return String(take!(c))
end


"""
$(SIGNATURES)

H-Function of the form `{{redirect /addr/blah.html}}`.
"""
function hfun_redirect(params::Vector{String})::String
    if length(params) != 1
        throw(HTMLFunctionError(
                "I found an {{redirect ...}} block and expected a single " *
                "address but got $(length(params)). Verify."))
    end
    addr = params[1]
    if !endswith(addr, ".html")
        throw(HTMLFunctionError("In a {{redirect address}} block the address must be " *
                                "complete up to the `.html` extension (got '$addr')."))
    end
    startswith(addr, '/') && (addr = addr[nextind(addr, 1):end])
    dst = joinpath(path(:site), addr)
    isfile(dst) && return ""
    mkpath(splitdir(dst)[1])
    write(dst, """
    <!-- Generated Redirect -->
    <!doctype html>
    <html>
    <head>
      <meta http-equiv="refresh" content="0; url=$(locvar(:fd_url))">
    </head>
    </html>
    """)
    return ""
end


const PAGINATE = "%##PAGINATE##%"


"""
    hfun_paginate

Called with `{{paginate iterable n_per_page}}`. It is assumed there is only
one such call per page.
Evaluation is actually delayed.
"""
function hfun_paginate(params::Vector{String})::String
    # params[1] --> the iterable to paginate (locvar)
    # params[2] --> a positive integer of items per page

    # Check arguments
    if length(params) != 2
        throw(HTMLFunctionError(
                "I found an {{paginate ...}} block and expected two args: " *
                "the name of the iterable and the number of item per page. " *
                "I see $(length(params)) arguments instead. Verify."))
    end
    iter = locvar(params[1])
    if isnothing(iter)
        hfun_misc_warn(:paginate, """
            The page variable '$(params[1])' does not match the name of a page
            variable. The call will be ignored.
            """)
        return ""
    end
    npp = locvar(params[2])
    if isnothing(npp)
        try
            npp = parse(Int, params[2])
        catch
            hfun_misc_warn(:paginate, """
                Failed to parse the number of items per page (given: '$(params[2])'). Setting to 10.
                """)
            npp = 10
        end
    end
    if npp <= 0
        hfun_misc_warn(:paginate, """
            Non-positive number of items per page ('$npp' read from $(params[2])). Setting to 10.
            """)
        npp = 10
    end

    # Was there already a pagination element on this page?
    # if so warn and ignore
    if !isnothing(locvar(:paginate_itr))
        hfun_misc_warn(:paginate, """
            Multiple calls to '{{paginate ...}}' on the page but at most one is
            expected.
            """)
        return ""
    end
    # we're just storing the name here, so we'll have to locvar(locvar(.))
    set_var!(LOCAL_VARS, "paginate_itr", params[1])
    set_var!(LOCAL_VARS, "paginate_npp", npp)

    # return a token which will be processed at the convert_and_write stage.
    return PAGINATE
end
