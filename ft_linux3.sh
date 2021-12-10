## Entering Chroot and Building Additional Temporary Tools

ROOT_PASSWORD=ftLinux145236

source /etc/profile.d/00-lfs-env.sh

# Changing Ownership
# Currently, the whole directory hierarchy in $LFS is owned by the user lfs, a user that exists only on the host system. If the directories and files under $LFS are kept as they are, they will be owned by a user ID without a corresponding account. This is dangerous because a user account created later could get this same user ID and would own all the files under $LFS, thus exposing these files to possible malicious manipulation.
chown -R root:root $LFS/{usr,lib,var,etc,bin,sbin,tools}
case $(uname -m) in
  x86_64) chown -R root:root $LFS/lib64 ;;
esac

# Preparing Virtual Kernel File Systems
# https://www.linuxfromscratch.org/lfs/view/11.0/chapter07/kernfs.html
mkdir -pv $LFS/{dev,proc,sys,run}
mknod -m 600 $LFS/dev/console c 5 1
mknod -m 666 $LFS/dev/null c 1 3
mount -v --bind /dev $LFS/dev
mount -v --bind /dev/pts $LFS/dev/pts
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run
if [ -h $LFS/dev/shm ]; then
  mkdir -pv $LFS/$(readlink $LFS/dev/shm)
fi

# Entering the Chroot Environment
# Now that all the packages which are required to build the rest of the needed tools are on the system, it is time to enter the chroot environment to finish installing the remaining temporary tools. This environment will be in use also for installing the final system. As user root, run the following command to enter the environment that is, at the moment, populated with only the temporary tools
chroot "$LFS" /usr/bin/env -i   \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin     \
    /bin/bash --login +h

# Creating Directories
# It is time to create the full structure in the LFS file system.
# Create some root-level directories that are not in the limited set required in the previous chapters
# The directory tree is based on the Filesystem Hierarchy Standard (FHS) (available at https://refspecs.linuxfoundation.org/fhs.shtml).
mkdir -pv /{boot,home,mnt,opt,srv}
mkdir -pv /etc/{opt,sysconfig}
mkdir -pv /lib/firmware
mkdir -pv /media/{floppy,cdrom}
mkdir -pv /usr/{,local/}{include,src}
mkdir -pv /usr/local/{bin,lib,sbin}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv /usr/{,local/}share/man/man{1..8}
mkdir -pv /var/{cache,local,log,mail,opt,spool}
mkdir -pv /var/lib/{color,misc,locate}

ln -sfv /run /var/run
ln -sfv /run/lock /var/lock

install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp

# Creating Essential Files and Symlinks
# https://www.linuxfromscratch.org/lfs/view/11.0/chapter07/createfiles.html
ln -sv /proc/self/mounts /etc/mtab
cat > /etc/hosts << EOF
127.0.0.1  localhost $(hostname)
::1        localhost
EOF
cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF
cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
wheel:x:97:
nogroup:x:99:
users:x:999:
EOF
echo "tester:x:101:101::/home/tester:/bin/bash" >> /etc/passwd
echo "tester:x:101:" >> /etc/group
install -o tester -d /home/tester
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp

# Libstdc++ from GCC-11.2.0, Pass 2
# When building gcc-pass2 we had to defer the installation of the C++ standard library because no suitable compiler was available to compile it. We could not use the compiler built in that section because it is a native compiler and should not be used outside of chroot and risks polluting the libraries with some host components.

cd /sources
tar -xf gcc-11.2.0.tar.xz
cd gcc-11.2.0
ln -s gthr-posix.h libgcc/gthr-default.h
mkdir -v build
cd build
../libstdc++-v3/configure            \
    CXXFLAGS="-g -O2 -D_GNU_SOURCE"  \
    --prefix=/usr                    \
    --disable-multilib               \
    --disable-nls                    \
    --host=$(uname -m)-lfs-linux-gnu \
    --disable-libstdcxx-pch
make
make install
cd /sources
rm -Rf gcc-11.2.0

# Gettext-0.21
# The Gettext package contains utilities for internationalization and localization. These allow programs to be compiled with NLS (Native Language Support), enabling them to output messages in the user's native language.
tar -xf gettext-0.21.tar.xz
cd gettext-0.21
./configure --disable-shared
make
cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
cd /sources
rm -Rf gettext-0.21

# Bison-3.7.6
# The Bison package contains a parser generator.
tar -xf bison-3.7.6.tar.xz
cd bison-3.7.6
./configure --prefix=/usr \
            --docdir=/usr/share/doc/bison-3.7.6
make
make install
cd /sources
rm -Rf bison-3.7.6

# Perl-5.34.0
# The Perl package contains the Practical Extraction and Report Language.
tar -xf perl-5.34.0.tar.xz
cd perl-5.34.0
sh Configure -des                                        \
             -Dprefix=/usr                               \
             -Dvendorprefix=/usr                         \
             -Dprivlib=/usr/lib/perl5/5.34/core_perl     \
             -Darchlib=/usr/lib/perl5/5.34/core_perl     \
             -Dsitelib=/usr/lib/perl5/5.34/site_perl     \
             -Dsitearch=/usr/lib/perl5/5.34/site_perl    \
             -Dvendorlib=/usr/lib/perl5/5.34/vendor_perl \
             -Dvendorarch=/usr/lib/perl5/5.34/vendor_perl
make
make install
cd /sources
rm -Rf perl-5.34.0

# Python-3.9.6
# The Python 3 package contains the Python development environment. It is useful for object-oriented programming, writing scripts, prototyping large programs, or developing entire applications.
tar -xf Python-3.9.6.tar.xz
cd Python-3.9.6
./configure --prefix=/usr   \
            --enable-shared \
            --without-ensurepip
make
make install
cd /sources
rm -Rf Python-3.9.6

# Texinfo-6.8
# The Texinfo package contains programs for reading, writing, and converting info pages.
tar -xf texinfo-6.8.tar.xz
cd texinfo-6.8
sed -e 's/__attribute_nonnull__/__nonnull/' \
    -i gnulib/lib/malloc/dynarray-skeleton.c
./configure --prefix=/usr
make
make install
cd /sources
rm -Rf texinfo-6.8

# Util-linux-2.37.2
# The Util-linux package contains miscellaneous utility programs.
tar -xf util-linux-2.37.2.tar.xz
cd util-linux-2.37.2
mkdir -pv /var/lib/hwclock
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime    \
            --libdir=/usr/lib    \
            --docdir=/usr/share/doc/util-linux-2.37.2 \
            --disable-chfn-chsh  \
            --disable-login      \
            --disable-nologin    \
            --disable-su         \
            --disable-setpriv    \
            --disable-runuser    \
            --disable-pylibmount \
            --disable-static     \
            --without-python     \
            runstatedir=/run
make
make install
cd /sources
rm -Rf util-linux-2.37.2

# Cleaning up and Saving the Temporary System
# https://www.linuxfromscratch.org/lfs/view/11.0/chapter07/cleanup.html
rm -rf /usr/share/{info,man,doc}/*
find /usr/{lib,libexec} -name \*.la -delete
rm -rf /tools

# Man-pages-5.13
# The Man-pages package contains over 2,200 man pages.
tar -xf man-pages-5.13.tar.xz
cd man-pages-5.13
make prefix=/usr install
cd /sources
rm -Rf man-pages-5.13

# Iana-Etc-20210611
# The Iana-Etc package provides data for network services and protocols.
tar -xf iana-etc-20210611.tar.gz
cd iana-etc-20210611
cp services protocols /etc
cd /sources
rm -Rf iana-etc-20210611

# Glibc-2.34
# The Glibc package contains the main C library. This library provides the basic routines for allocating memory, searching directories, opening and closing files, reading and writing files, string handling, pattern matching, arithmetic, and so on.
# https://www.linuxfromscratch.org/lfs/view/11.0/chapter08/glibc.html
tar -xf glibc-2.34.tar.xz
cd glibc-2.34
sed -e '/NOTIFY_REMOVED)/s/)/ \&\& data.attr != NULL)/' \
    -i sysdeps/unix/sysv/linux/mq_notify.c
patch -Np1 -i ../glibc-2.34-fhs-1.patch
mkdir -v build
cd build
echo "rootsbindir=/usr/sbin" > configparms
../configure --prefix=/usr                            \
             --disable-werror                         \
             --enable-kernel=3.2                      \
             --enable-stack-protector=strong          \
             --with-headers=/usr/include              \
             libc_cv_slibdir=/usr/lib
make
touch /etc/ld.so.conf
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
make install
sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd
cp -v ../nscd/nscd.conf /etc/nscd.conf
mkdir -pv /var/cache/nscd
mkdir -pv /usr/lib/locale
localedef -i POSIX -f UTF-8 C.UTF-8 2> /dev/null || true
localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
localedef -i de_DE -f ISO-8859-1 de_DE
localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
localedef -i de_DE -f UTF-8 de_DE.UTF-8
localedef -i el_GR -f ISO-8859-7 el_GR
localedef -i en_GB -f ISO-8859-1 en_GB
localedef -i en_GB -f UTF-8 en_GB.UTF-8
localedef -i en_HK -f ISO-8859-1 en_HK
localedef -i en_PH -f ISO-8859-1 en_PH
localedef -i en_US -f ISO-8859-1 en_US
localedef -i en_US -f UTF-8 en_US.UTF-8
localedef -i es_ES -f ISO-8859-15 es_ES@euro
localedef -i es_MX -f ISO-8859-1 es_MX
localedef -i fa_IR -f UTF-8 fa_IR
localedef -i fr_FR -f ISO-8859-1 fr_FR
localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
localedef -i is_IS -f ISO-8859-1 is_IS
localedef -i is_IS -f UTF-8 is_IS.UTF-8
localedef -i it_IT -f ISO-8859-1 it_IT
localedef -i it_IT -f ISO-8859-15 it_IT@euro
localedef -i it_IT -f UTF-8 it_IT.UTF-8
localedef -i ja_JP -f EUC-JP ja_JP
localedef -i ja_JP -f SHIFT_JIS ja_JP.SIJS 2> /dev/null || true
localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
localedef -i nl_NL@euro -f ISO-8859-15 nl_NL@euro
localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
localedef -i se_NO -f UTF-8 se_NO.UTF-8
localedef -i ta_IN -f UTF-8 ta_IN.UTF-8
localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
localedef -i zh_CN -f GB18030 zh_CN.GB18030
localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
localedef -i zh_TW -f UTF-8 zh_TW.UTF-8
cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF
tar -xf ../../tzdata2021a.tar.gz

ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}

for tz in etcetera southamerica northamerica europe africa antarctica  \
          asia australasia backward; do
    zic -L /dev/null   -d $ZONEINFO       ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix ${tz}
    zic -L leapseconds -d $ZONEINFO/right ${tz}
done

cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
unset ZONEINFO
ln -sfv /usr/share/zoneinfo/Africa/Casablanca /etc/localtime
cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF
cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
mkdir -pv /etc/ld.so.conf.d
cd /sources
rm -Rf glibc-2.34

# Zlib-1.2.11
# The Zlib package contains compression and decompression routines used by some programs.
tar -xf zlib-1.2.11.tar.xz
cd zlib-1.2.11
./configure --prefix=/usr
make
make install
rm -fv /usr/lib/libz.a
cd /sources
rm -Rf zlib-1.2.11

# Bzip2-1.0.8
# The Bzip2 package contains programs for compressing and decompressing files. Compressing text files with bzip2 yields a much better compression percentage than with the traditional gzip.
tar -xf bzip2-1.0.8.tar.gz
cd bzip2-1.0.8
patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
make -f Makefile-libbz2_so
make clean
make
make PREFIX=/usr install
cp -av libbz2.so.* /usr/lib
ln -sv libbz2.so.1.0.8 /usr/lib/libbz2.so
cp -v bzip2-shared /usr/bin/bzip2
for i in /usr/bin/{bzcat,bunzip2}; do
  ln -sfv bzip2 $i
done
rm -fv /usr/lib/libbz2.a
cd /sources
rm -Rf bzip2-1.0.8

# Xz-5.2.5
# The Xz package contains programs for compressing and decompressing files. It provides capabilities for the lzma and the newer xz compression formats. Compressing text files with xz yields a better compression percentage than with the traditional gzip or bzip2 commands.
tar -xf xz-5.2.5.tar.xz
cd xz-5.2.5
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/xz-5.2.5
make
make install
cd /sources
rm -Rf xz-5.2.5

# Zstd-1.5.0
# Zstandard is a real-time compression algorithm, providing high compression ratios. It offers a very wide range of compression / speed trade-offs, while being backed by a very fast decoder.
tar -xf zstd-1.5.0.tar.gz
cd zstd-1.5.0
make
make prefix=/usr install
rm -v /usr/lib/libzstd.a
cd /sources
rm -Rf zstd-1.5.0

# File-5.40
# The File package contains a utility for determining the type of a given file or files.
tar -xf file-5.40.tar.gz
cd file-5.40
./configure --prefix=/usr
make
make install
cd /sources
rm -Rf file-5.40

# Readline-8.1
# The Readline package is a set of libraries that offers command-line editing and history capabilities.
tar -xf readline-8.1.tar.gz
cd readline-8.1
sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install
./configure --prefix=/usr    \
            --disable-static \
            --with-curses    \
            --docdir=/usr/share/doc/readline-8.1
make SHLIB_LIBS="-lncursesw"
make SHLIB_LIBS="-lncursesw" install
install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.1
cd /sources
rm -Rf readline-8.1

# M4-1.4.19
# The M4 package contains a macro processor.
tar -xf m4-1.4.19.tar.xz
cd m4-1.4.19
./configure --prefix=/usr
make
make install
cd /sources
rm -Rf m4-1.4.19

# Bc-5.0.0
# The Bc package contains an arbitrary precision numeric processing language.
tar -xf bc-5.0.0.tar.xz
cd bc-5.0.0
CC=gcc ./configure --prefix=/usr -G -O3
make
make install
cd /sources
rm -Rf bc-5.0.0

# Flex-2.6.4
# The Flex package contains a utility for generating programs that recognize patterns in text.
tar -xf flex-2.6.4.tar.gz
cd flex-2.6.4
./configure --prefix=/usr \
            --docdir=/usr/share/doc/flex-2.6.4 \
            --disable-static
make
make install
ln -sv flex /usr/bin/lex
cd /sources
rm -Rf flex-2.6.4

# Tcl-8.6.11
# The Tcl package contains the Tool Command Language, a robust general-purpose scripting language. The Expect package is written in the Tcl language.
tar -xf tcl8.6.11-src.tar.gz
cd tcl8.6.11
tar -xf ../tcl8.6.11-html.tar.gz --strip-components=1
SRCDIR=$(pwd)
cd unix
./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            $([ "$(uname -m)" = x86_64 ] && echo --enable-64bit)
make

sed -e "s|$SRCDIR/unix|/usr/lib|" \
    -e "s|$SRCDIR|/usr/include|"  \
    -i tclConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.2|/usr/lib/tdbc1.1.2|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.2/generic|/usr/include|"    \
    -e "s|$SRCDIR/pkgs/tdbc1.1.2/library|/usr/lib/tcl8.6|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.2|/usr/include|"            \
    -i pkgs/tdbc1.1.2/tdbcConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/itcl4.2.1|/usr/lib/itcl4.2.1|" \
    -e "s|$SRCDIR/pkgs/itcl4.2.1/generic|/usr/include|"    \
    -e "s|$SRCDIR/pkgs/itcl4.2.1|/usr/include|"            \
    -i pkgs/itcl4.2.1/itclConfig.sh

unset SRCDIR
make install
chmod -v u+w /usr/lib/libtcl8.6.so
make install-private-headers
ln -sfv tclsh8.6 /usr/bin/tclsh
mv /usr/share/man/man3/{Thread,Tcl_Thread}.3
mkdir -v -p /usr/share/doc/tcl-8.6.11
cp -v -r ../html/* /usr/share/doc/tcl-8.6.11
cd /sources
rm -Rf tcl8.6.11

# Expect-5.45.4
# The Expect package contains tools for automating, via scripted dialogues, interactive applications such as telnet, ftp, passwd, fsck, rlogin, and tip. Expect is also useful for testing these same applications as well as easing all sorts of tasks that are prohibitively difficult with anything else. The DejaGnu framework is written in Expect.
tar -xf expect5.45.4.tar.gz
cd expect5.45.4
./configure --prefix=/usr           \
            --with-tcl=/usr/lib     \
            --enable-shared         \
            --mandir=/usr/share/man \
            --with-tclinclude=/usr/include
make
make install
ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib
cd /sources
rm -Rf expect5.45.4

# DejaGNU-1.6.3
# The DejaGnu package contains a framework for running test suites on GNU tools. It is written in expect, which itself uses Tcl (Tool Command Language).
tar -xf dejagnu-1.6.3.tar.gz
cd dejagnu-1.6.3
mkdir -v build
cd build
../configure --prefix=/usr
makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
makeinfo --plaintext       -o doc/dejagnu.txt  ../doc/dejagnu.texi
make install
install -v -dm755  /usr/share/doc/dejagnu-1.6.3
install -v -m644   doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-1.6.3
cd /sources
rm -Rf dejagnu-1.6.3

# Binutils-2.37
# The Binutils package contains a linker, an assembler, and other tools for handling object files.
tar -xf binutils-2.37.tar.xz
cd binutils-2.37
patch -Np1 -i ../binutils-2.37-upstream_fix-1.patch
sed -i '63d' etc/texi2pod.pl
find -name \*.1 -delete
mkdir -v build
cd build
../configure --prefix=/usr       \
             --enable-gold       \
             --enable-ld=default \
             --enable-plugins    \
             --enable-shared     \
             --disable-werror    \
             --enable-64-bit-bfd \
             --with-system-zlib
make tooldir=/usr
make tooldir=/usr install -j1
rm -fv /usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes}.a
cd /sources
rm -Rf binutils-2.37

# GMP-6.2.1
# The GMP package contains math libraries. These have useful functions for arbitrary precision arithmetic.
tar -xf gmp-6.2.1.tar.xz
cd gmp-6.2.1
cp -v configfsf.guess config.guess
cp -v configfsf.sub   config.sub
./configure --prefix=/usr    \
            --enable-cxx     \
            --disable-static \
            --docdir=/usr/share/doc/gmp-6.2.1
make
make html
make install
make install-html
cd /sources
rm -Rf gmp-6.2.1

# MPFR-4.1.0
# The MPFR package contains functions for multiple precision math.
tar -xf mpfr-4.1.0.tar.xz
cd mpfr-4.1.0
./configure --prefix=/usr        \
            --disable-static     \
            --enable-thread-safe \
            --docdir=/usr/share/doc/mpfr-4.1.0
make
make html
make install
make install-html
cd /sources
rm -Rf mpfr-4.1.0

# MPC-1.2.1
# The MPC package contains a library for the arithmetic of complex numbers with arbitrarily high precision and correct rounding of the result.
tar -xf mpc-1.2.1.tar.gz
cd mpc-1.2.1
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/mpc-1.2.1
make
make html
make install
make install-html
cd /sources
rm -Rf mpc-1.2.1

# Attr-2.5.1
# The attr package contains utilities to administer the extended attributes on filesystem objects.
tar -xf attr-2.5.1.tar.gz
cd attr-2.5.1
./configure --prefix=/usr     \
            --disable-static  \
            --sysconfdir=/etc \
            --docdir=/usr/share/doc/attr-2.5.1
make
make install
cd /sources
rm -Rf attr-2.5.1

# Acl-2.3.1
# The Acl package contains utilities to administer Access Control Lists, which are used to define more fine-grained discretionary access rights for files and directories.
tar -xf acl-2.3.1.tar.xz
cd acl-2.3.1
./configure --prefix=/usr         \
            --disable-static      \
            --docdir=/usr/share/doc/acl-2.3.1
make
make install
cd /sources
rm -Rf acl-2.3.1

# Libcap-2.53
# The Libcap package implements the user-space interfaces to the POSIX 1003.1e capabilities available in Linux kernels. These capabilities are a partitioning of the all powerful root privilege into a set of distinct privileges.
tar -xf libcap-2.53.tar.xz
cd libcap-2.53
sed -i '/install -m.*STA/d' libcap/Makefile
make prefix=/usr lib=lib
make prefix=/usr lib=lib install
chmod -v 755 /usr/lib/lib{cap,psx}.so.2.53
cd /sources
rm -Rf libcap-2.53

# Shadow-4.9
# The Shadow package contains programs for handling passwords in a secure way.
tar -xf shadow-4.9.tar.xz
cd shadow-4.9
sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD SHA512:' \
    -e 's:/var/spool/mail:/var/mail:'                 \
    -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                \
    -i etc/login.defs
sed -i 's:DICTPATH.*:DICTPATH\t/lib/cracklib/pw_dict:' etc/login.defs
sed -e "224s/rounds/min_rounds/" -i libmisc/salt.c
touch /usr/bin/passwd
./configure --sysconfdir=/etc \
            --with-group-name-max-length=32
make
make exec_prefix=/usr install
make -C man install-man
mkdir -p /etc/default
useradd -D --gid 999
pwconv
grpconv
sed -i 's/yes/no/' /etc/default/useradd
passwd root << EOF
$ROOT_PASSWORD
$ROOT_PASSWORD
EOF
cd /sources
rm -Rf shadow-4.9

# GCC-11.2.0
# The GCC package contains the GNU compiler collection, which includes the C and C++ compilers.
tar -xf gcc-11.2.0.tar.xz
cd gcc-11.2.0
sed -e '/static.*SIGSTKSZ/d' \
    -e 's/return kAltStackSize/return SIGSTKSZ * 4/' \
    -i libsanitizer/sanitizer_common/sanitizer_posix_libcdep.cpp
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac
mkdir -v build
cd build
../configure --prefix=/usr            \
             LD=ld                    \
             --enable-languages=c,c++ \
             --disable-multilib       \
             --disable-bootstrap      \
             --with-system-zlib
make
make install
rm -rf /usr/lib/gcc/$(gcc -dumpmachine)/11.2.0/include-fixed/bits/
chown -v -R root:root \
    /usr/lib/gcc/*linux-gnu/11.2.0/include{,-fixed}
ln -svr /usr/bin/cpp /usr/lib
ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/11.2.0/liblto_plugin.so \
        /usr/lib/bfd-plugins/
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
cd /sources
rm -Rf gcc-11.2.0

# Pkg-config-0.29.2
# The pkg-config package contains a tool for passing the include path and/or library paths to build tools during the configure and make phases of package installations.
tar -xf pkg-config-0.29.2.tar.gz
cd pkg-config-0.29.2
./configure --prefix=/usr              \
            --with-internal-glib       \
            --disable-host-tool        \
            --docdir=/usr/share/doc/pkg-config-0.29.2
make
make install
cd /sources
rm -Rf pkg-config-0.29.2

# Ncurses-6.2
# The Ncurses package contains libraries for terminal-independent handling of character screens.
tar -xf ncurses-6.2.tar.gz
cd ncurses-6.2
./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --with-shared           \
            --without-debug         \
            --without-normal        \
            --enable-pc-files       \
            --enable-widec
make
make install
for lib in ncurses form panel menu ; do
    rm -vf                    /usr/lib/lib${lib}.so
    echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc        /usr/lib/pkgconfig/${lib}.pc
done
rm -vf                     /usr/lib/libcursesw.so
echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
ln -sfv libncurses.so      /usr/lib/libcurses.so
rm -fv /usr/lib/libncurses++w.a
mkdir -v       /usr/share/doc/ncurses-6.2
cp -v -R doc/* /usr/share/doc/ncurses-6.2
cd /sources
rm -Rf ncurses-6.2

# Sed-4.8
# The Sed package contains a stream editor.
tar -xf sed-4.8.tar.xz
cd sed-4.8
./configure --prefix=/usr
make
make html
make install
install -d -m755           /usr/share/doc/sed-4.8
install -m644 doc/sed.html /usr/share/doc/sed-4.8
cd /sources
rm -Rf sed-4.8

# Psmisc-23.4
# The Psmisc package contains programs for displaying information about running processes.
tar -xf psmisc-23.4.tar.xz
cd psmisc-23.4
./configure --prefix=/usr
make
make install
cd /sources
rm -Rf psmisc-23.4

# Gettext-0.21
# The Gettext package contains utilities for internationalization and localization. These allow programs to be compiled with NLS (Native Language Support), enabling them to output messages in the user's native language.
tar -xf gettext-0.21.tar.xz
cd gettext-0.21
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/gettext-0.21
make
make install
chmod -v 0755 /usr/lib/preloadable_libintl.so
cd /sources
rm -Rf gettext-0.21

# Bison-3.7.6
# The Bison package contains a parser generator.
tar -xf bison-3.7.6.tar.xz
cd bison-3.7.6
./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.7.6
make
make install
cd /sources
rm -Rf bison-3.7.6

# Grep-3.7
# The Grep package contains programs for searching through the contents of files.
tar -xf grep-3.7.tar.xz
cd grep-3.7
./configure --prefix=/usr
make
make install
cd /sources
rm -Rf grep-3.7

# Bash-5.1.8
# The Bash package contains the Bourne-Again SHell.
tar -xf bash-5.1.8.tar.gz
cd bash-5.1.8
./configure --prefix=/usr                      \
            --docdir=/usr/share/doc/bash-5.1.8 \
            --without-bash-malloc              \
            --with-installed-readline
make
make install
cd /sources
rm -Rf bash-5.1.8

# Libtool-2.4.6
# The Libtool package contains the GNU generic library support script. It wraps the complexity of using shared libraries in a consistent, portable interface.
tar -xf libtool-2.4.6.tar.xz
cd libtool-2.4.6
./configure --prefix=/usr
make
make install
rm -fv /usr/lib/libltdl.a
cd /sources
rm -Rf libtool-2.4.6

# GDBM-1.20
# The GDBM package contains the GNU Database Manager. It is a library of database functions that use extensible hashing and works similar to the standard UNIX dbm. The library provides primitives for storing key/data pairs, searching and retrieving the data by its key and deleting a key along with its data.
tar -xf gdbm-1.20.tar.gz
cd gdbm-1.20
./configure --prefix=/usr    \
            --disable-static \
            --enable-libgdbm-compat
make
make install
cd /sources
rm -Rf gdbm-1.20

# Gperf-3.1
# Gperf generates a perfect hash function from a key set.
tar -xf gperf-3.1.tar.gz
cd gperf-3.1
./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1
make
make install
cd /sources
rm -Rf gperf-3.1

# Expat-2.4.1
# The Expat package contains a stream oriented C library for parsing XML.
tar -xf expat-2.4.1.tar.xz
cd expat-2.4.1
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/expat-2.4.1
make
make install
install -v -m644 doc/*.{html,png,css} /usr/share/doc/expat-2.4.1
cd /sources
rm -Rf expat-2.4.1

# Inetutils-2.1
# The Inetutils package contains programs for basic networking.
tar -xf inetutils-2.1.tar.xz
cd inetutils-2.1
./configure --prefix=/usr        \
            --bindir=/usr/bin    \
            --localstatedir=/var \
            --disable-logger     \
            --disable-whois      \
            --disable-rcp        \
            --disable-rexec      \
            --disable-rlogin     \
            --disable-rsh        \
            --disable-servers
make
make install
mv -v /usr/{,s}bin/ifconfig
cd /sources
rm -Rf inetutils-2.1

# Less-590
# The Less package contains a text file viewer.
tar -xf less-590.tar.gz
cd less-590
./configure --prefix=/usr --sysconfdir=/etc
make
make install
cd /sources
rm -Rf less-590

# Perl-5.34.0
# The Perl package contains the Practical Extraction and Report Language.
tar -xf perl-5.34.0.tar.xz
cd perl-5.34.0
patch -Np1 -i ../perl-5.34.0-upstream_fixes-1.patch
export BUILD_ZLIB=False
export BUILD_BZIP2=0
sh Configure -des                                         \
             -Dprefix=/usr                                \
             -Dvendorprefix=/usr                          \
             -Dprivlib=/usr/lib/perl5/5.34/core_perl      \
             -Darchlib=/usr/lib/perl5/5.34/core_perl      \
             -Dsitelib=/usr/lib/perl5/5.34/site_perl      \
             -Dsitearch=/usr/lib/perl5/5.34/site_perl     \
             -Dvendorlib=/usr/lib/perl5/5.34/vendor_perl  \
             -Dvendorarch=/usr/lib/perl5/5.34/vendor_perl \
             -Dman1dir=/usr/share/man/man1                \
             -Dman3dir=/usr/share/man/man3                \
             -Dpager="/usr/bin/less -isR"                 \
             -Duseshrplib                                 \
             -Dusethreads
make
make install
unset BUILD_ZLIB BUILD_BZIP2
cd /sources
rm -Rf perl-5.34.0

# XML::Parser-2.46
# The XML::Parser module is a Perl interface to James Clark's XML parser, Expat.
tar -xf XML-Parser-2.46.tar.gz
cd XML-Parser-2.46
perl Makefile.PL
make
make install
cd /sources
rm -Rf XML-Parser-2.46

# Intltool-0.51.0
# The Intltool is an internationalization tool used for extracting translatable strings from source files.
tar -xf intltool-0.51.0.tar.gz
cd intltool-0.51.0
sed -i 's:\\\${:\\\$\\{:' intltool-update.in
./configure --prefix=/usr
make
make install
install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
cd /sources
rm -Rf intltool-0.51.0

# Autoconf-2.71
# The Autoconf package contains programs for producing shell scripts that can automatically configure source code.
tar -xf autoconf-2.71.tar.xz
cd autoconf-2.71
./configure --prefix=/usr
make
make install
cd /sources
rm -Rf autoconf-2.71

# Automake-1.16.4
# The Automake package contains programs for generating Makefiles for use with Autoconf.
tar -xf automake-1.16.4.tar.xz
cd automake-1.16.4
./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.16.4
make
make install
cd /sources
rm -Rf automake-1.16.4

# Kmod-29
# The Kmod package contains libraries and utilities for loading kernel modules
tar -xf kmod-29.tar.xz
cd kmod-29
./configure --prefix=/usr          \
            --sysconfdir=/etc      \
            --with-xz              \
            --with-zstd            \
            --with-zlib
make
make install

for target in depmod insmod modinfo modprobe rmmod; do
  ln -sfv ../bin/kmod /usr/sbin/$target
done

ln -sfv kmod /usr/bin/lsmod
cd /sources
rm -Rf kmod-29

# Libelf from Elfutils-0.185
# Libelf is a library for handling ELF (Executable and Linkable Format) files.
tar -xf elfutils-0.185.tar.bz2
cd elfutils-0.185
./configure --prefix=/usr                \
            --disable-debuginfod         \
            --enable-libdebuginfod=dummy
make
make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig
rm /usr/lib/libelf.a
cd /sources
rm -Rf elfutils-0.185

# Libffi-3.4.2
# The Libffi library provides a portable, high level programming interface to various calling conventions. This allows a programmer to call any function specified by a call interface description at run time.
tar -xf libffi-3.4.2.tar.gz
cd libffi-3.4.2
./configure --prefix=/usr          \
            --disable-static       \
            --with-gcc-arch=native \
            --disable-exec-static-tramp
make
make install
cd /sources
rm -Rf libffi-3.4.2

# OpenSSL-1.1.1l
# The OpenSSL package contains management tools and libraries relating to cryptography. These are useful for providing cryptographic functions to other packages, such as OpenSSH, email applications, and web browsers (for accessing HTTPS sites).
tar -xf openssl-1.1.1l.tar.gz
cd openssl-1.1.1l
./config --prefix=/usr         \
         --openssldir=/etc/ssl \
         --libdir=lib          \
         shared                \
         zlib-dynamic
make
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install
mv -v /usr/share/doc/openssl /usr/share/doc/openssl-1.1.1l
cp -vfr doc/* /usr/share/doc/openssl-1.1.1l
cd /sources
rm -Rf openssl-1.1.1l

# Python-3.9.6
# The Python 3 package contains the Python development environment. It is useful for object-oriented programming, writing scripts, prototyping large programs, or developing entire applications.
tar -xf Python-3.9.6.tar.xz
cd Python-3.9.6
./configure --prefix=/usr        \
            --enable-shared      \
            --with-system-expat  \
            --with-system-ffi    \
            --with-ensurepip=yes \
            --enable-optimizations
make
make install
install -v -dm755 /usr/share/doc/python-3.9.6/html
tar --strip-components=1  \
    --no-same-owner       \
    --no-same-permissions \
    -C /usr/share/doc/python-3.9.6/html \
    -xvf ../python-3.9.6-docs-html.tar.bz2
cd /sources
rm -Rf Python-3.9.6

# Ninja-1.10.2
# Ninja is a small build system with a focus on speed.
tar -xf ninja-1.10.2.tar.gz
cd ninja-1.10.2
export NINJAJOBS=4
sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc
python3 configure.py --bootstrap
install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja
cd /sources
rm -Rf ninja-1.10.2

# Meson-0.59.1
# Meson is an open source build system meant to be both extremely fast and as user friendly as possible.
tar -xf meson-0.59.1.tar.gz
cd meson-0.59.1
python3 setup.py build
python3 setup.py install --root=dest
cp -rv dest/* /
install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
cd /sources
rm -Rf meson-0.59.1

# Coreutils-8.32
# The Coreutils package contains utilities for showing and setting the basic system characteristics.
tar -xf coreutils-8.32.tar.xz
cd coreutils-8.32
patch -Np1 -i ../coreutils-8.32-i18n-1.patch
autoreconf -fiv
FORCE_UNSAFE_CONFIGURE=1 ./configure \
            --prefix=/usr            \
            --enable-no-install-program=kill,uptime
make
make install
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
cd /sources
rm -Rf coreutils-8.32

# Check-0.15.2
# Check is a unit testing framework for C.
tar -xf check-0.15.2.tar.gz
cd check-0.15.2
./configure --prefix=/usr --disable-static
make
make docdir=/usr/share/doc/check-0.15.2 install
cd /sources
rm -Rf check-0.15.2

# Diffutils-3.8
# The Diffutils package contains programs that show the differences between files or directories.
tar -xf diffutils-3.8.tar.xz
cd diffutils-3.8
./configure --prefix=/usr
make
make install
cd /sources
rm -Rf diffutils-3.8

# Gawk-5.1.0
# The Gawk package contains programs for manipulating text files.
tar -xf gawk-5.1.0.tar.xz
cd gawk-5.1.0
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr
make
make install
mkdir -v /usr/share/doc/gawk-5.1.0
cp    -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-5.1.0
cd /sources
rm -Rf gawk-5.1.0

# Findutils-4.8.0
# The Findutils package contains programs to find files. These programs are provided to recursively search through a directory tree and to create, maintain, and search a database (often faster than the recursive find, but is unreliable if the database has not been recently updated).
tar -xf findutils-4.8.0.tar.xz
cd findutils-4.8.0
./configure --prefix=/usr --localstatedir=/var/lib/locate
make
make install
cd /sources
rm -Rf findutils-4.8.0

# Groff-1.22.4
# The Groff package contains programs for processing and formatting text.
tar -xf groff-1.22.4.tar.gz
cd groff-1.22.4
PAGE=A4 ./configure --prefix=/usr
make -j1
make install
cd /sources
rm -Rf groff-1.22.4

# GRUB-2.06
# The GRUB package contains the GRand Unified Bootloader.
tar -xf grub-2.06.tar.xz
cd grub-2.06
./configure --prefix=/usr          \
            --sysconfdir=/etc      \
            --disable-efiemu       \
            --disable-werror
make
make install
mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions
cd /sources
rm -Rf grub-2.06

# Gzip-1.10
# The Gzip package contains programs for compressing and decompressing files.
tar -xf gzip-1.10.tar.xz
cd gzip-1.10
./configure --prefix=/usr
make
make install
cd /sources
rm -Rf gzip-1.10

# IPRoute2-5.13.0
# The IPRoute2 package contains programs for basic and advanced IPV4-based networking.
tar -xf iproute2-5.13.0.tar.xz
cd iproute2-5.13.0
sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8
sed -i 's/.m_ipt.o//' tc/Makefile
make
make SBINDIR=/usr/sbin install
mkdir -v              /usr/share/doc/iproute2-5.13.0
cp -v COPYING README* /usr/share/doc/iproute2-5.13.0
cd /sources
rm -Rf iproute2-5.13.0

# Kbd-2.4.0
# The Kbd package contains key-table files, console fonts, and keyboard utilities.
tar -xf kbd-2.4.0.tar.xz
cd kbd-2.4.0
patch -Np1 -i ../kbd-2.4.0-backspace-1.patch
sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
./configure --prefix=/usr --disable-vlock
make
make install
mkdir -v            /usr/share/doc/kbd-2.4.0
cp -R -v docs/doc/* /usr/share/doc/kbd-2.4.0
cd /sources
rm -Rf kbd-2.4.0

# Libpipeline-1.5.3
# The Libpipeline package contains a library for manipulating pipelines of subprocesses in a flexible and convenient way.
tar -xf libpipeline-1.5.3.tar.gz
cd libpipeline-1.5.3
./configure --prefix=/usr
make
make install
cd /sources
rm -Rf libpipeline-1.5.3

# Make-4.3
# The Make package contains a program for controlling the generation of executables and other non-source files of a package from source files.
tar -xf make-4.3.tar.gz
cd make-4.3
./configure --prefix=/usr
make
make install
cd /sources
rm -Rf make-4.3

# Patch-2.7.6
# The Patch package contains a program for modifying or creating files by applying a “patch” file typically created by the diff program.
tar -xf patch-2.7.6.tar.xz
cd patch-2.7.6
./configure --prefix=/usr
make
make install
cd /sources
rm -Rf patch-2.7.6

# Tar-1.34
# The Tar package provides the ability to create tar archives as well as perform various other kinds of archive manipulation. Tar can be used on previously created archives to extract files, to store additional files, or to update or list files which were already stored.
tar -xf tar-1.34.tar.xz
cd tar-1.34
FORCE_UNSAFE_CONFIGURE=1  \
./configure --prefix=/usr
make
make install
make -C doc install-html docdir=/usr/share/doc/tar-1.34
cd /sources
rm -Rf tar-1.34

# Texinfo-6.8
# The Texinfo package contains programs for reading, writing, and converting info pages.
tar -xf texinfo-6.8.tar.xz
cd texinfo-6.8
./configure --prefix=/usr
sed -e 's/__attribute_nonnull__/__nonnull/' \
    -i gnulib/lib/malloc/dynarray-skeleton.c
make
make install
make TEXMF=/usr/share/texmf install-tex
pushd /usr/share/info
  rm -v dir
  for f in *
    do install-info $f dir 2>/dev/null
  done
popd
cd /sources
rm -Rf texinfo-6.8

# Vim-8.2.3337
# The Vim package contains a powerful text editor.
tar -xf vim-8.2.3337.tar.gz
cd vim-8.2.3337
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
./configure --prefix=/usr
make
make install
ln -sv vim /usr/bin/vi
for L in  /usr/share/man/{,*/}man1/vim.1; do
    ln -sv vim.1 $(dirname $L)/vi.1
done
ln -sv ../vim/vim82/doc /usr/share/doc/vim-8.2.3337
cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF
cd /sources
rm -Rf vim-8.2.3337

# Eudev-3.2.10
# The Eudev package contains programs for dynamic creation of device nodes.
tar -xf eudev-3.2.10.tar.gz
cd eudev-3.2.10
./configure --prefix=/usr           \
            --bindir=/usr/sbin      \
            --sysconfdir=/etc       \
            --enable-manpages       \
            --disable-static
make
mkdir -pv /usr/lib/udev/rules.d
mkdir -pv /etc/udev/rules.d
make install
tar -xvf ../udev-lfs-20171102.tar.xz
make -f udev-lfs-20171102/Makefile.lfs install
udevadm hwdb --update
cd /sources
rm -Rf eudev-3.2.10

# Man-DB-2.9.4
# The Man-DB package contains programs for finding and viewing man pages.
tar -xf man-db-2.9.4.tar.xz
cd man-db-2.9.4
./configure --prefix=/usr                        \
            --docdir=/usr/share/doc/man-db-2.9.4 \
            --sysconfdir=/etc                    \
            --disable-setuid                     \
            --enable-cache-owner=bin             \
            --with-browser=/usr/bin/lynx         \
            --with-vgrind=/usr/bin/vgrind        \
            --with-grap=/usr/bin/grap            \
            --with-systemdtmpfilesdir=           \
            --with-systemdsystemunitdir=
make
make install
cd /sources
rm -Rf man-db-2.9.4

# Procps-ng-3.3.17
# The Procps-ng package contains programs for monitoring processes.
tar -xf procps-ng-3.3.17.tar.xz
cd procps-3.3.17/
./configure --prefix=/usr                            \
            --docdir=/usr/share/doc/procps-ng-3.3.17 \
            --disable-static                         \
            --disable-kill
make
make install
cd /sources
rm -Rf procps-3.3.17/

# Util-linux-2.37.2
# The Util-linux package contains miscellaneous utility programs. Among them are utilities for handling file systems, consoles, partitions, and messages.
tar -xf util-linux-2.37.2.tar.xz
cd util-linux-2.37.2
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime   \
            --libdir=/usr/lib    \
            --docdir=/usr/share/doc/util-linux-2.37.2 \
            --disable-chfn-chsh  \
            --disable-login      \
            --disable-nologin    \
            --disable-su         \
            --disable-setpriv    \
            --disable-runuser    \
            --disable-pylibmount \
            --disable-static     \
            --without-python     \
            --without-systemd    \
            --without-systemdsystemunitdir \
            runstatedir=/run
make
make install
cd /sources
rm -Rf util-linux-2.37.2

# E2fsprogs-1.46.4
# The e2fsprogs package contains the utilities for handling the ext2 file system. It also supports the ext3 and ext4 journaling file systems.
tar -xf e2fsprogs-1.46.4.tar.gz
cd e2fsprogs-1.46.4
mkdir -v build
cd build
../configure --prefix=/usr           \
             --sysconfdir=/etc       \
             --enable-elf-shlibs     \
             --disable-libblkid      \
             --disable-libuuid       \
             --disable-uuidd         \
             --disable-fsck
make
make install
rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
gunzip -v /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo
install -v -m644 doc/com_err.info /usr/share/info
install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
cd /sources
rm -Rf e2fsprogs-1.46.4

# Sysklogd-1.5.1
# The sysklogd package contains programs for logging system messages, such as those given by the kernel when unusual things happen.
tar -xf sysklogd-1.5.1.tar.gz
cd sysklogd-1.5.1
sed -i '/Error loading kernel symbols/{n;n;d}' ksym_mod.c
sed -i 's/union wait/int/' syslogd.c
make
make BINDIR=/sbin install
cat > /etc/syslog.conf << "EOF"
# Begin /etc/syslog.conf

auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *

# End /etc/syslog.conf
EOF
cd /sources
rm -Rf sysklogd-1.5.1

# Sysvinit-2.99
# The Sysvinit package contains programs for controlling the startup, running, and shutdown of the system.
tar -xf sysvinit-2.99.tar.xz
cd sysvinit-2.99
patch -Np1 -i ../sysvinit-2.99-consolidated-1.patch
make
make install
cd /sources
rm -Rf sysvinit-2.99

# libtasn1-4.17.0
# libtasn1 is a highly portable C library that encodes and decodes DER/BER data following an ASN.1 schema.
tar -xf libtasn1-4.17.0.tar.gz
cd libtasn1-4.17.0
./configure --prefix=/usr --disable-static &&
make
make install
make -C doc/reference install-data-local
cd /sources
rm -Rf libtasn1-4.17.0

# p11-kit-0.24.0
# The p11-kit package provides a way to load and enumerate PKCS #11 (a Cryptographic Token Interface Standard) modules.
tar -xf p11-kit-0.24.0.tar.xz
cd p11-kit-0.24.0
sed '20,$ d' -i trust/trust-extract-compat &&
cat >> trust/trust-extract-compat << "EOF"
# Copy existing anchor modifications to /etc/ssl/local
/usr/libexec/make-ca/copy-trust-modifications

# Generate a new trust store
/usr/sbin/make-ca -f -g
EOF
mkdir p11-build &&
cd    p11-build &&

meson --prefix=/usr       \
      --buildtype=release \
      -Dtrust_paths=/etc/pki/anchors &&
ninja
ninja install &&
ln -sfv /usr/libexec/p11-kit/trust-extract-compat \
        /usr/bin/update-ca-certificates
ln -sfv ./pkcs11/p11-kit-trust.so /usr/lib/libnssckbi.so
cd /sources
rm -Rf p11-kit-0.24.0

# make-ca-1.7
# Public Key Infrastructure (PKI) is a method to validate the authenticity of an otherwise unknown entity across untrusted networks. PKI works by establishing a chain of trust, rather than trusting each individual host or entity explicitly. In order for a certificate presented by a remote entity to be trusted, that certificate must present a complete chain of certificates that can be validated using the root certificate of a Certificate Authority (CA) that is trusted by the local machine.
# Establishing trust with a CA involves validating things like company address, ownership, contact information, etc., and ensuring that the CA has followed best practices, such as undergoing periodic security audits by independent investigators and maintaining an always available certificate revocation list. This is well outside the scope of BLFS (as it is for most Linux distributions).
tar -xf make-ca-1.7.tar.xz
cd make-ca-1.7
make install &&
install -vdm755 /etc/ssl/local
/usr/sbin/make-ca -g --force
cd /sources
rm -Rf make-ca-1.7

# Wget-1.21.1
# The Wget package contains a utility useful for non-interactive downloading of files from the Web.
tar -xf wget-1.21.1.tar.gz
cd wget-1.21.1
./configure --prefix=/usr      \
            --sysconfdir=/etc  \
            --with-ssl=openssl &&
make
make install
cd /sources
rm -Rf wget-1.21.1

# OpenSSH-8.7p1
# The OpenSSH package contains ssh clients and the sshd daemon. This is useful for encrypting authentication and subsequent traffic over a network. The ssh and scp commands are secure implementations of telnet and rcp respectively.
tar -xf openssh-8.7p1.tar.gz
cd openssh-8.7p1
install  -v -m700 -d /var/lib/sshd &&
chown    -v root:sys /var/lib/sshd &&

groupadd -g 50 sshd        &&
useradd  -c 'sshd PrivSep' \
         -d /var/lib/sshd  \
         -g sshd           \
         -s /bin/false     \
         -u 50 sshd
./configure --prefix=/usr                            \
            --sysconfdir=/etc/ssh                    \
            --with-md5-passwords                     \
            --with-privsep-path=/var/lib/sshd        \
            --with-default-path=/usr/bin             \
            --with-superuser-path=/usr/sbin:/usr/bin \
            --with-pid-dir=/run
make
make install &&
install -v -m755    contrib/ssh-copy-id /usr/bin     &&

install -v -m644    contrib/ssh-copy-id.1 \
                    /usr/share/man/man1              &&
install -v -m755 -d /usr/share/doc/openssh-8.7p1     &&
install -v -m644    INSTALL LICENCE OVERVIEW README* \
                    /usr/share/doc/openssh-8.7p1
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
cd /sources
rm -Rf openssh-8.7p1
tar -xf blfs-bootscripts-20210826.tar.xz
cd blfs-bootscripts-20210826
make install-sshd
cd /sources
rm -Rf blfs-bootscripts-20210826

# Cleaning Up
rm -rf /tmp/*
find /usr/lib /usr/libexec -name \*.la -delete
find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rf
userdel -r tester

# LFS-Bootscripts-20210608
# The LFS-Bootscripts package contains a set of scripts to start/stop the LFS system at bootup/shutdown. The configuration files and procedures needed to customize the boot process are described in the following sections.
tar -xf lfs-bootscripts-20210608.tar.xz
cd lfs-bootscripts-20210608
make install
cd /sources
rm -Rf lfs-bootscripts-20210608

# Creating Custom Udev Rules
bash /usr/lib/udev/init-net-rules.sh

# Creating Network Interface Configuration Files
cd /etc/sysconfig/
cat > ifconfig.eth0 << "EOF"
ONBOOT=yes
IFACE=eth0
SERVICE=ipv4-static
IP=192.168.42.111
PREFIX=24
BROADCAST=192.168.42.255
EOF

# Creating the /etc/resolv.conf File
cat > /etc/resolv.conf << "EOF"
# Début de /etc/resolv.conf

nameserver 127.0.0.53
options edns0 trust-ad

# Fin de /etc/resolv.conf
EOF

# Configuring the system hostname
echo "<zoulhafi>" > /etc/hostname

# Customizing the /etc/hosts File
cat > /etc/hosts << "EOF"
# Begin /etc/hosts (network card version)

127.0.0.1 localhost

# End /etc/hosts (network card version)
EOF

# Configuring Sysvinit
cat > /etc/inittab << "EOF"
# Begin /etc/inittab

id:3:initdefault:

si::sysinit:/etc/rc.d/init.d/rc S

l0:0:wait:/etc/rc.d/init.d/rc 0
l1:S1:wait:/etc/rc.d/init.d/rc 1
l2:2:wait:/etc/rc.d/init.d/rc 2
l3:3:wait:/etc/rc.d/init.d/rc 3
l4:4:wait:/etc/rc.d/init.d/rc 4
l5:5:wait:/etc/rc.d/init.d/rc 5
l6:6:wait:/etc/rc.d/init.d/rc 6

ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now

su:S016:once:/sbin/sulogin

1:2345:respawn:/sbin/agetty --noclear tty1 9600
2:2345:respawn:/sbin/agetty tty2 9600
3:2345:respawn:/sbin/agetty tty3 9600
4:2345:respawn:/sbin/agetty tty4 9600
5:2345:respawn:/sbin/agetty tty5 9600
6:2345:respawn:/sbin/agetty tty6 9600

# End /etc/inittab
EOF

# Configuring the System Clock
cat > /etc/sysconfig/clock << "EOF"
# Begin /etc/sysconfig/clock

UTC=1

# Set this to any options you might need to give to hwclock,
# such as machine hardware clock type for Alphas.
CLOCKPARAMS=

# End /etc/sysconfig/clock
EOF

# Creating the /etc/inputrc File
# The inputrc file is the configuration file for the readline library, which provides editing capabilities while the user is entering a line from the terminal. It works by translating keyboard inputs into specific actions.
cat > /etc/inputrc << "EOF"
# Begin /etc/inputrc
# Modified by Chris Lynn <roryo@roryo.dynup.net>

# Allow the command prompt to wrap to the next line
set horizontal-scroll-mode Off

# Enable 8bit input
set meta-flag On
set input-meta On

# Turns off 8th bit stripping
set convert-meta Off

# Keep the 8th bit for display
set output-meta On

# none, visible or audible
set bell-style none

# All of the following map the escape sequence of the value
# contained in the 1st argument to the readline specific functions
"\eOd": backward-word
"\eOc": forward-word

# for linux console
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert

# for xterm
"\eOH": beginning-of-line
"\eOF": end-of-line

# for Konsole
"\e[H": beginning-of-line
"\e[F": end-of-line

# End /etc/inputrc
EOF

# Creating the /etc/shells File
# The shells file contains a list of login shells on the system. Applications use this file to determine whether a shell is valid. For each shell a single line should be present, consisting of the shell's path relative to the root of the directory structure (/).
cat > /etc/shells << "EOF"
# Begin /etc/shells

/bin/sh
/bin/bash

# End /etc/shells
EOF

# Creating the /etc/fstab File
cat > /etc/fstab << "EOF"
# Begin /etc/fstab

# file system  mount-point  type     options             dump  fsck
#                                                              order

/dev/sda2	swap	swap	pri=1	0	0
/dev/sda3	/	ext4	defaults	0	1
/dev/sda1	/boot	ext2	defaults	0	2
proc           /proc        proc     nosuid,noexec,nodev 0     0
sysfs          /sys         sysfs    nosuid,noexec,nodev 0     0
devpts         /dev/pts     devpts   gid=5,mode=620      0     0
tmpfs          /run         tmpfs    defaults            0     0
devtmpfs       /dev         devtmpfs mode=0755,nosuid    0     0
EOF

# Linux-5.13.12
# The Linux package contains the Linux kernel.
cd /sources/
tar -xf linux-5.13.12.tar.xz
cd linux-5.13.12
make mrproper
cp ../.config
make
make modules_install
cp -iv arch/x86/boot/bzImage /boot/vmlinuz-5.13.12-zoulhafi
cp -iv System.map /boot/System.map-5.13.12
cp -iv .config /boot/config-5.13.12
install -d /usr/share/doc/linux-5.13.12
cp -r Documentation/* /usr/share/doc/linux-5.13.12

# Configuring Linux Module Load Order
install -v -m755 -d /etc/modprobe.d
cat > /etc/modprobe.d/usb.conf << "EOF"
# Begin /etc/modprobe.d/usb.conf

install ohci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i ohci_hcd ; true
install uhci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i uhci_hcd ; true

# End /etc/modprobe.d/usb.conf
EOF

# Creating the GRUB Configuration File
dd if=/dev/zero of=/dev/sdb seek=1 count=2047
grub-install /dev/sdb
cat > /boot/grub/grub.cfg << "EOF"
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5

insmod ext2
set root=(hd0,1)

menuentry "GNU/Linux, Linux 5.13.12-zoulhafi" {
        linux   /vmlinuz-5.13.12-zoulhafi root=/dev/sda3 ro
}
EOF
