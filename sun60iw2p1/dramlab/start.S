/* SPDX-License-Identifier: Apache-2.0 */
/*
 * dramlab: the A733 vendor libdram as a flat AArch32 blob at 0x90000.
 *  +0x00  entry (ARM): called by "sunxi-fel exe 0x90000" from the BROM FEL
 *         loop or by blx from U-Boot SPL (CONFIG_SUNXI_LIBDRAM); returns the
 *         DRAM size in MiB in r0 and also stores it at +0x08
 *  +0x04  magic "DRLB"
 *  +0x08  result (DRAM size in MiB, 0 = failed), +0x0c: run counter
 *  +0x40  struct dram_para (256 bytes), fex order, defaults for Cubie A7A
 */
	.syntax unified
	.section .text.start, "ax"
	.arm
	.global _start
_start:
	b	entry
	.ascii	"DRLB"
	.word	0			/* +0x08 result */
	.word	0			/* +0x0c runs */
	.space	0x30
	.global	dram_para
dram_para:				/* +0x40 */
	.word	1800		/* dram_clk */
	.word	9		/* dram_type: LPDDR5 */
	.word	0x0e0e0e0e	/* dram_dx_odt */
	.word	0x0f0f0f0f	/* dram_dx_dri */
	.word	0xec030e0f	/* dram_ca_dri */
	.word	0		/* dram_para0 */
	.word	0xa10a		/* dram_para1 */
	.word	0x1001		/* dram_para2 */
	.word	0, 0, 0, 0x6, 0, 0, 0	/* mr0..mr6 */
	.word	0x12, 0x44, 0, 0x34	/* mr11 mr12 mr13 mr14 */
	.word	0, 0x86, 0	/* mr16 mr17 mr22 */
	.word	0x4040, 0, 0x11080503, 0x3800	/* tpr0 tpr1 tpr2 tpr3 */
	.word	0x3514, 0x325f0000, 0, 0	/* tpr6 tpr10 tpr11 tpr12 */
	.word	0x10065, 0	/* tpr13 tpr14 */
	.space	256 - 32 * 4

entry:
	push	{r4-r11, lr}
	mov	r4, sp
	ldr	sp, =__stack_top
	push	{r4}
	blx	dramlab_main		/* Thumb */
	pop	{r4}
	mov	sp, r4
	adr	r1, _start
	str	r0, [r1, #8]
	ldr	r2, [r1, #12]
	add	r2, r2, #1
	str	r2, [r1, #12]
	pop	{r4-r11, pc}
	.ltorg
