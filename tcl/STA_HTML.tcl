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
set ICON(lyg_logo)   {.icon/lyg_logo.png}
set ICON(lyg_banner) {.icon/lyg_banner.png}

variable BANNER
set BANNER(lyg-semi) {
  <a href=http://www.lyg-semi.com/lyg_www/about.html>
  <img src=.icon/lyg_banner.png width=250>
  </a>
  <br>
}

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
