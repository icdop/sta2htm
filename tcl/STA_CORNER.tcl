#!/usr/bin/tclsh
#
# Parse Library Corner List
#
# By Albert Li 
# 2020/07/04
# 
puts "INFO: Loading 'STA_CORNER.tcl'..."  
namespace eval LIB_STA {

variable DEBUG_MODE 0

variable CORNER_ID
variable CORNER_NAME

proc reset_corner_list {} {
  variable CORNER_ID
  variable CORNER_NAME

  array unset CORNER_ID
  array unset CORNER_NAME
}

proc print_corner_list {} {
  variable CORNER_ID
  foreach i [lsort [array names CORNER_ID]] {
     puts "DEBUG: $CORNER_ID($i) [split $i ","]"
  }
}

proc check_corner_list {corner_list} {
  variable CORNER_NAME

  set error 0
  foreach sta_corner $corner_list {
     if {![info exist CORNER_NAME($sta_corner)]} {
        incr error
        puts "ERROR: CORNER_NAME($sta_corner) is not defined!"
     }
  }
  return $error
}

proc read_corner_list {{corner_setup "sta2htm.corner"}} {
  global STA2HTM
  variable CORNER_ID
  variable STA_CFG_DIR
  
  if [file exist $corner_setup] {
     set filename $corner_setup
  } elseif [file exist "$STA_CFG_DIR/$corner_setup"] {
     set filename "$STA_CFG_DIR/$corner_setup"
  } elseif [file exist "$STA2HTM/etc/$corner_setup"] {
     set filename "$STA2HTM/etc/$corner_setup"
  } elseif [file exist $corner_setup.corner] {
     set filename $corner_setup.corner
  } else {
     return
  }
  puts "INFO: Reading corner table file '$filename'..."
  set fp [open $filename "r"]
  while {[gets $fp line]>=0} {
     if [regexp {^\#Mode\s+(\S+)} $line matched sta_mode] {
        puts "STA MODE = $sta_mode"
     } elseif [regexp {^(\d+)\_(\S+)} $line corner_name corner_id corner_postfix] {
        set_corner_id $corner_name $corner_id
     } elseif [regexp {^(\d+)\s+(\S+)} $line matched corner_id corner_name] {
        set_corner_id $corner_name $corner_id
     } else {
        continue
     }
     puts "CORNER: [format "%4s => %s" $corner_id $corner_name]"
  }
  close $fp
  puts "INFO: Total [array size CORNER_ID] corners."
}

proc set_corner_id {corner_name {corner_id "999"}} {
  variable CORNER_ID
  variable CORNER_NAME

  set CORNER_ID($corner_name) $corner_id
  set CORNER_NAME($corner_id) $corner_name

}

proc get_corner_id {corner_name} {
  variable CORNER_ID
  
  if [info exist CORNER_ID($corner_name)] { 
     set corner_id $CORNER_ID($corner_name)
  } elseif [regexp {^(\d+)\_(\S+)} $corner_name whole corner_id corner_postfix] {
  } else {
     set corner_id "999"
  }
  return $corner_id
}
proc get_corner_name {corner_id} {
  variable CORNER_NAME
  
  if [info exist CORNER_NAME($corner_id)] { 
     set corner_name $CORNER_NAME($corner_id)
  } elseif [regexp {^(\d+)\_(\S+)} $corner_id whole corner_id corner_name] {
  } else {
     set corner_name $corner_id
  }
  return $corner_name
}
}
::LIB_STA::reset_corner_list

