# This takes over from some of the lower-level tests that were done earlier to test
# the newcommand; these are more integrated as a result.

@testset "basic" begin
    s = raw"""
        \newcommand{\abc}{hello}
        A \abc B
        """ |> fd2html
    @test s // "<p>A hello B</p>"
    s = raw"""
        \newcommand{\abc}[1]{hello#1}
        A \abc{Bob} C
        """ |> fd2html
    @test s // "<p>A hello Bob C</p>"
    s = raw"""
        \newcommand{\abc}[1]{hello!#1}
        A \abc{Bob} C
        """ |> fd2html
    @test s // "<p>A helloBob C</p>"
    s = raw"""
        \newcommand{\abc}[2]{A#1B#2C}
        AA \abc{EE}{FF} BB
        """ |> fd2html
    @test s // "<p>AA A EEB FFC BB</p>"
    s = raw"""
        \newcommand{\abc}[2]{A!#1B!#2C}
        AA \abc{EE}{FF} BB
        """ |> fd2html
    @test s // "<p>AA AEEBFFC BB</p>"
end

@testset "redef" begin
    s = raw"""
        \newcommand{\abc}{hello}
        A \abc B
        \newcommand{\abc}{bye}
        A \abc B
        """ |> fd2html
    @test s // "<p>A hello B</p>\n<p>A bye B</p>"
    s = raw"""
        \newcommand{\abc}[1]{hello#1}
        A \abc{Bob} B
        \newcommand{\abc}{bye}
        A \abc B
        """ |> fd2html
    @test s // "<p>A hello Bob B</p>\n<p>A bye B</p>"
end

@testset "nesting" begin
    s = raw"""
        \newcommand{\abc}{hello}
        \newcommand{\def}[1]{\abc#1}
        A \def{Bob} B
        """ |> fd2html
    @test s // "<p>A hello Bob B</p>"
end

@testset "errors" begin
    # malformed
    s = raw"""
        abc \newcommand abc
        """
    @test_throws F.LxObjError (s |> fd2html)
    s = raw"""
        \newcommand{abc}{hello}
        """
    @test_throws F.LxDefError (s |> fd2html)
    # ordering
    s = raw"""
        \abc
        \newcommand{\abc}{hello}
        """
    @test_throws F.LxObjError (s |> fd2html)
    # nargs not proper
    s = raw"""
        \newcommand{\abc}[d]{hello}
        """
    @test_throws F.LxDefError (s |> fd2html)
    # bad use
    s = raw"""
        \newcommand{\comb}[1]{HH#1HH}
        etc \comb then.
        """
    @test_throws F.LxObjError (s |> fd2html)
end

# ==== more integrated examples recuperated from previous more specific tests ===

@testset "integrated-1" begin
    st = raw"""
        \newcommand{\com}{blah}
        \newcommand{\comb}[ 2]{hello #1 #2 \com}
        A \comb{AA}{BB} B
        """ |> fd2html
    @test isapproxstr(st, "<p>A hello AA BB blah B</p>")
end

@testset "integrated-2" begin
    st = raw"""
        \newcommand{\com}{HH}
        \newcommand{\comb}[1]{GG#1FF}
        Blah \com and \comb{blah} etc
        ```julia
        f(x) = x^2
        ```
        etc \comb{blah} then maybe
        @@adiv inner part @@ final.
        """ |> fd2html
    @test isapproxstr(st, """
        <p>Blah HH and GG blahFF etc</p>
        <pre><code class="language-julia">f&#40;x&#41; &#61; x^2</code></pre>
        <p>etc GG blahFF then maybe</p>
        <div class="adiv">inner part</div>
        <p>final.</p>
        """)
end

@testset "integrated-3" begin
    st = raw"""
        \newcommand{\E}[1]{\mathbb E\left[#1\right]}blah de blah
        ~~~
        escape b1
        ~~~
        \newcommand{\eqa}[1]{\begin{eqnarray}#1\end{eqnarray}}
        \newcommand{\R}{\mathbb R}
        Then something like
        \eqa{ \E{f(X)} \in \R &\text{if}& f:\R\maptso\R }
        and we could try to show latex:
        ```latex
        \newcommand{\brol}{\mathbb B}
        ```
        """ |> fd2html
    @test isapproxstr(st, raw"""
        <p>
          blah de blah
          escape b1
        </p>
        <p>
          Then something like
            \[\begin{array}{rcl}
              \mathbb E\left[ f(X)\right] \in \mathbb R &\text{if}& f:\mathbb R\maptso\mathbb R
            \end{array}\]
          and we could try to show latex:
        </p>
        <pre><code class="language-latex">
          \newcommand&#123;\brol&#125;&#123;\mathbb B&#125;
        </code></pre>
        """)
end

@testset "integrated-4" begin
    s = raw"""
        text A1 \newcommand{\com}{blah}text A2 \com and
        ~~~
        escape B1
        ~~~
        \newcommand{\comb}[ 1]{\mathrm{#1}} text C1 $\comb{b}$ text C2
        \newcommand{\comc}[ 2]{part1:#1 and part2:#2} then \comc{AA}{BB}.
        """ |> fd2html
    @test isapproxstr(s, raw"""
        <p>text A1 text A2 blah and
        escape B1
        text C1 \(\mathrm{ b}\) text C2  then part1: AA and part2: BB.</p>
        """)
end

@testset "integrated-5" begin
    s = raw"""
        @def title = "Convex Optimisation I"
        \newcommand{\com}[1]{⭒!#1⭒}
        \com{A}
        <!-- comment -->
        then some
        ## blah <!-- ✅ 19/9/999 -->
        end \com{B}.
        """ |> fd2html
    @test isapproxstr(s, raw"""
        ⭒A⭒
        <p>then some</p>
        <h2 id="blah"><a href="#blah" class="header-anchor">blah </a></h2>
        <p>end ⭒B⭒.</p>
        """)
end

@testset "integrated-6" begin
    st = raw"""
        \newcommand{\com}{HH}
        \newcommand{\comb}[1]{FF#1GG}
        A list
        * \com and \comb{blah}
        * $f$ is a function
        * a last element
        """ |> fd2html
    # newer Markdown renders tight list items without wrapping <p> tags
    @test isapproxstr(st, VERSION < v"1.14.0-" ? raw"""
        <p>A list</p>
        <ul>
        <li><p>HH and FF blahGG</p>
        </li>
        <li><p>\(f\) is a function</p>
        </li>
        <li><p>a last element</p>
        </li>
        </ul>
        """ : raw"""
        <p>A list</p>
        <ul>
        <li>HH and FF blahGG</li>
        <li>\(f\) is a function</li>
        <li>a last element</li>
        </ul>
        """)

    st = raw"""
        a\newcommand{\eqa}[1]{\begin{eqnarray}#1\end{eqnarray}}b@@d .@@
        \eqa{\sin^2(x)+\cos^2(x) &=& 1}
        """ |> fd2html

    @test isapproxstr(st, raw"""
        <p>ab</p>
        <div class="d">.</div>
        \[\begin{array}{rcl} \sin^2(x)+\cos^2(x) &=& 1\end{array}\]
        """)
end
