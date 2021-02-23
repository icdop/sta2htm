#!/usr/bin/tclsh
#
# GunPlot STA Chart
#
# By Albert Li 
# 2020/07/02
#
#

puts "INFO: Loading 'STA_PLOT.tcl'..."
namespace eval LIB_STA {

#
# <Title>
# Create NVP/WNS Plot PNG
#
# <Input>
# $odir/$sta_path.nvp_wns.dat
#
# <Output>
# $odir/$sta_path.nvp_wns.png
#
proc create_nvp_wns_plot {data_path {title_prefix ""}} {
  file mkdir [file dir $data_path]
  set data_file [format "%s.nvp_wns" $data_path]
  set ymax [get_nvp_ymax $data_file.dat]
  set fout [open "$data_file.plt" w]
    puts $fout "set title \"$title_prefix$data_path\""
    puts $fout "set term png truecolor size 1000,400 medium"
    puts $fout "set output \"$data_file.png\""
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
    puts $fout "plot \"$data_file.dat\" using 2:xticlabels(1) axis x1y1  title \"NVP\", \\"
    puts $fout "     \"\"     using 0:2:2 with labels center offset 0,1 notitle, \\"
    puts $fout "     \"\"     using 3:xticlabels(1) with linespoints lc 3 lw 2 pt 7 ps 1 axis x1y2  title \"WNS\", \\"
    puts $fout "     \"\"     using 0:3:(sprintf(\"(%d)\",\$3)) with labels center offset -0.5,2 axis x1y2 notitle lc 3"
   close $fout
  puts "INFO: Generating Violation Statistics Graph ($data_path)..."
  puts "\t:$data_file.png"
  catch {exec gnuplot $data_file.plt}
}

#
# <Title>
# Create NVP/WNS Comparison Plot PNG
#
# <Input>
# $odir/$sta_path.nvp_wns.dat
# $xdir/$sta_path.nvp_wns.dat
#
# <Output>
# $odir/$sta_path.nvp_wns.comp.png
#


proc create_comp_nvp_wns_plot {sta_path odir xdir {comp "diff"}} {
  set data_file [format "%s/%s.nvp_wns" $odir $sta_path]
  set odir [file normalize $odir]
  set oname [format "%s/%s" [file tail [file dirname $odir]] [file tail $odir]]
  set xfile [format "%s/%s.nvp_wns" $xdir $sta_path]
  set xdir [file normalize $xdir]
  set xname [format "%s/%s" [file tail [file dirname $xdir]] [file tail $xdir]]


  set ymax [get_nvp_ymax $data_file.dat]
  set ymax1 [get_nvp_ymax $xfile.dat]
  if {$ymax1>$ymax} { set ymax $ymax1}
  set fout [open "$data_file.$comp.plt" w]
    puts $fout "set title \"$sta_path\""
    puts $fout "set term png truecolor size 1000,400 medium"
    puts $fout "set output \"$data_file.$comp.png\""
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
    puts $fout "     \"$data_file.dat\" using 2:xticlabels(1) lc 1 axis x1y1  title \"$oname-NVP\", \\"
    puts $fout "     \"$data_file.dat\" using 0:2:2 with labels left offset 0,0 notitle, \\"
    puts $fout "     \"$data_file.dat\" using 3:xticlabels(1) with linespoints lc 3 lw 2 pt 7 ps 1 axis x1y2  title \"$oname-WNS\", \\"
    puts $fout "     \"$data_file.dat\" using 0:3:(sprintf(\"(%d)\",\$3)) with labels center offset -0.5,2 axis x1y2 notitle lc 3"
   close $fout
  puts "INFO: Generating Violation Diff Chart ($sta_path)..."
  puts "\t:$data_file.$comp.png"
  catch {exec gnuplot $data_file.$comp.plt}
  catch {exec diff -W 60 -y $data_file.dat $xfile.dat > $data_file.$comp.rpt}
}

proc get_nvp_ymax {datfile} {
  set ymax 100
  if {[catch {open $datfile r} fin]} {
     return $ymax
  }
  while {[gets $fin line] >= 0} {
        if {[regexp {^\#} $line]} continue;
        set wns  [lindex $line 2]
        set nvp  [lindex $line 1]
        if {$nvp>$ymax} {
           if {$nvp>1000} {
              set ymax $nvp
           } else if {$nvp>100} {
              set ymax 1000
           } else if {$nvp>10} {
              set ymax 100
           }
        }
  }
  close $fin
  return $ymax
}

}