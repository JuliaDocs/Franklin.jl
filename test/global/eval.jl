# This set of tests is specifically for the ordering
# of operations, when code blocks are eval-ed or re-eval-ed

@testset "EvalOrder" begin
    flush_td(); set_globals()

    Random.seed!(0) # seed for extra testing of when code is ran
    # Generate random numbers in a sequence then we'll check
    # things are done in the same sequence on the page
    a, b, c, d, e = randn(5)
    Random.seed!(0)

    # Create a page "foo.md" which we'll use and abuse
    foo = raw"""
        @def hascode = true
        ```julia:ex
        println(randn())
        ```
        \output{ex}
        """

    # XXX FIRST PASS --> EVAL

    h = foo |> fd2html_td

    @test isapproxstr(h, """
                <pre><code class="language-julia">$(F.htmlesc("""println(randn())"""))</code></pre> <pre><code class=\"plaintext code-output\">$a</code></pre>
                """)

    # XXX TEXT MODIFICATION + IN SCOPE --> NO REEVAL

    foo *= "etc"

    h = foo |> fd2html_td

    @test isapproxstr(h, """
                <pre><code class="language-julia">$(F.htmlesc("""println(randn())"""))</code></pre> <p><pre><code class=\"plaintext code-output\">$a</code></pre> etc</p>
                """)

    # XXX CODE ADDITION --> NO REEVAL OF FIRST BLOCK

    foo *= raw"""
        ```julia:ex2
        println(randn())
        ```
        \output{ex2}
        ```julia:ex3
        println(randn())
        ```
        \output{ex3}
        """

    h = foo |> fd2html_td

    @test isapproxstr(h, """
        <pre><code class="language-julia">
            $(F.htmlesc(raw"""
            println(randn())
            """))
        </code></pre>
        <p><pre><code class=\"plaintext code-output\">$a</code></pre> etc</p>
        <pre><code class="language-julia">
            $(F.htmlesc(raw"""
            println(randn())
            """))
        </code></pre>
        <pre><code class=\"plaintext code-output\">$b</code></pre>
        <pre><code class="language-julia">
            $(F.htmlesc(raw"""
            println(randn())"""))
        </code></pre>
        <pre><code class=\"plaintext code-output\">$c</code></pre>
        """)

    # XXX CODE MODIFICATION --> REEVAL OF BLOCK AND AFTER

    foo = raw"""
        @def hascode = true
        ```julia:ex
        println(randn())
        ```
        \output{ex}
        ```julia:ex2
        # modif
        println(randn())
        ```
        \output{ex2}
        ```julia:ex3
        println(randn())
        ```
        \output{ex3}
        """

    h = foo |> fd2html_td

    @test isapproxstr(h, """
        <pre><code class="language-julia">$(F.htmlesc(raw"""
            println(randn())
            """))
        </code></pre>
        <pre><code class=\"plaintext code-output\">$a</code></pre>
        <pre><code class="language-julia">$(F.htmlesc(raw"""
            # modif
            println(randn())
            """))
        </code></pre>
        <pre><code class=\"plaintext code-output\">$d</code></pre>
        <pre><code class="language-julia">$(F.htmlesc(raw"""
            println(randn())
            """))
        </code></pre>
        <pre><code class=\"plaintext code-output\">$e</code></pre>
        """)
end

@testset "EvalOrder2" begin
    flush_td(); set_globals()

    # Inserting new code block
    h = raw"""
        @def hascode = true
        ```julia:ex1
        a = 5
        println(a)
        ```
        \output{ex1}
        ```julia:ex2
        a += 3
        println(a)
        ```
        \output{ex2}
        """ |> fd2html_td

    @test isapproxstr(h, """
            <pre><code class="language-julia">$(F.htmlesc(raw"""
                a = 5
                println(a)
                """))
            </code></pre>
            <pre><code class=\"plaintext code-output\">5</code></pre>
            <pre><code class="language-julia">$(F.htmlesc(raw"""
                a += 3
                println(a)
                """))
            </code></pre>
            <pre><code class=\"plaintext code-output\">8</code></pre>
            """)

    h = raw"""
        @def hascode = true
        @def reeval  = true
        ```julia:ex1
        a = 5
        println(a)
        ```
        \output{ex1}
        ```julia:ex1b
        a += 1
        println(a)
        ```
        \output{ex1b}
        ```julia:ex2
        a += 3
        println(a)
        ```
        \output{ex2}
        """ |> fd2html_td

    @test isapproxstr(h, """
            <pre><code class="language-julia">$(F.htmlesc(raw"""
                a = 5
                println(a)
                """))
            </code></pre>
            <pre><code class=\"plaintext code-output\">5</code></pre>
            <pre><code class="language-julia">$(F.htmlesc(raw"""
                a += 1
                println(a)
                """))
            </code></pre>
            <pre><code class=\"plaintext code-output\">6</code></pre>
            <pre><code class="language-julia">$(F.htmlesc(raw"""
                a += 3
                println(a)
                """))
            </code></pre>
            <pre><code class=\"plaintext code-output\">9</code></pre>
            """)
end

# https://github.com/JuliaDocs/Franklin.jl/issues/832
@testset "#832" begin
    s = """
       ```!
       x=5 # a
       ```
       """ |> F.fd2html
    @test isapproxstr(s, """
        <pre><code class="language-julia">x&#61;5 # a</code></pre>
        <pre><code class="plaintext code-output">5</code></pre>
        """)
    s = """
       ```!
       x=5; # a
       ```
       """ |> F.fd2html
    @test isapproxstr(s, """
        <pre><code class=\"language-julia\">x&#61;5; # a</code></pre>
        """)
end
