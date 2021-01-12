set title "func/setup"
set term png truecolor size 1000,400 medium
set output "uniq_end/func/setup.nvp_wns.diff.png"
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
plot "PREV/uniq_end/func/setup.nvp_wns.dat" using 2:xticlabels(1) lc 0 axis x1y1  title "GOLDEN-1114/uniq_end-NVP", \
     "PREV/uniq_end/func/setup.nvp_wns.dat" using 3:xticlabels(1) with linespoints lc 0 lw 1 pt 7 ps 1 axis x1y2  title "GOLDEN-1114/uniq_end-WNS", \
     "uniq_end/func/setup.nvp_wns.dat" using 2:xticlabels(1) lc 1 axis x1y1  title "GOLDEN-1114/uniq_end-NVP", \
     "uniq_end/func/setup.nvp_wns.dat" using 0:2:2 with labels left offset 0,0 notitle, \
     "uniq_end/func/setup.nvp_wns.dat" using 3:xticlabels(1) with linespoints lc 3 lw 2 pt 7 ps 1 axis x1y2  title "GOLDEN-1114/uniq_end-WNS", \
     "uniq_end/func/setup.nvp_wns.dat" using 0:3:(sprintf("(%d)",$3)) with labels center offset -0.5,2 axis x1y2 notitle lc 3
