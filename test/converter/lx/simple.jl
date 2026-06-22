fs()

@testset "figalt, fig" begin
    mkpath(joinpath(F.PATHS[:site], "assets"))
    write(joinpath(F.PATHS[:site], "assets", "testimg.png"), "png code")
    h = raw"""
        A figure:
        \figalt{fig 1}{/assets/testimg.png}
        \fig{/assets/testimg.png}
        \fig{/assets/testimg}
        Done.
        """ |> seval
    @test isapproxstr(h, """
            <p>A figure:
            <img src=\"/assets/testimg.png\" alt=\"fig 1\">
            <img src=\"/assets/testimg.png\" alt=\"\">
            <img src=\"/assets/testimg.png\" alt=\"\">
            Done.</p>
            """)
    p = mkpath(joinpath(F.PATHS[:site], "assets", "output"))
    write(joinpath(p, "testimg_2.png"), "png code")
    h = raw"""
        Another figure:
        \figalt{fig blah "hello!"}{/assets/testimg_2.png}
        """ |> seval
    @test isapproxstr(h, """
            <p>Another figure:
            <img src=\"/assets/output/testimg_2.png\" alt=\"fig blah $(F.htmlesc("\"hello!\""))\">
            </p>
            """)
    h = raw"""
        No fig:
        \fig{/assets/testimg_3.png}
        """ |> seval
    @test isapproxstr(h, """
            <p>No fig: $(F.html_err("Image matching '/assets/testimg_3.png' not found."))</p>
            """)
end

@testset "table" begin
    #
    # has header in source
    #
    testcsv = "h1,h2,h3\nstring1, 1.567, 0\n,,\n l i n e ,.158,99999999"
    write(joinpath(F.PATHS[:site], "assets", "testcsv.csv"), testcsv)
    # no header specified
    h = raw"""
        A table:
        \tableinput{}{/assets/testcsv.csv}
        Done.
        """ |> seval

    # NOTE: in VERSION > 1.4, Markdown has alignment for tables:
    # -- https://github.com/JuliaLang/julia/pull/33849
    if VERSION >= v"1.4.0-"
        shouldbe = """
            <p>A table:
            <table>
              <tr><th align="right">h1</th><th align="right">h2</th><th align="right">h3</th></tr>
              <tr><td align="right">string1</td><td align="right">1.567</td><td align="right">0</td></tr>
              <tr><td align="right"></td><td align="right"></td><td align="right"></td></tr>
              <tr><td align="right">l i n e</td><td align="right">.158</td><td align="right">99999999</td></tr>
            </table>
            Done.</p>"""
    else
        shouldbe = """
            <p>A table:
            <table>
              <tr><th>h1</th><th>h2</th><th>h3</th></tr>
              <tr><td>string1</td><td>1.567</td><td>0</td></tr>
              <tr><td></td><td></td><td></td></tr>
              <tr><td>l i n e</td><td>.158</td><td>99999999</td></tr>
            </table>
            Done.</p>"""
    end
    @test isapproxstr(h, shouldbe)
    # header specified
    h = raw"""
        A table:
        \tableinput{A,B,C}{/assets/testcsv.csv}
        Done.
        """ |> seval
    if VERSION >= v"1.4.0-"
        shouldbe = """
            <p>A table:
            <table>
              <tr><th align="right">A</th><th align="right">B</th><th align="right">C</th></tr>
              <tr><td align="right">h1</td><td align="right">h2</td><td align="right">h3</td></tr>
              <tr><td align="right">string1</td><td align="right">1.567</td><td align="right">0</td></tr>
              <tr><td align="right"></td><td align="right"></td><td align="right"></td></tr>
              <tr><td align="right">l i n e</td><td align="right">.158</td><td align="right">99999999</td></tr>
            </table>
            Done.</p>"""
    else
        shouldbe = """
            <p>A table:
            <table>
              <tr><th>A</th><th>B</th><th>C</th></tr>
              <tr><td>h1</td><td>h2</td><td>h3</td></tr>
              <tr><td>string1</td><td>1.567</td><td>0</td></tr>
              <tr><td></td><td></td><td></td></tr>
              <tr><td>l i n e</td><td>.158</td><td>99999999</td></tr>
            </table>
            Done.</p>"""
    end
    @test isapproxstr(h, shouldbe)
    # wrong header
    h = raw"""
        A table:
        \tableinput{,}{/assets/testcsv.csv}
        Done.
        """ |> seval
    shouldbe = """<p>A table: <p><span style=\"color:red;\">// In `\\tableinput`: header size (2) and number of columns (3) do not match. //</span></p>
            Done.</p>"""
    @test isapproxstr(h, shouldbe)

    #
    # does not have header in source
    #

    testcsv = "string1, 1.567, 0\n,,\n l i n e ,.158,99999999"
    write(joinpath(F.PATHS[:site], "assets", "testcsv.csv"), testcsv)
    # no header specified
    h = raw"""
        A table:
        \tableinput{}{/assets/testcsv.csv}
        Done.
        """ |> seval
    if VERSION >= v"1.4.0-"
        shouldbe = """
            <p>A table:
            <table>
              <tr><th align="right">string1</th><th align="right">1.567</th><th align="right">0</th></tr>
              <tr><td align="right"></td><td align="right"></td><td align="right"></td></tr>
              <tr><td align="right">l i n e</td><td align="right">.158</td><td align="right">99999999</td></tr>
            </table>
            Done.</p>"""
    else
        shouldbe = """
            <p>A table:
            <table>
              <tr><th>string1</th><th>1.567</th><th>0</th></tr>
              <tr><td></td><td></td><td></td></tr>
              <tr><td>l i n e</td><td>.158</td><td>99999999</td></tr>
            </table>
            Done.</p>"""
    end
    @test isapproxstr(h, shouldbe)
    # header specified
    h = raw"""
        A table:
        \tableinput{A,B,C}{/assets/testcsv.csv}
        Done.
        """ |> seval

    if VERSION >= v"1.4.0-"
        shouldbe = """
            <p>A table: <table><tr><th align="right">A</th><th align="right">B</th><th align="right">C</th></tr><tr><td align="right">string1</td><td align="right">1.567</td><td align="right">0</td></tr><tr><td align="right"></td><td align="right"></td><td align="right"></td></tr><tr><td align="right">l i n e</td><td align="right">.158</td><td align="right">99999999</td></tr></table>
            Done.</p>"""
    else
        shouldbe = """<p>A table: <table><tr><th>A</th><th>B</th><th>C</th></tr>
                <tr><td>string1</td><td>1.567</td><td>0</td></tr>
                <tr><td></td><td></td><td></td></tr>
                <tr><td>l i n e</td><td>.158</td><td>99999999</td></tr></table>
                Done.</p>"""
    end
    @test isapproxstr(h, shouldbe)
    # wrong header
    h = raw"""
        A table:
        \tableinput{A,B}{/assets/testcsv.csv}
        Done.
        """ |> seval

    shouldbe = """<p>A table: <p><span style=\"color:red;\">// In `\\tableinput`: header size (2) and number of columns (3) do not match. //</span></p>
            Done.</p>"""
    @test isapproxstr(h, shouldbe)
end
