function escapeHtml(t) {
  gsub(/&/,  "\\&amp;", t);
  gsub(/</,  "\\&lt;", t);
  gsub(/>/,  "\\&gt;", t);
  gsub(/"/,  "\\&quot;", t);
  gsub(/'/,  "\\&x27;", t);
  return t;
}

function escapeHtmlFile(path_file) {
  fragment_escaped = ""

  while((getline line < path_file) > 0) fragment_escaped = fragment_escaped escapeHtml(line) "\n"

  fragment_escaped = substr(fragment_escaped, 1, length(fragment_escaped) - 1)

  return fragment_escaped
}

BEGIN {
  print escapeHtmlFile(ARGV[1])
  exit
}
