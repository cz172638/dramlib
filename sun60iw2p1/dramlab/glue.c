/* SPDX-License-Identifier: Apache-2.0 */
/*
 * Environment libdram expects from boot0: printf, udelay, memcpy, memset,
 * set_ddr_voltage_ext, sunxi_smc_en_with_glitch_workaround.
 */
#include <stdarg.h>
#include <stdint.h>
#include <stddef.h>

#define CCU          0x02002000u
#define PIO_PB_CFG1  0x02000104u
#define UART0        0x02500000u

#define R(a)         (*(volatile uint32_t *)(uintptr_t)(a))

extern uint32_t dram_para[64];
extern uint8_t __bss_start[], __bss_end[];
extern int init_DRAM(int type, void *para);

static void uart_putc(int c)
{
	if (c == '\n') {
		uart_putc('\r');
	}
	while ((R(UART0 + 0x14) & 0x20) == 0) {
	}
	R(UART0) = (uint32_t)c;
}

static void uart_init(void)
{
	R(CCU + 0x538) = 0;                      /* UART clock: HOSC / 1 */
	R(CCU + 0xe00) |= 0x00010001u;           /* UART0 gate, reset off */
	R(PIO_PB_CFG1) = (R(PIO_PB_CFG1) & ~0xff0u) | 0x220u; /* PB9/PB10 */
	R(UART0 + 0x0c) = 0x83;
	R(UART0 + 0x00) = 13;                    /* 24 MHz, 115200 */
	R(UART0 + 0x04) = 0;
	R(UART0 + 0x0c) = 0x03;
	R(UART0 + 0x08) = 0x07;
}

static void put_num(unsigned long v, int base, int width, char pad, int neg)
{
	char b[24];
	int n = 0;

	do {
		b[n++] = "0123456789abcdef"[v % (unsigned int)base];
		v /= (unsigned int)base;
	} while (v != 0 && n < (int)sizeof(b));
	if (neg) {
		b[n++] = '-';
	}
	while (n < width) {
		uart_putc(pad);
		width--;
	}
	while (n > 0) {
		uart_putc(b[--n]);
	}
}

int printf(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	for (; *fmt != '\0'; fmt++) {
		int width = 0;
		char pad = ' ';

		if (*fmt != '%') {
			uart_putc(*fmt);
			continue;
		}
		fmt++;
		if (*fmt == '0') {
			pad = '0';
			fmt++;
		}
		while (*fmt >= '0' && *fmt <= '9') {
			width = width * 10 + (*fmt++ - '0');
		}
		while (*fmt == 'l' || *fmt == 'h') {
			fmt++;
		}
		switch (*fmt) {
		case 'd':
		case 'i': {
			int v = va_arg(ap, int);

			put_num(v < 0 ? (unsigned long)-v : (unsigned long)v, 10, width, pad,
				v < 0);
			break;
		}
		case 'u':
			put_num(va_arg(ap, unsigned int), 10, width, pad, 0);
			break;
		case 'x':
		case 'X':
		case 'p':
			put_num(va_arg(ap, unsigned int), 16, width, pad, 0);
			break;
		case 'c':
			uart_putc(va_arg(ap, int));
			break;
		case 's': {
			const char *s = va_arg(ap, const char *);

			while (s != NULL && *s != '\0') {
				uart_putc(*s++);
			}
			break;
		}
		case '%':
			uart_putc('%');
			break;
		default:
			uart_putc('%');
			uart_putc(*fmt);
			break;
		}
	}
	va_end(ap);
	return 0;
}

/* generic timer, 24 MHz */
static uint64_t cntpct(void)
{
	uint32_t lo, hi;

	__asm__ volatile("isb; mrrc p15, 0, %0, %1, c14" : "=r"(lo), "=r"(hi));
	return ((uint64_t)hi << 32) | lo;
}

void udelay(unsigned long us)
{
	uint64_t end = cntpct() + (uint64_t)us * 24U;

	while (cntpct() < end) {
	}
}

void *memcpy(void *d, const void *s, size_t n)
{
	uint8_t *dd = d;
	const uint8_t *ss = s;

	while (n-- != 0) {
		*dd++ = *ss++;
	}
	return d;
}

void *memset(void *d, int c, size_t n)
{
	uint8_t *dd = d;

	while (n-- != 0) {
		*dd++ = (uint8_t)c;
	}
	return d;
}

/*
 * PMIC rails for the DRAM (AXP318). Not implemented: report the request and
 * rely on the power-on defaults of the board (LPDDR5 straps).
 */
int set_ddr_voltage_ext(const char *name, int mv, int on)
{
	printf("dramlab: set_ddr_voltage_ext(%s, %d mV, %d) ignored\n", name ? name : "?", mv,
	       on);
	return 0;
}

int sunxi_smc_en_with_glitch_workaround(void)
{
	return 0;
}

#define DRAM_BASE 0x40000000u

/* walking pattern at every 64 MiB step of the reported size */
static int dram_check(int mb)
{
	uint32_t step = 64U << 20, n = ((uint32_t)mb << 20) / step, i, bad = 0;

	for (i = 0; i < n; i++) {
		R(DRAM_BASE + i * step) = 0x5a5a0000u ^ i;
		R(DRAM_BASE + i * step + 4) = ~(0x5a5a0000u ^ i);
	}
	for (i = 0; i < n; i++) {
		uint32_t a = R(DRAM_BASE + i * step), b = R(DRAM_BASE + i * step + 4);

		if (a != (0x5a5a0000u ^ i) || b != ~(0x5a5a0000u ^ i)) {
			printf("dramlab: mismatch at %x: %x %x\n", DRAM_BASE + i * step, a, b);
			bad++;
		}
	}
	printf("dramlab: check %u/%u blocks ok\n", n - bad, n);
	return bad == 0 ? 0 : -1;
}

int dramlab_main(void)
{
	int mb;

	memset(__bss_start, 0, (size_t)(__bss_end - __bss_start));
	uart_init();
	printf("\ndramlab: init_DRAM(0, %p) clk %d type %d tpr13 %x\n", dram_para, dram_para[0],
	       dram_para[1], dram_para[30]);
	mb = init_DRAM(0, dram_para);
	printf("dramlab: init_DRAM returned %d MiB\n", mb);
	if (mb > 0 && dram_check(mb) != 0) {
		mb = 0;
	}
	return mb;
}
