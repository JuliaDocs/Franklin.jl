# see also https://github.com/JuliaDocs/Franklin.jl/issues/330
@testset "locvar" begin
    s = raw"""
        @def va = 5
        @def vb = 7
        ```julia:ex
        #hideall
        println(locvar("va")+locvar("vb"))
        ```
        \output{ex}
        """ |> fd2html_td
    @test isapproxstr(s, """
         <pre><code class="plaintext code-output">12</code></pre>
        """)
end


@testset "shortcut" begin
    a = """
        A
        ```!
        x = 1
        ```
        B
        ```!
        print(x)
        ```
        """ |> fd2html_td
    @test isapproxstr(a, """
            <p>A</p>

            <pre><code class="language-julia">
            x &#61; 1
            </code></pre>
            <pre><code class="plaintext code-output">1</code></pre>

            <p>B</p>

            <pre><code class="language-julia">print&#40;x&#41;</code></pre>
            <pre><code class="plaintext code-output">1</code></pre>
            """)
end


@testset "#697" begin
    a = """
        A
        ```!
        x = :ab
        ```
        B
        ```!
        x = :(a+b)
        ```
        C
        """ |> fd2html_td
    @test isapproxstr(a, """
        <p>A</p>
        <pre><code class="language-julia">x &#61; :ab</code></pre>
        <pre><code class="plaintext code-output">:ab</code></pre>
        <p>B</p>
        <pre><code class="language-julia">x &#61; :&#40;a&#43;b&#41;</code></pre>
        <pre><code class="plaintext code-output">:(a + b)</code></pre>
        <p>C</p>
        """)
end
