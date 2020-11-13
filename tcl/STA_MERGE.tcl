# of All Mode and All corners!/usr/bin/tclsh
#
# Parse Timing Report File
#
# By Albert Li 
# 2020/07/02
#
# package require LIB_CORNER
# package require LIB_PLOT
# package require LIB_HTML

puts "INFO: Loading 'LIB_STA.tcl'..."
namespace eval LIB_STA {
variable VIO_FILE  
variable VIO_LIST  ""
variable VIO_WNS       

#
# <Title>
#   Merge Multiple Slack Violation Report 
#
# <Input>
# $STA_SUM_DIR/$sta_mode/$sta_check/*.vio
#
# <Output>
# VIO_LIST : {{$egroup,$instpin} $wns $wcorner}
# VIO_WNS($egroup,$instpin,sta_corner) : $wns
#
proc merge_vio_endpoint {sta_mode {sta_check ""}  } {
  variable STA_SUM_DIR
  variable STA_CHECK
  variable STA_CORNER
  variable VIO_WNS
  variable VIO_LIST
  variable VIO_FILE

  if {$sta_check==""} { set sta_check $STA_CHECK}
  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return 
  }
  puts "INFO($sta_mode): Merging slack files of multiple corners ..."
  array unset SLACK 
  if ![catch {glob $STA_SUM_DIR/$sta_mode/$sta_check/*.vio} files] {
    foreach fname $files {
      set fin [open $fname r]
      regsub {\.vio$} [file tail $fname] "" corner_name
      if {![regexp {^(\d+)\_} $corner_name whole sta_corner]} {
         set sta_corner [get_corner_id $corner_name]
      }
      puts "($sta_corner)\t: $fname"
      set VIO_FILE($sta_mode,$sta_check,$sta_corner) $fname
      while {[gets $fin line] >= 0} {
        if {[regexp {^\#} $line]} continue;
        if {[regexp {^\*} $line]} continue;
        set slack   [format "%.2f" [lindex $line 0]]
        set egroup  [lindex $line 1]
        set instpin [lindex $line 2]
        if [info exist VIO_WNS($egroup,$instpin,$sta_corner)] {
          if {($VIO_WNS($egroup,$instpin,$sta_corner)-$slack)>0.00} {
            set VIO_WNS($egroup,$instpin,$sta_corner) $slack
          }
        } else {
            set VIO_WNS($egroup,$instpin,$sta_corner) $slack
        }
        if [info exist cc($egroup,$instpin)] {
           if {($VIO_WNS($egroup,$instpin,$cc($egroup,$instpin))-$slack)>0.00} {
              set cc($egroup,$instpin) $sta_corner
           }
        } else { 
           set cc($egroup,$instpin) $sta_corner
        }
      }
      close $fin
    }
  }
  set VIO_LIST ""
  foreach key [array name cc] {
      lappend VIO_LIST [list [split $key ","] $VIO_WNS($key,$cc($key)) $cc($key)]
  }
#  set VIO_LIST [lsort -real -increasing -index 1 $VIO_LIST] 
  set VIO_LIST [lsort -unique $VIO_LIST] 
  set VIO_LIST [lsort -index 0 $VIO_LIST] 
}


}


