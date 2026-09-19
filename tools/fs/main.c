/*
	Copyright 2026 Driftless Software Pvt. Ltd
	main.c
	19/09/26
	mpathak
	MKTFFS image inspection and manipulation utility.
*/

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <ctype.h>

#define IMG_START_ADDR      0x00010000ULL

#define FS_SECTOR_SIZE      256ULL
#define FS_DIRENT_SIZE      16ULL
#define FS_DIRENT_NUM       15

#define FS_STATE_FREE       0xFF
#define FS_STATE_USED       0x01

#define FS_NAME_LEN         8
#define FS_EXT_LEN          3
#define FS_FULLNAME_LEN     (FS_NAME_LEN + FS_EXT_LEN)

#define FS_START_SECTOR_OFF 12
#define FS_SECTOR_SPAN_OFF  14

#define FS_REC_HDR_SIZE     2
#define FS_MAX_PAYLOAD_LEN  254

unsigned long gProgVersionMajor = 1;
unsigned long gProgVersionMinor = 2;
unsigned long gProgVersionBuild = 1;

static uint16_t read_le16(const unsigned char *p)
{
	return (uint16_t)p[0] |
	       ((uint16_t)p[1] << 8);
}

static void write_le16(unsigned char *p, uint16_t val)
{
	p[0] = (unsigned char)(val & 0xFF);
	p[1] = (unsigned char)((val >> 8) & 0xFF);
}

static uint64_t align4(uint64_t value)
{
	return (value + 3ULL) & ~3ULL;
}

static void normalize_name(
	const char *input,
	char *name,
	char *ext)
{
	size_t i = 0;
	const char *dot;

	memset(name, 0, FS_NAME_LEN + 1);
	memset(ext, 0, FS_EXT_LEN + 1);

	dot = strchr(input, '.');

	if (dot != NULL) {
		size_t name_len = (size_t)(dot - input);

		if (name_len > FS_NAME_LEN)
			name_len = FS_NAME_LEN;

		for (i = 0; i < name_len; ++i)
			name[i] = (char)toupper((unsigned char)input[i]);

		dot++;

		for (i = 0; i < FS_EXT_LEN && dot[i] != '\0'; ++i)
			ext[i] = (char)toupper((unsigned char)dot[i]);
	} else {
		for (i = 0; i < FS_NAME_LEN && input[i] != '\0'; ++i)
			name[i] = (char)toupper((unsigned char)input[i]);
	}
}

static void print_filename(const unsigned char *entry)
{
	int i;
	int has_name = 0;
	int has_ext = 0;

	for (i = 0; i < FS_NAME_LEN; ++i) {
		unsigned char c = entry[1 + i];
		if (c == 0) break;
		putchar(c);
		has_name = 1;
	}

	for (i = 0; i < FS_EXT_LEN; ++i) {
		unsigned char c = entry[1 + FS_NAME_LEN + i];
		if (c == 0) break;
		if (!has_ext) {
			putchar('.');
			has_ext = 1;
		}
		putchar(c);
	}

	if (!has_name && !has_ext)
		printf("<unnamed>");
}

static int filename_matches(
	const unsigned char *entry,
	const char *wanted)
{
	char wanted_name[FS_NAME_LEN + 1];
	char wanted_ext[FS_EXT_LEN + 1];

	normalize_name(wanted, wanted_name, wanted_ext);

	for (int i = 0; i < FS_NAME_LEN; ++i) {
		unsigned char disk = entry[1 + i];
		unsigned char expected = (unsigned char)wanted_name[i];
		if (disk != expected) return 0;
		if (disk == 0) break;
	}

	for (int i = 0; i < FS_EXT_LEN; ++i) {
		unsigned char disk = entry[1 + FS_NAME_LEN + i];
		unsigned char expected = (unsigned char)wanted_ext[i];
		if (disk != expected) return 0;
		if (disk == 0) break;
	}

	return 1;
}

static int read_dir_entry(
	FILE *fp,
	unsigned int index,
	unsigned char *entry)
{
	uint64_t offset = IMG_START_ADDR + ((uint64_t)index * FS_DIRENT_SIZE);

	if (fseeko(fp, (off_t)offset, SEEK_SET) != 0)
		return -1;

	if (fread(entry, 1, FS_DIRENT_SIZE, fp) != FS_DIRENT_SIZE)
		return -1;

	return 0;
}

static int write_dir_entry(
	FILE *fp,
	unsigned int index,
	const unsigned char *entry)
{
	uint64_t offset = IMG_START_ADDR + ((uint64_t)index * FS_DIRENT_SIZE);

	if (fseeko(fp, (off_t)offset, SEEK_SET) != 0)
		return -1;

	if (fwrite(entry, 1, FS_DIRENT_SIZE, fp) != FS_DIRENT_SIZE)
		return -1;

	return 0;
}

static int calculate_file_size(
	FILE *fp,
	uint64_t file_start,
	uint64_t file_end,
	uint64_t *logical_size,
	uint64_t *record_count,
	uint64_t *free_cursor)
{
	uint64_t cursor = file_start;
	uint64_t size = 0;
	uint64_t records = 0;

	while (cursor + FS_REC_HDR_SIZE <= file_end) {
		unsigned char hdr[2];
		uint16_t length;
		uint64_t record_size;
		uint64_t next;

		if (fseeko(fp, (off_t)cursor, SEEK_SET) != 0)
			return -1;

		if (fread(hdr, 1, 2, fp) != 2)
			return -1;

		length = read_le16(hdr);

		if (length == 0xFFFF)
			break;

		record_size = align4((uint64_t)FS_REC_HDR_SIZE + (uint64_t)length);
		next = cursor + record_size;

		if (next > file_end)
			return -1;

		size += length;
		records++;
		cursor = next;
	}

	if (logical_size) *logical_size = size;
	if (record_count) *record_count = records;
	if (free_cursor)  *free_cursor  = cursor;

	return 0;
}

static int find_file(
	FILE *fp,
	const char *filename,
	unsigned char *entry,
	unsigned int *entry_index)
{
	for (unsigned int i = 0; i < FS_DIRENT_NUM; ++i) {
		if (read_dir_entry(fp, i, entry) != 0)
			return -1;

		if (entry[0] != FS_STATE_USED)
			continue;

		if (filename_matches(entry, filename)) {
			if (entry_index != NULL)
				*entry_index = i;
			return 0;
		}
	}
	return -1;
}

static void get_file_range(
	const unsigned char *entry,
	uint64_t *file_start,
	uint64_t *file_end)
{
	uint16_t start_sector = read_le16(&entry[FS_START_SECTOR_OFF]);
	uint16_t sector_span  = read_le16(&entry[FS_SECTOR_SPAN_OFF]);

	*file_start = IMG_START_ADDR + ((uint64_t)start_sector * FS_SECTOR_SIZE);
	*file_end   = *file_start + ((uint64_t)sector_span * FS_SECTOR_SIZE);
}

static uint16_t find_free_sector_run(FILE *fp, uint64_t image_size, uint16_t sectors_needed)
{
	uint64_t total_sectors = (image_size - IMG_START_ADDR) / FS_SECTOR_SIZE;
	uint16_t start_sector = 1; // Sector 0 is reserved for directory table

	while (start_sector + sectors_needed <= total_sectors) {
		int overlap = 0;

		for (unsigned int i = 0; i < FS_DIRENT_NUM; ++i) {
			unsigned char entry[FS_DIRENT_SIZE];

			if (read_dir_entry(fp, i, entry) != 0)
				return 0;

			if (entry[0] == FS_STATE_FREE)
				continue;

			uint16_t ent_start = read_le16(&entry[FS_START_SECTOR_OFF]);
			uint16_t ent_span  = read_le16(&entry[FS_SECTOR_SPAN_OFF]);
			uint16_t ent_end   = ent_start + ent_span;

			uint16_t req_end   = start_sector + sectors_needed;

			if (start_sector < ent_end && req_end > ent_start) {
				start_sector = ent_end;
				overlap = 1;
				break;
			}
		}

		if (!overlap)
			return start_sector;
	}

	return 0;
}

static int create_file_entry(
	FILE *fp,
	const char *filename,
	uint16_t sector_span,
	uint64_t image_size)
{
	unsigned char entry[FS_DIRENT_SIZE];
	unsigned int free_index = FS_DIRENT_NUM;

	if (sector_span == 0) {
		fprintf(stderr, "MKTFFS: sector span must be > 0\n");
		return -1;
	}

	for (unsigned int i = 0; i < FS_DIRENT_NUM; ++i) {
		if (read_dir_entry(fp, i, entry) != 0)
			return -1;

		if (entry[0] == FS_STATE_FREE) {
			if (free_index == FS_DIRENT_NUM)
				free_index = i;
		} else if (entry[0] == FS_STATE_USED) {
			if (filename_matches(entry, filename)) {
				fprintf(stderr, "MKTFFS: file '%s' already exists\n", filename);
				return -1;
			}
		}
	}

	if (free_index == FS_DIRENT_NUM) {
		fprintf(stderr, "MKTFFS: directory full\n");
		return -1;
	}

	uint16_t start_sector = find_free_sector_run(fp, image_size, sector_span);
	if (start_sector == 0) {
		fprintf(stderr, "MKTFFS: not enough contiguous flash space\n");
		return -1;
	}

	memset(entry, 0, FS_DIRENT_SIZE);
	entry[0] = FS_STATE_USED;

	char name[FS_NAME_LEN + 1];
	char ext[FS_EXT_LEN + 1];
	normalize_name(filename, name, ext);

	memcpy(&entry[1], name, FS_NAME_LEN);
	memcpy(&entry[1 + FS_NAME_LEN], ext, FS_EXT_LEN);

	write_le16(&entry[FS_START_SECTOR_OFF], start_sector);
	write_le16(&entry[FS_SECTOR_SPAN_OFF], sector_span);

	if (write_dir_entry(fp, free_index, entry) != 0) {
		fprintf(stderr, "MKTFFS: failed to write directory entry\n");
		return -1;
	}

	printf("Created %s (start_sector=%u, sector_span=%u)\n", filename, start_sector, sector_span);
	return 0;
}

static int delete_file_entry(
	FILE *fp,
	const char *filename,
	uint64_t image_size)
{
	unsigned char entry[FS_DIRENT_SIZE];
	unsigned int entry_index;
	uint64_t file_start, file_end;

	if (find_file(fp, filename, entry, &entry_index) != 0) {
		fprintf(stderr, "MKTFFS: file '%s' not found in image\n", filename);
		return -1;
	}

	uint16_t start_sector = read_le16(&entry[FS_START_SECTOR_OFF]);
	uint16_t sector_span  = read_le16(&entry[FS_SECTOR_SPAN_OFF]);

	if (start_sector == 0) {
		fprintf(stderr, "MKTFFS Error: Refusing to delete entry with start_sector=0 (Directory Sector)\n");
		return -1;
	}

	if (sector_span == 0) {
		fprintf(stderr, "MKTFFS Error: Cannot delete file with 0 sector span\n");
		return -1;
	}

	get_file_range(entry, &file_start, &file_end);

	uint64_t min_allowed_addr = IMG_START_ADDR + FS_SECTOR_SIZE;

	if (file_start < min_allowed_addr || file_end > image_size || file_end <= file_start) {
		fprintf(stderr, "MKTFFS Error: Invalid file range [0x%llX - 0x%llX] for image size 0x%llX\n",
		        (unsigned long long)file_start,
		        (unsigned long long)file_end,
		        (unsigned long long)image_size);
		return -1;
	}

	unsigned char ff_buf[FS_SECTOR_SIZE];
	memset(ff_buf, FS_STATE_FREE, sizeof(ff_buf));

	if (fseeko(fp, (off_t)file_start, SEEK_SET) != 0) {
		fprintf(stderr, "MKTFFS: failed to seek to file data start (0x%llX)\n", (unsigned long long)file_start);
		return -1;
	}

	for (uint64_t cursor = file_start; cursor < file_end; cursor += FS_SECTOR_SIZE) {
		if (fwrite(ff_buf, 1, FS_SECTOR_SIZE, fp) != FS_SECTOR_SIZE) {
			fprintf(stderr, "MKTFFS: failed to erase sector at offset 0x%llX\n", (unsigned long long)cursor);
			return -1;
		}
	}

	memset(entry, FS_STATE_FREE, FS_DIRENT_SIZE);

	if (write_dir_entry(fp, entry_index, entry) != 0) {
		fprintf(stderr, "MKTFFS: failed to update directory entry for deletion\n");
		return -1;
	}

	printf("Successfully deleted '%s' (erased data sectors %u to %u)\n",
	       filename, start_sector, start_sector + sector_span - 1);
	return 0;
}

static int write_file_contents(
	FILE *fp,
	const char *tffs_filename,
	const char *local_filepath,
	uint64_t image_size)
{
	unsigned char entry[FS_DIRENT_SIZE];
	uint64_t file_start, file_end, free_cursor;
	FILE *local_fp;

	if (find_file(fp, tffs_filename, entry, NULL) != 0) {
		fprintf(stderr, "MKTFFS: file '%s' not found in image\n", tffs_filename);
		return -1;
	}

	get_file_range(entry, &file_start, &file_end);

	if (calculate_file_size(fp, file_start, file_end, NULL, NULL, &free_cursor) != 0) {
		fprintf(stderr, "MKTFFS: target file corrupted or invalid range\n");
		return -1;
	}

	local_fp = fopen(local_filepath, "rb");
	if (!local_fp) {
		fprintf(stderr, "MKTFFS: cannot open local file '%s': %s\n", local_filepath, strerror(errno));
		return -1;
	}

	unsigned char buffer[FS_MAX_PAYLOAD_LEN];
	size_t bytes_read;

	while ((bytes_read = fread(buffer, 1, sizeof(buffer), local_fp)) > 0) {
		uint64_t padded_size = align4((uint64_t)FS_REC_HDR_SIZE + bytes_read);

		if (free_cursor + padded_size > file_end) {
			fprintf(stderr, "MKTFFS: allocated file sectors exceeded!\n");
			fclose(local_fp);
			return -1;
		}

		unsigned char hdr[2];
		write_le16(hdr, (uint16_t)bytes_read);

		if (fseeko(fp, (off_t)free_cursor, SEEK_SET) != 0 ||
			fwrite(hdr, 1, 2, fp) != 2 ||
			fwrite(buffer, 1, bytes_read, fp) != bytes_read) {
			fprintf(stderr, "MKTFFS: write to image failed\n");
			fclose(local_fp);
			return -1;
		}
		size_t pad_bytes = padded_size - (FS_REC_HDR_SIZE + bytes_read);
		if (pad_bytes > 0) {
			unsigned char zeros[4] = {0};
			if (fwrite(zeros, 1, pad_bytes, fp) != pad_bytes) {
				fprintf(stderr, "MKTFFS: write padding failed\n");
				fclose(local_fp);
				return -1;
			}
		}

		free_cursor += padded_size;
	}

	fclose(local_fp);
	printf("Successfully wrote '%s' to '%s'\n", local_filepath, tffs_filename);
	return 0;
}

static int list_files(FILE *fp, uint64_t image_size)
{
	unsigned char entry[FS_DIRENT_SIZE];
	int found_files = 0;

	printf("FILES:\n");
	printf("------------------------------------------------------------\n");

	for (unsigned int i = 0; i < FS_DIRENT_NUM; ++i) {
		uint16_t start_sector, sector_span;
		uint64_t file_start, file_end, logical_size, record_count;

		if (read_dir_entry(fp, i, entry) != 0) return -1;
		if (entry[0] == FS_STATE_FREE) continue;

		if (entry[0] != FS_STATE_USED) {
			printf("[%02u] INVALID STATE 0x%02X\n", i, entry[0]);
			continue;
		}

		start_sector = read_le16(&entry[FS_START_SECTOR_OFF]);
		sector_span  = read_le16(&entry[FS_SECTOR_SPAN_OFF]);

		if (sector_span == 0) {
			printf("[%02u] INVALID: zero sector span\n", i);
			continue;
		}

		get_file_range(entry, &file_start, &file_end);

		if (file_start >= image_size || file_end > image_size || file_end < file_start) {
			printf("[%02u] INVALID RANGE\n", i);
			continue;
		}

		if (calculate_file_size(fp, file_start, file_end, &logical_size, &record_count, NULL) != 0) {
			printf("[%02u] CORRUPT FILE: ", i);
			print_filename(entry);
			putchar('\n');
			continue;
		}

		printf("[%02u] ", i);
		print_filename(entry);
		printf("   start=%u  sectors=%u  size=%llu  records=%llu\n",
		       start_sector, sector_span, (unsigned long long)logical_size, (unsigned long long)record_count);

		found_files++;
	}

	printf("------------------------------------------------------------\n");
	printf("%d file%s found.\n", found_files, found_files == 1 ? "" : "s");
	return 0;
}

static int read_file_contents(FILE *fp, const char *filename, uint64_t image_size)
{
	unsigned char entry[FS_DIRENT_SIZE];
	uint64_t file_start, file_end, cursor;

	if (find_file(fp, filename, entry, NULL) != 0) {
		fprintf(stderr, "MKTFFS: file not found: %s\n", filename);
		return -1;
	}

	get_file_range(entry, &file_start, &file_end);

	if (file_start >= image_size || file_end > image_size || file_end < file_start) {
		fprintf(stderr, "MKTFFS: file range is outside image\n");
		return -1;
	}

	cursor = file_start;

	while (cursor + FS_REC_HDR_SIZE <= file_end) {
		unsigned char hdr[2];
		uint16_t length;

		if (fseeko(fp, (off_t)cursor, SEEK_SET) != 0 || fread(hdr, 1, 2, fp) != 2)
			return -1;

		length = read_le16(hdr);
		if (length == 0xFFFF) break;

		if (cursor + FS_REC_HDR_SIZE + length > file_end) {
			fprintf(stderr, "MKTFFS: corrupt record in %s\n", filename);
			return -1;
		}

		for (uint32_t i = 0; i < length; ++i) {
			int c = fgetc(fp);
			if (c == EOF) return -1;
			putchar(c);
		}

		cursor += align4((uint64_t)FS_REC_HDR_SIZE + (uint64_t)length);
	}

	return 0;
}

static void usage(const char *program)
{
	fprintf(
		stderr,
		"Usage:\n"
		"  %s IMAGE.IMG\n"
		"  %s IMAGE.IMG LIST\n"
		"  %s IMAGE.IMG READ FILE\n"
		"  %s IMAGE.IMG CREATE FILE SECTORS\n"
		"  %s IMAGE.IMG WRITE FILE LOCAL_PATH\n"
		"  %s IMAGE.IMG DELETE FILE\n",
		program, program, program, program, program, program
	);
}

int main(int argc, char **argv)
{
	FILE *fp;
	uint64_t image_size;

	printf(
		"DRIFTLESS MKTFFS VERSION %lu.%lu.%lu\n",
		gProgVersionMajor,
		gProgVersionMinor,
		gProgVersionBuild
	);

	if (argc < 2 || argc > 5) {
		usage(argv[0]);
		return EXIT_FAILURE;
	}

	const char *cmd = (argc >= 3) ? argv[2] : "LIST";
	int is_write_op = (strcasecmp(cmd, "WRITE") == 0 ||
	                   strcasecmp(cmd, "CREATE") == 0 ||
	                   strcasecmp(cmd, "DELETE") == 0 ||
	                   strcasecmp(cmd, "DEL") == 0);

	fp = fopen(argv[1], is_write_op ? "rb+" : "rb");

	if (fp == NULL) {
		fprintf(stderr, "MKTFFS: cannot open '%s': %s\n", argv[1], strerror(errno));
		return EXIT_FAILURE;
	}

	if (fseeko(fp, 0, SEEK_END) != 0) {
		fprintf(stderr, "MKTFFS: cannot seek image\n");
		fclose(fp);
		return EXIT_FAILURE;
	}

	off_t end = ftello(fp);
	if (end < 0) {
		fprintf(stderr, "MKTFFS: cannot determine image size\n");
		fclose(fp);
		return EXIT_FAILURE;
	}
	image_size = (uint64_t)end;

	if (image_size < IMG_START_ADDR + FS_SECTOR_SIZE) {
		fprintf(stderr, "MKTFFS: image is too small for TFFS\n");
		fclose(fp);
		return EXIT_FAILURE;
	}

	int result = -1;

	if (strcasecmp(cmd, "LIST") == 0) {
		result = list_files(fp, image_size);
	} else if (strcasecmp(cmd, "READ") == 0) {
		if (argc != 4) {
			usage(argv[0]);
		} else {
			result = read_file_contents(fp, argv[3], image_size);
		}
	} else if (strcasecmp(cmd, "CREATE") == 0) {
		if (argc != 5) {
			usage(argv[0]);
		} else {
			uint16_t sectors = (uint16_t)atoi(argv[4]);
			result = create_file_entry(fp, argv[3], sectors, image_size);
		}
	} else if (strcasecmp(cmd, "WRITE") == 0) {
		if (argc != 5) {
			usage(argv[0]);
		} else {
			result = write_file_contents(fp, argv[3], argv[4], image_size);
		}
	} else if (strcasecmp(cmd, "DELETE") == 0 || strcasecmp(cmd, "DEL") == 0) {
		if (argc != 4) {
			usage(argv[0]);
		} else {
			result = delete_file_entry(fp, argv[3], image_size);
		}
	} else {
		fprintf(stderr, "MKTFFS: unknown command '%s'\n", cmd);
		usage(argv[0]);
	}

	fclose(fp);
	return (result == 0) ? EXIT_SUCCESS : EXIT_FAILURE;
}
