<div align="center">
  <a href="https://franklinjl.org">
    <img src="https://franklinjl.org/assets/infra/logoF2.svg" alt="Franklin" width="100">
  </a>
</div>

<h2 align="center">Franklin: a Static Site Generator in Julia.
<p align="center">
  <img src="https://img.shields.io/badge/lifecycle-maturing-blue.svg"
       alt="Lifecycle">
  <a href="https://github.com/JuliaDocs/Franklin.jl/actions">
    <img src="https://github.com/JuliaDocs/Franklin.jl/workflows/CI/badge.svg"
         alt="Build Status">
  </a>
  <a href="http://codecov.io/github/JuliaDocs/Franklin.jl?branch=master">
    <img src="http://codecov.io/github/JuliaDocs/Franklin.jl/coverage.svg?branch=master"
         alt="Coverage">
  </a>
</p>
</h2>

Franklin is a simple **static site generator** (SSG) oriented towards technical blogging (code, maths, ...), flexibility and extensibility.
The base syntax is plain markdown with a few extensions such as the ability to define and use LaTeX-like commands in or outside of maths environments and the possibility to evaluate code blocks on the fly.

Franklin has a channel **#franklin** on the Julia slack, this is the best place to ask usage questions.

**Note**: I'm looking for people with web-dev chops who would be keen to help improve and enrich the base themes available at [FranklinTemplates.jl](https://github.com/JuliaDocs/FranklinTemplates.jl), even if you're not super confident in Julia. More generally, if you would like to work on something or fix something in either Franklin or FranklinTemplates, please reach out on Slack, I will gladly help you get started.

## Docs

Go to [Franklin's main website](https://franklinjl.org). For users already familiar with Franklin you might also find [these demos](https://franklinjl.org/demos/) useful. Ifihan Olusheye also wrote [this blog](https://dev.to/ifihan/building-a-blog-with-franklin-jl-3h77) on building a blog with Franklin.

### Important notes

* if, upon deployment, your website doesn't seem to apply CSS, you likely forgot a step, please [see here](https://franklinjl.org/workflow/deploy/#creating_a_repo_on_github).
* it is currently recommended to **switch off** pre-rendering and minification (you can do this by passing `prerender=false, minify=false` to the `optimize(...)` call in your deploy script), the corresponding logic will be removed in future version of Franklin as it's tricky to maintain and caused too many issues.
* if you're getting warning messages about some JS library not being found on your computer, you can safely ignore this.

## Key features

* Use standard markdown with the possibility to use LaTeX-style commands and generating functions written in Julia
* Simple way to introduce div blocks allowing easy styling on a page (e.g. "Theorem" boxes etc.),
* Can execute and show the output of Julia code blocks,
* Easy HTML templating to define or adapt a given layout,
* Custom RSS generation,
* Simple website optimisation step:
  - compression of HTML and CSS of the generated pages,
  - optional pre-rendering of KaTeX and highlighted code blocks to remove javascript dependency,
* Extremely flexible and extensible.

See [the docs](https://franklinjl.org) for more information and examples.

## Examples

Some examples of websites using Franklin (_if you're using Franklin with a public repo, consider adding the "franklin" tag to the repo to help others find examples, thanks!_)

**Adapted templates** (i.e. starting from one of [the available themes](https://tlienart.github.io/FranklinTemplates.jl/))
* Franklin's own website is written in Franklin, [see docs/](docs/)
* [@cormullion's website](https://cormullion.github.io), the author of [Luxor.jl](https://github.com/JuliaGraphics/Luxor.jl),
* MLJ's [tutorial website](https://alan-turing-institute.github.io/DataScienceTutorials.jl/) which shows how Franklin can interact nicely with [Literate.jl](https://github.com/fredrikekre/Literate.jl)
* [Tom Kwong's website](https://ahsmart.com/) author of [_Hands-on Design Patterns and Best Practices with  Julia_](https://www.amazon.com/gp/product/183864881X)
* [SymbolicUtils.jl's manual](https://juliasymbolics.github.io/SymbolicUtils.jl/) using the Tufte template
* [@terasakisatoshi's website](https://terasakisatoshi.github.io/MathSeminar.jl/) using the vela template, [source](https://github.com/terasakisatoshi/MathSeminar.jl)
* [@Wikunia's blog](https://opensourc.es) using the vela template
* [SciML.ai](https://github.com/SciML/sciml.ai), Julia's SciML Scientific Machine Learning organization website
* [My website](https://tlienart.github.io), using bootstrap 5
* [JuliaActuary](https://JuliaActuary.org), Julia's community promoting open-source actuarial science
* [MIT Introduction to Computational Thinking](https://computationalthinking.mit.edu/Fall20) course website
* [Rik Huijzer's blog](https://huijzer.xyz) which is mostly about programming and statistics
* [TuringModels](https://statisticalrethinkingjulia.github.io/TuringModels.jl/) implements the models from [Statistical Rethinking](https://xcelab.net/rm/statistical-rethinking/) using [Turing.jl](https://turing.ml/stable/)
* [Ricardo Rosa's website](https://rmsrosa.github.io/en/) ([repo](https://github.com/rmsrosa/rmsrosa.github.io)).
* [hustf's blog](https://hustf.github.io/)
* [Bayesian-Julia](https://storopoli.github.io/Bayesian-Julia/) A set of Tutorials on how to do Bayesian statistics using Turing ([repo](https://github.com/storopoli/Bayesian-Julia))
* [Jose Storopoli's website](https://storopoli.io/) personal website with bootstrap buttons along with FontAwesome and Academicons icons ([repo](https://git.sr.ht/~storopoli/storopoli.io))
* [ETH Zurich's Solving PDEs in parallel on GPUs with Julia](https://eth-vaw-glaciology.github.io/course-101-0250-00/) course website
* [Julia Package Comparisons](https://juliapackagecomparisons.github.io/) is a website to help Julia users discover and choose between packages. ([repo](https://github.com/JuliaPackageComparisons/JuliaPackageComparisons.github.io))

**Custom templates** (i.e. migrating an existing design)
* The [Julia website](https://julialang.org), including the blog, are deployed using Franklin ([repo](https://github.com/JuliaLang/www.julialang.org))
* [Circuitscape's website](https://circuitscape.org) was migrated from Jekyll ([repo](https://github.com/Circuitscape/www.circuitscape.org))
* [@zlatanvasovic's website](https://zlatanvasovic.github.io) using Bootstrap 4.5 ([repo](https://github.com/zlatanvasovic/zlatanvasovic.github.io))
* [PkgPage.jl](https://tlienart.github.io/PkgPage.jl/), front-page generator based on Franklin using Bootstrap 4.5
* [@abhishalya's website](https://abhishalya.github.io) using a custom minimalistic theme ([repo](https://github.com/abhishalya/abhishalya.github.io))
* [JuliaCon's website](https://juliacon.org) using Franklin and Bootstrap ([repo](https://github.com/JuliaCon/www.juliacon.org))
* [JuliaGPU's website](https://juliagpu.org) using Franklin and a custom template ([repo](https://github.com/JuliaGPU/juliagpu.org))
* [FluxML's website](https://fluxml.ai) was migrated from jekyll (including the blogs and tutorials) ([repo](https://github.com/FluxML/fluxml.github.io))


## Getting started

With Julia ≥ 1.3:

```julia
pkg> add Franklin
```

you can then get started with

```julia
julia> using Franklin

julia> newsite("MyNewSite")
✔ Website folder generated at "MyNewSite" (now the current directory).
→ Use serve() from Franklin to see the website in your browser.

julia> serve()
→ Initial full pass...
→ Starting the server...
✔ LiveServer listening on http://localhost:8000/ ...
  (use CTRL+C to shut down)
```

Modify the files in `MyNewSite/src` and see the changes being live-rendered in your browser.
Head to [the docs](https://franklinjl.org) for more information.

You can also start from [one of the templates](https://tlienart.github.io/FranklinTemplates.jl/) by doing something like:

```julia
julia> newsite("MyNewSite", template="vela")
```

You might want to put the following command in your `.bash_profile` or `.bashrc` as a way to quickly launch the server from your terminal:

```
alias franklin=julia -O0 -e 'using Franklin; serve()'
```

### Heads up!

While Franklin broadly supports standard Markdown there are a few things that may trip you which are either due to Franklin or due to Julia's Markdown library, here are key ones you should keep in mind:

* when writing a list, the content of the list item **must** be on a single line (no line break)
* you can write comments with `<!-- comments -->` the comment markers `<!--` and `-->` **must** be separated by a character that is not a `-` to work properly so `<!--A-->` is ok but `<!---A--->` is not, best is to just systematically use whitespace: `<!-- A -->`.
* be careful writing double braces, `{{...}}` has a *meaning* (html functions) this can cause issues in latex commands, if you have double braces in a latex command, **make sure to add whitespaces** for instance write `\dfrac{1}{ {101}_{2} }` instead of `\dfrac{1}{{101}_{2}}`. In general use whitespaces liberally to help the parser in math and latex commands.
* (as of `v0.7`) code blocks should be delimited with backticks `` ` `` you *can* also use indented blocks to delimit code blocks but you now have to **opt in** explicitly on pages that would use them by using `@def indented_code = true`, if you want to use that everywhere, write that in the `config.md`. Note that indented blocks are **ambiguous** with some of the other things that Franklin provides (div blocks, latex commands) and so if you use them, you are responsible for avoiding ambiguities (effectively that means _not using indentation for anything else than code_)


## Associated repositories

* [LiveServer.jl](https://github.com/asprionj/LiveServer.jl) a package authored with [Jonas Asprion](https://github.com/asprionj) to render and watch the content of a local folder in the browser.
* [FranklinTemplates.jl](https://github.com/JuliaDocs/FranklinTemplates.jl) the repositories where Franklin themes/templates are developed.
* [Xranklin.jl](https://github.com/JuliaDocs/Xranklin.jl) experimental repo for a refactoring of Franklin.jl

## Licenses

**Core**:

* Franklin, FranklinTemplates and LiveServer are all MIT licensed.

**External**:

* KaTeX is [MIT licensed](https://github.com/KaTeX/KaTeX/blob/master/LICENSE),
* Node's is essentially [MIT licensed](https://github.com/nodejs/node/blob/master/LICENSE),
* css-html-js-minify is [LGPL licensed](https://github.com/juancarlospaco/css-html-js-minify/blob/master/LICENCE.lgpl.txt),
* highlight.js is [BSD licensed](https://github.com/highlightjs/highlight.js/blob/master/LICENSE).
