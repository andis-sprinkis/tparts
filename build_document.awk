function escapeHtml(s) {
  gsub(/&/, "\\\\\\&amp;", s)
  gsub(/</, "\\\\\\&lt;", s)
  gsub(/>/, "\\\\\\&gt;", s)
  gsub(/"/, "\\\\\\&quot;", s)
  gsub(/'/, "\\\\\\&apos;", s)

  return s
}

function trim_last_char(s) {
  return substr(s, 1, length(s) - 1)
}

function read_values_index_file(path_values_index, result) {
  count = 0

  while((getline line < path_values_index) > 0) {
    count ++
    split(line, basename_path, ":")
    result[basename_path[1]]["path"] = basename_path[2]

    if (match(basename_path[1], /tparts_block_.*/)) result[basename_path[1]]["type"] = "block"
    else if (match(basename_path[1], /tparts_pre_.*/)) result[basename_path[1]]["type"] = "pre"
    else if (match(basename_path[1], /tparts_inline_.*/)) result[basename_path[1]]["type"] = "inline"
  }

  return count
}

function recognise_values_in_string(string, values_index, result) {
  split(string, string_array, "\n")
  count = 0

  for (line_index in string_array) {
    for (value_index in values_index) {
      if (match(string_array[line_index], "<!-- " value_index " -->")) {
        result[value_index] = 1
        count++
      }
    }
  }

  return count
}

function indent_lines(value, indent) {
  indented_value = ""
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

function substitute_with_recognized_values(recognised_values, values_index, fragment_html) {
  for (recognised_value in recognised_values) {
    if (recognised_values[recognised_value] == 1) {
      recognised_value_lines = ""
      while((getline line < (values_index[recognised_value]["path"])) > 0) {
        if (values_index[recognised_value]["type"] == "inline") recognised_value_lines = recognised_value_lines line
        else if (values_index[recognised_value]["type"] == "pre") recognised_value_lines = recognised_value_lines escapeHtml(line) "\n"
        else if (values_index[recognised_value]["type"] == "block") recognised_value_lines = recognised_value_lines line "\n"
        else continue
      }

      if (values_index[recognised_value]["type"] == "pre") recognised_value_lines = trim_last_char(recognised_value_lines)

      split(fragment_html, fragment_html_array, "\n")
      fragment_html = ""
      recognised_value_placeholder = "<!-- " recognised_value " -->"

      for (line_index in fragment_html_array) {
        empty_line = 0
        if (match(fragment_html_array[line_index], recognised_value_placeholder)) {
          if (values_index[recognised_value]["type"] == "block") {
            if (fragment_html_array[line_index] == "") {
              empty_line = (empty_line || 1)
              break
            }

            indent = match(fragment_html_array[line_index], /^\s+/, indent_match) ? indent_match[0] : ""

            sub(recognised_value_placeholder, indent_lines(trim_last_char(recognised_value_lines), indent), fragment_html_array[line_index])
          } else {
            sub(recognised_value_placeholder, recognised_value_lines, fragment_html_array[line_index])
          }
        }

        fragment_html = fragment_html fragment_html_array[line_index] "\n"
      }

      fragment_html = trim_last_char(fragment_html)
    }
  }

  return fragment_html
}

function remove_block_value_placeholder_lines(s) {
  gsub(/\s+<!-- tparts_block_.*-->/, "", s)
  return s
}

BEGIN {
  read_values_index_file(path_values_index, values_index)

  while((getline line < values_index[filename_value_entrypoint]["path"]) > 0) fragment_html = fragment_html line "\n"

  while (recognise_values_in_string(fragment_html, values_index, recognised_values) > 0) {
    fragment_html = substitute_with_recognized_values(recognised_values, values_index, fragment_html)
    delete recognised_values
  }

  fragment_html = remove_block_value_placeholder_lines(fragment_html)
  fragment_html = trim_last_char(fragment_html)

  print fragment_html

  exit
}
