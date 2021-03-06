#!/usr/bin/tclsh
#
# HTML Related Variable 
#
# By Albert Li 
# 2021/01/13
#

puts "INFO: Loading 'STA_HTML.tcl'..."  
namespace eval STA_HTML {

variable ICON
set ICON(logo_banner) {.icon/logo_banner.png}

variable LINK
set LINK(logo_banner) {http://www.lyg-semi.com/lyg_www/about.html}


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
