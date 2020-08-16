@testset "Paginate" begin
    gotd()

    write(joinpath(td, "config.md"), "@def aa = 5")
    mkpath(joinpath(td, "_css"))
    mkpath(joinpath(td, "_layout"))
    write(joinpath(td, "_layout", "head.html"), "HEAD\n")
    write(joinpath(td, "_layout", "foot.html"), "\nFOOT\n")
    write(joinpath(td, "_layout", "page_foot.html"), "\nPG_FOOT\n")
    write(joinpath(td, "index.md"), raw"""
        @def el = ("a", "b", "c", "d")
        ~~~<ul>~~~
        {{paginate el 2}}
        ~~~</ul>~~~
        """)
    write(joinpath(td, "foo.md"), raw"""
        @def a = ["<li>Item $i</li>" for i in 1:10]
        Some content
        ~~~<ul>~~~
        {{paginate a 4}}
        ~~~</ul>~~~
        """)
    serve(single=true)
    # expected outputs for index
    @test isfile(joinpath("__site", "index.html"))
    @test isfile(joinpath("__site", "1", "index.html"))
    @test isfile(joinpath("__site", "2", "index.html"))
    @test isfile(joinpath("__site", "foo", "index.html"))
    @test isfile(joinpath("__site", "foo", "1", "index.html"))
    @test isfile(joinpath("__site", "foo", "2", "index.html"))
    @test isfile(joinpath("__site", "foo", "3", "index.html"))
    # expected content
    @test read(joinpath("__site", "index.html"), String) // """
        HEAD
        <div class=\"franklin-content\"><p><ul> ab </ul></p>

        PG_FOOT
        </div>
        FOOT"""
    @test read(joinpath("__site", "2", "index.html"), String) // """
        HEAD
        <div class=\"franklin-content\"><p><ul> cd </ul></p>

        PG_FOOT
        </div>
        FOOT"""
    @test read(joinpath("__site", "foo", "1", "index.html"), String) // """
        HEAD
        <div class=\"franklin-content\"><p>Some content <ul> <li>Item 1</li><li>Item 2</li><li>Item 3</li><li>Item 4</li> </ul></p>

        PG_FOOT
        </div>
        FOOT"""
    @test read(joinpath("__site", "foo", "3", "index.html"), String) // """
        HEAD
        <div class=\"franklin-content\"><p>Some content <ul> <li>Item 9</li><li>Item 10</li> </ul></p>

        PG_FOOT
        </div>
        FOOT"""

    # WARNINGS
    write(joinpath(td, "foo.md"), raw"""
        @def a = ["<li>Item $i</li>" for i in 1:10]
        Some content
        {{paginate abc 4}}
        """)
    @test_logs (:warn, "In a {{paginate ...}} block, I couldn't recognise the name of the iterable. Nothing will get printed as a result.") serve(single=true)
    write(joinpath(td, "foo.md"), raw"""
        @def a = ["<li>Item $i</li>" for i in 1:10]
        Some content
        {{paginate a iehva}}
        """)
    @test_logs (:warn, "In a {{paginate ...}} block, I couldn't parse the number of items per page. Defaulting to 10.") serve(single=true)
    write(joinpath(td, "foo.md"), raw"""
        @def a = ["<li>Item $i</li>" for i in 1:10]
        Some content
        {{paginate a -5}}
        """)
    @test_logs (:warn, "In a {{paginate ...}} block, the number of items per page is non-positive, defaulting to 10.") serve(single=true)
    write(joinpath(td, "foo.md"), raw"""
        @def a = ["<li>Item $i</li>" for i in 1:10]
        Some content
        ~~~<ul>~~~
        {{paginate a 4}}
        ~~~</ul>~~~
        ~~~<ul>~~~
        {{paginate a 4}}
        ~~~</ul>~~~
        """)
    @test_logs (:warn, "It looks like you have multiple calls to {{paginate ...}} on the page; only one is supported. Verify.") serve(single=true)

    # ERRORS
    write(joinpath(td, "foo.md"), raw"""
        @def a = ["<li>Item $i</li>" for i in 1:10]
        Some content
        ~~~<ul>~~~
        {{paginate a}}
        ~~~</ul>~~~
        """)
    @test_throws Franklin.HTMLFunctionError serve(single=true)

end
