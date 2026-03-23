# <?xml version="1.0" encoding="utf-8" standalone="yes" ?>
# <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
# <url>
#      <loc>http://www.example.com/</loc>
#      ?<lastmod>2005-01-01</lastmod>
#      ?<changefreq>monthly</changefreq>
#      ?<priority>0.8</priority>
# </url>
# </urlset>
#

struct SMOpts
    lastmod::Date        # 2005-01-01 -- format YYYY-MM-DD
    changefreq::String   # one of...
    priority::Float64    #
    function SMOpts(l, c, p)
        if l == Date(1)
            l = Date(now())
        end
        c = lowercase(c)
        p = isa(p, String) ? parse(Float64, p) : float(p)
        allowedf = ("always", "hourly", "daily", "weekly", "monthly",
        "yearly", "never")
        assertf = """
        Given change frequency on $(FD_ENV[:SOURCE]) is invalid according to
        sitemap specifications, expected one of $allowedf.
        """
        assertp = """
        Given priority on $(FD_ENV[:SOURCE]) is invalid according to sitemap
        specifications, expected a floating point number between 0 and 1.
        """
        @assert c in allowedf assertf
        @assert 0 <= p <= 1 assertp
        return new(l, c, p)
    end
end

const SITEMAP_DICT = LittleDict{String,SMOpts}()

"""
    default_sitemap_priority(loc::String)::Float64

Compute a default sitemap priority based on URL depth.
Root pages get 1.0, one level deep gets 0.8, deeper pages get 0.5.
Can be overridden per-page via `sitemap_priority` frontmatter.
"""
function default_sitemap_priority(loc::String)::Float64
    stripped = replace(loc, r"index\.html$" => "")
    stripped = strip(stripped, '/')
    isempty(stripped) && return 1.0
    depth = count('/', stripped)
    depth == 0 && return 0.8
    return 0.5
end

"""
$SIGNATURES

Add an entry to `SITEMAP_DICT`.
"""
function add_sitemap_item(; html=false)
    loc = url_curpage()
    endswith(loc, "404.html") && return nothing
    locvar(:sitemap_exclude)::Bool && return nothing
    if !html
        lastmod = locvar(:fd_mtime_raw)
        changefreq = locvar(:sitemap_changefreq)
        priority = locvar(:sitemap_priority)
    else
        # use default which can be overwritten in a {{sitemap_opts ...}}
        fp = joinpath(path(:folder), locvar(:fd_rpath)::String)
        lastmod = Date(unix2datetime(stat(fp).mtime))
        changefreq = "monthly"
        # Depth-based priority for non-markdown pages where priority
        # was previously hardcoded to 0.5. Markdown pages use the
        # sitemap_priority frontmatter variable directly.
        priority = default_sitemap_priority(loc)
    end
    res = SITEMAP_DICT[loc] = SMOpts(lastmod, changefreq, priority)
    return res
end

"""
$SIGNATURES

Generate a `sitemap.xml`, if one already exists, it will be replaced.
"""
function sitemap_generator()
    sitemap_file = splitext(globvar(:sitemap_file))[1] * ".xml"
    dst = joinpath(path(:site), sitemap_file)
    isfile(dst) && rm(dst)
    io = IOBuffer()
    println(io, """
        <?xml version="1.0" encoding="utf-8" standalone="yes" ?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        """)
    base_url = globvar(:website_url)
    strip_index = globvar(:sitemap_strip_index)
    for (k, v) in SITEMAP_DICT
        key = joinpath(escapeuri.(split(k, '/'))...)
        key = replace(key, '\\' => '/')
        if strip_index && endswith(key, "index.html")
            key = key[1:end-length("index.html")]
        end
        loc = "<loc>$(joinpath(base_url, key))</loc>"
        lastmod = "<lastmod>$(v.lastmod)</lastmod>"
        changefreq = "<changefreq>$(v.changefreq)</changefreq>"
        priority = "<priority>$(v.priority)</priority>"
        write(io, """
            <url>
                $loc
                $lastmod
                $changefreq
                $priority
            </url>
            """)
    end
    println(io, "</urlset>")
    write(dst, take!(io))
    return nothing
end
