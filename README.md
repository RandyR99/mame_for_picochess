# mame_for_picochess

The MAME engine files for [picochess](https://github.com/JohanSjoblom/picochess): for each emulated chess computer, the scripts that start MAME with the [chessengine](https://github.com/RandyR99/chessengine) plugin, its level list, and its entry in picochess's retro engine menu. The files are for **MAME 0.289**.

## Contents

| Path | What it is |
|---|---|
| `retro.ini` | The retro engine list picochess shows: one `[mame/<system>]` section per machine with its names, Elo, number of levels and `ponder/brain`. |
| `mame/<system>` | Start script: runs MAME headless (`-video none`) with the chessengine plugin. picochess passes its MAME options (speed, sound) as `$1`. |
| `mame/<system>_art` | The same with the MAME window and the machine's artwork, used when the artwork display is switched on in picochess. |
| `mame/<system>.uci` | The machine's levels as picochess offers them. |
| `retro_additions.ini` | Proposed new entries, not read by picochess; an entry moves into `retro.ini` once it has been tested and reviewed. |

`<system>` is the MAME set name. A few entries run another set or a cartridge through their script, for example `vccg` runs `vcc -bios de` and `ggm_steinitz` runs `ggm steinitz`.

## Installing

picochess expects MAME in `/opt/picochess/engines/mame_emulation` (the `mess` binary, with this chessengine version in `plugins/chessengine`), and these files in its engine folder (`engines/<architecture>/`): `retro.ini` and the `mame/` folder. The ROMs are not included. Software-list cartridges go in `<softwarelist>.zip` per list.

## Conventions

- **retro.ini**: `name` ends with the year MAME gives for the set. `small` (max 6 characters, lowercase), `medium` (8), `large` (11) and `web` (40) names are unique across the file. `elo` comes from CB-Emu's Programs.txt. `levels` is the number of entries in the `.uci` file. `ponder/brain = y` only when the machine was measured thinking on the player's time; manuals can be wrong.
- **.uci files**: sections `[Level <n> - <description>]` numbered from 1, about ten levels, from easiest to hardest within each group (time per move, game in, tournament). Each has the machine's own level string (`level = ...`) and `PicoTimeControl`. Level times were checked on the machine's display.

## Machines

Which features each machine supports (position setup, history replay, live info, pondering), its known limits and its change history are listed in chessengine's [docs/MACHINES.md](https://github.com/RandyR99/chessengine/blob/main/docs/MACHINES.md).

## License

GPL-3.0, the same as picochess. See [LICENSE](LICENSE).
