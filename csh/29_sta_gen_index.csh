#!/usr/bin/tclsh
set STA_HOME [file dirname [file dirname [file normalize [info script]]]]

source $STA_HOME/tcl/LIB_DOP.tcl
source $STA_HOME/tcl/LIB_HTML.tcl
source $STA_HOME/tcl/LIB_STA.tcl

::LIB_STA::parse_argv $argv
::LIB_STA::parse_argv $argv
::LIB_STA::read_config
::LIB_STA::read_corner_list

::LIB_STA::report_index_mode
::LIB_STA::report_index_corner
::LIB_STA::report_index_main mode.htm

puts "INFO: sta_index Done..."
