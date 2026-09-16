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

.SILENT:
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
	
	sed 's/;.*$$//' dos/ver.asm > preproc/ver.s
	sed 's/;.*$$//' dos/help.asm > preproc/help.s
	sed 's/;.*$$//' dos/echo.asm > preproc/echo.s

	sed 's/;.*$$//' doel/emain.asm > preproc/emain.s
	sed 's/;.*$$//' doel/eint.asm > preproc/eint.s

	# Compile
	riscv64-unknown-elf-gcc -march=rv32imafc -mabi=ilp32f -nostdlib -I../inc -T link.ld \
	preproc/fwboot.s preproc/main.s preproc/cmd.s preproc/api.s preproc/str.s preproc/uart.s preproc/ver.s \
	preproc/help.s preproc/echo.s preproc/emain.s preproc/eint.s -o boot.elf

	# Rid of all preprocessing evidence!
	rm -rf preproc

	# Tells us the actual .text size of our program.
	riscv64-unknown-elf-size boot.elf

rv32_debug: rv32_make
	cp boot.elf ../qemu/build/boot.elf && cd ../qemu/build/ && ./qemu-system-riscv32 -M ch32v307 \
	-cpu rv32,i=true,m=true,a=true,f=true,c=true,pmp=true -kernel boot.elf -serial stdio -s -S

rv32_run:
	cp boot.elf ../qemu/build/boot.elf && cd ../qemu/build/ && ./qemu-system-riscv32 -M ch32v307 \
	-cpu rv32,i=true,m=true,a=true,f=true,c=true,pmp=true -kernel boot.elf -nographic && cd ../../rvdos

rv32_clean:
	rm -f boot.elf
