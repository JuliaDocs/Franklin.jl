<!--
reviewed: 18/4/20
-->

# Working with Franklin

\blurb{Set things up in minutes and focus on writing great content.}

\lineskip

\toc

## Creating your website

To get started, the easiest is to use the `newsite` function to generate a website folder which you can then modify to your heart's content.
The command takes one mandatory argument: the _name_ of the folder (which can be `"."` if you want to set things up in your current directory).
You can optionally specify a template:

```julia-repl
julia> newsite("TestWebsite"; template="vela")
✓ Website folder generated at "TestWebsite" (now the current directory).
→ Use serve() from Franklin to see the website in your browser.
```

There are a number of [simple templates](https://juliadocs.org/FranklinTemplates.jl/) you can choose from and tweak.

\note{The templates are meant to be used as _starting points_ and will likely require some fixes to match what you want. Your help to make them better is very welcome.}

Once you have created a new website folder, you can start the live rendering of your website with

```julia-repl
julia> serve()
→ Initial full pass...
→ Starting the server...
✓ LiveServer listening on http://localhost:8000/ ...
  (use CTRL+C to shut down)
```

and navigate in a browser to the corresponding address to preview the website.

### Folder structure

The initial call to `newsite` generates a folder with the following structure:

```plaintext
.
├── _assets/
├── _layout/
├── _libs/
├── config.md
└── index.md
```

After running `serve` the first time, an additional folder is generated: `__site` which will contain your full generated website.
Among these folders:

@@tlist
* the files in the top folder such as `index.md` are the source files for the generated pages, you must have an `index.md` or `index.html` at the top level but can then use whatever folder structure you want (see further),
* you should **not** modify the content of `__site` as it's *generated* and any changes you do in there may be silently over-written whenever you modify files elsewhere,
* the folders `_assets/`, `_libs/`, `_layout` and  `_css` contain *auxiliary files* supporting your site:
  * `_assets/` will contain images, code snippets, etc.,
  * `_css/` will contain the style sheets,
  * `_libs/` will contain javascript libraries,
  * `_layout/` will contain bits of HTML scaffolding for the generated pages,
@@

### Top folder

In this folder,

@@tlist
* `index.md` will generate the site's landing page,
* `pages/page1.md` would correspond to pages on your website (you can have whatever subfolder structure you want in here),
* `config.md` allows specifying variables that help steer the page generation, you can also use it to declare global variables or definitions that can then be used on all pages.
@@

\note{You can also write pages in plain HTML. For instance, you may want to write an `index.html` file instead of generating it via the `index.md`. You will still need to put it in the exact same place and let Franklin copy the files appropriately.}

Note that Franklin generates a folder structure in `__site` which allows having URLs like `[website]/page1/`. The following rules are applied:

* the filename is `[path/]index.md` or `[path/]index.html`, it will be copied over "as is" to `__site/[path/]index.html`,
* the filename is `[path/]somepage.md` or `[path/]somepage.html`, it will be copied to `__site/[path/]somepage/index.html`.

So for instance, if we ignore auxiliary files and you have

```
.
├── index.md
├── folder
│   └── subpage.md
└── page.md
```

it will lead to

```
__site
  ├── index.html
  ├── folder
  │   └── subpage
  │       └── index.html
  └── page
      └── index.html
```

which allows having the following URLs:

@@tlist
* `[website]/`
* `[website]/page/`
* `[website]/folder/subpage/`
@@

### Reserved names

To avoid name clashes, refrain from using the following paths where `/` indicates the top directory (website folder):

@@tlist
* `/css/` or `/css.md`
* `/layout/` or `/layout.md`
* `/literate/` or `/literate.md`
@@

Also bear in mind that Franklin will ignore `README.md`, `LICENSE.md`, `Manifest.toml` and `Project.toml` (`Manifest.toml` and `Project.toml` are still copied to the output directory).

### Tag pages

All pages with a given tag can be found (by default) at `[website]/tag/<tag_name>`. The tag page location can be changed by setting the `tag_page_path` variable in `config.md`. For example, setting `@def tag_page_path = "my_tags"` would cause tag pages to appear at `[website]/my_tags/<tag_name>`.

### Editing and testing your website

The `serve` function can be used to launch a server which will track and render modifications.
There are a few useful options you can use beyond the barebone `serve()`, do `?serve` in your REPL for all options, we list a few noteworthy ones below:

@@tlist
* `clear=false`, whether to erase `__site` and start from a blank slate,
* `single=false`, whether to do a single build pass generating all pages and not start the server.
* `prerender=false`, whether to prerender code blocks and maths (see the [optimisation step](#optimisation_step))
* `verb=false`, whether to show information about which page is being processed etc,
* `silent=false`, whether to suppress any informative messages that could otherwise appear in  your console when editing your site, this goes one step further than `verb=false` as it also  applies for code evaluation,
* `eval_all=false`, whether to re-evaluate all code blocks on all pages.
@@

## Post-processing

### Verify links

Before deploying you may want to verify that links on your website lead somewhere, to do so use the `verify_links()`.
It will take a few seconds to verify all links on every generated page but can be quite helpful to identify dead links or links with typos:

```julia-repl
julia> verify_links()
Verifying links... [you seem online ✓]
- internal link issue on page index.md: /menu3/.
```

then after fixing and re-generating pages:

```julia-repl
julia> verify_links()
All internal and external links verified ✓.
```

\note{
  This functionality is pretty rudimentary and while it might help you to find internal dead links, for serious work you might still want to do a second pass with a well-established link-checker such as [broken-link-checker](https://github.com/stevenvachon/broken-link-checker#readme).
}

### Pre-rendering and compression

The `optimize` function can

@@tlist
* pre-render KaTeX and highlight.js code to HTML so that the pages don't have to load these javascript libraries,
* minify all generated HTML and CSS.
@@
See `?optimize` for options.

Those two steps _may_ lead to faster loading pages.
Note that in order to run them, you will need a couple of external dependencies as mentioned in the [installation section](/index.html#installing_optional_extras).

\note{
  The minifier script (an external python lib) used is far from perfect and can break your website, generally speaking, if things work locally but not when you deploy, try disabling it with `optimize(minify=false)`.

  Also note that if you use GitHub or GitLab pages, the minification is not needed as these platforms compress the pages themselves.
}

### Publish

\note{If you use GitHub or GitLab with a deployment action on those platforms, you do not need to use `publish`, you can just push your changes and let the relevant action do the rest on the platform. See the section on [deployment](/workflow/deploy/).}

Once you have synched your local folder with a remote repository (see [deployment instructions](/workflow/deploy/)), the `publish` function can be called to deploy your website; it essentially:

@@tlist
- applies an optional optimisation step (see the previous point),
- does a `git add -A; git commit -am "franklin-update"; git push`.
@@

See `?publish` for more information.

In any case, before deploying, if you're working on a _project website_ i.e. a website whose root URL will look like `username.gitlab.io/project/` then you should add the following line in your `config.md` file:

```markdown
+++
prepath = "project"
+++
```

the `publish` function will then ensure that all links are fixed before deploying your website.

Note also that the `publish` function accepts a `final=` keyword to which you can pass any function `() -> nothing` to do some final post-processing before pushing updates online.
For instance, you can use `final=lunr` where `lunr` is a function exported by Franklin which generates a Lunr search index (see [this tutorial](/extras/lunr/) for more details).
