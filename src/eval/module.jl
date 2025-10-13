#=
Functionalities to generate a sandbox module.
=#

"""
$SIGNATURES

Return a sandbox module name corresponding to the page at `fpath`, effectively
`FD_SANDBOX_*` where `*` is a hash of the path.
"""
modulename(fpath::AS) = "FD_SANDBOX_$(hash(fpath))"

"""
$SIGNATURES

Checks whether a name is a defined module.
"""
function ismodule(name::String)::Bool
    s = Symbol(name)
    @invokelatest(isdefined(Main, s)) || return false
    typeof(@invokelatest(getglobal(Main, s))) === Module
end

"""
$SIGNATURES

Creates a new module with a given name, if the module exists, it is wiped.
Discards the warning message that a module is replaced which may otherwise
happen. Return a handle pointing to the module.
"""
function newmodule(name::String)::Module
    mod  = nothing

    mktemp() do _, outf
        # discard the "WARNING: redefining module X"
        redirect_stderr(outf) do
            mod = Core.eval(Main, Meta.parse("""
                module $name
                    import Franklin
                    import Franklin: @OUTPUT, @delay, fdplotly,
                                     locvar, pagevar, globvar,
                                     fd2html, get_url
                    """ * ifelse(startswith(name, "Utils"), "",
                            ifelse(FD_ENV[:UTILS_HASH] === nothing, "", """
                    import $(Franklin.utils_name())
                    """)) * """
                    using Dates
                end
                """))
        end
    end
    return mod
end
