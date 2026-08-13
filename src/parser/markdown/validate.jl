"""
$(SIGNATURES)

Given a candidate header block, check that the opening `#` is at the start of a
line, otherwise ignore the block.
"""
function validate_start_of_line!(tokens::Vector{Token}, names)::Nothing
    isempty(tokens) && return
    s = str(tokens[1].ss) # does not allocate
    rm = Int[]
    for (i, τ) in enumerate(tokens)
        τ.name in names || continue
        # check if it overlaps with the first character
        fromτ = from(τ)
        fromτ == 1 && continue
        # otherwise check if the previous character is a linereturn
        prevc = s[prevind(s, fromτ)]
        prevc == '\n' && continue
        push!(rm, i)
    end
    deleteat!(tokens, rm)
    return
end


"""
$SIGNATURES

Find footnotes refs and defs and eliminate the ones that don't verify the
appropriate regex. For a footnote ref: `\\[\\^[\\p{L}0-0]+\\]` and
`\\[\\^[\\p{L}0-0]+\\]:` for the def.
"""
function validate_footnotes!(tokens::Vector{Token})
    fn_refs = Vector{Token}()
    rm      = Int[]
    for (i, τ) in enumerate(tokens)
        τ.name == :FOOTNOTE_REF || continue
        # footnote ref [^1]:
        m = match(FN_DEF_PAT, τ.ss)
        if !isnothing(m)
            if !isnothing(m.captures[1])
                # it's a def
                tokens[i] = Token(:FOOTNOTE_DEF, τ.ss)
            end
            # otherwise it's a ref, leave as is
        else
            # delete
            push!(rm, i)
        end
    end
    deleteat!(tokens, rm)
    return nothing
end

"""
$SIGNATURES

Verify that a given string corresponds to a well formed html entity.
"""
validate_html_entity(ss::AS) = !isnothing(match(HTML_ENT_PAT, ss))


function validate_emojis!(tokens::Vector{Token})::Nothing
    isempty(tokens) && return
    s = str(tokens[1].ss) # doesn't allocate
    rm = Int[]
    for (i, τ) in enumerate(tokens)
        τ.name == :CAND_EMOJI || continue
        # check if the immediate next character is `:`
        nextidx = nextind(s, to(τ))
        if nextidx <= lastindex(s) && s[nextidx] == ':'
            # check if the string describes a known emoji if not, remove,
            # otherwise re-form the emoji to add the closing ':'.
            key = "\\$(τ.ss):"
            if key in keys(emoji_symbols)
                tokens[i] = Token(:EMOJI, subs(s, from(τ), nextidx))
            else
                push!(rm, i)
            end
        else
            push!(rm, i)
        end
    end
    deleteat!(tokens, rm)
    return
end

"""
    emoji(token)

Return the emoji corresponding to an Emoji token by querying `emoji_symbols`.
This assumes that the token has name `:EMOJI` and so we know it's in the dict.
"""
emoji(τ::Token) = emoji_symbols["\\$(τ.ss)"]


"""
$(SIGNATURES)

Keep track of link defs. Deactivate any blocks that is within the span of
a link definition (see issue #314).
"""
function validate_and_store_link_defs!(blocks::Vector{OCBlock})::Nothing
    isempty(blocks) && return
    rm = Int[]
    parent = str(blocks[1])
    for (i, β) in enumerate(blocks)
        if β.name == :LINK_DEF
            # incremental backward look until we find a `[` or a `\n`
            # if `\n` (or start of string) first, discard
            ini  = prevind(parent, from(β))
            k    = ini
            char = '\n'
            while k ≥ 1
                char = parent[k]
                char ∈ ('[','\n') && break
                k = prevind(parent, k)
            end
            if char == '['
                # redefine the full block
                ftk = Token(:FOO,subs(""))
                # we have a [id]: lk add it to PAGE_LINK_DEFS
                id = subs(parent, nextind(parent, k), ini)
                # issue #266 in case there's formatting in the link
                id = fd2html(id, internal=true)
                id = replace(id, r"^\s*(?:<p>)?(.*?)(?:<\/p>)?\s*$" => s"\1")
                lk = β |> content |> strip |> string
                PAGE_LINK_DEFS[id] = lk
                # replace the block by a full one so that it can be fully
                # discarded in the process of md blocks
                blocks[i] = OCBlock(:LINK_DEF, ftk=>ftk, subs(parent, k, to(β)))
            else
                # discard
                push!(rm, i)
            end
        end
    end
    isempty(rm) || deleteat!(blocks, rm)
    # cleanup: deactivate any block that it's in the span of a link def
    spans = [(from(ld), to(ld)) for ld in blocks if ld.name == :LINK_DEF]
    if !isempty(spans)
        for (i, block) in enumerate(blocks)
            # if it's in one of the span, discard
            curspan = (from(block), to(block))
            # early stopping if before all ld or after all of them
            curspan[2] < spans[1][1]   && continue
            curspan[1] > spans[end][2] && continue
            # go over each span break as soon as it's in
            for span in spans
                if span[1] < curspan[1] && curspan[2] < span[2]
                    push!(rm, i)
                    break
                end
            end
        end
    end
    isempty(rm) || deleteat!(blocks, rm)
    return nothing
end

"""
    find_double_brace_blocks(tokens)

Find `{{` and `}}` then form double brace blocks `{{ ... }}` (in markdown).
"""
function find_double_brace_blocks(tokens)
    # keep track of `{{` and `}}`
    db_tokens = Token[]
    # find `{` or `}` if next one exists and is the same
    # then make the first one a double with an increased substring
    # and remove the second one
    head = 1
    while head < length(tokens)
        thead = tokens[head]
        if thead.name in (:LXB_OPEN, :LXB_CLOSE)
            tcand = tokens[head+1]
            nhead = nextind(str(thead), to(thead))
            if from(tcand) == nhead && tcand.name == thead.name
                name = ifelse(thead.name == :LXB_OPEN, :DB_OPEN, :DB_CLOSE)
                ss   = subs(str(thead), from(thead), to(tcand))
                push!(db_tokens, Token(name, ss, 0))
                head += 1
            end
        end
        head += 1
    end
    # Now go back over the list of tokens and form blocks
    # these are non-nestable so it's easy.
    dbb = OCBlock[]
    head = 1
    while head < length(db_tokens)
        thead = db_tokens[head]
        if thead.name == :DB_OPEN
            hnext = findfirst(h -> db_tokens[h].name == :DB_CLOSE,
                              head+1:length(db_tokens))
            if isnothing(hnext)
                throw(OCBlockError("I found the opening token '{{' but not " *
                                   "the corresponding closing token '}}'.",
                                   context(thead)))
            end
            hnext += head
            ocb = OCBlock(:DOUBLE_BRACE, thead => db_tokens[hnext])
            push!(dbb, ocb)
            head = hnext
        end
        head += 1
    end
    return dbb
end

"""
$SIGNATURES

Check that a `---` or `***` or `___` starts at the beginning of a line and is preceded by an empty line, if that's not the case, discard it.
"""
function find_hrules!(tokens::Vector{Token})
    keep = Int[]
    rm   = Int[]
    for (i, τ) in enumerate(tokens)
        τ.name == :HORIZONTAL_RULE || continue
        # check if it has the right format
        if !(startswith(τ.ss, "---") ||
             startswith(τ.ss, "___") ||
             startswith(τ.ss, "***")) || length(unique(τ.ss)) > 1
            push!(rm, i)
            continue
        end
        # check if it's at the start of the string  or
        # if it's preceded by an empty line, in which case mark it as
        # horizontal rule, leave all other cases to be dealt with by Julia's
        # Markdown parser.
        s, k = str(τ), from(τ)
        if !(k == 1 || s[prevind(s, k, 2):prevind(s, k)] == "\n\n")
            push!(rm, i)
            continue
        end
        push!(keep, i)
    end
    hrules = tokens[keep]
    deleteat!(tokens, sort(vcat(rm, keep)))
    return hrules
end
