"""
$SIGNATURES

Resolve arguments for `LxObj` by interpolating `#k` appropriately.
"""
function resolve_args(base::AS, braces::Vector{OCBlock})
    res = base
    for (i, brace) in enumerate(braces)
        brace_content = stent(brace)
        # space-sensitive 'unsafe' one
        res = replace(res, "!#$i" => brace_content)
        # space-insensitive 'safe' one (e.g. for things like `\mathbb#1`)
        res = replace(res, "#$i" => " " * brace_content)
    end
    return res
end


"""
$(SIGNATURES)

Take a `<: LxObj` and try to resolve it by looking up the appropriate definition, applying it then
reparsing the result.
"""
function resolve_lxobj(lxo::LxObj, lxdefs::Vector{LxDef};
                       inmath::Bool=false)::String
    # retrieve the definition the environment points to
    lxd = getdef(lxo)
    env = lxo isa LxEnv

    # in case it's defined in Utils or in Franklin
    name = getname(lxo)
    fun  = Symbol(ifelse(env, "env_", "lx_") * name)
    # it will be `nothing` in math mode or when defined in utils
    if isnothing(lxd)
        # check if it's defined in Utils and act accordingly
        if @invokelatest(isdefined(Main, utils_symb())) && @invokelatest(isdefined(utils_module(), fun))
            raw = Core.eval(utils_module(), :($fun($lxo, $lxdefs)))
            return reprocess(raw, lxdefs)
        else
            # let the math backend deal with the string
            return lxo.ss
        end
    end

    # the definition can be empty (which can be on purpose, for internal defs)
    # NOTE: here note that there is NO re-processing. This is inconsistent
    # with the behaviour of the lx_* functions defined in Utils. So for instance
    # the output of lx_label is direct HTML.
    if (!env && isempty(lxd)) || (env && isempty(lxd.first) && isempty(lxd.second))
        name = getname(lxo)
        @invokelatest(isdefined(Franklin, fun)) && return eval(:($fun($lxo, $lxdefs)))
        return ""
    end

    # non-empty cases
    if !env
        partial = resolve_args(lxd, lxo.braces)
    else
        partial  = resolve_args(lxd.first, lxo.braces)
        partial *= content(lxo)
        partial *= resolve_args(lxd.second, lxo.braces)
    end

    # if 'inmath' surround accordingly so that this information is preserved
    inmath && (partial = mathenv(partial))

    return reprocess(partial, lxdefs)
end


"""
$SIGNATURES

Convenience function to take a markdown string (e.g. produced by a latex command) and re-parse it.
"""
function reprocess(s::AS, lxdefs::Vector{<:LxDef}; nostripp=false)
    r = convert_md(s, lxdefs;
                   isrecursive=true, isconfig=false, has_mddefs=false,
                   nostripp=nostripp)
    return r
end
