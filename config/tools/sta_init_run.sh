#!/usr/bin/env bash
# sta_init_run.sh — bash 版 sta_init_run（無 csh 環境的替代品；行為對齊 csh/20_sta_init_run.csh）
# 用法：sta_init_run [--STA_DIR <dir>] <run_dir> <report_path> [group...]
# 環境：STA2HTM 必須指向 STA2HTM 安裝根
set -e
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 [--STA_DIR <dir>] <run_dir> <report_path> [group...]" >&2; exit 1
fi
STA_DIR=STA
if [ "$1" = "--STA_DIR" ]; then STA_DIR=$2; shift 2; fi
RUN=$1; RPT=$2; shift 2
: "${STA2HTM:?STA2HTM env not set}"
ETC="$STA2HTM/etc"
echo "# STA_RUN := $RUN"; mkdir -p "$RUN"
cp -f "$ETC/make/sta2htm.make" "$RUN/Makefile"
echo "# STA_RUN := $RUN" > "$RUN/Makefile.group"
mkdir -p "$RUN/.icon" "$RUN/.javascript"
cp -f "$ETC"/icon/* "$RUN/.icon/" 2>/dev/null || true
cp -f "$ETC/html/chartjs/Chart.bundle.min.js" "$RUN/.javascript/" 2>/dev/null || true
RPT_ABS=$(realpath "${RPT:-$RUN}")
echo "# STA_RPT := $RPT_ABS" >> "$RUN/Makefile.group"
mkdir -p "$RUN/.sta"; cp -f "$RPT_ABS"/.sta/sta2htm.* "$RUN/.sta/" 2>/dev/null || true
rm -f "$RUN/$STA_DIR"; ln -s "$RPT_ABS" "$RUN/$STA_DIR"
if [ $# -eq 0 ]; then
  echo "STA_GROUP := uniq_end" >> "$RUN/Makefile.group"
else
  for g in "$@"; do echo "STA_GROUP += $g" >> "$RUN/Makefile.group"; done
fi
echo "sta_init_run(bash): $RUN  <-  $RPT_ABS"
