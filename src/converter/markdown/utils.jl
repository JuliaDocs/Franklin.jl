"""
$(SIGNATURES)

Convenience function to call the base markdown to html converter on "simple" strings (i.e. strings
that don't need to be further considered and don't contain anything else than markdown tokens).
The boolean `stripp` indicates whether to remove the inserted `<p>` and `</p>` by the base markdown
processor, this is relevant for things that are parsed within latex commands etc.
"""
# Recursively replace soft line breaks ('\n' in inline text) with spaces, leaving
# code (spans and blocks) and LaTeX untouched. See use in `md2html`.
_collapse_soft_breaks(s::AbstractString) = replace(s, '\n' => ' ')
_collapse_soft_breaks(c::Markdown.Code)  = c
_collapse_soft_breaks(l::Markdown.LaTeX) = l
function _collapse_soft_breaks(x)
    for f in fieldnames(typeof(x))
        fv = getfield(x, f)
        fv isa AbstractVector && _collapse_soft_breaks!(fv)
    end
    return x
end
function _collapse_soft_breaks!(v::AbstractVector)
    for i in eachindex(v)
        v[i] = _collapse_soft_breaks(v[i])
    end
    return v
end

function md2html(ss::AS; stripp::Bool=false)::AS
    # if there's nothing, return that...
    isempty(ss) && return ss
    # Use Julia's Markdown parser followed by Julia's MD->HTML conversion
    partial = ss |> fix_inserts |> Markdown.parse
    # collapse soft line breaks (single '\n' within inline text) into spaces; on
    # Julia <= 1.12 `Markdown.parse` did this for us, but since then the '\n' is
    # kept verbatim which would spread a paragraph over several lines (issue #489)
    _collapse_soft_breaks!(partial.content)
    # take over from the parsing of indented blocks
    for (i, c) in enumerate(partial.content)
        c isa Markdown.Code || continue
        partial.content[i] = Markdown.Paragraph(Any[c.code])
    end
    # Use Julia's MD->HTML conversion
    partial = partial |> Markdown.html
    # Markdown.html transforms {{ with HTML entities but we don't want that
    partial = replace(partial, r"&#123;&#123;" => "{{")
    partial = replace(partial, r"&#125;&#125;" => "}}")
    # Older Markdown.html escaped '!', '[' and ']' as numeric entities; newer
    # versions leave them literal. Franklin's link fixer (see `ESC_LINK_PAT`)
    # relies on the escaped form to locate reference-style links, so restore it.
    # These characters never appear structurally in the generated HTML, so this
    # is safe (and a no-op on Julia versions that already escape them).
    partial = replace(partial, '!' => "&#33;", '[' => "&#91;", ']' => "&#93;")
    # In some cases, base converter adds <p>...</p>\n which we might not want
    stripp || return partial
    if startswith(partial, "<p>") && endswith(partial, "</p>\n")
        partial = chop(partial, head=3, tail=5)
    end
    return partial
end


"""
$(SIGNATURES)

Convenience function to check if `idx` is smaller than the length of `v`, if it is, then return the starting point of `v[idx]` (via `from`), otherwise return `BIG_INT`.
"""
from_ifsmaller(v::Vector, idx::Int, len::Int)::Int = (idx > len) ? BIG_INT : from(v[idx])


"""
$(SIGNATURES)

Since divs are recursively processed, once they've been found, everything
inside them needs to be deactivated and left for further re-processing to
avoid double inclusion.
"""
function deactivate_divs(blocks::Vector{OCBlock})::Vector{OCBlock}
    active_blocks = ones(Bool, length(blocks))
    for (i, β) ∈ enumerate(blocks)
        fromβ, toβ = from(β), to(β)
        active_blocks[i] || continue
        if β.name == :DIV
            innerblocks = findall(b -> (fromβ < from(b) < toβ), blocks)
            active_blocks[innerblocks] .= false
        end
    end
    return blocks[active_blocks]
end


"""
$(SIGNATURES)

The insertion token have whitespaces around them: ` ##FDINSERT## `, this mostly helps but causes
a problem when combined with italic or bold markdown mode since `_blah_` works but not `_ blah _`.
This function looks for any occurrence of `[\\*_] ##FDINSERT##` or the opposite and removes the
extraneous whitespace.
"""
fix_inserts(s::AS)::String =
    replace(replace(s, r"([\*_]) ##FDINSERT##" => s"\1##FDINSERT##"),
                       r"##FDINSERT## ([\*_])" => s"##FDINSERT##\1")

"""
$(SIGNATURES)

Takes a list of tokens and deactivate tokens that happen to be in a multi-line
md-def. Used in [`convert_md`](@ref).
"""
function preprocess_candidate_mddefs!(tokens::Vector{Token})
    isempty(tokens) && return nothing
    # process:
    # 1. find a MD_DEF_OPEN token
    # 2. Look for the first LINE_RETURN (proper)
    # 3. try to parse the content with Meta.parse. If it completely fails,
    # error, otherwise consider the  span of the first ok expression and
    # discard all tokens within its span leaving effectively just the
    # opening MD_DEF_OPEN and closing LINE_RETURN
    from_to_list = Pair{Int,Int}[]
    i = 0
    while i < length(tokens)
        i += 1
        τ  = tokens[i]
        τ.name == :MD_DEF_OPEN || continue
        # look ahead stopping with the first LINE_RETURN
        j = findfirst(τc -> τc.name ∈ (:LINE_RETURN, :EOS), tokens[i+1:end])
        if j !== nothing
            e = i+j
            # discard if it's a single line
            any(τx -> τx.name == :LR_INDENT, tokens[i:e]) || continue
            push!(from_to_list, (i => e))
        end
    end
    remove = Int[]
    s = str(first(tokens))
    for (i, j) in from_to_list
        si = nextind(s, to(tokens[i]))
        sj = prevind(s, from(tokens[j]))
        sc = subs(s, si, sj)
        ex, pos = Meta.parse(sc, 1)

        # find where's the first character after the effective end of the
        # definition (right-strip)
        str_expr = subs(s, si, si + prevind(sc, pos))
        stripped = strip(str_expr)
        start_id = findfirst(c -> c == stripped[1], str_expr)
        last_id  = prevind(str_expr, start_id + length(stripped))

        # find the first token after si + next_id - 1 and discard what's before
        c = findfirst(k -> from(tokens[k]) > si + last_id - 1, i+1:j)
        # we discard everything between i+1 and i+c-1 (we want to keep i+c)
        if !isnothing(c)
            append!(remove, i+1:i+c-1)
        end
    end
    deleteat!(tokens, remove)
    return nothing
end
