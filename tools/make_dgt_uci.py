#!/usr/bin/env python3
"""Generate the DGT .uci set and the two .uci zips from mame/*.uci.

The DGT3000 and DGTPi clocks show 11 characters, so a level name must fit in
that: '[Level 06 - 40 moves/2h]' becomes '[06-40/2h]'. Only the section headers
change; every other line is copied as it is. mame/*.uci stays the master, never
edit dgt/ by hand.

  tools/make_dgt_uci.py          write dgt/*.uci, stop on a header over the limit
  tools/make_dgt_uci.py --check  only report whether dgt/ is up to date
  tools/make_dgt_uci.py --zip D  also write mame_uci_web_en.zip and
                                 mame_uci_dgtpi_en.zip into directory D
"""
import argparse
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "mame"
TARGET = ROOT / "dgt"

LIMIT = 11
ROOM = LIMIT - len("00-")  # characters left for the description

HEADER = re.compile(r"^(;?\[)Level (\d+) - (.*?)(\].*)$")

# Texts the general rules below would make unreadable.
SPECIAL = {
    "40 moves/2h + 20 moves/1h": "40/2h+20",
    "120m game": "2h game",
}


def shorten(desc):
    """Fit a level description in ROOM characters, losing as little as possible."""
    if desc in SPECIAL:
        return SPECIAL[desc]
    desc = re.sub(r"^(\d+) moves/", r"\1/", desc)
    desc = desc.replace(" to ", "-")
    for full, *shorter in ((" move", " mov", " mv", ""), (" game", " gam", " gm", "")):
        if desc.endswith(full):
            for tail in shorter:
                if len(desc) <= ROOM:
                    break
                desc = desc[: -len(full)] + tail if tail else desc[: -len(full)]
                full = tail
    return desc


def convert(text):
    """Return the DGT text of a .uci file and the headers over the limit."""
    lines, too_long = [], []
    for line in text.split("\n"):
        match = HEADER.match(line)
        if match:
            name = f"{int(match[2]):02d}-{shorten(match[3])}"
            if len(name) > LIMIT:
                too_long.append(name)
            line = match[1] + name + match[4]
        lines.append(line)
    return "\n".join(lines), too_long


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true", help="only verify dgt/")
    parser.add_argument("--zip", type=Path, metavar="DIR", help="write the zips here")
    args = parser.parse_args()

    converted, problems = {}, []
    for path in sorted(SOURCE.glob("*.uci")):
        converted[path.name], too_long = convert(path.read_text(encoding="utf-8"))
        problems += [f"{path.name}: {name}" for name in too_long]
    if problems:
        sys.exit("over %d characters:\n  %s" % (LIMIT, "\n  ".join(problems)))

    existing = {path.name for path in TARGET.glob("*.uci")}
    stale = sorted(existing - set(converted))
    changed = sorted(
        name
        for name, text in converted.items()
        if name not in existing or (TARGET / name).read_text(encoding="utf-8") != text
    )
    if args.check:
        if stale or changed:
            sys.exit(f"dgt/ out of date: {len(changed)} changed, {len(stale)} stale")
        print(f"dgt/ up to date ({len(converted)} files)")
        return

    TARGET.mkdir(exist_ok=True)
    for name in stale:
        (TARGET / name).unlink()
    for name in changed:
        (TARGET / name).write_text(converted[name], encoding="utf-8")
    print(f"{len(converted)} files, {len(changed)} written, {len(stale)} removed")

    if args.zip:
        args.zip.mkdir(parents=True, exist_ok=True)
        for zip_name, folder in (("mame_uci_web_en.zip", SOURCE), ("mame_uci_dgtpi_en.zip", TARGET)):
            with zipfile.ZipFile(args.zip / zip_name, "w", zipfile.ZIP_DEFLATED) as archive:
                for path in sorted(folder.glob("*.uci")):
                    archive.write(path, path.name)
            print(args.zip / zip_name)


if __name__ == "__main__":
    main()
