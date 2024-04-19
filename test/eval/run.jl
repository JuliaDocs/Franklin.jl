@testset "parse_code" begin
    c = """
    a = 7
    println(a); a^2
    """
    exs = F.parse_code(c)
    @test exs[1] == :(a=7)
    @test exs[2].args[1] == :(println(a))
    @test exs[2].args[2] == :(a ^ 2)
    # invalid code is fine
    c = """
    a = 7
    f = foo(a = 3
    """
    exs = F.parse_code(c)
    @test exs[1] == :(a = 7)
    @test exs[2].head == :incomplete
    if VERSION < v"1.10"
        @test exs[2].args[1] == "incomplete: premature end of input"
    end
    # empty code
    c = ""
    exs = F.parse_code(c)
    @test isempty(exs)
end

@testset "run_code" begin
    mn  = F.modulename("foo/path.md")
    mod1 = F.newmodule(mn)
    junk = tempname()

    # empty code
    c = ""
    @test isnothing(F.run_code(mod1, c, junk))

    # code with no print
    c = """
        const a = 5
        a^2
        """
    r = F.run_code(mod1, c, junk)
    @test r == 25
    @test isempty(read(junk, String))

    # code with print
    c = """
        using Random
        Random.seed!(555)
        println("hello")
        b = randn()
        iszero(b)
        """
    r = F.run_code(mod1, c, junk)

    @test r == false
    @test read(junk, String) == "hello\n"

    # code with show
    c = """
        x = 5
        @show x
        y = 7;
        """
    r = F.run_code(mod1, c, junk)
    @test isnothing(r)
    @test read(junk, String) == "x = 5\n"

    # code with error
    c = """
        e = 0
        a = sqrt(-1)
        b = 7
        """

    s = @capture_out F.run_code(mod1, c, junk)
    @test occursin("Warning: in <input string>", s)
    @test occursin("error of type 'DomainError'", s)
    @test !occursin("(::Franklin.var", s)
end

@testset "i462" begin
    s = raw"""
       A
       ```julia:ex
       1 # hide
       ```
       \show{ex}

       B""" |> fd2html_td
    @test isapproxstr(s, """
        <p>A</p>
        <pre><code class="plaintext code-output">1</code></pre>
        <p>B</p>
        """)
    s = raw"""
       A
       ```julia:ex
       "hello" # hide
       ```
       \show{ex}

       B""" |> fd2html_td
    @test isapproxstr(s, """
        <p>A</p>
        <pre><code class="plaintext code-output">"hello"</code></pre>
        <p>B</p>
        """)
end

@testset "trim_stacktrace" begin
    @test rstrip(F.trim_stacktrace("""
        Stacktrace:
            [1] f()
            [2] top-level scope
        """)) == """
        Stacktrace:
            [1] f()"""
    @test F.trim_stacktrace("unrecognized pattern") == "unrecognized pattern"
end
