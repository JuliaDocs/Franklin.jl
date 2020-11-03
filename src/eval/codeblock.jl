#=
Functionalities to take a code block and process it.
These functionalities are called from `convert/md_blocks`.
=#

"""
$SIGNATURES

Take a fenced code block and return a tuple with the language, the relative
path (if any) and the code.
"""
function parse_fenced_block(ss::SubString, shortcut=false)::Tuple
    if shortcut
        lang  = locvar(:lang)
        cntr  = locvar(:fd_evalc)
        rpath = "_ceval_$cntr"
        code  = match(CODE_3!_PAT, ss).captures[1]
        set_var!(LOCAL_VARS, "fd_evalc", cntr + 1)
    else
        # cases: (note there's necessarily a lang, see `convert_block`)
        # * ```lang ... ``` where lang can be something like julia-repl
        # * ```lang:path ... ``` where path is a relative path like "this/path"
        # group 1 => lang; group 2 => path; group 3 => code
        reg   = ifelse(startswith(ss, "`````"), CODE_5_PAT, CODE_3_PAT)
        m     = match(reg, ss)
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

    # 1. global setting forcing all pages to reeval
    FD_ENV[:FORCE_REEVAL] && return true

    # 2. local setting forcing the current page to reeval everything
    locvar(:reeval) && return true

    # 3. if space previously marked as stale, return true
    # note that on every page build, this is re-init as false.
    locvar(:fd_eval) && return true

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
function resolve_code_block(ss::SubString; shortcut=false)::String
    # 1. what kind of code is it
    lang, rpath, code = parse_fenced_block(ss, shortcut)
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

    # 2. here we have Julia code, assess whether to run it or not
    # if not, just return the code as a html block
    if should_eval(code, rpath)
        # 3. here we have code that should be (re)evaluated
        # >> retrieve the modulename, the module may not exist
        # (& may not need to)
        modname = modulename(locvar(:fd_rpath))
        # >> check if relevant module exists, otherwise create one
        mod = ismodule(modname) ?
                getfield(Main, Symbol(modname)) :
                newmodule(modname)
        # >> retrieve the code paths
        cp = form_codepaths(rpath)
        # >> write the code to file
        mkpath(cp.script_dir)
        write(cp.script_path, MESSAGE_FILE_GEN_FMD * code)
        # make the output directory available to the code block
        # (see @OUTPUT macro)
        OUT_PATH[] = cp.out_dir
        # >> eval the code in the relevant module (this creates output/)
        res = run_code(mod, code, cp.out_path; strip_code=false)
        # >> write res to file
        # >> this weird thing is to make sure that the proper "show"
        #    is called...
        io = IOBuffer()
        if typeof(res) in (Symbol, Expr)
            show(io, res)
        else
            Core.eval(mod, quote show($io, "text/plain", $res) end)
        end
        write(cp.res_path, take!(io))
        # >> since we've evaluated a code block, toggle scope as stale
        set_var!(LOCAL_VARS, "fd_eval", true)
    end
    # >> finally return as html
    if locvar(:showall) || shortcut
        return html_code(code, lang) *
                reprocess("\\show{$rpath}", [GLOBAL_LXDEFS["\\show"]])
    end
    return html_code(code, lang)
end
