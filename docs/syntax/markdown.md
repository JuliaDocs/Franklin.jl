<!--
reviewed: 18/4/20
-->

# Markdown syntax

\blurb{Franklin aims to support most of Common Mark with a few differences and some useful extensions.}

\lineskip

\toc

## Experimenting

Beyond directly experimenting in a project folder, you  can also explore what HTML is generated with the `fd2html` function:

```julia-repl
julia> """Set `x` to 1, see [the docs](http://example.com).""" |> fd2html
"&lt;p&gt;Set &lt;code&gt;x&lt;/code&gt; to 1, see &lt;a href&#61;&quot;http://example.com&quot;&gt;the docs&lt;/a&gt;.&lt;/p&gt;\n"
```

## Basics

If you're already familiar with Markdown, you can skip this section, though it may serve as a useful reminder.

### Headers

```markdown
# Level 1
## Level 2
...
###### Level 6
```

will generate the various header levels.

\note{Franklin makes headers into links to help with internal links and automatic table of contents generation (which you can include anywhere using `\toc`).}

### Text styling

```plaintext
**Bold text**, *italic* or _italic_, **_bold italic_**, `inline code`.
```

Inserting a horizontal rule can be done with

```markdown
---
```

For a blockquote, start the line with `>`:

```markdown
> This is a blockquote

```

### Links

```markdown
inline links: [plain link](https:://www.wikipedia.org)

reference links: ["reference" link][reflink] and ["reference" link][]

[reflink]: https://www.wikipedia.org
["reference" link]: https://www.wikipedia.org
```

Footnotes follow a similar syntax

```markdown
This has a footnote[^1]

[^1]: footnote definition
```

**Note**: footnotes are expected to be on a single line, this is due to a limitation of the parser.

For images, just add an exclamation mark `!`:

```markdown
inline: ![alt text](https://juliacon.org/2018/assets/img/julia-logo-dots.png)

reference: ![alt text][ref]

[ref]: https://juliacon.org/2018/assets/img/julia-logo-dots.png
```

**Notes**:

@@tlist
* (**link reference**) when using "indirect links" i.e. in the text you use something like `[link name][link A]` and then somewhere else you define `[link A]: some/url/`, we recommend you use unambiguous link identifiers (here `[link A]`). We recommend you to not use numbers like `[link name][1]`, indeed if on the page you have some code where `[1]` appears, there is an ambiguity for the parser,
* (**link title**) are currently _not supported_ e.g. something like `[link A](some/url/ "link title")`,
* (**suppress links**) if, for some reason, you want to have something like `[...]: ...` somewhere on your page that does _not_ define a link, then you need to toggle ref-links off (`@def reflinks = false`) and only use inline links `[link name](some/url/)`.
@@

### Lists

Unordered list (you can  also use `-`, `+` or `.` instead  of `*`)

```markdown
* item 1
* item 2
  * sub-item 1
```

Ordered list (the proper numbering is done automatically)

```markdown
1. item 1
1. item 2
  1. subitem 1
```

\note{List items _must_ be on the same line (_this is due to [a limitation](https://github.com/JuliaLang/julia/issues/30198) of the Julia Markdown parser_).}

### Comments

You can add comments in your markdown using HTML-style comments: `<!-- your comment -->` possibly on multiple lines. Note that comments are **not** allowed in a math environment.

### Symbols and HTML entities

Outside code environments, there are a few quirks in dealing with symbols:

@@tlist
* (**dollar sign**) to introduce a dollar sign, you _must_ escape it with a backslash: `\$` as it is otherwise used to open and close inline math blocks,
* (**HTML entity**) you can use HTML entities without issues like `&rarr;` for "→" or `&#36;` for "\$",
* (**backslash**) to introduce a backslash, you can just use ~~~<code>\</code>~~~, while a _double backslash_ ~~~<code>\\</code>~~~ can be used to specify a _line break_ in text.
@@

## Table of contents

Franklin can insert an automatically generated table of contents simply by using `\toc` or `\tableofcontents` somewhere appropriate in your markdown.
The table of contents will be generated in a `franklin-toc` div block, so if you would like to modify the styling, you should modify `.franklin-toc ol`, `.franklin-toc li` etc in your CSS.

You can specify the minimum and maximum header level to control the table of contents nesting using `@def mintoclevel=2` and `@def maxtoclevel=3` where, here, it would build a table of contents with the `h2` and `h3` headers only (this is the setting used here for instance).

## Code

Inline code with single and double back-ticks

```markdown
Single back-ticks: `var = 5`, and
double back-ticks if the code includes ticks: ``var = "`"``.
```

Blocks of code with triple back-ticks and the language specifier

`````markdown
```julia
a = 5
println(a)
```
`````

You're not obliged to specify the language, if you don't it will assume the language corresponds to the [page variable](/syntax/page-variables/) `lang` (set to `julia` by default).
If you want the block to be considered as plaintext, use  `plaintext` as the language specifier.

Finally, you can also use indented code blocks (which will also take its highlighting hint from `lang`) but this is **not recommended** and you have to explicitly opt in by setting `indented_code` on a page that would use them:

```markdown
@def indented_code = true
Code block:

    a = 5
    println(a)

```

Indented code blocks are _ambiguous_ with how other Franklin blocks can be defined such as div blocks and latex blocks. If you really want to use them, you will have to ensure that your div blocks and latex commands on that page do **not use** indentation as it might cause problems.

### Highlighting

Syntax highlighting is done via [highlight.js](https://highlightjs.org/) and you can find the relevant script in the  `/_libs/highlight/` folder.
The default one supports highlighting for Bash, CSS, Ini, Julia, Julia-repl, Markdown, plaintext, Python, R, Ruby, Xml and Yaml.
Note that if you use pre-rendering, then the full `highlight.js` is used with support for over 100 languages.

By default unfenced code blocks (e.g. indented code blocks) will be highlighted as Julia code blocks; to change this, set `@def lang = "python"`.
If you want a code block to _not_ be highlighted, we recommend you use `plaintext` to guarantee this:

`````markdown
```plaintext
this will not be highlighted
```
`````

If you wish to have highlighting for more languages outside of the pre-rendering mode, head to [highlight.js](https://highlightjs.org/), make a selection of languages and place the resulting `highlight.pack.js` in the `/_libs/highlight/` folder.
If you do this, you might want to slightly modify it to ensure that the Julia-repl mode is properly highlighted (e.g. `shell>`):

@@tlist
* open the  `highlight.pack.js` in an editor of your choice
* look for `hljs.registerLanguage("julia-repl"` and modify the entry to:
@@

```javascript
hljs.registerLanguage("julia-repl",function(a){return{c:[{cN:"meta",b:/^julia>/,r:10,starts:{e:/^(?![ ]{6})/,sL:"julia"}},{cN:"metas",b:/^shell>/,r:10,starts:{e:/^(?![ ]{6})/,sL:"bash"}},{cN:"metap",b:/^\(.*\)\spkg>/,r:10,starts:{e:/^(?![ ]{6})/,sL:"julia"}}]}});
```

(see also [the README](https://github.com/JuliaDocs/FranklinTemplates.jl#notes) of FranklinTemplates).

### Evaluated code blocks

Julia code blocks can be evaluated and the result of the code is either shown or rendered.
To declare a code block for evaluation, use the fenced code block syntax with a name for the code block:

`````markdown
```julia:snippet1
using LinearAlgebra, Random
Random.seed!(555)
a = randn(5)
round(norm(a), sigdigits=4)
```

\show{snippet1}
`````

This will look like

```julia:snippet1
using LinearAlgebra, Random
Random.seed!(555)
a = randn(5)
round(norm(a), sigdigits=4)
```

\show{snippet1}

For more information on using evaluated code blocks, please head to the [section on code insertion](/code/).

## Maths

### Inline and display maths

Inserting maths is done pretty much like in LaTeX:

```plaintext
Inline: $x=5$ or display:

$$ \mathcal W_\psi[f] = \int_{\mathbb R} f(s)\psi(s)\mathrm{d}s $$
```

Inline: $x=5$ or display:

$$ \mathcal W_\psi[f] = \int_{\mathbb R} f(s)\psi(s)\mathrm{d}s $$

You can also use `\[...\]` for display maths.

One thing to keep in mind when adding maths on your page is that you should be generous in your use of whitespace, particularly around inequality operators to avoid the ambiguity that could confuse KaTeX.
So for instance prefer: `$0 < C$` to `$0<C$` (the latter will not render properly).
Also if you have to write double braces, make sure to add a space in between so `{ {` or `} }` and not `{{` or `}}` since that has a specific meaning in Franklin:

```plaintext
$$ \dfrac{ {101}_{2} } $$
```

$$\dfrac{1}{ {101}_{2} }$$


### Aligned maths

For aligned environment you can use `\begin{eqnarray}...\end{eqnarray}` or `\begin{align}...\end{align}`

```markdown
\begin{eqnarray}
  \exp(i\pi)+1 &=& 0\\
  1+1 &=& 2
\end{eqnarray}

\begin{align}
  \exp(i\pi)+1 &= 0\\
  1+1 &= 2
\end{align}
```

\begin{eqnarray}
  \exp(i\pi)+1 &=& 0\\
  1+1 &=& 2
\end{eqnarray}

\begin{align}
  \exp(i\pi)+1 &= 0\\
  1+1 &= 2
\end{align}

\note{In proper LaTeX, the use of `\eqnarray` is discouraged due to possible interference with array column spacing. In Franklin, this does not happen and so the only practical difference is that `\eqnarray` will give you a bit more horizontal spacing around the `=` signs.}

## Raw HTML

You can inject raw HTML by fencing it with `~~~...~~~` which can be useful for custom formatting.

A simple example is if you want to colour your text; for instance with

```html
~~~
<span style="color:magenta;">coloured</span>
~~~
```

you get: some ~~~<span style="color:magenta;">coloured</span>~~~ text (note that it all can be on a single line.)

You could also use this to locally customise a layout etc.

\note{Inside a raw HTML block, you cannot use markdown, maths, etc. For this reason, it is often preferable to use nested `@@divname...@@` blocks instead of raw HTML since those _can_ have markdown, maths, etc. in them. (See [inserting divs](/syntax/divs-commands/).)}

## File insertions
A few commands are defined to help you with insertions of content; you can also define your own commands using custom HTML as was discussed before.

### Inserting a figure

The commands
@@tlist
* `\figalt{alt}{path}`, and
* `\fig{path}`
@@
are convenient commands to insert figures.
Of course, you're free to use the default markdown way `![alt](full_path)` instead.
One difference with these commands though is that they allow the use of relative paths; this can be convenient in order to organise your assets as you organise your pages.

**Note**: to help with the organisation of assets, Franklin will assume by default that figures are placed in a folder `/output/` relative to where the script is, i.e. if the script is in `[script_dir]`, the figures will be in `[script_dir]/output/`. To help with this, the macro `@OUTPUT` can be used which specifies the path to this relative output dir:

`````
```julia:./ex1
using PyPlot
figure()
plot([0, 1], [0, 1])
savefig(joinpath(@OUTPUT, "test.png"))
```
\fig{./output/test}
`````

This gives:

```julia:./ex1
using PyPlot
figure()
plot([0, 1], [0, 1])
savefig(joinpath(@OUTPUT, "test.png"))
```

@@small-img
  \fig{./output/test}
@@

In fact the syntax `\fig{./test}` is also allowed, Franklin will then first look in the `[script_dir]` for a `test.*` figure and, if it doesn't find one, will try to  look in `[script_dir]/output/` for a `test.*` figure:

@@small-img
  \fig{./test}
@@

Figure style (for instance, if one wishes to modify figure width) can be further customized in two different ways. The first way is to define custom CSS for the figure. In the markdown, this comes down to writing:

```
@@im-50
![](/assets/rndimg.jpg)
@@
```
which puts the image in a div block with a class `name im-50`.

While defining the corresponding custom CSS as such:

```css
.im-50 {text-align: center;}
.im-50 img {
    padding: 0;
    width: 50%;
}
```

Another solution consists in defining a custom LaTeX command, for example:

```
\newcommand{\figenv}[3]{
~~~
<figure style="text-align:center;">
<img src="!#2" style="padding:0;#3" alt="#1"/>
<figcaption>#1</figcaption>
</figure>
~~~
}
```
This creates a command called `figenv` which takes 3 arguments and inserts raw HTML (`~~~`...`~~~`) plugging in each of the arguments in the appropriate location i.e.: (1) the image caption (2) the image source path and (3) specific CSS styling for the image. This command could be used as such (here changing the width and adding a 1px wide red border to the image):

```
\figenv{the caption}{/assets/rndimg.jpg}{width:50%;border: 1px solid red;}
```

\note{Remember that these docs are written in Franklin so you can inspect the source directory if you would like to see the source markdown.}

### Inserting markdown

In some situations, you may have some markdown in a file which you might want to include somewhere else.
This can be achieved thanks to the  `\textinput{path}` command.
The path specification is as the other commands, and the text will be formatted.

As an example you could have in `/assets/ccc/sidefile.md`:


```markdown
some **markdown** in a side file.
```

whereas in `index.md`:

```markdown
This is the index then \textinput{ccc/sidefile}
```

and this will be equivalent to just having in `index.md`:

```markdown
This is the index then some **markdown** in a side file.
```

**Note**: if you don't specify a file extension, `.md` is appended to the specified path.

### Inserting a table

You can insert tables directly from CSV files with the `\tableinput{header}{path}` command.
If you generate the file on the fly, you should follow this example:

`````
```julia:./tableinput/gen
testcsv = "h1,h2,h3
152,some string, 1.5f0
0,another string,2.87"
write("assets/pages/tableinput/testcsv.csv", testcsv)
```
`````

Then you can insert the table with:

`````
\tableinput{}{./tableinput/testcsv.csv}
`````

This will result in:

| h1  | h2             | h3    |
| --- | -------------- | ----- |
| 152 | some string    | 1.5f0 |
| 0   | another string | 2.87  |

In this case, given no header was specified in the call, a header was generated from the first line in the CSV (here: `h1, h2, h3`).

If your file doesn't have a header, you can specify it in the call:

`````
```julia:./tableinput/gen
testcsv = "152,some string, 1.5f0
0,another string,2.87"
write("assets/pages/tableinput/testcsv2.csv", testcsv)
```
\tableinput{custom h1,custom h2,custom h3}{./tableinput/testcsv2.csv}
`````

| custom h1 | custom h2      | custom h3 |
| --------- | -------------- | --------- |
| 152       | some string    | 1.5f0     |
| 0         | another string | 2.87      |

With the above in mind, you can also include existing CSV files.

\note{The look of the table will be defined by your CSS stylesheet.}

There are a couple of rules that you have to keep in mind when using the `\tableinput{}{}` command:

@@tlist
* Columns must be separated by a comma (`,`).
* If a header is specified, its length must match the number of columns in the file.
@@

The standard way of creating tables in Markdown, namely using:

```markdown
| Heading 1 | Heading 2 | Heading 3 |
|-----------|-----------|-----------|
| LaTeX     | KaTeX     | MikTeX    |
```

can also be used. It is also possible to use HTML to create a table with the HTML fenced between `~~~`.
