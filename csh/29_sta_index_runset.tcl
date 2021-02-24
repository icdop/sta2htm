#!/usr/bin/tclsh
set STA2HTM [file dirname [file dirname [file normalize [info script]]]]

source $STA2HTM/tcl/LIB_STA.tcl

::LIB_STA::parse_argv $argv
::LIB_STA::read_sta_runset
::LIB_STA::report_index_runset

puts "INFO: sta_index_runset Done..."
