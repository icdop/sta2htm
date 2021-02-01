#!/usr/bin/tclsh
set STA_HOME [file dirname [file dirname [file normalize [info script]]]]

source $STA_HOME/tcl/LIB_STA.tcl

::LIB_STA::parse_argv $argv
::LIB_STA::read_config
::LIB_STA::read_corner
::LIB_STA::report_uniq_end
::LIB_STA::report_index_main

puts "INFO: sta_uniq_end Done..."
