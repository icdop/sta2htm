var chartData = {
labels: [
'000','151','157','258'
],
datasets: [{
        type: 'line',
        label: 'WNS',
        borderColor: window.chartColors.red,
        borderWidth: 2,
        fill: false,
        yAxisID: 'y-axis-2',
        data: [
5.26,1.77,1.48,50.81
        ]
}, {
        type: 'bar',
        label: 'NVP',
        backgroundColor: window.chartColors.blue,
        borderColor: 'white',
        borderWidth: 2,
        yAxisID: 'y-axis-1',
        data: [
4,20,33,3
        ]
  }]
};

var chartOption = {
responsive: true,
title: {
        display: true,
        text: 'func/hold'
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
