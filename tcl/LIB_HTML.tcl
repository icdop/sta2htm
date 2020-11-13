#!/usr/bin/tclsh
#
# Parse Timing Report File
#
# By Albert Li 
# 2020/07/02
#
# package require LIB_PLOT

puts "INFO: Loading 'LIB_HTML.tcl'..."  
namespace eval LIB_HTML {

variable TABLE_CSS

set TABLE_CSS(sta_tbl) {
<style>
#sta_tbl {
  font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
  border-collapse: collapse;
}

#sta_tbl td, #sta_tbl th {
  border: 1px solid #ddd;
  padding: 8px;
}

#sta_tbl tr:nth-child(even){background-color: #f2f2f2;}

#sta_tbl tr:hover {background-color: #ddd;}

#sta_tbl th {
  padding-top: 12px;
  padding-bottom: 12px;
  text-align: left;
  background-color: #4CAF50;
  color: white;
}
</style>
}
}
