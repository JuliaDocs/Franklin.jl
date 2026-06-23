# Items are assembled by the rss_generator in a global feed and sub-feeds
# for each of the tag. So each item is a tuple with the string of the item
# and
struct RSSItem
    item::String
    date::Date
    tags::Vector{String}
end

const RSS_ITEMS = Vector{RSSItem}()


"""
$SIGNATURES

If there's an RSS feed to generate, check that the template files are there, if not
then get them from FranklinTemplates. Also check that a few key variables
are defined.
"""
function prepare_for_rss()::Nothing
    # check for key variables
    key_vars = (:website_title, :website_url, :website_description)
    flag = any(isempty, globvar(key_var)::String for key_var in key_vars)

    # XXX [April 2020, 0.10.35] if the flag is false and generate_rss is false
    # switch it to true for backward compatibility; otherwise return
    gen_rss = globvar(:generate_rss)::Bool
    if flag
        gen_rss || return nothing
        print_warning("""
            RSS is set to be generated but the RSS feed is improperly described:
            at least one of the following variables have not been defined in
            your 'config.md': 'website_title', 'website_url', 'website_description'.
            The feed will not be (re)generated.
            \nRelevant pointer:
            $POINTER_PV
            """)
        return nothing
    elseif !gen_rss
        set_var!(GLOBAL_VARS, "generate_rss", true)
    end
    # check if there's an _rss folder, if there isn't generate one from
    # template (see FranklinTemplates)
    isdir(path(:rss)) || mkdir(path(:rss))
    for template in ("head.xml", "item.xml")
        dst = joinpath(path(:rss), template)
        if !isfile(dst)
            src = joinpath(
                dirname(pathof(FranklinTemplates)),
                "templates", "common", "_rss", template
            )
            cp(src, dst)
            # ensure the file is not read-only
            chmod(dst, 0o644)
        end
    end
    return nothing
end


"""
$SIGNATURES

Extract the entries from RSS_ITEMS and assemble the RSS. If RSS_ITEMS is empty, nothing
is generated. If tags are associated with items, also create one feed per tag.

Note: if a file `head_rtag.xml` is available, where `rtag` is the refstring of a tag, it
will take precedence for the corresponding tag feed; otherwise `head.xml` will be used.
"""
function rss_generator()::Nothing
    # is there anything to go in the RSS feed?
    isempty(RSS_ITEMS) && return nothing

    # sort items by reverse chronological order
    sorted_items = sort(RSS_ITEMS, rev=true, by=x->x.date)

    feed_name = globvar(:rss_file)::String * ".xml"
    global_feed_path = joinpath(PATHS[:site], feed_name)
    global_feed_head = replace(
        read(joinpath(path(:rss), "head.xml"), String),
        r"<!--(.|\n)*?-->" => ""
    )
    if FD_ENV[:FINAL_PASS]
        pp = globvar(:prepath)::String
        isempty(pp) || (pp = "/$pp")
        global_feed_head = replace(
            global_feed_head,
            r"(\/[a-zA-Z0-9\_-]+\.xsl)" => SubstitutionString("$pp\\1")
        )
    end

    open(global_feed_path, "w") do io
        write(io, convert_html(global_feed_head))
        for item in sorted_items
            write(io, item.item)
        end
        write(io, "</channel></rss>")
    end

    # Tag specific feed; filter items by tag
    # > Collect all raw tags
    tags = Set{String}()
    foreach(x -> union!(tags, x.tags), RSS_ITEMS)
    # > write a feed per tag, use head_tag if it exists
    for tag in tags
        rtag = refstring(tag)
        tag_dir = joinpath(path(:tag), refstring(tag))
        isdir(tag_dir) || mkpath(tag_dir)
        tag_feed_path = joinpath(tag_dir, feed_name)
        open(tag_feed_path, "w") do io
            tag_feed_head = global_feed_head
            tag_feed_head_cand = joinpath(path(:rss), "head_$rtag.xml")
            if isfile(tag_feed_head_cand)
                tag_feed_head = read(tag_feed_head_cand)
            end
            write(io, convert_html(tag_feed_head))
            for item in sorted_items
                tag ∈ item.tags || continue
                write(io, item.item)
            end
            write(io, "</channel></rss>")
        end
    end
    return nothing
end


"""
$SIGNATURES

This is called in `convert_and_write` to add an RSS item.
"""
function add_rss_item()
    item_template = replace(
        read(joinpath(path(:rss), "item.xml"), String),
        r"<!--(.|\n)*?-->" => ""
    )
    # if the rss_title is not given, infer from title
    if isempty(locvar(:rss_title)::String)
        set_var!(LOCAL_VARS, "rss_title", locvar(:title)::String)
    end
    item = replace(convert_html(item_template), r"\n\n" => "")
    item = replace(item, Regex(raw"""<a\shref=(?:"|')?\#.*?>(.*?)</a>""") => s"\1")
    # Strip index.html from URLs (consistent with sitemap behavior).
    # Normalizing here (post-hoc on rendered XML) rather than at the
    # url_curpage() level to avoid changing URL generation globally.
    if globvar(:sitemap_strip_index)
        item = replace(item, "/index.html" => "/")
    end

    rss_item = RSSItem(
        item,
        locvar(:rss_pubdate)::Date,
        locvar(:tags)::Vector{String}
    )
    push!(RSS_ITEMS, rss_item)
end
