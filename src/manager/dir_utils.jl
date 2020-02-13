"""
TrackedFiles

Convenience type to keep track of files to watch.
"""
const TrackedFiles = Dict{Pair{String, String}, Float64}


"""
Prepare the output directory `PATHS[:pub]`.

## Argument

* `clear=true`: removes the content of the output directory if it exists to
                start from a blank slate
"""
function prepare_output_dir(clear::Bool=true)::Nothing
    if FD_ENV[:STRUCTURE] < v"0.2"
        # if required to start from a blank slate -> remove the output dir
        (clear & isdir(PATHS[:pub])) && rm(PATHS[:pub], recursive=true)
        # create the output dir and the css dir if necessary
        !isdir(path(:pub)) && mkdir(path(:pub))
        !isdir(path(:css)) && mkdir(path(:css))
    else
        (clear & isdir(path(:site))) && rm(path(:site), recursive=true)
        !isdir(path(:site)) && mkdir(path(:site))
    end
    return nothing
end

"""
$(SIGNATURES)

Given a file path split in `(base, file)`, form the output path (where the
output file will be written/copied).
"""
function form_output_path(base::AS, file::AS, case::Symbol)
    # .md -> .html for md pages:
    case == :md && (file = change_ext(file))
    if FD_ENV[:STRUCTURE] < v"0.2"
        outbase = _out_path(base)
    else
        outbase = _out_path2(base)
        if case in (:md, :html)
            # file is index.html --> keep the path
            # file is page.html  --> .../page/index.html
            fname = splitext(file)[1]
            if fname != "index"
                file = joinpath(fname, "index.html")
            end
        end
    end
    outpath = joinpath(outbase, file)
    outdir  = splitdir(outpath)[1]
    isdir(outdir) || mkpath(outdir)
    return outpath
end

# NOTE: LEGACY way of getting the target path
function _out_path(base::String)::String
    if startswith(base, PATHS[:src_css])
        f_out_path = replace(base, PATHS[:src_css] => PATHS[:css])
        !ispath(f_out_path) && mkpath(f_out_path)
        return f_out_path
    end
    len_in = lastindex(joinpath(PATHS[:src], ""))
    length(base) <= len_in && return PATHS[:folder]
    dpath = base[nextind(base, len_in):end]
    # construct the out path
    f_out_path = joinpath(PATHS[:folder], dpath)
    f_out_path = replace(f_out_path, r"([^a-zA-Z\d\s_:])pages" => s"\1pub")
    # if it doesn't exist, make the path
    !ispath(f_out_path) && mkpath(f_out_path)
    return f_out_path
end

function _out_path2(base::String)::String
    if startswith(base, path(:assets)) ||
       startswith(base, path(:css))    ||
       startswith(base, path(:layout)) ||
       startswith(base, path(:libs))   ||
       startswith(base, path(:literate))

       # add a closing separator to folder path
       rbase   = joinpath(path(:folder), "")
       outpath = replace(base, Regex("$(rbase)_([a-z]+)") => s"\1")
       outpath = joinpath(path(:site), outpath)
   else
       # path is not a 'special folder'
       outpath = replace(base, path(:folder) => path(:site))
   end
    # if it doesn't exist, make the path
    !ispath(outpath) && mkpath(outpath)
    return outpath
end


"""
$(SIGNATURES)

Update the dictionaries referring to input files and their time of last change.
The variable `verb` propagates verbosity.
"""
function scan_input_dir!(args...; kw...)
    if FD_ENV[:STRUCTURE] < v"0.2"
        return _scan_input_dir!(args...)
    end
    return _scan_input_dir2!(args...; kw...)
end

function _scan_input_dir!(other_files::TrackedFiles,
                          infra_files::TrackedFiles,
                          md_files::TrackedFiles,
                          html_files::TrackedFiles,
                          literate_files::TrackedFiles,
                          verb::Bool=false)::Nothing
    # top level files (src/*)
    for file ∈ readdir(PATHS[:src])
        isfile(joinpath(PATHS[:src], file)) || continue
        # skip if it has to be ignored
        file ∈ IGNORE_FILES && continue
        fname, fext = splitext(file)
        fpair = (PATHS[:src] => file)
        if file == "config.md"
            add_if_new_file!(infra_files, fpair, verb)
        elseif fext == ".md"
            add_if_new_file!(md_files, fpair, verb)
        else
            add_if_new_file!(html_files, fpair, verb)
        end
    end
    # pages files (src/pages/*)
    for (root, _, files) ∈ walkdir(PATHS[:src_pages])
        for file ∈ files
            isfile(joinpath(root, file)) || continue
            # skip if it has to be ignored
            file ∈ IGNORE_FILES && continue
            fname, fext = splitext(file)
            fpair = (root => file)
            if fext == ".md"
                add_if_new_file!(md_files, fpair, verb)
            elseif fext == ".html"
                add_if_new_file!(html_files, fpair, verb)
            else
                add_if_new_file!(other_files, fpair, verb)
            end
        end
    end
    # infastructure files (src/_css/* and src/_html_parts/*)
    for d ∈ (:src_css, :src_html), (root, _, files) ∈ walkdir(PATHS[d])
        for file ∈ files
            isfile(joinpath(root, file)) || continue
            fname, fext = splitext(file)
            # skipping files that are not of the type INFRA_FILES
            fext ∉ INFRA_FILES && continue
            add_if_new_file!(infra_files, root=>file, verb)
        end
    end
    # literate script files if any, note that the folder may not exist
    if isdir(PATHS[:literate])
        for (root, _, files) ∈ walkdir(PATHS[:literate])
            for file ∈ files
                isfile(joinpath(root, file)) || continue
                fname, fext = splitext(file)
                # skipping files that are not script file
                fext != ".jl" && continue
                add_if_new_file!(literate_files, root=>file, verb)
            end
        end
    end
    return nothing
end

function _scan_input_dir2!(other_files::TrackedFiles,
                           infra_files::TrackedFiles,
                           md_pages::TrackedFiles,
                           html_pages::TrackedFiles,
                           literate_scripts::TrackedFiles,
                           verb::Bool=false;
                           in_loop::Bool=false)::Nothing
    # go over all files in the website folder
    for (root, _, files) ∈ walkdir(path(:folder))
        for file in files
            # assemble full path (root is an absolute path)
            fpath = joinpath(root, file)
            fpair = root => file
            fext  = splitext(file)[2]

            opts = (fpair, verb, in_loop)

            # early skips
            (!isfile(fpath) || file ∈ IGNORE_FILES) && continue
            # skip over `__site` folder, `.git` and `.github` folder
            startswith(fpath, path(:site)) && continue
            startswith(fpath, joinpath(path(:folder), ".git")) && continue
            # skip over toml files
            fext == ".toml" && continue

            # assets file --> other
            if startswith(fpath, path(:assets))
                add_if_new_file!(other_files, opts...)
            # infra_files
            elseif startswith(fpath, path(:css))    ||
                   startswith(fpath, path(:layout)) ||
                   startswith(fpath, path(:libs))
                add_if_new_file!(infra_files, opts...)
            # literate_files
            elseif startswith(fpath, path(:literate))
                # ignore files that are not script files
                fext == ".jl" || continue
                add_if_new_file!(literate_scripts, opts...)
            else
                if file == "config.md"
                    add_if_new_file!(infra_files, opts...)
                elseif fext == ".md"
                    add_if_new_file!(md_pages, opts...)
                elseif fext ∈ (".html", ".htm")
                    add_if_new_file!(html_pages, opts...)
                else
                    add_if_new_file!(other_files, opts...)
                end
            end
        end
    end
    return nothing
end


"""
Helper function, if `fpair` is not referenced in the dictionary (new file) add
the entry to the dictionary with the time of last modification as val.
"""
function add_if_new_file!(dict::TrackedFiles, fpair::Pair{String,String},
                          verb::Bool, in_loop::Bool=false)::Nothing
    haskey(dict, fpair) && return nothing
    # it's a new file
    verb && println("tracking new file '$(fpair.second)'.")
    # save it's modification time, set to zero if it's a new file in a loop
    # to force its processing in FS2
    dict[fpair] = ifelse(in_loop, 0, mtime(joinpath(fpair...)))
    return nothing
end
