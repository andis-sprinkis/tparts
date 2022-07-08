function escape_ml(s) {
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
  i = 0

  while((getline line < path_values_index) > 0) {
    i++
    split(line, basename_path, ":")
    result[basename_path[1]]["path"] = basename_path[2]

    if (match(basename_path[1], /_block_.*/)) result[basename_path[1]]["type"] = "block"
    else if (match(basename_path[1], /_pre_.*/)) result[basename_path[1]]["type"] = "pre"
    else if (match(basename_path[1], /_inline_.*/)) result[basename_path[1]]["type"] = "inline"
  }

  return i
}

function recognise_values_in_string(string, values_index, result) {
  split(string, string_array, "\n")
  i = 0

  for (line_index in string_array) {
    for (value_index in values_index) {
      if (match(string_array[line_index], "<!-- " value_index " -->")) {
        result[value_index] = 1
        i++
      }
    }
  }

  return i
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

function substitute_with_recognized_values(recognised_values, values_index, fragment_out) {
  for (recognised_value in recognised_values) {
    if (recognised_values[recognised_value]) {
      recognised_value_lines = ""
      while((getline line < (values_index[recognised_value]["path"])) > 0) {
        if (values_index[recognised_value]["type"] == "inline") recognised_value_lines = recognised_value_lines line
        else if (values_index[recognised_value]["type"] == "pre") recognised_value_lines = recognised_value_lines escape_ml(line) "\n"
        else if (values_index[recognised_value]["type"] == "block") recognised_value_lines = recognised_value_lines line "\n"
        else continue
      }

      if (values_index[recognised_value]["type"] == "pre") recognised_value_lines = trim_last_char(recognised_value_lines)

      split(fragment_out, fragment_out_array, "\n")
      fragment_out = ""
      recognised_value_placeholder = "<!-- " recognised_value " -->"

      for (line_index in fragment_out_array) {
        empty_line = 0
        if (match(fragment_out_array[line_index], recognised_value_placeholder)) {
          if (values_index[recognised_value]["type"] == "block") {
            if (fragment_out_array[line_index] == "") {
              empty_line = (empty_line || 1)
              break
            }

            indent = match(fragment_out_array[line_index], /^\s+/, indent_match) ? indent_match[0] : ""

            sub(recognised_value_placeholder, indent_lines(trim_last_char(recognised_value_lines), indent), fragment_out_array[line_index])
          } else {
            sub(recognised_value_placeholder, recognised_value_lines, fragment_out_array[line_index])
          }
        }

        fragment_out = fragment_out fragment_out_array[line_index] "\n"
      }

      fragment_out = trim_last_char(fragment_out)
    }
  }

  return fragment_out
}

function remove_block_value_placeholder_lines(s) {
  gsub(/\s+<!-- _block_.*-->/, "", s)
  return s
}

BEGIN {
  read_values_index_file(path_values_index, values_index)

  while((getline line < values_index["_inline_build_entrypoint"]["path"]) > 0) {
    fragment_out = fragment_out line "\n"
  }

  while (recognise_values_in_string(fragment_out, values_index, recognised_values) > 0) {
    fragment_out = substitute_with_recognized_values(recognised_values, values_index, fragment_out)
    delete recognised_values
  }

  fragment_out = remove_block_value_placeholder_lines(fragment_out)
  fragment_out = trim_last_char(fragment_out)

  print fragment_out >> path_output

  exit
}
