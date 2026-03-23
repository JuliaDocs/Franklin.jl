const DTAG  = LittleDict{String,Set{String}}
const DTAGI = LittleDict{String,Vector{String}}

"""
    dpair

Helper function to create a default pair for a page variable.
"""
dpair(v) = Pair(v, (typeof(v),))

"""
    GLOBAL_VARS

Dictionary of variables accessible to all pages. Used as an initialiser for
`LOCAL_VARS` and modified by `config.md`.
Entries have the format KEY => PAIR where KEY is a string (e.g.: "author") and
PAIR is a pair where the first element is the current value for the variable
and the second is a tuple of accepted possible (super)types
for that value. (e.g.: "THE AUTHOR" => (String, Nothing))
"""
const GLOBAL_VARS = PageVars()

const GLOBAL_VARS_DEFAULT = [
    # General
    "author"           => Pair("", (String, Nothing)),
    "prepath"          => dpair(""),
    "date_format"      => dpair("U dd, yyyy"),
    "date_days"        => dpair(String[]),
    "date_shortdays"   => dpair(String[]),
    "date_months"      => dpair(String[]),
    "date_shortmonths" => dpair(String[]),
    "tag_page_path"    => dpair("tag"),
    "title_links"      => dpair(true),
    # will be added to IGNORE_FILES
    "ignore"           => Pair(String[], (Vector{Any},)),
    # don't insert `index.html` at the end of the path for these files
    "keep_path"        => Pair(String[], (Vector{String},)),
    # for robots.txt
    "robots_disallow"  => Pair(String[], (Vector{String},)),
    "generate_robots"  => dpair(true),
    # RSS
    "generate_rss"        => dpair(false),
    "website_title"       => dpair(""),
    "website_url"         => dpair(""),
    "website_description" => dpair(""),
    "rss_file"            => dpair("feed"),
    "rss_full_content"    => dpair(false),
    # Sitemap
    "generate_sitemap"    => dpair(true),
    "sitemap_file"        => dpair("sitemap"),
    "sitemap_strip_index" => dpair(true),
    # div names
    "content_tag"       => dpair("div"),
    "content_class"     => dpair("franklin-content"),
    "content_id"        => dpair(""),
    "code_output_class" => dpair("code-output"),
    # auto detection of code / math (see hasmath/hascode)
    "autocode"         => dpair(true),
    "automath"         => dpair(true),
    # keep track page=>tags and tag=>pages
    "fd_page_tags"     => Pair(nothing, (DTAG,  Nothing)),
    "fd_tag_pages"     => Pair(nothing, (DTAGI, Nothing)),
    "fd_rss_feed_url"  => dpair(""),
    # keep track of all anchors {label => page} in case of clash, there's no guarantee
    "anchors"          => dpair(LittleDict{String,String}()),
    # allow md strings in Literate
    "literate_mds"     => dpair(false),
    # each cell runs a cd in/out OUT_PATH
    "auto_code_path"   => dpair(false),
    # don't generate tag pages
    "generate_tags"    => dpair(true),
    # -----------------------------------------------------
    # LEGACY
    "div_content" => dpair(""), # see build_page
    #
    "_has_base_project" => dpair(false),
    ]

const GLOBAL_VARS_ALIASES = LittleDict(
    "prefix"            => "prepath",
    "base_path"         => "prepath",
    "base_url"          => "website_url",
    "rss_website_title" => "website_title",
    "rss_website_url"   => "website_url",
    "rss_website_descr" => "website_description",
    "website_descr"     => "website_description",
    "rss_filename"      => "rss_file",
    "sitemap_filename"  => "sitemap_file",
    )

"""
Re-initialise the global page vars dictionary. (This is done once).
"""
 function def_GLOBAL_VARS!()::Nothing
    empty!(GLOBAL_VARS)
    for (v, p) in GLOBAL_VARS_DEFAULT
        GLOBAL_VARS[v] = p
    end
    return nothing
end

"""
Dictionary of variables accessible to the current page. It's initialised with
`GLOBAL_VARS` and modified via `@def ...`.
"""
const LOCAL_VARS = PageVars()

const LOCAL_VARS_DEFAULT = [
    # General
    "title"         => Pair(nothing,    (String, Nothing)),
    "hasmath"       => dpair(false),
    "hascode"       => dpair(false),
    "date"          => Pair(Date(1),    (String, Date, Nothing)),
    "lang"          => dpair("julia"),  # default lang indented code
    "reflinks"      => dpair(true),     # are there reflinks?
    "indented_code" => dpair(false),    # support indented code?
    "tags"          => dpair(String[]),
    "prerender"     => dpair(true),     # allow specific switch
    "slug"          => dpair(""),       # allow specific target url eg: aa/bb/cc
    "draft"         => dpair(false),    # page will not be generated at built time if true
    # -----------------
    # TABLE OF CONTENTS
    "mintoclevel" => dpair(1),   # set to 2 to ignore h1
    "maxtoclevel" => dpair(10),  # set to 3 to ignore h4,h5,h6
    # ---------------
    # CODE EVALUATION
    "reeval"        => dpair(false),  # whether to reeval all pg
    "noeval"        => dpair(false),  # whether to disable code eval
    "showall"       => dpair(false),  # if true, notebook style
    "fd_eval"       => dpair(false),  # toggle re-eval
    # ------------------
    # header links class
    "header_anchor_class" => dpair("header-anchor"),
    # ------------------
    # RSS 2.0 specs [^2]
    "rss_description" => dpair(""),
    "rss_title"       => dpair(""),
    "rss_author"      => dpair(""),
    "rss_category"    => dpair(""),
    "rss_comments"    => dpair(""),
    "rss_enclosure"   => dpair(""),
    "rss_pubdate"     => dpair(Date(1)),
    # -------------
    # SITEMAP specs https://www.sitemaps.org/protocol.html
    "sitemap_changefreq" => dpair("monthly"),
    "sitemap_priority"   => dpair(0.5),
    "sitemap_exclude"    => dpair(false),
    # -------------
    # ROBOTS.TXT
    "robots_disallow_this_page" => dpair(false),
    # -------------
    # MISCELLANEOUS (should not be modified by the user)
    "fd_mtime_raw" => dpair(Date(1)),
    "fd_ctime"     => dpair("0001-01-01"),  # time of creation
    "fd_mtime"     => dpair("0001-01-01"),  # time of last modification
    "fd_rpath"     => dpair(""),            # relative path to current page [1]
    "fd_url"       => dpair(""),            # relative url to current page [2]
    "fd_full_url"  => dpair(""),            # full url to current page [3]
    "fd_tag"       => dpair(""),            # (generated) current tag
    "fd_evalc"     => dpair(1),             # counter for direct evaluation cells (3! blocks)
    "fd_page_html" => dpair(""),            # the generated html for the page
    ]
#=
NOTE:
 2. only title, link and description *must*
        title       -- rss_title // fallback to title
    (*) link        -- [automatically generated]
        description -- rss // rss_description, if undefined, no item generated
        author      -- rss_author // fallback to author
        category    -- rss_category
        comments    -- rss_comments
        enclosure   -- rss_enclosure
    (*) guid        -- [automatically generated from link]
        pubDate     -- rss_pubdate // fallback date // fallback fd_ctime
    (*) source      -- [unsupported assumes for now there's only one channel]

[1] e.g.: blog/kaggle.md
[2] e.g.: /blog/kaggle/index.html
[3] e.g.: https://username.github.io/project/blog/kaggle/index.html
=#

const LOCAL_VARS_ALIASES = LittleDict(
    "rss_descr" => "rss_description",
    "rss"       => "rss_description"
    )


"""
Re-initialise the local page vars dictionary. (This is done for every page).
Note that a global default overrides a local default. So for instance if
`title` is defined in the config as `@def title = "Universal"`, then the
default title on every page will be that.
"""
function def_LOCAL_VARS!()::Nothing
    empty!(LOCAL_VARS)
    for (v, p) in LOCAL_VARS_DEFAULT
        LOCAL_VARS[v] = p
    end
    # Merge global page vars, if it defines anything that local defines, then
    # global takes precedence.
    merge!(LOCAL_VARS, GLOBAL_VARS)
    # which page we're on, see convert_and_write which sets :CUR_PATH
    set_var!(LOCAL_VARS, "fd_rpath", FD_ENV[:CUR_PATH])
    set_var!(LOCAL_VARS, "fd_url", url_curpage())
    return nothing
end

"""
    locvar(name; default=nothing)

Convenience function to get the value associated with a local var.
Return `default` (which is `nothing` if not specified) if the variable is not found.
"""
function locvar(name::Union{Symbol,String}; default=nothing)
    name = String(name)
    name = get(LOCAL_VARS_ALIASES, name, name)
    name = get(GLOBAL_VARS_ALIASES, name, name)
    return haskey(LOCAL_VARS, name) ? LOCAL_VARS[name].first : default
end

"""
    globvar(name; default=nothing)

Convenience function to get the value associated with a global var.
Return `default` (which is `nothing` if not specified) if the variable is not found.
"""
function globvar(name::Union{Symbol,String}; default=nothing)
    name = String(name)
    return haskey(GLOBAL_VARS, name) ? GLOBAL_VARS[name].first : default
end


"""
Dict to keep track of all pages and their vars. Each key is a relative path
to a page, values are PageVars.
The keys don't have the file extension so `"blog/pg1" => PageVars`.
"""
const ALL_PAGE_VARS = LittleDict{String,PageVars}()

"""
    pagevar(rpath, name; default=nothing)

Convenience function to get the value associated with a var available to a page
corresponding to `rpath`. So for instance if `blog/index.md` has `@def var = 0`
then this can be accessed with `pagevar("blog/index", "var")` or
`pagevar("blog/index.md", "var")`.
If `rpath` is not yet a key of `ALL_PAGE_VARS` then maybe the page hasn't been
processed yet so force a pass over that page.

Return `default` (which is `nothing` if not specified) if the variable is not found.
"""
function pagevar(rpath::AS, name::Union{Symbol,String}; default=nothing)
    # HACK avoid stackoverflow for pagevar cycle
    PAGEVAR_DEPTH[] > 5 && return default

    # only split extension if it's .md or .html (otherwise can cause trouble
    # if there's a dot in the page name... not recommended but happens.)
    rpc = splitext(rpath)
    if rpc[2] in (".md", ".html")
        rpath = rpc[1]
    end

    (:pagevar, "$rpath, $name (key: $(haskey(ALL_PAGE_VARS, rpath)))") |> logger

    if !haskey(ALL_PAGE_VARS, rpath)
        # does there exist a file with a `.md` ? if so go over it
        # otherwise return nothing
        fpath = rpath * ".md"
        candpath = joinpath(path(:folder), fpath)
        isfile(candpath) || return nothing
        # store curpath
        bk_path = locvar(:fd_rpath)::String
        bk_path_ = splitext(bk_path)[1]

        (:pagevar, "!haskey, bkpath: $bk_path, rpath: $rpath") |> logger

        # set temporary cur path (so that defs go to the right place)
        set_cur_rpath(fpath, isrelative=true)
        # effectively we only care about the mddefs
        convert_md(read(fpath, String), pagevar=true)

        if !haskey(ALL_PAGE_VARS, bk_path_) # empty corner case in tests
            def_LOCAL_VARS!()
        else
            # re-set the cur path to what it was before
            set_cur_rpath(bk_path, isrelative=true)
            # re-set local vars using ALL_PAGE_VARS
            # NOTE: we must do this in place to messing things up.
            empty!(LOCAL_VARS)
            merge!(LOCAL_VARS, ALL_PAGE_VARS[bk_path_])
        end
    end
    name = String(name)
    return haskey(ALL_PAGE_VARS[rpath], name) ? ALL_PAGE_VARS[rpath][name].first : default
end

"""
Keep track of the names declared in the Utils module.
"""
const UTILS_NAMES = Vector{String}()

"""
Keep track of seen headers. The key is the refstring, the value contains the
title, the occurence number for the first appearance of that title and the
level (1, ..., 6).
"""
const PAGE_HEADERS = LittleDict{AS,Tuple{AS,Int,Int}}()

"""
$(SIGNATURES)

Empties `PAGE_HEADERS`.
"""
 function def_PAGE_HEADERS!()::Nothing
    empty!(PAGE_HEADERS)
    return nothing
end

"""
PAGE_FNREFS

Keep track of name of seen footnotes; the order is kept as it's a list.
"""
const PAGE_FNREFS = String[]

"""
$(SIGNATURES)

Empties `PAGE_FNREFS`.
"""
 function def_PAGE_FNREFS!()::Nothing
    empty!(PAGE_FNREFS)
    return nothing
end

"""
PAGE_LINK_DEFS

Keep track of link def candidates
"""
const PAGE_LINK_DEFS = LittleDict{String,String}()

"""
$(SIGNATURES)

Empties `PAGE_LINK_DEFS`.
"""
 function def_PAGE_LINK_DEFS!()::Nothing
    empty!(PAGE_LINK_DEFS)
    return nothing
end

#= ==========================================
Convenience functions related to the page vars
============================================= =#

"""
$(SIGNATURES)

Convenience function taking a `DateTime` object and returning the corresponding
formatted string with the format contained in `LOCAL_VARS["date_format"]` and
with the locale data provided in `date_months`, `date_shortmonths`, `date_days`,
and `date_shortdays` local variables. If `short` variations are not provided,
automatically construct them using the first three letters of the names in
`date_months` and `date_days`.
"""
function fd_date(d::DateTime)
    # aliases for locale data and format from local variables
    format      = locvar(:date_format)
    months      = locvar(:date_months)
    shortmonths = locvar(:date_shortmonths)
    days        = locvar(:date_days)
    shortdays   = locvar(:date_shortdays)
    # if vectors are empty, user has not defined custom locale,
    # defaults to english
    if all(isempty.((months, shortmonths, days, shortdays)))
        return Dates.format(d, format, locale="english")
    end
    # if shortdays or shortmonths are undefined,
    # automatically construct them from other lists
    if !isempty(days) && isempty(shortdays)
        shortdays = first.(days, 3)
    end
    if !isempty(months) && isempty(shortmonths)
        shortmonths = first.(months, 3)
    end
    # set locale for this page
    Dates.LOCALES["date_locale"] = Dates.DateLocale(months, shortmonths,
                                                    days, shortdays)
    return Dates.format(d, format, locale="date_locale")
end


"""
$(SIGNATURES)

Checks if a data type `t` is a subtype of a tuple of accepted types `tt`.
"""
function check_type(t::DataType, tt::NTuple{N,DataType} where N)::Bool
    any(valid_subtype(t, tᵢ) for tᵢ ∈ tt) && return true
    return false
end

valid_subtype(::Type{T1},
              ::Type{T2}) where {T1,T2} = T1 <: T2
valid_subtype(::Type{<:AbstractArray{T1,K}},
              ::Type{<:AbstractArray{T2,K}}) where {T1,T2,K} = T1 <: T2



"""
$(SIGNATURES)

Take a var dictionary `dict` and update the corresponding pair. This should
only be used internally as it does not check the validity of `val`. See
[`convert_and_write`](@ref) where it is used to store a file's creation and last
modification time.

Note: `check` can be false for DTAG, DTAGI which are considered as UnionAll types.
"""
function set_var!(vars::PageVars, key::String, value::T;
                  isglobal=false, check=true) where T
    exists = haskey(vars, key)
    # aliases are allowed for some global variables
    if !exists
        if isglobal && haskey(GLOBAL_VARS_ALIASES, key)
            exists = true
            key = GLOBAL_VARS_ALIASES[key]
        elseif !isglobal && haskey(LOCAL_VARS_ALIASES, key)
            exists = true
            key = LOCAL_VARS_ALIASES[key]
        end
    end
    if exists && check
        # if the retrieved value has the right type, assign it to the corresponding key
        acc_types = vars[key].second
        if check_type(T, acc_types)
            vars[key] = Pair(value, acc_types)
        else
            mddef_warn(key, value, acc_types)
        end
    else
        # there is no key, so directly assign, the type is not checked
        vars[key] = Pair(value, (T,))
    end
    return
end

#= =================================================
set_vars, the key function to assign site variables
==================================================== =#

"""
$(SIGNATURES)

Given a set of definitions `assignments`, update the variables dictionary
`vars`. Keys in `assignments` that do not match keys in `vars` are
ignored (a warning message is displayed).
The entries in `assignments` are of the form `KEY => STR` where `KEY` is a
string key (e.g.: "hasmath") and `STR` is an assignment to evaluate (e.g.:
"=false").
"""
function set_vars!(vars::PageVars, assignments::Vector{Pair{String,String}};
                   isglobal=false)::PageVars
    # if there's no assignment, cut it short
    isempty(assignments) && return vars
    # process each assignment in turn
    for (key, assign) ∈ assignments
        # at this point there may still be a comment in the assignment
        # string e.g. if it came from @def title = "blah" <!-- ... -->
        # so let's strip <!-- and everything after.
        # NOTE This is agressive so if it happened that the user wanted
        # this in a string it would fail (but come on...)
        idx = findfirst("<!--", assign)
        !isnothing(idx) && (assign = assign[1:prevind(assign, idx[1])])
        value, = Meta.parse(assign, 1)
        # try to evaluate the parsed assignment
        try
            value = eval(value)
        catch err
            throw(PageVariableError(
                "An error (of type '$(typeof(err))') occurred when trying " *
                "to evaluate '$value' in a page variable assignment."))
        end
        set_var!(vars, key, value; isglobal=isglobal)
    end
    return vars
end


"""
    set_page_env()

Initialises all page dictionaries.
"""
function set_page_env()
    def_LOCAL_VARS!()       # page-specific variables
    def_PAGE_HEADERS!()     # all the headers
    def_PAGE_EQREFS!()      # page-specific equation dict (hrefs)
    def_PAGE_BIBREFS!()     # page-specific reference dict (hrefs)
    def_PAGE_FNREFS!()      # page-specific footnote dict
    def_PAGE_LINK_DEFS!()   # page-specific link definition candidates
    return nothing
end
