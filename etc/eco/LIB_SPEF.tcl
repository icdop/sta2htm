#!/usr/bin/tclsh
#
# SPEF Libary Header
#
# By Albert Li 
# 2016/08/15
# 
#*T_UNIT 1.00000 NS
#*C_UNIT 1.00000 FF
#*R_UNIT 1.00000 OHM
#*L_UNIT 1.00000 HENRY

#*CONN
#*I *17737823:a I *C 203.280 765.450 *D d04bfn00wnud5
#*I *17724582:o O *C 203.140 765.576 *D d04bfn00wn0a5
#*N *2320723:468390 *C 203.280 765.405
#*N *2320723:627134 *C 203.208 765.450
#*END

namespace eval LIB_SPEF {
    variable SPEF_LIST
    variable MAX_RATIO 0.2
    variable MAX_DIFF  0.5
    
    proc init {} {
      puts "###########################################################"
      puts "# SPEF LIBRARY                                            #"
      puts "###########################################################"
    }


    proc create_cap_file {name {outdir .}} {
      if {[file isdirectory $name]} {
         catch {glob $name/*\.spef*} files
      } elseif [file isfile $name] {
         set files $name
      }
      file mkdir $outdir
      foreach fname $files {
        regsub {.gz$} $fname ""  capfile
#        regsub {\/} $capfile "_" capfile
        set capfile [file tail $capfile]
        parse_spef_cap $fname $outdir/$capfile.cap
      }
    }
    
    proc parse_spef_cap {fname capfile} {
      variable SPEF_LIST
      puts "*LIB_SPEF: Reading SPEF file '$fname'..."
      if {[regexp {.gz$} $fname]} {
         set fin [open "|gunzip -c $fname" r]
      } else {
         set fin [open $fname r]
      }
      puts "*LIB_SPEF: Writing CAP file '$capfile'..."
      set fo [open "$capfile" w]

      set ln 0
      set n 0
      array set UNIT { T {1 NS} C {1 FF} R {1 OHM} L {1 HENRY}}
      while {[gets $fin line] >= 0} {
        incr ln
#        if {[expr $ln % 100000]==0} { puts "LINE #$ln" }
        if {[regexp {^\s*$} $line]} {
        } elseif {[regexp {^\*D_NET\s+\*(\S+)\s+(\S+)} $line whole net_id cap]} {
          incr n
          if {[expr $n % 100000]==0} { puts "D_NET: #$n" }
          if {![info exist NET($net_id)]} {\
             puts "ERROR: Can not find net ($net_id)."
          } else {
#             puts $fo [format "%10d %10.2f %s" $net_id $cap $NET($net_id) ]
#             puts $fo [format "%s %10.4f" $NET($net_id) $cap ]
             puts $fo [format "%10.4f %s" $cap $NET($net_id)]
          }
          while {[gets $fin line] >= 0} {
            incr ln
            if {[regexp {^\*END} $line]} {
              break;
            }
          }
        } elseif {[regexp {^\*NAME_MAP} $line]} {
          puts "NAME_MAP: BEGIN"
          set m 0
          while {[gets $fin line] >= 0} {
            incr ln
            if {[regexp {^\*(\d+)\s+(\S+)} $line whole net_id net]} {
                incr m
                if {[expr $m % 100000]==0} { puts "NAME_MAP: #$m" }
                set NET($net_id) $net
            } elseif {[regexp {^\s*$} $line] && ($m>0)} {
                break;
            }
          }
          puts "NAME_MAP: Total $m netname"
        } elseif {[regexp {^\*PORTS\s*} $line]} {
          puts "PORTS: BEGIN"
          set p 0
          while {[gets $fin line] >= 0} {
            incr ln
            if {[regexp {^\*(\d+)\s+(\S+)} $line whole port_id dir]} {
                incr p
                set PORT($net_id) $dir
            } elseif {[regexp {^\s*$} $line] && ($p>0)} {
                break;
            }
          }
          puts "PORTS: Total $p ports"
        
        } elseif {[regexp {^\s*\/\/} $line whole matched]} {
        } elseif {[regexp {^\*T_UNIT\s+(\S+)\s+(\S+)} $line whole unit_t_x unit_t]} {
        } elseif {[regexp {^\*C_UNIT\s+(\S+)\s+(\S+)} $line whole unit_c_x unit_c]} {
        } elseif {[regexp {^\*R_UNIT\s+(\S+)\s+(\S+)} $line whole unit_r_x unit_r]} {
        } elseif {[regexp {^\*L_UNIT\s+(\S+)\s+(\S+)} $line whole unit_l_x unit_l]} {
        } else {
        }
      }
      puts "D_NET: Total $n nets"
      close $fin
      close $fo
    }

    proc cmp_cap {net cap1 cap2 max_ratio max_diff} {
      set mismatch ""
      set cap0 [expr ($cap1-$cap2)]
      if {($cap1==0)||($cap2==0)} {
        if ($cap1>0) {
            set ratio "*"
            puts [format "MISSING NET2: (cap1=%.4f) %s" $cap1 $net]
        } elseif ($cap2>0) {
            set ratio "*"
            puts [format "MISSING NET1: (cap2=%.4f) %s" $cap2 $net]
        } else {
            set ratio "#"
#            puts [format "UNEXTRACTED:: %s" $net] 
        }
        set mismatch [format "%-4s %10.4f %10.4f %10.4f %s" $ratio $cap0 $cap1 $cap2 $net]
      } else {
         set ratio [expr $cap0/$cap2]
         if {($cap0>$max_diff)||($ratio>$max_ratio)} {
            set mismatch [format "%-4.2f %10.4f %10.4f %10.4f %s" $ratio $cap0 $cap1 $cap2 $net]
#            puts [format "MISMATCH: %s" $mismatch]
         } else {
            set mismatch ""
         } 
         
      }
      return $mismatch
    }
    
    proc compare_cap_file {new_cap ref_cap {rptdir "."}} {
      variable MAX_RATIO
      variable MAX_DIFF
      
      array unset CAP1
      array unset CAP2
      
      set max_diff $MAX_DIFF
      set max_ratio MAX_RATIO
      file mkdir $rptdir
      
      puts "Compare $new_cap  with $ref_cap... "
      if {[regexp {.gz$} $new_cap]} { set new_cap "|gunzip -c $new_cap" }
      if {[regexp {.gz$} $ref_cap]} { set ref_cap "|gunzip -c $ref_cap" }
      set f1 [open $new_cap r]
      set f2 [open $ref_cap r]
      set fo [open "$rptdir/compare_cap.rpt" w]
      set fx [open "$rptdir/missing_cap.rpt" w]
      puts $fo [format "# Cmp Cap : %s" $new_cap]
      puts $fo [format "# Ref Cap : %s" $ref_cap]
      puts $fo [format "# Criteria: c/r > %s , diff > %s" $max_ratio $max_diff]
      puts $fo [format "#c/r %10s %10s %10s %s" diff cmp ref  net_name]

      puts $fx [format "# Cmp Cap: %s" $new_cap]
      puts $fx [format "# Ref Cap: %s" $ref_cap]
      puts $fx [format "#    %10s %10s %10s %s" diff cmp ref  net_name]
      set ln 0
      set cap1cnt 0
      set cap2cnt 0
      set compare 0
      set matched 0
      set changed 0
      set missing 0
      set zerocap 0
      while {1} {
            set line1 ""
            set line2 ""
            set d1 [gets $f1 line1]
            set d2 [gets $f2 line2]
            if {($d1 <= 0) && ( $d2 <= 0)} { break; }
            incr ln
            if {[expr $ln % 10000]==0} { puts "LINE #$ln" }
            if {[regexp {^\s*(\S+)\s+(\S+)} $line1 whole cap1 net1]} {
              incr cap1cnt
#              puts "CAP1: $cap1 $net1"
              if {[info exist CAP2($net1)]} {
                 incr compare
                 set cap2 $CAP2($net1)
                 set result [cmp_cap $net1 $cap1 $cap2 $max_ratio $max_diff]
                 if {[regexp {^\#} $result]} {
                    incr zerocap
                    puts $fx $result
                 } elseif {[regexp {^\*} $result]} {
                    incr missing
                    puts $fx $result
                 } elseif {[regexp {^\s*(\S+)\s+(\S+)} $result ratio cap0]} {
                    incr changed
                    puts $fo $result
                 } else {
                    incr matched
                 }
                 array unset CAP2 $net1
              } else {
                 set CAP1($net1) $cap1
              }
            }
            if {[regexp {^\s*(\S+)\s+(\S+)} $line2 whole cap2 net2]} {
              incr cap2cnt
#              puts "CAP2: $cap2 $net2"
              if {[info exist CAP1($net2)]} {
                 incr compare
                 set cap1 $CAP1($net2)
                 set result [cmp_cap $net2 $cap1 $cap2 $max_ratio $max_diff]
                 if {[regexp {^\#} $result]} {
                    incr zerocap
                    puts $fx $result
                 } elseif {[regexp {^\*} $result]} {
                    incr missing
                    puts $fx $result
                 } elseif {[regexp {^\s*(\S+)\s+(\S+)} $result ratio cap0]} {
                    incr changed
                    puts $fo $result
                 } else {
                    incr matched
                 }
                 array unset CAP1 $net2
              } else {
                 set CAP2($net2) $cap2
              }
            }
      }
      close $f1
      close $f2
      close $fo
      close $fx
      puts "CmpFile Net: $cap1cnt"      
      puts "RefFile Net: $cap2cnt"      
      puts "Compare Net: $compare"      
      puts "Matched Net: $matched"      
      puts "Changed Net: $changed"      
      puts "Missing Net: $missing"      
      puts "ZeroCap Net: $zerocap"      
    }
}
LIB_SPEF::init
