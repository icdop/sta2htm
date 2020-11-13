#!/usr/bin/tclsh
#
# STA Libary Header
#
# By Albert Li 
# 2020/07/04
# 
namespace eval LIB_STA {
  variable STA_HOME  [file dirname [file dirname [file normalize [info script]]]]

  proc init_path {} {
    global env
    global STA_HOME

    set STA_HOME [file dirname [file dirname [file normalize [info script]]]]
    puts "###########################################################"
    puts "# STA LIBRARY ver.2020.07                                 #"
    puts "###########################################################"
    puts "INFO: STA_HOME = $STA_HOME"
  }

}

LIB_STA::init_path
