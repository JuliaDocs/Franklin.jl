@testset "Sitemap gen" begin
    f = joinpath(p, "basic", "__site", "sitemap.xml")
    @test isfile(f)
    fc = prod(readlines(f, keep=true))

    @test occursin(raw"""
        <?xml version="1.0" encoding="utf-8" standalone="yes" ?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">""", fc)
    # the base url comes from the template's `website_url`; read it from the
    # generated config rather than hardcoding a host, so the test doesn't break
    # when FranklinTemplates changes it (see #1116 CI).
    cfg = read(joinpath(p, "basic", "config.md"), String)
    website_url = match(r"website_url\s*=\s*\"(.*?)\"", cfg).captures[1]
    # check pages (default: index.html stripped from URLs)
    for pg in ("", "menu1", "menu2", "menu3")
        slug = isempty(pg) ? "" : "$pg/"
        @test occursin("<loc>$(joinpath(website_url, slug))</loc>", fc)
    end
    @test !occursin("index.html", fc)
end

@testset "Robots.txt gen" begin
    f = joinpath(p, "basic", "__site", "robots.txt")
    @test isfile(f)
    fc = prod(readlines(f, keep=true))

    cfg = read(joinpath(p, "basic", "config.md"), String)
    website_url = match(r"website_url\s*=\s*\"(.*?)\"", cfg).captures[1]
    @test occursin("Sitemap: $(joinpath(website_url, "sitemap.xml"))", fc)
end
