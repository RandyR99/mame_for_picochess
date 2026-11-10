# mame_for_picochess

The MAME engine files for [picochess](https://github.com/JohanSjoblom/picochess): for each emulated chess computer, the scripts that start MAME with the [chessengine](https://github.com/RandyR99/chessengine) plugin, its level list, and its entry in picochess's retro engine menu. The files are for **MAME 0.289**.

## Contents

| Path | What it is |
|---|---|
| `retro.ini` | The retro engine list picochess shows: one `[mame/<system>]` section per machine with its names, Elo, number of levels and `ponder/brain`. |
| `mame/<system>` | Start script: runs MAME headless (`-video none`) with the chessengine plugin. picochess passes its MAME options (speed, sound) as `$1`. |
| `mame/<system>_art` | The same with the MAME window and the machine's artwork, used when the artwork display is switched on in picochess. |
| `mame/<system>.uci` | The machine's levels as picochess offers them. |
| `dgt/<system>.uci` | The same levels with names short enough for the DGT3000 and DGTPi clocks. Generated from `mame/<system>.uci`. |
| `tools/make_dgt_uci.py` | Generates `dgt/` and builds `mame_uci_web_en.zip` and `mame_uci_dgtpi_en.zip`. |
| `tools/check_softlist_roms.sh` | Lists the engines whose software list ROMs are missing (see [Software lists](#software-lists)). |

`<system>` is the MAME set name. A few entries run another set or a cartridge through their script, for example `vccg` runs `vcc -bios de` and `ggm_steinitz` runs `ggm steinitz`.

## Installing

picochess expects MAME in `/opt/picochess/engines/mame_emulation` (the `mess` binary, with this chessengine version in `plugins/chessengine`), and these files in its engine folder (`engines/<architecture>/`): `retro.ini` and the `mame/` folder. The ROMs are not included.

## ROMs

The ROMs go in `/opt/picochess/engines/mame_emulation/roms`. They must match the MAME version of your `mess` binary: MAME renames sets and replaces ROM dumps between versions, so a ROM set made for another version may not load. Check them with:

```sh
cd /opt/picochess/engines/mame_emulation
./mess -verifyroms
./mess -verifysoftlist
```

Every set should be reported as OK. `-verifyroms` checks the machines' own ROMs (`<system>.zip`), `-verifysoftlist` the software lists described below.

### Software lists

Some machines need a cartridge or an external ROM, for example a program module. Their start scripts give it after the system name, and MAME looks it up in a software list: `mame/arb_sargon25` runs `arb sargon25`, which loads the `sargon25` module from the `arb` list. Without the software list archive these engines don't start.

`-verifysoftlist` only reports the software it finds, not what is missing. To see which engines can't start, run:

```sh
bash tools/check_softlist_roms.sh
```

It prints each engine whose software is missing and the ROM it needs, for example `arb_sargon25: needs arb:sargon25`. By default it checks the start scripts in `/opt/picochess/engines/<arch>/mame` against the ROM folder of the MAME in `/opt/picochess/engines/mame_emulation`. Give other folders as arguments (`check_softlist_roms.sh <script dir> <mame dir>`). To check another ROM folder, such as a ROM pack before you install it, set `ROMPATH=<roms dir>`. MAME also finds software stored as its own zip (`roms/sargon25.zip`), but ROM packs for older MAME versions may use older names (`gms30.zip` for `gms3`), and the script reports those as missing.

Each software list goes in one archive, named `<softwarelist name>.zip`. Inside it, each piece of software has a folder named `<software name>` that holds all of its `<rom name>` files. The names come from:

```sh
./mess -listsoftware <system>
```

This prints the system's software lists as XML: `<softwarelist name="...">`, then `<software name="...">` for each piece of software, with a `<rom name="...">` line for each of its files. Without a system name it prints every list.

The engines here use these archives (MAME 0.289): `arb.zip`, `chessmstdm.zip`, `conchess.zip`, `fidel_msc.zip`, `fidel_sc6.zip`, `fidel_scc.zip`, `ggm.zip`, `intellect02.zip`, `mephisto_mm1.zip`, `mephisto_mm2.zip`, `mephisto_mm4.zip`, `mephisto_mm5.zip`, `mephisto_smondial2.zip`, `novag_ssensor4.zip`, `saitek_egr.zip`, `saitek_kso.zip` and `saitek_schess.zip`.

For example, in MAME 0.289 `arb.zip` holds five folders:

```
arb.zip
    avelan/
        avelan.bin
    gms3/
        1.bin
        2.bin
        3.bin
    gms4/
        1.bin
        2.bin
        3.bin
    sargon25/
        4000-4800_ea_8332a161-1
        5000-5800_ea_8332a160-1
    sargon35/
        1.bin
        2.bin
        3.bin
```

The folders keep files with the same name apart (`gms3`, `gms4` and `sargon35` each have a `1.bin`). `./mess -verifysoftlist arb` checks a single list.

## Conventions

- **retro.ini**: `name` ends with the year MAME gives for the set. `small` (max 6 characters, lowercase), `medium` (8), `large` (11) and `web` (40) names are unique across the file. `elo` comes from CB-Emu's Programs.txt. `levels` is the number of entries in the `.uci` file. `ponder/brain = y` only when the machine was measured thinking on the player's time; manuals can be wrong.
- **.uci files**: sections `[Level <n> - <description>]` numbered from 1, about ten levels, from easiest to hardest within each group (time per move, game in, tournament). Each has the machine's own level string (`level = ...`) and `PicoTimeControl`. Level times were checked on the machine's display.
- **DGT .uci files**: never edited by hand. After a change in `mame/*.uci`, run `tools/make_dgt_uci.py`. Names fit the clock's 11 characters: `[Level 6 - 40 moves/2h]` becomes `[06-40/2h]`. The number is always two digits because picochess sorts level names alphabetically in the clock menu.

## Machines

Which features each machine supports (position setup, history replay, live info, pondering), its known limits and its change history are listed in chessengine's [docs/MACHINES.md](https://github.com/RandyR99/chessengine/blob/main/docs/MACHINES.md).

## License

GPL-3.0, the same as picochess. See [LICENSE](LICENSE).
