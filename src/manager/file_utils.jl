"""
$(SIGNATURES)

Checks for a `config.md` file and uses it to set the global variables
referenced in `GLOBAL_VARS` it also sets the global latex commands via
`GLOBAL_LXDEFS`. If the configuration file is not found a warning is shown.
The keyword `init` is used internally to distinguish between the first call
where only structural variables are considered (e.g. controlling folder
structure).
"""
function process_config()::Nothing
    FD_ENV[:SOURCE] = "config.md"
    config_path = joinpath(FOLDER_PATH[], "config.md")
    if isfile(config_path)
        convert_md(read(config_path, String); isconfig=true)
    else
        config_warn()
    end
    return nothing
end

"""
$(SIGNATURES)

Checks for a `utils.jl` file and uses it to set global computed variables,
functions and html functions. Whatever is defined in `utils.jl` takes
precedence over things defined internally in Franklin or in the global vars;
in particular users can redefine the behaviour of `hfuns` though that's not
recommended.
"""
function process_utils()
    FD_ENV[:SOURCE] = "utils.jl"
    utils = joinpath(FOLDER_PATH[], "utils.jl")
    isfile(utils) || return nothing
    # wipe / create module Utils
    newmodule("Utils")
    Base.include(Main.Utils, utils)
    # keep track of utils names
    ns = String.(names(Main.Utils, all=true))
    filter!(n -> n[1] != '#' && n ∉ ("eval", "include", "Utils"), ns)
    empty!(UTILS_NAMES)
    append!(UTILS_NAMES, ns)
    return nothing
end


"""
$(SIGNATURES)

See [`process_file_err`](@ref).
"""
function process_file(case::Symbol, fpair::Pair{String,String}, args...)::Int
    if FD_ENV[:DEBUG_MODE]
        process_file_err(case, fpair, args...)
        return 0
    end

    try
        process_file_err(case, fpair, args...)
    catch err
        rp = fpair.first
        rp = rp[end-min(20, length(rp))+1 : end]
        if !FD_ENV[:QUIET_TEST]
            FD_ENV[:SOURCE] = fpair.second
            print_warning("""
                Encountered an issue processing '$(fpair.second)' in $rp.
                Verify, then re-start the Franklin server.
                The error is displayed below:
                $err
                """)
        end
        FD_ENV[:SUPPRESS_ERR] || throw(err)
        return -1
    end
    return 0
end


"""
$(SIGNATURES)

Considers a source file which, depending on `case` could be a HTML file or a
file in Franklin-Markdown etc, located in a place described by `fpair`,
processes it by converting it and adding appropriate header and footer and
writes it to the appropriate place. It can throw an error which will be
caught in `process_file(args...)`.
"""
function process_file_err(case::Symbol, fpair::Pair{String, String},
                          head::AS="", pgfoot::AS="", foot::AS="",
                          t::Float64=0.0)::Nothing
    # depending on the file extension, either full process (.md), partial
    # process (.html) or no process (everything else)
    inp  = joinpath(fpair...)
    outp = form_output_path(fpair.first, fpair.second, case)
    if case == :md
        FD_ENV[:SOURCE] = get_rpath(inp)
        convert_and_write(fpair..., head, pgfoot, foot, outp)
    elseif case == :html
        FD_ENV[:SOURCE] = get_rpath(inp)
        set_cur_rpath(joinpath(fpair...))
        set_page_env()
        raw_html  = read(inp, String)
        # add the item *before* the conversion so that the conversion
        # can affect the page itself with {{...}}
        cond_add = globvar(:generate_sitemap) && FD_ENV[:FULL_PASS]
        cond_add && add_sitemap_item(html=true)
        proc_html = convert_html(raw_html) |> postprocess_page
        write(outp, proc_html)
    else # case in (:other, :infra)
        # there's a bunch of thing we don't want to copy over
        if startswith(inp, path(:layout))   ||
            startswith(inp, path(:literate)) ||
            endswith(inp, "config.md") ||
            endswith(inp, "search.md")
            # skip
            @goto end_copyblock
        end
        # NOTE: some processing may be added here later on (e.g. parsing of
        # CSS files). Only copy again if necessary (file is not there or
        # has changed)
        if !isfile(outp) || (mtime(outp) < t && !filecmp(inp, outp))
            cp(inp, outp, force=true)
        end
        @label end_copyblock
    end
    FD_ENV[:SOURCE] = ""
    FD_ENV[:FULL_PASS] || FD_ENV[:SILENT_MODE] || rprint("→ page updated [✓]")
    return nothing
end


"""
$(SIGNATURES)

Convenience function to replace the extension of a filename with another.
"""
change_ext(fname::AS, ext=".html")::String = splitext(fname)[1] * ext


"""
    get_rpath(fpath)

Extracts the relative file system path out of the full system path to a file
currently being processed. Does not start with a path separator.
So `[some_fs_path]/blog/page.md` --> `blog/page.md` (keeps the extension).
"""
function get_rpath(fpath::String)
    root = path(:folder)
    return fpath[lastindex(root)+length(PATH_SEP)+1:end]
end

"""
    set_cur_rpath(fpath)

Takes the path to the current file and sets the `fd_rpath` local page variable
as well as the `FD_ENV[:CUR_PATH]` variable (used for conditional blocks
depending on URL for instance).
"""
function set_cur_rpath(fpath::String; isrelative::Bool=false)
    if isrelative
        rpath = fpath
    else
        rpath = get_rpath(fpath)
    end
    FD_ENV[:CUR_PATH] = rpath
    set_var!(LOCAL_VARS, "fd_rpath", rpath)
    return nothing
end
