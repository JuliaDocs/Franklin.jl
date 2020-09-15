"""Convenience function to add an id attribute to a html element."""
attr(name::Symbol, val::AS) = ifelse(isempty(val), "", " $name=\"$val\"")

"""Convenience function for a sup item."""
html_sup(id::String, in::AS) = "<sup id=\"$id\">$in</sup>"

"""Convenience function for a header."""
html_hk(hk::String, t::AS; id::String="", class::String="") =
    "<$hk$(attr(:id, id))>$t</$hk>"

"""Convenience function for content tagging (see `build_page`)"""
html_content(tag::String, content::AS; class::String, id::String) =
   "<$tag$(attr(:class, class))$(attr(:id, id))>$content</$tag>"

"""Convenience function to introduce a hyper reference."""
function html_ahref(link::AS, name::Union{Int,AS};
                    title::AS="", class::AS="")
    a  = "<a href=\"$(htmlesc(link))\""
    a *= attr(:title, title)
    a *= attr(:class, class)
    a *= ">$name</a>"
    return a
end

"""
    html_ahref_key

Convenience function to introduce a hyper reference relative to a key.
"""
html_ahref_key(k::AS, n::Union{Int,AS}) = html_ahref("#$k", n)

"""
    html_div

Convenience function to introduce a div block.
"""
html_div(name::AS, in::AS) = "<div class=\"$name\">$in</div>"

"""
    html_span

Convenience function to introduce a named span block.
"""
html_span(name::AS, in::AS) = "<span class=\"$name\">$in</span>"

"""
    html_img

Convenience function to introduce an image. The alt is escaped just in case the
user adds quotation marks in the alt string.
"""
html_img(src::AS, alt::AS="") = "<img src=\"$src\" alt=\"$(htmlesc(alt))\">"

"""
    html_code

Convenience function to introduce a code block. With indented blocks, the
language will be resolved at build time; as a result no lines will be hidden
for such blocks.
"""
function html_code(c::AS, lang::AS="")::String
    isempty(c) && return ""
    # if it's plaintext
    isempty(lang) && return "<pre><code class=\"plaintext\">$c</code></pre>"
    # escape it if it isn't already
    c = is_html_escaped(c) ? c : htmlesc(c)
    # remove hidden lines if any
    c = html_skip_hidden(c, lang)
    # if empty (e.g. via #hideall) return ""
    c == "" && return ""
    return "<pre><code class=\"language-$lang\">$c</code></pre>"
end


const REGEX_CODE_HIDE = Regex(raw"(?:^|[^\S\r\n]*?)#(\s)*?(?i)hide(all)?")
const REGEX_LIT_HIDE  = Regex(raw"(?:^|[^\S\r\n]*?)#src")

"""
    html_skip_hidden

Convenience function to process a code string and hide some lines.
"""
function html_skip_hidden(c::AS, lang::AS)::String
    # if the language is not one of CODE_LANG, just return
    # without hiding anything
    lang in keys(CODE_LANG) || return c
    # otherwise retrive the symbol marking a comment
    _, comsym = CODE_LANG[lang]
    # read code line by line and write to buffer
    buf = IOBuffer()
    for line in split(c, '\n')
        m  = match(REGEX_CODE_HIDE, line)
        ml = match(REGEX_LIT_HIDE, line)
        if m === ml === nothing
            println(buf, line)
        elseif m !== nothing
            # does it have a "all" or not?
            isnothing(m.captures[2]) && continue
            # if it doesn return an empty string
            return ""
        end
        # in other cases: skip the line
    end
    # strip as there may be a stray `\n`
    return strip(String(take!(buf)))
end


"""
    html_code_inline

Convenience function to introduce inline code.
"""
html_code_inline(c::AS) = "<code>$c</code>"


"""
    html_err

Insertion of a visible red message in HTML to show there was a problem.
"""
html_err(mess::String="") =
    "<p><span style=\"color:red;\">// $mess //</span></p>"


"""
    url_curpage

Helper function to get the relative url of the current page.
"""
function url_curpage()
    # get the relative path to current page and split extension (.md)
    fn = splitext(locvar(:fd_rpath))[1]
    # if it's not `index` then add `index`:
    if splitdir(fn)[2] != "index"
        fn = joinpath(fn, "index")
    end
    fn *= ".html"
    # unixify
    fn = unixify(fn)
    # if it does not start with "/", add a "/" in front
    startswith(fn, "/") || (fn = "/" * fn)
    # append .html and return
    return fn
end

"""
    get_url

Take a `rpath` and return the corresponding valid url
"""
function get_url(rpath)
    rpc, ext = splitext(rpath)
    if ext in (".md", ".html")
        url = rpc
    else
        url = rpath
    end
    if endswith(url, "index")
        url = url[1:length(url)-length("index")]
    end
    url = strip(url, '/')
    if isempty(url)
        url = "/"
    else
        url = "/$url/"
    end
    return url
end

# Copied from https://github.com/JuliaLang/julia/blob/acb7bd93fb2d5adbbabeaed9f39ab3c85495b02f/stdlib/Markdown/src/render/html.jl#L25-L31
const _htmlescape_chars = LittleDict(
            '<' => "&lt;",
            '>' => "&gt;",
            '"' => "&quot;",
            '&' => "&amp;"
            )
for ch in "'`!\$%()=+{}[]"
    _htmlescape_chars[ch] = "&#$(Int(ch));"
end

const _htmlesc_to = values(_htmlescape_chars) |> collect

"""
    is_html_escaped

Internal function to check if some html code has been escaped.
"""
is_html_escaped(cs::AS) =
    !isnothing(findfirst(ss -> occursin(ss, cs), _htmlesc_to))

"""
    html_unescape

Internal function to reverse the escaping of some html code (in order to avoid
double escaping when pre-rendering with highlight, see issue 326).
"""
function html_unescape(cs::AbstractString)
    # this is a bit inefficient but whatever, `cs` shouldn't  be very long.
    for (ssfrom, ssto) in _htmlescape_chars
        cs = replace(cs, ssto => ssfrom)
    end
    return cs
end


"""
    simplify_ps(s)

In some cases, an insertion might look like `<p>INS</p>` and the ps could be
dropped. This is a helper function to check that (1) there is only one opening
and closing `p` tag and (2) that they're at the beginning and end of the
string in which case they're removed.
"""
function simplify_ps(s::AbstractString)
    # 1. check whether the string starts and ends with the tag
    s = strip(s)
    left = startswith(s, "<p>")
    right = endswith(s, "</p>")
    (left && right) || return s
    from = nextind(s, 0, 4)
    to   = prevind(s, lastindex(s), 4)
    ss   = subs(s, from:to)
    k    = findfirst(r"<\/?p>", ss)
    isnothing(k) || return s
    return ss
end
