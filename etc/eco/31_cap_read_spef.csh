#!/usr/bin/tclsh
set env(DQR_HOME) [file dirname [file dirname [file normalize [info script]]]]
source $env(DQR_HOME)/tcl/LIB_SPEF.tcl

eval ::LIB_SPEF::create_cap_file $argv

