@testset "Bold x*" begin # issue 223
    h = raw"**x\***" |> seval
    @test h == "<p><strong>x&#42;</strong></p>\n"

    h = raw"_x\__" |> seval
    @test h == "<p><em>x&#95;</em></p>\n"
end

@testset "Bold code" begin # issue 222
    h = raw"""A **`master`** B.""" |> seval
    @test h == "<p>A <strong><code>master</code></strong> B.</p>\n"
end

@testset "Tickssss" begin # issue 219
    st = raw"""A `B` C"""
    tokens = F.find_tokens(st, F.MD_TOKENS, F.MD_1C_TOKENS)
    @test tokens[1].name == :CODE_SINGLE
    @test tokens[2].name == :CODE_SINGLE

    st = raw"""A ``B`` C"""
    tokens = F.find_tokens(st, F.MD_TOKENS, F.MD_1C_TOKENS)
    @test tokens[1].name == :CODE_DOUBLE
    @test tokens[2].name == :CODE_DOUBLE

    st = raw"""A ``` B ``` C"""
    tokens = F.find_tokens(st, F.MD_TOKENS, F.MD_1C_TOKENS)
    @test tokens[1].name == :CODE_TRIPLE
    @test tokens[2].name == :CODE_TRIPLE

    st = raw"""A ```` B ```` C"""
    tokens = F.find_tokens(st, F.MD_TOKENS, F.MD_1C_TOKENS)
    @test tokens[1].name == :CODE_QUAD
    @test tokens[2].name == :CODE_QUAD

    st = raw"""A ````` B ````` C"""
    tokens = F.find_tokens(st, F.MD_TOKENS, F.MD_1C_TOKENS)
    @test tokens[1].name == :CODE_PENTA
    @test tokens[2].name == :CODE_PENTA

    st = raw"""A ```b B ``` C"""
    tokens = F.find_tokens(st, F.MD_TOKENS, F.MD_1C_TOKENS)
    @test tokens[1].name == :CODE_LANG3
    @test tokens[2].name == :CODE_TRIPLE

    st = raw"""A `````b B ````` C"""
    tokens = F.find_tokens(st, F.MD_TOKENS, F.MD_1C_TOKENS)
    @test tokens[1].name == :CODE_LANG5
    @test tokens[2].name == :CODE_PENTA

    h = raw"""
        A
        `````markdown
        B
        `````
        C
        """ |> fd2html_td

    @test isapproxstr(h, raw"""
            <p>A</p>
            <pre><code class="language-markdown">B</code></pre>
            <p>C</p>
            """)

    h = raw"""
        A
        `````markdown
        ```julia
        B
        ```
        `````
        C
        """ |> fd2html_td

    @test isapproxstr(h, """
            <p>A</p>
            <pre><code class="language-markdown">$(F.htmlesc("""```julia
            B
            ```"""))
            </code></pre>
            <p>C</p>
            """)
end

@testset "Nested ind" begin # issue 285
    h = raw"""
    \newcommand{\hello}{
        yaya
        bar bar
    }
    \hello
    """ |> fd2html_td
    @test isapproxstr(h, raw"""yaya  bar bar""")

    h = raw"""
    @@da
        @@db
            @@dc
                blah
            @@
        @@
    @@
    """ |> fd2html_td
    @test isapproxstr(h, raw"""
            <div class="da">
                <div class="db">
                    <div class="dc">
                        blah
                    </div>
                </div>
            </div>
            """)
    h = raw"""
    \newcommand{\hello}[1]{#1}
    \hello{
        good lord
    }
    """ |> fd2html_td
    @test isapproxstr(h, "good lord")
end

@testset "Double brace" begin
    s = """
        @def title = "hello"
        {{title}}{{title}}
        """ |> fd2html_td
    @test isapproxstr(s, "<p>hellohello</p>")
    s = """
        @def a_b = "hello"
        @def c_d = "goodbye"
        {{a_b}}{{c_d}}
        """ |> fd2html_td
    @test isapproxstr(s, "<p>hellogoodbye</p>")
end

# issue 424 with double braces
@testset "Double brace2" begin
    s = raw"""
        @def title = "hello"
        {{title}}
        $\rho=\frac{e^{-\beta \mathcal{E}_{s}}} {\mathcal{Z}} $
        """ |> fd2html_td
    @test s // raw"""
                <p>hello \(\rho=\frac{e^{-\beta \mathcal{E}_{s}}} {\mathcal{Z}} \)</p>"""
end

# issue 432 and consequences
@testset "Hz rule" begin
    # issue 432
    s = raw"""
        hello[^a]

        [^a]: world

        ---
        """ |> fd2html_td
    @test isapproxstr(s, """
        <p>hello<sup id="fnref:a"><a href="#fndef:a" class="fnref">[1]</a></sup></p>
        <p><table class="fndef" id="fndef:a">
            <tr>
                <td class="fndef-backref"><a href="#fnref:a">[1]</a></td>
                <td class="fndef-content">world</td>
            </tr>
        </table>
        <hr /></p>
        """)
    s = raw"""
        A
        ---
        """ |> fd2html_td
    @test isapproxstr(s, """
        <h2>A</h2>""")
    s = raw"""
        A
        ----
        ****
        """ |> fd2html_td
    @test isapproxstr(s, "<h2>A</h2>\n<hr />")

    # cases where nothing should happen
    s = raw"""
        A
        ---*
        ***_
        """ |> fd2html_td
    if VERSION <= v"1.12.0"
        @test isapproxstr(s, "<p>A –-* ***_</p>") # note double -- is transformed -
    else
        @test isapproxstr(s, "<p>A –-* ***_</p>\n") # note double -- is transformed -
    end
end

# issue 439 and consequences
@testset "mathunicode" begin
    s = raw"""
        \newcommand{\u}{1}
        $$ φφφ\u abcdef $$
        """ |> fd2html_td
    @test isapproxstr(s, raw"\[ φφφ1 abcdef \]")
end

@testset "emoji-basics" begin
    s = "abc :+1: def" |> fd2html
    @test s // "<p>abc 👍 def</p>"
    s = "abc :+10: def" |> fd2html
    @test s // "<p>abc :&#43;10: def</p>"
    s = "abc :joy: def" |> fd2html
    @test s // "<p>abc 😂 def</p>"
    s = "abc :joy def:" |> fd2html
    @test s // "<p>abc :joy def:</p>"
    s = "abc : joy: def" |> fd2html
    @test s // "<p>abc : joy: def</p>"
    s = "abc :joi: def" |> fd2html
    @test s // "<p>abc :joi: def</p>"
end

@testset "quad-backticks" begin
    s = """
        ````julia
        1+1
        ````
        """ |> fd2html
    @test s // """<pre><code class="language-julia">1&#43;1</code></pre>"""
end
