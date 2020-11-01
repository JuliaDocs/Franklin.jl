# TODO: could also expose the channel options if someone wanted
# to define those; can probably leave for later until feedback has
# been received.

# Specifications: RSS 2.0 -- https://cyber.harvard.edu/rss/rss.html#sampleFiles
# steps:
# 0. check if the relevant variables are defined otherwise don't generate the RSS
# 1. is there an RSS file?
#  --> remove it and create a new one (bc items may have been updated)
# 2. go over all pages
#  --> is there a rss var?
#  NO  --> skip
#  YES --> recuperate the `fd_ctime` and `fd_mtime` and add a RSS channel object
# 3. save the file

struct RSSItem
    # -- required fields
    title::String
    link::String
    description::String  # note: should not contain <p>
    # -- optional fields
    author::String       # note: should be a valid email
    category::String
    comments::String     # note: should be a valid URL
    enclosure::String
    # guid == link
    pubDate::Date        # note: should respect RFC822 (https://www.w3.org/Protocols/rfc822/)
end

# page_url => (RSSItem, tag vector)
const RSS_DICT = LittleDict{String,Tuple{RSSItem,Vector{String}}}()


"""
    jor(a, b)

Convenience function for fallback fields.
"""
jor(a::String, b::String) = ifelse(isempty(locvar(a)), locvar(b), locvar(a))

"""
    remove_html_ps

Convenience function to remove <p> and </p> in RSS description (not supposed to
happen).
"""
remove_html_ps(s::String)::String = replace(s, r"</?p>" => "")

"""
$SIGNATURES

RSS should not contain relative links so this finds relative links and prepends
them with the canonical link.
"""
fix_relative_links(s::String, link::String) =
    replace(s, r"(href|src)\s*?=\s*?\"\/" => SubstitutionString("\\1=\"$link"))

"""
$SIGNATURES

Create an `RSSItem` out of the provided fields defined in the page vars.
"""
function add_rss_item()
    link  = url_curpage()
    title = jor("rss_title", "title")
    descr = jor("rss", "rss_description")

    descr = fd2html(descr; internal=true) |> remove_html_ps

    author    = locvar(:rss_author)
    category  = locvar(:rss_category)
    comments  = locvar(:rss_comments)
    enclosure = locvar(:rss_enclosure)

    # Keep track of tags for tag specific feeds
    tags = locvar(:tags)::Vector{String}

    pubDate = locvar(:rss_pubdate)
    if pubDate == Date(1)
        pubDate = locvar(:date)
        if !isa(pubDate, Date) || pubDate == Date(1)
            pubDate = Date(locvar(:fd_mtime_raw))
        end
    end

    # warning for title which should really be defined
    isnothing(title) && (title = "")
    isempty(title)   && print_warning("""
        An RSS description was found but without title for page '$link'.
        """)

    rss = RSSItem(title, link, descr, author, category, comments, enclosure, pubDate)

    res = RSS_DICT[link] = (rss, tags)
    return res
end


"""
$SIGNATURES

Extract the entries from RSS_DICT and assemble the RSS. If the dictionary is empty, nothing
is generated.
"""
function rss_generator()::Nothing
    # is there anything to go in the RSS feed?
    isempty(RSS_DICT) && return nothing

    # are the basic defs there? otherwise warn and break
    rss_title = globvar("website_title")
    rss_descr = globvar("website_descr")
    rss_link  = globvar("website_url")

    if any(isempty, (rss_title, rss_descr, rss_link))
        print_warning("""
            RSS items were found but the RSS feed is improperly described:
            at least one of the following variables have not been defined in
            your 'config.md': 'website_title', 'website_descr', 'website_url'.
            The feed will not be (re)generated.
            \nRelevant pointer:
            $POINTER_PV
            """)
        return nothing
    end

    endswith(rss_link, "/") || (rss_link *= "/")
    rss_descr = fd2html(rss_descr; internal=true) |> remove_html_ps

    # sort items by pubDate
    RSS_DICT_SORTED = sort(OrderedDict(RSS_DICT), rev = true, byvalue = true, by = x -> x[1].pubDate)

    # Global feed; include all items
    rss_path = joinpath(PATHS[:site], "feed.xml")
    ## Remove tags vector
    rss_items = OrderedDict{String,RSSItem}(k => v[1] for (k, v) in RSS_DICT_SORTED)
    ## Write the file
    write_rss_xml(rss_path, rss_title, rss_descr, rss_link, rss_items)

    # Tag specific feed; filter items by tag
    ## Collect all tags
    tags = Set{String}()
    foreach(x -> union!(tags, x[2]), values(RSS_DICT))
    for tag in tags
        rss_path = joinpath(path(:tag), tag, "feed.xml")
        ## Filter items containing this tag only
        rss_items = OrderedDict{String,RSSItem}(k => v[1] for (k, v) in RSS_DICT_SORTED if tag ∈ v[2])
        ## Write the file
        write_rss_xml(rss_path, rss_title, rss_descr, rss_link, rss_items)
    end

    return nothing
end

function write_rss_xml(rss_path, rss_title, rss_descr, rss_link, rss_items)
    # is there an RSS file already? if so remove it
    isfile(rss_path) && rm(rss_path)
    # make sure the directory exists
    mkpath(dirname(rss_path))

    # create a buffer which will correspond to the output
    rss_buff = IOBuffer()
    write(rss_buff,
        """
        <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
        <channel>
          <title>$rss_title</title>
          <description><![CDATA[$(fix_relative_links(rss_descr, rss_link))]]></description>
          <link>$rss_link</link>
          <atom:link href="$(rss_link)feed.xml" rel="self" type="application/rss+xml" />
        """)


    # loop over items
    for (k, v) in rss_items
        full_link = rss_link
        if startswith(v.link, "/")
            full_link *= v.link[2:end]
        else
            full_link *= v.link
        end
        write(rss_buff,
          """
            <item>
              <title>$(v.title)</title>
              <link>$(full_link)</link>
              <description><![CDATA[$(fix_relative_links(v.description, rss_link))<br><a href=\"$full_link\">Read more</a>]]></description>
          """)
        for elem in (:author, :category, :comments, :enclosure)
            e = getproperty(v, elem)
            isempty(e) || write(rss_buff,
              """
                  <$elem>$e</$elem>
              """)
        end
        write(rss_buff,
          """
              <guid>$(full_link)</guid>
              <pubDate>$(Dates.format(v.pubDate, "e, d u Y")) 00:00:00 UT</pubDate>
            </item>
          """)
    end
    # finalize
    write(rss_buff,
        """
        </channel>
        </rss>
        """)
    write(rss_path, take!(rss_buff))

    return nothing
end
