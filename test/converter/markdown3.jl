# NOTE: theses tests focus on speciall characters, html entities
# escaping things etc.

@testset "Backslashes" begin # see issue #205
    st = raw"""
        Hello \ blah \ end
        and `B \ c` end and
        ```
        A \ b
        ```
        done
        """ * J.EOS

    steps = explore_md_steps(st)
    tokens, = steps[:tokenization]

    # the first two backspaces are detected
    @test tokens[1].ss == "\\" && tokens[1].name == :CHAR_BACKSPACE
    @test tokens[2].ss == "\\" && tokens[2].name == :CHAR_BACKSPACE
    # the third one also
    @test tokens[5].ss == "\\" && tokens[5].name == :CHAR_BACKSPACE

    sp_chars, = steps[:spchars]

    # there's only two tokens left which are the backspaces NOT in the code env
    sp_chars = J.find_special_chars(tokens)
    for i in 1:2
        @test sp_chars[i] isa J.HTML_SPCH
        @test sp_chars[i].ss == "\\"
        @test sp_chars[i].r == "&#92;"
    end

    inter_html, = steps[:inter_html]

    @test isapproxstr(inter_html, "<p>Hello  ##JDINSERT##  blah  ##JDINSERT##  end and  ##JDINSERT##  end and  ##JDINSERT##  done</p>")

    @test isapproxstr(st |> seval, raw"""
                <p>Hello &#92; blah &#92; end
                and <code>B \ c</code> end and
                <pre><code>A \ b</code></pre>
                done</p>
                """)
end

@testset "Backslashes2" begin # see issue #205
    st = raw"""
        Hello \ blah \ end
        and `B \ c` end \\ and
        ```
        A \ b
        ```
        done
        """ * J.EOS
    steps = explore_md_steps(st)
    tokens, = steps[:tokenization]
    @test tokens[7].name == :CHAR_LINEBREAK
    h = st |> seval
    @test isapproxstr(st |> seval, """
                        <p>Hello &#92; blah &#92; end
                        and <code>B \ c</code> end <br/> and
                        <pre><code>A \ b</code></pre>
                        done</p>
                        """)
end

@testset "Backtick" begin # see issue #205
    st = raw"""Blah \` etc""" * J.EOS
    @test isapproxstr(st |> seval, "<p>Blah &#96; etc</p>")
end

@testset "HTMLEnts" begin # see issue #206
    st = raw"""Blah &pi; etc""" * J.EOS
    @test isapproxstr(st |> seval, "<p>Blah &pi; etc</p>")
    # but ill-formed ones (either deliberately or not) will be parsed
    st = raw"""AT&T""" * J.EOS
    @test isapproxstr(st |> seval, "<p>AT&amp;T</p>")
end

@testset "DoubleTicks" begin # see issue #204
    st = raw"""A `single` B""" * J.EOS
    steps = explore_md_steps(st)
    tokens = steps[:tokenization].tokens
    @test tokens[1].name == :CODE_SINGLE
    @test tokens[2].name == :CODE_SINGLE

    st = raw"""A ``double`` B""" * J.EOS
    steps = explore_md_steps(st)
    tokens = steps[:tokenization].tokens
    @test tokens[1].name == :CODE_DOUBLE
    @test tokens[2].name == :CODE_DOUBLE

    st = raw"""A `single` and ``double`` B""" * J.EOS
    steps = explore_md_steps(st)
    tokens = steps[:tokenization].tokens
    @test tokens[1].name == :CODE_SINGLE
    @test tokens[2].name == :CODE_SINGLE
    @test tokens[3].name == :CODE_DOUBLE
    @test tokens[4].name == :CODE_DOUBLE

    st = raw"""A `single` and ``double ` double`` B""" * J.EOS
    steps = explore_md_steps(st)
    blocks, tokens = steps[:ocblocks]
    @test blocks[1].name == :CODE_INLINE
    @test J.content(blocks[1]) == "double ` double"
    @test blocks[2].name == :CODE_INLINE
    @test J.content(blocks[2]) == "single"

    st = raw"""A `single` and ``double ` double`` and ``` triple ``` B""" * J.EOS
    steps = explore_md_steps(st)
    tokens = steps[:tokenization].tokens
    @test tokens[1].name == :CODE_SINGLE
    @test tokens[2].name == :CODE_SINGLE
    @test tokens[3].name == :CODE_DOUBLE
    @test tokens[4].name == :CODE_SINGLE
    @test tokens[5].name == :CODE_DOUBLE
    @test tokens[6].name == :CODE_TRIPLE
    @test tokens[7].name == :CODE_TRIPLE
    blocks, tokens = steps[:ocblocks]
    @test blocks[1].name == :CODE_BLOCK
    @test J.content(blocks[1]) == " triple "
    @test blocks[2].name == :CODE_INLINE
    @test blocks[3].name == :CODE_INLINE

    st = raw"""A `single` and ``double ` double`` and ``` triple `` triple```
               and ```julia 1+1``` and `single again` done""" * J.EOS
    steps = explore_md_steps(st)
    blocks, _ = steps[:ocblocks]
    @test blocks[1].name == :CODE_BLOCK_LANG
    @test J.content(blocks[1]) == " 1+1"
    @test blocks[2].name == :CODE_BLOCK
    @test J.content(blocks[2]) == " triple `` triple"
    @test blocks[3].name == :CODE_INLINE
    @test J.content(blocks[3]) == "double ` double"
    @test blocks[4].name == :CODE_INLINE
    @test J.content(blocks[4]) == "single"
end

@testset "\\ and \`" begin # see issue 203
    st = raw"""The `"Hello\n"` after the `readall` command is a returned value, whereas the `Hello` after the `run` command is printed output.""" * J.EOS
    st |> seval
    @test isapproxstr(st |> seval, raw"""
                        <p>The <code>&quot;Hello\n&quot;</code> after
                        the <code>readall</code> command is a returned value,
                        whereas the <code>Hello</code> after the <code>run</code>
                        command is printed output.</p>""")
end
