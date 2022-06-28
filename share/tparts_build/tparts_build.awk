#!/usr/bin/awk

function get_value_path_from_dirs_list(tparts_values_dir_list, value_name) {
  for (k = split(tparts_values_dir_list, tparts_values_dir_list_array, ":"); k > 0; k--) {
    file_value_test = tparts_values_dir_list_array[k] "/" value_name

    if (!system("test -f " file_value_test)) return file_value_test
  }
}

function read_tparts_values(tparts_values, tparts_values_dir_list) {
  for (j in tparts_values) {
    file_value = get_value_path_from_dirs_list(tparts_values_dir_list, j)

    if (file_value != "") {
      while((getline line < file_value) > 0) tparts_values[j]["value"] = tparts_values[j]["value"] line "\n"

      tparts_values[j]["value"] = substr(tparts_values[j]["value"], 1, length(tparts_values[j]["value"]) - 1)
    }
  }
}

function indent_lines(value, indent) {
  split(value, value_lines, "\n")

  in_preformatted = 0
  for (i in value_lines) {
    # For HTML code formatting and rendering consistency, the <pre> tags and children are being not indented.
    match(value_lines[i], /(<pre>)|(<pre( .*))/, preformatted_begin_match)
    match(value_lines[i], /<\/pre>/, preformatted_end_match)

    if (preformatted_end_match[0] != "") in_preformatted = 0
    else if (preformatted_begin_match[0] != "") in_preformatted = 1

    indented_value = indented_value ((i == 1 || in_preformatted || preformatted_end_match[0]) ? "" : indent) value_lines[i] "\n"
  }

  indented_value = substr(indented_value, 1, length(indented_value) - 1)

  return indented_value
}

function build_markup(dir_template, tparts_values, filename_template) {
  path_file_template = dir_template "/" filename_template

  while((getline line < path_file_template) > 0) {
    empty_line = 0

    for (i in tparts_values) {
      tpart_tag = "<!-- " i " -->"

      if (tparts_values[i]["block"] && match(line, tpart_tag)) {
        if (tparts_values[i]["value"] == "") {
          empty_line = (empty_line || 1)
          break
        }

        substitution = indent_lines(tparts_values[i]["value"], match(line, /^\s*/, indent_match) ? indent_match[0] : "")
      } else substitution = tparts_values[i]["value"]

      sub(tpart_tag, substitution, line)
    }

    if (empty_line) continue

    fragment_html = fragment_html line "\n"
  }

  fragment_html = substr(fragment_html, 1, length(fragment_html) - 1)

  return fragment_html
}

@include "init.awk"

BEGIN {
  filename_template = filename_template ? filename_template : "template.html"

  read_tparts_values(tparts_values, tparts_values_dir_list)
  print build_markup(dir_template, tparts_values, filename_template)

  exit
}
