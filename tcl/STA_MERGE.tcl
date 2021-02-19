#!/usr/bin/tclsh
#
# Uniquify Timing Violation Point
#
# By Albert Li 
# 2020/07/02
#

puts "INFO: Loading 'STA_MERGE.tcl'..."
namespace eval LIB_STA {
variable VIO_FILE  
variable VIO_LIST  ""
variable VIO_WNS       

#
# <Title>
#   Merge Multiple Slack Violation Report 
#
# <Input>
# $sta_group/$sta_mode/$sta_check/*.vio
#
# <Output>
#
# <Return>
# VIO_LIST : {{$egroup,$instpin} $wns $wcorner}
# VIO_WNS($egroup,$instpin,sta_corner) : $wns
#
proc merge_vio_endpoint {sta_group sta_mode sta_check {corner_list ""}} {
  variable STA_CORNER
  variable VIO_WNS
  variable VIO_LIST
  variable VIO_FILE

  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return 
  }
  puts "INFO($sta_mode): Merging slack files of multiple corners ..."
  set WNS 0.0
  set TNS 0.0
  foreach corner_mask $corner_list {
  if ![catch {glob $sta_group/$sta_mode/$sta_check/$corner_mask*.vio} files] {
    foreach fname $files {
      set fin [open $fname r]
      regsub {\.vio$} [file tail $fname] "" sta_corner
      set corner_name [get_corner_name $sta_corner]
      puts "($sta_corner)\t: $fname"
      set VIO_FILE($sta_mode,$sta_check,$sta_corner) $fname
      while {[gets $fin line] >= 0} {
        if {[regexp {^\#} $line]} continue;
        if {[regexp {^\*} $line]} continue;
        set slack   [format "%.2f" [lindex $line 0]]
        set egroup  [lindex $line 1]
        set instpin [lindex $line 2]
        if {$slack<$WNS} { set WNS $slack }
        set TNS [format "%.2f" [expr $TNS+$slack]]
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
  }
  
  set VIO_LIST ""
  foreach key [array name cc] {
      lappend VIO_LIST [list [split $key ","] $VIO_WNS($key,$cc($key)) $cc($key)]
  }
#  set VIO_LIST [lsort -real -increasing -index 1 $VIO_LIST] 
  set VIO_LIST [lsort -unique $VIO_LIST] 
  set VIO_LIST [lsort -index 0 $VIO_LIST] 

  set NVP [llength $VIO_LIST]
  set dqi_path $sta_group/$sta_mode/$sta_check/.dqi/520-STA
  catch { 
    exec mkdir -p $dqi_path; 
    exec echo $NVP > $dqi_path/NVP;
    exec echo $WNS > $dqi_path/WNS;
    exec echo $TNS > $dqi_path/TNS;
  }
  
}


}


