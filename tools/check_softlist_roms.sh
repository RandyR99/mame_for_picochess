#!/bin/bash
# List picochess MAME engines whose software-list ROMs (cartridges, modules,
# opening books) are missing, the ROM files they need, and any zip in the ROM
# folder that holds those files under another name.
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
needed=""
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
        needed+="$(basename "$f") $list $sw"$'\n'
        missing=$((missing+1))
    fi
done

if [ -n "$needed" ]; then
    # ROM folders: ROMPATH, else rompath from mame.ini (relative to mame_dir)
    rp=${ROMPATH:-$(sed -n 's/^rompath[[:space:]]\+//p' mame.ini 2>/dev/null)}
    python3 - "${rp:-roms}" "$needed" <<'EOF'
import os, sys, zipfile
import xml.etree.ElementTree as ET

rompaths = [p.strip().strip('"') for p in sys.argv[1].split(';') if p.strip()]

# CRC of every file in every zip in the ROM folders (from the zip directory)
index = {}
contents = {}
def show(path):
    rel = os.path.relpath(path, rompaths[0])
    return path if rel.startswith('..') else rel
for top in rompaths:
    for root, dirs, files in os.walk(top):
        for name in sorted(files):
            if not name.lower().endswith('.zip'):
                continue
            path = os.path.join(root, name)
            try:
                with zipfile.ZipFile(path) as z:
                    for i in z.infolist():
                        if not i.is_dir():
                            index.setdefault((i.CRC, i.file_size), []).append((path, i.filename))
                            contents.setdefault(path, set()).add((i.CRC, i.file_size))
            except (zipfile.BadZipFile, OSError):
                print(f"  (cannot read {path})")

lists = {}
def roms_of(lst, sw):
    if lst not in lists:
        try:
            lists[lst] = ET.parse(f"hash/{lst}.xml").getroot()
        except (OSError, ET.ParseError):
            lists[lst] = None
    root = lists[lst]
    if root is None:
        return []
    for s in root.iter('software'):
        if s.get('name') == sw:
            return [(r.get('name'), r.get('crc'), int(r.get('size'), 0))
                    for r in s.iter('rom') if r.get('name') and r.get('crc')]
    return []

print(f"ROM folder: {rompaths[0]}")
shown = {}
for line in sys.argv[2].splitlines():
    engine, lst, sw = line.split()
    print(f"{engine}: needs {lst}:{sw}  (in {lst}.zip or as {sw}.zip)")
    if (lst, sw) in shown:
        print(f"    same files as {shown[(lst, sw)]}")
        continue
    shown[(lst, sw)] = engine
    files = roms_of(lst, sw)
    for name, crc, size in files:
        hits = index.get((int(crc, 16), size), [])
        if hits:
            where = ", ".join(show(z) + (f" ({f})" if os.path.basename(f) != name else "") for z, f in hits)
            print(f"    {name}  crc {crc}  found in {where}")
        else:
            print(f"    {name}  crc {crc}  not found")
    # a zip that holds exactly this item's files can be copied under the item's name
    want = {(int(crc, 16), size) for name, crc, size in files}
    for z in sorted(contents):
        if want and contents[z] == want:
            print(f"    -> copy {show(z)} as {sw}.zip")
EOF
fi
echo "$missing engine(s) with missing software-list ROMs"
