@def hascode = true

# Add search with Lunr

\toc\skipline

[`lunr.js`](https://lunrjs.com/) is a neat little Javascript library that equips your website with a search functionality fairly easily.

The steps below show a simple way of doing this matching what is done on this website.
Once it's working, you might want to adjust the `build_index.js` and/or the `lunrclient.js` to match your needs.

## Pre-requisites

### Libraries

Install `lunr` and `cheerio` (a HTML parser) with `node` locally:

```bash
$> npm install lunr
$> npm install cheerio
```

(you might have to add `sudo` before `npm`).

### Files

Copy [this folder](https://github.com/JuliaDocs/Franklin.jl/tree/master/docs/_libs/lunr) to a `/_libs/lunr/` directory.
Discard the `lunr_index.js` which is the index of this website, a version for your website will be generated dynamically.

The important files are `build_index.js` and `lunrclient.js` (of which a minified version is provided which you will want to re-generate if you modify the base file).
These files are adapted from [this repository](https://github.com/BLE-LTER/Lunr-Index-and-Search-for-Static-Sites) which shows how to use Lunr on a static website.

You can choose whether to serve your own copy of `lunr.min.js` (done here) or to use an online version via

```html
<script src="https://unpkg.com/lunr/lunr.js"></script>
```


### Index builder

The file `build_index.js` does the following:

@@tlist
- it goes over all files in a `HTML_FOLDER` (by default: `/__site/`),
- it builds an index `lunr_index.js` which can subsequently be queried upon the user entering search terms.
@@

By default, the index built is fairly barebone to reduce the size of the generated index. If you want a fancier search, you might want to modify this a bit to add a preview of the page, boost results depending on where there are (title, keyword, ...), add stop words, etc. (Refer to the [Lunr docs](https://lunrjs.com/docs/index.html) for this as well as [the example repo](https://github.com/BLE-LTER/Lunr-Index-and-Search-for-Static-Sites) mentioned earlier or [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl/blob/master/assets/html/search.js)'s version).

\note{
    Modify this file at will but be careful with the lines with `PATH_PREPEND` if your website is a project website (i.e. the root URL is something like `username.github.io/project/`). These lines help ensure that the generated links are valid. See also the section on [updating the index](#buildingupdating_the_index).
}

### Client

The file `lunrclient.js` (and its minified version) does the following:

@@tlist
- query the index
- display the results
@@

You might want to modify the `parseLunrResults` if you want the results to be displayed differently.

\note{
    If you modify this file, make sure it's called properly in the `_layout/index.html` and, eventually, [minify it](https://jscompress.com/).  
}

## Adding a search box

### Adding a form in `head.html`

The search box on this website is added with the following HTML in `_layout/head.html`:

```html
<!doctype html>
<!-- first few lines ... -->
  <script src="/libs/lunr/lunr.min.js"></script>
  <script src="/libs/lunr/lunr_index.js"></script>
  <script src="/libs/lunr/lunrclient.min.js"></script>
</head>
<!-- ... -->
<form id="lunrSearchForm" name="lunrSearchForm">
  <input class="search-input" name="q" placeholder="Enter search term" type="text">
  <input type="submit" value="Search" formaction="/search/index.html">
</form>
<-- ... -->
```

You may want to style it a bit like so:

```css
.result-title a { text-decoration: none; }
.result-title a:hover { text-decoration: underline; }
.result-preview { color: #808080; }
.resultCount { color: #808080; }
.result-query { font-weight: bold; }
#lunrSearchForm { margin-top: 1em; }
```

### Target search page

You also need to add a `src/search.md` to display the results with the appropriate divs:

```html
@def title = "Search ⋅ YourWebsite"

## Search

Number of results found: ~~~<span id="resultCount"></span>~~~

~~~
<div id="searchResults"></div>
~~~
```

Note that if you modify the `id` of these elements, you will need to adapt the `lunrclient` file(s) accordingly.

## Building/updating the index

Franklin exports a `lunr()` function which

@@tlist
- checks that you have the right files at the right place,
- (re)builds the index, prepending a path to links if required.
@@

If you are experimenting locally, just call `lunr()` then `serve()` and test that searching works as expected.

When you are ready to update your website you  can either:

@@tlist
1. (recommended) Call `publish(final=lunr)`,
1. Call `lunr()` or `lunr(prepath)` if there is a prepath and then publish your updates manually.
@@

The `publish(final=lunr)` calls the `lunr` function as the last step prior to doing a `git push`.
An advantage of using this is that Franklin will properly handle the `prepath` if there is one defined in your `config.md`.

\note{
  This `final=` keyword can be used with your own functions `()->nothing` if you need to do some post-processing with the generated files before pushing.
}
