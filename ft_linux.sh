#!/bin/bash
# FT_LINUX/LFS script made by zoulhafi Tested on UBUNTU SERVER 20.04.3 LTS
# Source : https://www.linuxfromscratch.org/lfs/view/11.0/

LFS_PASSWD=321456
CORES=3

apt update
apt upgrade -y

# Note that the symlinks mentioned above are required to build an LFS system using the instructions contained within this book. Symlinks that point to other software (such as dash, mawk, etc.) may work, but are not tested or supported by the LFS development team, and may require either deviation from the instructions or additional patches to some packages.
rm /bin/sh
ln -sv bash /bin/sh

# https://www.linuxfromscratch.org/lfs/view/11.0/chapter02/hostreqs.html
# Your host system should have the following software with the minimum versions indicated. This should not be an issue for most modern Linux distributions
apt install -y binutils bison gcc g++ make texinfo

# Creating Patitions Needed for The LFS system
# I used another hard drive seperated from the host hard drive for this operations mounted as => /dev/sdb
# https://www.linuxfromscratch.org/lfs/view/11.0/chapter02/creatingpartition.html
echo y | mkfs -v -t ext4 /dev/sdb
fdisk /dev/sdb << EOF
n
p


+200M
n
p


+2G
n
e



n

+2G
n

+5G
n

+5G
n

+2G
n

+5G
n


p
w
EOF
mkswap /dev/sdb2
echo y | mkfs -v -t ext2 /dev/sdb1
echo y | mkfs -v -t ext4 /dev/sdb5
echo y | mkfs -v -t ext4 /dev/sdb6
echo y | mkfs -v -t ext4 /dev/sdb7
echo y | mkfs -v -t ext4 /dev/sdb8
echo y | mkfs -v -t ext4 /dev/sdb9
echo y | mkfs -v -t ext4 /dev/sdb10

# Setting The $LFS Variable
echo "export LFS=/mnt/lfs" > /etc/profile.d/00-lfs-env.sh
source /etc/profile.d/00-lfs-env.sh
echo $LFS

# Mounting the new partitions
cat >> /etc/fstab << EOF
/dev/sdb2	none	swap	sw	0	0
/dev/sdb10	/mnt/lfs	ext4	defaults	0	2
/dev/sdb1	/mnt/lfs/boot	ext2	defaults	0	2
/dev/sdb5	/mnt/lfs/home	ext4	defaults	0	2
/dev/sdb6	/mnt/lfs/usr	ext4	defaults	0	2
/dev/sdb7	/mnt/lfs/opt	ext4	defaults	0	2
/dev/sdb8	/mnt/lfs/tmp	ext4	defaults	0	2
/dev/sdb9	/mnt/lfs/usr/src	ext4	defaults	0	2
EOF

mkdir -pv $LFS
mkdir -pv $LFS/boot
mkdir -pv $LFS/home
mkdir -pv $LFS/usr
mkdir -pv $LFS/opt
mkdir -pv $LFS/tmp
mkdir -pv $LFS/usr/src

mount -a

# Creating sources folders where downloaded packages will be stored
mkdir -v $LFS/sources

# Make this directory writable and sticky. “Sticky” means that even if multiple users have write permission on a directory, only the owner of a file can delete the file within a sticky directory
chmod -v a+wt $LFS/sources

# Download all of the packages and patches by using wget-list
cd ~ && wget https://raw.githubusercontent.com/oulhafiane/1337-42-ft_linux/main/wget-list
wget --input-file=wget-list --continue --directory-prefix=$LFS/sources
pushd $LFS/sources
  md5sum -c md5sums
popd

# Creating a limited directory layout in LFS filesystem
mkdir -pv $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}

for i in bin lib sbin; do
  ln -sv usr/$i $LFS/$i
done

case $(uname -m) in
  x86_64) mkdir -pv $LFS/lib64 ;;
esac

mkdir -pv $LFS/tools

# Adding the lfs USER, and grant lfs full access to all directories under $LFS
# When logged in as user root, making a single mistake can damage or destroy a system. Therefore, the packages in the next two chapters are built as an unprivileged user. You could use your own user name, but to make it easier to set up a clean working environment, create a new user called lfs as a member of a new group (also named lfs) and use this user during the installation process.
groupadd lfs
useradd -s /bin/bash -g lfs -m -k /dev/null lfs
passwd lfs << EOF
$LFS_PASSWD
$LFS_PASSWD
EOF
chown -v lfs $LFS/{usr{,/*},lib,var,etc,bin,sbin,tools}
case $(uname -m) in
  x86_64) chown -v lfs $LFS/lib64 ;;
esac
chown -v lfs $LFS/sources

# Login now as lfs user
# The “-” instructs su to start a login shell as opposed to a non-login shell.
su - lfs

# Setting Up The Environment
# When logged on as user lfs, the initial shell is usually a login shell which reads the /etc/profile of the host (probably containing some settings and environment variables) and then .bash_profile. The exec env -i.../bin/bash command in the .bash_profile file replaces the running shell with a new one with a completely empty environment, except for the HOME, TERM, and PS1 variables. This ensures that no unwanted and potentially hazardous environment variables from the host system leak into the build environment. The technique used here achieves the goal of ensuring a clean environment.
cat > ~/.bash_profile << EOF
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

# The new instance of the shell is a non-login shell, which does not read, and execute, the contents of /etc/profile or .bash_profile files, but rather reads, and executes, the .bashrc file instead. Create the .bashrc file now:
# For more informations : https://www.linuxfromscratch.org/lfs/view/11.0/chapter04/settingenvironment.html
cat > ~/.bashrc << EOF
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
export MAKEFLAGS='-j$CORES'
EOF

logout
su - lfs

## Compiling a Cross-Toolchain

# Binutils - PASS 1
# https://www.linuxfromscratch.org/lfs/view/11.0/chapter05/binutils-pass1.html
cd $LFS/sources
tar -xf binutils-2.37.tar.xz
cd binutils-2.37
mkdir -v build
cd       build
../configure --prefix=$LFS/tools \
             --with-sysroot=$LFS \
             --target=$LFS_TGT   \
             --disable-nls       \
             --disable-werror
make
make install -j1
cd $LFS/sources
rm -Rf binutils-2.37

# GCC-11.2.0 - PASS 1
# https://www.linuxfromscratch.org/lfs/view/11.0/chapter05/gcc-pass1.html
# GCC requires the GMP, MPFR and MPC packages. As these packages may not be included in your host distribution, they will be built with GCC. Unpack each package into the GCC source directory and rename the resulting directories so the GCC build procedures will automatically use them
cd $LFS/sources
tar -xf gcc-11.2.0.tar.xz
cd gcc-11.2.0
tar -xf ../mpfr-4.1.0.tar.xz
mv -v mpfr-4.1.0 mpfr
tar -xf ../gmp-6.2.1.tar.xz
mv -v gmp-6.2.1 gmp
tar -xf ../mpc-1.2.1.tar.gz
mv -v mpc-1.2.1 mpc
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
 ;;
esac
mkdir -v build
cd       build
../configure                                       \
    --target=$LFS_TGT                              \
    --prefix=$LFS/tools                            \
    --with-glibc-version=2.11                      \
    --with-sysroot=$LFS                            \
    --with-newlib                                  \
    --without-headers                              \
    --enable-initfini-array                        \
    --disable-nls                                  \
    --disable-shared                               \
    --disable-multilib                             \
    --disable-decimal-float                        \
    --disable-threads                              \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx                            \
    --enable-languages=c,c++
