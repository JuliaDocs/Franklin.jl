# Utils

\blurb{The utils file allows to create functions to customise markdown parsing and/or HTML generation.}

\lineskip

Franklin supports two types of special functions: `lx_*` and `hfun_*` functions.
At a high level, `lx_*` functions can be used to hijack Franklin's parsing of Markdown whereas `hfun_*` functions can be used to generate and plug custom HTML.

These functions are to be defined in the `utils.jl` file which lies at the same level as the `config.md` file and complements it.
They **must** be named with `lx_` or `hfun_` followed by a name; for instance: `lx_foo`, `hfun_bar_baz` are accepted.
These functions are defined in plain Julia and can themselves call other functions that would be defined in the `utils.jl` file or elsewhere.

**Note**: often, it is enough to use `~~~...~~~` blocks or define `newcommand`s (or both) rather than use `hfun_*` and `lx_*`; but sometimes it can be very convenient to have a way to just generate things with your own code.
For instance, to locally use custom styling of text, Franklin comes with the following command:

```html
\newcommand{\style}[2]{~~~<span style="!#1">!#2</span>~~~}
```

which allows you to do something like `\style{color:red}{hello}`: \style{color:red}{hello}. No need for a `hfun_*` or `lx_*` function here...

\toc

## "HTML" functions (`hfun_*`)

A `hfun_*` function is a simple way to generate custom and plug custom HTML somewhere.

### Without parameters

A parameter-free HTML function `hfun_foo` will have a definition in `utils.jl` like

```julia
function hfun_foo()
    # some code here which defines "generated_html"
    # as a String containing valid HTML
    return generated_html
end
```

this can be called with `{{foo}}` either in one of the files in `layout/` or in any of your markdown files.

\note{As you can see the way the function is called depends on the name of the function definition `hfun_foo` ⟶ `foo`. Make sure that the name does not clash with one of the [base HTML function](/syntax/page-variables/) (`fill`, `insert`, ...) or one of the local or global variables.}

**Working example**: here's an example where the function would list the last 3 files in a folder and display them as a list; you can see also see a similar full example used on the JuliaLang website [here](https://github.com/JuliaLang/www.julialang.org/blob/54a7f5e1e62204302be37e632a47d85a60728ece/utils.jl#L70-L123).

```julia
function hfun_recentblogposts()
    list = readdir("blog")
    filter!(f -> endswith(f, ".md"), list)
    dates = [stat(joinpath("blog", f)).mtime for f in list]
    perm = sortperm(dates, rev=true)
    idxs = perm[1:min(3, length(perm))]
    io = IOBuffer()
    write(io, "<ul>")
    for (k, i) in enumerate(idxs)
        fi = "/blog/" * splitext(list[i])[1] * "/"
        write(io, """<li><a href="$fi">Post $k</a></li>\n""")
    end
    write(io, "</ul>")
    return String(take!(io))
end
```

that function can then be called as `{{recentblogposts}}`.

### With parameters

You can also have parameters with `hfun_*` functions which will allow you to write:

```html
{{fname arg1 arg2}}
```

the parameters are passed as a **vector of strings** i.e.: in the case above, the function will receive `["arg1", "arg2"]` and these strings will need to be further processed by the function.

The procedure is otherwise the same as at the previous point, you just need to define the function like this:

```julia
function hfun_bar(params)
    # params is a Vector{String}, do what you need to
    # with the individual strings then form some HTML
    return generated_html
end
```

Note that all functions defined in `utils.jl` can call `locvar(name)` and `globvar(name)` to retrieve the value associated with a local or global page variable by its name; for instance `locvar("author")`. You may optionally pass a `default` argument that will be returned instead of `nothing` if the variable does not exist, eg `locvar(name; default="Not named")`.

## "LaTeX" functions (`lx_*`)

A `lx_*` function is a way to bypass Franklin's parsing and generate Markdown which will be _reprocessed_ by Franklin (though you can always avoid that by generating HTML directly after wrapping it in `~~~`).

This is a more advanced command and you should probably double-check before making use of it as, usually, there will be a simpler way of achieving what you want.
Also if you intend to use it, you will want to check out [FranklinUtils](http://github.com/tlienart/FranklinUtils.jl) which provides helper functions for it.

It's harder to come up with meaningful examples as most simple examples will be achievable another way so here we proceed with a dumb example (and will show why it's dumb later).

Let's imagine you want to bypass the way Franklin deals with headers, that you would like to be able to write

```
\h2{id="foo" title="Bar"}
```

in order to get

```html
<h2 id="foo">Bar</h2>
```

You can do this via a `lx_*` function:

\escape{julia::
function lx_h2(com, _) # the signature must look like this
    # leave this first line, it extracts the content of the brace
    content = Franklin.content(com.braces[1])
    # dumb way to recover stuff
    m = match(r"id\s*=\s*\"(.*?)\"\s*title\s*=\s*\"(.*?)\"", content)
    id, title = m.captures[1:2]
    return """~~~<h2 id="$id">$title</h2>~~~"""
end
} <!--_-->

\note{The same comment as earlier, you can see that the way the function is called depends on the name of the function definition `lx_foo` ⟶ `foo`. Make sure that the name does not clash with one of the pre-defined commands (`label`, `style`, ...).}

\note{For the moment, this only works with a single brace see [issue 518](https://github.com/JuliaDocs/Franklin.jl/issues/518) for comments.}

### Why it was a dumb example

In this case, it would have been simpler to just define this as a simple newcommand:

```html
\newcommand{\h2}[2]{~~~<h2 id="!#1">#2</h2>~~~}
```

which you would have called `\h2{foo}{Bar}`.
