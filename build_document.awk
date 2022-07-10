function make_values_index( \
  paths_values_dirs_arr, result, \
  _cmd_find, _cmd_basename, _value_name, _i \
) {
  for (_i in paths_values_dirs_arr) {
    _cmd_find = "find " paths_values_dirs_arr[_i] " -name \"_*\""
    while ((_cmd_find | getline _line ) > 0) {
      _cmd_basename = "basename " _line
      _cmd_basename | getline _value_name
      close(_cmd_basename)
      result[_value_name]["path"] = _line

      if (match(_line, /_block_.*/)) result[_value_name]["type"] = "block"
      else if (match(_line, /_pre_.*/)) result[_value_name]["type"] = "pre"
      else if (match(_line, /_inline_.*/)) result[_value_name]["type"] = "inline"
    }
  }
}

function escape_ml(str) {
  gsub(/&/, "\\\\\\&amp;", str)
  gsub(/</, "\\\\\\&lt;", str)
  gsub(/>/, "\\\\\\&gt;", str)
  gsub(/"/, "\\\\\\&quot;", str)
  gsub(/'/, "\\\\\\&apos;", str)

  return str
}

function trim_last_char(str) {
  return substr(str, 1, length(str) - 1)
}

function find_values_in_str( \
  str, values_index, result, \
  _line_index, _value_index, _count \
) {
  split(str, _str_arr, "\n")
  _count = 0

  for (_line_index in _str_arr) {
    for (_value_index in values_index) {
      if (match(_str_arr[_line_index], "<!-- " _value_index " -->")) {
        result[_value_index] = 1
        _count++
      }
    }
  }

  return _count
}

function indent_lines( \
  value, indent, \
  _value_lines, _indented_value_lines, _in_preformatted, _preformatted_begin_match, _preformatted_end_match, _i \
) {
  split(value, _value_lines, "\n")

  _in_preformatted = 0
  for (_i in _value_lines) {
    match(_value_lines[_i], /(<pre>)|(<pre( .*))/, _preformatted_begin_match)
    match(_value_lines[_i], /<\/pre>/, _preformatted_end_match)

    if (_preformatted_end_match[0] != "") _in_preformatted = 0
    else if (_preformatted_begin_match[0] != "") _in_preformatted = 1

    _indented_value_lines = _indented_value_lines ((_i == 1 || _in_preformatted || _preformatted_end_match[0]) ? "" : indent) _value_lines[_i] "\n"
  }

  return trim_last_char(_indented_value_lines)
}

function read_value_file( \
  value, \
  _value_lines, _line \
) {
  while((getline _line < (value["path"])) > 0) {
    if (value["type"] == "inline") _value_lines = _value_lines _line
    else if (value["type"] == "pre") _value_lines = _value_lines escape_ml(_line) "\n"
    else if (value["type"] == "block") _value_lines = _value_lines _line "\n"
    else continue
  }
  close(value["path"])

  if (value["type"] == "pre") _value_lines = trim_last_char(_value_lines)

  return _value_lines
}

function sub_placeholders_values( \
  found_values, values_index, fragment, \
  _value_lines, _fragment_out, _indent, _indent_match, _value_placeholder, _value, _empty_line, _i \
) {
  for (_value in found_values) {
    _value_lines = ""
    _read = 0

    split(fragment, _fragment_out_arr, "\n")
    _fragment_out = ""
    _value_placeholder = "<!-- " _value " -->"

    for (_i in _fragment_out_arr) {
      _empty_line = 0
      if (match(_fragment_out_arr[_i], _value_placeholder)) {
        if (! _read) {
          _value_lines = read_value_file(values_index[_value])
          _read = 1
        }

        if (values_index[_value]["type"] == "block") {
          if (_fragment_out_arr[_i] == "") {
            _empty_line = (_empty_line || 1)
            break
          }

          _indent = match(_fragment_out_arr[_i], /^\s+/, _indent_match) ? _indent_match[0] : ""

          sub(_value_placeholder, indent_lines(trim_last_char(_value_lines), _indent), _fragment_out_arr[_i])
        } else {
          sub(_value_placeholder, _value_lines, _fragment_out_arr[_i])
        }
      }

      _fragment_out = _fragment_out _fragment_out_arr[_i] "\n"
    }

    _fragment_out = trim_last_char(_fragment_out)
  }

  return _fragment_out
}

function rm_block_placholder_lines(s) {
  gsub(/\s+<!-- _block_.*-->/, "", s)
  return s
}

function build_document( \
  paths_values_dirs, path_dir_root, url_path, \
  _fragment_out, _paths_values_dirs_arr, _values_index, _document_filename, _found_values \
) {
  split(paths_values_dirs, _paths_values_dirs_arr, ":")

  make_values_index(_paths_values_dirs_arr, _values_index)

  _fragment_out = read_value_file(_values_index["_inline_build_entrypoint"])

  while (find_values_in_str(_fragment_out, _values_index, _found_values) > 0) {
    _fragment_out = sub_placeholders_values(_found_values, _values_index, _fragment_out)
    delete _found_values
  }

  _fragment_out = rm_block_placholder_lines(_fragment_out)

  if (!url_path) url_path = read_value_file(_values_index["_inline_path"])
  _document_filename = read_value_file(_values_index["_inline_filename"])

  if (! system("mkdir -p " path_dir_root "/" url_path)) print _fragment_out >> path_dir_root "/" url_path "/" _document_filename
  
  if (! system("test -d " _paths_values_dirs_arr[length(_paths_values_dirs_arr)] "/static")) {
    system("cp -r " _paths_values_dirs_arr[length(_paths_values_dirs_arr)] "/static/* " path_dir_root "/" url_path "/")
  }
}

BEGIN {
  build_document(paths_values_dirs, path_dir_root, url_path)

  exit
}
