#!/bin/csh -f
set prog=$0:t
if ("$prog" == "setup.cshrc") then
   setenv STA_HOME `realpath $0:h`
else 
   setenv STA_HOME `pwd`
endif

set path = ($STA_HOME/bin $path)
setenv STA_PLUGIN $STA_HOME/plugin

if ($?DOP_HOME == 0) then
   setenv DOP_HOME $STA_HOME:h
endif

echo "DOP_HOME = $DOP_HOME"
echo "STA_HOME = $STA_HOME"
