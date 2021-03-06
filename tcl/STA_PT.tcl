#!/usr/bin/tclsh
#
# Parse PrimeTime Timing Report File
#
# By Albert Li 
# 2020/07/14
#

puts "INFO: Loading 'STA_PT.tcl'..."
namespace eval LIB_STA {

# <Title>
#   Parsing PrimeTime STA Timing Violation Report
#
# <Input>
# $sta_group,$sta_mode,$sta_check
# $sta_report_path/$sta_report_file
#   Ex: ($sta_report_path/$sta_mode/$corner_name/rpt/$sta_check/RptTimCnst.rpt)
#
# <Refer>
# report_vio_histogram
# output_block_table
# output_clock_table
#
# <Output>
# $sta_group/$sta_mode/$sta_check.htm
# $sta_group/$sta_mode/$sta_check.nvp_wns.dat
# $sta_group/$sta_mode/$sta_corner/$sta_check.vio
#
# VIO_LIST
# MET_LIST
# WAV_LIST
#
# GROUP_NVP
# GROUP_GID
#
proc parse_primetime_report {sta_group sta_mode sta_check sta_report_path sta_report_filter} {
  variable STA_CURR_RUN
  variable STA_MODE_NAME
  variable STA_CORNER_NAME
  variable STA_CORNER
  
  variable STA_DATA
  variable VIO_LIST
  variable MET_LIST
  variable WAV_LIST
  
  if {[info exist STA_MODE_NAME($sta_mode)]} { 
     set mode_name $STA_MODE_NAME($sta_mode)
  } else {
     set mode_name $sta_mnode
  }
  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return 
  }
  puts "INFO: Parsing Timing Report Files ($sta_check)..."
  file delete -force $sta_group/$sta_mode/$sta_check
  file mkdir $sta_group/$sta_mode
  puts "INFO: $sta_group/$sta_mode/$sta_check"

  set fdat [open "$sta_group/$sta_mode/$sta_check.nvp_wns.dat" w]
  puts $fdat "# $STA_CURR_RUN/$sta_group"
  puts $fdat [format "#%4s %10s %10s" "----" "----------" "----------"]
  puts $fdat [format "#%-4s %10s %10s" ID NVP WNS]
  puts $fdat [format "#%4s %10s %10s" "----" "----------" "----------"]

  set FID 0
  set NVP 0
  set WNS 0.0
  set TNS 0.0

  reset_block_data
  reset_clock_data
  
  foreach sta_corner $STA_CORNER($sta_mode,$sta_check) {
    file mkdir $sta_group/$sta_mode/$sta_corner
    set corner_name [get_corner_name $sta_corner]
    if {[file exist $sta_group/$sta_mode/$sta_corner/$sta_check.vio]} {
      puts "INFO: $sta_group/$sta_mode/$sta_corner/$sta_check.vio"
      continue
    }
    reset_waive_list
    read_waive_list all
    read_waive_list $sta_corner
    set nvp -
    set wns 0.0
    set tns 0.0

    catch {exec rm -fr $sta_group/$sta_mode/$sta_corner/$sta_check.*}
    set files ""
    foreach filter $sta_report_filter {
      puts "FILTER: $sta_report_path/$filter"
    
      if [catch {eval glob $sta_report_path/$filter} files] continue;
      foreach fname [lsort -increasing -unique $files] {
        incr FID 
        set wns 0.0
        set tns 0.0
        set nvp 0
        set nmp 0
        set nwp 0
        foreach path_name [split $fname "/"] {
           set corner_path [split $path_name "_"]
           if {$sta_corner==[lindex $corner_path 0]} {
              set corner_name $path_name
           }
        } 
        puts "($FID) $sta_corner\t$corner_name\t$fname"
        if [regsub {\.gz$} $fname "" n] {
           exec gunzip -c $fname > $sta_group/$sta_mode/$sta_corner/.unzip.rpt
           set fin [open $sta_group/$sta_mode/$sta_corner/.unzip.rpt r]
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
        set WAV_LIST ""
        set MET_LIST ""
        set VIO_LIST ""
        set slack_offset 0

        set fout [open $sta_group/$sta_mode/$sta_corner/$sta_check.vio a]
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
                   set tns   [format "%.2f" [expr ($tns+$slack)]]
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
                   set tns   [format "%.2f" [expr ($tns+$slack)]]
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
              } elseif {[regexp {^\s+Startpoint\:\s+(\S+)} $line whole sinst]} {
                set sclock "-"
                set eclock "-"
                set egroup "**default**"
                set epoint ""
                set rpt_check ""
                set path_point "s"
                set sclock_delay 0
                set eclock_delay 0
                set clock_recon 0
              } elseif {[regexp {^\s+Endpoint\:\s+(\S+)} $line whole einst]} {
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
                set epoint $instpin
                set inst_matching 0
              } elseif {$inst_matching} {
                if {[regexp {^\s+(\S+)\s+(\S+)\s+(\S+)} $line whole instpin cell idelay]} {
                   set instname [file dirname $instpin]
                   if {$instname == $sinst} {
                      set spoint $instpin
                   } elseif {$instname == $einst} {
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
                   set tns   [format "%.2f" [expr ($tns+$slack)]]
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
          #############################################################
          } else {
            continue
          }
        }
        # end while
        puts "\t:   Path# $nspt , Line# $line_cnt"
        puts "\t:   WNS = $wns"
        puts "\t:   TNS = $tns"
        puts "\t:   NVP = $nvp"
        puts "\t:   NMP = $nmp"
        puts "\t:   NWP = $nwp"
        set dqi_path $sta_group/$sta_mode/$sta_corner/.dqi/520-STA/$sta_check
        catch { exec mkdir -p $dqi_path; 
                exec echo $nvp > $dqi_path/NVP;
                exec echo $nwp > $dqi_path/NWP;
                exec echo $wns > $dqi_path/WNS;
                exec echo $tns > $dqi_path/TNS;
                } msg
        puts $msg
        close $fout
        close $fin
        catch {exec rm -f $sta_group/$sta_mode/$sta_check/.unzip.rpt}

        report_vio_histogram $sta_group $sta_mode $sta_corner/$sta_check

        set bid [output_block_table $sta_group $sta_mode $sta_check $sta_corner]
        set cid [output_clock_table $sta_group $sta_mode $sta_check $sta_corner]

        lappend STA_DATA($sta_mode,$sta_check,$sta_corner) [list $corner_name $fname $nwp $nvp $wns $tns $cid $bid]

      }
      # foreach fname
    }  
    if {$nvp=="-"} {
      puts $fdat [format "*%-4s %10d %10.2f" $sta_corner 0 0.0]
    } else {
      puts $fdat [format "%-5s %10d %10.2f" $sta_corner $nvp [expr -$wns]]
    }
  }
  # foreach sta_corner
  close $fdat
}

}