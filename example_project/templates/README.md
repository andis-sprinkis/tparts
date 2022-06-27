This directory contains the example `tparts` templates.

# Template directory

- `README.md`
- `init.awk` - initializes list of supported template values that are used in the template or in build process
    - `tparts` - associative array
        - key
            - Template value name: string
        - values
            - `block`: `1` or `0` - is it a left-indentable block value or not
            - `value`: string - text or markup language value
- `template.html` - document template
