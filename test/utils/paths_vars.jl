const td = mktempdir()
flush_td() = (isdir(td) && rm(td; recursive=true); mkdir(td))
F.FOLDER_PATH[] = td

fd2html_td(e)  = fd2html(e; dir=td)
fd2html_tdv(e) = F.fd2html_v(e; dir=td)

F.def_GLOBAL_VARS!()
F.def_GLOBAL_LXDEFS!()

@testset "Paths" begin
    P = F.set_paths!()

    @test F.PATHS[:folder]   == td
    @test F.PATHS[:src]      == joinpath(td, "src")
    @test F.PATHS[:src_css]  == joinpath(td, "src", "_css")
    @test F.PATHS[:src_html] == joinpath(td, "src", "_html_parts")
    @test F.PATHS[:libs]     == joinpath(td, "libs")
    @test F.PATHS[:pub]      == joinpath(td, "pub")
    @test F.PATHS[:css]      == joinpath(td, "css")

    @test P == F.PATHS

    mkdir(F.PATHS[:src])
    mkdir(F.PATHS[:src_pages])
    mkdir(F.PATHS[:libs])
    mkdir(F.PATHS[:src_css])
    mkdir(F.PATHS[:src_html])
    mkdir(F.PATHS[:assets])
end

# copying _libs/katex in the F.PATHS[:libs] so that it can be used in testing
# the js_prerender_math
cp(joinpath(dirname(dirname(pathof(Franklin))), "test", "_libs", "katex"), joinpath(F.PATHS[:libs], "katex"))

@testset "Set vars" begin
    d = F.PageVars(
    	"a" => 0.5 => (Real,),
    	"b" => "hello" => (String, Nothing))
    F.set_vars!(d, ["a"=>"5", "b"=>"nothing"])

    @test d["a"].first == 5
    @test d["b"].first === nothing

    @test_logs (:warn, "Page var 'a' (type(s): (Real,)) can't be set to value 'blah' (type: String). Assignment ignored.") F.set_vars!(d, ["a"=>"\"blah\""])

    @test_throws F.PageVariableError F.set_vars!(d, ["a"=> "sqrt(-1)"])

    # assigning new variables

    F.set_vars!(d, ["blah"=>"1"])
    @test d["blah"].first == 1
end

@testset "Def+coms" begin # see #78
    st = raw"""
        @def title = "blah" <!-- comment -->
        @def hasmath = false
        etc
        """
    m = F.convert_md(st)
    @test F.locvar("title") == "blah"
    @test F.locvar("hasmath") == false
end
