#!/usr/bin/tclsh
#
# Parse Timing Report File
#
# By Albert Li 
# 2016/07/30
#
# package require LIB_WAIVE
# package require LIB_CORNER

puts "INFO: Loading 'LIB_PLOT.tcl'..."
namespace eval LIB_PLOT {

proc plot_all {} {

  puts "# plot corner min_func"
  plot_corner min_func
  puts "# plot corner max_func"
  plot_corner max_func
  puts "# plot corner min scan"
  plot_corner min_scan
  puts "# plot corner max scan"
  plot_corner max_scan

  puts "# plot trend chart"
  plot_trend_chart
}
proc plot_corner {corner} {
  source db.tcl
  source setting.tcl

## Inner
  gen_nvp_wns ${version}_$corner ${corner}_Inner_nvp_wns
  lappend type TOP
  source ~/type.tcl
  set fout [open .tmp w]
  foreach i $type {
    #puts [format "%-10s %-8d %-8.f" $i $db($i,$corner,inner,nvp) [expr abs($db($i,$corner,inner,wns))]]
    puts $fout [format "%-10s %-8d %-8.f" $i $db($i,$corner,inner,nvp) [expr abs($db($i,$corner,inner,wns))]]
  }
  close $fout
  catch {exec tcsh -fc "gnuplot -c nvp_wns.plt"}

# All
  gen_nvp_wns ${version}_$corner ${corner}_All_nvp_wns
  lappend type IN
  lappend type OUT

  set fout [open .tmp w]
  foreach i $type {
    puts [format "%-10s %-8d %-8.f" $i $db($i,$corner,all,nvp) [expr abs($db($i,$corner,all,wns))]]
    puts $fout [format "%-10s %-8d %-8.f" $i $db($i,$corner,all,nvp) [expr abs($db($i,$corner,all,wns))]]
  }
  close $fout
  catch {exec tcsh -fc "gnuplot -c nvp_wns.plt"}
}

proc hpm_count_nvp_of_each_corner {} {
  source setting.tcl
  gen_nvp_of_each_corner HPM $version
  source ~/icf_lib/hpm_num.tcl

  set fout [open .tmp w]
  foreach i $ilist {
    if [file exist ${i}_waive.ses] {
      source ${i}_waive.ses
      puts $fout "$i [set ${i}_waive(size)]"
    }
  }
  close $fout
  exec tcsh -fc "gnuplot -c nvp_of_each_corner.plt"
}
proc lpm_count_nvp_of_each_corner {} {
  source setting.tcl
  gen_nvp_of_each_corner LPM $version
  source ~/icf_lib/lpm_num.tcl

  set fout [open .tmp w]
  foreach i $ilist {
    if [file exist "../lpm/${i}_waive.ses"] {
      source ../lpm/${i}_waive.ses
      puts $fout "$i [set ${i}_waive(size)]"
    }
  }
  close $fout
  exec tcsh -fc "gnuplot -c nvp_of_each_corner.plt"
}

proc c1 {before after} {
  plt_compare  003 $before $after
  plt_compare  020 $before $after
  plt_compare  053 $before $after
  plt_compare  072 $before $after
  plt_if_inner 003 $after
  plt_if_inner 020 $after
  plt_if_inner 053 $after
  plt_if_inner 072 $after
  plt_nvp_wns  003 $after
  plt_nvp_wns  020 $after
  plt_nvp_wns  053 $after
  plt_nvp_wns  072 $after
}
proc plt_compare {corner before after} {
  if [catch {glob $before/hpm/$corner*/rpts/NVP_WNS.dat}] {
    puts "No $corner in $before"
    return;
  } else {
    set bfile [glob $before/hpm/$corner*/rpts/NVP_WNS.dat]
  }
  if [catch {glob $after/hpm/$corner*/rpts/NVP_WNS.dat}] {
    puts "No $corner in $after"
    return;
  } else {
    set afile [glob $after/hpm/$corner*/rpts/NVP_WNS.dat]
  }
  puts $bfile
  puts $afile
  exec tcsh -fc "grep -v # $bfile > .tmp1"
  exec tcsh -fc "grep -v # $afile > .tmp2"
  exec tcsh -fc "join -o 1.1 1.4 2.4 .tmp1 .tmp2 > .tmp_join"
  gen_compare $corner 1000 400 $before $after "$corner NVP comparison $before vs. $after"
  #exec tcsh -fc "gnuplot -c compare.plt;eog ${corner}_compare.png "
  exec tcsh -fc "gnuplot -c compare.plt"
}
# plt_wns_compare
# {{{
proc plt_wns_compare {corner before after} {
  if [catch {glob $before/hpm/$corner*/rpts/NVP_WNS.dat}] {
    puts "No $corner in $before"
    return;
  } else {
    set bfile [glob $before/hpm/$corner*/rpts/NVP_WNS.dat]
  }
  if [catch {glob $after/hpm/$corner*/rpts/NVP_WNS.dat}] {
    puts "No $corner in $after"
    return;
  } else {
    set afile [glob $after/hpm/$corner*/rpts/NVP_WNS.dat]
  }
  puts $bfile
  puts $afile
  exec tcsh -fc "grep -v # $bfile > .tmp1"
  exec tcsh -fc "grep -v # $afile > .tmp2"
  exec tcsh -fc "join -o 1.1 1.5 2.5 .tmp1 .tmp2 > .tmp_join"
  gen_wns_compare $corner 1000 400 $before $after "$corner WNS comparison $before vs. $after"
  #exec tcsh -fc "gnuplot -c compare.plt;eog ${corner}_compare.png "
  exec tcsh -fc "gnuplot -c wns_compare.plt"
}
# }}}
proc plt_if_inner {corner run} {
  if [catch {glob $run/hpm/$corner*/rpts/NVP_WNS.dat}] {
    puts "No $corner in $run"
    return;
  } else {
    set bfile [glob $run/hpm/$corner*/rpts/NVP_WNS.dat]
  }

  gen_if_inner $corner $run
  exec tcsh -fc "awk '{print \$1 \"\\t\" \$2 \"\\t\" \$3}' $bfile > .tmp"
  #exec tcsh -fc "gnuplot -c if_inner.plt;eog ${corner}_if_inner.png "
  exec tcsh -fc "gnuplot -c if_inner.plt"

}
proc plt_nvp_wns {corner run} {
  if [catch {glob $run/hpm/$corner*/rpts/NVP_WNS.dat}] {
    puts "No $corner in $run"
    return;
  } else {
    set bfile [glob $run/hpm/$corner*/rpts/NVP_WNS.dat]
  }

  set bfile [glob $run/hpm/$corner*/rpts/NVP_WNS.dat]
  gen_nvp_wns $corner $run
  exec tcsh -fc "awk '{print \$1 \"\\t\" \$4 \"\\t\" \$5}' $bfile > .tmp"
  #exec tcsh -fc "gnuplot -c nvp_wns.plt;eog ${corner}_nvp_wns.png "
  exec tcsh -fc "gnuplot -c nvp_wns.plt"

}
proc gen_nvp_of_each_corner {title date} {
  set fout [open "nvp_of_each_corner.plt" w]
    puts $fout "set title \"$date NVP of each $title corners\""
    puts $fout "set term png truecolor size 1600,600 medium"
    puts $fout "set output \"$title.png\""
    puts $fout "set style data histogram"
    puts $fout "set style histogram clustered gap 1"
    puts $fout "set style fill solid 0.4 border"
    puts $fout "set grid"
    puts $fout "set ylabel \"NVP\""
    puts $fout "set xlabel \"Corners\""
    puts $fout "plot \".tmp\" using 2:xticlabels(1) notitle, \\"
    puts $fout "     \"\"        using 0:2:2 with labels center offset -1,1 notitle"
   close $fout

}

proc gen_nvp_wns {title ofile} {
  set fout [open "nvp_wns.plt" w]
    puts $fout "set title \"$title\""
    puts $fout "set term png truecolor size 1000,400 medium"
    puts $fout "set output \"$ofile.png\""
    puts $fout "set style data histogram"
    puts $fout "set style histogram clustered gap 1"
    puts $fout "set style fill transparent solid 0.4 border"
    puts $fout "set grid"
    puts $fout "set size 1,1"
    puts $fout "set ylabel \"NVP\""
    puts $fout "set y2label \"WNS\""
    puts $fout "set ytics nomirror"
    puts $fout "set y2tics"
    puts $fout "plot \".tmp\" using 2:xticlabels(1) axis x1y1  title \"NVP\", \\"
    puts $fout "     \"\"     using 0:2:2 with labels center offset 0,1 notitle, \\"
    puts $fout "     \"\"     using 3:xticlabels(1) with linespoints lc 3 lw 2 pt 7 ps 1 axis x1y2  title \"WNS\", \\"
    puts $fout "     \"\"     using 0:3:(sprintf(\"-%d\",\$3)) with labels center offset -0.5,2 axis x1y2 notitle lc 3"
   close $fout
}
proc gen_inner {corner date} {
  set fout [open "if_inner.plt" w]
    puts $fout "set term png truecolor size 1000,400 medium"
    puts $fout "set output \"${corner}_if_inner.png\""
    puts $fout "set style data histogram"
    puts $fout "set style histogram clustered gap 1"
    puts $fout "set style fill transparent solid 0.4 border"
    puts $fout "set grid"
    puts $fout "set size 1,1"
    puts $fout "set title \"$date Corner $corner IF/Inner\""


    puts $fout "plot \".tmp\" using 2:xticlabels(1) title \"InneInnerr\", \\"
    puts $fout "     \"\"     using 0:2:2 with labels center offset -1.5,1 notitle"
   close $fout

}
proc gen_if_inner {corner date} {
  set fout [open "if_inner.plt" w]
    puts $fout "set term png truecolor size 1000,400 medium"
    puts $fout "set output \"${corner}_if_inner.png\""
    puts $fout "set style data histogram"
    puts $fout "set style histogram clustered gap 1"
    puts $fout "set style fill transparent solid 0.4 border"
    puts $fout "set grid"
    puts $fout "set size 1,1"
    puts $fout "set title \"$date Corner $corner IF/Inner\""


    puts $fout "plot \".tmp\" using 2:xticlabels(1) title \"I/F\", \\"
    puts $fout "     \"\"     using 3:xticlabels(1) title \"Inner\", \\"
    puts $fout "     \"\"     using 0:3:3 with labels center offset 1.5,1 notitle, \\"
    puts $fout "     \"\"     using 0:2:2 with labels center offset -1.5,1 notitle"
   close $fout

}
proc gen_compare {corner width height before after title} {
  set fout [open "compare.plt" w]
    puts $fout "set term png truecolor size $width,$height medium"
    puts $fout "set output \"${corner}_compare.png\""
    puts $fout {set style data histogram}
    puts $fout {set style histogram clustered gap 1}
    puts $fout {set style fill transparent solid 0.4 border}
    puts $fout {set grid}
    puts $fout {set ylabel "NVP"}
    puts $fout "set title \"$title\""
    puts $fout {}
    puts $fout "plot \".tmp_join\" using 2:xticlabels(1) title \"$before\", \\"
    puts $fout "     \"\"            using 0:2:2 with labels center offset -3,1 notitle, \\"
    puts $fout "     \"\"            using 3:xticlabels(1) title \"$after\", \\"
    puts $fout "     \"\"            using 0:3:3 with labels center offset 3,1 notitle"
  close $fout
}
proc gen_wns_compare {corner width height before after title} {
  set fout [open "wns_compare.plt" w]
    puts $fout "set term png truecolor size $width,$height medium"
    puts $fout "set output \"${corner}_WNS_compare.png\""
    #puts $fout {set style data histogram}
    #puts $fout {set style histogram clustered gap 1}
    #puts $fout {set style fill transparent solid 0.4 border}
    puts $fout {set grid}
    puts $fout {set ylabel "WNS"}
    puts $fout "set title \"$title\""
    puts $fout {}
    puts $fout "plot \".tmp_join\" using 2:xticlabels(1) with linespoints lc 2 lw 2 pt 7 ps 1 axis x1y2  title \"$before\", \\"
    puts $fout "     \"\"     using 0:2:(sprintf(\"-%d\",\$2)) with labels center offset -0.5,2 notitle lc 3, \\"
    puts $fout "     \"\"     using 3:xticlabels(1) with linespoints lc 3 lw 2 pt 7 ps 1 axis x1y2  title \"$after\", \\"
    puts $fout "     \"\"     using 0:3:(sprintf(\"-%d\",\$3)) with labels center offset -0.5,2 notitle lc 3"
  close $fout
}
### PLOT TREND CHART
proc update_trend_db {} {
  source /home/plot_db/trend.tcl
  if [file exist "setting.tcl"] {
    source setting.tcl
  } else {
    puts "Error: No setting.tcl"
    exit
  }
  lappend ilist max_func_waive
  lappend ilist min_func_waive
  lappend ilist max_scan_waive
  lappend ilist min_scan_waive
  lappend ilist 003_waive
  lappend ilist 020_waive
  lappend ilist 053_waive
  lappend ilist 072_waive

  foreach i $ilist {
    set fname ${i}.ses
    if [file exist $fname] {
      source $fname
      regsub "_waive" $i "" j
      puts $j
      set trend($j,$version) [set ${i}(size)]
      #puts [set ${i}(size)]
    }
  }

  #parray trend
  exec tcsh -fc "cp /home/plot_db/trend.tcl /home/plot_db/bak.trend.tcl"
  save_ses trend /home/plot_db/trend.tcl
}
proc plot_trend_chart {} {
  source /home/plot_db/trend.tcl
  source /home/plot_db/to_plot.tcl
  lappend ilist max_func
  lappend ilist min_func
  lappend ilist max_scan
  lappend ilist min_scan

  lappend jlist 003
  lappend jlist 020
  lappend jlist 053
  lappend jlist 072

  foreach i $ilist j $jlist {
    gen_trend_plt ${i}_trend "${i} Trend Chart" "${i}"
    set fout [open .tmp w]
    foreach d $dates {
# both exist
      if {[info exist trend($i,$d)] && [info exist trend($j,$d)]} {
         puts "$d $trend($j,$d) $trend($i,$d)"
         puts $fout "$d $trend($j,$d) $trend($i,$d)"
# only major corner exist
      } elseif {![info exist trend($i,$d)] && [info exist trend($j,$d)]} {
         puts "$d $trend($j,$d)"
         puts $fout "$d $trend($j,$d)"
      }
    }
    close $fout
    exec tcsh -fc "gnuplot -c trend.plt"
  }
}
proc gen_trend_plt {ofile title corner} {
  set fout [open "trend.plt" w]
    puts $fout "set term png truecolor medium size 1000,500"
    puts $fout "set output \"$ofile.png\""
    puts $fout "set xlabel \"WW\""
    puts $fout "set ylabel \"NVP\""
    puts $fout "set title \"$title\""
    puts $fout "set grid"
    #puts $fout "set yrange \[0:3600\]"
    puts $fout "plot \".tmp\" using 0:2:xticlabels(1) with linespoints lc 3 lw 2 pt 7 ps 1 title \"$corner\", \\"
    puts $fout "     \"\"                     using 0:2:2 with labels center offset 0,1 notitle, \\"
    puts $fout "     \"\"                     using 0:3:xticlabels(1) with linespoints lc 4 lw 2 pt 7 ps 1 title \"Unique endpoints from all FUNC MAX corners\", \\"
    puts $fout "     \"\"                     using 0:3:3 with labels center offset 0,1 notitle"
  close $fout

}
proc gen_plot_db {} {
  lappend ilist min_func
  lappend ilist max_func
  lappend ilist min_scan
  lappend ilist max_scan
  foreach i $ilist {
    source ${i}_waive.ses
    count_All   ${i}_waive ${i}
    count_Inner ${i}_waive ${i}
  }

}
}
