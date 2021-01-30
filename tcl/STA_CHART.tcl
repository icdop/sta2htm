#!/usr/bin/tclsh
#
#
# By Albert Li 
# 2021/01/13
#

puts "INFO: Loading 'STA_CHART.tcl'..."
namespace eval LIB_STA {

proc create_check_chart {sta_mode {sta_check ""} } {
  variable STA_SUM_DIR
  variable STA_CHECK
  variable STA_CORNER

  if {$sta_check==""} { set sta_check $STA_CHECK}
  if {![info exist STA_CORNER($sta_mode,$sta_check)]} {
     puts "INFO: STA_CORNER($sta_mode,$sta_check) is not defined..."
     return 
  }
  create_curr_nvp_chart "$sta_mode/$sta_check" $STA_SUM_DIR
  set fo [open "$STA_SUM_DIR/$sta_mode/$sta_check.chart.htm" w]
  puts $fo "<html>"
  puts $fo $::LIB_HTML::TABLE_CSS(sta_tbl)
  puts $fo $::LIB_HTML::CHART_JS(sta2htm)
  puts $fo "<script>"
  puts $fo $::LIB_HTML::CHART_JS(color)
  puts $fo $::LIB_HTML::CHART_JS(onload)
  puts $fo "</script>"
  puts $fo "<script src='$sta_check.nvp_wns.js'></script>"
  puts $fo "<head>"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<div style=\"width:75%;margin:0 auto\">"
  puts $fo "<canvas id=sta_chart width=800 height=400></canvas>"
  puts $fo "</div>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
}

proc create_nvp_wns_chart {path odir} {
  
  set datfile [format "%s/%s.nvp_wns.dat" $odir $path]
  set outfile [format "%s/%s.nvp_wns.js" $odir $path]
  set ymax 100
  if {![catch {open $datfile r} fin]} {
    while {[gets $fin line] >= 0} { 
        if {[regexp {^\#} $line]} continue;
        set label [lindex $line 0]
        set nvp  [lindex $line 1]
        set wns  [lindex $line 2]
        lappend LABEL '$label'
        lappend NVP $nvp
        lappend WNS $wns
        if {$nvp>$ymax} {
           if {$nvp>1000} {
              set ymax $nvp
           } elseif {$nvp>100} {
              set ymax 1000
           } elseif {$nvp>10} {
              set ymax 100
           }
        }
    }
  }
  close $fin
  set fo [open $outfile w]
  puts $fo "var chartData = {"
  puts $fo "labels: \["
  puts $fo [join $LABEL ","]
  puts $fo "\],"
  puts $fo "datasets: \[{"
  puts $fo "        type: 'line',"
  puts $fo "        label: 'WNS',"
  puts $fo "        borderColor: window.chartColors.red,"
  puts $fo "        borderWidth: 2,"
  puts $fo "        fill: false,"
  puts $fo "        yAxisID: 'y-axis-2',"
  puts $fo "        data: \["
  puts $fo [join $WNS ","]
  puts $fo "        \]"
  puts $fo "}, {"
  puts $fo "        type: 'bar',"
  puts $fo "        label: 'NVP',"
  puts $fo "        backgroundColor: window.chartColors.blue,"
  puts $fo "        borderColor: 'white',"
  puts $fo "        borderWidth: 2,"
  puts $fo "        yAxisID: 'y-axis-1',"
  puts $fo "        data: \["
  puts $fo [join $NVP ","]
  puts $fo "        \]"
  puts $fo "  }\]"
  puts $fo "};"
  puts $fo ""
  puts $fo "var chartOption = {"
  puts $fo "responsive: true,"
  puts $fo "title: {"
  puts $fo "        display: true,"
  puts $fo "        text: '$path'"
  puts $fo "},"
  puts $fo "legend: {"
  puts $fo "        display: true,"
  puts $fo "        labels: {"
  puts $fo "                fontColor: window.chartColors.yellow"
  puts $fo "        }"
  puts $fo "},"
  puts $fo "tooltips: {"
  puts $fo "        mode: 'index',"
  puts $fo "        intersect: true"
  puts $fo "},"
  puts $fo "scales: {"
  puts $fo "        yAxes: \[{"
  puts $fo "                type: 'linear',"
  puts $fo "                display: true,"
  puts $fo "                position: 'left',"
  puts $fo "                id: 'y-axis-1',"
  puts $fo "                ticks: {"
  puts $fo "                   min: 0,"
  puts $fo "                   max: $ymax"
  puts $fo "                }"
  puts $fo "        }, {"
  puts $fo "                type: 'linear',"
  puts $fo "                display: true,"
  puts $fo "                position: 'right',"
  puts $fo "                id: 'y-axis-2',"
  puts $fo "                gridLines: {"
  puts $fo "                        drawOnChartArea: false"
  puts $fo "                }"
  puts $fo "        }\],"
  puts $fo "}"
  puts $fo "};"
  close $fo
}

##########################
}