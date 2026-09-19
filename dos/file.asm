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
.global FsOpenFile
.global FsWriteFile
.global FsReadFile
.global FsSafeWriteStorage

.include "inc/priv/fs.inc"

.equ FS_DIR_BASE, FLASH_BEGIN_FS
.equ FS_DIRENT_SIZE, 16
.equ FS_DIRENT_NUM, 15
.equ FS_STATE_FREE, 0xFF
.equ FS_STATE_USED, 0x01

;RMW wrapper
FsSafeWriteStorage:
	addi sp, sp, -48
	sw ra, 44(sp)
	sw s0, 40(sp)
	sw s1, 36(sp)
	sw s2, 32(sp)
	sw s3, 28(sp)
	sw s4, 24(sp)

	mv s0, a0
	mv s1, a1
	mv s2, a2

sw_page_loop:
	beqz s2, sw_ok

	li t0, ~(FS_ERASE_PAGE_SIZE - 1)
	and s3, s0, t0

	sub t2, s0, s3

	li t3, FS_ERASE_PAGE_SIZE
	sub t3, t3, t2
	ble t3, s2, sw_chunk_ok
	mv t3, s2
sw_chunk_ok:
	mv s4, t3

	la t4, FsPageScratch
	mv t5, s3
	li t6, FS_ERASE_PAGE_SIZE
sw_read_loop:
	beqz t6, sw_read_done
	lbu a3, 0(t5)
	sb a3, 0(t4)
	addi t5, t5, 1
	addi t4, t4, 1
	addi t6, t6, -1
	j sw_read_loop
sw_read_done:

	la t4, FsPageScratch
	add t4, t4, t2
	mv t5, s1
	mv t6, s4
sw_patch_loop:
	beqz t6, sw_patch_done
	lbu a3, 0(t5)
	sb a3, 0(t4)
	addi t5, t5, 1
	addi t4, t4, 1
	addi t6, t6, -1
	j sw_patch_loop
sw_patch_done:

	mv a0, s3
	la a1, FsPageScratch
	li a2, FS_ERASE_PAGE_SIZE
	call WriteStorage
	bnez a0, sw_fail

	add s0, s0, s4
	add s1, s1, s4
	sub s2, s2, s4
	j sw_page_loop

sw_ok:
	li a0, 0
	j sw_done

sw_fail:
	li a0, -1

sw_done:
	lw s4, 24(sp)
	lw s3, 28(sp)
	lw s2, 32(sp)
	lw s1, 36(sp)
	lw s0, 40(sp)
	lw ra, 44(sp)
	addi sp, sp, 48
	ret

.section .bss
.align 2
FsPageScratch:
	.space FS_ERASE_PAGE_SIZE

.section .text

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
;CHAR NAME[FS_FILENAME_LEN]
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
	call FsSafeWriteStorage

	lw ra, 8(sp)
	addi sp, sp, 16
	ret

FsNormalizeName:
	li t0, 0
zero_loop:
	li t1, FS_FULLNAME_LEN
	bge t0, t1, zero_done
	add t2, a1, t0
	sb zero, 0(t2)
	addi t0, t0, 1
	j zero_loop
zero_done:

	mv t3, a0
	li t4, 0

name_copy:
	li t5, FS_NAME_LEN
	bge t4, t5, skip_to_dot

	lbu t6, 0(t3)
	beqz t6, nm_done
	li t0, '.'
	beq t6, t0, found_dot

	li t0, 'a'
	blt t6, t0, nm_store
	li t0, 'z'
	bgt t6, t0, nm_store
	addi t6, t6, -32

nm_store:
	add t0, a1, t4
	sb t6, 0(t0)
	addi t3, t3, 1
	addi t4, t4, 1
	j name_copy

skip_to_dot:
	lbu t6, 0(t3)
	beqz t6, nm_done
	li t0, '.'
	beq t6, t0, found_dot
	addi t3, t3, 1
	j skip_to_dot

found_dot:
	addi t3, t3, 1
	li t4, 0

ext_copy:
	li t5, FS_EXT_LEN
	bge t4, t5, nm_done

	lbu t6, 0(t3)
	beqz t6, nm_done

	li t0, 'a'
	blt t6, t0, ext_store
	li t0, 'z'
	bgt t6, t0, ext_store
	addi t6, t6, -32

ext_store:
	addi t0, a1, FS_NAME_LEN
	add t0, t0, t4
	sb t6, 0(t0)
	addi t3, t3, 1
	addi t4, t4, 1
	j ext_copy

nm_done:
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
	lhu t5, 12(s2)
	lhu t6, 14(s2)
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

	mv a0, s0
	addi a1, sp, 1
	call FsNormalizeName

name_done:
	addi t5, sp, 12
	sh s3, 0(t5)
	addi t5, sp, 14
	sh s1, 0(t5)

	mv a0, s2
	mv a1, sp
	li a2, FS_DIRENT_SIZE
	call FsSafeWriteStorage

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

FsDirFindByName:
	addi sp, sp, -32
	sw ra, 28(sp)
	sw s0, 24(sp)
	sw s1, 20(sp)
	sw s2, 16(sp)

	mv s0, a0
	addi a1, sp, 0
	call FsNormalizeName

	li s1, FS_DIR_BASE
	li s2, FS_DIRENT_NUM

entry_loop:
	beqz s2, fbn_fail

	lbu t0, 0(s1)
	li t1, FS_STATE_FREE
	beq t0, t1, fbn_next

	li t2, 0
cmp_loop:
	li t3, FS_FULLNAME_LEN
	bge t2, t3, fbn_match

	addi t4, s1, 1
	add t4, t4, t2
	lbu t5, 0(t4)

	add t6, sp, t2
	lbu a2, 0(t6)

	bne t5, a2, fbn_next
	addi t2, t2, 1
	j cmp_loop

fbn_match:
	mv a0, s1
	j fbn_done

fbn_next:
	addi s1, s1, FS_DIRENT_SIZE
	addi s2, s2, -1
	j entry_loop

fbn_fail:
	li a0, 0

fbn_done:
	lw s2, 16(sp)
	lw s1, 20(sp)
	lw s0, 24(sp)
	lw ra, 28(sp)
	addi sp, sp, 32
	ret

;
; FUNCTION DESCRIPTION
;
; This function opens a file by name.
;
; FUNCTION PARAMETERS
;
; a0 - File name.
; a1 - OUT, pointer to FS_FILE structure (see below).
;
; FUNCTION RETURN
;
; a0 - Address of DIRECTORY entry.
;
FsOpenFile:
	;
	;FS_FILE struct
	;
	;U32 BASE_ADDRESS
	;U32 CURSOR_ADDRESS
	;U32 END_ADDRESS
	;U32 READ_CURSOR
	;

	addi sp, sp, -32
	sw ra, 28(sp)
	sw s0, 24(sp)
	sw s1, 20(sp)
	sw s2, 16(sp)
	sw s3, 12(sp)
	sw s4, 8(sp)

	mv s0, a1

	call FsDirFindByName
	beqz a0, of_fail
	mv s1, a0

	;BASE_ADDRESS=FLASH_BEGIN_FS+START_SECTOR*FLASH_SECTOR_SIZE
	lhu t0, 12(s1)
	slli t0, t0, 8
	li t1, FLASH_BEGIN_FS
	add s2, t1, t0

	;END_ADDRESS=BASE_ADDRESS+SECTOR_SPAN*FLASH_SECTOR_SIZE
	lhu t0, 14(s1)
	slli t0, t0, 8
	add s3, s2, t0

	mv s4, s2

walk_loop:
	addi t0, s4, 2
	bgt t0, s3, walk_done

	lhu t1, 0(s4)
	li t2, 0xFFFF
	beq t1, t2, walk_done

	addi t3, t1, 2
	addi t3, t3, 3
	andi t3, t3, ~3

	add t4, s4, t3
	bgt t4, s3, walk_done

	mv s4, t4
	j walk_loop

walk_done:
	sw s2, 0(s0)
	sw s4, 4(s0)
	sw s3, 8(s0)
	sw s2, 12(s0)

	mv a0, s1
	j of_done

of_fail:
	li a0, 0

of_done:
	lw s4, 8(sp)
	lw s3, 12(sp)
	lw s2, 16(sp)
	lw s1, 20(sp)
	lw s0, 24(sp)
	lw ra, 28(sp)
	addi sp, sp, 32
	ret

;
; FUNCTION DESCRIPTION
;
; This function writes to a file by name and appending.
;
; FUNCTION PARAMETERS
;
; a0 - Pointer to FS_FILE structure.
; a1 - Pointer to payload.
; a2 - Payload length in BYTES.
;
; FUNCTION RETURN
;
; a0 - 0 on success, -1 if too large.
;
FsWriteFile:
	addi sp, sp, -288
	sw ra, 276(sp)
	sw s0, 272(sp)
	sw s1, 268(sp)
	sw s2, 264(sp)
	sw s3, 260(sp)
	sw s4, 256(sp)
	;sp+0 .. sp+255 doubles as the rec build buffer

	mv s0, a0
	mv s1, a1
	mv s2, a2

	li t0, FS_MAX_PAYLOAD_LEN
	bgt s2, t0, wf_fail

	;PADDED SIZE =align4(2 + len)
	addi t1, s2, FS_REC_HDR_SIZE
	addi t1, t1, 3
	andi t1, t1, -4
	mv s3, t1

	lw t2, 4(s0)
	lw t3, 8(s0)
	mv s4, t2

	add t4, t2, s3
	;fat file!
	bgt t4, t3, wf_fail

	sh s2, 0(sp)

	mv t5, s1
	li t6, 0
copy_loop:
	bge t6, s2, pad_start
	lbu t0, 0(t5)
	addi t1, sp, FS_REC_HDR_SIZE
	add t1, t1, t6
	sb t0, 0(t1)
	addi t5, t5, 1
	addi t6, t6, 1
	j copy_loop

pad_start:
	addi t0, s2, FS_REC_HDR_SIZE
pad_loop:
	bge t0, s3, do_write
	add t1, sp, t0
	sb zero, 0(t1)
	addi t0, t0, 1
	j pad_loop

do_write:
	mv a0, s4
	mv a1, sp
	mv a2, s3
	call FsSafeWriteStorage
	bnez a0, wf_fail

	add t2, s4, s3
	sw t2, 4(s0)

	li a0, 0
	j wf_done

wf_fail:
	li a0, -1

wf_done:
	lw s4, 256(sp)
	lw s3, 260(sp)
	lw s2, 264(sp)
	lw s1, 268(sp)
	lw s0, 272(sp)
	lw ra, 276(sp)
	addi sp, sp, 288
	ret

;
; FUNCTION DESCRIPTION
;
; This function reads the next record from a file using the
; FS_FILE cursor.
;
; FUNCTION PARAMETERS
;
; a0 - Pointer to FS_FILE structure.
; a1 - Pointer to destination buffer.
; a2 - Destination buffer capacity in BYTES.
;
; FUNCTION RETURN
;
; a0 - Number of bytes copied on success, 0 if at end of file, -1 if next record larger
; than supplied buffer. Note that on -1, cursor is not advanced and caller may retry
; with a larger buffer.
;
FsReadFile:
	addi sp, sp, -32
	sw ra, 28(sp)
	sw s0, 24(sp)
	sw s1, 20(sp)
	sw s2, 16(sp)
	sw s3, 12(sp)
	sw s4, 8(sp)

	mv s0, a0
	mv s1, a1
	mv s2, a2

	lw s3, 12(s0)
	lw t0, 4(s0)

	bge s3, t0, rf_eof

	lhu s4, 0(s3)
	li t2, 0xFFFF
	beq s4, t2, rf_eof

	bgt s4, s2, rf_toobig

	addi t3, s3, FS_REC_HDR_SIZE
	mv t4, s1
	li t5, 0
rd_copy_loop:
	bge t5, s4, rd_copy_done
	lbu t6, 0(t3)
	sb t6, 0(t4)
	addi t3, t3, 1
	addi t4, t4, 1
	addi t5, t5, 1
	j rd_copy_loop
rd_copy_done:
	addi t1, s4, FS_REC_HDR_SIZE
	addi t1, t1, 3
	andi t1, t1, -4
	add t2, s3, t1
	sw t2, 12(s0)

	mv a0, s4
	j .rf_done

rf_eof:
	li a0, 0
	j .rf_done

rf_toobig:
	li a0, -1

.rf_done:
	lw s4, 8(sp)
	lw s3, 12(sp)
	lw s2, 16(sp)
	lw s1, 20(sp)
	lw s0, 24(sp)
	lw ra, 28(sp)
	addi sp, sp, 32
	ret
