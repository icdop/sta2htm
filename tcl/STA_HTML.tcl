#!/usr/bin/tclsh
#
# HTML Related Variable 
#
# By Albert Li 
# 2021/01/13
#

puts "INFO: Loading 'STA_HTML.tcl'..."  
namespace eval STA_HTML {
global STA2HTM

variable TABLE_CSS
variable CHART_JS

set TABLE_CSS(sta_tbl) {
    <style>
    #sta_tbl {
      font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
      border-collapse: collapse;
    }

    #sta_tbl td, #sta_tbl th {
      border: 1px solid #ddd;
      padding: 8px;
    }

    #sta_tbl tr:nth-child(even){background-color: #f2f2f2;}

    #sta_tbl tr:hover {background-color: #ddd;}

    #sta_tbl th {
      padding-top: 12px;
      padding-bottom: 12px;
      text-align: left;
      background-color: #4CAF50;
      color: white;
    }
    </style>
}

set CHART_JS(sta2htm) "<script src='$STA2HTM/etc/html/chartjs/Chart.bundle.js'></script>"

set CHART_JS(cndjs) {
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

set CHART_JS(onload) {
	window.onload = function() {
                var ctx = document.getElementById('sta_chart').getContext('2d');
                window.NVPChart = new Chart(ctx, {
                        type: 'bar',
                        data: chartData,
                        options: chartOption
                });
        };
}


}
