#!/usr/bin/tclsh
#
# Timing Waiver List
#
# By Albert Li 
# 2020/07/04
# 
# ::LIB_STA::reset_waive_list
# ::LIB_STA::read_waive_list  all_mode.waive
# ::LIB_STA::read_waive_list  max_func.waive
#
# set waive_slack [::LIB_STA::get_waive_slack $path_group $inst_pin]
#
# if ($slack>$waive_slack) {
#    WAIVED VIOLATION
# } else {
#    REAL VIOLATION
# }
#
namespace eval LIB_STA {

variable STA_CFG_DIR
variable WAIVE_MASK 
variable SLACK_OFFSET


proc reset_waive_list {} {
  variable WAIVE_MASK
  array unset WAIVE_MASK 
}


proc print_waive_list {} {
  variable WAIVE_MASK
  foreach i [lsort [array names WAIVE_MASK]] {
     puts "DEBUG: $WAIVE_MASK($i) [split $i ","]"
  }
}

proc read_waive_list {{sta_mode "all"}} {
  variable STA_CFG_DIR
  variable WAIVE_MASK

  if [file exist "$sta_mode.waive"] {
     set filename $sta_mode.waive
  } elseif [file exist "$STA_CFG_DIR/$sta_mode.waive"] {
     set filename "$STA_CFG_DIR/$sta_mode.waive"
  } elseif [file exist "$STA_CFG_DIR/$sta_mode.waive"] {
     set filename "$STA_CFG_DIR/$sta_mode.waive"
  } elseif [file exist "$::LIB_STA::STA_HOME/etc/$sta_mode.waive"] {
     set filename "$::LIB_STA::STA_HOME/etc/$sta_mode.waive"
  } elseif [file exist $sta_mode] {
     if {[file type $sta_mode]=="file"} {
        set filename $sta_mode
     } else {
        return
     }
  } else {
     return
  }
  puts "INFO: Reading waive filter file '$filename'..."
  set fp [open $filename "r"]

  set sgroup "-"
  set spoint "-"
  while {[gets $fp line]>=0} {
     set egroup "-"
     set epoint "-"
     set corner "-"
     regsub {^\s+} $line "" line
     if {[regexp {^\#} $line matched]} {
        continue
     } elseif {[regexp {^\*(\S+)\s+(\S+)\s+(\S+)} $line matched lineid sgroup spoint]} {
        continue
     } elseif {[regexp {^\*(\S+)\s+(\S+)\s} $line matched lineid sgroup]} {
        continue
     } elseif {[regexp {^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)} $line matched slack egroup epoint corner]} {
     } elseif {[regexp {^(\S+)\s+(\S+)\s+(\S+)} $line matched slack egroup epoint]} {
     } elseif {[regexp {^(\S+)\s+(\S+)} $line matched slack egroup]} {
     } elseif {[regexp {^(\S+)} $line matched slack]} {
     } else {
        continue
     }
     set WAIVE_MASK($sgroup:$egroup,$spoint:$epoint,$corner) $slack
     puts "WAIVE($sta_mode): $slack $sgroup:$egroup $spoint:$epoint $corner"
     set sgroup "-"
     set spoint "-"
  }
  close $fp
}

proc set_waive_slack {slack {egroup -} {epoint -} {corner -}} {
     variable WAIVE_MASK
     set WAIVE_MASK($egroup,$epoint,$corner) $slack
}

proc check_waive_slack {slack {egroup "-:-"} {epoint "-:-"} {corner "-"}} {
    variable WAIVE_MASK
      set waive_slack 0

      if {0} {
      } elseif [info exist WAIVE_MASK($egroup,$epoint,$corner)] {
         set waive_slack $WAIVE_MASK($egroup,$epoint,$corner)
      } elseif [info exist WAIVE_MASK(-:$egroup,-:$epoint,$corner)] {
         set waive_slack $WAIVE_MASK(-:$egroup,-:$epoint,$corner)
      } elseif [info exist WAIVE_MASK($egroup,$epoint,-)] {
         set waive_slack $WAIVE_MASK($egroup,$epoint,-)
      } elseif [info exist WAIVE_MASK(-:$egroup,-:$epoint,-)] {
         set waive_slack $WAIVE_MASK(-:$egroup,-:$epoint,-)
      } elseif [info exist WAIVE_MASK($egroup,-:-,-)] {
         set waive_slack $WAIVE_MASK($egroup,-:-,-) 
      } elseif [info exist WAIVE_MASK(-:$egroup,-:-,-)] {
         set waive_slack $WAIVE_MASK(-:$egroup,-:-,-) 
      } elseif [info exist WAIVE_MASK(-:-,$epoint,-)] {
         set waive_slack $WAIVE_MASK(-:-,$epoint,-) 
      } elseif [info exist WAIVE_MASK(-:-,-:$epoint,-)] {
         set waive_slack $WAIVE_MASK(-:-,-:$epoint,-) 
      } elseif [info exist WAIVE_MASK(-:-,-:-,-)] {
         set waive_slack $WAIVE_MASK(-:-,-:-,-) 
      } else {
         return 0
      } 
      if {$waive_slack == "-"} {
         return 1
      } elseif {$slack >= $waive_slack} {
         return 1
      }
      return 0
}
 
proc get_slack_offset {{sta_mode ""} {sta_check ""} {sta_corner ""} {egroup ""}} {
  variable SLACK_OFFSET
     if {[info exist SLACK_OFFSET($sta_mode,$sta_check,$sta_corner,$egroup)]} {
        set slack_offset $SLACK_OFFSET($sta_mode,$sta_check,$sta_corner,$egroup)
     } elseif {[info exist SLACK_OFFSET($sta_mode,$sta_check,$sta_corner)]} {
        set slack_offset $SLACK_OFFSET($sta_mode,$sta_check,$sta_corner)
     } elseif {[info exist SLACK_OFFSET($sta_mode,$sta_check)]} {
        set slack_offset $SLACK_OFFSET($sta_mode,$sta_check)
     } else {
        set slack_offset 0
     }
     if {$slack_offset>0} {
        puts "INFO: SLACK_OFFSET = $slack_offset"
     }
     return $slack_offset
}


}

puts "INFO: Loading 'LIB_WAIVE.tcl'..."  
LIB_STA::reset_waive_list
