#!/usr/bin/tclsh
#
# Parse STA2HTM Config File
#
# By Albert Li 
# 2021/02/10
# 
puts "INFO: Loading 'STA_CONFIG.tcl'..."  
namespace eval LIB_STA {
  variable STA_RUN_LIST     
  variable STA_RUN_REPORT
  variable STA_RUN_GROUPS
  variable STA_GROUP_LIST     
  variable STA_GROUP_FILES
  variable STA_BLOCK_LIST   
  variable STA_BLOCK_DEF
  variable STA_CHECK_LIST   
  variable STA_CHECK_DEF
  variable STA_MODE_LIST    
  variable STA_MODE_NAME
  variable STA_MODE_DEF
  variable STA_CORNER_LIST  
  variable STA_CORNER_NAME
  variable STA_CORNER_DEF
  variable STA_CORNER
  variable STA_SCENARIO_LIST 
  variable STA_SCENARIO_DEF
  variable STA_SCENARIO_MAP

#
# <Title>
#   Read Configuration File
#
# <Input>
#
proc reset_sta_config {} {
  variable STA_RUN_LIST
  variable STA_RUN_REPORT
  variable STA_RUN_GROUPS
  variable STA_GROUP_LIST
  variable STA_GROUP_FILES
  variable STA_BLOCK_LIST
  variable STA_BLOCK_DEF
  variable STA_CHECK_LIST
  variable STA_CHECK_DEF
  variable STA_MODE_LIST
  variable STA_MODE_NAME
  variable STA_MODE_DEF
  variable STA_CORNER_LIST
  variable STA_CORNER_NAME
  variable STA_CORNER_DEF
  variable STA_CORNER
  variable STA_SCENARIO_LIST
  variable STA_SCENARIO_DEF
  variable STA_SCENARIO_MAP

  set STA_RUN_LIST ""
  set STA_GROUP_LIST ""
  set STA_BLOCK_LIST ""
  set STA_CHECK_LIST ""
  set STA_MODE_LIST ""
  set STA_CORNER_LIST ""
  set STA_SCENARIO_LIST ""
  
  array set STA_RUN_REPORT   {}
  array set STA_RUN_GROUPS   {}
  array set STA_GROUP_FILES  {}
  array set STA_BLOCK_DEF    {}
  array set STA_CHECK_DEF    {}
  array set STA_MODE_NAME    {}
  array set STA_MODE_DEF     {}
  array set STA_CORNER_NAME  {}
  array set STA_CORNER_DEF   {}
  array set STA_CORNER       {}
  array set STA_SCENARIO_DEF {}
  array set STA_SCENARIO_MAP {}
  
  set STA_CORNER_NAME(-) "-"
}


proc read_sta_config {{filename "sta2htm.cfg"}} {
  variable STA_CFG_PATH
  variable STA_CFG_FILE
  variable STA_RPT_FILE
  
  variable STA_CHECK_LIST
  variable STA_CHECK_DEF
  variable STA_MODE_LIST
  variable STA_MODE_NAME
  variable STA_MODE_DEF
  variable STA_CORNER_LIST
  variable STA_CORNER_NAME
  variable STA_CORNER_DEF
  variable STA_SCENARIO_LIST
  variable STA_SCENARIO_DEF
  variable STA_SCENARIO_MAP
  variable STA_CORNER

  read_sta_corner
  foreach path $STA_CFG_PATH {
    if [file exist $path/$filename] {
       set STA_CFG_FILE $path/$filename
       puts "INFO: Reading tcl variable file '$path/$filename'..."
       source $path/$filename
    }
  }
  sync_sta_config
#  output_sta2htm_runset sta2htm.config
}

proc sync_sta_config {} {
  global env
  variable STA_CURR_RUN
  variable STA_CURR_GROUP
  variable STA_RPT_PATH
  variable STA_RPT_FILE
  variable STA_RUN_LIST
  variable STA_RUN_REPORT
  variable STA_RUN_GROUPS
  variable STA_GROUP_LIST
  variable STA_GROUP_FILES

  variable STA_BLOCK_LIST
  variable STA_BLOCK_DEF
  variable STA_CHECK_LIST
  variable STA_CHECK_DEF
  variable STA_MODE_LIST
  variable STA_MODE_NAME
  variable STA_MODE_DEF
  variable STA_CORNER_LIST
  variable STA_CORNER_NAME
  variable STA_CORNER_DEF
  variable STA_CORNER
  variable STA_SCENARIO_LIST
  variable STA_SCENARIO_DEF
  variable STA_SCENARIO_MAP

  set STA_CURR_RUN [file tail $env(PWD)]
  set STA_RUN_LIST $STA_CURR_RUN
  if {[catch {file readlink $STA_RPT_PATH} sta_run_report]} {
     set STA_RUN_REPORT($STA_CURR_RUN) $STA_RPT_PATH
  } else {
     set STA_RUN_REPORT($STA_CURR_RUN) $sta_run_report
  }
  set STA_RUN_GROUPS($STA_CURR_RUN) $STA_CURR_GROUP
  set STA_GROUP_LIST $STA_CURR_GROUP
  set STA_GROUP_FILES($STA_CURR_GROUP) $STA_RPT_FILE
  
  foreach sta_block $STA_BLOCK_LIST {
    if ![info exist STA_BLOCK_DEF($sta_block)] {
      set STA_BLOCK_DEF($sta_block) $sta_block
    }
  }
  foreach sta_check $STA_CHECK_LIST {
    if ![info exist STA_CHECK_DEF($sta_check)] { 
      set STA_CHECK_DEF($sta_check) $sta_check
    }
  }
  foreach sta_mode $STA_MODE_LIST {
    if ![info exist STA_MODE_NAME($sta_mode)] { 
       set STA_MODE_NAME($sta_mode) $sta_mode
       set STA_MODE_DEF($sta_mode) ""
    }
  }
  foreach sta_corner $STA_CORNER_LIST {
    if ![info exist STA_CORNER_NAME($sta_corner)] { 
       set STA_CORNER_NAME($sta_corner) $sta_corner
       set STA_CORNER_DEF($sta_corner) ""
    }
  }
  set error 0
  set scenario_id 0
  set STA_SCENARIO_LIST ""
  array set STA_SCENARIO_DEF {}
  array set STA_SCENARIO_MAP {}
  foreach sta_check $STA_CHECK_LIST {
    foreach sta_mode $STA_MODE_LIST {
      if [info exist STA_CORNER($sta_mode,$sta_check)] {
         incr scenario_id
         set sta_scenario [format "S%04d" $scenario_id]
         puts "$scenario_id $sta_check $sta_mode $STA_CORNER($sta_mode,$sta_check)"
         lappend STA_SCENARIO_LIST $sta_scenario
         set STA_SCENARIO_DEF($sta_scenario) [format "%-10s %-10s" $sta_check $sta_mode]
         foreach sta_corner $STA_CORNER($sta_mode,$sta_check) {
           if {$sta_corner != "-"} {
               if {![info exist STA_CORNER_NAME($sta_corner)]} {
                  incr error
                  set STA_CORNER_NAME($sta_corner) $sta_corner
                  puts "ERROR: STA_CORNER($sta_mode,$sta_check) has undefined corner ($sta_corner) !"
               }
               set STA_SCENARIO_MAP($sta_check,$sta_mode,$sta_corner) $STA_CORNER_NAME($sta_corner)
           }
         }
      }
    }
  }
  
  if {$error>0} {
     puts "INFO: $error ERRORs found, please check the config file."
     return -1
  }
}
#
# <Title>
#   Read STA2HTM RunSet Config File
#
# <Input>
#
# <Format>
# [VERSION]
# <version>     <sta_run_report>      <sta_run_group>
# GOLDEN-0122   reports/eco1_0121/    uniq_end
#
# [GROUP]
# <group>      <sta_group_report_file>
# uniq_end    "$sta_mode/$corner_name/$sta_check.rpt"
# reg2reg     "$sta_mode/$corner_name/$sta_check\_r2r.rpt"
#
# [BLOCK]
# <sta_block> <block_patten>
# cpu          {^cpu/.*}
#
# [MODE]
# <sta_mode>   <mode_name>       <mode_sdc> ...
# func01       func_init         func01.sdc
# scan01       dc_scan_shift     scan_shift.sdc
#
# [CHECK]
# <sta_check>  <sta_check_dqi>
# setup        WNS TNS
# hold         NVP WNS
#
# [CORNER]
# <sta_corner> <corner_name> <lib_corner>  <rc_corner> <lib_files>
# 000          000_TTT       TT:1.2V:025C    RCtyp     
#
# [SCENARIO]
# <sta_id> <sta_check> <sta_mode>  <corner_list> ...
# S000       setup       func01      000 111 - 153 258
# H001       hold        scan01      000 -   - 153 258
#
proc read_sta_runset {{filename "sta2htm.run"}} {
  variable STA_CFG_FILE
  reset_sta_config
  if [file exist $filename] {
    puts "INFO: Reading configuration file '$filename'..."
    set STA_CFG_FILE $filename
    set fp [open $filename "r"]
    set section ""
    while {[gets $fp line]>=0} {
       regsub {\;.*$} $line {} line
       if [regexp {^\#} $line] continue;
       if [regexp {^\s*$} $line] continue;
       if [regexp {^\s*\[([A-Z]+)\]} $line matched section] {
           puts "CONFIG: "
           puts [format "CONFIG: %-10s -----------------------------------------" \[$section\]]
       } else {
           parse_runset_line $section $line
       }
    }
    close $fp
  }
}

proc parse_runset_line {section line} {
  variable STA_RUN_LIST
  variable STA_RUN_REPORT
  variable STA_RUN_GROUPS
  variable STA_GROUP_LIST
  variable STA_GROUP_FILES
  variable STA_BLOCK_LIST
  variable STA_BLOCK_DEF
  variable STA_CHECK_LIST
  variable STA_CHECK_DEF
  variable STA_MODE_LIST
  variable STA_MODE_NAME
  variable STA_MODE_DEF
  variable STA_CORNER_LIST
  variable STA_CORNER_NAME
  variable STA_CORNER_DEF
  variable STA_CORNER
  variable STA_SCENARIO_LIST
  variable STA_SCENARIO_DEF
  variable STA_SCENARIO_MAP

  set fp stdout
  puts -nonewline $fp "CONFIG: "
  switch -nocase $section {
    VERSION {
      set sta_run [lindex $line 0]
      set STA_RUN_REPORT($sta_run) [lindex $line 1]
      set STA_RUN_GROUPS($sta_run) [lrange $line 2 end]
      lappend STA_RUN_LIST $sta_run
      puts $fp [format "%-12s %-20s %s" $sta_run $STA_RUN_REPORT($sta_run) $STA_RUN_GROUPS($sta_run)]
    }
    GROUP {
      set sta_group   [lindex $line 0]
      set STA_GROUP_FILES($sta_group) [lrange $line 1 end]
      lappend STA_GROUP_LIST $sta_group
      puts $fp [format "%-12s %s" $sta_group $STA_GROUP_FILES($sta_group)]
    }
    BLOCK {
      set sta_block   [lindex $line 0]
      set STA_BLOCK_DEF($sta_block) [lrange $line 1 end]
      lappend STA_BLOCK_LIST $sta_block
      puts $fp [format "%-12s %s" $sta_block $STA_BLOCK_DEF($sta_block)]
    }
    CHECK {
      set sta_check   [lindex $line 0]
      set STA_CHECK_DEF($sta_check) [lrange $line 1 end]
      lappend STA_CHECK_LIST $sta_check
      puts $fp [format "%-12s %s" $sta_check $STA_CHECK_DEF($sta_check)]
    }
    MODE {
      set sta_mode   [lindex $line 0]
      set STA_MODE_NAME($sta_mode) [lindex $line 1]
      set STA_MODE_DEF($sta_mode) [lrange $line 2 end]
      lappend STA_MODE_LIST $sta_mode
      puts $fp [format "%-12s %-16s %s" $sta_mode $STA_MODE_NAME($sta_mode) $STA_MODE_DEF($sta_mode)]
    }
    CORNER {
      set sta_corner   [lindex $line 0]
      set STA_CORNER_NAME($sta_corner) [lindex $line 1]
      set STA_CORNER_DEF($sta_corner) [lrange $line 2 end]
      lappend STA_CORNER_LIST $sta_corner
      puts $fp [format "%-12s %-16s %s" $sta_corner $STA_CORNER_NAME($sta_corner) $STA_CORNER_DEF($sta_corner)]
    }
    SCENARIO {
      set sta_scenario     [lindex $line 0]
      set sta_check        [lindex $line 1]
      set sta_mode         [lindex $line 2]
      set STA_CORNER($sta_mode,$sta_check) [lrange $line 3 end]
      set STA_SCENARIO_DEF($sta_scenario) [format "%-10s %-10s" $sta_check $sta_mode]
      lappend STA_SCENARIO_LIST $sta_scenario

      if {![info exist STA_MODE_DEF($sta_mode)]} {
         puts "WARNING: STA_MODE\[$sta_mode\] is not defined.."
         set STA_MODE_NAME($sta_mode) $sta_mode
         set STA_MODE_DEF($sta_mode)  ""
         lappend STA_MODE_LIST $sta_mode
      }
      if {![info exist STA_CHECK_DEF($sta_check)]} {
         puts "WARNING: STA_CHECK\[$sta_check\] is not defined.."
         set STA_CHECK_DEF($sta_check) $sta_check
         lappend STA_CHECK_LIST $sta_check
      }
      foreach sta_corner $STA_CORNER($sta_mode,$sta_check) {
         if {$sta_corner != "-" } { 
           set STA_SCENARIO_MAP($sta_check,$sta_mode,$sta_corner) $sta_scenario
           if {![info exist STA_CORNER_NAME($sta_corner)]} {
              puts "WARNING: CORNER\[$sta_corner\] is not defined.."
              set STA_CORNER_NAME($sta_corner) $sta_corner
              set STA_CORNER_DEF($sta_corner) ""
              lappend STA_CORNER_LIST $sta_corner
           }
         }
      }
      puts $fp [format "%-12s %-12s %-12s %s" $sta_scenario $sta_check $sta_mode $STA_CORNER($sta_mode,$sta_check)]
    }
    - {
      puts "WARNING: $line"
    }
  }
}

proc output_sta2htm_runset {filename} {
  variable STA_RUN_LIST
  variable STA_RUN_REPORT
  variable STA_RUN_GROUPS
  variable STA_GROUP_LIST
  variable STA_GROUP_FILES
  variable STA_BLOCK_LIST
  variable STA_BLOCK_DEF
  variable STA_CHECK_LIST
  variable STA_CHECK_DEF
  variable STA_MODE_LIST
  variable STA_MODE_NAME
  variable STA_MODE_DEF
  variable STA_CORNER
  variable STA_CORNER_LIST
  variable STA_CORNER_NAME
  variable STA_CORNER_DEF
  variable STA_SCENARIO_LIST
  variable STA_SCENARIO_DEF
  variable STA_SCENARIO_MAP
  
  puts "INFO: Writing configuration file '$filename'..."
  set fp [open $filename "w"]
  puts $fp {[VERSION]}
  puts $fp "#STA_RUN    STA_RUN_REPORT        STA_RUN_GROUPS"
  puts $fp "#---------- --------------------- -------------------------"
  foreach sta_run $STA_RUN_LIST {
    puts $fp [format "%-12s %-20s %s" $sta_run $STA_RUN_REPORT($sta_run) $STA_RUN_GROUPS($sta_run)]
  }
  puts $fp ""
  puts $fp {[GROUP]}
  puts $fp "#STA_GROUP   STA_GROUP_FILES"
  puts $fp "#----------- -----------------------------------------------"

  foreach sta_group $STA_GROUP_LIST {
    puts $fp [format "%-12s %s" $sta_group $STA_GROUP_FILES($sta_group)]
  }
  puts $fp ""
  puts $fp {[BLOCK]}
  puts $fp "#BLOCK       STA_BLOCK_DEF"
  puts $fp "#----------- -------------------"
  foreach sta_block $STA_BLOCK_LIST {
    puts $fp [format "%-12s %s" $sta_block $STA_BLOCK_DEF($sta_block)]
  }
  puts $fp ""
  puts $fp {[CHECK]}
  puts $fp "#<sta_check> STA_CHECK_DEF" 
  puts $fp "#----------- -------------------"
  foreach sta_check $STA_CHECK_LIST {
    puts $fp [format "%-12s %s" $sta_check $STA_CHECK_DEF($sta_check)]
  }
  puts $fp ""
  puts $fp {[MODE]}
  puts $fp "#<sta_mode>  STA_MODE_NAME       STA_MODE_DEF" 
  puts $fp "#----------- ------------------- ---------------------------------------"
  foreach sta_mode $STA_MODE_LIST {
    puts $fp [format "%-12s %-12s %s" $sta_mode $STA_MODE_NAME($sta_mode) $STA_MODE_DEF($sta_mode)]
  }
  puts $fp ""
  puts $fp {[CORNER]}
  puts $fp "#<corner_id> STA_CORNER_NAME     STA_CORNER_DEF" 
  puts $fp "#----------- ------------------- ---------------------------------------"
  foreach sta_corner $STA_CORNER_LIST {
    puts $fp [format "%-12s %-12s %s" $sta_corner $STA_CORNER_NAME($sta_corner) $STA_CORNER_DEF($sta_corner)]
  }
  puts $fp ""
  puts $fp {[SCENARIO]}
  puts $fp "#<sta_id>  <sta_check>  <sta_mode>   <corner_list>" 
  puts $fp "#--------- ------------ ---hjm--------- --------------------------"
  foreach sta_scenario $STA_SCENARIO_LIST {
    set sta_check [lindex $STA_SCENARIO_DEF($sta_scenario) 0]
    set sta_mode  [lindex $STA_SCENARIO_DEF($sta_scenario) 1]
    puts -nonewline $fp [format "%-10s %-12s %-12s" $sta_scenario $sta_check $sta_mode]
    foreach sta_corner $STA_CORNER_LIST {
      if [info exist STA_SCENARIO_MAP($sta_check,$sta_mode,$sta_corner)] {
         puts -nonewline $fp [format " %-3s" $sta_corner]
      } else {
         puts -nonewline $fp [format " %-3s" "-"]
      }
    }
    puts $fp ""
  }
  close $fp
}

}
::LIB_STA::reset_sta_config
