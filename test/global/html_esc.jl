# See https://github.com/JuliaDocs/Franklin.jl/issues/326

@testset "Issue 326" begin
    h1 = "<div class=\"hello\">Blah</div>"
    h1e = Markdown.htmlesc(h1)
    @test F.is_html_escaped(h1e)
    @test F.html_unescape(h1e) == h1
end
