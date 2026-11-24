# dramlab

The Allwinner A733 (sun60iw2p1) vendor `libdram` linked into a flat AArch32
blob that runs from SRAM at `0x90000`. It is started from the BROM FEL loop
with `sunxi-fel exe`, so DRAM can be brought up and its parameters changed
from a shell without boot0 or an SPL.

The same `dramlab.bin` follows the calling convention of the A733 U-Boot SPL
hook (`CONFIG_SUNXI_LIBDRAM`, `CONFIG_SUNXI_LIBDRAM_BASE=0x90000`): entered
with `blx`, returns the DRAM size in MiB in `r0`.

## Layout

| Offset | Content |
|--------|---------|
| `+0x00` | ARM entry: own stack, `dramlab_main()`, returns to the caller |
| `+0x04` | magic `DRLB` |
| `+0x08` | result: DRAM size in MiB, 0 on failure |
| `+0x0c` | run counter |
| `+0x40` | `struct dram_para`, `sys_config.fex` field order, Cubie A7A values |

`.bss` follows the image (cleared at entry), the stack sits 16 KiB above it
(`0xc7000`); everything stays below 0xc8000.

## Glue for libdram

`printf` (UART0 PB9/PB10, 115200), `udelay` (CNTPCT, 24 MHz), `memcpy`,
`memset`, `sunxi_smc_en_with_glitch_workaround` (no-op) and
`set_ddr_voltage_ext` (only prints: PMIC rails stay at their power-on
values). `__aeabi_*` come from libgcc (soft-float).

After `init_DRAM` a pattern is written and read back at every 64 MiB of the
reported size; a mismatch sets the result to 0.

## Build

    make CROSS=arm-zephyr-eabi-        # links ../spl_libdram/libdram

## Use

    export FEL=~/bin/sunxi-fel-a733
    . ./fel.sh; . ./dramlab.sh
    fel_soc            # a733 (soc=1903)
    dram_load
    dram_para
    dram_run           # log on UART0
    fel_dump 0x40000000 4

Change a parameter before `dram_run`: `dram_set clk 1200`,
`dram_set tpr13 0x10065`. `dram_load` restores the defaults.
