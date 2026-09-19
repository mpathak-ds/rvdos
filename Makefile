#******** ROOT MAKEFILE ********
#
# You need to set this up so in your project folder, you have two folders:
#
# - rvdos
# - qemu
#
# In the qemu folder, add a subdirectory /build, in which you can keep your
# qemu ch32v307 port file. That can be obtained from my own repository:
# https://github.com/mpathak-ds/qemu-ch32v307
#
# After this setup, it should work. If you have any problems, open an issue
# in this repository.
#
# --- QEMU BUILD ONLY SECTION ---
# For real hardware, skip to the next section.
#
# In order to start building, simply go ahead and run just:
#
# $ make
#
# first. It will run you through a quick setup. After that, quit
# QEMU. Now, to install the sample DOS binaries, run:
#
# $ make cfg
#
# You can now run make again with a full installation. To clean
# your installation, just delete osimg.img at the root.
#
# --- CH32V307 BUILD SECTION ---
#
# TODO add proper after full pipeline
#

.SILENT:

#available: GER, FRE, ENG, NED, JPN, RUS
DOSLANG ?= ENG

all: rv32_make rv32_run rv32_clean

rv32_make:
	# This is the preprocessing step which allows us to write ;-style comments
	# I hate GAS syntax so I had to add this.
	mkdir -p preproc
	sed 's/;.*$$//' boot/fwboot.asm > preproc/fwboot.s
	sed 's/;.*$$//' dos/main.asm > preproc/main.s
	sed 's/;.*$$//' dos/command.asm > preproc/cmd.s
	sed 's/;.*$$//' dos/api.asm > preproc/api.s
	sed 's/;.*$$//' lib/str.asm > preproc/str.s
	sed 's/;.*$$//' drv/disp/uart.asm > preproc/uart.s
	sed 's/;.*$$//' drv/flash/fpec.asm > preproc/fpec.s
	sed 's/;.*$$//' dos/file.asm > preproc/file.s
	
	sed 's/;.*$$//' dos/ver.asm > preproc/ver.s
	sed 's/;.*$$//' dos/help.asm > preproc/help.s
	sed 's/;.*$$//' dos/echo.asm > preproc/echo.s
	sed 's/;.*$$//' dos/memac.asm > preproc/mem.s
	sed 's/;.*$$//' dos/read.asm > preproc/read.s

	sed 's/;.*$$//' doel/emain.asm > preproc/emain.s
	sed 's/;.*$$//' doel/eint.asm > preproc/eint.s

	# Compile
	riscv64-unknown-elf-gcc -march=rv32imafc -mabi=ilp32f -nostdlib -Wa,-defsym,LANG_$(DOSLANG)=1 -I. -I../inc -T link.ld \
	preproc/fwboot.s preproc/main.s preproc/cmd.s preproc/api.s preproc/str.s preproc/uart.s preproc/ver.s \
	preproc/help.s preproc/echo.s preproc/emain.s preproc/eint.s preproc/fpec.s \
	preproc/mem.s preproc/file.s preproc/read.s -o boot.elf

	# Rid of all preprocessing evidence!
	rm -rf preproc

	# Tells us the actual .text size of our program.
	riscv64-unknown-elf-size boot.elf

cfg:
	cd ex/hello && make && cd ../../
	cd tools/fs && make && (./mktffs ../../osimg.img DELETE HELLO.COM || true) && ./mktffs ../../osimg.img CREATE HELLO.COM 1 \
	&& ./mktffs ../../osimg.img WRITE HELLO.COM ../../ex/hello/doel86.com && make clean && cd ../../
	cd ex/hello && make clean && cd ../../

rv32_debug: rv32_make
	cp boot.elf ../qemu/build/boot.elf && cd ../qemu/build/ && ./qemu-system-riscv32 -M ch32v307,flash-image=../../rvdos/osimg.img \
	-cpu rv32,i=true,m=true,a=true,f=true,c=true,pmp=true -kernel boot.elf -serial stdio -s -S

rv32_run:
	cp boot.elf ../qemu/build/boot.elf && cd ../qemu/build/ && ./qemu-system-riscv32 -M ch32v307,flash-image=../../rvdos/osimg.img \
	-cpu rv32,i=true,m=true,a=true,f=true,c=true,pmp=true -kernel boot.elf -nographic && cd ../../rvdos

rv32_clean:
	rm -f boot.elf
