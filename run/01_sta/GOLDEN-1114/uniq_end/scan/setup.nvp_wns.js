var chartData = {
labels: [
'000','157','*258'
],
datasets: [{
        type: 'line',
        label: 'WNS',
        borderColor: window.chartColors.red,
        borderWidth: 2,
        fill: false,
        yAxisID: 'y-axis-2',
        data: [
-0.00,-0.00,0.00
        ]
}, {
        type: 'bar',
        label: 'NVP',
        backgroundColor: window.chartColors.blue,
        borderColor: 'white',
        borderWidth: 2,
        yAxisID: 'y-axis-1',
        data: [
0,0,0
        ]
  }]
};

var chartOption = {
responsive: true,
title: {
        display: true,
        text: 'scan/setup'
},
legend: {
        display: true,
        labels: {
                fontColor: window.chartColors.yellow
        }
},
tooltips: {
        mode: 'index',
        intersect: true
},
scales: {
        yAxes: [{
                type: 'linear',
                display: true,
                position: 'left',
                id: 'y-axis-1',
                ticks: {
                   min: 0,
                   max: 100
                }
        }, {
                type: 'linear',
                display: true,
                position: 'right',
                id: 'y-axis-2',
                gridLines: {
                        drawOnChartArea: false
                }
        }],
}
};
