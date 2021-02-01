#!/usr/bin/tclsh
set STA_HOME [file dirname [file dirname [file normalize [info script]]]]

source $STA_HOME/tcl/LIB_STA.tcl

::LIB_STA::parse_argv $argv
::LIB_STA::read_config
::LIB_STA::read_corner
::LIB_STA::report_group_end

puts "INFO: sta_group_end Done..."
