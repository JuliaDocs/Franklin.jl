@def hascode=false

<!--
reviewed: 20/12/19
-->

# FAQ - Meta

## Why bother with yet another SSG?

There is a [multitude of static site generators](https://www.staticgen.com/) out there... is this one worth your time?

I didn't start working on Franklin hoping to "beat" mature and sophisticated generators like Hugo or Jekyll.
Rather, I had been using Jacob Mattingley's much simpler [Jemdoc](http://jemdoc.jaboc.net/using.html) package in Python with Wonseok Shin's [neat extension](https://github.com/wsshin/jemdoc_mathjax) for MathJax support.

I liked that Jemdoc+Mathjax was simple to use and didn't require a lot of web-dev skills to get going.
That's how I got the idea of doing something similar in Julia, hopefully improving on the few things I didn't like such as the lack of support for live-rendering preview or the speed of page generation.

That being said, if you just want a blogging generator mostly for text and pictures, then Franklin may not be the tool for you.
If you want to host a technical blog with maths, an code blocks, and would like some easy and reproducible control over elements, then Franklin could help you (feel free to [open an issue](https://github.com/JuliaDocs/Franklin.jl/issues/new) to see if Franklin is right for you).

### Why not Pandoc?

[Pandoc](https://pandoc.org/) is a very different beast.
Franklin's aim was never to provide a full-fledged LaTeX to HTML conversion (which Pandoc does).
Rather, Franklin supports standard markdown **and** the definition of commands following a LaTeX-like syntax.
These commands can make the use of repeated elements in your website significantly easier to use and maintain.

Further, Pandoc does not deal with the generation of a full website with things like live previews, code evaluation etc.

### Why write a markdown parser?

I suspect many computer scientists or similar types will agree that _parsing_ is an interesting topic.
Franklin provided an incentive to think hard about how to parse extended markdown efficiently and while I'd definitely not dare to say that the parser is very good, it does a decent job and I learned a lot coding it.

In particular, processing LaTeX-like commands which can be re-defined and should be resolved recursively, proved pretty interesting (and sometimes a bit tricky).  

Initially, Franklin was heavily reliant upon the Julia `Markdown` package (part of the `stdlib`) which can convert markdown to HTML but, over time, this changed as Franklin gained the capacity to parse a broader set of Markdown as well as extensions.

### Did you know?

Franklin was initially named "_JuDoc_" which happened to be a [fairly obscure saint](https://en.wikipedia.org/wiki/Judoc) (I definitely did not know that before registering the package). 
The name was meant to be close to *Jemdoc* from which the initial inspiration for this package comes and, of course, to hint at the fact that it was in Julia.
After being kindly told that the name was awkward, I received great suggestions and we ended up renaming the package to Franklin to honour

@@tlist
- [Rosalind Franklin](https://en.wikipedia.org/wiki/Rosalind_Franklin), an English chemist who contributed to the discovery of the structure of DNA, and
- [Benjamin Franklin](https://en.wikipedia.org/wiki/Benjamin_Franklin), an American polymath and one of the Founding Fathers,
- [Aretha Franklin](https://en.wikipedia.org/wiki/Aretha_Franklin), a great American singer. 
@@

There also happens to be a turtle and a US president with that name but that's mostly fortuitous.
