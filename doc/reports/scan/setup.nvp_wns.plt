set title "scan/setup"
set term png truecolor size 1000,400 medium
set output "uniq_end/scan/setup.nvp_wns.png"
set style data histogram
set style histogram clustered gap 1
set style fill solid 0.4 border
set grid
set size 1,1
set yrange [0:100]
set ylabel "NVP"
set y2label "WNS (ps)"
set ytics nomirror
set y2tics
plot "uniq_end/scan/setup.nvp_wns.dat" using 2:xticlabels(1) axis x1y1  title "NVP", \
     ""     using 0:2:2 with labels center offset 0,1 notitle, \
     ""     using 3:xticlabels(1) with linespoints lc 3 lw 2 pt 7 ps 1 axis x1y2  title "WNS", \
     ""     using 0:3:(sprintf("(%d)",$3)) with labels center offset -0.5,2 axis x1y2 notitle lc 3
