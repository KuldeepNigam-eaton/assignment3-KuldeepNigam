#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} linux-stable --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # TODO: Add your kernel build steps here
    # Deep clean to remove any stale configuration
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    # Generate default configuration for arm64
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    # Build kernel image, modules and device tree blobs
    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
fi

echo "Adding the Image in outdir"
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}
echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
mkdir -p ${OUTDIR}/rootfs
cd ${OUTDIR}/rootfs
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr/bin usr/lib usr/sbin var/log

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone https://github.com/mirror/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox
    make distclean
    make defconfig
else
    cd busybox
fi

# TODO: Make and install busybox
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install

echo "Library dependencies"
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "Shared library"

# TODO: Add library dependencies to rootfs
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)

# Copy the program interpreter (dynamic linker)
INTERP=$(${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')
cp -a ${SYSROOT}/${INTERP} ${OUTDIR}/rootfs/lib/

# Copy shared libraries referenced by busybox
for lib in $(${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p'); do
    LIBFILE=$(find ${SYSROOT} -name "${lib}" ! -type d | head -1)
    cp -a "${LIBFILE}" ${OUTDIR}/rootfs/lib64/
done

# TODO: Make device nodes
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3
sudo mknod -m 600 ${OUTDIR}/rootfs/dev/console c 5 1

# TODO: Clean and build the writer utility
cd /home/eaton/training/assignment2-KuldeepNigam/finder-app
make clean
CROSS_COMPILE=${CROSS_COMPILE} make
cp writer ${OUTDIR}/rootfs/home/
cd "$OUTDIR"

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs

ASSIGNMENT2_DIR=/home/eaton/training/assignment2-KuldeepNigam/finder-app

# Copy required Assignment 2 artifacts into target /home
cp ${ASSIGNMENT2_DIR}/finder.sh ${OUTDIR}/rootfs/home/
cp ${ASSIGNMENT2_DIR}/finder-test.sh ${OUTDIR}/rootfs/home/
mkdir -p ${OUTDIR}/rootfs/home/conf
cp ${ASSIGNMENT2_DIR}/conf/username.txt ${OUTDIR}/rootfs/home/conf/
cp ${ASSIGNMENT2_DIR}/conf/assignment.txt ${OUTDIR}/rootfs/home/conf/

# Update finder-test.sh to use conf/assignment.txt in rootfs/home layout
sed -i 's#\.\./conf/assignment\.txt#conf/assignment.txt#g' ${OUTDIR}/rootfs/home/finder-test.sh

cp ${FINDER_APP_DIR}/autorun-qemu.sh ${OUTDIR}/rootfs/home/



# TODO: Chown the root directory
sudo chown -R root:root ${OUTDIR}/rootfs

# TODO: Create initramfs.cpio.gz
cd ${OUTDIR}/rootfs
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
gzip -f ${OUTDIR}/initramfs.cpio
