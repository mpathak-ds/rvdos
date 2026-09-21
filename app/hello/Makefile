all:
	riscv64-unknown-elf-gcc -march=rv32imafc -mabi=ilp32f -nostdlib -I../stdlib/ -mno-relax -fPIC -fvisibility=hidden -ffreestanding -T ../app.ld -Wl,--no-relax \
	../stdlib/std.s main.c -o main.elf
	riscv64-unknown-elf-objcopy -O binary main.elf ../../main.bin
	rm main.elf
