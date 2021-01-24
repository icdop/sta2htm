#!/usr/bin/tclsh
#
# STA Libary Header
#
# By Albert Li 
# 2020/07/04
# 
namespace eval LIB_STA {
  global STA2HTM  
  set STA2HTM [file dirname [file dirname [file normalize [info script]]]]

  proc init_path {} {
    global env
    global STA2HTM

    set STA2HTM [file dirname [file dirname [file normalize [info script]]]]
    puts "###########################################################"
    puts "# STA2HTM LIBRARY ver.2020.07                             #"
    puts "###########################################################"
    puts "INFO: STA2HTM = $STA2HTM"
  }

}

LIB_STA::init_path
