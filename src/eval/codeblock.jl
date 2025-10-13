#=
Functionalities to take a code block and process it.
These functionalities are called from `convert/md_blocks`.
=#

"""
$SIGNATURES

Take a fenced code block and return a tuple with the language, the relative
path (if any) and the code.
"""
function parse_fenced_block(ss::SubString, scut=false; shortcut=scut, # scut for legacy #1037
            repl=false, shell=false, pkg=false, help=false)::Tuple

    if any((shortcut, repl, shell, pkg, help))
        lang  = locvar(:lang)::String
        cntr  = locvar(:fd_evalc)::Int
        rpath = "_ceval_$cntr"
        code  = match(CODE_3!_PAT, ss).captures[1]
        set_var!(LOCAL_VARS, "fd_evalc", cntr + 1)
    else
        # cases: (note there's necessarily a lang, see `convert_block`)
        # * ```lang ... ``` where lang can be something like julia-repl
        # * ```lang:path ... ``` where path is a relative path like "this/path"
        # group 1 => lang; group 2 => path; group 3 => code
        reg = startswith(ss, "`````") ? CODE_5_PAT :
              startswith(ss, "````")  ? CODE_4_PAT : CODE_3_PAT
        m     = match(reg, ss)
        if m === nothing
            throw(ArgumentError("Could not match codeblock:\n$ss"))
        end
        lang  = m.captures[1]
        rpath = m.captures[2]
        code  = strip(m.captures[3])
        rpath === nothing || (rpath = rpath[2:end]) # ignore starting `:`
    end
    return lang, rpath, code
end

"""
$SIGNATURES

Return true if the code should be reevaluated and false otherwise.
The code should be reevaluated if any of following flags are true:

1. global eval flag (`eval_all`)
1. local eval flag (`reeval`)
1. stale scope (due to a prior code block having been evaluated)
1. the code is different than what's in the script
1. the output is missings
"""
function should_eval(code::AS, rpath::AS)
    # 0. the page is currently delayed, skip evals
    isdelayed() && return false

    # 0b. force no eval
    locvar(:noeval)::Bool && return false

    # 1. global setting forcing all pages to reeval
    FD_ENV[:FORCE_REEVAL] && return true

    # 2. local setting forcing the current page to reeval everything
    locvar(:reeval)::Bool && return true

    # 3. if space previously marked as stale, return true
    # note that on every page build, this is re-init as false.
    locvar(:fd_eval)::Bool && return true

    # 4. if the code has changed reeval
    cp = form_codepaths(rpath)
    # >> does the script exist?

    isfile(cp.script_path) || return true
    # >> does the script match the code?
    MESSAGE_FILE_GEN_FMD * code == read(cp.script_path, String) || return true

    # 5. if the outputs aren't there, reeval
    # >> does the output dir exist
    isdir(cp.out_dir) || return true
    # >> do the output files exist?
    all(isfile, (cp.out_path, cp.res_path)) || return true

    # otherwise don't reeval
    return false
end

"""
$SIGNATURES

Helper function to process the content of a code block.
Return the html corresponding to the code block, possibly after having
evaluated the code.
"""
function resolve_code_block(
            ss::SubString;
            shortcut=false,
            repl=false,
            pkg=false,
            shell=false,
            help=false
        )::String
    # 1. what kind of code is it
    lang, rpath, code = parse_fenced_block(ss; shortcut, repl, pkg, shell, help)
    # 1.a if no rpath is given, code should not be evaluated
    isnothing(rpath) && return html_code(code, lang)
    # 1.b if not julia code, eval is not supported
    if lang != "julia"
        print_warning("""
            Evaluation of non-Julia code blocks is not yet supported.
            \nRelevant pointers:
            $POINTER_EVAL
            """)
        return html_code(code, lang)
    end

    # NOTE: in future if support direct eval of code in other
    # languages, can't do the module trick so will need to keep track
    # of that virtually. There will need to be a branching over lang=="julia"
    # vs rest here.
    repl_code_chunks = Pair{String,String}[]

    # 2. here we have Julia code, assess whether to run it or not
    # if not, just return the code as a html block
    if any((shortcut, repl, shell, help, pkg)) || should_eval(code, rpath)
        # 3. here we have code that should be (re)evaluated
        # >> retrieve the modulename, the module may not exist
        # (& may not need to)
        modname = modulename(locvar(:fd_rpath)::String)
        # >> check if relevant module exists, otherwise create one
        mod = ismodule(modname) ?
                @invokelatest(getglobal(Main, Symbol(modname))) :
                newmodule(modname)

        # >> retrieve the code paths
        cp = form_codepaths(rpath)
        # >> write the code to file
        mkpath(cp.script_dir)
        write(cp.script_path, MESSAGE_FILE_GEN_FMD * code)
        # make the output directory available to the code block
        # (see @OUTPUT macro)
        OUT_PATH[] = cp.out_dir
        bk  = pwd()
        out = ifelse(locvar(:auto_code_path)::Bool, cp.out_dir, bk)
        isdir(out) || mkpath(out)
        cd(out)

        if repl
            # imitating https://github.com/JuliaLang/julia/blob/fe2eeadc0b382508bef7e77ab517789ea844e708/stdlib/REPL/src/REPL.jl#L429-L430
            chunk_code = ""
            chunk_ast = nothing
            for line in split(code, r"\r?\n", keepempty=false)
                chunk_code *= line * "\n"
                chunk_ast   = Base.parse_input_line(chunk_code)
                if (isa(chunk_ast, Expr) && chunk_ast.head === :incomplete)
                    continue
                else
                    # we have a complete chunk of code
                    # >> eval the code in the relevant module (this creates output/)
                    res = run_code(mod, chunk_code, cp.out_path; strip_code=false)
                    cd(bk)
                    # >> write res to string (see further down)
                    io = IOBuffer()
                    Core.eval(mod, quote show($(io), "text/plain", $(QuoteNode(res))) end)
                    stdout_str = read(cp.out_path, String)
                    res_str = String(take!(io))
                    res_str = ifelse(res_str == "nothing", "", res_str * "\n")
                    push!(repl_code_chunks,
                        chunk_code => stdout_str * res_str
                    )
                    # reset for the next chunk
                    chunk_code = ""
                    chunk_ast = nothing
                end
            end

        # NOTE: shell, pkg, and help mode are currently fairly rudimentary
        # and should be considered experimental

        elseif shell
            for line in split(code, '\n', keepempty=false)
                a = tempname()
                open(a, "w") do outf
                    redirect_stdout(outf) do
                        redirect_stderr(outf) do
                            Base.repl_cmd(Cmd(string.(split(line))), nothing)
                        end
                    end
                end
                push!(repl_code_chunks,
                    line => String(strip(read(a, String))) * "\n"
                )
            end

        elseif pkg
            for line in split(code, '\n', keepempty=false)
                a = tempname()
                pname = splitpath(Pkg.project().path)[end-1]
                open(a, "w") do outf
                    redirect_stdout(outf) do
                        redirect_stderr(outf) do
                            Pkg.REPLMode.pkgstr(string(line))
                        end
                    end
                end
                push!(repl_code_chunks,
                    "($(pname)) pkg> " * line => String(strip(read(a, String))) * "\n"
                )
            end

        elseif help
            # NOTE: this is pretty crap there should be a better way to just
            # reproduce what `?` but the code for the Docs module is opaque to me.
            r = eval(Meta.parse("@doc $code"))
            push!(repl_code_chunks,
                code => replace(Markdown.html(r),
                    r"\<a href=\"@ref(.*?)\"\>" => "",
                    "</code></a>" => "</code>",
                    "language-jldoctest" => "language-julia-repl",
                    "<pre><code>" => "<pre><code class=\"language-julia\">"
                )
            )

        else
            # >> eval the code in the relevant module (this creates output/)
            res = run_code(mod, code, cp.out_path; strip_code=false)
            cd(bk)
            # >> write res to file
            # >> this weird thing with QuoteNode is to make sure that the proper
            #    "show" method is called...
            io = IOBuffer()
            Core.eval(mod, quote show($(io), "text/plain", $(QuoteNode(res))) end)
            write(cp.res_path, take!(io))
        end
        # >> since we've evaluated a code block, toggle scope as stale
        set_var!(LOCAL_VARS, "fd_eval", true)
    end
    # >> finally return as html either with or without output
    # --- with
    if any((repl, shell, help, pkg))
        s = repl ? :repl : shell ? :shell : help ? :help : :pkg
        return html_repl_code(repl_code_chunks, s)

    elseif shortcut || locvar(:showall)::Bool
        return html_code(code, lang) *
                reprocess("\\show{$rpath}", [GLOBAL_LXDEFS["\\show"]])
    end
    # --- without
    return html_code(code, lang)
end
