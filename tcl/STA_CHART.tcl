#!/usr/bin/tclsh
#
#
# By Albert Li 
# 2021/01/13
#

puts "INFO: Loading 'STA_CHART.tcl'..."
namespace eval LIB_STA {
variable CHART_JS

set CHART_JS(local) "<script src='.javascript/Chart.bundle.js'></script>"

set CHART_JS(http) {
   <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.9.4/Chart.bundle.js" integrity="sha512-zO8oeHCxetPn1Hd9PdDleg5Tw1bAaP0YmNvPY8CwcRyUk7d7/+nyElmFrB6f7vg4f7Fv4sui1mcep8RIEShczg==" crossorigin="anonymous"></script>
   <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.9.4/Chart.css" integrity="sha512-C7hOmCgGzihKXzyPU/z4nv97W0d9bv4ALuuEbSf6hm93myico9qa0hv4dODThvCsqQUmKmLcJmlpRmCaApr83g==" crossorigin="anonymous" />
}

set CHART_JS(color) {
        window.chartColors = {
                red: 'rgb(255, 99, 132)',
                orange: 'rgb(255, 159, 64)',
                yellow: 'rgb(255, 205, 86)',
                green: 'rgb(75, 192, 192)',
                blue: 'rgb(54, 162, 235)',
                purple: 'rgb(153, 102, 255)',
                grey: 'rgb(201, 203, 207)'
        };
}

#
# <Title>
# Create NVP/WNS Plot Chart
#
# <Input>
# $data_path.nvp_wns.dat
#
# <Output>
# $data_path.nvp_wns.htm
# $data_path.nvp_wns.js
#

proc create_nvp_wns_chart {data_path {title_prefix ""}} {
  variable STA_CURR_RUN
  variable CHART_JS

  set data_name [file tail $data_path]
  set data_dir  [file dir $data_path]
  file mkdir $data_dir
  if {![file exists $data_dir/.javascript]} {
    file link $data_dir/.javascript ../../../.javascript
  } 
  set fo [open "$data_path.nvp_wns.htm" w]
  puts $fo "<html>"
  puts $fo $::STA_HTML::TABLE_CSS(sta_tbl)
  puts $fo $CHART_JS(local)
  puts $fo "<script src='$data_name.nvp_wns.js'></script>"
  puts $fo "<head>"
  puts $fo "</head>"
  puts $fo "<body>"
  puts $fo "<div style='width:75%;margin:0 auto'>"
  puts $fo "<canvas id='$data_path' width=800 height=400></canvas>"
  puts $fo "</div>"
  puts $fo "</body>"
  puts $fo "</html>"
  close $fo
  
  set datfile [format "%s.nvp_wns.dat" $data_path]
  set outfile [format "%s.nvp_wns.js" $data_path]
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
  puts $fo "window.chartColors = {"
  puts $fo "        red: 'rgb(255, 99, 132)',"
  puts $fo "        orange: 'rgb(255, 159, 64)',"
  puts $fo "        yellow: 'rgb(255, 205, 86)',"
  puts $fo "        green: 'rgb(75, 192, 192)',"
  puts $fo "        blue: 'rgb(54, 162, 235)',"
  puts $fo "        purple: 'rgb(153, 102, 255)',"
  puts $fo "        grey: 'rgb(201, 203, 207)'"
  puts $fo "};"
  puts $fo "var chartData = {"
  puts $fo "labels: \["
  puts $fo [join $LABEL ","]
  puts $fo "\],"
  puts $fo "datasets: \[{"
  puts $fo "        type: 'line',"
  puts $fo "        lineTension: 0,"
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
  puts $fo "        text: '$title_prefix$data_path'"
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
  puts $fo "	window.onload = function() {"
  puts $fo "                var ctx = document.getElementById('$data_path').getContext('2d');"
  puts $fo "                window.NVPChart = new Chart(ctx, {"
  puts $fo "                        type: 'bar',"
  puts $fo "                        data: chartData,"
  puts $fo "                        options: chartOption"
  puts $fo "                });"
  puts $fo "        };"
  close $fo
}

##########################
}