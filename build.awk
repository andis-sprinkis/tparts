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
  value_lines, indent, \
  _indented_value_lines, _in_preformatted, _preformatted_begin_match, _preformatted_end_match, _value_lines_arr, _i \
) {
  split(value_lines, _value_lines_arr, "\n")

  _in_preformatted = 0
  for (_i in _value_lines_arr) {
    match(_value_lines_arr[_i], /(<pre>)|(<pre( .*))/, _preformatted_begin_match)
    match(_value_lines_arr[_i], /<\/pre>/, _preformatted_end_match)

    if (_preformatted_end_match[0] != "") _in_preformatted = 0
    else if (_preformatted_begin_match[0] != "") _in_preformatted = 1

    _indented_value_lines = _indented_value_lines ((_i == 1 || _in_preformatted || _preformatted_end_match[0]) ? "" : indent) _value_lines_arr[_i] "\n"
  }

  return trim_last_char(_indented_value_lines)
}

function document_make_values_index( \
  paths_values_dirs_arr, indexed_value_paths, result, \
  _cmd_find, _cmd_basename, _value_name, _i, _path, _is_indexed_path, _prop \
) {
  for (_i in paths_values_dirs_arr) {
    _is_indexed_path = 0

    for (_path in indexed_value_paths) {
      if (_is_indexed_path) break
      if (_path == paths_values_dirs_arr[_i]) _is_indexed_path = 1
    }

    if (! _is_indexed_path) {
      _cmd_find = "find " paths_values_dirs_arr[_i] "/_* -maxdepth 0 -type f"
      while ((_cmd_find | getline _line ) > 0) {
        _cmd_basename = "basename " _line
        _cmd_basename | getline _value_name
        close(_cmd_basename)

        indexed_value_paths[paths_values_dirs_arr[_i]][_value_name]["path"] = _line

        if (match(_line, /_block_.*/)) indexed_value_paths[paths_values_dirs_arr[_i]][_value_name]["type"] = "block"
        else if (match(_line, /_pre_.*/)) indexed_value_paths[paths_values_dirs_arr[_i]][_value_name]["type"] = "pre"
        else if (match(_line, /_inline_.*/)) indexed_value_paths[paths_values_dirs_arr[_i]][_value_name]["type"] = "inline"

        indexed_value_paths[paths_values_dirs_arr[_i]][_value_name]["value"] = read_value_file(indexed_value_paths[paths_values_dirs_arr[_i]][_value_name])
      }
      close(_cmd_find)
    }

    for (_value_name in indexed_value_paths[paths_values_dirs_arr[_i]]) {
      for (_prop in indexed_value_paths[paths_values_dirs_arr[_i]][_value_name]) {
        result[_value_name][_prop] = indexed_value_paths[paths_values_dirs_arr[_i]][_value_name][_prop]
      }
    }
  }
}

function find_values_placeholders_in_str( \
  str, values_index, result, \
  _value_index, _count \
) {
  for (_value_index in values_index) {
    _value_count = match(str, "<!-- " _value_index " -->")
    if (_value_count) result[_value_index] = 1
    _count += _value_count
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
      if (match(_fragment_out_arr[_i], _value_placeholder)) {
        if (values_index[_value]["type"] == "block") {
          if (_fragment_out_arr[_i] == "") break
          _indent = match(_fragment_out_arr[_i], /^\s+/, _indent_match) ? _indent_match[0] : ""
          sub(_value_placeholder, indent_lines(trim_last_char(values_index[_value]["value"]), _indent), _fragment_out_arr[_i])
        } else sub(_value_placeholder, values_index[_value]["value"], _fragment_out_arr[_i])
      }

      _fragment_out = _fragment_out _fragment_out_arr[_i] "\n"
    }

    _fragment_out = trim_last_char(_fragment_out)
  }

  return _fragment_out
}

function document_sub_placeholders_values( \
  paths_values_dirs_arr, result, \
  _fragment_out, _found_values \
) {
  _fragment_out = result["values_index"]["_inline_build_entrypoint"]["value"]

  while (find_values_placeholders_in_str(_fragment_out, result["values_index"], _found_values) > 0) {
    _fragment_out = sub_values_placeholders_in_str(_found_values, result["values_index"], _fragment_out)
    delete _found_values
  }

  gsub(/\s+<!-- _block_.*-->/, "", _fragment_out)

  result["fragment"] = _fragment_out
}

function document_write( \
  document, dir_site, \
  _path_dir_document_out, _path_file_document_out \
) {
  _path_dir_document_out = dir_site "/../dist/" document["values_index"]["_inline_path"]["value"]
  _path_file_document_out = _path_dir_document_out "/" document["values_index"]["_inline_filename"]["value"]

  if (! system("mkdir -p " _path_dir_document_out)) {
    print document["fragment"] >> _path_file_document_out
    close(_path_file_document_out)
  }
}

function document_copy_static(\
  path_document_src, dir_site, url_path, \
  _path_dir_static \
) {
  _path_dir_src_static = path_document_src "/static"
  _path_dir_dist_static = dir_site "/../dist/" url_path "/"

  if (! system("test -d " _path_dir_src_static)) system("cp -r " _path_dir_src_static "/* " _path_dir_dist_static)
}

BEGIN {
  if (! dir_site) {
    print "No root directory provided"
    exit 1
  }

  print "Root directory " dir_site

  system("rm -rf " dir_site "/../dist && mkdir -p " dir_site "/../dist/tmp/sitemap")

  _children_sitemap = ""

  print "Building generic documents"

  _cmd_find_documents = "find " dir_site "/documents/* -maxdepth 0 -type d"

  _indexed_value_paths[0] = ""

  while ((_cmd_find_documents | getline _path_dir_src_document ) > 0) {
    print "Building document " _path_dir_src_document

    _paths_values_dirs_arr_document[1] = dir_site
    _paths_values_dirs_arr_document[2] = _path_dir_src_document
    _document["values_index"][0] = ""
    document_make_values_index(_paths_values_dirs_arr_document, _indexed_value_paths, _document["values_index"])
    document_sub_placeholders_values(_paths_values_dirs_arr_document, _document)
    document_write(_document, dir_site)
    document_copy_static(_path_dir_src_document, dir_site, _document["values_index"]["_inline_path"]["value"])
    delete _document

    match(_path_dir_src_document, /.*\/(403|404|robots\.txt$)/, _noindex_match)

    if (! _noindex_match[0]) {
      print "Building sitemap entry"

      _paths_values_dirs_arr_sitemap_entry[1] = dir_site
      _paths_values_dirs_arr_sitemap_entry[2] = _path_dir_src_document
      _paths_values_dirs_arr_sitemap_entry[3] = dir_site "/sitemap/url"
      _sitemap_entry["values_index"][0] = ""
      document_make_values_index(_paths_values_dirs_arr_sitemap_entry, _indexed_value_paths, _sitemap_entry["values_index"])
      document_sub_placeholders_values(_paths_values_dirs_arr_sitemap_entry, _sitemap_entry)
      _children_sitemap = _children_sitemap _sitemap_entry["fragment"]
      delete _sitemap_entry

      print "Built sitemap entry"
    } else print "Skipping building sitemap entry"

    print "Built document " _path_dir_src_document
  }
  close(_cmd_find_documents)

  print "Built generic documents"

  print "Building sitemap"

  _path_file_children_sitemap = dir_site "/../dist/tmp/sitemap/_block_sitemap_children.xml"
  print _children_sitemap >> _path_file_children_sitemap 
  close(_path_file_children_sitemap)

  _paths_values_dirs_arr_sitemap[1] = dir_site
  _paths_values_dirs_arr_sitemap[2] = dir_site "/sitemap/document"
  _paths_values_dirs_arr_sitemap[3] = dir_site "/../dist/tmp/sitemap"
  _sitemap["values_index"][0] = ""
  document_make_values_index(_paths_values_dirs_arr_sitemap, _indexed_value_paths, _sitemap["values_index"])
  document_sub_placeholders_values(_paths_values_dirs_arr_sitemap, _sitemap)
  document_write(_sitemap, dir_site)
  delete _sitemap

  print "Built sitemap"

  system("rm -rf " dir_site "/../dist/tmp")

  print "Finished"

  exit
}
