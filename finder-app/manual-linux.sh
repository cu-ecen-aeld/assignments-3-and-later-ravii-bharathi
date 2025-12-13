#!/bin/bash
# AESD Assignment 3: Linux Kernel + BusyBox Rootfs Builder for ARM64 QEMU
# Builds: Linux kernel, BusyBox shell, finder-app, and creates bootable initramfs
# Usage: ./manual-linux.sh [OUTDIR]
# Environment: Set CROSS_COMPILE to override toolchain detection

set -e
set -u

# ============================================================================
# CONFIGURATION
# ============================================================================

OUTDIR=${1:-/tmp/aesd-autograder}
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

print_section() {
    echo ""
    echo "=========================================="
    echo -e "${BLUE}$*${NC}"
    echo "=========================================="
}

# ============================================================================
# TOOLCHAIN DETECTION
# ============================================================================

if [ -z "${CROSS_COMPILE:-}" ]; then
    log_info "Detecting ARM64 cross-compiler toolchain..."
    
    if [ -x /toolchain/arm-gnu-toolchain-14.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-gcc ]; then
        CROSS_COMPILE=/toolchain/arm-gnu-toolchain-14.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
        log_success "Found mounted toolchain at /toolchain (GitHub Actions runner)"
    elif [ -x /home/ravi/toolchain/arm-gnu-toolchain-14.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-gcc ]; then
        CROSS_COMPILE=/home/ravi/toolchain/arm-gnu-toolchain-14.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
        log_success "Found local toolchain at /home/ravi/toolchain"
    elif command -v aarch64-none-linux-gnu-gcc &>/dev/null; then
        CROSS_COMPILE=aarch64-none-linux-gnu-
        log_success "Found system toolchain in PATH"
    else
        log_error "ARM64 toolchain not found in any expected location"
        log_error "Checked: /toolchain, /home/ravi/toolchain, system PATH"
        echo ""
        echo "To fix: Set CROSS_COMPILE=/path/to/toolchain/bin/aarch64-none-linux-gnu-"
        exit 1
    fi
fi

# Verify toolchain is functional
log_info "Verifying toolchain functionality..."
TOOLCHAIN_VERSION=$(${CROSS_COMPILE}gcc --version | head -1)
log_success "Toolchain verified: $TOOLCHAIN_VERSION"

# ============================================================================
# BUILD CONFIGURATION SUMMARY
# ============================================================================

print_section "BUILD CONFIGURATION"
echo "Output directory:      $OUTDIR"
echo "Cross-compiler:        $CROSS_COMPILE"
echo "Architecture:          $ARCH"
echo "Kernel version:        $KERNEL_VERSION"
echo "BusyBox version:       $BUSYBOX_VERSION"
echo "Finder app location:   $FINDER_APP_DIR"

# ============================================================================
# SETUP & VALIDATION
# ============================================================================

if [ $# -lt 1 ]; then
    log_warning "No output directory specified, using default: $OUTDIR"
else
    log_info "Using specified output directory: $OUTDIR"
fi

log_info "Creating output directory and cleaning previous artifacts..."
if ! sudo mkdir -p ${OUTDIR}; then
    log_error "Could not create output directory $OUTDIR"
    exit 1
fi

sudo rm -rf "${OUTDIR}/busybox" "${OUTDIR}/rootfs"
log_success "Previous artifacts removed, ready for fresh build"

# ============================================================================
# KERNEL BUILD
# ============================================================================

print_section "STEP 1: LINUX KERNEL BUILD (${KERNEL_VERSION})"

cd "$OUTDIR"

if [ ! -d "${OUTDIR}/linux-stable" ]; then
    log_info "Cloning linux-stable repository (v${KERNEL_VERSION})..."
    git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
    log_success "Repository cloned"
else
    log_info "Linux-stable repository already exists, skipping clone"
fi

if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    
    log_info "Checking out kernel version ${KERNEL_VERSION}..."
    git checkout ${KERNEL_VERSION}
    
    log_info "Preparing kernel build (mrproper)..."
    make ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE} mrproper
    
    log_info "Generating default ARM64 kernel config..."
    make ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE} defconfig
    
    log_info "Building kernel image (this may take 5-15 minutes)..."
    log_info "Using $(nproc) parallel jobs..."
    make -j$(nproc) ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE} Image
    
    log_info "Copying kernel image to output directory..."
    cp arch/${ARCH}/boot/Image "${OUTDIR}/Image"
    
    cd "$OUTDIR"
else
    log_warning "Kernel Image already exists, skipping build"
fi

log_success "Kernel ready: ${OUTDIR}/Image ($(du -h ${OUTDIR}/Image | cut -f1))"

# ============================================================================
# ROOTFS STAGING
# ============================================================================

print_section "STEP 2: ROOTFS STAGING DIRECTORY"

log_info "Creating directory structure for root filesystem..."
sudo mkdir -p "${OUTDIR}/rootfs"{/bin,/dev,/etc,/home,/lib,/lib64,/proc,/sys,/tmp,/usr,/var}
sudo chmod 1777 "${OUTDIR}/rootfs/tmp"
log_success "Root filesystem skeleton created"

# ============================================================================
# BUSYBOX BUILD
# ============================================================================

print_section "STEP 3: BUSYBOX BUILD AND INSTALLATION"

if [ ! -d "${OUTDIR}/busybox" ]; then
    log_info "Cloning BusyBox source (v${BUSYBOX_VERSION})..."
    git clone https://git.busybox.net/busybox "${OUTDIR}/busybox"
    cd "${OUTDIR}/busybox"
    git checkout "${BUSYBOX_VERSION}"
    log_success "BusyBox repository cloned"
else
    log_info "BusyBox source already exists"
fi

cd "${OUTDIR}/busybox"

log_info "Cleaning previous BusyBox build artifacts..."
make distclean

log_info "Generating default BusyBox configuration for ARM64..."
make ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" defconfig

log_info "Building BusyBox (this may take 2-5 minutes)..."
make -j$(nproc) ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}"

log_info "Installing BusyBox to rootfs..."
sudo make ARCH=arm64 CROSS_COMPILE="${CROSS_COMPILE}" CONFIG_PREFIX="${OUTDIR}/rootfs" install

log_success "BusyBox installed to rootfs"

cd "${OUTDIR}"

# ============================================================================
# LIBRARY DEPENDENCIES
# ============================================================================

print_section "STEP 4: ADDING ARM64 LIBRARY DEPENDENCIES"

log_info "Analyzing BusyBox binary dependencies..."
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "program interpreter" || log_warning "No interpreter found"
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "Shared library" || log_warning "No shared libraries needed"

SYSROOT=$(${CROSS_COMPILE}gcc --print-sysroot)
log_info "Toolchain sysroot: $SYSROOT"

log_info "Creating lib directories..."
sudo mkdir -p "${OUTDIR}/rootfs/lib" "${OUTDIR}/rootfs/lib64"

log_info "Copying glibc runtime libraries..."
# Dynamic linker
sudo cp -a "${SYSROOT}/lib/ld-linux-aarch64.so.1" "${OUTDIR}/rootfs/lib/" 2>/dev/null && \
    log_success "  ✓ ld-linux-aarch64.so.1" || log_warning "  ✗ ld-linux-aarch64.so.1 not found"

# C library
sudo cp -a "${SYSROOT}/lib64/libc.so.6" "${OUTDIR}/rootfs/lib64/" 2>/dev/null && \
    log_success "  ✓ libc.so.6" || log_warning "  ✗ libc.so.6 not found"

# Math library
sudo cp -a "${SYSROOT}/lib64/libm.so.6" "${OUTDIR}/rootfs/lib64/" 2>/dev/null && \
    log_success "  ✓ libm.so.6" || log_warning "  ✗ libm.so.6 not found"

# Resolver library (DNS)
sudo cp -a "${SYSROOT}/lib64/libresolv.so.2" "${OUTDIR}/rootfs/lib64/" 2>/dev/null && \
    log_success "  ✓ libresolv.so.2" || log_warning "  ✗ libresolv.so.2 not found"

log_info "Libraries copied to rootfs"
echo ""
echo "Library verification:"
ls -lh "${OUTDIR}/rootfs/lib/"*.so* "${OUTDIR}/rootfs/lib64/"*.so* 2>/dev/null || log_warning "No libraries found"

# ============================================================================
# DEVICE NODES
# ============================================================================

print_section "STEP 5: CREATING DEVICE NODES"

log_info "Creating /dev/null..."
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3
log_success "  /dev/null created"

log_info "Creating /dev/console..."
sudo mknod -m 622 ${OUTDIR}/rootfs/dev/console c 5 1
log_success "  /dev/console created"

# ============================================================================
# FINDER-APP BUILD & COPY
# ============================================================================

print_section "STEP 6: FINDER-APP BUILD AND INTEGRATION"

log_info "Building finder-app (writer + finder.sh)..."
cd "${FINDER_APP_DIR}"

log_info "Cleaning previous builds..."
make clean

log_info "Building writer utility..."
make ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE}
log_success "Finder-app built successfully"

log_info "Copying finder-app to rootfs /home directory..."
sudo mkdir -p "${OUTDIR}/rootfs/home"

# ✓ FIXED: Copy files directly to /home (not /home/finder-app)
log_info "  Copying binaries and scripts..."
sudo cp writer "${OUTDIR}/rootfs/home/"
log_success "    ✓ writer binary"

sudo cp finder.sh "${OUTDIR}/rootfs/home/"
log_success "    ✓ finder.sh script"

sudo cp finder-test.sh "${OUTDIR}/rootfs/home/"
log_success "    ✓ finder-test.sh"

sudo cp Makefile "${OUTDIR}/rootfs/home/"
log_success "    ✓ Makefile"

sudo cp *.c "${OUTDIR}/rootfs/home/" 2>/dev/null || true
log_success "    ✓ C source files"

log_info "  Copying configuration and autorun script..."
REPO_ROOT=$(cd .. && pwd)
sudo cp -r "${REPO_ROOT}/conf" "${OUTDIR}/rootfs/home/conf"
log_success "    ✓ conf/ directory"

sudo cp "${REPO_ROOT}/autorun-qemu.sh" "${OUTDIR}/rootfs/home/"
log_success "    ✓ autorun-qemu.sh"

# ============================================================================
# ROOTFS VALIDATION
# ============================================================================

print_section "STEP 7: ROOTFS VALIDATION BEFORE PACKING"

cd "${OUTDIR}/rootfs"

log_info "Verifying critical files..."
CRITICAL_FILES=(
    "lib/ld-linux-aarch64.so.1"
    "lib64/libc.so.6"
    "lib64/libm.so.6"
    "lib64/libresolv.so.2"
    "bin/busybox"
    "home/autorun-qemu.sh"
    "home/finder-test.sh"
    "home/Makefile"
    "home/writer"
    "home/conf/username.txt"
)

MISSING=0
for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ] || [ -e "$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ MISSING: $file"
        MISSING=$((MISSING + 1))
    fi
done

if [ $MISSING -gt 0 ]; then
    log_error "$MISSING critical files missing from rootfs!"
    log_error "Cannot proceed to initramfs packing"
    echo ""
    echo "Rootfs /home contents:"
    ls -lh home/
    exit 1
fi

log_success "All critical files present"

echo ""
log_info "Rootfs /home directory contents:"
ls -lhR home/ | head -30

echo ""
log_info "Library files:"
find lib lib64 -name "*.so*" -exec ls -lh {} \; | awk '{print $9, "(" $5 ")"}'

# ============================================================================
# INITRAMFS CREATION
# ============================================================================

print_section "STEP 8: CREATING BOOTABLE INITRAMFS"

log_info "Setting final permissions (all files: root:root)..."
sudo chown -R root:root .
log_success "Permissions set"

log_info "Packing rootfs into cpio archive..."
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
log_success "CPIO archive created"

log_info "Compressing with gzip..."
gzip -f ${OUTDIR}/initramfs.cpio
log_success "Compression complete"

if [ ! -f "${OUTDIR}/initramfs.cpio.gz" ]; then
    log_error "initramfs.cpio.gz not created!"
    exit 1
fi

INITRAMFS_SIZE=$(du -h "${OUTDIR}/initramfs.cpio.gz" | awk '{print $1}')
log_success "Initramfs created: $INITRAMFS_SIZE"

# ============================================================================
# BUILD SUMMARY
# ============================================================================

print_section "BUILD COMPLETE ✓"

echo ""
echo -e "${GREEN}Bootable images created successfully!${NC}"
echo ""
echo "Files generated:"
echo "  • Kernel:   ${OUTDIR}/Image ($(du -h ${OUTDIR}/Image | cut -f1))"
echo "  • Rootfs:   ${OUTDIR}/initramfs.cpio.gz ($INITRAMFS_SIZE)"
echo ""
echo "Ready for QEMU:"
echo "  qemu-system-aarch64 -M virt -m 512M \\"
echo "    -kernel ${OUTDIR}/Image \\"
echo "    -initrd ${OUTDIR}/initramfs.cpio.gz \\"
echo "    -append 'root=/dev/ram0 console=ttyAMA0' \\"
echo "    -nographic"
echo ""

