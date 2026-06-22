@testset "Hyperref" begin
    st = raw"""
       Some string
       $$ x = x \label{eq 1}$$
       then as per \citet{amari98b} also this \citep{bardenet17} and
       \cite{amari98b, bardenet17}
       Reference to equation: \eqref{eq 1}.

       Then maybe some text etc.

       * \biblabel{amari98b}{Amari and Douglas., 1998} **Amari** and **Douglas**: *Why Natural Gradient*, 1998.
       * \biblabel{bardenet17}{Bardenet et al., 2017} **Bardenet**, **Doucet** and **Holmes**: *On Markov Chain Monte Carlo Methods for Tall Data*, 2017.
    """;

    F.def_GLOBAL_VARS!()
    F.def_GLOBAL_LXDEFS!()

    m = F.convert_md(st)

    h1 = F.refstring("eq 1")
    h2 = F.refstring("amari98b")
    h3 = F.refstring("bardenet17")

    @test haskey(F.PAGE_EQREFS,  h1)
    @test haskey(F.PAGE_BIBREFS, h2)
    @test haskey(F.PAGE_BIBREFS, h3)

    @test F.PAGE_EQREFS[h1]  == 1 # first equation
    @test F.PAGE_BIBREFS[h2] == "Amari and Douglas., 1998"
    @test F.PAGE_BIBREFS[h3] == "Bardenet et al., 2017"

    h = F.convert_html(m)

    # newer Markdown renders tight list items without wrapping <p> tags
    bib = VERSION < v"1.14.0-" ? """
        <ul>
          <li><p><a id="$h2" class=\"anchor\"></a>
            <strong>Amari</strong> and <strong>Douglas</strong>: <em>Why Natural Gradient</em>, 1998.</p>
          </li>
          <li><p><a id="$h3" class=\"anchor\"></a>
            <strong>Bardenet</strong>, <strong>Doucet</strong> and <strong>Holmes</strong>: <em>On Markov Chain Monte Carlo Methods for Tall Data</em>, 2017.</p>
          </li>
        </ul>
        """ : """
        <ul>
          <li><a id="$h2" class=\"anchor\"></a>
            <strong>Amari</strong> and <strong>Douglas</strong>: <em>Why Natural Gradient</em>, 1998.</li>
          <li><a id="$h3" class=\"anchor\"></a>
            <strong>Bardenet</strong>, <strong>Doucet</strong> and <strong>Holmes</strong>: <em>On Markov Chain Monte Carlo Methods for Tall Data</em>, 2017.</li>
        </ul>
        """
    @test isapproxstr(h, """
        <p>
          Some string
        </p>
        <a id="$h1" class=\"anchor\"></a>
        \\[ x = x \\]
        <p>
          then as per
            <span class="bibref"><a href="#$h2">Amari and Douglas., 1998</a></span>
          also this
            <span class="bibref">(<a href="#$h3">Bardenet et al., 2017</a>)</span>
          and
            <span class="bibref"><a href="#$h2">Amari and Douglas., 1998</a>, <a href="#$h3">Bardenet et al., 2017</a></span>
          Reference to equation:
            <span class="eqref">(<a href="#$h1">1</a>)</span>.
        </p>
        <p>
          Then maybe some text etc.
        </p>
        $bib
        """)
end

@testset "Href-space" begin
    st = raw"""
       A
       $$ x = x \label{eq 1}$$
       B
       C \eqref{eq 1}.
       and *B $E$*.
    """
    h = st |> seval
    @test occursin(raw"""<a id="eq_1" class=\"anchor\"></a>\[ x = x \]""", h)
    @test occursin(raw"""<span class="eqref">(<a href="#eq_1">1</a>)</span>.""", h)
    @test occursin(raw"""<em>B \(E\)</em>.""", h)
end

@testset "Eqref" begin
    st = raw"""
        \newcommand{\E}[1]{\mathbb E\left[#1\right]}
        \newcommand{\eqa}[1]{\begin{eqnarray}#1\end{eqnarray}}
        \newcommand{\R}{\mathbb R}
        Then something like
        \eqa{ \E{f(X)} \in \R &\text{if}& f:\R\maptso\R}
        and then
        \eqa{ 1+1 &=& 2 \label{eq:a trivial one}}
        but further
        \eqa{ 1 &=& 1 \label{beyond hope}}
        and finally a \eqref{eq:a trivial one} and maybe \eqref{beyond hope}.
        """
    m = F.convert_md(st, collect(values(F.GLOBAL_LXDEFS)))

    @test F.PAGE_EQREFS[F.PAGE_EQREFS_COUNTER] == 3
    @test F.PAGE_EQREFS[F.refstring("eq:a trivial one")] == 2
    @test F.PAGE_EQREFS[F.refstring("beyond hope")] == 3

    h1 = F.refstring("eq:a trivial one")
    h2 = F.refstring("beyond hope")

    m == "<p>Then something like  \$\$\\begin{array}{c}  \\mathbb E\\left[ f(X)\\right] \\in \\mathbb R &\\text{if}& f:\\mathbb R\\maptso\\mathbb R\\end{array}\$\$ and then  <a id=\"$h1\" class=\"anchor\"></a>\$\$\\begin{array}{c}  1+1 &=&2 \\end{array}\$\$ but further  <a id=\"$h2\" class=\"anchor\"></a>\$\$\\begin{array}{c}  1 &=& 1 \\end{array}\$\$ and finally a  <span class=\"eqref)\">({{href EQR $h1}})</span> and maybe  <span class=\"eqref)\">({{href EQR $h2}})</span>.</p>\n"
end
