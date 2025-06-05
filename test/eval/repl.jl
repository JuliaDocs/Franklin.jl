@testset "repl" begin
    s = """
    ```>
    x = 5
    y = 7 + x
    ```
    some explanation
    ```>
    z = y * 2
    ```
    """ |> fd2html

    @test isapproxstr(s, """
        <pre><code class="language-julia-repl julia-repl">julia> x &#61; 5
        5

        julia> y &#61; 7 &#43; x
        12

        </code></pre>

        <p>some explanation</p>
        <pre><code class="language-julia-repl julia-repl">
        julia> z &#61; y * 2
        24

        </code></pre>
        """)

    s = """
    ```>
    println("hello")
    x = 5
    ```
    """ |> fd2html
    @test isapproxstr(s, """
        <pre><code class="language-julia-repl julia-repl">julia> println&#40;&quot;hello&quot;&#41;
        hello

        julia> x &#61; 5
        5

        </code></pre>
        """)

    s = """
    ```>
    x = 5;
    ```
    """ |> fd2html
    @test isapproxstr(s, """
        <pre><code class="language-julia-repl julia-repl">julia> x &#61; 5;

        </code></pre>
        """
    )
end

@testset "help" begin
    s = """
    ```?
    im
    ```
    """ |> fd2html

    @test occursin("""
        <pre><code class="language-julia-repl julia-repl-help">help?> im
        </code></pre>
        <div class="julia-help">
        <pre><code class="language-julia">im</code></pre>
        <p>The imaginary unit.</p>
        """, s)
end

@testset "shell" begin
    s = """
        ```;
        echo "foo"
        ```
        """ |> fd2html
    @test isapproxstr(s, """
        <pre><code class="language-julia-repl julia-repl-shell">shell> echo &quot;foo&quot;
        "foo"
        </code></pre>
        """)
    # multiline
    s = """
        ```;
        echo abc
        echo "abc"
        ```
        """ |> fd2html
    @test isapproxstr(s, """
        <pre><code class="language-julia-repl julia-repl-shell">shell> echo abc
        abc

        shell> echo &quot;abc&quot;
        "abc"

        </code></pre>
        """)
end

@testset "pkg" begin
    s = """
        ```]
        activate --temp
        add StableRNGs
        st
        ```

        this is now in the activated stuff

        ```!
        using StableRNGs
        round(rand(StableRNG(1)), sigdigits=3)
        ```

        """ |> fd2html

    print(s)

    # first block
    @test occursin(
        """pkg&gt; activate --temp""", s
    )
    @test occursin(
        """pkg&gt; add StableRNGs""", s
    )
    @test occursin(
        """Resolving package versions...""", s
    )
    @test occursin(
        """pkg&gt; st\nStatus""", s
    )

    # second block uses StableRNG
    @test occursin(
        """<pre><code class="language-julia">using StableRNGs
        round&#40;rand&#40;StableRNG&#40;1&#41;&#41;, sigdigits&#61;3&#41;</code></pre><pre><code class="plaintext code-output">0.585</code></pre>""",
        s
    )
    Pkg.activate()
end
