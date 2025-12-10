#!/bin/bash
# Script outline to install and build kernel.


set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=/home/ravi/toolchain/arm-gnu-toolchain-14.3.rel1-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

if ! sudo mkdir -p ${OUTDIR}; then
	echo "ERROR: Could not create output directory ${OUTDIR}"
	exit 1
fi

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

#user code start for kernel build
	
	make ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE} mrproper
    	make ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE} defconfig
    	make -j$(nproc) ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE} Image
    	cp arch/${ARCH}/boot/Image "${OUTDIR}/Image"
	cd "$OUTDIR"
fi

echo "Kernel built and copied to ${OUTDIR}/Image"

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ];
    	sudo rm  -rf ${OUTDIR}/rootfs
fi
    		sudo rm  -rf ${OUTDIR}/rootfs

sudo mkdir -p "${OUTDIR}/rootfs"{/bin,/dev,/etc,/home,/lib,/lib64,/proc,/sys,/tmp,/usr,/var}
sudo chmod 1777 "${OUTDIR}/rootfs/tmp"

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone https://git.busybox.net/busybox
    cd busybox
    git checkout ${BUSYBOX_VERSION}
else
    cd busybox
fi
make distclean
make ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE} defconfig
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE}
make ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX="${OUTDIR}/rootfs" install
cd "${OUTDIR}"

echo "Library dependencies"

${CROSS_COMPILE}readelf -a ${OUTDIR}/bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a /bin/busybox | grep "Shared library"

echo "Library dependencies: searching for dependencies in ~/bin/busybox"

${CROSS_COMPILE}readelf -a ~/bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a ~/bin/busybox | grep "Shared library"

# TODO: Add library dependencies to rootfs
SYSROOT=$(${CROSS_COMPILE}gcc --print-sysroot)

cp -a $SYSROOT/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib/
cp -a $SYSROOT/lib/libc.so.6 ${OUTDIR}/rootfs/lib64/
cp -a $SYSROOT/lib/libm.so.6 ${OUTDIR}/rootfs/lib64/
cp -a $SYSROOT/lib64/libresolv.s0.6 ${OUTDIR}/rootfs/lib64/



# TODO: Make device nodes

sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3
sudo mknod -m 622 ${OUTDIR}/rootfs/dev/console c 5 1

# TODO: Clean and build the writer utility

cd ~/repos/aeld-assignments/finder-app/
make clean
make ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE}
cp writer ${OUTDIR}/rootfs/home

# TODO: Copy the finder related scripts and executables to the /home directory

sudo mkdir -p "${OUTDIR}/rootfs/home/finder-app"
cp -r ~/repos/aeld-assignments/conf/* ${OUTDIR}/rootfs/home/
cp -r  ~/repos/aeld-assignments/finder-app/* ${OUTDIR}/rootfs/home/finder-app/
cp ~/repos/aeld-assignments/autorun-qemu.sh ${OUTDIR}/rootfs/home/

# TODO: Chown the root directory

cd ${OUTDIR}/rootfs
sudo chown -R root:root *

# TODO: Create initramfs.cpio.gz

cd ${OUTDIR}/rootfs
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
gzip -f ${OUTDIR}/initramfs.cpio.gz

echo "process compelted. Output: ${OUTDIR}/Image and ${OUTDIR}/initramfs.cpio.gz"
