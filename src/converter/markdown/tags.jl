"""
$(SIGNATURES)

Create and/or update `__site/tag` folders/files. It takes the set of tags to
refresh (in which case only the pages associated to those tags will be
refreshed) or an empty set in which case all tags will be (re)-generated.
Note that if a tag is removed from a page, it may be that `refresh_tags`
contains a tag which should effectively be removed because no page have it.
(This only matters at the end in the call to `write_tag_page`).
Note: the `clean_tags` cleans up orphan tags (tags that wouldn't be pointing
to any page anymore).
"""
function generate_tag_pages(refresh_tags=Set{String}())::Nothing
    globvar(:generate_tags)::Bool || return
    # if there are no page tags, cleanup and finish
    PAGE_TAGS = globvar("fd_page_tags")
    isnothing(PAGE_TAGS) && return clean_tags()

    # if there are page tags, eliminate the pages that don't exist anymore
    for rpath in keys(PAGE_TAGS)
        # check first the md path (default), but in some case the tag
        # may have been collected from a raw file which may be in assets in
        # which case the rpath includes the extension (.html)
        # see: https://github.com/JuliaDocs/Franklin.jl/discussions/1010
        has_source  = isfile(rpath * ".md")
        has_source |= isfile(replace(rpath, "/assets/" => "/_assets/" ))
        has_source || delete!(PAGE_TAGS, rpath)
    end
    # if there's nothing left, clean up and finish
    isempty(PAGE_TAGS) && return clean_tags()

    # Here we have a non-empty PAGE_TAGS dictionary where the keys are
    # paths of existing files, and values are the tags associated with
    # these files.
    # Get the inverse dictionary {tag -> [rp1, rp2...]}
    TAG_PAGES = invert_dict(PAGE_TAGS)
    # store it in globvar
    set_var!(GLOBAL_VARS, "fd_tag_pages", TAG_PAGES; check=false)
    all_tags = collect(keys(TAG_PAGES))

    # some tags may have been given to refresh which don't have any
    # pages linking to them anymore, these tags will have to be cleaned up
    rm_tags = filter(t -> t ∉ all_tags, refresh_tags)

    # check which tags should be refreshed
    update_tags = isempty(refresh_tags) ? all_tags :
                    filter(t -> t ∈ all_tags, refresh_tags)

    # Generate the tag folder if it doesn't exist already
    isdir(path(:tag)) || mkpath(path(:tag))
    # Generate the tag layout page if it doesn't exist (it should...)
    isfile(joinpath(path(:layout), "tag.html")) || write_default_tag_layout()
    # write each tag, note that they are necessarily in TAG_PAGES
    for tag in update_tags
        write_tag_page(tag)
    end
    return clean_tags(rm_tags)
end

"""
    clean_tags(rm_tags=nothing)

Check the content of the tag folder and remove orphan pages.
"""
function clean_tags(rm_tags=nothing)::Nothing
    isdir(path(:tag)) || return nothing
    PAGE_TAGS = globvar("fd_page_tags")
    if isnothing(PAGE_TAGS) || isempty(PAGE_TAGS)
        all_tags = []
    else
        all_tags = union(values(PAGE_TAGS)...)
    end
    # check what folders are present
    all_tag_folders = readdir(path(:tag))
    # check what folders shouldn't be present
    orphans = setdiff(all_tags, all_tag_folders)
    if !isnothing(rm_tags)
        orphans = union(orphans, rm_tags)
    end
    # clean up
    for dirname in orphans
        dirpath = joinpath(path(:tag), dirname)
        isdir(dirpath) && rm(dirpath, recursive=true)
    end
    return nothing
end

"""
$SIGNATURES

Internal function to (re)write the tag pages corresponding to `update_tags`.
"""
function write_tag_page(tag)::Nothing
    FD_ENV[:SOURCE] = "generated - tag"
    # make `fd_tag` available to that page generation
    set_var!(LOCAL_VARS, "fd_tag", tag)

    layout  = path(:layout)
    content = read(joinpath(layout, "tag.html"), String)

    dir = joinpath(path(:tag), tag)
    isdir(dir) || mkdir(dir)

    h = convert_html(content) |> postprocess_page

    write(joinpath(dir, "index.html"), h)

    # reset `fd_tag`
    set_var!(LOCAL_VARS, "fd_tag", "")
    return nothing
end


"""
    write_default_tag_layout()

If `_layout/tag.html` is not defined, input a basic default one indicating
that the user has to modify it. This will help users transition when they may
have used a template that did not define `_layout/tag.html`.
"""
function write_default_tag_layout()::Nothing
    dc = globvar("div_content")::String
    dc = ifelse(isempty(dc), globvar("content_class")::String, dc)
    html = """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Tag: {{fill fd_tag}}</title>
        </head>
        <body>
          <div class="$dc tagpage">
            {{taglist}}
          </div>
        </body>
        </html>
        """
    write(joinpath(path(:layout), "tag.html"), html)
    return nothing
end
