# SPDX-License-Identifier: Apache-2.0
#
# Bash helpers around sunxi-fel: registers, GPIO and the UART0 console of
# Allwinner SoCs reached in FEL mode, without anything in DRAM.
#
#   . ./fel.sh                 # FEL=/path/to/sunxi-fel to override
#   fel_soc                    # detect the SoC (A523/A527/T527, A733)
#   uart_init && uart_puts "hello from FEL\r\n"
#   fel_rd 0x02002e00; fel_set 0x02002e00 0x10001; fel_dump 0x02500000 8
#   gpio_func B 6 1; gpio_out B 6 1
#
# Only SRAM and peripherals are usable from FEL; DRAM needs boot0 or an SPL.

FEL=${FEL:-sunxi-fel}

fel() { "$FEL" "$@"; }

hex() { printf '0x%08x' $(( $1 & 0xffffffff )); }

fel_rd() { fel readl "$(hex "$1")"; }

fel_wr() { fel writel "$(hex "$1")" "$(hex "$2")"; }

# fel_rmw <addr> <clear mask> <set mask>
fel_rmw() {
	local v
	v=$(fel_rd "$1") || return
	fel_wr "$1" $(( (v & ~$2) | $3 ))
}

fel_set() { fel_rmw "$1" 0 "$2"; }
fel_clr() { fel_rmw "$1" "$2" 0; }

# fel_dump <addr> [words]
fel_dump() {
	local a=$(( $1 )) n=${2:-1} i
	for (( i = 0; i < n; i++ )); do
		printf '%08x: %s\n' $(( a + 4 * i )) "$(fel_rd $(( a + 4 * i )))"
	done
}

# SoC description: CCU, UART clock/gate registers, PIO layout, UART0
fel_soc() {
	local id
	id=$(fel version | sed -n 's/.*soc=\([0-9a-fA-F]*\).*/\1/p')
	case $(( 16#${id:-0} )) in
	$(( 0x1890 )))	# A523/A527/T527
		SOC=a523 CCU=0x02001000 UART_CLK= UART_BGR=0x90c
		PIO=0x02000000 PIO_BANK=0x30 UART0=0x02500000 UART_HZ=24000000 ;;
	$(( 0x1903 )))	# A733
		SOC=a733 CCU=0x02002000 UART_CLK=0x538 UART_BGR=0xe00
		PIO=0x02000080 PIO_BANK=0x80 UART0=0x02500000 UART_HZ=24000000 ;;
	*)
		echo "fel_soc: unknown SoC id '$id'" >&2
		return 1 ;;
	esac
	echo "$SOC (soc=$id)"
}

# PIO, ports from A: CFGn at +4n (4 bits per pin), DAT at +0x10
pio_bank() { echo $(( PIO + ($(printf '%d' "'$1") - 65) * PIO_BANK )); }

# gpio_func <port> <pin> <function>   (0 input, 1 output, 2.. peripheral)
gpio_func() {
	local b sh
	b=$(pio_bank "$1")
	sh=$(( ($2 % 8) * 4 ))
	fel_rmw $(( b + ($2 / 8) * 4 )) $(( 0xf << sh )) $(( ($3 & 0xf) << sh ))
}

# gpio_out <port> <pin> <0|1>
gpio_out() {
	local b
	b=$(pio_bank "$1")
	if (( $3 )); then fel_set $(( b + 0x10 )) $(( 1 << $2 )); else fel_clr $(( b + 0x10 )) $(( 1 << $2 )); fi
}

gpio_in() { local b; b=$(pio_bank "$1"); echo $(( ($(fel_rd $(( b + 0x10 ))) >> $2) & 1 )); }

# UART0 on PB9/PB10 (function 2), 8N1
uart_init() {
	local baud=${1:-115200} div
	[[ -n $SOC ]] || fel_soc >/dev/null || return
	[[ -n $UART_CLK ]] && fel_wr $(( CCU + UART_CLK )) 0
	fel_set $(( CCU + UART_BGR )) 0x00010001
	gpio_func B 9 2
	gpio_func B 10 2
	div=$(( (UART_HZ + 8 * baud) / (16 * baud) ))
	fel_wr $(( UART0 + 0x0c )) 0x83
	fel_wr $(( UART0 + 0x00 )) $(( div & 0xff ))
	fel_wr $(( UART0 + 0x04 )) $(( div >> 8 ))
	fel_wr $(( UART0 + 0x0c )) 0x03
	fel_wr $(( UART0 + 0x08 )) 0x07
}

uart_putc() { fel_wr "$UART0" "$1"; }

# uart_puts <string>, printf escapes allowed ("\r\n")
uart_puts() {
	local s i
	s=$(printf '%b.' "$1")
	s=${s%.}
	for (( i = 0; i < ${#s}; i++ )); do
		uart_putc "$(printf '%d' "'${s:i:1}")"
	done
}
