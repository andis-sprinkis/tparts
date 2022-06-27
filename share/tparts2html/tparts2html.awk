#!/usr/bin/awk

function get_tpart_path_from_list(tparts_dir_list, tpart_name) {
  for (i = split(tparts_dir_list, tparts_dir_list_array, ":"); i > 0; i--) {
    file_tpart_test = tparts_dir_list_array[i] "/" tpart_name

    if (!system("test -f " file_tpart_test)) return file_tpart_test
  }
}

function read_tparts(tparts, tparts_dir_list) {
  for (tpart_name in tparts) {
    file_tpart = get_tpart_path_from_list(tparts_dir_list, tpart_name)

    if (file_tpart != "") {
      while((getline line < file_tpart) > 0) tparts[tpart_name]["value"] = tparts[tpart_name]["value"] line "\n"

      tparts[tpart_name]["value"] = substr(tparts[tpart_name]["value"], 1, length(tparts[tpart_name]["value"]) - 1)
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

function tparts_to_html(dir_template, tparts, filename_template) {
  path_file_template = dir_template "/" filename_template

  while((getline line < path_file_template) > 0) {
    for (i in tparts) {
      tpart_tag = "<!-- " i " -->"

      if (tparts[i]["block"] && match(line, tpart_tag)) {
        substitution = indent_lines(tparts[i]["value"], match(line, /^\s*/, indent_match) ? indent_match[0] : "")
      } else substitution = tparts[i]["value"]

      sub(tpart_tag, substitution, line)
    }

    fragment_html = fragment_html line "\n"
  }

  fragment_html = substr(fragment_html, 1, length(fragment_html) - 1)

  return fragment_html
}

@include "init.awk"

BEGIN {
  filename_template = filename_template ? filename_template : "template.html"

  read_tparts(tparts, tparts_dir_list)
  print tparts_to_html(dir_template, tparts, filename_template)

  exit
}
