@testset "Sitemap gen" begin
    f = joinpath(p, "basic", "__site", "sitemap.xml")
    @test isfile(f)
    fc = prod(readlines(f, keep=true))

    @test occursin(raw"""
        <?xml version="1.0" encoding="utf-8" standalone="yes" ?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">""", fc)
    # check pages
    for pg in ("", "menu1", "menu2", "menu3")
        pgg = joinpath(pg, "index.html")
        @test occursin("""
            <loc>https://juliadocs.org/FranklinTemplates.jl/$pgg</loc>""", fc)
    end
end

@testset "Robots.txt gen" begin
    f = joinpath(p, "basic", "__site", "robots.txt")
    @test isfile(f)
    fc = prod(readlines(f, keep=true))

    @test occursin(raw"""
        Sitemap: https://juliadocs.org/FranklinTemplates.jl/sitemap.xml""", fc)
end
