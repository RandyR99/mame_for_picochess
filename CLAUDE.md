# CLAUDE.md — mame_for_picochess

Guidance for Claude Code (and other AI coding tools) working in this repo. README.md describes the files for users.

## What this is

[picochess](https://github.com/JohanSjoblom/picochess)'s engine definitions for its MAME retro engines (current as of MAME 0.289), using the [chessengine](https://github.com/RandyR99/chessengine) plugin. Artwork is in [picochess_mame_artwork](https://github.com/RandyR99/picochess_mame_artwork).

- `retro.ini` — one `[mame/<system>]` section per machine: `name`, `small`, `medium`, `large`, `web`, `elo`, `levels`, `ponder/brain`, and an optional `comments`.
- `mame/<system>` — headless launch script. `mame/<system>_art` runs the same with the MAME window and artwork. `mame/<system>.uci` is the level list.
- `dgt/<system>.uci` — copies with short level names for DGT clocks. They are generated: never edit them by hand.
- `tools/make_dgt_uci.py` — regenerates `dgt/` (`--check` verifies it, `--zip DIR` also builds the two `.uci` zips).
- `tools/check_softlist_roms.sh` — lists engines whose software list ROMs are missing and searches the ROM zips for their files by CRC. It reads the software name from each start script, so update its argument parsing if a script uses a new media option.

## Rules

- Commit and push only after the maintainer's OK, usually together with the matching chessengine change.
- **Newly created engine entries are vetted by the maintainer before they are added to `retro.ini`.** Approved entries go in alphabetical order, next to their parent set. Existing entries are edited in place.
- Every working MAME set gets a launch script, an `_art` script, a `.uci` file and a retro entry. A clone may reuse its parent's levels.
- Remove files for systems that the targeted MAME release no longer has, together with their retro entries.
- LF line endings. After every change to `mame/*.uci`, run `tools/make_dgt_uci.py`.

## retro.ini

- `name` ends with the year from the set's `SYST`/`CONS` line in the MAME driver. Write only the year, never a ROM date; ROM dates go in `comments`.
- `small` has at most 6 characters and is lowercase. `medium` has at most 8, `large` 11 and `web` 40. **Every `name`, `small`, `medium`, `large` and `web` value must be unique across the whole file.** Recheck the whole file after adding entries.
- `levels` is the number of entries in the `.uci` file.
- Set `ponder/brain = y` only if the machine was measured thinking on the player's time. Measure from a position outside the opening book, because manuals can be wrong. Otherwise set `n`.
- `comments` is free text on one line; picochess ignores it.

## .uci files

- Sections are `[Level 1 - <desc>]`, `[Level 2 - ...]` in sequence, with exactly one blank line between sections. Each section has `level = <the machine's own level string>` and `PicoTimeControl = ...`.
- PicoTimeControl formats:
  - one number = seconds per move
  - `5 0` = a 5-minute game
  - `40 90 0` = 40 moves in 90 minutes

  Add no increment unless the manual specifies one.
- The heading time matches PicoTimeControl, for example `5s move`, `5m game` or `40 moves/2h`.
- Aim for about ten levels: 5s, 10s, 30s, 1m, 5m and 10m per move, 5m, 10m and 30m per game, and a classical level. Pick the closest machine level for each, and check the level string on the machine's display.
- The minimum is 5 s per move, unless the machine has very few levels. Leave out fixed-depth levels and impractical ones (hours per move).
- Order the levels as follows:
  1. per-move levels, ascending
  2. game levels, ascending
  3. tournament levels, by time per move
  4. Analysis, last, and only if the interface has `show_info`

## Scripts

Launch scripts change to picochess's `engines/mame_emulation` folder and run `mess $1 -video none -plugin chessengine <system>` with `SDL_VIDEODRIVER=dummy`. The `_art` scripts drop both. picochess passes its MAME options as `$1`. Cartridge sets pass the software-list item (`-cart ...`); ROMs aren't part of this repo.
