@testset "∫ newcom" begin
    st = raw"""
        \newcommand{ \coma }[ 1]{hello #1}
        \newcommand{ \comb} [2 ]{\coma{#1}, goodbye #1, #2!}
        Then \comb{auth1}{auth2}.
        """
    @test isapproxstr(st |> conv,
            """<p>
            Then hello auth1, goodbye auth1, auth2$(F.htmlesc("!")).
            </p>""")
end


@testset "∫ math" begin
    st = raw"""
        \newcommand{\E}[1]{\mathbb E\left[#1\right]}
        \newcommand{\eqa}[1]{\begin{eqnarray}#1\end{eqnarray}}
        \newcommand{\R}{\mathbb R}
        Then something like
        \eqa{ \E{f(X)} \in \R &\text{if}& f:\R\maptso\R }
        """
    @test isapproxstr(st |> fd2html,
            """<p>
            Then something like
            \\[\\begin{array}{rcl} \\mathbb E\\left[ f(X)\\right] \\in \\mathbb R &\\text{if}& f:\\mathbb R\\maptso\\mathbb R \\end{array}\\]
            </p>""")
end


@testset "∫ re-com" begin # see #36
    st = raw"""
        \newcommand{\com}[1]{⭒!#1⭒}
        \com{A}
        \newcommand{\com}[1]{◲!#1◲}
        \com{A}
        """
    @test st |> conv == "⭒A⭒\n◲A◲\n"
end


@testset "∫ div" begin # see #74
    st = raw"""
        Etc and `~~~` but hey.
        @@dd but `x` and `y`? @@
        done
        """
    @test isapproxstr(st |> conv,
            """
            <p>Etc and <code>~~~</code> but hey.</p>
            <div class="dd">but <code>x</code> and <code>y</code>?</div>
            <p>done</p>
            """)
end


@testset "∫ code-l" begin
    st = raw"""
        Some code
        ```julia
        struct P
            x::Real
        end
        ```
        done
        """
    @test isapproxstr(st |> conv,
            """
            <p>Some code</p>
            <pre><code class="language-julia">struct P
                x::Real
            end</code></pre>
            <p>done</p>
            """)
end


@testset "∫ math-br" begin # see #73
    st = raw"""
        \newcommand{\R}{\mathbb R}
        $$
            \min_{x\in \R^n} \quad f(x)+i_C(x).
        $$
        """
    @test isapproxstr(st |> conv,
            """\\[ \\min_{x\\in \\mathbb R^n} \\quad f(x)+i_C(x). \\]""")
end


@testset "∫ insert" begin # see also #65
    st = raw"""
        \newcommand{\com}[1]{⭒!#1⭒}
        abc\com{A}\com{B}def.
        """
    @test st |> conv == "<p>abc⭒A⭒⭒B⭒def.</p>\n"

    st = raw"""
        \newcommand{\com}[1]{⭒!#1⭒}
        abc

        \com{A}\com{B}

        def.
        """
    @test st |> conv == "<p>abc</p>\n<p>⭒A⭒⭒B⭒</p>\n<p>def.</p>\n"

    st = raw"""
        \newcommand{\com}[1]{⭒!#1⭒}
        abc

        \com{A}

        def.
        """
    @test (st |> conv) //
            """
            <p>abc</p>
            ⭒A⭒
            <p>def.</p>
            """

    st = raw"""
        \newcommand{\com}[1]{†!#1†}
        blah \com{a}
        * \com{aaa} tt
        * ss \com{bbb}
        """
    @test isapproxstr(st |> conv, VERSION < v"1.14.0-" ?
            """<p>blah †a†</p>
            <ul>
               <li><p>†aaa† tt</p></li>
               <li><p>ss †bbb†</p></li>
            </ul>""" :
            """<p>blah †a†</p>
            <ul>
               <li>†aaa† tt</li>
               <li>ss †bbb†</li>
            </ul>""")
end


@testset "∫ br-rge" begin # see #70
    st = raw"""
           \newcommand{\scal}[1]{\left\langle#1\right\rangle}
           \newcommand{\E}{\mathbb E}
           exhibit A
           $\scal{\mu, \nu} = \E[X]$
           exhibit B
           $\E[X] = \scal{\mu, \nu}$
           end."""
    @test isapproxstr(st |> conv,
            """<p>exhibit A
            \\(\\left\\langle \\mu, \\nu\\right\\rangle = \\mathbb E[X]\\)
            exhibit B
            \\(\\mathbb E[X] = \\left\\langle \\mu, \\nu\\right\\rangle\\)
            end.</p>""")
end


@testset "∫ cond" begin
    stv(var1, var2) = """
        @def var1 = $var1
        @def var2 = $var2
        start
        ~~~
        {{ if var1 }} targ1 {{ else if var2 }} targ2 {{ else }} targ3 {{ end }}
        ~~~
        done
        """
    @test stv(true, true)   |> conv == "<p>start \n targ1 \n done</p>\n"
    @test stv(false, true)  |> conv == "<p>start \n targ2 \n done</p>\n"
    @test stv(false, false) |> conv == "<p>start \n targ3 \n done</p>\n"
end


@testset "∫ recurs" begin # see #97
    st = raw"""
        | A | B |
        | :---: | :---: |
        | C | D |
        """

    if VERSION >= v"1.4.0-"
        @test isapproxstr(st |> conv,
            """<table><tr><th align="center">A</th><th align="center">B</th></tr><tr><td align="center">C</td><td align="center">D</td></tr></table>""")
    else
        @test isapproxstr(st |> conv,
            """<table>
                 <tr><th>A</th><th>B</th></tr>
                 <tr><td>C</td><td>D</td></tr>
               </table>""")
    end

    @test F.convert_md(st, isrecursive=true) |> chtml == st |> conv

    st = raw"""
        @@emptydiv
        @@emptycore
        @@
        @@
        """
    st |> conv == "<div class=\"emptydiv\"><div class=\"emptycore\"></div>\n</div>\n"
end


@testset "∫ label" begin
    st = raw"""
        Blah blah
        ## some title
        and then an anchor here \label{anchor} done.
        """
    F.def_GLOBAL_LXDEFS!()
    r = st |> conv
    @test occursin("here <a id=\"anchor\" class=\"anchor\"></a> done.", r)
end
