#!/usr/bin/tclsh
set STA2HTM [file dirname [file dirname [file normalize [info script]]]]

source $STA2HTM/tcl/LIB_STA.tcl

::LIB_STA::parse_argv $argv
::LIB_STA::read_sta_config
::LIB_STA::report_uniq_end

puts "INFO: sta_uniq_end Done..."
