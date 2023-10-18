# `tparts`

A static site generator script written in GNU AWK.

Requires `gawk`, `find` in a typical \*nix shell environment.

---

To build the example project ([on github.io](https://andis-sprinkis.github.io/tparts/), [on gitlab.io](https://andis-sprinkis.gitlab.io/tparts)) from source files found in `./site` into the output directory `./dist`, run

```sh
tparts ./site ./dist
```

or run the `build` script.

## Goals

1. Compiles web documents, handling the repetative parts.
1. Boilerplate for low-maintenance, static websites.
1. No external dependencies I need to worry about.
1. Hopefully works _forever_, as I don't expect GNU AWK to change a lot.
1. Remains as rudamentary and concise as possible.
1. Example project has good accessibility.

## Non-goals

1. Separating content and document markup (e.g. Markdown parser).
1. Document templating language.

---

## How does the script work?

This tparts script is for building a set of plain text files – documents, in their target directories, from reusable, hierarchially inheritant parts – template value files, prefixed by `_inline_`, `_block_`, `_pre_`.

In the example project it means creating the HTML documents, supplementary files like `manifest.webmanifest`, `robots.txt`, `sitemap.xml` from the globally defined and the document specific values in the available template value files. And also copying static assets to their specified document directories.

In value files, the template value placeholders to be subsituted are other value file names wrapped in HTML comment syntax, e.g. `<-- _inline_lastmod -->` will be subsituted in place with contents of a file `_inline_lastmod`. Substitutions are recursive.

Template value file name prefixes determine value placeholder substitution type – how the text value will be inserted in higher order document template output:

-   `_inline_` – to be inserted inline

    (The configuration values, which don't get directly inserted into the documents also use this prefix.)

-   `_block_` – to be inserted as a block of one or multiple new lines
-   `_pre_` – to be inserted as preformatted text (HTML `<pre>`)

---

Template value files values can be defined in a hierarchy of inheritance scopes, e.g. in the example project, the value files under

-   `./site/*` are project scope values
-   `./site/(documents|sitemap)/<document label>/*` are document local scope values

where document local scope value files overwrite project scope values.

---

Some notable value files and their contents:

-   `_inline_build_entrypoint` – name of the root level template value file for a document.
-   `_inline_path` – output document nested directory path in the project build.
-   `_inline_filename` – output filename of a document in the project build.
-   `_inline_lastmod` – document last modified date, used in sitemap entries.

### Data structures

#### Template values files index

Identified as `_values_files_index`.

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

Identified as `_generic_documents`, `_sitemap_entry`, `_sitemap`.

While the `_values_files_index` is a cache of all template values, these values are subsequently written in document-level values indices, being resolved according theirn hierarchy of scopes.

When building a document level values index, the values defined on the document scope e.g. `./site/documents/index/_inline_title` take precedence over the global scope value `./site/_inline_title`.

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
