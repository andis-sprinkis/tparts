# `tparts`

A static site generator script written in GNU AWK.

Requires `gawk`, `find` in a typical \*nix shell environment.

## The example project

To build the example Web site project (hosted [on github.io](https://andis-sprinkis.github.io/tparts/), [on gitlab.io](https://andis-sprinkis.gitlab.io/tparts)) from source files found in `./site` into the output directory `./dist`, run:

```sh
tparts ./site ./dist
```

Or run the `build` script:

```sh
./build
```

You can use an HTTP server, such as [serve](https://www.npmjs.com/package/serve), to preview the site locally:

```sh
serve ./dist
```

## Goals and non-goals

-   Goals
    1. Compiles web documents, handling the repetative parts.
    1. A boilerplate for low-maintenance, statically rendered websites.
    1. No external dependencies I need to worry about or maintain.
    1. Works _forever_, as I don't expect the GNU AWK to change a lot.
    1. Remains as rudamentary and concise as possible.
    1. The example web site project has good UI accessibility.
-   Non-goals
    1. Separating the content from the document structure or presentation (e.g. a Markdown parser).
    1. A complex to maintain document templating language (something comparable to Pug or Handlebars).

## How does the script work?

The tparts script is for building a set of plain text files – the documents, in their target directories, from reusable, inheritant parts – the template value files, prefixed by `_inline_`, `_block_`, `_pre_`.

In the example Web site project it means creating the HTML documents and the supplementary files, like `manifest.webmanifest`, `robots.txt`, `sitemap.xml`, from the globally defined and the document specific values in the available template value files, prefixed with `_`. And also copying the static assets files, like style-sheets and images, to their respective document directories.

In value files, the template value placeholders to be subsituted are the other value file names wrapped in the HTML comment syntax, e.g. `<-- _inline_lastmod -->` is to be subsituted in place with contents of the file `_inline_lastmod`. The substitution process is iterative, exhausiting the names of known value files.

Template value file name prefixes determine value placeholder substitution type – how the value file text content will be inserted in the output:

-   `_inline_` – to be inserted inline

    (The configuration values, which don't get directly inserted into the documents also use this prefix.)

-   `_block_` – to be inserted as a block of one or multiple new lines
-   `_pre_` – to be inserted as preformatted text (HTML `<pre>`)

Template value files values can be defined in a hierarchy of inheritance scopes, e.g. in the example project, where we get 2 scopes, the value files under paths

1.   `./site/*` are the project scope values
1.   `./site/(documents|sitemap)/<document label>/*` are the document local scope values, where the document local scope value files overwrite the project scope values

Some notable value files and their contents:

-   `_inline_build_entrypoint` – the name of the root level template value file for a document.
-   `_inline_path` – the document nested directory path in the project build.
-   `_inline_filename` – the filename of a document in the project build.
-   `_inline_lastmod` – the document last modified date, used in the example site sitemap entries.
-   `_inline_static_asset_caching_id` – build-time generated ID string, used in the example site document static asset URLs for cache busting.

### Runtime data structures

This section describes how the tparts script indexes the value files during building the project.

#### Template values files index

Declared as variable `_values_files_index`

Index of the all known template values files, grouped by their scope directory and indexed by file path.

```
_values_files_index: [
  <Document template value file directory path>: [
    <Document template value name>: [
      path: <Template value file path>
      type: <Substitution type (_inline_, _block_ or _pre_)>
      value: <Content of the template value>
    ]
    ..
  ]
  ..
]
```

e.g.

```
_values_files_index: [
  /home/user/tparts/site/documents/404: [
    _inline_title: [
      path: /home/user/tparts/site/documents/404/_inline_title
      type: _inline_
      value: Not found
    ]
    ..
  ]
  /home/user/tparts/site: [
    _block_document.html: [
      path: /home/user/tparts/site/_block_document.html
      type: _block_
      value: <!DOCTYPE html>
               <html lang="<!-- _inline_lang -->">
               <head>
             ..
    ]
    ..
  ]
  ..
]
```

#### Document level resolved value indices

Declared as variables `_generic_documents`, `_sitemap_entry`, `_sitemap`

While the previously mentioned `_values_files_index` is a flat list caching all template values, the values are subsequently written in the document-level values indices, resolved according their document scopes hierarchy.

So, when building a document level values index, the values defined on the very document scope, for example the value `./site/documents/index/_inline_title`, take precedence over defined corresponding project scope values, such as `./site/_inline_title`.

Document level resolved values indices data structure:

```
<Enumerated list of documents>: [
  <Index integer>: [
    path_src: <Document source directory path>
    paths_values_dir <List of value directories paths,
     in order of project to document scope>: [
      <Index integer>: <Template value directory path>
      ..
    ]
    values_index <List of scope-resolved values for the document>: [
      <Template value name>: [
        path: <Template value file path>
        type: <Substitution type (_inline_, _block_ or _pre_)>
        value: <Content of template value>
      ]
      ..
    ]
    ..
  ]
]
```

e.g.

```
_generic_documents: [
  1: [
    path_src: /home/user/tparts/site/documents/index
    paths_values_dir: [
      /home/user/project/tparts/site
      /home/user/project/tparts/site/documents/index
    ]
    values_index: [
      _inline_domain: [
        path: /home/user/project/tparts/site/_inline_domain
        type: _inline
        value: example.com
      ]
      _inline_title: [
        path: /home/user/project/tparts/site/documents/index/_inline_title
        type: _inline
        value: Index page
      ]
      _block_layout_index_children.html: [
        path: /home/user/project/tparts/site/documents/index/_block_layout_index_children.html
        type: _block
        value: <section>
                 <h1>Example index page</h1>
               ..
      ]
      ..
    ]
  ]
  ..
]
```

---

This software is licensed under the GNU General Public License Version 3.
