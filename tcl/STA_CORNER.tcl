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

variable STA_CORNER_LIST
variable STA_CORNER_NAME
variable STA_CORNER_DEF

proc reset_corner_list {} {
  variable STA_CORNER_NAME
  variable STA_CORNER_DEF

  array unset STA_CORNER_NAME
  array unset STA_CORNER_DEF
}

proc print_corner_list {} {
  variable STA_CORNER_NAME
  foreach sta_corner [lsort [array names STA_CORNER_NAME]] {
     puts "DEBUG: $sta_corner $STA_CORNER_NAME($sta_corner) $STA_CORNER_DEF($sta_corner)"
  }
}

proc check_corner_list {corner_list} {
  variable STA_CORNER_NAME

  set error 0
  foreach sta_corner $corner_list {
     if {![info exist STA_CORNER_NAME($sta_corner)]} {
        incr error
        puts "ERROR: STA_CORNER_NAME($sta_corner) is not defined!"
     }
  }
  return $error
}

proc read_sta_corner {{corner_setup "sta2htm.corner"}} {
  variable STA_CFG_DIR
  variable STA_CORNER_LIST
  variable STA_CORNER_NAME
  variable STA_CORNER_DEF
  
  if [file exist $corner_setup] {
     set filename $corner_setup
  } elseif [file exist "$STA_CFG_DIR/$corner_setup"] {
     set filename "$STA_CFG_DIR/$corner_setup"
  } else {
     return
  }
  set STA_CORNER_LIST ""
  puts "INFO: Reading corner table file '$filename'..."
  set fp [open $filename "r"]
  while {[gets $fp line]>=0} {
     if [regexp {^\#Mode\s+(\S+)} $line matched sta_mode] {
        puts "STA MODE = $sta_mode"
     } elseif [regexp {^(\d+)\_(\S+)} $line corner_name corner_id corner_postfix] {
        set STA_CORNER_NAME($corner_id) $corner_name
     } elseif [regexp {^(\d+)\s+(\S+)} $line matched corner_id corner_name] {
        set STA_CORNER_NAME($corner_id) $corner_name
     } else {
        continue
     }
     puts "CORNER: [format "%4s => %s" $corner_id $corner_name]"
     set STA_CORNER_DEF($corner_id) [lrange $line 2 end]
     lappend STA_CORNER_LIST $corner_id
  }
  close $fp
  puts "INFO: Total [array size STA_CORNER_NAME] corners."
}


proc get_corner_id {corner_name} {
  variable STA_CORNER_NAME
  foreach corner_id [array name STA_CORNER_NAME] {
    if {$corner_name==$STA_CORNER_NAME($corner_id)} {
       return $corner_id
    }
  } 
  return "999"
}

proc get_corner_name {corner_id} {
  variable STA_CORNER_NAME
  
  if [info exist STA_CORNER_NAME($corner_id)] { 
     set corner_name $STA_CORNER_NAME($corner_id)
  } elseif [regexp {^(\d+)\_(\S+)} $corner_id whole corner_id corner_name] {
  } else {
     set corner_name $corner_id
  }
  return $corner_name
}
}
::LIB_STA::reset_corner_list

