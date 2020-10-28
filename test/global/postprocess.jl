@testset "Gen&Opt" begin
    isdir("basic") && rm("basic", recursive=true, force=true)
    newsite("basic")

    global silly_call = 0
    function foo_on_write(pg, vars)
        global silly_call
        silly_call += length(pg)
        vars["fd_rpath"] # should not error
        return nothing
    end

    serve(single=true, on_write=foo_on_write)

    @test silly_call > 0

    # ---------------
    @test all(isdir, ("_assets", "_css", "_libs", "_layout", "__site"))
    @test isfile(joinpath("__site", "index.html"))
    @test isfile(joinpath("__site", "menu1", "index.html"))
    @test isfile(joinpath("__site", "menu2", "index.html"))
    @test isfile(joinpath("__site", "menu3", "index.html"))
    @test isfile(joinpath("__site", "css", "basic.css"))
    @test isfile(joinpath("__site", "css", "franklin.css"))

    # ---------------
    if Franklin.FD_CAN_MINIFY
        presize1 = stat(joinpath("__site", "css", "basic.css")).size
        presize2 = stat(joinpath("__site", "index.html")).size
        optimize(prerender=false)
        @test stat(joinpath("__site", "css", "basic.css")).size < presize1
        @test stat(joinpath("__site", "index.html")).size < presize2
    end
    # ---------------
    # verify all links
    Franklin.verify_links()

    # ---------------
    # change the prepath
    index = read(joinpath("__site","index.html"), String)
    @test occursin("=\"/css/basic.css", index)
    @test occursin("=\"/css/franklin.css", index)
    @test occursin("=\"/libs/highlight/github.min.css", index)
    @test occursin("=\"/libs/katex/katex.min.css", index)

    optimize(minify=false, prerender=false, prepath="prependme")
    index = read(joinpath("__site","index.html"), String)
    @test occursin("=\"/prependme/css/basic.css", index)
    @test occursin("=\"/prependme/css/franklin.css", index)
    @test occursin("=\"/prependme/libs/highlight/github.min.css", index)
    @test occursin("=\"/prependme/libs/katex/katex.min.css", index)
end

if F.FD_CAN_PRERENDER; @testset "prerender" begin
    @testset "katex" begin
        hs = raw"""
        <!doctype html>
        <html lang=en>
        <meta charset=UTF-8>
        <div class=franklin-content>
        <p>range is \(10\sqrt{3}\)–\(20\sqrt{2}\) <!-- non-ascii en dash --></p>
        <p>Consider an invertible matrix \(M\) made of blocks \(A\), \(B\), \(C\) and \(D\) with</p>
        \[ M \quad\!\! =\quad\!\! \begin{pmatrix} A & B \\ C & D \end{pmatrix} \]
        </div>
        """

        jskx = F.js_prerender_katex(hs)
        # conversion of the non-ascii endash (inline)
        @test occursin("""–<span class=\"katex\">""", jskx)
        # # conversion of `\(M\)` (inline)
        # @test occursin("""<span class=\"katex\"><span class=\"katex-mathml\"><math xmlns=\"http://www.w3.org/1998/Math/MathML\"><semantics><mrow><mi>M</mi></mrow>""", jskx)
        # # conversion of the equation (display)
        # @test occursin("""<span class=\"katex-display\"><span class=\"katex\"><span class=\"katex-mathml\"><math xmlns=\"http://www.w3.org/1998/Math/MathML\"><semantics><mrow><mi>M</mi>""", jskx)
    end

    if F.FD_CAN_HIGHLIGHT; @testset "highlight" begin
        hs = raw"""
        <!doctype html>
        <html lang=en>
        <meta charset=UTF-8>
        <div class=franklin-content>
        <h1>Title</h1>
        <p>Blah</p>
        <pre><code class=language-julia >using Test
        # Woodbury formula
        b = 2
        println("hello $b")
        </code></pre>
        </div>
        """
        jshl = F.js_prerender_highlight(hs)
        # conversion of the code
        @test occursin("""<pre><code class="julia hljs"><span class="hljs-keyword">using</span>""", jshl)
        @test occursin(raw"""<span class=\"hljs-comment\"># Woodbury formula</span>""", jshl)
    end; end # if can highlight
end; end # if can prerender
