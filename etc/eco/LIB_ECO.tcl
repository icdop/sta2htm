#!/usr/bin/tclsh
#
# Parse ICC2 ECO output from PTECO
#
# By Albert Li 
# 2016/07/20
# 
puts "INFO: Loading 'LIB_ECO.tcl'..."  
namespace eval LIB_ECO {
  variable ECO_LOG_FILE "lib_eco.log"
  variable ECO_LOG stdout
  variable CURRENT_DESIGN ""
  variable CURRENT_INSTANCE ""
  variable SIZE_CELL_CNT 0
  variable SIZE_CELL_LIST ""
  variable array SIZE_CELL_HASH 
  variable INSERT_BUFFER_CNT 0
  variable INSERT_BUFFER_LIST {}
  variable array INSERT_BUFFER_HASH 

  proc init {{filename ""}} {
     variable ECO_LOG
     variable ECO_LOG_FILE
     if {$filename != ""} { set ECO_LOG_FILE $filename}
     set ECO_LOG [open $ECO_LOG_FILE "w"]
     reset_size_cell_list
     reset_insert_buffer_list
     close $ECO_LOG
  }

  proc log_puts str {
     variable ECO_LOG
     variable ECO_LOG_FILE
     set ECO_LOG [open $ECO_LOG_FILE "a"]
     puts $ECO_LOG [format "%s" $str]
     close $ECO_LOG
  }

  proc get_current_design {} {
       variable CURRENT_DESIGN
       return $CURRENT_DESIGN
  }
  proc set_current_design {{name ""}} {
       variable CURRENT_DESIGN
       set CURRENT_DESIGN $name 
       return $CURRENT_DESIGN
  }
 
  proc get_current_instance {} {
       variable CURRENT_INSTANCE
       return $CURRENT_INSTANCE
  }
  proc set_current_instance {{name ""}} {
       variable CURRENT_INSTANCE
       if {$name == ""} {
          set CURRENT_INSTANCE ""
       } elseif {$CURRENT_INSTANCE == ""} { 
          set CURRENT_INSTANCE $name
       } else {
          set CURRENT_INSTANCE $CURRENT_INSTANCE/$name
       }
       return $CURRENT_INSTANCE
  }
  proc full_hier_name {name} {
       variable CURRENT_INSTANCE
       if {$CURRENT_INSTANCE == ""} {
          return $name
       } else {
          return "$CURRENT_INSTANCE/$name"
       }
  }
 
  proc reset_size_cell_list {} {
       variable SIZE_CELL_CNT 0
       variable SIZE_CELL_LIST "" 
       variable SIZE_CELL_HASH 
       array set SIZE_CELL_HASH {}
  }
  proc add_size_cell {cell_name libcell} {
       variable CURRENT_INSTANCE
       variable SIZE_CELL_CNT
       variable SIZE_CELL_LIST
       variable SIZE_CELL_HASH
       set current_instance $CURRENT_INSTANCE
       set full_cell_name [full_hier_name $cell_name]
       if {[info exists SIZE_CELL_HASH($full_cell_name)]} {
          set cmd_libcell [lindex $SIZE_CELL_HASH($full_cell_name) 3]
          if {$libcell == $cmd_libcell} {
             puts "DUPL: size_cell $full_cell_name $libcell"
          } else {
             puts "CNFT: size_cell $full_cell_name $libcell <= $cmd_libcell"
          }
       } else {
          set SIZE_CELL_HASH($full_cell_name) "$SIZE_CELL_CNT {$current_instance} {$cell_name} {$libcell}"
          lappend SIZE_CELL_LIST $full_cell_name
          incr SIZE_CELL_CNT
          log_puts "size_cell \{$full_cell_name\} \{$libcell\}"
       }
  }
  proc print_size_cell_list {fp} {
       variable CURRENT_INSTANCE
       variable SIZE_CELL_CNT
       variable SIZE_CELL_LIST
       variable SIZE_CELL_HASH
       set cell_cnt 0
       set current_instance ""
       foreach full_cell_name $SIZE_CELL_LIST {
           set size_cell_cmd $SIZE_CELL_HASH($full_cell_name)
           set cmd_cnt [lindex $size_cell_cmd 0]
           set cmd_curr_inst [lindex $size_cell_cmd 1]
           set cmd_cell_name [lindex $size_cell_cmd 2]
           set cmd_libcell [lindex $size_cell_cmd 3]
           set x [split $full_cell_name "/"]
           set cmd_curr_inst [join [lrange $x 0 end-1] "/"]
           set cmd_cell_name [lindex $x end]
           if {$cmd_curr_inst!=$current_instance} {
              puts $fp "current_instance"
              puts $fp "current_instance $cmd_curr_inst"
              set current_instance $cmd_curr_inst
           }
           puts $fp "size_cell $cmd_cell_name $cmd_libcell"
           incr cell_cnt
       } 
       if {$cell_cnt>0} {
          puts $fp "current_instance"
          puts $fp "# total $cell_cnt cells been resized."
       }
  }

  proc reset_insert_buffer_list {} {
       variable INSERT_BUFFER_CNT 0
       variable INSERT_BUFFER_LIST "" 
       variable INSERT_BUFFER_HASH 
       array set INSERT_BUFFER_HASH {}
  }
  proc add_insert_buffer {pin_name libcell net_name newcellname} {
       variable CURRENT_INSTANCE
       variable INSERT_BUFFER_CNT 
       variable INSERT_BUFFER_LIST  
       variable INSERT_BUFFER_HASH
       set curr_instance $CURRENT_INSTANCE
       set full_pin_name [full_hier_name $pin_name]
       set full_net_name [full_hier_name $net_name]
       if {[info exists INSERT_BUFFER_HASH($full_pin_name)]} {
          foreach insert_buffer_cmd $INSERT_BUFFER_HASH($full_pin_name) {
             set cmd_pin_name [lindex $insert_buffer_cmd 0]
             set cmd_libcell [lindex $insert_buffer_cmd 1]
             set cmd_net_name [lindex $insert_buffer_cmd 2]
             set cmd_newcellname [lindex $insert_buffer_cmd 3]
             if {($libcell == $cmd_libcell)&&($newcellname == $cmd_newcellname)} {
                puts "DUPL: insert_buffer $full_pin_name $libcell"
                return
             }
          }
          puts "ABUF: insert_buffer $full_pin_name\n    : $libcell $newcellname"
       } else {
          puts "IBUF: insert_buffer $full_pin_name\n    : $libcell $newcellname"
          lappend INSERT_BUFFER_LIST $full_pin_name
       }
       lappend INSERT_BUFFER_HASH($full_pin_name) "$pin_name $libcell $net_name $newcellname"
       incr INSERT_BUFFER_CNT 
       log_puts "insert_buffer \[get_pins {$full_pin_name}\] $libcell -new_net_names {$full_net_name} -new_cell_names {$newcellname}"
  }
  proc print_insert_buffer_list {fp} {
       variable CURRENT_INSTANCE
       variable INSERT_BUFFER_CNT 
       variable INSERT_BUFFER_LIST  
       variable INSERT_BUFFER_HASH
       set current_instance "" 
       set pin_cnt 0
       set buf_cnt 0
       foreach full_pin_name $INSERT_BUFFER_LIST {
          foreach insert_buffer_cmd $INSERT_BUFFER_HASH($full_pin_name) {
             set cmd_pin_name [lindex $insert_buffer_cmd 0]
             set cmd_libcell [lindex $insert_buffer_cmd 1]
             set cmd_net_name [lindex $insert_buffer_cmd 2]
             set cmd_newcellname [lindex $insert_buffer_cmd 3]
             set x [split $full_pin_name "/"]
             set cmd_curr_inst [join [lrange $x 0 end-2] "/"]
             set cmd_pin_name [join [lrange $x end-1 end] "/"]
             if {$cmd_curr_inst!=$current_instance} {
                puts $fp "current_instance"
                puts $fp "current_instance $cmd_curr_inst"
                set current_instance $cmd_curr_inst
             }
             puts $fp "insert_buffer \[get_pins {$cmd_pin_name}\] $cmd_libcell -new_net_names {$cmd_net_name} -new_cell_names {$cmd_newcellname}"
             incr buf_cnt
          }
          incr pin_cnt
       }
       if {$buf_cnt>0} {
          puts $fp "current_instance"
          puts $fp "# total $buf_cnt buffers been inserted in $pin_cnt pins."
       }
  }
}

LIB_ECO::init

 
