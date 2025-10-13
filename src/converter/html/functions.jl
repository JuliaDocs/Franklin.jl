"""
$(SIGNATURES)

Helper function to process an individual block when it's a `HFun` such as
`{{ fill author }}`. See also [`convert_html`](@ref).
"""
function convert_html_fblock(β::HFun)::String
    fun = Symbol("hfun_" * lowercase(β.fname))
    ex  = isempty(β.params) ? :($fun()) : :($fun($β.params))
    # see if a hfun was defined in utils
    if @invokelatest(isdefined(Main, utils_symb())) && @invokelatest(isdefined(utils_module(), fun))
        # skip eval if the page is delayed
        isdelayed() && return ""
        res = Core.eval(utils_module(), ex)
        return string(res)
    end
    # see if a hfun was defined internally
    @invokelatest(isdefined(Franklin, fun)) && return eval(ex)
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
            repl = string(@invokelatest(getglobal(utils_module(), Symbol(vname))))
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

    levels = [h[3] for (rs,h) ∈ headers]
    baselvl = minimum(h[3] for h in values(headers))
    curlvl  = baselvl

    new_levels = [1] # first level should be left-most aligned (i.e., start at 1)
    curlvl = 1
    for i in 2:length(levels)
        if levels[i-1] < levels[i]
            curlvl += 1
        else
            curlvl = levels[i] == baselvl ? 1 : 2
        end
        push!(new_levels, curlvl)
    end
    open_lists = 0
    curskip = 0

    for (li, (rs, h)) ∈ enumerate(headers)
        lvl = h[3]
        skip = new_levels[li]
        if skip ≤ curskip
            # Close previous list item
            inner *= "</li>"
            # Close additional sublists for each level eliminated
            for i = fill(nothing, curskip - skip)
                inner *= "</ol></li>"
                open_lists -= 1
            end
            # Reopen for this list item
            inner *= "<li>"
        else
            # Open additional sublists for each level added
            for i = fill(nothing, skip - curskip)
                inner *= "<ol><li>"
                open_lists += 1
            end
        end
        inner *= html_ahref_key(rs, h[1])
        curlvl = lvl
        curskip = skip
        # At this point, number of sublists (<ol><li>) open equals curlvl
    end
    # Close remaining lists, as if going down to the base level
    for i = fill(nothing, open_lists)
        inner *= "</li></ol>"
    end
    toc = "<div class=\"franklin-toc\">" * inner * "</div>"
end

"""
$(SIGNATURES)

H-Function of the form `{{taglist}}`.
"""
function hfun_taglist()::String
    tag = locvar(:fd_tag)::String

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

H-Function of the form `{{redirect /addr/blah.html}}` or `{{redirect /addr/blah/}}`
if the last part ends with `/` then `index.html` is appended. Note that the first
`/` can be omitted.
"""
function hfun_redirect(params::Vector{String})::String
    # don't put those on the sitemap
    set_var!(LOCAL_VARS, "sitemap_exclude", true)
    if length(params) != 1
        throw(HTMLFunctionError(
                "I found an {{redirect ...}} block and expected a single " *
                "address but got $(length(params)). Verify."))
    end
    addr = params[1]
    addr *= ifelse(addr[end] == '/', "index.html", "")
    if !endswith(addr, ".html")
        throw(HTMLFunctionError("In a {{redirect address}} block the address must be " *
                                "complete up to the `.html` extension (got '$addr')."))
    end
    startswith(addr, '/') && (addr = addr[nextind(addr, 1):end])
    dst = joinpath(path(:site), addr)
    isfile(dst) && return ""
    mkpath(splitdir(dst)[1])
    pp = globvar(:prepath)::String
    pp = ifelse(isempty(pp), pp, "/$pp")
    pp = ifelse(FD_ENV[:FINAL_PASS]::Bool, pp, "")
    write(dst, """
    <!-- Generated Redirect -->
    <!doctype html>
    <html>
    <head>
      <meta http-equiv="refresh" content='0; url="$(pp)$(locvar(:fd_url)::String)"'>
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
    if !isnothing(locvar(:paginate_itr)::Union{String,Nothing})
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


"""
    hfun_sitemap_opts

Called with `{{sitemap_opts monthly 0.5}}`. It is assumed this is called only
on raw html pages (e.g. custom landing page).

## Example usage

* `{{sitemap_opts exclude}}`
* `{{sitemap_opts monthly 0.5}}`
"""
function hfun_sitemap_opts(params::Vector{String})::String
    # Check arguments
    if length(params) == 1 && lowercase(params[1]) != "exclude"
        throw(HTMLFunctionError(
                "I found an {{sitemap_opts xxx}} block with 1 arg and " *
                "that is only allowed if the arg is 'exclude'. Verify."))
    elseif length(params) != 2
        throw(HTMLFunctionError(
                "I found an {{sitemap_opts ...}} block and expected 2 args: " *
                "the changefreq and the priority. " *
                "I see $(length(params)) arguments instead. Verify."))
    end
    key = url_curpage()
    if params[1] == "exclude"
        delete!(SITEMAP_DICT, key)
        return ""
    end
    changefreq = params[1]
    priority = params[2]
    fp = joinpath(path(:folder), locvar(:fd_rpath)::String)
    lastmod = Date(unix2datetime(stat(fp).mtime))
    SITEMAP_DICT[key] = SMOpts(lastmod, changefreq, priority)
    return ""
end


"""
    hfun_fd2rss

Take a fd-markdown string, convert it to HTML and fix relative links.
"""
function hfun_fd2rss(params::Vector{String})::String
    src = locvar(params[1])::String
    src_html = fd2html(src; internal=true, nop=true)
    return _fix_relative_links(src_html)
end


"""
    hfun_fix_relative_links

Makes relative links into full links, typically in the context of RSS.
"""
function hfun_fix_relative_links(params::Vector{String})::String
    src = locvar(params[1])::String
    return _fix_relative_links(src)
end

function _fix_relative_links(src::String)
    base_link = globvar(:website_url)::String
    isempty(strip(base_link, '/')) && return src
    endswith(base_link, '/') || (base_link *= '/')
    return replace(src, PREPATH_FIX_PAT => SubstitutionString("\\1=\\2$base_link"))
end


"""
    hfun_RFC822

Print a date with the format 822/1123 (RSS).
"""
function hfun_rfc822(params::Vector{String})
    dt = DateTime(locvar(params[1])::Date)
    return Dates.format(dt, Dates.RFC1123Format) * " +0000"
end
