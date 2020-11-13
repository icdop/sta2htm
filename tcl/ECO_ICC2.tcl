#!/usr/bin/tclsh
#
# Parse ICC2 ECO output from PTECO
#
# By Albert Li 
# 2016/07/20
# 
puts "INFO: Loading 'ECO_ICC2.tcl'..."  
namespace eval ICC2 {

  variable ECO_LOG_FILE "read_eco.log"
  variable ECO_LOG stdout
  variable ECO_PREFIX "FixHoldECO_0728"
  variable ECO_SERIAL 50

  proc init {{filename ""}} {
     variable ECO_LOG
     variable ECO_LOG_FILE
     if {$filename == ""} {
        set ECO_LOG_FILE [format "read_eco.%s.log" [exec date +%m%d%H%M%S] ]
     } else {
         set ECO_LOG_FILE $filename
     }
     puts "INFO: read_eco log file $ECO_LOG_FILE"
     set ECO_LOG [open $ECO_LOG_FILE "w"]
     close $ECO_LOG
  }
  proc log_puts str {
     variable ECO_LOG
     variable ECO_LOG_FILE
     set ECO_LOG [open $ECO_LOG_FILE "a"]
     puts $ECO_LOG [format "%s" $str]
     close $ECO_LOG
  }


  proc get_pin {pin_name} {
       return $pin_name
       return [::LIB_ECO::full_hier_name $pin_name]
  }
  proc get_pins {pin_name} {
       return $pin_name
       return [::LIB_ECO::full_hier_name $pin_name]
  }
  proc current_instance {{name ""}} {
       log_puts "current_instance $name"
       ::LIB_ECO::set_current_instance $name
  } 
  proc size_cell {cell_name libcell} {
       log_puts "size_cell \{$cell_name\} \{$libcell\}"
       ::LIB_ECO::add_size_cell $cell_name $libcell
  }
#
  proc insert_buffer {pin_name libcell {opt1 -new_net_names} {net_name ""} {opt2 -new_cell_names} {newcellname ""}} {
       variable ECO_SERIAL
       variable ECO_PREFIX
       incr ECO_SERIAL
       if {$net_name==""} {
          set net_name  "Net_$ECO_PREFIX\_$ECO_SERIAL"
       }
       if {$newcellname==""} {
          set newcellname "Cell_$ECO_PREFIX\_$ECO_SERIAL"
       }
       log_puts "insert_buffer \[get_pins {$pin_name}\] $libcell $opt1 {$net_name} $opt2 {$newcellname}"
       ::LIB_ECO::add_insert_buffer $pin_name $libcell $net_name $newcellname
  }
  proc read_eco {filename} {
       init
       source $filename
  }
  proc write_eco {filename} {
       set fp [open $filename "w"]
       puts $fp "# write_eco "
       ::LIB_ECO::print_size_cell_list $fp
       puts $fp ""
       ::LIB_ECO::print_insert_buffer_list $fp
       puts $fp "current_instance"
       close $fp
  }
}


 
