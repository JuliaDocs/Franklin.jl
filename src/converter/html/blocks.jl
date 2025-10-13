"""
$SIGNATURES

Recursively process a conditional block from an opening HTML_COND_OPEN to a
{{end}}.
"""
function process_html_cond(hs::AS, qblocks::Vector{AbstractBlock},
                           i::Int)::Tuple{String,Int,Int}
    if i == length(qblocks)
        throw(HTMLBlockError("Could not close the conditional block " *
                             "starting with '$(qblocks[i].ss)'."))
    end

    init_idx      = i
    else_idx      = 0
    elseif_idx    = Vector{Int}()
    accept_elseif = true # false as soon as we see an else block
    content       = ""

    # inbalance keeps track of whether we've managed to find a
    # matching {{end}}. It increases if it sees other opening {{if..}}
    # and decreases if it sees a {{end}}
    inbalance = 1
    probe = qblocks[i] # just for allocation
    while i < length(qblocks) && inbalance > 0
        i    += 1
        probe = qblocks[i]
        # if we have a {{elseif ...}} or {{else}} with the right level,
        # keep track of them
        if inbalance == 1
            if probe isa HElseIf
                accept_elseif || throw(HTMLBlockError("Saw a {{elseif ...}} " *
                                            "after a {{else}} block."))
                push!(elseif_idx, i)
            elseif probe isa HElse
                else_idx      = i
                accept_elseif = false
            end
        end
        inbalance += hbalance(probe)
    end
    # we've exhausted the candidate qblocks and not found an appropriate {{end}}
    if inbalance > 0
        throw(HTMLBlockError("Could not close the conditional block " *
                             "starting with '$(qblocks[init_idx].ss)'."))
    end

    # we've found the closing {{end}} at index `i`
    β_close = probe
    i_close = i

    # We now have a complete conditional block with possibly
    # several else-if blocks and possibly an else block.
    # Check which one applies and discard the rest

    k   = 0 # index of the first verified condition
    lag = 0 # aux var to distinguish 1st block case

    # initial block may be {{if..}} or {{isdef..}} or...
    # if its not just a {{if...}}, need to act appropriately
    # and if the condition is verified then k=1
    βi = qblocks[init_idx]
    if βi isa HTML_OPEN_COND_SP
        lag = 1
        if !(βi isa Union{HIsPage, HIsNotPage})
            k = haskey(LOCAL_VARS, βi.vname)
            if βi isa Union{HIsDef, HIsNotDef}
                k ⊻= βi isa HIsNotDef
            elseif βi isa Union{HIsEmpty, HIsNotEmpty}
                v = locvar(βi.vname)
                e = _isemptyvar(v)
                k = ifelse(βi isa HIsEmpty, e, !e)
            end
        else
            # HIsPage//HIsNotPage
            rpath = splitext(unixify(locvar(:fd_rpath)::String))[1]
            # are we currently on a tag page?
            if !isempty(locvar(:fd_tag)::String)
                tag = locvar(:fd_tag)::String
                rpath = "/tag/$tag/"
            end

            # compare with β.pages
            inpage = any(p -> match_url(rpath, p), βi.pages)
            k = ifelse(βi isa HIsPage, inpage, !inpage)
        end
        k = Int(k) # either 0 (not found) or 1 (found and first)
    end

    # If we've not yet found a verified condition, keep looking
    # Now all cond blocks ahead are {{if ...}} {{elseif  ...}}
    if iszero(k)
        if lag == 0
            conds = [βi.vname, (qblocks[c].vname for c in elseif_idx)...]
        else
            conds = [qblocks[c].vname for c in elseif_idx]
        end
        known = [haskey(LOCAL_VARS, c) for c in conds]

        if !all(known)
            idx = findfirst(.!known)
            throw(HTMLBlockError("At least one of the condition variable " *
                                 "could not be found: check '$(conds[idx])'."))
        end
        # check that all these variables are bool
        bools = [isa(locvar(c), Bool) for c  in conds]
        if !all(bools)
            idx = findfirst(.!bools)
            throw(HTMLBlockError("At least one of the condition variable is " *
                                 " not a Bool: check '$(conds[idx])'."))
        end
        # which one is verified?
        u = findfirst(c -> locvar(c)::Bool, conds)
        k = isnothing(u) ? 0 : u + lag
    end

    if iszero(k)
        # if we still haven't found a verified condition, use the else
        # if there is one
        if !iszero(else_idx)
            # use elseblock, the content is from it to the β_close
            head = nextind(hs, to(qblocks[else_idx]))
            tail = prevind(hs, from(β_close))
            # get the stack of blocks in there
            action_qblocks = qblocks[else_idx+1:i_close-1]
            # process
            content = process_html_qblocks(hs, action_qblocks, head, tail)
        end
    else
        # determine the span of blocks
        oidx = 0 # opening conditional
        cidx = 0 # closing conditional
        if k == 1
            oidx = init_idx
        else
            oidx = elseif_idx[k-1]
        end
        if k ≤ length(elseif_idx)
            cidx = elseif_idx[k]
        else
            cidx = ifelse(iszero(else_idx), i_close, else_idx)
        end
        # Get the content
        head = nextind(hs, to(qblocks[oidx]))
        tail = prevind(hs, from(qblocks[cidx]))
        # Get the stack of blocks in there
        action_qblocks = qblocks[oidx+1:cidx-1]
        # process
        content = process_html_qblocks(hs, action_qblocks, head, tail)
    end
    # move the head after the final {{end}}
    head = nextind(hs, to(β_close))

    return content, head, i_close
end

# used for the HIsEmpty, HIsNotEmpty
_isemptyvar(v::T) where T = hasmethod(isempty, (T,)) ? isempty(v) : false
_isemptyvar(::Nothing)    = true
_isemptyvar(v::Date)      = (v == Date(1,1,1))


"""
$SIGNATURES

Process a for block (for a variable iterate).
"""
function process_html_for(hs::AS, qblocks::Vector{AbstractBlock},
                          i::Int)::Tuple{String,Int,Int}
    # check that the iterable is known
    β_open  = qblocks[i]
    vname   = β_open.vname # x or (x, v)
    iname   = β_open.iname # var
    content = ""

    if iname ∉ UTILS_NAMES && !haskey(LOCAL_VARS, iname)
        throw(HTMLBlockError(
            "The iterable '$iname' is not recognised. " *
            "Please make sure it's defined."))
    end
    if iname ∈ UTILS_NAMES # can only happen if Utils is defined.
        iter = @invokelatest getglobal(utils_module(), Symbol(iname))
    else
        iter = locvar(iname)
    end

    i_close, β_close = get_for_body(i, qblocks)
    isempty(iter) && @goto final_step

    # is vname a single variable or multiple variables?
    # --> {{for v in iterate}}
    # --> {{for (v1, v2) in iterate }}   (unpacking)
    vnames = [vname]
    if startswith(vname, "(")
        vnames = strip.(split(vname[2:end-1], ","))
    end
    # check that the first element of the iterate has the same length
    el1 = first(iter)
    length(vnames) in (1, length(el1)) ||
        throw(HTMLBlockError("In a {{for ...}}, the first element of " *
                "the iterate has length $(length(el1)) but tried to unpack " *
                "it as $(length(vnames)) variables."))

    # so now basically we have to simply copy-paste the content replacing
    # variable `vname` when it appears in a html block {{...}}
    # users should try not to be dumb about this... if vname or iname
    # corresponds to something they shouldn't touch, they'll crash things.

    # content of the for block
    inner = subs(hs, nextind(hs, to(β_open)), prevind(hs, from(β_close)))
    content = ""
    isempty(strip(inner)) && @goto final_step
    if length(vnames) == 1
        rx1 = Regex("{{\\s*(?:fill\\s)?\\s*$vname\\s*}}")           # {{ fill v}} or {{v}}
        rx2 = Regex("{{\\s*(?:fill\\s)?\\s*(\\S+)\\s+$vname\\s*}}") # {{ fill x v}}
        for v in iter
            # at the moment we only consider {{fill ...}}
            tmp = replace(inner, rx1 => "$v")
            tmp = replace(tmp, rx2 => SubstitutionString("{{fill \\1 $v}}"))
            content *= tmp
        end
    else
        for values in iter # each element of the iter can be unpacked
            tmp = inner
            for (vname, v) in zip(vnames, values)
                rx1 = Regex("{{\\s*(?:fill\\s)?\\s*$vname\\s*}}")
                rx2 = Regex("{{\\s*(?:fill\\s)\\s*(\\S+)\\s+$vname\\s*}}")
                tmp = replace(tmp, rx1 => "$v")
                tmp = replace(tmp, rx2 => SubstitutionString("{{fill \\1 $v}}"))
            end
            content *= tmp
        end
    end
    @label final_step
    head = nextind(hs, to(β_close))
    return convert_html(content), head, i_close
end

"""
$SIGNATURES

Extract the body of a for loop, keeping track of balancing.
"""
function get_for_body(i::Int, qblocks::Vector{AbstractBlock})
    # try to close the for loop
    if i == length(qblocks)
        throw(HTMLBlockError("Could not close the block starting with" *
                             "'$(qblocks[i].ss)'."))
    end
    init_idx = i
    content  = ""
    # inbalance keeps track of whether we've managed to find a
    # matching {{end}}. It increases if it sees other opening {{if..}}
    # and decreases if it sees a {{end}}
    inb = 1
    while i < length(qblocks) && inb > 0
        i   += 1
        inb += hbalance(qblocks[i])
    end
    # we've exhausted the candidate qblocks and not found a matching {{end}}
    if inb > 0
        throw(HTMLBlockError("Could not close the block starting with" *
                             "'$(qblocks[init_idx].ss)'."))
    end
    # we've found the closing {{end}} and index `i`
    return i, qblocks[i]
end
