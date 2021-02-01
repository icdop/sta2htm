#!/usr/bin/tclsh
#
# Report Histogram
#
# By Albert Li 
# 2021/01/30
#

puts "INFO: Loading 'STA_HISTOGRAM.tcl'..."
namespace eval LIB_STA {

#
# <Title>
# Report Violation Point Histogram
#
# <Input>
# VIO_LIST : (($egroup,$epoint) $wns $wcorner)
#
# <Output>
# $STA_SUM_DIR/$sta_mode/$fname.wns
# $STA_SUM_DIR/$sta_mode/$fname.nvp
# $STA_SUM_DIR/$sta_mode/$fname.sum
#
#
proc report_violation_histogram {sta_mode {fname "uniq_end"}} {
  variable STA_SUM_DIR
  variable NVP_GP
  variable NVP_WAIVED_GP
  variable NVP_REAL_GP
  variable WNS_GP
  variable WNS_HRANGE
  variable NVP_ACCUM
  variable NVP_WAIVED
  variable NVP_REAL
  variable VIO_LIST

  array unset WNS_GP
  array unset NVP_GP 
  array unset NVP_WAIVED_GP 
  array unset NVP_REAL_GP 

  array unset NVP_ACCUM
  array unset NVP_REAL

  foreach ri $WNS_HRANGE { 
     set NVP_ACCUM($ri) 0 
     set NVP_REAL($ri) 0 
  }
  
  puts "INFO: Generating Slack Summary Report.."
  foreach item $VIO_LIST {
      foreach {key slack wcorner} $item { foreach {egroup epoint} $key {}}
      #foreach {egroup epoint slack wcorner} $item {}
      if ![info exist NVP_GP($egroup)] {
         set NVP_GP($egroup) 0 
         set NVP_WAIVED_GP($egroup) 0
         set NVP_REAL_GP($egroup) 0
      }
      incr NVP_GP($egroup)
      foreach ri $WNS_HRANGE { if (($slack-$ri)<=0.00) { incr NVP_ACCUM($ri) }}
      if {![info exist WNS_GP($egroup)] || ($slack<$WNS_GP($egroup))} {
         set WNS_GP($egroup) $slack
      }
      if {[check_waive_slack $slack $egroup $epoint]==1} {
         incr NVP_WAIVED_GP($egroup)
      } else {
         incr NVP_REAL_GP($egroup)
         foreach ri $WNS_HRANGE { if (($slack-$ri)<=0.00) { incr NVP_REAL($ri) }}
      }
  }
      
  
  set S 0
  set T 0
  set V 0
  set W 0
  set flog [open $STA_SUM_DIR/$sta_mode/$fname.wns w]
  puts $flog [format "# Mode : %s" $sta_mode/$fname]
  puts $flog [format "#%10s %10s %10s %10s %s"  "==========" "==========" "==========" "==========" "=========================="]
  puts $flog [format "#%10s %10s %10s %10s %s" "NVP" "WAIVED" "NVP-W" "WNS" "PathGroup"]
  puts $flog [format "#%10s %10s %10s %10s %s"  "==========" "==========" "==========" "==========" "=========================="]
  puts [format "\t: %10s %10s %10s %10s %s"  "==========" "==========" "==========" "==========" "=========================="]
  puts [format "\t: %10s %10s %10s %10s %s" "NVP" "WAIVED" "NVP-W" "WNS" "PathGroup"]
  puts [format "\t: %10s %10s %10s %10s %s"  "==========" "==========" "==========" "==========" "=========================="]
  set pg_list ""
  foreach key [array name WNS_GP] { 
    lappend pg_list [list $key $WNS_GP($key) ]
  }
  foreach item [lsort -index 0 $pg_list] {
    foreach {p wns} $item {}
    puts [format "\t: %10s %10s %10s %10.2f  %s" $NVP_GP($p)   $NVP_WAIVED_GP($p) $NVP_REAL_GP($p) $wns $p]
    puts $flog [format " %10s %10s %10s %10s  %s" $NVP_GP($p)   $NVP_WAIVED_GP($p) $NVP_REAL_GP($p) $wns $p]
    if {$S>$wns} { set S $wns}
    incr T $NVP_GP($p)
    incr V $NVP_REAL_GP($p)
    incr W $NVP_WAIVED_GP($p)
  }
  puts $flog [format "#%10s %10s %10s %10s %s"  "==========" "==========" "==========" "==========" "=========================="]
  puts $flog [format "#%10s %10s %10s %10s %s" $V $W $T $S [llength $pg_list]]
  puts $flog [format "#%10s %10s %10s %10s %s"  "==========" "==========" "==========" "==========" "=========================="]
  puts $flog ""
  close $flog

  set flog [open $STA_SUM_DIR/$sta_mode/$fname.nvp w]
  puts $flog [format "# $sta_mode/$fname"]
  puts $flog [format "#==================================="]
  puts $flog [format "# %6s | %10s %10s" "Slack" "NVP" "Accum"]
  puts $flog [format "#==================================="]
  set pi 1000
  foreach ri $WNS_HRANGE {
     if {[info exist NVP_ACCUM($pi)]} {
        puts $flog [format "  %6s   %10s %10s" $pi [expr $NVP_ACCUM($pi)-$NVP_ACCUM($ri)] $NVP_ACCUM($pi)] 
     }
     set pi $ri
  }
  puts $flog [format "  %6s   %10s %10s" $pi $NVP_ACCUM($ri) $NVP_ACCUM($ri)]
  close $flog

  set flog [open $STA_SUM_DIR/$sta_mode/$fname.sum w]
  puts $flog [format "# $sta_mode/$fname"]
  puts $flog [format "#======================================================"]
  puts $flog [format "# %6s - %6s | : %10s %10s" "Max" "Min" "NVP" "Accmu"]
  puts $flog [format "#======================================================"]
  set pi 1000
  foreach ri $WNS_HRANGE {
     if {[info exist NVP_ACCUM($pi)]} {
        puts $flog [format "( %6s ~ %6s \] : %10s %10s" $pi $ri [expr $NVP_ACCUM($pi)-$NVP_ACCUM($ri)] $NVP_ACCUM($pi)]
     }
     set pi $ri
  }
  puts $flog [format "( %6s ~ %6s \] : %10s %10s" $pi "" $NVP_ACCUM($ri) $NVP_ACCUM($ri)]
  close $flog
}

}