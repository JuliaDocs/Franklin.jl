const FD_PY_MIN_NAME = ".__py_tmp_minscript.py"

"""
$(SIGNATURES)

Does a full pass followed by a pre-rendering and minification step.

* `prepath=""`:     set this to something like "project-name" if it's a project
                     page (usually this is set via config.md)
* `version=""`:     if "dev", the base url will be `/{prepath}/dev/`, if "xxx",
                     the base url will be `/{prepath}/stable/`, a copy of
                     the website will also be at `/{prepath}/xxx/` an example
                     would be `version="v0.15.2"`. If left empty, the base url
                     is just `/{prepath}/`.
* `is_preview=false`: if true, then no matter what the version given is, it will
                       not update `/stable/` and `/dev/`.
* `prerender=true`: whether to pre-render katex and highlight.js (requires
                     `node.js`)
* `minify=true`:    whether to minify output (requires `python3` and
                     `css_html_js_minify`)
* `sig=false`:      whether to return an integer indicating success (see
                     [`publish`](@ref))
* `clear=false`:    whether to clear the output dir and thereby regenerate
                     everything
* `no_fail_prerender=true`: whether to ignore errors during the pre-rendering
                             process
* `suppress_errors=true`:   whether to suppress errors
* `fail_on_warning=false`:   if true, warnings become fatal errors
* `cleanup=true`:   whether to empty environment dictionaries
* `on_write(pg, fd_vars)`: callback function after the page is rendered,
                      passing as arguments the rendered page and the page
                      variables

Note: if the prerendering is set to `true`, the minification will take longer
as the HTML files will be larger (especially if you have lots of maths on
pages).
"""
function optimize(;
            prepath::String="",
            version::String="",
            prerender::Bool=true,
            minify::Bool=true,
            sig::Bool=false,
            no_fail_prerender::Bool=true,
            on_write::Function=(_,_)->nothing,
            suppress_errors::Bool=true,
            clear::Bool=false,
            cleanup::Bool=true,
            fail_on_warning::Bool = false
            )::Union{Nothing,Bool}

    suppress_errors && (FD_ENV[:SUPPRESS_ERR] = true)
    FD_ENV[:FAIL_ON_WARNING] = fail_on_warning

    isassigned(FOLDER_PATH) || (FOLDER_PATH[] = pwd(); set_paths!())

    #
    # Prerendering
    #
    if prerender && !FD_CAN_PRERENDER()
        prerender = false
    end
    prerender && !FD_CAN_HIGHLIGHT(; force=true)
    if !isempty(prepath)
        GLOBAL_VARS["prepath"] = dpair(prepath)
    end
    no_set_paths = false
    join_to_prepath = ""
    version = lowercase(strip(version))
    if !isempty(version)
        if version == "dev"
            c = "dev"
        elseif startswith(version, "previews/")
            c = version
        else
            c = "stable"
        end
        join_to_prepath = c
        PATHS[:site] = joinpath(PATHS[:folder], "__site", c)
        PATHS[:tag]  = joinpath(PATHS[:site], "tag")
        mkpath(PATHS[:site])
        no_set_paths = true
    end

    # re-do a (silent) full pass
    start = time()
    fmsg = "\r→ Full pass"
    withpre = fmsg * ifelse(prerender,
                                rpad(" (with pre-rendering)", 24),
                                rpad(" (no pre-rendering)",   24))
    succ = nothing === serve(single=true, clear=clear, nomess=true,
                             is_final_pass=true, prerender=prerender,
                             no_fail_prerender=no_fail_prerender,
                             cleanup=false, on_write=on_write,
                             no_set_paths=no_set_paths,
                             join_to_prepath=join_to_prepath)
    print_final(withpre, start)

    #
    # Minification
    #
    if minify && (succ || no_fail_prerender)
        if FD_CAN_MINIFY()
            start = time()
            mmsg = rpad("→ Minifying *.[html|css] files...", 35)
            print(mmsg)
            # copy the script to the current dir
            path_to = joinpath(dirname(pathof(Franklin)),
                                "scripts", "minify.py")
            py_script = read(path_to, String)
            write(FD_PY_MIN_NAME, py_script)
            # run it
            succ = success(`$([e for e in split(PY())]) $FD_PY_MIN_NAME`)
            # remove the script file
            rm(FD_PY_MIN_NAME)
            print_final(mmsg, start)
        end
    end

    # if not dev or preview, the /stable/ path was overwritten and we copy that
    # to whatever the version is so that it's also /v.../
    if !isempty(version) && version != "dev" && !startswith(version, "previews/")
        for c in (version, "dev")
            mpath = joinpath(PATHS[:folder], "__site", c)
            isdir(mpath)  && rm(mpath, recursive=true)
            cp(path(:site), mpath)

            # go over every file and fix the prepath to prepath/version
            for (root, _, files) in walkdir(mpath)
                for file in files
                    endswith(file, ".html") || continue
                    fp = joinpath(root, file)
                    ct = read(fp, String)
                    write(fp, replace(ct, "/stable/" => "/$c/"))
                end
            end
        end
    end

    #
    # Clean up empty folders if any
    #
    for name in readdir(path(:site))
        p = joinpath(path(:site), name)
        isdir(p) || continue
        isempty(readdir(p)) && rm(p)
    end

    cleanup && clear_dicts()

    FD_ENV[:SUPPRESS_ERR] = false
    return ifelse(sig, succ, nothing)
end


"""
$(SIGNATURES)

This is a simple wrapper doing a git commit and git push without much
fanciness. It assumes the current directory is a git folder.
It also fixes all links if you specify `prepath` (or if it's set in
`config.md`).

**Keyword arguments**

* `prerender=true`: prerender javascript before pushing see
                     [`optimize`](@ref)
* `minify=true`:    minify output before pushing see [`optimize`](@ref)
* `nopass=false`:   set this to true if you have already run `optimize`
                     manually.
* `prepath=""`:     set this to something like "project-name" if it's a
                     project page
* `message="franklin-update"`: add commit message.
* `cleanup=true`:   whether to cleanup environment dictionaries (should
                     stay true).
* `final=nothing`:  a function `()->nothing` to execute last, before doing
                     the git push. It can be used to refresh a Lunr index,
                     generate notebook files with Literate, etc, ...
                     You might want to compose `fdf_*` functions that are
                     exported by Franklin (or imitate those). It can
                     access GLOBAL_VARS.
"""
function publish(; prerender::Bool=true, minify::Bool=true, nopass::Bool=false,
                   prepath::String="", message::String="franklin-update",
                   cleanup::Bool=true, final::Union{Nothing,Function}=nothing,
                   do_push::Bool=true)::Nothing
    succ = true
    if !isempty(prepath) || !nopass
        # no cleanup so that can access global page variables in final step
        succ = optimize(prerender=prerender, minify=minify,
                        sig=true, prepath=prepath, cleanup=false)
    end
    if succ
        # final hook
        final === nothing || final()
        # --------------------------
        # Push to git (publication)
        start = time()
        pubmsg = rpad("→ Pushing updates with git...", 35)
        print(pubmsg)
        try
            run(`git add -A `)
            wait(run(`git commit -m "$message" --quiet`; wait=false))
            if do_push
                run(`git push --quiet`)
            end
            print_final(pubmsg, start)
        catch e
            println("✘ Could not push updates, verify your connection " *
                    "and/or try manually.\n")
            @show e
        end
    else
        println("✘ Something went wrong in the optimisation step. " *
                "Not pushing updates.")
    end
    return nothing
end


"""
Allows you to pull from your remote git repository after having
removed the local output directory. This will help avoid merge clashes.
"""
function cleanpull()::Nothing
    FOLDER_PATH[] = pwd()
    set_paths!()

    rmmsg = rpad("→ Removing local __site dir...", 35)
    print(rmmsg)
    isdir(path(:site)) && rm(path(:site), force=true, recursive=true)
    println("\r" * rmmsg * " [done ✔ ]")

    try
        pmsg = rpad("→ Retrieving updates from the repository...", 35)
        print(pmsg)
        run(`git pull --quiet`)
        println("\r" * pmsg * " [done ✔ ]")
    catch e
        println("✘ Could not pull updates, verify your connection and try manually.\n")
        @show e
    end
    return nothing
end


"""
$SIGNATURES

Take a page (in HTML) and check all `href` on it to see if they lead somewhere.
"""
function verify_links_page(path::AS, online::Bool)
    shortpath = replace(path, PATHS[:folder] => "")
    mdpath = replace(path, PATHS[:site] => "")
    mdpath = splitext(mdpath)[1] * ".md"
    dir, fn = splitdir(mdpath) # fn will be index.md
    if dir == "/"
        mdpath = dir * "index.md"
    else
        mdpath = dir * "[" * PATH_SEP *  "index].md"
    end
    allok = true
    page  = read(path, String)
    for m in eachmatch(r"\shref=\"(https?://)?(.*?)(?:#(.*?))?\"", page)
        if m.captures[1] === nothing
            # internal link;
            link = m.captures[2]
            anchor = m.captures[3]
            (isempty(link) || link == "/") && continue # this is always ok
            if link[1] === '/'
                # Absolute link, join with the base site folder
                full_link = joinpath(PATHS[:site], link[2:end])
            else
                # Relative path, compute from the current path
                full_link = joinpath(dirname(path), link)
            end
            if endswith(full_link, "/")
                full_link *= "index.html"
            end
            if !isfile(full_link)
                allok && println("")
                println("- internal link issue on page $mdpath: $link.")
                allok = false
            else
                if !isnothing(anchor)
                    if full_link != path
                        rpage = read(full_link, String)
                    else
                        rpage = page
                    end
                    # look for `id=...` either with or without quotation marks
                    if match(Regex("id=(?:\")?$anchor(?:\")?"), rpage) === nothing
                        allok && println("")
                        println("- internal link issue on page $mdpath: $link.")
                        allok = false
                    end
                end
            end
        else
            online || continue
            # external link
            link = m.captures[1] * m.captures[2]
            ok = false
            try
                headers = contains(link, "doi.org") ? ["Accept" => "application/x-bibtex"] : []
                ok = HTTP.request("HEAD", link, headers, timeout=3).status == 200
            catch e
            end
            if !ok
                allok && println("")
                println("- external link issue on page $mdpath: $link")
                allok = false
            end
        end
    end
    return allok
end

"""
$SIGNATURES

Verify all links in generated HTML.
"""
function verify_links(; ttl=64)::Nothing
    @assert 1 ≤ ttl ≤ 255 "IP Time to Live must be between 1 and 255"
    # if this is done before `serve` is called
    if isempty(PATHS)
        FOLDER_PATH[] = pwd()
        set_paths!()
    end
    # check that the user is online (otherwise only verify internal links)
    # this is fast as it uses `ping` and does not resolve a request
    online = findfirst(ipadd -> check_ping(ipadd, ttl), first.(IP_CHECK)) !== nothing

    print("Verifying links...")
    if online
        print(" [you seem online ✓]")
    else
        print(" [you don't seem online ✗]")
    end

    overallok = true
    for (root, _, files) ∈ walkdir(PATHS[:folder])
        for file ∈ files
            splitext(file)[2] == ".html" || continue
            fpath = joinpath(root, file)
            if startswith(fpath, path(:assets)) ||
               startswith(fpath, path(:css))    ||
               startswith(fpath, path(:layout)) ||
               startswith(fpath, path(:libs))   ||
               startswith(fpath, path(:literate))
               startswith(fpath, joinpath(path(:folder), ".git"))
               continue
            end
            allok = verify_links_page(fpath, online)
            overallok = overallok && allok
        end
    end
    overallok && println("\rAll internal $(ifelse(online,"and external ",""))links verified ✓.      ")
    return nothing
end
