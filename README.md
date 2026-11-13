# Psycho-Nics Oscar — for MEGA65

**Psycho-Nics Oscar** is Data East's arcade action-platform game, featuring two-player support, eight-way movement and three action buttons.

This project is an **original FPGA implementation of Psycho-Nics Oscar for the MEGA65**. It uses reusable components from **Jotego's JTFRAME/JTCORES framework** and also uses **T65 6502 CPU core originally developed by Daniel Wallner,with contributions from Mike Johnson, Wolfgang Scherr and Morten Leikvoll.**.

The core uses [MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65) and [QNICE-FPGA](https://github.com/sy2002/QNICE-FPGA) for MEGA65 integration, SD-card ROM loading, configuration and the on-screen menu.

## Credits

- **Jotego and JTCORES contributors** — JTFRAME infrastructure and reusable FPGA components used by this project;
- **sy2002, MJoergen and the MiSTer2MEGA65 contributors** — MEGA65 framework and related integration.
- **Data East Corporation** — original Psycho-Nics Oscar arcade game.
- **T65 6502 Core - Daniel Wallner, Mike Johnson, Wolfgang Scherr and Morten Leikvoll**

This is an unofficial, independently developed FPGA implementation, not an official Data East release.

## How to install the core

### 1. Obtain the original MAME ROMs

Supply your own compatible **World (`oscar`)** MAME ROM set. **ROMs are not included in this repository.**

Unlike cores that require converted or merged ROM images, **Oscar does not need a ROM-generation script**. Extract the individual ROM files from `oscar.zip`, retaining their original filenames, into this directory on your MEGA65 SD card:

```text
/arcade/oscar/
```

The following original chip files are required:

| Region | ROM files |
|---|---|
| Main CPU | `du10`, `ed09` |
| Sub CPU | `du11` |
| Sound CPU | `ed12` |
| Characters | `ed08` |
| Sprites | `ed04`, `ed05`, `ed06`, `ed07` |
| Background tiles | `ed00`, `ed01`, `ed02`, `ed03` |

Your SD-card directory should look like this:

```text
/arcade/oscar/
    du10
    ed09
    du11
    ed12
    ed08
    ed04
    ed05
    ed06
    ed07
    ed00
    ed01
    ed02
    ed03
```

Do **not** combine, interleave, rename or convert these files. The FPGA core handles the required ROM layout internally.

### 2. Install the MEGA65 core

Install the Oscar `.cor` file using the standard MEGA65 core installation procedure. Use the version built for your MEGA65 hardware revision.

### 3. Start the game

Launch the core with the ROM files present in `/arcade/oscar/`. Press **HELP** to open the MiSTer2MEGA65 on-screen menu for controls, display options and the original arcade DIP switches.

## Game setup

### Controls

Oscar uses an **eight-way joystick** and three action buttons:

| Game action | MEGA65 joystick input | Keyboard (Player 1) |
|---|---|---|
| Move | Joystick directions | Cursor keys |
| Attack / Shoot | Fire / configurable button mapping | `Z` |
| Jump | POTX / configurable button mapping | `X` |
| Power-Up / Select | POTY / configurable button mapping | `C` |
| Player 1 start | — | `1` |
| Player 2 start | — | `2` |
| Coin 1 / Coin 2 | — | `5` / `6` |
| Service | — | `9` |

The control menu provides alternative assignments for **Fire, POTX and POTY**, plus POT polarity selection. Keyboard movement and action buttons apply to Player 1.

### DIP switches

The on-screen menu exposes Oscar's original two DIP-switch banks:

| DSW0 | Function |
|---|---|
| Coin 1 | Coinage |
| Coin 2 | Coinage |
| Demo Freeze Mode | Off / On |
| Attract Mode Sound | On / Off |
| Flip Screen | Normal / Reverse |
| Cabinet Type | Upright / Table (cocktail) |

| DSW1 | Function |
|---|---|
| No. of Lives | Lives selection |
| Difficulty | Normal / Easy / Hard / Hardest |
| Extend | Extra-life thresholds |
| No Death | Off / On |
| Allow Continue | Yes / No |

The game software controls screen orientation through the BAC06 video register. Some changes to **Flip Screen** and **Cabinet Type** may take effect during a game transition or after a reset, rather than immediately when toggled in the menu.

### Video and audio

The game uses a **horizontal** screen layout. The MEGA65 framework provides HDMI and analogue video configuration through the on-screen menu, including options for compatible 15 kHz CRT displays.

Audio is generated using **YM2203** and **YM3526** sound synthesis.

## Upstream projects and components

- [JTCORES / JTFRAME — Jotego](https://github.com/jotego/jtcores) (reusable FPGA framework and components)
- [MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65)
- [QNICE-FPGA](https://github.com/sy2002/QNICE-FPGA)
- [T65 6502 core](https://github.com/MiSTer-devel/T65)

These projects provide infrastructure or components. **The Psycho-Nics Oscar game core itself was written independently for this MEGA65 project.** Individual source files retain their respective copyright notices and licences; consult the repository's licence information.

## Status and issue reports

This README describes the **World (`oscar`)** ROM set. Other regional or revision sets are not documented as supported here.

For problems with this MEGA65 implementation, report the MEGA65 revision, ROM set, observed behaviour and reproduction steps to this project's issue tracker. Please do not report MEGA65-specific problems to the upstream framework projects unless the issue is also reproducible in their components.
