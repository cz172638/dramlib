/* SPDX-License-Identifier: Apache-2.0 */
ENTRY(_start)
SECTIONS
{
	. = 0x90000;
	.text : { KEEP(*(.text.start)) *(.text*) *(.rodata*) *(.glue_7*) }
	.data : { *(.data*) }
	.bss : { __bss_start = .; *(.bss*) *(COMMON) __bss_end = .; }
	. = ALIGN(16);
	__end = .;
	__stack_top = ALIGN(__end + 0x4000, 0x1000);
	/DISCARD/ : { *(.ARM.exidx*) *(.comment) *(.note*) }
}
