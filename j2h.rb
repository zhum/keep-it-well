#!/usr/bin/env ruby

require 'json2html'

#json2html = Json2Html.new do
#    node '<div><span id="%<key>s_label">%<name>s</span><span id="%<key>s">%<value>s</span></div>'
#end

body = Json2Html.new.to_html(File.open(ARGV[0]).read).gsub('/div>',"/div>\n")

puts <<"HEAD"
<!doctype html5>
<html>
<head>
</head>
<body>
<style>
.json-node {
  pad-left: 10px;
}
</style>
HEAD

puts body

puts "</body></html>"
