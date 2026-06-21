#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

BEOUTOS_SQUASHFS_COMPRESSION="zstd"
BEOUTOS_SQUASHFS_COMPRESSION_LEVEL="19"
BEOUTOS_SQUASHFS_BLOCK_SIZE="131072"

horus_create_squashfs() {
    local chroot_dir="$1"
    local output_file="$2"
    local compression="${3:-$BEOUTOS_SQUASHFS_COMPRESSION}"
    local comp_level="${4:-$BEOUTOS_SQUASHFS_COMPRESSION_LEVEL}"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Creating SquashFS image from ${chroot_dir}..."

    if [[ ! -d "$chroot_dir" ]]; then
        echo -e "${RED}${BOLD}[ERROR]${NC} Chroot directory not found: ${chroot_dir}"
        return 1
    fi

    local exclude_dirs=(
        "proc"
        "sys"
        "dev"
        "run"
        "tmp"
        "var/cache"
        "var/tmp"
        "var/log"
        "var/run"
    )

    local exclude_args=()
    for d in "${exclude_dirs[@]}"; do
        exclude_args+=("-e/${d}")
    done

    mksquashfs "$chroot_dir" "$output_file" \
        -comp "$compression" \
        -Xcompression-level "$comp_level" \
        -b "$BEOUTOS_SQUASHFS_BLOCK_SIZE" \
        -no-fragments \
        -no-duplicates \
        -all-root \
        -no-progress \
        "${exclude_args[@]}"

    if [[ ! -f "$output_file" ]]; then
        echo -e "${RED}${BOLD}[ERROR]${NC} SquashFS image creation failed."
        return 1
    fi

    local image_size
    image_size=$(stat -c%s "$output_file" 2>/dev/null || echo 0)
    local image_size_mb
    image_size_mb=$(echo "scale=1; $image_size / 1048576" | bc 2>/dev/null || echo 0)
    echo -e "${GREEN}${BOLD}[OK]${NC} SquashFS image created: ${output_file} (${image_size_mb}MB)"

    horus_verify_squashfs "$output_file"
}

horus_verify_squashfs() {
    local squashfs_file="$1"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Verifying SquashFS image integrity..."

    if [[ ! -f "$squashfs_file" ]]; then
        echo -e "${RED}${BOLD}[ERROR]${NC} SquashFS file not found: ${squashfs_file}"
        return 1
    fi

    local file_type
    file_type=$(file "$squashfs_file" 2>/dev/null | grep -c "Squashfs filesystem" || echo 0)
    if [[ "$file_type" -eq 0 ]]; then
        echo -e "${RED}${BOLD}[ERROR]${NC} File is not a valid SquashFS image."
        return 1
    fi

    local unsquashfs_test
    unsquashfs_test=$(unsquashfs -s "$squashfs_file" 2>/dev/null || echo "")
    if [[ -z "$unsquashfs_test" ]]; then
        echo -e "${RED}${BOLD}[ERROR]${NC} SquashFS image integrity check failed."
        return 1
    fi

    local comp_type
    comp_type=$(unsquashfs -s "$squashfs_file" 2>/dev/null | grep "Compression" | awk '{print $2}' || echo "unknown")
    local num_frags
    num_frags=$(unsquashfs -s "$squashfs_file" 2>/dev/null | grep "Number of fragments" | awk '{print $NF}' || echo "unknown")
    local num_inodes
    num_inodes=$(unsquashfs -s "$squashfs_file" 2>/dev/null | grep "Number of inodes" | awk '{print $NF}' || echo "unknown")

    echo -e "${BLUE}${BOLD}[INFO]${NC} Compression: ${comp_type}"
    echo -e "${BLUE}${BOLD}[INFO]${NC} Fragments: ${num_frags}"
    echo -e "${BLUE}${BOLD}[INFO]${NC} Inodes: ${num_inodes}"

    echo -e "${GREEN}${BOLD}[OK]${NC} SquashFS integrity verification passed."
    return 0
}

horus_write_squashfs_to_partition() {
    local squashfs_file="$1"
    local target_partition="$2"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Writing SquashFS image to partition ${target_partition}..."

    horus_verify_squashfs "$squashfs_file" || return 1

    local mount_point="/mnt/horus-roota"
    mkdir -p "$mount_point"

    mount "$target_partition" "$mount_point"

    cp "$squashfs_file" "${mount_point}/system.squashfs"

    local checksum_source
    checksum_source=$(sha256sum "$squashfs_file" | awk '{print $1}')
    local checksum_target
    checksum_target=$(sha256sum "${mount_point}/system.squashfs" | awk '{print $1}')

    if [[ "$checksum_source" != "$checksum_target" ]]; then
        umount "$mount_point"
        echo -e "${RED}${BOLD}[ERROR]${NC} SquashFS copy integrity mismatch."
        return 1
    fi

    echo "$checksum_source" > "${mount_point}/system.squashfs.sha256"
    echo "${BEOUTOS_SQUASHFS_COMPRESSION}" > "${mount_point}/system.squashfs.meta"

    sync
    umount "$mount_point"

    echo -e "${GREEN}${BOLD}[OK]${NC} SquashFS image written and verified on ${target_partition}."
}

horus_extract_squashfs() {
    local squashfs_file="$1"
    local extract_dir="$2"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Extracting SquashFS image to ${extract_dir}..."

    if [[ ! -f "$squashfs_file" ]]; then
        echo -e "${RED}${BOLD}[ERROR]${NC} SquashFS file not found."
        return 1
    fi

    mkdir -p "$extract_dir"
    unsquashfs -d "$extract_dir" "$squashfs_file"

    if [[ ! -d "$extract_dir" ]]; then
        echo -e "${RED}${BOLD}[ERROR]${NC} SquashFS extraction failed."
        return 1
    fi

    echo -e "${GREEN}${BOLD}[OK]${NC} SquashFS extracted successfully."
}

horus_create_delta_image() {
    local old_squashfs="$1"
    local new_squashfs="$2"
    local delta_output="$3"

    echo -e "${CYAN}${BOLD}[STEP]${NC} Creating delta update image..."

    local old_dir="/tmp/horus-delta-old"
    local new_dir="/tmp/horus-delta-new"

    rm -rf "$old_dir" "$new_dir"
    horus_extract_squashfs "$old_squashfs" "$old_dir"
    horus_extract_squashfs "$new_squashfs" "$new_dir"

    local diff_list="/tmp/horus-delta-files.txt"
    diff -rq "$old_dir" "$new_dir" | grep "^Files" | awk '{print $4}' | \
        sed "s|^${new_dir}/||" > "$diff_list"

    local added_list="/tmp/horus-delta-added.txt"
    diff -rq "$old_dir" "$new_dir" | grep "^Only in ${new_dir}" | \
        awk '{print $3 "/" $NF}' | sed "s|^${new_dir}/||" > "$added_list"

    cat "$diff_list" "$added_list" > "/tmp/horus-delta-combined.txt"

    if [[ ! -s "/tmp/horus-delta-combined.txt" ]]; then
        echo -e "${GREEN}${BOLD}[OK]${NC} No differences found. Delta not needed."
        rm -rf "$old_dir" "$new_dir"
        return 0
    fi

    mksquashfs "$new_dir" "$delta_output" \
        -comp "$BEOUTOS_SQUASHFS_COMPRESSION" \
        -no-fragments \
        -no-progress \
        -all-root

    rm -rf "$old_dir" "$new_dir"
    echo -e "${GREEN}${BOLD}[OK]${NC} Delta image created: ${delta_output}"
}
