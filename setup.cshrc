#!/bin/csh -f
set prog=$0:t
if ("$prog" == "setup.cshrc") then
   setenv STA2HTM `realpath $0:h`
else 
   setenv STA2HTM `pwd`
endif

set path = ($STA2HTM/bin $path)
setenv STA_PLUGIN $STA2HTM/plugin

if ($?DOP_HOME == 0) then
   setenv DOP_HOME $STA2HTM:h
endif

echo "DOP_HOME = $DOP_HOME"
echo "STA2HTM  = $STA2HTM"
