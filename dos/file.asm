;*++
;    Copyright Driftless Software Pvt. Ltd 2026
;    file.asm
;    18/09/26
;    mpathak
;    This implements TFFS (Tiny Flash File System).
;--*

.section .text
.global FsFormatAll
.global FsCreateFile

.include "inc/priv/fs.inc"

.equ FS_DIR_BASE, FLASH_BEGIN_FS
.equ FS_DIRENT_SIZE, 16
.equ FS_DIRENT_NUM, 15
.equ FS_STATE_FREE, 0xFF
.equ FS_STATE_USED, 0x01

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
	;for us. But also this way, accidentally, we also create the entire
	;DIRECTORY itself, as 0xFF is marked as unused anyway!
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

;
; FUNCTION DESCRIPTION
;
; This function scans DIRECTORY for the first entry whose STATE is
; still unused.
;
; FUNCTION PARAMETERS
;
; None.
;
; FUNCTION RETURN
;
; a0 - Address of free entry if found, NULL otherwise.
;
FsDirFindFree:
	li t0, FS_DIR_BASE
	li t1, FS_DIRENT_NUM

1:
	beqz t1, 2f
	lbu t2, 0(t0)
	li t3, FS_STATE_FREE
	beq t2, t3, 3f

	addi t0, t0, FS_DIRENT_SIZE
	addi t1, t1, -1
	j 1b

2:
	li a0, 0
	ret

3:
	mv a0, t0
	ret

;
; FUNCTION DESCRIPTION
;
; This function finds the first contigious run of unused sectors starting at
; sector 1 that is at least the requested length. First fit.
;
; FUNCTION PARAMETERS
;
; a0 - Number of sectors requested.
;
; FUNCTION RETURN
;
; a0 - Starting sector number. 0 if not found.
;
FsDirFindFreeRun:
	addi sp, sp, -16
	sw ra, 12(sp)
	sw s0, 8(sp)
	sw s1, 4(sp)
	sw s2, 0(sp)

	mv s1, a0
	;one indexed
	li s0, 1

restart_scan:
	add t0, s0, s1
	li t1, FS_TOTAL_SECTORS
	bgt t0, t1, rf_fail

	li s2, FS_DIR_BASE
	li t2, FS_DIRENT_NUM

scan_loop:
	beqz t2, no_overlap

	lbu t3, 0(s2)
	li t4, FS_STATE_FREE
	beq t3, t4, next_ent

	;occupied
	lhu t5, 8(t2)
	lhu t6, 10(t2)
	add t6, t5, t6

	add t0, s0, s1
	bge s0, t6, next_ent
	ble t0, t5, next_ent

	mv s0, t6
	j restart_scan

next_ent:
	addi s2, s2, FS_DIRENT_SIZE
	addi t2, t2, -1
	j scan_loop

no_overlap:
	mv a0, s0
	j rf_done

rf_fail:
	li a0, 0

rf_done:
	lw s2, 0(sp)
	lw s1, 4(sp)
	lw s0, 8(sp)
	lw ra, 12(sp)
	addi sp, sp, 16
	ret

;
; FUNCTION DESCRIPTION
;
; This function creates a new file but does not write any content.
;
; FUNCTION PARAMETERS
;
; a0 - File name.
; a1 - Number of sectors to reserve.
;
; FUNCTION RETURN
;
; a0 - Address of new DIRECTORY entry.
;
FsCreateFile:
	addi sp, sp, -48
	sw ra, 44(sp)
	sw s0, 40(sp)
	sw s1, 36(sp)
	sw s2, 32(sp)
	sw s3, 28(sp)

	mv s0, a0
	mv s1, a1

	;yes ofcourse we have 0 sectors to reserve..
	beqz s1, cf_fail

	call FsDirFindFree
	;dir full
	beqz a0, cf_fail
	mv s2, a0

	mv a0, s1
	call FsDirFindFreeRun
	;fat file!
	beqz a0, cf_fail
	mv s3, a0

	;build ent
	li t0, FS_STATE_USED
	sb t0, 0(sp)

	mv t1, s0
	li t2, 0
copy_name:
	li t3, FS_MAX_FILE_NAME_LEN
	bge t2, t3, name_pad
	lbu t4, 0(t1)
	beqz t4, name_pad
	addi t5, sp, 1
	add t5, t5, t2
	sb t4, 0(t5)
	addi t1, t1, 1
	addi t2, t2, 1
	j copy_name

name_pad:
	li t3, FS_MAX_FILE_NAME_LEN
	bge t2, t3, name_done
	addi t5, sp, 1
	add t5, t5, t2
	sb zero, 0(t5)
	addi t2, t2, 1
	j name_pad

name_done:
	addi t5, sp, 8
	;START_SECTOR
	sh s3, 0(t5)
	addi t5, sp, 10
	;SECTOR_SPAN
	sh s1, 0(t5)
	;RESERVED
	sb zero, 12(sp)

	mv a0, s2
	mv a1, sp
	li a2, FS_DIRENT_SIZE
	call WriteStorage

	mv a0, s2
	j cf_done

cf_fail:
	li a0, 0

cf_done:
	lw s3, 28(sp)
	lw s2, 32(sp)
	lw s1, 36(sp)
	lw s0, 40(sp)
	lw ra, 44(sp)
	addi sp, sp, 48
	ret
