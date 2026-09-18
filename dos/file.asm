;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    file.asm
;    18/09/26
;    mpathak
;    This implements TFFS (Tiny Flash File System).
;--*

.section .text
.global FsFormatAll

;adjustable based on available storage
.equ FLASH_BEGIN_FS, 0x08010000
.equ FLASH_SECTOR_SIZE, 0x100 ;256 bytes
.equ FS_MAX_FILE_NAME_LEN, 7
.equ FS_MAGIC_ADDR, FLASH_BEGIN_FS + FLASH_SECTOR_SIZE - 4
.equ FS_MAGIC_VAL, 0x53464654 ;TFFS little endian

;
;flash is divided into 256 byte or flash sector size sectors. sector 0 is reserved and
;recognized as SPECIAL because it houses the DIRECTORY.. each file reserves at most 1
;sector, in a contiguous run reserved when the file was created. this does not mean that
;all files can only be 256 bytes, because when created it can reserve more than a single
;sector, such as a file can reserve sectors 1-4. however that is not dynamic and static
;when created. there is no free page tracking implemented in this design.
;
;During formatting of the flash to install TFFS, at end of sector 0, the last 4 bytes are
;written with a magic number to reserve as the DIRECTORY. it also erases every sector.
;when the OS boots, it mounts, which all that means is it checks for those reserved bytes
;and formats the flash if corrupted or not formatted with TFFS. it may ask for confirmation
;at that time but that is UX design.
;
;When creating a file, it walks the DIRECTORY. It is about time I explain what DIR actually is,
;simply put, it is an array of 16 byte entries, ordered as below:
;
;U8 STATE
;CHAR NAME[7]
;U16 START_SECTOR
;U16 SECTOR_SPAN
;U8 RESERVED
;
;It then finds the first run of unused pages long enough for the request, and then finds the entry
;whose state is still 0xFF or not filled in yet. then it writes that 16 byte entry.
;
;When opening a file, it looks up the directory entry by name, it fetches the starting sector and
;sector count, giving the file addr range. A dirty little trick is applied here! when figuring
;where the write should resume, we do not store the current size as a number. instead, every write
;itself is stored as:
;
;[2 byte len] [payload] [padding to 4 byte alignment]
;
;Opening walks these writes, ONLY reading the 2 byte length! not byte by byte. If 0xFF or erased,
;we found the end, if not, increment by the length found in that header.
;
;When writing to a file, we build the whole record as documented above as one buffer. then we write
;that buffer in ONE call starting where we found it stop via OPENFILE, then advance cursor in RAM.
;

;
; FUNCTION DESCRIPTION
;
; This function formats FLASH for TFFS.
;
; FUNCTION PARAMETERS
;
; None.
;
; FUNCTION CLOBBERS
;
; None.
;
FsFormatAll:
	addi sp, sp, -16
	sw ra, 8(sp)

	;
	;Ideally we would erase first, but WriteStorage already does that
	;for us.
	;

	;write 4 byte magic at tail of sector 0
	li t0, FS_MAGIC_VAL
	sw t0, 0(sp)

	;target address
	li a0, FS_MAGIC_ADDR
	mv a1, sp
	;byte count
	li a2, 4
	call WriteStorage

	lw ra, 8(sp)
	addi sp, sp, 16
	ret
