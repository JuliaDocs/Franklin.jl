### LX_PAT
@testset "latex" begin
    for s in (
            raw"\com",
            raw"  \com ",
        )
        m = match(F.LX_NAME_PAT, s)
        @test m.captures[1] == raw"\com"
    end
    for s in (
            raw"\cöm",
            raw"  \cöm ",
        )
        m = match(F.LX_NAME_PAT, s)
        @test m.captures[1] == raw"\cöm"
    end
    m = match(F.LX_NAME_PAT, raw"\com*")
    @test m.captures[1] == raw"\com*"
    for s in (
            raw"[2]",
            raw" [2] ",
            raw" [ 2]",
            raw" [ 2 ] "
        )
        m = match(F.LX_NARG_PAT, s)
        @test m.captures[2] == "2"
    end
end

### Assign pat
@testset "assign" begin
    for s in (
            raw"cöm_012 = blah",
        )
        m = match(F.ASSIGN_PAT, s)
        @test m.captures[1] == raw"cöm_012"
        @test strip(m.captures[2]) == raw"blah"
    end
end

### LINK
@testset "esclink" begin
    s = F.htmlesc("[hello]")
    a,b,c = match(F.ESC_LINK_PAT, s).captures
    @test isnothing(a)
    @test b == "hello"
    @test isnothing(c)
    s = F.htmlesc("[hello][]")
    a,b,c = match(F.ESC_LINK_PAT, s).captures
    @test isnothing(a)
    @test b == "hello"
    @test isempty(c)
    s = F.htmlesc("[hello][id]")
    a,b,c = match(F.ESC_LINK_PAT, s).captures
    @test isnothing(a)
    @test b == "hello"
    @test c == "id"
    s = F.htmlesc("![hello][id]")
    a,b,c = match(F.ESC_LINK_PAT, s).captures
    @test a == F.htmlesc("!")
    @test b == "hello"
    @test c == "id"
    s = F.htmlesc("[hello]:")
    @test isnothing(match(F.ESC_LINK_PAT, s))
end

@testset "fndef" begin
    for s in (
            raw"[^örα_01]:",
        )
        m = match(F.FN_DEF_PAT, s)
        @test !isnothing(m)
    end
end

### HTML ENTITY
@testset "html-ent" begin
    for s in (
        "&tab;",
     	"&newline;",
        "&excl;",
        "&quot;",
        "&#x00009;",
        "&#x00027;",
        "&#39;",
        "&#58;",
        "&#123;",
        "&ccirc;",
        "&#x00107;",
        "&#263;"
        )
        @test !isnothing(match(F.HTML_ENT_PAT, s))
    end
end

### Code blocks
@testset "code" begin
    list = (
        "```julia:n some code```", # issue 705
        "```julia:ex some code```",
        "```cpp:πγ some code```",
        "```julia:πγ.jl some code```",
        "```julia:./πγ.jl some code```",
        "```julia:./πγ/λη.jl some code```",
        )
    for s in list
        @test !isnothing(match(F.CODE_3_PAT, s))
    end
    for s in list
        @test !isnothing(match(F.CODE_5_PAT, "``$s``"))
    end
    noklist = (
        "```γulia some code```",
        "```julia:0ex some code```",
        )
    for s in noklist
        @test isnothing(match(F.CODE_3_PAT, s))
    end
end

### HBLOCK REGEXES

@testset "hb-if" begin
    for s in (
            "{{if var1}}",
            "{{if  var1 }}",
            "{{ if  var1 }}",
            "&#123;&#123; if var1 &#125;&#125;"
        )
        m = match(F.HBLOCK_IF_PAT, s)
        @test m.captures[1] == "var1"
    end
    for s in (
            "{{if var1 var2}}",
            "{{ifvar1}}"
        )
        m = match(F.HBLOCK_IF_PAT, s)
        @test isnothing(m)
    end
end
@testset "hb-else" begin
    for s in (
            "{{else}}",
            "{{ else}}",
            "{{  else   }}",
            "&#123;&#123; else &#125;&#125;"
        )
        m = match(F.HBLOCK_ELSE_PAT, s)
        @test !isnothing(m)
    end
end
@testset "hb-elseif" begin
    for s in (
            "{{elseif var1}}",
            "{{else if  var1 }}",
            "{{ elseif  var1 }}",
            "&#123;&#123; elseif var1 &#125;&#125;"
        )
        m = match(F.HBLOCK_ELSEIF_PAT, s)
        @test m.captures[1] == "var1"
    end
    for s in (
            "{{else if var1 var2}}",
            "{{elif var1}}"
        )
        m = match(F.HBLOCK_ELSEIF_PAT, s)
        @test isnothing(m)
    end
end
@testset "hb-end" begin
    for s in (
            "{{end}}",
            "{{ end}}",
            "{{  end   }}",
            "&#123;&#123; end &#125;&#125;"
        )
        m = match(F.HBLOCK_END_PAT, s)
        @test !isnothing(m)
    end
end
@testset "hb-isdef" begin
    for s in (
            "{{isdef var1}}",
            "{{ isdef  var1 }}",
            "{{ isdef  var1 }}",
            "{{ ifdef  var1 }}",
            "&#123;&#123; ifdef var1 &#125;&#125;"
        )
        m = match(F.HBLOCK_ISDEF_PAT, s)
        @test m.captures[1] == "var1"
    end
    for s in (
            "{{isdef var1 var2}}",
            "{{is def var1}}",
            "{{if def var1}}"
        )
        m = match(F.HBLOCK_ISDEF_PAT, s)
        @test isnothing(m)
    end
end
@testset "hb-isndef" begin
    for s in (
            "{{isnotdef var1}}",
            "{{ isndef  var1 }}",
            "{{ ifndef  var1 }}",
            "{{ ifnotdef  var1 }}",
            "&#123;&#123; ifndef var1 &#125;&#125;"
        )
        m = match(F.HBLOCK_ISNOTDEF_PAT, s)
        @test m.captures[1] == "var1"
    end
    for s in (
            "{{isnotdef var1 var2}}",
            "{{isnot def var1}}",
            "{{ifn def var1}}"
        )
        m = match(F.HBLOCK_ISNOTDEF_PAT, s)
        @test isnothing(m)
    end
end
@testset "hb-ispage" begin
    for s in (
            "{{ispage var1 var2}}",
            "&#123;&#123; ispage var1 var2 &#125;&#125;"
        )
        m = match(F.HBLOCK_ISPAGE_PAT, s)
        @test m.captures[1] == "var1 var2"
    end
end
@testset "hb-isnotpage" begin
    for s in (
            "{{isnotpage var1 var2}}",
            "&#123;&#123; isnotpage var1 var2 &#125;&#125;"
        )
        m = match(F.HBLOCK_ISNOTPAGE_PAT, s)
        @test m.captures[1] == "var1 var2"
    end
end
@testset "hb-for" begin
    for s in (
            "{{for (v1,v2,v3) in iterate}}",
            "{{for (v1, v2,v3) in iterate}}",
            "{{for ( v1, v2, v3) in iterate}}",
            "{{for ( v1  , v2 , v3 ) in iterate}}",
            "&#123;&#123; for (v1, v2, v3) in iterate &#125;&#125;"
        )
        m = match(F.HBLOCK_FOR_PAT, s)
        @test isapproxstr(m.captures[1], "(v1, v2, v3)")
    end
    s = "{{for v1 in iterate}}"
    m = match(F.HBLOCK_FOR_PAT, s)
    @test isapproxstr(m.captures[1], "v1")

    # WARNING: NOT RECOMMENDED / NEEDS CARE
    s = "{{for v1,v2 in iterate}}"
    m = match(F.HBLOCK_FOR_PAT, s)
    @test isapproxstr(m.captures[1], "v1,v2")
    s = "{{for (v1,v2 in iterate}}"
    m = match(F.HBLOCK_FOR_PAT, s)
    @test isapproxstr(m.captures[1], "(v1,v2")
    s = "{{for v1,v2) in iterate}}"
    m = match(F.HBLOCK_FOR_PAT, s)
    @test isapproxstr(m.captures[1], "v1,v2)")
end
@testset "hb-fun-0" begin
    for s in (
            "{{toc}}",
            "{{ toc }}",
            "&#123;&#123; toc &#125;&#125;"
            )
        m = match(F.HBLOCK_FUN_PAT, s)
        @test m.captures[1] == "toc"
        @test m.captures[2] === nothing || isempty(strip(m.captures[2]))
    end
end
@testset "hb-fun-1" begin
    for s in (
            "{{fun p1}}",
            "{{ fun  p1 }}",
            "&#123;&#123; fun p1 &#125;&#125;"
            )
        m = match(F.HBLOCK_FUN_PAT, s)
        @test m.captures[1] == "fun"
        @test strip(m.captures[2]) == "p1"
    end
end
@testset "hb-fun-2" begin
    for s in (
            "{{fun p1 p2}}",
            "{{ fun  p1 p2 }}"
            )
        m = match(F.HBLOCK_FUN_PAT, s)
        @test m.captures[1] == "fun"
        @test strip(m.captures[2]) == "p1 p2"
    end
end

# ========
# Checkers
# ========
@testset "ch-for" begin
    s = "{{for v in iterate}}"
    m = match(F.HBLOCK_FOR_PAT, s).captures[1]
    @test isnothing(F.check_for_pat(m))
    s = "{{for (v1,v2) in iterate}}"
    m = match(F.HBLOCK_FOR_PAT, s).captures[1]
    @test isnothing(F.check_for_pat(m))
    s = "{{for (v in iterate}}"
    m = match(F.HBLOCK_FOR_PAT, s).captures[1]
    @test_throws F.HTMLBlockError F.check_for_pat(m)
    s = "{{for v1,v2) in iterate}}"
    m = match(F.HBLOCK_FOR_PAT, s).captures[1]
    @test_throws F.HTMLBlockError F.check_for_pat(m)
    s = "{{for v1,v2 in iterate}}"
    m = match(F.HBLOCK_FOR_PAT, s).captures[1]
    @test_throws F.HTMLBlockError F.check_for_pat(m)
end

@testset "fix_links" begin
    F.set_var!(F.GLOBAL_VARS, "prepath", "foo")
    p = """
        url='/bar'
        src="/bar"
        href=/bar
        """ |> F.fix_links
    @test p // """
        url='/foo/bar'
        src="/foo/bar"
        href=/foo/bar
        """
end
