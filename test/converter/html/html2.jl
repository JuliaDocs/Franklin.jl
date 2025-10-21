@testset "Non-nested" begin
    F.set_vars!(F.LOCAL_VARS, [
        "a" => "false",
        "b" => "false"])

    hs = """A{{if a}}B{{elseif b}}C{{else}}D{{end}}E"""

    tokens          = F.find_tokens(hs, F.HTML_TOKENS, F.HTML_1C_TOKENS)
    hblocks, tokens = F.find_all_ocblocks(tokens, F.HTML_OCB)
    qblocks         = F.qualify_html_hblocks(hblocks)

    F.set_vars!(F.LOCAL_VARS, ["a"=>"true","b"=>"false"])
    fhs = F.process_html_qblocks(hs, qblocks)
    @test isapproxstr(fhs, "ABE")

    F.set_vars!(F.LOCAL_VARS, ["a"=>"false","b"=>"true"])
    fhs = F.process_html_qblocks(hs, qblocks)
    @test isapproxstr(fhs, "ACE")

    F.set_vars!(F.LOCAL_VARS, ["a"=>"false","b"=>"false"])
    fhs = F.process_html_qblocks(hs, qblocks)
    @test isapproxstr(fhs, "ADE")
end

@testset "Nested" begin
    F.def_LOCAL_VARS!()
    F.set_vars!(F.LOCAL_VARS, [
        "a" => "false",
        "b" => "false",
        "c" => "false"])

    hs = """A {{if a}} B {{elseif b}} C {{if c}} D {{end}} {{else}} E {{end}} F"""

    tokens          = F.find_tokens(hs, F.HTML_TOKENS, F.HTML_1C_TOKENS)
    hblocks, tokens = F.find_all_ocblocks(tokens, F.HTML_OCB)
    qblocks         = F.qualify_html_hblocks(hblocks)

    F.set_vars!(F.LOCAL_VARS, ["a"=>"true"])
    fhs = F.process_html_qblocks(hs, qblocks)
    @test isapproxstr(fhs, "ABF")

    F.set_vars!(F.LOCAL_VARS, ["a"=>"false", "b"=>"true", "c"=>"false"])
    fhs = F.process_html_qblocks(hs, qblocks)
    @test isapproxstr(fhs, "ACF")

    F.set_vars!(F.LOCAL_VARS, ["a"=>"false", "b"=>"true", "c"=>"true"])
    fhs = F.process_html_qblocks(hs, qblocks)
    @test isapproxstr(fhs, "ACDF")

    F.set_vars!(F.LOCAL_VARS, ["a"=>"false", "b"=>"false"])
    fhs = F.process_html_qblocks(hs, qblocks)
    @test isapproxstr(fhs, "AEF")
end

# https://github.com/JuliaDocs/Franklin.jl/issues/731
@testset "hfun strings" begin
    a = Franklin.split_hfun_parameters(strip("""
        "Hello to you" my "julia friends" and "all the others"
        """))
    @test a[1] == "Hello to you"
    @test a[2] == "my"
    @test a[3] == "julia friends"
    @test a[4] == "and"
    @test a[5] == "all the others"
end