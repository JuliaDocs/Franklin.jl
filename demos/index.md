+++
title = "Franklin FAQ"
tags = ["index"]
auto_code_path = true
hasmath = true
+++

# Franklin Demos

\style{text-align:center;width:100%;display:inline-block;font-variant-caps:small-caps}{[**Click here to see the source**](https://github.com/JuliaDocs/Franklin.jl/tree/master/demos)}

This website is meant to be a quick way to show how to do stuff that people ask (or that I thought would be a nice demo), it will complement the [official documentation](https://franklinjl.org/).

It's not meant to be beautiful, rather just show how to get specific stuff done.
If one block answers one of your question, make sure to check [the source](https://github.com/JuliaDocs/Franklin.jl/tree/master/demos/index.md) to see how it was done.
The ordering is reverse chronological but just use the table of contents to guide you to whatever you might want to explore.

**Note**: an important philosophy here is that if you can write a Julia function that would produce the HTML you want, then write that function and let Franklin call it.

**Note 2**: the numbering in georgian script in the table of content is on purpose (though for no particularly good reason other than that it looks nice... 🇬🇪)

\toc

## (019) From `Dataframe` to HTML table

If you have some data that you would like to manipulate and render nicely in `Franklin`, you can use the following snippet relying on [`DataFrames.jl`](https://github.com/JuliaData/DataFrames.jl)
and [`PrettyTables.jl`](https://github.com/ronisbr/PrettyTables.jl).

The following `Dataframe`: 

```julia
val = [1,2,3,4]
tag = ['a','b','c','d']
math = ["\$x\$", "\$y^2\$", "\$\\sqrt{z}\$", "\$\\Omega\$"]
DataFrame(; val, tag, math)
```

will be rendered as:

{{ render_table }}

This done via a `hfun_render_table` which can be found in [`utils.jl`](https://github.com/JuliaDocs/Franklin.jl/blob/master/demos/utils.jl).



## (018) collapsible block
How to make a section expand when clicked, so that content is initially hidden? (Based on [this html guide](https://www.w3schools.com/howto/howto_js_collapsible.asp).)

\newcommand{\collaps}[2]{
~~~<button type="button" class="collapsible">~~~ #1 ~~~</button><div class="collapsiblecontent">~~~ #2 ~~~</div>~~~
}

\collaps{We first define a command, `\collaps{title}{content}`, allowing both the title and the content to be given as markdown and processed by Franklin}{
```html
\newcommand{\collaps}[2]{
~~~<button type="button" class="collapsible">~~~ #1 ~~~</button><div class="collapsiblecontent">~~~ #2 ~~~</div>~~~
}
```
}

\collaps{Then, we need to add styling for these classes. Here, we add it to `_css/extras.css`.}{
```css
 /* Style the button that is used to open and close the collapsible content */
 .collapsible {
  background-color: #eee;
  color: #444;
  cursor: pointer;
  padding: 18px;
  width: 100%;
  border: none;
  text-align: left;
  outline: none;
  font-size: inherit;
}

/* Add a background color to the button if it is clicked on (add the .active class with JS), and when you move the mouse over it (hover) */
.active, .collapsible:hover {
  background-color: #ccc;
}

/* Style the collapsible content. Note: hidden by default */
.collapsiblecontent {
  padding: 0 18px;
  display: none;
  overflow: hidden;
  background-color: #f1f1f1;
}
```
}

\collaps{Finally, we need the javascript that can be added either on the page where it is used, or in e.g. the foot `_layout/page_foot.html`}{
```html
<script>
  var coll = document.getElementsByClassName("collapsible");
  var i;

  for (i = 0; i < coll.length; i++) {
    coll[i].addEventListener("click", function() {
      this.classList.toggle("active");
      var content = this.nextElementSibling;
      if (content.style.display === "block") {
        content.style.display = "none";
      } else {
        content.style.display = "block";
      }
    });
  }
</script>
```
}

With these definitions, the expandible code sections could be added!

\collaps{An additional example: **Press here to expand**}{In the content part you can have latex: $x^2$,

lists
* Item 1
* Item 2

And all other stuff processed by Franklin!
}


## (017) making cells work in their own path

Currently if you're saving a figure in a code block, you need to specify where to place that figure, if you don't it will go in the current directory which is the main site directory, typically you don't want that, so one trick is to use the `@OUTPUT` macro like so:

```!
using PyPlot
figure(figsize=(8,6))
plot(rand(5), rand(5))
savefig(joinpath(@OUTPUT, "ex_outpath_1.svg"))
```

and that directory is among the ones that are automatically checked when you use the `\fig` command (e.g. `\fig{ex_outpath_1.svg}`):

\fig{ex_outpath_1.svg}

if you're writing tutorials and have lots of such figures and you don't want your readers to see these weird `@OUTPUT` or you can't be bothered to add `#hide` everywhere, you can set a variable `auto_code_path` to `true` (either locally on a page or globally in your config), what this will do is that each time a cell is executed, Julia will first `cd` to the output path. So the above bit of code now reads:

```!
using PyPlot
figure(figsize=(8,6))
plot(rand(5), rand(5), color="red")
savefig("ex_outpath_2.svg")
```

and like before just use `\fig{ex_outpath_2.svg}`:

\fig{ex_outpath_2.svg}

**Note**: since this was meant to be a non-breaking change, `auto_code_path` is set to `false` by default, you must set it yourself to `true` in your `config.md` if you want this to apply everywhere.

## (016) using WGLMakie + JSServe

[This page](/wgl/) shows an example using WGLMakie + JSServe.
It assumes you're familiar with these two libraries and that you have the latest version of each.

Note that it requires WebGL to work which might not be enabled on all browsers.

## (015) Using Weave

[Here's a page](/weave/) where the content is generated from a [Weave.jl](https://github.com/JunoLab/Weave.jl).


## (014) Using MathJax

If you prefer MathJax over KaTeX for maths rendering, you can use that. For now this is not fully supported and so taking this path may lead to issues, please report them and help fixing those is welcome.

Head to [this page](/mathjax/) for a demo and setup instructions.

## (013) Inserting Markdown in Markdown

Let's say you have a file `content.md` and you would like to include it in another page as if it had been written there in the first place.
This is pretty easy to do.
You could for instance use the following function:

```julia
function hfun_insertmd(params)
  rpath = params[1]
  fullpath = joinpath(Franklin.path(:folder), rpath)
  isfile(fullpath) || return ""
  return read(fullpath, String)
end
```

One thing to note is that all `.md` files in your folder will be considered as potential pages to turn into HTML, so if a `.md` file is meant to exclusively be used "inserted", you should remove it from Franklin's reach by adding it to the `ignore` global variable putting something like this in your `config.md`:

```
@def ignore = ["path/to/content.md"]
```

Here's an example with the insertion of the content of a file `foo/content.md`; the result of `{{insertmd foo/content.md}}` is:

{{insertmd foo/content.md}}

You can look at [`utils.jl`](https://github.com/JuliaDocs/Franklin.jl/blob/master/demos/utils.jl) for the definition of the `hfun` (same as above), at [`index.md`](https://github.com/JuliaDocs/Franklin.jl/blob/master/demos/index.md) to see how it's called and at [`foo/content.md`](https://github.com/JuliaDocs/Franklin.jl/blob/master/demos/foo/content.md) for the content file.
Finally you can also check out the [`config.md`](https://github.com/JuliaDocs/Franklin.jl/blob/master/demos/config.md) file to see how the content page is ignored.

## (012) Dates

The date of last modification on the page is kept in the `fd_mtime_raw` internal page variable, there is also a pre-formatted `fd_mtime`.

Last modified: {{fd_mtime_raw}} or {{fd_mtime}}

## (011) showing type information

This is a short demo following a discussion on Slack, it shows three things:

* how to mark a block as "_run here directly and show the output_" without having to explicitly add a path and use a `\show`
* that types are now shown properly as they would be in the REPL.
* that continuation works from cell to cell (i.e. you can assume that a cell further below another cell has access to what was defined in the first)

```!
s = "hello"
struct T; v::Int; end
[
    Dict(:a => T(1)),
    Dict(:b => T(2)),
]
```

Here's another cell

```!
T(1)
print(s)
```

Suppressed output:

```!
X = randn(2, 3);
```


## (010) clipboard button for code blocks

It's fairly easy to add a "copy" button to your code blocks using  a tool like [`clipboard.js`](https://clipboardjs.com).
In fact on this demo page, as you can see, there is a copy button on all code blocks.
The steps to  reproduce  this are:

* copy the [`clipboard.min.js`](https://github.com/JuliaDocs/Franklin.jl/blob/master/demos/_libs/clipboard.min.js) to `/libs/clipboard.min.js` (_note that this is an old version of the library, `1.4` or something, if you take  the most recent version, you will have to adapt the script_)
* load that in `_layout/head.html` adding something like

```html
<script src="/libs/clipboard.min.js"></script>
```

* add Javascript in the `_layout/foot.html`,  something [like this](https://github.com/JuliaDocs/Franklin.jl/blob/master/demos/_layout/foot_clipboard.html)
* adjust the CSS, for instance [something like this](https://github.com/JuliaDocs/Franklin.jl/blob/0276b1afb054017ff7e81bc7d083021a867a4b92/demos/_css/extras.css#L37-L61)

and that's it 🏁.

## (009) custom environment for TikzCD

{{if isAppleARM}}
> This demo unfortunately doesn't work on Apple ARM since it uses tectonic through the [TikzPictures.jl](https://github.com/JuliaTeX/TikzPictures.jl) package. See issue [Tectonic.jl#13](https://github.com/MichaelHatherly/Tectonic.jl/issues/13).

{{else}}

Following up on [#008](#008_custom_environments_and_commands), here's a custom environment for Tikz diagrams using the [TikzPictures.jl](https://github.com/JuliaTeX/TikzPictures.jl) package.

Let's first see what you get for your effort:

@@small-imgc \begin{tikzcd}{tcd1}
A \arrow[r, "\phi"] \arrow[d, red]
  & B \arrow[d, "\psi" red] \\
  C \arrow[r, red, "\eta" blue]
  & D
\end{tikzcd}@@

Cool! Modulo a div class that shrinks the image a bit, the code that was used here is very nearly a copy-paste from an example in the [tikz-cd docs](https://ctan.kako-dev.de/graphics/pgf/contrib/tikz-cd/tikz-cd-doc.pdf), the only difference is one additional bracket with the file name (here `tcd1`):

```plaintext
\begin{tikzcd}{tcd1}
A \arrow[r, "\phi"] \arrow[d, red]
  & B \arrow[d, "\psi" red] \\
  C \arrow[r, red, "\eta" blue]
  & D
\end{tikzcd}
```

The corresponding `env_tikzcd` function is in the `utils.jl` file and is quite simple.

{{end}}

## (008) (custom) environments and commands

You can define new commands and new environments using essentially the same syntax as in LaTeX:

```plaintext
\newcommand{\command}[nargs]{def}
\newenvironment{environment}[nargs]{pre}{post}
```

The first one allows to define a command that you can call as `\command{...}` and the second one an environment that you can call as
```plaintext
\begin{environment}{...}...\end{environment}
```
In both cases you can have a number of arguments (or zero) and the output is _reprocessed by Franklin_ (so treated as Franklin-markdown).
Here are a few simple examples:

```plaintext
\newcommand{\hello}{**Hello!**}
Result: \hello.
```
\newcommand{\hello}{**Hello!**}
Result: \hello.

```plaintext
\newcommand{\html}[1]{~~~#1~~~}
\newcommand{\red}[1]{\html{<span style="color:red">#1</span>}}
Result: \red{hello!}.
```
\newcommand{\html}[1]{~~~#1~~~}
\newcommand{\red}[1]{~~~<span style="color:red">#1</span>~~~}
Result: \red{hello!}.

```plaintext
\newenvironment{center}{
  \html{<div style="text-align:center">}
}{
  \html{</div>}
}
Result: \begin{center}This bit of text is in a centered div.\end{center}
```
\newenvironment{center}{
  \html{<div style="text-align:center">}
}{
  \html{</div>}
}
Result: \begin{center}This bit of text is centered.\end{center}

```plaintext
\newenvironment{figure}[1]{
  \html{<figure>}
}{
  \html{<figcaption>#1</figcaption></figure>}
}
Result: \begin{figure}{A koala eating a leaf.}![](/assets/koala.jpg)\end{figure}
```
\newenvironment{figure}[1]{
  \html{<figure>}
}{
  \html{<figcaption>#1</figcaption></figure>}
}
Result: \begin{figure}{A koala eating a leaf.}![](/assets/koala.jpg)\end{figure}

### Customise with Julia code

Much like `hfun_*`, you can have commands and environments be effectively defined via Julia code. The main difference is that the output will be treated as Franklin-markdown and so will be _reprocessed by Franklin_ (where for a `hfun`, the output is plugged in directly as HTML).

In both cases, a single option bracket is expected, no more no less. It can be empty but it has to be there. See also [the docs](https://franklinjl.org/syntax/utils/#latex_functions_lx_) for more information.

Here are two simple examples (see in `utils.jl` too):

```julia
function lx_capa(com, _)
  # this first line extracts the content of the brace
  content = Franklin.content(com.braces[1])
  output = replace(content, "a" => "A")
  return "**$output**"
end
```

```plaintext
Result: \capa{Baba Yaga}.
```
Result: \capa{Baba Yaga}.

```julia
function env_cap(com, _)
  option = Franklin.content(com.braces[1])
  content = Franklin.content(com)
  output = replace(content, option => uppercase(option))
  return "~~~<b>~~~$output~~~</b>~~~"
end
```

```plaintext
Result: \begin{cap}{ba}Baba Yaga with a baseball bat\end{cap}
```
Result: \begin{cap}{ba}Baba Yaga with a baseball bat\end{cap}

Of course these are toy examples and you could have arrived to the same effect some other way.
With a bit of practice, you might develop a preference towards using one out of the three options:  `hfun_*`, `lx_*` or `env_*` depending on your context.

## (007) delayed hfun

When you call `serve()`, Franklin first does a full pass which builds all your pages and then waits for changes to happen in a given page before updating that page.
If you have a page `A` and a page `B` and that the page `A` calls a function which would need something that will only be defined once `B` is built, you have two cases:

1. A common one is to have the function used by `A` require a _local_ page variable defined on `B`; in that case just use `pagevar(...)`. When called, it will itself build `B` so that it can access the page variable defined on `B`. This is usually all you need.
1. A less common one is to have the function used by `A` require a _global_ page variable such as, for instance, the list of all tags, which is only complete _once all pages have been built_. In that case the function to be used by `A` should be marked with `@delay hfun_...(...)` so that Franklin knows it has to wait for the full pass to be completed before re-building `A` now being sure that it will have access to the proper scope.

The page [foo](/foo/) has a tag `foo` and a page variable `var`; let's show both use cases; see `utils.jl` to see the definition of the relevant functions.

**Case 1** (local page variable access, `var = 5` on page foo): {{case_1}}

**Case 2** (wait for full build, there's a tag `index` here and a tag `foo` on page foo): {{case_2}}

## (006) code highlighting

Inserting highlighted code is very easy in Franklin; just use triple backquotes and the name of the language:

```julia
struct Point{T}
  x::T
  y::T
end
```

The highlighting is done via highlight.js, it's important to understand there are two modes:

* using the `_libs/highlight/highlight.pack.js`, this happens when serving locally **and** when publishing a website **without** pre-rendering,
* using the full `highlight.js` package, this happens when pre-rendering and supports all languages.

The first one only has support for selected languages (by default: `css`, `C/AL`, `C++`, `yaml`, `bash`, `ini`, `TOML`, `markdown`, `html`, `xml`, `r`, `julia`, `julia-repl`, `plaintext`, `python` with the minified `github` theme), you can change this by going to the [highlightjs](https://highlightjs.org/download/) and making your selection.

The recommendation is to:

- check whether the language of your choosing is in the default list above (so that when you serve locally things look nice), if not, go to the highlight.js website, get the files, and replace what's in `_libs/highlight/`,
- use pre-rendering if you can upon deployment.

Here are some more examples with languages that are in the default list:

```r
# some R
a <- 10
while (a > 4) {
  cat(a, "...", sep = "")
  a <- a - 1
}
```

```python
# some Python
def foo():
  print("Hello world!")
  return
```

```cpp
// some c++
#include <iostream>

int main() {
  std::cout << "Hello World!";
  return 0;
}
```

```css
/* some CSS */
p {
  border-style: solid;
  border-right-color: #ff0000;
}
```

## (005) pagination

Pagination works with `{{paginate list num}}` where `list` is a page variable with elements that you want to paginate (either a list or tuple), and `num` is the number of elements you want per page.
There are many ways you can use this, one possible way is to wrap it in a command if you want to insert this in an actual list which is what is demoed here:

\newcommand{\pglist}[2]{~~~<ul>~~~{{paginate #1 #2}}~~~</ul>~~~}

@def alist = ["<li>item $i</li>" for i in 1:10]

\label{pgex}
\pglist{alist}{4}

Now observe that

* [page 1](/1/#pgex) has items 1-4
* [page 2](/2/#pgex) has items 5-8
* [page 3](/3/#pgex) has items 9-10

## (004) use Latexify.jl

Latexify produces a LaTeX string which should basically be passed to KaTeX. To do that you need to recuperate the output, extract the string and pass it into a maths block.

Here there's a bug with `\begin{equation}` in Franklin (issue [#584](https://github.com/JuliaDocs/Franklin.jl/issues/584)) which is why I'm replacing those with `$$` but it should be fixed in the near future so that you wouldn't have to use these two "replace" lines:

```julia:lx1
using Latexify
empty_ary = Array{Float32, 2}(undef, 2, 2)
ls = latexify(empty_ary) # this is an L string
println(ls.s) # hide
```

\textoutput{lx1}

## (003) styling of code output blocks

At the moment (August 2020) no particular class is added on an output (see [#531](https://github.com/JuliaDocs/Franklin.jl/issues/531)); you can still do something similar by adding a `@@code-output` (or whatever appropriate name) around the command that extracts the output and specify this in your css (see `extras.css`):

```julia:cos1
x = 7
```

@@code-output
\show{cos1}
@@

If you find yourself writing that a lot, you should probably define a command like

```plaintext
\newcommand{\prettyshow}[1]{@@code-output \show{#1} @@}
```

and put it in your `config.md` file so that it's globally available.

\prettyshow{cos1}

## (002) code block scope

On a single page all code blocks share their environment so

```julia:cbs1
x = 5
```

then

```julia:cbs2
y = x+2
```

\show{cbs2}

## (001) how to load data from file and loop over rows

This was asked on Slack with the hope it could mimick the [Data Files](https://jekyllrb.com/docs/datafiles/) functionality of Jekyll where you would have a file like

```
name,github
Eric Mill,konklone
Parker Moore,parkr
Liu Fengyun,liufengyun
```

and you'd want to loop over that and do something with it.

**Relevant pieces**:
* see `_assets/members.csv` (content is the code block above)

### Approach 1, with a `hfun`

* see `utils.jl` for the definition of `hfun_members_table`; calling `{{members_table _assets/members.csv}}` gives

{{members_table _assets/members.csv}}


### Approach 2, with a page variable and a for loop

* see `config.md` for the definition of the `members_from_csv` _global_ page variable.

Writing the following

```html
~~~
<ul>
{{for (name, alias) in members_from_csv}}
  <li>
    <a href="https://github.com/{{alias}}">{{name}}</a>
  </li>
{{end}}
</ul>
~~~
```

gives:

~~~
<ul>
{{for (name, alias) in members_from_csv}}
  <li>
    <a href="https://github.com/{{alias}}">{{name}}</a>
  </li>
{{end}}
</ul>
~~~

**Notes**:
* we use a _global_ page variable so that we don't reload the CSV file every single time something changes on the caller page.
