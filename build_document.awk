function resolve_values_paths(list_dir_values_paths_array, result) {
  for (i in list_dir_values_paths_array) {
    cmd = "find " list_dir_values_paths_array[i] " -name \"_*\""
    while ((cmd | getline line ) > 0) {
      cmd2 = "basename " line
      cmd2 | getline result_index
      close(cmd2)
      result[result_index]["path"] = line

      if (match(line, /_block_.*/)) result[result_index]["type"] = "block"
      else if (match(line, /_pre_.*/)) result[result_index]["type"] = "pre"
      else if (match(line, /_inline_.*/)) result[result_index]["type"] = "inline"
    }
  }
}

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
    match(value_lines[i], /(<pre>)|(<pre( .*))/, preformatted_begin_match)
    match(value_lines[i], /<\/pre>/, preformatted_end_match)

    if (preformatted_end_match[0] != "") in_preformatted = 0
    else if (preformatted_begin_match[0] != "") in_preformatted = 1

    indented_value = indented_value ((i == 1 || in_preformatted || preformatted_end_match[0]) ? "" : indent) value_lines[i] "\n"
  }

  indented_value = substr(indented_value, 1, length(indented_value) - 1)
  return indented_value
}

function read_recognised_value_lines(recognised_value) {
  recognised_value_lines = ""

  while((getline line < (recognised_value["path"])) > 0) {
    if (recognised_value["type"] == "inline") recognised_value_lines = recognised_value_lines line
    else if (recognised_value["type"] == "pre") recognised_value_lines = recognised_value_lines escape_ml(line) "\n"
    else if (recognised_value["type"] == "block") recognised_value_lines = recognised_value_lines line "\n"
    else continue
  }
  close(recognised_value["path"])

  if (recognised_value["type"] == "pre") recognised_value_lines = trim_last_char(recognised_value_lines)

  return recognised_value_lines
}

function substitute_with_recognized_values(recognised_values, values_index, fragment_out) {
  for (recognised_value in recognised_values) {
    recognised_value_lines = read_recognised_value_lines(values_index[recognised_value])

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

  return fragment_out
}

function remove_block_value_placeholder_lines(s) {
  gsub(/\s+<!-- _block_.*-->/, "", s)
  return s
}

BEGIN {
  split(list_dir_values_paths, list_dir_values_paths_array, ":")
  resolve_values_paths(list_dir_values_paths_array, values_index)

  while((getline line < values_index["_inline_build_entrypoint"]["path"]) > 0) fragment_out = fragment_out line "\n"
  close(values_index["_inline_build_entrypoint"]["path"])

  while (recognise_values_in_string(fragment_out, values_index, recognised_values) > 0) {
    fragment_out = substitute_with_recognized_values(recognised_values, values_index, fragment_out)
    delete recognised_values
  }

  fragment_out = trim_last_char(remove_block_value_placeholder_lines(fragment_out))

  if (!url_path) url_path = read_recognised_value_lines(values_index["_inline_path"])
  document_filename = read_recognised_value_lines(values_index["_inline_filename"])

  if (! system("mkdir -p " path_root "/" url_path)) print fragment_out >> path_root "/" url_path "/" document_filename
  
  if (! system("test -d " list_dir_values_paths_array[length(list_dir_values_paths_array)] "/static")) {
    system("cp -r " list_dir_values_paths_array[length(list_dir_values_paths_array)] "/static/* " path_root "/" url_path "/")
  }

  exit
}
