<!--
reviewed: 20/11/21
-->

# RSS

\blurb{Franklin aims to support automatic & easy RSS feed generation.}

\lineskip

\toc

## Overview

RSS (commonly referred to as _**R**eally **S**imple **S**yndication_) is a
standard web format that allows interested readers to _subscribe_ to _feeds_ and
read new content on a platform of their choosing, i.e., without browsing to the
website from which the content originated. Franklin makes it easy to generate
this feed so that readers can more easily stay up to date with your new content.

## How to Setup RSS

There is a Franklin-generated `_rss` folder that contains two parts: `head.xml`
& `item.xml` (if this is not present for you, then copy the files from the
[FranklinTemplates source](https://github.com/JuliaDocs/FranklinTemplates.jl/tree/master/src/templates/common/_rss).

The complete RSS feed will be built by assembling

```plaintext
head
item
item
item
(foot)
```

\note{`foot.xml` is not exposed by default because there is nothing to customize
there. Both `head.xml` & `item.xml` contain sane defaults based on good
standards. However, their contents may be modified.}

### Global Configuration

In order to set up an RSS feed for your website, make sure to set the following
in your `config.md`.

```julia
generate_rss = true
rss_website_title = "Website Title"
rss_website_descr = "Website Description"
rss_website_url   = "https://<your username>.github.io"
rss_full_content = true
```

\note{Notice the last line, `rss_full_content = true`. This line is important if
you wish for your RSS feed to include the _full content_ of your posts. If
`rss_full_content = false`, then subscribers will be notified of new content,
but must visit your site in order to read it.}

### Local Configuration

For each page that you wish to be included in your RSS feed, you should specify
the description of the page. This can be done with the `rss_description` or
equivalently the `rss` or `rss_descr` local page variable.

```julia
@def rss_description = "The page synopsis."
```

Each page should include a publication date - specified by `rss_pubdate` and in
the format of `Dates.Date`. For example:

```julia
@def rss_pubdate = Date(2021, 12, 31)
```

Each page should also include a title. If one is not specified then the page
`title` will be used instead. To explicitly set the `rss_title`, do the
following:

```julia
@def rss_title = "Item Title"
```

Optionally, the following page variables can be set as well

- `rss_author`
- `rss_category`
- `rss_comments`
- `rss_enclosure`

\warn{Check the RSS specifications before using these optional page variables as
many have strict requirements and should probably be left blank. For instance, 
the `rss_author` variable **must** be an email address. So unless you are
familiar it is advised to leave these out.}

## RSS Page Variables

Here is a summary of all page variables related to RSS.

### Global RSS Variables

@@lalign
| Name | Type(s) | Default value | Comment
| :--: | :-----: | :-----------: | :-----:
| `generate_rss` | `Bool` | `false` | indicates whether `feed.xml` should be generated
| `website_title` (alias `rss_website_title`) | `String` | `""` | Used as website title in the RSS feed
| `website_description` (alias `website_descr` or `rss_website_descr`) | `String` | `""` | Used as website description in the RSS feed
| `website_url` (alias `base_url` or `rss_website_url`) | `String` | `""` | (RSS)
@@

\warn{If you set `generate_rss` to `true` then the three other variables **must** be defined.}

\note{
  For backward compatibility reasons, if `generate_rss` is `false` but the three `website_*` variables are defined, `generate_rss` will be switched to `true`.
}

### Local RSS Variables

These are variables related to [RSS 2.0 specifications](https://cyber.harvard.edu/rss/rss.html)  and must match the format indicated there.

@@lalign
| Name | Default value |
| ---- | ------------- |
| `rss`, `rss_description` | `""` |
| `rss_title` | current page title |
| `rss_author` | current author |
| `rss_category` | `""` |
| `rss_comments` | `""` |
| `rss_enclosure` | `""` |
| `rss_pubdate`   | `""` |
@@

To recapitulate, for a working RSS feed to be generated you need:

@@tlist
- to set the `website_*` variables in your  `config.md` (see [global configuration](#global_configuration)),
- on appropriate pages, to define at least `rss` to a valid description.
@@

### Examples

@@tlist
- [JuliaLang config](https://raw.githubusercontent.com/JuliaLang/www.julialang.org/main/config.md)
- [JuliaLang feed](https://julialang.org/feed.xml) 
- [JuliaGPU config](https://github.com/JuliaGPU/juliagpu.org/blob/master/config.md)
- [JuliaGPU feed](https://juliagpu.org/post/index.xml)
@@
