# environments
# ------------
# - images
# - headers
# - links
# - code inline
# - code blocks
# - maths inline
# - maths blocks
# - div blocks
# - lx commands
# - hfun commands
# - tables
# - admonition (is it a thing?)
# - blockquotes
# - escaped blocks
# - def blocks
# - indented blocks
# - lists
# - raw html inclusion
# - raw html block with separating line
# - footnotes
# - citations

F.def_GLOBAL_VARS!()

@testset "close:headers" begin
    h = """
    A
    # H
    B
    """ |> fd2html
    @test h // """
        <p>A</p>
        <h1 id="h"><a href="#h" class="header-anchor">H</a></h1>
        <p>B</p>"""
    h = """
    A
    # H1
    ## H2
    B
    ## H2
    C
    """ |> fd2html
    @test h // """
        <p>A</p>
        <h1 id="h1"><a href="#h1" class="header-anchor">H1</a></h1>
        <h2 id="h2"><a href="#h2" class="header-anchor">H2</a></h2>
        <p>B</p>
        <h2 id="h2__2"><a href="#h2__2" class="header-anchor">H2</a></h2>
        <p>C</p>"""
end

@testset "close:div" begin
    h = """
    A
    @@b,c D @@
    E
    """ |> fd2html
    @test h // """
        <p>A</p>
        <div class="b c">D</div>
        <p>E</p>"""
end

# NOTE: will fail upon use of CommonMark (list)
@testset "close:list+i" begin
    h = """
    A
    * B
    * `C`
    E
    """ |> fd2html
    @test h // (VERSION < v"1.14.0-" ? """
        <p>A</p>
        <ul>
        <li><p>B</p>
        </li>
        <li><p><code>C</code></p>
        </li>
        </ul>
        <p>E</p>""" : """
        <p>A</p>
        <ul>
        <li>B</li>
        <li><code>C</code></li>
        </ul>
        <p>E</p>""")
end


@testset "ending p" begin
    # Franklin.LOGGING[] = true
    h = raw"""
    @def date_format = "e, d u Y"
    ```julia:ex1
    #hideall
    using Dates
    println(Franklin.fd_date(DateTime("1996-01-01T12:30:00")))
    ```
    A \textoutput{ex1} B
    """ |> fd2html
    @test h // "<p>A Mon, 1 Jan 1996 B</p>"
end
