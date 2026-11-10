#!/bin/bash
# List picochess MAME engines whose software-list ROMs (cartridges, modules,
# opening books) are missing.
# Usage: [ROMPATH=<roms dir>] check_softlist_roms.sh [script_dir] [mame_dir]
#   script_dir  start scripts (default /opt/picochess/engines/<arch>/mame)
#   mame_dir    folder with mess, mame.ini and hash/ (default /opt/picochess/engines/mame_emulation)
#   ROMPATH     check this ROM folder instead of the one in mame.ini
SCRIPTS=${1:-/opt/picochess/engines/$(uname -m)/mame}
MAMEDIR=${2:-/opt/picochess/engines/mame_emulation}
cd "$MAMEDIR" || exit 1
export SDL_VIDEODRIVER=dummy
declare -A good
missing=0
for f in "$SCRIPTS"/*; do
    [ -f "$f" ] || continue
    case "$f" in *.uci|*_art) continue ;; esac
    args=$(sed -n 's/.*-plugin chessengine //p' "$f")
    [ -n "$args" ] || continue
    set -- $args
    sys=$1; shift
    sw=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -cart*|-rom|-card*|-flop*|-cass*|-quik*) sw=$2; shift 2 ;;
            -*) shift 2 ;;
            *) sw=$1; shift ;;
        esac
    done
    [ -n "$sw" ] || continue
    # software list holding $sw: the system's own lists first, else any hash file
    list=$(./mess -listsoftware "$sys" 2>/dev/null | awk -v sw="$sw" '/<softwarelist /{match($0,/name="[^"]*"/);l=substr($0,RSTART+6,RLENGTH-7)} $0 ~ "<software name=\""sw"\""{print l; exit}')
    [ -n "$list" ] || list=$(grep -l "<software name=\"$sw\"" hash/*.xml 2>/dev/null | head -1 | xargs -r basename -s .xml)
    if [ -z "$list" ]; then
        echo "$(basename "$f"): $sw is in no software list in hash/"
        missing=$((missing+1)); continue
    fi
    # MAME lists only the items it finds, so a missing item is simply absent
    [ -n "${good[$list]+x}" ] || good[$list]=$(./mess ${ROMPATH:+-rompath "$ROMPATH"} -verifysoftlist "$list" 2>/dev/null | sed -n 's/^romset \(.*\) is \(good\|best available\)$/\1/p')
    if ! grep -qx "$list:$sw" <<< "${good[$list]}"; then
        echo "$(basename "$f"): needs $list:$sw  (in roms/$list.zip or as roms/$sw.zip)"
        missing=$((missing+1))
    fi
done
echo "$missing engine(s) with missing software-list ROMs"
