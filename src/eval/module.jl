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
    isdefined(Main, s) || return false
    typeof(getfield(Main, s)) === Module
end

"""
$SIGNATURES

Creates a new module with a given name, if the module exists, it is wiped.
Discards the warning message that a module is replaced which may otherwise
happen. Return a handle pointing to the module.
"""
function newmodule(name::String)::Module
    mod  = nothing
    junk = tempname()
    open(junk, "w") do outf
        # discard the "WARNING: redefining module X"
        redirect_stderr(outf) do
            mod = Core.eval(Main, Meta.parse("""
                module $name
                    import Franklin: @OUTPUT, fdplotly
                end
                """))
        end
    end
    return mod
end
