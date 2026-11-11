# Psycho-Nics Oscar — ROM layout baseline

Source: supplied `Psycho-Nics Oscar (World).mra`, cross-checked against supplied MAME `dec8.cpp` ROM_START(oscar).

| Combined ROM offset | Size | MRA input | Notes |
|---|---:|---|---|
| 0x00000 | 0x08000 | du10 | Main fixed ROM; MAME maps at maincpu 0x08000 |
| 0x08000 | 0x10000 | ed09 | Main banked ROM; MAME maps at maincpu 0x10000 |
| 0x18000 | 0x10000 | du11 | Sub CPU ROM; MAME maps at sub 0x0000 |
| 0x28000 | 0x08000 | ed12 | Audio CPU ROM; MAME maps at audiocpu 0x8000 |
| 0x30000 | 0x08000 | ed08 + 0x4000 zero padding | Only 0x4000 actual character ROM bytes |
| 0x38000 | 0x40000 | ed04, ed05, ed06, ed07 | Four 0x10000 sprite chips; MRA interleaves 32-bit with maps 0001/0010/0100/1000 |
| 0x78000 | 0x40000 | ed01, ed03, ed00, ed02 | Four 0x10000 tile chips; MRA interleaves 32-bit with maps 0001/0010/0100/1000 |
| **0xB8000** | | | **752,640 bytes (735 KiB)** |

## Important implementation distinctions

- The MAME sprite and tile **region capacities** are each 0x80000, but each contains four 0x10000 ROMs (0x40000 actual ROM bytes). The MRA repacks those into a dense 0x40000 interleaved region. Do not allocate 0x80000 per region based only on MAME region declarations.
- `ed08` contains 0x4000 bytes; the MRA adds 0x4000 padding. The combined ROM therefore uses 0x8000 for the character region.
- The sound CPU's 0x20000 MAME region includes a decrypted opcode area; the MRA only stores the original 0x8000 ROM. Opcode decryption must be performed in hardware (or equivalent logic), not by allocating the full MAME region.
- The main banked ROM consists of 4 x 0x4000 banks in `ed09`; bank selection logic must be confirmed against the MAME handler.
- No `gfx_sort` operation is yet justified. Keep the MRA's interleave layout until the HDL graphics address mapping is specified and tested.
- 735 KiB of combined ROM is a **layout size**, not a confirmed MEGA65 BRAM fit. RAM requirements and access timing still need budgeting.
