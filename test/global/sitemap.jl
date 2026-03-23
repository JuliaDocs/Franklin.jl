@testset "Sitemap gen" begin
    f = joinpath(p, "basic", "__site", "sitemap.xml")
    @test isfile(f)
    fc = prod(readlines(f, keep=true))

    @test occursin(raw"""
        <?xml version="1.0" encoding="utf-8" standalone="yes" ?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">""", fc)
    # check pages (default: index.html stripped from URLs)
    for pg in ("", "menu1", "menu2", "menu3")
        slug = isempty(pg) ? "" : "$pg/"
        @test occursin("""
            <loc>https://tlienart.github.io/FranklinTemplates.jl/$slug</loc>""", fc)
    end
    @test !occursin("index.html", fc)
end

@testset "Robots.txt gen" begin
    f = joinpath(p, "basic", "__site", "robots.txt")
    @test isfile(f)
    fc = prod(readlines(f, keep=true))

    @test occursin(raw"""
        Sitemap: https://tlienart.github.io/FranklinTemplates.jl/sitemap.xml""", fc)
end
