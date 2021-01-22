#!/usr/bin/tclsh
#
#
# By Albert Li 
# 2021/01/122
#

puts "INFO: Loading 'STA_COMP.tcl'..."
namespace eval LIB_STA {
#
# <Title>
# Report STA Summary Page of STA_CHECK with diff
#
# <Input>
#
# <Output>
# $STA_SUM_DIR/$sta_check.$comp.htm
#
proc report_comp_sta_html {{sta_check ""} {comp "diff"} } {
  variable STA_CURR_RUN
  variable STA_SUM_DIR
  variable STA_MODE_LIST
  variable STA_CHECK
  variable STA_CORNER
  
  if {$sta_check==""} { set sta_check $STA_CHECK}

 
  set fo [open "$STA_SUM_DIR/$sta_check.$comp.htm" "w"]
  puts $fo "<html>"
  puts $fo $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fo "<head>"
  puts $fo "\[<a href=index.htm>\@Index</a>\]"
  puts $fo "\[<a href=mode.htm>\@Mode</a>\]"
  puts $fo "\[<a href=check.htm>\@Check</a>\]"
  puts $fo "\[<a href=corner.htm>\@Corner</a>\]"
  puts $fo "\[<a href=$sta_check.htm>\@Prev</a>\]"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<table border=\"1\" id=\"sta_tbl\">"
  puts $fo "<caption><h3 align=\"left\">"
  puts $fo "<a href=..>$STA_CURR_RUN</a>"
  puts $fo "/"
  puts $fo "<a href=.>$STA_SUM_DIR</a>"
  puts $fo "</a>"
  puts $fo "(<a href=$sta_check.htm>$sta_check</a>)"
  puts $fo "<h3></caption>"
  foreach sta_mode $STA_MODE_LIST {
    if {[info exist STA_CORNER($sta_mode,$sta_check)]} {
    puts $fo "<tr>"
    puts $fo "<th colspan=2><h3><a href=$sta_mode/$sta_check.htm>$sta_mode/$sta_check</a></h3></th>"
    puts $fo "</tr>"
    puts $fo "<tr>"
    puts $fo "<td>"
    puts $fo "<a href=\"$sta_check.htm\">"
    puts $fo "<img src=$sta_mode/$sta_check.nvp_wns.$comp.png>"
    puts $fo "</a>"
    puts $fo "</td>"
    puts $fo "<td>"
    puts $fo "<iframe src=\"$sta_mode/$sta_check.nvp_wns.$comp.rpt\" height=\"400\" width=\"500\"></iframe>"
    puts $fo "</td>"
    puts $fo "</tr>"
    }
  }
  puts $fo "</table>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
}

proc create_comp_nvp_plot {path odir xdir {comp "diff"}} {
  set ofile [format "%s/%s.nvp_wns" $odir $path]
  set odir [file normalize $odir]
  set oname [format "%s/%s" [file tail [file dirname $odir]] [file tail $odir]]
  set xfile [format "%s/%s.nvp_wns" $xdir $path]
  set xdir [file normalize $xdir]
  set xname [format "%s/%s" [file tail [file dirname $xdir]] [file tail $xdir]]


  set ymax [get_nvp_ymax $ofile.dat]
  set ymax1 [get_nvp_ymax $xfile.dat]
  if {$ymax1>$ymax} { set ymax $ymax1}
  set fout [open "$ofile.$comp.plt" w]
    puts $fout "set title \"$path\""
    puts $fout "set term png truecolor size 1000,400 medium"
    puts $fout "set output \"$ofile.$comp.png\""
    puts $fout "set style data histogram"
    puts $fout "set style histogram clustered gap 1"
    puts $fout "set style fill solid 0.4 border"
    puts $fout "set grid"
    puts $fout "set size 1,1"
    puts $fout "set yrange \[0:$ymax\]"
    puts $fout "set ylabel \"NVP\""
    puts $fout "set y2label \"WNS (ps)\""
    puts $fout "set ytics nomirror"
    puts $fout "set y2tics"
    puts $fout "plot \"$xfile.dat\" using 2:xticlabels(1) lc 0 axis x1y1  title \"$xname-NVP\", \\"
#    puts $fout "     \"$xfile.dat\" using 0:2:2 with labels right offset 0,1 notitle, \\"
    puts $fout "     \"$xfile.dat\" using 3:xticlabels(1) with linespoints lc 0 lw 1 pt 7 ps 1 axis x1y2  title \"$xname-WNS\", \\"
#    puts $fout "     \"$xfile.dat\" using 0:3:(sprintf(\"(%di)\",\$3)) with labels center offset -0.5,2 axis x1y2 notitle lc 0, \\"
    puts $fout "     \"$ofile.dat\" using 2:xticlabels(1) lc 1 axis x1y1  title \"$oname-NVP\", \\"
    puts $fout "     \"$ofile.dat\" using 0:2:2 with labels left offset 0,0 notitle, \\"
    puts $fout "     \"$ofile.dat\" using 3:xticlabels(1) with linespoints lc 3 lw 2 pt 7 ps 1 axis x1y2  title \"$oname-WNS\", \\"
    puts $fout "     \"$ofile.dat\" using 0:3:(sprintf(\"(%d)\",\$3)) with labels center offset -0.5,2 axis x1y2 notitle lc 3"
   close $fout
  puts "INFO: Generating Violation Diff Chart ($path)..."
  puts "\t:$ofile.$comp.png"
  catch {exec gnuplot $ofile.$comp.plt}
  catch {exec diff -W 60 -y $ofile.dat $xfile.dat > $ofile.$comp.rpt}
}

}

