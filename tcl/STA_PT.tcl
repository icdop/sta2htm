#!/usr/bin/tclsh
#
# Parse PrimeTime Timing Report File
#
# By Albert Li 
# 2020/07/14
#
# package require LIB_WAIVE
# package require LIB_CORNER
# package require LIB_PLOT
# package require LIB_HTML

puts "INFO: Loading 'STA_PT.tcl'..."
namespace eval LIB_STA {

# <Title>
#   Parsing PrimeTime STA Timing Violation Report
#
# <Input>
# $STA_RPT_ROOT/$STA_RPT_PATH/$STA_RPT_FILE
#   Ex: (STA/$sta_mode/$corner_name/rpt/$sta_check/RptTimCnst.rpt)
#
# <Refer>
# report_slack_summary
#
#
# <Output>
# $STA_SUM_DIR/$sta_mode/$sta_check.htm
# $STA_SUM_DIR/$sta_mode/$sta_check.nvp_wns.dat
# $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.vio
#
# VIO_LIST
# GROUP_NVP
# GROUP_GID
#
proc parse_timing_report {sta_mode {sta_check ""} } {
  global   env
  variable STA_SUM_DIR
  variable STA_RPT_ROOT
  variable STA_RPT_PATH
  variable STA_RPT_FILE
  variable STA_CHECK
  variable STA_CORNER
  variable STA_POSTFIX
  variable VIO_LIST
  variable MET_LIST
  variable WAV_LIST
  variable GROUP_NVP
  variable GROUP_GID
  
  if {$sta_check==""} { set sta_check $STA_CHECK}
  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return 
  }
  puts "INFO: Parsing Timing Report Files ($sta_check)..."
  file delete -force $STA_SUM_DIR/$sta_mode/$sta_check
  file mkdir $STA_SUM_DIR/$sta_mode/$sta_check

  set fhtm [open "$STA_SUM_DIR/$sta_mode/$sta_check.htm" w]
  puts $fhtm "<html>"
  puts $fhtm "<head>"
  puts $fhtm $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fhtm "</head>"
  puts $fhtm "<body>"
  puts $fhtm "<table border=\"1\" id=\"sta_tbl\">"
  puts $fhtm "<caption><h3>"
  puts $fhtm "$env(PWD)/$STA_SUM_DIR/$sta_mode/$sta_check"
  puts $fhtm "<a href=../mode.htm>"
  puts $fhtm "<img src=$sta_check.nvp_wns.png>"
  puts $fhtm "</a>"
  puts $fhtm "</h3></caption>"
  puts $fhtm "<tr>"
  puts $fhtm "<th><a href=../mode.htm>Mode</a></th>"
  puts $fhtm "<th><a href=../$sta_mode/>Check</a></th>"
  puts $fhtm "<th><a href=../corner.htm>Corner</a></th>"
  puts $fhtm "<th><a href=$sta_check.blk.htm>Block</a></th>"
  puts $fhtm "<th><a href=$sta_check.clk.htm>Clock</a></th>"
  puts $fhtm "<th><a href=$sta_check.uniq_end.wns>WNS</a></th>"
  puts $fhtm "<th><a href=$sta_check.uniq_end.nvp>NVP</a></th>"
  puts $fhtm "<th><a href=$sta_check.uniq_end.htm>Report</a></th>"
  puts $fhtm "<th><a href=$env(PWD)/$STA_RPT_ROOT/$sta_mode/>Path</a></th>"
  puts $fhtm "</tr>"
  puts $fhtm ""

  set fdat [open "$STA_SUM_DIR/$sta_mode/$sta_check.nvp_wns.dat" w]
  puts $fdat "# [file tail $env(PWD)]/$STA_SUM_DIR"
  puts $fdat [format "#%-4s %10s %10s" ID NVP WNS]
  puts $fdat [format "#%4s %10s %10s" "----" "----------" "----------"]

  if {$STA_POSTFIX==""} { set STA_POSTFIX {""}}
  set FID 0
  set WNS 0
  set GID 0
  set BID 0
  array unset GROUP_GID
  array unset GROUP_NVP

  foreach sta_corner $STA_CORNER($sta_mode,$sta_check) {
  set corner_name [get_corner_name $sta_corner]
  if {[file exist $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.vio]} {
  puts "INFO: $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.vio"
  } else {
  reset_waive_list
  read_waive_list all
  read_waive_list $sta_corner
  set wns 0
  set nvp -

  catch {exec rm -fr $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.*}
  foreach sta_postfix $STA_POSTFIX { 
#  puts "INFO: $STA_RPT_ROOT/$STA_RPT_PATH/$STA_RPT_FILE"
  if [catch {eval glob $STA_RPT_ROOT/$STA_RPT_PATH/$STA_RPT_FILE} files] {
     set files ""
  }
#  puts "INFO: $files"
  foreach fname [lsort -increasing -unique $files] {
    incr FID 
    set bid 0
    set gid 0
    set cid 0
    set wns 0
    set nvp 0
    set nmp 0
    set nwp 0
    foreach path_name [split $fname "/"] {
       set corner_path [split $path_name "_"]
       if {$sta_corner==[lindex $corner_path 0]} {
          set corner_name $path_name
       }
    } 
#    if {[regsub {/rpt/.*$} $fname "" corner_path]} {
#       set corner_name [file  tail $corner_path]
#    }
    puts "($FID) $sta_corner\t$corner_name\t$fname"
    puts $fhtm "<tr>"
    puts $fhtm "<td>$sta_mode</td>"
    puts $fhtm "<td>$sta_check</td>"
    if [regsub {\.gz$} $fname "" n] {
       exec gunzip -c $fname > $STA_SUM_DIR/$sta_mode/$sta_check/.unzip.rpt
       set fin [open $STA_SUM_DIR/$sta_mode/$sta_check/.unzip.rpt r]
    } else {
       set fin [open $fname r]
    }
    set line_cnt   0
    set line_rpt   0
    set line_end   0
    set rpt_type   ""
    set rpt_style  ""
    set rpt_check  ""
    set sclock  "-"
    set eclock  "-" 
    set egroup  "**default**"
    set cnt_group  0
    set VIO_LIST ""
    set slack_offset 0

    set fout [open $STA_SUM_DIR/$sta_mode/$sta_check/$corner_name.vio a]
    puts $fout "# File : [file normalize $fname]"
    set nspt 0
    while {[gets $fin line] >= 0} {
      incr line_cnt
      if {[regexp {Report\s+\:\s+(\S+)} $line whole rpt_type]} {
         set line_rpt $line_cnt
         set line_end $line_cnt
         set rpt_style ""
      } elseif {($rpt_type=="constraint")&&[regexp {\-path slack_only} $line rpt_style]} {
      puts "\t:   Report : $rpt_type $rpt_style (Line# $line_rpt)"
      puts $fout "# Report : $rpt_type $rpt_style (Line# $line_rpt)"
      set egroup "**default**"
      while {[gets $fin line] >= 0} {
        incr line_cnt
        if {[regexp {^\s+(\S+)\s+(\S+)\s+\(VIOLATED\)$} $line whole epoint slack ]} {
          if {$rpt_check==$sta_check} {
             incr nspt
             set slack [format "%.2f" [expr ($slack+$slack_offset)*1000]]
             puts $fout [format "%10.2f %-30s %s" $slack $egroup $epoint]
             if {$slack<$wns} { set wns $slack }

             if {[check_waive_slack "$egroup" $epoint $sta_corner]} {
                incr nwp 
                lappend WAV_LIST [list [list $egroup $epoint] $slack $sta_corner]
             } elseif {$slack>=0.00} {
                incr nmp
                lappend MET_LIST [list [list $egroup $epoint] $slack $sta_corner]
             } else {
                incr nvp 
                lappend VIO_LIST [list [list $egroup $epoint] $slack $sta_corner]
                if {[info exist GROUP_NVP($egroup,$sta_corner)]} {
                   incr GROUP_NVP($egroup,$sta_corner) 
                } else {
                   set GROUP_NVP($egroup,$sta_corner) 1
                }
                sort_slack_by_clock $sta_corner $slack - $egroup
		sort_slack_by_block $sta_corner $slack - $epoint 
             }
          }
        } elseif {[regexp {max_delay/setup\s+\('(\S+)' group\)$} $line whole egroup]} {
          puts "\t:$line"
          if {[regexp {^clock_gating_} $egroup]} { set egroup "**clock_gating_default**" }
          set rpt_check setup
          set slack_offset [get_slack_offset $sta_mode $rpt_check $sta_corner $egroup]
        } elseif {[regexp {min_delay/hold\s+\('(\S+)' group\)$} $line whole  egroup]} {
          puts "\t:$line"
          if {[regexp {^clock_gating_} $egroup]} { set egroup "**clock_gating_default**" }
          set rpt_check hold
          set slack_offset [get_slack_offset $sta_mode $rpt_check $sta_corner $egroup]
        } elseif {[regexp {^\s+clock_gating_(setup|hold)$} $line whole m]} {
          set rpt_check $m
          set egroup "**clock_gating_default**"
          set slack_offset [get_slack_offset $sta_mode $rpt_check $sta_corner $egroup]
        } elseif {[regexp {^\s+recovery$} $line]} {
          set rpt_check "setup"
          set egroup "**async**"
          set slack_offset [get_slack_offset $sta_mode $rpt_check $sta_corner $egroup]
        } elseif {[regexp {^\s+removal$} $line]} {
          set rpt_check "hold"
          set egroup "**async**"
          set slack_offset [get_slack_offset $sta_mode $rpt_check $sta_corner $egroup]
        } elseif {[regexp {^\s+sequential_clock_pulse_width} $line]} {
          set rpt_check "pulse_width"
          set egroup "**clock_pin**"
          break;
        } elseif {[regexp {^\s+clock_tree_pulse_width} $line]} {
          set rpt_check "pulse_width"
          set egroup "**clock_tree**"
          break;
        } elseif {[regexp {^\s+max_capacitance$} $line]} {
          set rpt_check "capacitance"
          set egroup "**drv**"
          break;
        } elseif {[regexp {^\s+min_capacitance$} $line]} {
          set rpt_check "capacitance"
          set egroup "**drv**"
          break;
        } elseif {[regexp {^\s+max_transition$} $line]} {
          set rpt_check "transition"
          set egroup "**drv**"
          break;
        } elseif {[regexp {^\s+min_transition$} $line]} {
          set rpt_check "transition"
          set egroup "**drv**"
          break;
        } elseif {[regexp {^\s+max_fanout$} $line]} {
          set rpt_check "fanout"
          set egroup "**drv**"
          break;
        } elseif {[regexp {^\s+-------} $line]} {
        } elseif {[regexp {Report\s+\:\s+(\S+)} $line whole rpt_type]} {
          set line_rpt $line_cnt
          set line_end $line_cnt
          set rpt_style ""
          break;
        }
      }
      puts "\t:   WNS = $wns"
      puts "\t:   NVP = $nvp"
      puts "\t:   NMP = $nmp"
      puts "\t:   NWP = $nwp"
      #############################################################
      } elseif {($rpt_type=="constraint") && [regexp {\-verbose} $line rpt_style]} {
      puts "\t:   Report : $rpt_type $rpt_style (Line# $line_rpt)"
      puts $fout "# Report : $rpt_type $rpt_style (Line# $line_rpt)"
      set inst_matching 0
      while {[gets $fin line] >= 0} {
        incr line_cnt
        if {[regexp {^\s+slack\s+\(VIOLATED\)\s+(\S+)$} $line whole slack]} {
          if {$rpt_check==$sta_check} {
             incr nspt
             if {[expr $nspt%100]==0} {
                puts -nonewline stderr "\t:   Path# $nspt , Line# $line_cnt\r"
             }
             set slack [format "%.2f" [expr ($slack+$slack_offset)*1000]]
             puts $fout [format "*%03d:%05d %-30s %s" $nspt $line_cnt $sclock $spoint]
             puts $fout [format "%10.2f %-30s %s" $slack $eclock $epoint]
             if {$slack<$wns} { set wns $slack }
             if {[check_waive_slack $eclock $epoint $sta_corner]} {
                incr nwp 
                lappend WAV_LIST [list [list $eclock $epoint] $slack $sta_corner]
             } elseif {[check_waive_slack $sclock:$eclock $spoint:$epoint $sta_corner]} {
                incr nwp 
                lappend WAV_LIST [list [list $eclock $epoint] $slack $sta_corner]
             } elseif {$slack>=0.00} {
                incr nmp
                lappend MET_LIST [list [list $eclock $epoint] $slack $sta_corner]
             } else {
                incr nvp 
                lappend VIO_LIST [list [list $eclock $epoint] $slack $sta_corner]
                if {[info exist GROUP_NVP($egroup,$sta_corner)]} {
                   incr GROUP_NVP($egroup,$sta_corner) 
                } else {
                   set GROUP_NVP($egroup,$sta_corner) 1
                }
                sort_slack_by_clock $sta_corner $slack $sclock $eclock
		sort_slack_by_block $sta_corner $slack $spoint $epoint 
             }
          }
        } elseif {[regexp {^\s+Startpoint\:\s+(\S+)} $line whole spoint]} {
          set sclock "-"
          set eclock "-"
          set egroup "**default**"
          set epoint ""
          set rpt_check ""
          set path_point "s"
          set sclock_delay 0
          set eclock_delay 0
          set clock_recon 0
        } elseif {[regexp {^\s+Endpoint\:\s+(\S+)} $line whole epoint]} {
          set path_point "e"
        } elseif {[regexp {^\s+Path Group\:\s+(\S+)} $line whole egroup]} {
        } elseif {[regexp {^\s+Path Type\:\s+(\S+)} $line whole ptype]} {
          if {$ptype == "max"} {
             set rpt_check "setup"
          } elseif {$ptype == "min"} {
             set rpt_check "hold"
          } else {
             set rpt_check "drv"
          }
          set slack_offset [get_slack_offset $sta_mode $rpt_check $sta_corner $eclock]
        } elseif {[regexp {^\s+Point\s+} $line]} {
          set inst_matching 1
        } elseif {[regexp {^\s+clock network delay\s+(\S+)\s+(\S+)\s+(\S+)} $line whole ctype idelay accu]} {
          if {$path_point =="e"} {
             set eclock_delay $idelay
          } else {
             set sclock_delay $idelay
          }
        } elseif {[regexp {^\s+clock reconvergence pessimism\s+(\S+)\s+(\S+)} $line whole idelay accu]} {
          set clock_recon $idelay 
        } elseif {[regexp {^\s+clock\s+(\S+)} $line clk_name]} {
        } elseif {[regexp {^\s+data arrival time\s+} $line]} {
          set inst_matching 0
        } elseif {$inst_matching} {
          if {[regexp {^\s+(\S+)\s+(\S+)\s+(\S+)} $line whole instpin cell idelay]} {
             set instname [file dirname $instpin]
             if {$instname == $spoint} {
                set spoint $instpin
                #puts "S: $spoint"
             } elseif {$instname == $epoint} {
                set epoint $instpin
             }
          }
        } elseif {[regexp {Report\s+\:\s+(\S+)} $line whole rpt_type]} {
          set line_rpt $line_cnt
          set line_end $line_cnt
          set rpt_style ""
          break;
        } else {
        }
        if {[regexp {clocked by (\S+)} $line whole clkname]} {
          regsub {\)$} $clkname "" clkname
          if {$path_point =="e"} {
             set eclock $clkname
          } else {
             set sclock $clkname
          }
        }
      }
      puts "\t:   Path# $nspt , Line# $line_cnt"
      puts "\t:   WNS = $wns"
      puts "\t:   NVP = $nvp"
      puts "\t:   NMP = $nmp"
      puts "\t:   NWP = $nwp"
      #############################################################
      } elseif {$rpt_type == "timing"} {
      puts "\t:   Report : $rpt_type $rpt_style (Line# $line_rpt)"
      puts $fout "# Report : $rpt_type $rpt_style (Line# $line_rpt)"
      set inst_matching 0
      while {[gets $fin line] >= 0} {
        incr line_cnt
        if {[regexp {^\s+slack\s+\(VIOLATED\)\s+(\S+)$} $line whole slack]} {
          if {$rpt_check==$sta_check} {
             incr nspt
             if {[expr $nspt%100]==0} {
                puts -nonewline stderr "\t:   Path# $nspt , Line# $line_cnt\r"
             }
             set slack [format "%.2f" [expr ($slack+$slack_offset)*1000]]
             set clock_skew [format "%.2f" [expr  ($sclock_delay-$eclock_delay-$clock_recon)*1000]]
             puts $fout [format "*%03d:%05d %-30s %s" $nspt $line_cnt $sclock $spoint]
             puts $fout [format "%10.2f %-30s %s" $slack $eclock $epoint]
             if {$slack<$wns} { set wns $slack }
             if {[check_waive_slack $eclock $epoint $sta_corner]} {
                incr nwp 
                lappend WAV_LIST [list [list $eclock $epoint] $slack $sta_corner]
             } elseif {[check_waive_slack $sclock:$eclock $spoint:$epoint $sta_corner]} {
                incr nwp 
                lappend WAV_LIST [list [list $eclock $epoint] $slack $sta_corner]
             } elseif {$slack>=0.00} {
                incr nmp
                lappend MET_LIST [list [list $eclock $epoint] $slack $sta_corner]
             } else {
                incr nvp 
                lappend VIO_LIST [list [list $eclock $epoint] $slack $sta_corner]
                if {[info exist GROUP_NVP($egroup,$sta_corner)]} {
                   incr GROUP_NVP($egroup,$sta_corner) 
                } else {
                   set GROUP_NVP($egroup,$sta_corner) 1
                }
                sort_slack_by_clock $sta_corner $slack $sclock $eclock
		sort_slack_by_block $sta_corner $slack $spoint $epoint
             }
          }
        } elseif {[regexp {^\s+Startpoint\:\s+(\S+)} $line whole spoint]} {
          set sclock "-"
          set eclock "-"
          set egroup "**default**"
          set rpt_check ""
          set epoint ""
          set path_point "s"
          set sclock_delay 0
          set eclock_delay 0
          set clock_recon 0
          set spoint $spoint
        } elseif {[regexp {^\s+Endpoint\:\s+(\S+)} $line whole epoint]} {
          set path_point "e"
        } elseif {[regexp {^\s+Path Group\:\s+(\S+)} $line whole egroup]} {
        } elseif {[regexp {^\s+Path Type\:\s+(\S+)} $line whole ptype]} {
          if {$ptype == "max"} {
             set rpt_check "setup"
          } elseif {$ptype == "min"} {
             set rpt_check "hold"
          } else {
             set rpt_check "drv"
          }
          set slack_offset [get_slack_offset $sta_mode $rpt_check $sta_corner $eclock]
          set inst_matching 1
        } elseif {[regexp {^\s+clock network delay\s+(\S+)\s+(\S+)\s+(\S+)} $line whole ctype idelay accu]} {
          if {$path_point =="e"} {
             set eclock_delay $idelay
          } else {
             set sclock_delay $idelay
          }
        } elseif {[regexp {^\s+clock reconvergence pessimism\s+(\S+)\s+(\S+)} $line whole idelay accu]} {
          set clock_recon $idelay 
        } elseif {[regexp {^\s+clock\s+(\S+)} $line clk_name]} {
        } elseif {[regexp {^\s+Point\s+} $line]} {
          set inst_matching 1
        } elseif {[regexp {^\s+data arrival time\s+} $line]} {
          set inst_matching 0
        } elseif {$inst_matching} {
          if {[regexp {^\s+(\S+)\s+(\S+)\s+(\S+)} $line whole instpin cell idelay]} {
             set instname [file dirname $instpin]
             if {$instname == $spoint} {
                set spoint $instpin
                #puts "S: $spoint"
             } elseif {$instname == $epoint} {
                set epoint $instpin
             }
          }
        } elseif {[regexp {Report\s+\:\s+(\S+)} $line whole rpt_type]} {
          set line_rpt $line_cnt
          set line_end $line_cnt
          set rpt_style ""
          break;
        } else {
        }
        if {[regexp {clocked by (\S+)} $line whole clkname]} {
          regsub {\)$} $clkname "" clkname
          if {$path_point =="e"} {
             set eclock $clkname
          } else {
             set sclock $clkname
          }
        }
      }
      puts "\t:   Path# $nspt , Line# $line_cnt"
      puts "\t:   WNS = $wns"
      puts "\t:   NVP = $nvp"
      puts "\t:   NMP = $nmp"
      puts "\t:   NWP = $nwp"
      #############################################################
      } else {
      }
    }
    close $fout
    close $fin
    catch {exec rm -f $STA_SUM_DIR/$sta_mode/$sta_check/.unzip.rpt}

    set bid [output_block_table $sta_mode $sta_check $corner_name]
    set cid [output_clock_table $sta_mode $sta_check $corner_name]

    if {$wns<$WNS} { set WNS $wns}
    if {$nvp>0} {
    puts $fhtm "<td align=left><a href=$sta_check/$corner_name.vio>$corner_name</a></td>"
    puts $fhtm "<td align=right><a href=$sta_check/$corner_name.blk.htm> $bid </a></td>"
    puts $fhtm "<td align=right><a href=$sta_check/$corner_name.clk.htm> $cid </a></td>"
    puts $fhtm "<td align=right><a href=$sta_check/$corner_name.wns> $wns </a></td>"
    puts $fhtm "<td align=right><a href=$sta_check/$corner_name.nvp> $nvp </a></td>"
    } else {
    puts $fhtm "<td align=left>$corner_name</td>"
    puts $fhtm "<td align=right> $bid </td>"
    puts $fhtm "<td align=right> $cid </td>"
    puts $fhtm "<td align=right> $wns </td>"
    puts $fhtm "<td align=right> $nvp </td>"
    }
    puts $fhtm "<td><a href=\"$env(PWD)/$fname\">[file tail $fname]</a></td>"
    puts $fhtm "<td><a href=\"[file dirname $env(PWD)/$fname]\">[file dirname $fname]</a></td>"
    puts $fhtm "</tr>"

    report_slack_summary $sta_mode $sta_check/$corner_name
  }
  #foreach fname
  } 
  # foreach sta_postfix
  if {$nvp=="-"} {
    puts $fdat [format "*%-4s %10d %10.2f" $sta_corner 0 0.0]
  } else {
    puts $fdat [format "%-5s %10d %10.2f" $sta_corner $nvp [expr -$wns]]
  }
  }
  }
  # foreach sta_corner
  close $fdat

  set NVP "NVP"
  puts $fhtm "<tr>"
  puts $fhtm "<th><a href=.>$sta_mode</a></th>"
  puts $fhtm "<th><a href=../$sta_check.diff.htm>$sta_check</a></th>"
  puts $fhtm "<th><a href=../corner.htm>Merged $FID files</a></th>"
  puts $fhtm "<th><a href=$sta_check.blk.htm>Block</a></th>"
  puts $fhtm "<th><a href=$sta_check.clk.htm>Clock</a></th>"
#  puts $fhtm "<th><a href=$sta_check.uniq_end.blk.htm>Uniqe</a></th>"
#  puts $fhtm "<th><a href=$sta_check.uniq_end.clk.htm>Uniqe</a></th>"
  puts $fhtm "<th align=right><a href=$sta_check.uniq_end.wns>[format "%.2f" $WNS]</a></th>"
  puts $fhtm "<th align=right><a href=$sta_check.uniq_end.nvp>$NVP</a></th>"
  puts $fhtm "<th>"
  puts $fhtm "<a href=$sta_check.uniq_end.rpt>Unique</a>"
  puts $fhtm "<a href=$sta_check.waive_end.rpt>Waived</a>"
  puts $fhtm "</th>"
  puts $fhtm "<th></th>"
  puts $fhtm "</tr>"
  puts $fhtm "</table>"
  puts $fhtm "</body>"
  puts $fhtm "</html>"
  close $fhtm

}
}


