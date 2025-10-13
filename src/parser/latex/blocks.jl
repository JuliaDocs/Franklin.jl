"""
$(SIGNATURES)

Find `\\newcommand` and `\\newenvironment` elements and try to parse what
follows to form a proper Latex command/environment.
Return a list of such elements.

The format is:

    \\newcommand{\\NAME}[NARGS]{DEFINITION}
    \\newenvironment{NAMING}[NARGS]{PRE}{POST}

where [NARGS] is optional.
"""
function find_lxdefs(tokens::Vector{Token}, blocks::Vector{OCBlock})
    # container for definitions
    lxdefs  = Vector{LxDef}()
    # find braces `{` and `}`
    braces  = filter(β -> β.name == :LXB, blocks)
    nbraces = length(braces)
    # keep track of active tokens
    active_tokens = ones(Bool, length(tokens))
    active_blocks = ones(Bool, length(blocks))

    # go over active tokens, stop over the ones that indicate a newcommand
    # or a newenvironment, deactivate the tokens that are within the scope
    # of the definition of the command/environment
    for (i, τ) ∈ enumerate(tokens)
        # skip inactive tokens
        active_tokens[i] || continue
        # look for tokens that indicate a new[com\env]
        τ.name in (:LX_NEWCOMMAND, :LX_NEWENVIRONMENT) || continue
        case = ifelse(τ.name == :LX_NEWCOMMAND, :com, :env)

        # find first brace blocks after the newX (naming)
        fromτ = from(τ)
        k = findfirst(β -> (fromτ < from(β)), braces)

        if case == :com
            # there must be two brace blocks after the newcommand (name, def)
            if isnothing(k) || !(1 <= k < nbraces)
                throw(LxDefError(
                    "Ill formed newcommand (needs two {...})"))
            end
        else
            # there must be three brace blocks after the newenvironment
            if isnothing(k) || !(1 <= k < nbraces - 1)
                throw(LxDefError(
                    "Ill formed newenvironment (needs three {...})"))
            end
        end

        # try to find a number of arg between the two first {...} to see
        # if it may contain something which we'll try to interpret as [.d.]
        rge    = (to(braces[k])+1):(from(braces[k+1])-1)
        lxnarg = 0
        # it found something between the naming brace and the 1st def brace
        # check if it looks like [.d.] where d is a number and . are
        # optional spaces (specification of the number of arguments)
        # see the regex pattern LX_NARG_PAT
        if !isempty(rge)
            inter  = subs(str(braces[k]), rge)
            lxnarg = match(LX_NARG_PAT, inter)
            # see test/utils/errors for examples
            if isnothing(lxnarg.captures[1])
                sinner = strip(inter)
                if !isempty(sinner)
                    # corner case: {...}[ ]{...} (empty)
                    if isnothing(match(r"\[\s*\]", sinner))
                        throw(LxDefError("""
                            Ill formed new(command|environment), the indication
                            for the number of arguments could not be read.
                            Expected '[x]' where 'x' is a number."""))
                    end
                end
            end
            matched = lxnarg.captures[2]
            lxnarg  = isnothing(matched) ? 0 : parse(Int, matched)
        end

        # assign naming / def
        naming_braces = braces[k]
        matched = match(LX_NAME_PAT, content(naming_braces))
        # >>> case 1: newcommand
        if case == :com
            if isnothing(matched) || !startswith(matched.captures[1], '\\')
                throw(LxDefError("""
                    Invalid naming in a newcommand, expected a command name of
                    the form `\\command`."""))
            end
            lxname          = string(matched.captures[1])
            defining_braces = braces[k+1] # valid bc of previous check
            # recover the definition + span
            lx_def = stent(defining_braces)
            to_def = to(defining_braces)
            # store the new command
            push!(lxdefs, LxDef(lxname, lxnarg, lx_def, fromτ, to_def))
        # >>> case 2: newenvironment
        else
            if isnothing(matched) || startswith(matched.captures[1], '\\')
                throw(LxDefError("""
                    Invalid naming in a newenvironment, expected an environment
                    name form `command`."""))
            end
            lxname      = string(matched.captures[1])
            pre_braces  = braces[k+1]
            post_braces = braces[k+2] # both valid due to earlier check
            # extract defs
            pre_def  = stent(pre_braces)
            post_def = stent(post_braces)
            to_def   = to(post_braces)
            # store the new env
            push!(lxdefs, LxDef(lxname, lxnarg, pre_def => post_def,
                                fromτ, to_def))
        end
        # mark any active token in the span as inactive
        first_after = findfirst(t -> (from(t) > to_def), tokens[i+1:end])
        if isnothing(first_after)
            active_tokens[i:end] .= false
        else
            active_tokens[i:(i+first_after-1)] .= false
        end
    end # of enumeration of tokens

    # filter out the stuff that's now marked as inactive by virtue of being
    # part of a newX definition (these things will be inspected later)
    tokens = tokens[active_tokens]
    blocks = blocks[active_blocks]

    # separate the braces from the rest of the blocks, they will be used
    # to define the lxcoms
    braces_mask = map(β -> β.name == :LXB, blocks)
    braces = blocks[braces_mask]
    blocks = blocks[@. ~braces_mask]

    return lxdefs, tokens, braces, blocks
end

"""
$(SIGNATURES)

Get the reference pointing to a `LxDef` corresponding to a given `lxname`.
If no reference is found but `inmath=true`, we propagate and let KaTeX deal
with it. If something is found, the reference is returned and will be accessed
further down.
The boolean that is also returned helps keeps track of whether the command or
environment was defined in the utils.
"""
function get_lxdef_ref(lxname::SubString, lxdefs::Vector{LxDef},
                       inmath::Bool=false, offset::Int=0; isenv=false
                       )::Tuple{Ref,Bool}
    # find lxdefs with matching name
    ks = findall(δ -> (δ.name == lxname), lxdefs)

    # check that the def is before the usage
    fromlx = from(lxname) + offset
    filter!(k -> (fromlx > from(lxdefs[k])), ks)

    # if no definition is found, there are three possibilities:
    #  1. there is a Utils definition
    #  2. we're in math, let the math engine deal with it
    #  3. throw an error
    if isempty(ks)
        # check if defined in utils
        if @invokelatest isdefined(Main, utils_symb())
            # env def 'env_***'
            flag = isenv && @invokelatest isdefined(utils_module(), Symbol("env_$(lxname)"))
            # com def 'lx_***'
            flag |= @invokelatest isdefined(utils_module(), Symbol("lx_$(lxname[2:end])"))
            flag && return (Ref(nothing), true)
        end
        # if we're here, and in math mode, let the math engine deal with it
        inmath && return (Ref(nothing), false)
        # otherwise throw an error
        throw(LxObjError("""
            Command or environment '$lxname' was used before it was
            defined."""))
    end
    return (Ref(lxdefs, ks[end]), false)
end

"""
$(SIGNATURES)

For a command or an environment, find the arguments (i.e. a sequence of braces
immediately after the opening token).
"""
function find_opts_braces(τ::Token, narg::Int, braces::Vector{OCBlock}, name="")
    # spot where an opening brace is expected, note that we can use exact
    # char algebra here because we know that the last character is '}' w length 1.
    nxtidx = to(τ) + 1
    # try to find one at that place
    b1_idx = findfirst(β -> (from(β) == nxtidx), braces)
    # --> it needs to exist + there should be enough braces left for the options
    if isnothing(b1_idx) || (b1_idx + narg - 1 > length(braces))
        throw(LxObjError("""
            Command/Environment '$name' expects $narg argument(s) and there
            should be no space(s) between the command name and the first brace:
            \\com{arg1}... or \\begin{env}{arg1}...
            """))
    end
    # --> examine candidate braces, there should be no spaces between
    # braces to avoid ambiguities
    cand_braces = braces[b1_idx:b1_idx+narg-1]
    for bidx ∈ 1:narg-1
        if (to(cand_braces[bidx]) + 1 != from(cand_braces[bidx+1]))
            throw(LxObjError("""
                Argument braces should not be separated by space(s):
                \\com{arg1}{arg2}... Verify a '$name' command/environment.
                """))
        end
    end
    # If we get here then we have candidate braces that match the number
    # required which we can just return
    return cand_braces
end


function find_opts_braces_math(τ::Token, narg::Int, braces::Vector{OCBlock}, name="")
    cand_braces_idx = Int[]
    # spot where an opening brace is expected, note that we can use exact
    # char algebra here because we know that the last character is '}' w length 1.
    nxtidx = to(τ) + 1
    for i ∈ 1:narg
        b_i_idx = findfirst(β -> (from(β) == nxtidx), braces)
        # --> it needs to exist
        if isnothing(b_i_idx)
            throw(LxObjError("""
                Command/Environment '$name' expects $narg argument(s) and there
                should be no space(s) between the command name and the first brace:
                \\com{arg1}... or \\begin{env}{arg1}...
                """))
        end
        push!(cand_braces_idx, b_i_idx)
        nxtidx = to(braces[cand_braces_idx[end]]) + 1
    end
    # If we get here then we have candidate braces that match the number
    # required which we can just return
    return braces[cand_braces_idx]
end


"""
$(SIGNATURES)

Find `\\command{arg1}{arg2}...` outside of `xblocks` and `lxdefs`.
"""
function find_lxcoms(tokens::Vector{Token}, lxdefs::Vector{LxDef},
                     braces::Vector{OCBlock}, offset::Int=0;
                     inmath::Bool=false)::Tuple{Vector{LxCom}, Vector{Token}}
    # containers for the lxcoms
    lxcoms   = Vector{LxCom}()
    active_τ = ones(Bool, length(tokens))
    nbraces  = length(braces)

    # go over tokens, stop over the ones that indicate a command
    for (i, τ) ∈ enumerate(tokens)
        active_τ[i] || continue
        τ.name == :LX_COMMAND || continue

        # 1. look for the definition given the command name
        lxname = τ.ss
        lxdefref, utils = get_lxdef_ref(lxname, lxdefs, inmath, offset)

        (:find_lxcoms, "lxname: '$lxname'") |> logger
        (:find_lxcoms, "utils: '$utils'") |> logger

        if utils
            # custom command defined in utils, take a single bracket
            lxnarg = 1
        elseif isnothing(lxdefref[])
            # unrecognised command in math mode, defer to backend
            continue
        else
            lxnarg = getindex(lxdefref).narg
        end

        (:find_lxcoms, "lxnarg: '$lxnarg'") |> logger
        (:find_lxcoms, "braces: '$(content.(braces))'") |> logger

        # 2. explore with # arguments
        # >> no arguments
        if lxnarg == 0
            push!(lxcoms, LxCom(lxname, lxdefref))
            active_τ[i] = false
        # >> there is at least one argument --> find all of them
        else
            if inmath
                arg_braces = find_opts_braces_math(τ, lxnarg, braces, lxname)
            else
                arg_braces = find_opts_braces(τ, lxnarg, braces, lxname)
            end
            # all good, can push it
            from_c = from(τ)
            to_c   = to(arg_braces[end])
            str_c  = subs(str(τ), from_c, to_c)

            if utils
                push!(lxcoms, LxCom(str_c, nothing, arg_braces))
            else
                push!(lxcoms, LxCom(str_c, lxdefref, arg_braces))
            end

            # deactivate tokens in the span of the command (will be reprocessed
            # later on)
            first_after = findfirst(τ -> (from(τ) > to_c), tokens[i+1:end])
            if isnothing(first_after)
                active_τ[i+1:end] .= false
            elseif first_after > 1
                active_τ[i+1:(i+first_after-1)] .= false
            end
        end
    end
    return lxcoms, tokens[active_τ]
end


"""
$(SIGNATURES)

Find `\\begin{xxx}` and `\\end{xxx}` blocks.
"""
function find_lxenv_delims!(tokens::Vector{Token}, blocks::Vector{OCBlock})
    rmidx = Int[]
    for (i, τ) ∈ enumerate(tokens)
        τ.name ∈ (:CAND_LX_BEGIN, :CAND_LX_END) || continue
        # try to get an adjoining brace
        nxtidx = to(τ) + 1
        braceidx = findfirst(β -> (β.name == :LXB && from(β) == nxtidx), blocks)
        # it needs to exist
        if isnothing(braceidx)
            throw(LxObjError("""
                Found a delimiter '\\begin' or '\\end' and expected a name in braces
                after that but didn't find it. There should be no space between the
                delimiter and the brace: \\begin{name}.
                """))
        end
        push!(rmidx, braceidx)
        # get the brace
        brace = blocks[braceidx]
        # form a valid token and replace the candidate by it
        from_c = from(τ)
        to_c = to(brace)
        name = ifelse(τ.name == :CAND_LX_BEGIN, :LX_BEGIN, :LX_END)
        tokens[i] = Token(name, subs(τ.ss.string, from_c, to_c))
    end
    deleteat!(blocks, rmidx)
    return nothing
end

"""
$SIGNATURES

Find active environment blocks between an opening and matching closing
delimiter. These can be nested. See also `find_ocblocks` and `find_lxcoms`,
this is essentially a mix of the two.
"""
function find_lxenvs(tokens::Vector{Token}, lxdefs::Vector{LxDef},
                     braces::Vector{OCBlock}, offset::Int=0;
                     inmath=false)::Tuple{Vector{LxEnv}, Vector{Token}}
    # containers for the lxenvs
    lxenvs   = Vector{LxEnv}()
    active_τ = ones(Bool, length(tokens))
    nbraces  = length(braces)
    ntokens  = length(tokens)

    for (i, τ) ∈ enumerate(tokens)
        # only consider active and opening tokens
        active_τ[i] || continue
        τ.name == :LX_BEGIN || continue

        # 1. extract the environment name and find the definition
        env_name        = envname(τ)
        lxdefref, utils = get_lxdef_ref(env_name, lxdefs, inmath, offset; isenv=true)
        if utils
            # custom env defined in utils, take a single bracket
            lxnarg = 1
        elseif isnothing(lxdefref[])
            # unrecognised environment in math mode, defer to backend
            continue
        else
            lxnarg = getindex(lxdefref).narg
        end

        # 2. explore with # argument
        # >> no arguments
        if lxnarg == 0
            arg_braces = Vector{OCBlock}()
        # >> at least one argument
        else
            if inmath
                arg_braces = find_opts_braces_math(τ, lxnarg, braces, env_name)
            else
                arg_braces = find_opts_braces(τ, lxnarg, braces, env_name)
            end
        end

        # 3. find closing delimiter
        # find the closing token \end{$env_name}
        # note that the braces are not tokens anymore as they're already in OCB
        inbalance = 1
        j = i
        while !iszero(inbalance) && (j < ntokens)
            j += 1
            inbalance += envbalance(tokens[j], env_name)
        end
        if inbalance > 0
            throw(OCBlockError(
                "I found at least one opening delimiter '\\begin{$env_name}' " *
                "that is not closed properly.", context(τ)))
        end
        # Construct and store the LxEnv
        push!(lxenvs,
              LxEnv(
                subs(str(τ), from(τ), to(tokens[j])), # string of the whole env
                ifelse(utils, nothing, lxdefref),     # def (none for custom)
                arg_braces, τ => tokens[j]            # args + delims
                )
             )

        # Mark all tokens in the span of the env as inactive (reproc later)
        active_τ[i:j] .= false
    end
    return lxenvs, tokens[active_τ]
end
