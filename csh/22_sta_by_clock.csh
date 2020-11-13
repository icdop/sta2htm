#!/usr/bin/tclsh
set STA_HOME [file dirname [file dirname [file normalize [info script]]]]

source $STA_HOME/tcl/LIB_DOP.tcl
source $STA_HOME/tcl/LIB_HTML.tcl
source $STA_HOME/tcl/LIB_STA.tcl
#source $STA_HOME/tcl/STA_CORNER.tcl
#source $STA_HOME/tcl/STA_WAIVE.tcl
#source $STA_HOME/tcl/STA_PT.tcl

::LIB_STA::parse_argv $argv
::LIB_STA::parse_argv $argv
::LIB_STA::read_config
::LIB_STA::read_corner_list
::LIB_STA::report_clock_end

puts "INFO: sta_clock_end Done..."
