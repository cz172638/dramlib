# SPDX-License-Identifier: Apache-2.0
#
# Drive dramlab.bin (A733 libdram in SRAM) through sunxi-fel.
#
#   . ./fel.sh; . ./dramlab.sh       # FEL=~/bin/sunxi-fel-a733
#   dram_load                        # write dramlab.bin to 0x90000
#   dram_para                        # show the parameter block
#   dram_set clk 1200                # change a field before the run
#   dram_run                         # init_DRAM, prints the size in MiB
#   fel_dump 0x40000000 4            # DRAM is reachable from FEL afterwards

DRAMLAB=${DRAMLAB:-0x90000}
DRAMLAB_BIN=${DRAMLAB_BIN:-$(dirname "${BASH_SOURCE[0]}")/dramlab.bin}

# struct dram_para field order (sys_config.fex [dram_para])
DRAM_FIELDS=(clk type dx_odt dx_dri ca_dri para0 para1 para2
	mr0 mr1 mr2 mr3 mr4 mr5 mr6 mr11 mr12 mr13 mr14 mr16 mr17 mr22
	tpr0 tpr1 tpr2 tpr3 tpr6 tpr10 tpr11 tpr12 tpr13 tpr14)

dram_off() {
	local i
	for i in "${!DRAM_FIELDS[@]}"; do
		[[ ${DRAM_FIELDS[i]} == "${1#dram_}" ]] && { echo $(( DRAMLAB + 0x40 + 4 * i )); return; }
	done
	echo "dram_off: unknown field '$1'" >&2
	return 1
}

dram_load() {
	fel write "$(hex "$DRAMLAB")" "$DRAMLAB_BIN" || return
	[[ $(fel_rd $(( DRAMLAB + 4 ))) == 0x4452424c ]] || { echo "dram_load: no DRLB magic" >&2; return 1; }
}

dram_para() {
	local i
	for i in "${!DRAM_FIELDS[@]}"; do
		printf '%-7s %s\n' "${DRAM_FIELDS[i]}" "$(fel_rd $(( DRAMLAB + 0x40 + 4 * i )))"
	done
}

dram_get() { local o; o=$(dram_off "$1") && fel_rd "$o"; }
dram_set() { local o; o=$(dram_off "$1") && fel_wr "$o" "$2"; }

# runs init_DRAM; log on UART0 (115200), result word at +0x08
dram_run() {
	fel exe "$(hex "$DRAMLAB")" || return
	printf 'dram: %d MiB (run %d)\n' "$(fel_rd $(( DRAMLAB + 8 )))" "$(fel_rd $(( DRAMLAB + 12 )))"
}
