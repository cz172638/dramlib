# SPDX-License-Identifier: Apache-2.0
# make [CROSS=arm-zephyr-eabi-] [LIBDRAM=../spl_libdram/libdram]
CROSS   ?= arm-zephyr-eabi-
LIBDRAM ?= ../spl_libdram/libdram
CC      := $(CROSS)gcc
CFLAGS  := -march=armv7-a -mthumb -mfloat-abi=soft -Os -ffreestanding -fno-builtin -nostdlib -Wall -Wextra
LIBGCC  := $(shell $(CC) $(CFLAGS) -print-libgcc-file-name)

dramlab.bin: dramlab.elf
	$(CROSS)objcopy -O binary $< $@

dramlab.elf: start.o glue.o $(LIBDRAM) dramlab.ld
	$(CC) $(CFLAGS) -T dramlab.ld -Wl,--no-warn-rwx-segments -Wl,--no-enum-size-warning \
		-Wl,-Map=dramlab.map -o $@ start.o glue.o $(LIBDRAM) $(LIBGCC)

%.o: %.S
	$(CC) $(CFLAGS) -c $< -o $@
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f start.o glue.o dramlab.elf dramlab.bin dramlab.map
.PHONY: clean
