#!/usr/bin/tclsh
#
# DEBUG Infortaion
#
# By Albert Li 
# 2016/07/30
# 
namespace eval LIB_DEBUG {
variable DEBUG_MODE 0

proc debug_puts s {
  variable DEBUG_MODE
  if $DEBUG_MODE {puts "<DEBUG> $s"}
}

}
LIB_DEBUG::init
proc debug_puts str {
  ::LIB_DEBUG::debug_puts $str
}