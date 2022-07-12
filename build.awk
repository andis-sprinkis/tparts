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

function indent_lines( \
  value_lines_arr, indent, \
  _indented_value_lines, _in_preformatted, _preformatted_begin_match, _preformatted_end_match, _i \
) {
  _in_preformatted = 0
  for (_i in value_lines_arr) {
    match(value_lines_arr[_i], /(<pre>)|(<pre( .*))/, _preformatted_begin_match)
    match(value_lines_arr[_i], /<\/pre>/, _preformatted_end_match)

    if (_preformatted_end_match[0] != "") _in_preformatted = 0
    else if (_preformatted_begin_match[0] != "") _in_preformatted = 1

    _indented_value_lines = _indented_value_lines ((_i == 1 || _in_preformatted || _preformatted_end_match[0]) ? "" : indent) value_lines_arr[_i] "\n"
  }

  return trim_last_char(_indented_value_lines)
}

function make_values_index( \
  paths_values_dirs_arr, result, \
  _cmd_find, _cmd_basename, _value_name, _i \
) {
  for (_i in paths_values_dirs_arr) {
    _cmd_find = "find " paths_values_dirs_arr[_i] "/_* -maxdepth 0 -type f"
    while ((_cmd_find | getline _line ) > 0) {
      _cmd_basename = "basename " _line
      _cmd_basename | getline _value_name
      close(_cmd_basename)
      result[_value_name]["path"] = _line

      if (match(_line, /_block_.*/)) result[_value_name]["type"] = "block"
      else if (match(_line, /_pre_.*/)) result[_value_name]["type"] = "pre"
      else if (match(_line, /_inline_.*/)) result[_value_name]["type"] = "inline"
    }
    close(_cmd_find)
  }
}

function find_values_placeholders_in_str( \
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

function read_value_file( \
  value, \
  _value_lines, _line \
) {
  while((getline _line < (value["path"])) > 0) {
    if (value["type"] == "inline") {
      _value_lines = _value_lines _line
      continue
    }
    if (value["type"] == "pre") {
      _value_lines = _value_lines escape_ml(_line) "\n"
      continue
    }
    if (value["type"] == "block") {
      _value_lines = _value_lines _line "\n"
      continue
    }
  }
  close(value["path"])

  if (value["type"] == "pre") _value_lines = trim_last_char(_value_lines)

  return _value_lines
}

function sub_values_placeholders_in_str( \
  found_values, values_index, fragment, \
  _value_lines, _value_lines_array, _fragment_out, _indent, _indent_match, _value_placeholder, _value, _empty_line, _i \
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

          split(trim_last_char(_value_lines), _value_lines_array, "\n")
          sub(_value_placeholder, indent_lines(_value_lines_array, _indent), _fragment_out_arr[_i])
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

function document_build( \
  paths_values_dirs_arr, result, \
  _fragment_out, _found_values \
) {
  make_values_index(paths_values_dirs_arr, result["values_index"])

  _fragment_out = read_value_file(result["values_index"]["_inline_build_entrypoint"])

  while (find_values_placeholders_in_str(_fragment_out, result["values_index"], _found_values) > 0) {
    _fragment_out = sub_values_placeholders_in_str(_found_values, result["values_index"], _fragment_out)
    delete _found_values
  }

  result["fragment"] = rm_block_placholder_lines(_fragment_out)
}

function document_write( \
  document, dir_site, url_path, document_filename, \
  _path_dir_document_out, _path_file_document_out \
) {
  _path_dir_document_out = dir_site "/../dist/" url_path
  _path_file_document_out = _path_dir_document_out "/" document_filename
  if (! system("mkdir -p " _path_dir_document_out)) {
    print document["fragment"] >> _path_file_document_out
    close(_path_file_document_out)
  }
}

function document_copy_static(path_document_src, dir_site, url_path) {
  if (! system("test -d " path_document_src "/static")) {
    system("cp -r " path_document_src "/static/* " dir_site "/../dist/" url_path "/")
  }
}

BEGIN {
  if (! dir_site) {
    print "No root directory provided"
    exit 1
  }
  
  print "Root directory " dir_site

  print "Finding generic documents"
  _cmd_find_documents = "find " dir_site "/documents/* -maxdepth 0 -type d"
  _i = 1
  while ((_cmd_find_documents | getline _line ) > 0) {
    _paths_documents[_i] = _line
    print "Found " _line
    _i++
  }
  close(_cmd_find_documents)

  system("rm -rf " dir_site "/../dist && mkdir -p " dir_site "/../dist/tmp/sitemap")

  _children_sitemap = ""

  print "Building generic documents"
  for (_i in _paths_documents) {
    print "Building document " _paths_documents[_i]

    _paths_values_dirs_arr_document[1] = dir_site
    _paths_values_dirs_arr_document[2] = _paths_documents[_i]
    _document["values_index"][0] = ""

    document_build(_paths_values_dirs_arr_document, _document)
    _document_url_path = read_value_file(_document["values_index"]["_inline_path"])
    _document_filename = read_value_file(_document["values_index"]["_inline_filename"])
    document_write(_document, dir_site, _document_url_path, _document_filename)
    document_copy_static(_paths_documents[_i], dir_site, _document_url_path)
    delete _document

    _cmd_basename = "basename " _paths_documents[_i]
    _cmd_basename | getline _basename
    close(_cmd_basename)

    if (_basename != "404" && _basename != "403" && _basename != "robots.txt") {
      print "Building sitemap fragment"
      _paths_values_dirs_arr_sitemap_entry[1] = dir_site
      _paths_values_dirs_arr_sitemap_entry[2] = _paths_documents[_i]
      _paths_values_dirs_arr_sitemap_entry[3] = dir_site "/sitemap/url"
      _sitemap_fragment["values_index"][0] = ""

      document_build(_paths_values_dirs_arr_sitemap_entry, _sitemap_fragment)
      _children_sitemap = _children_sitemap _sitemap_fragment["fragment"]
      delete _sitemap_fragment

      print "Built sitemap fragment"
    } else print "Skipping building sitemap fragment"

    print "Built document " _paths_documents[_i]
  }
  print "Built generic documents"

  print "Building sitemap"

  _path_file_children_sitemap = dir_site "/../dist/tmp/sitemap/_block_sitemap_children.xml"
  print _children_sitemap >> _path_file_children_sitemap 
  close(_path_file_children_sitemap)

  _paths_values_dirs_arr_sitemap[1] = dir_site
  _paths_values_dirs_arr_sitemap[2] = dir_site "/sitemap/document"
  _paths_values_dirs_arr_sitemap[3] = dir_site "/../dist/tmp/sitemap"
  _sitemap["values_index"][0] = ""

  document_build(_paths_values_dirs_arr_sitemap, _sitemap)
  _sitemap_url_path = read_value_file(_sitemap["values_index"]["_inline_path"])
  _sitemap_filename = read_value_file(_sitemap["values_index"]["_inline_filename"])
  document_write(_sitemap, dir_site, _sitemap_url_path, _sitemap_filename)
  delete _sitemap

  print "Built sitemap"

  system("rm -rf " dir_site "/../dist/tmp")

  print "Finished"

  exit
}
