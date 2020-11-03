# see also https://github.com/tlienart/Franklin.jl/issues/330
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
         <pre><code class="plaintext">12</code></pre>
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
        """ |> fd2html
    @test isapproxstr(a, """
            <p>A</p>

            <pre><code class="language-julia">
            x &#61; 1
            </code></pre>
            <pre><code class="plaintext">1</code></pre>

            <p>B</p>

            <pre><code class="language-julia">print&#40;x&#41;</code></pre>
            <pre><code class="plaintext">1</code></pre>
            """)
end
