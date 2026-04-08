@testset "sitemap" begin
    @testset "strip index.html (default)" begin
        F.def_GLOBAL_VARS!()
        F.set_var!(F.GLOBAL_VARS, "website_url", "https://example.com")
        F.set_var!(F.GLOBAL_VARS, "sitemap_file", "sitemap")
        empty!(F.SITEMAP_DICT)

        F.SITEMAP_DICT["index.html"] = F.SMOpts(Date(2025, 1, 1), "monthly", 1.0)
        F.SITEMAP_DICT["blog/post/index.html"] = F.SMOpts(Date(2025, 6, 15), "monthly", 0.5)

        site_dir = mktempdir()
        F.PATHS[:site] = site_dir
        F.sitemap_generator()
        content = read(joinpath(site_dir, "sitemap.xml"), String)

        @test !occursin("index.html", content)
        @test occursin("blog/post/", content)
    end

    @testset "preserve index.html when opted out" begin
        F.def_GLOBAL_VARS!()
        F.set_var!(F.GLOBAL_VARS, "website_url", "https://example.com")
        F.set_var!(F.GLOBAL_VARS, "sitemap_file", "sitemap")
        F.set_var!(F.GLOBAL_VARS, "sitemap_strip_index", false)
        empty!(F.SITEMAP_DICT)

        F.SITEMAP_DICT["blog/post/index.html"] = F.SMOpts(Date(2025, 6, 15), "monthly", 0.5)

        site_dir = mktempdir()
        F.PATHS[:site] = site_dir
        F.sitemap_generator()
        content = read(joinpath(site_dir, "sitemap.xml"), String)

        @test occursin("index.html", content)
    end

    @testset "depth-based priority" begin
        @test F.default_sitemap_priority("index.html") == 1.0
        @test F.default_sitemap_priority("") == 1.0
        @test F.default_sitemap_priority("blog/index.html") == 0.8
        @test F.default_sitemap_priority("papers/index.html") == 0.8
        @test F.default_sitemap_priority("blog/2025/post/index.html") == 0.5
    end
end
