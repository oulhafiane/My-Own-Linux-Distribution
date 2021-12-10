#!/bin/bash
# FT_LINUX/LFS script made by zoulhafi Tested on UBUNTU SERVER 20.04.3 LTS
# Source : https://www.linuxfromscratch.org/lfs/view/11.0/

apt update

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
p



w
EOF
mkswap /dev/sdb2
echo y | mkfs -v -t ext2 /dev/sdb1
echo y | mkfs -v -t ext4 /dev/sdb3

# Setting The $LFS Variable
echo "export LFS=/mnt/lfs" > /etc/profile.d/00-lfs-env.sh
source /etc/profile.d/00-lfs-env.sh
echo $LFS

# Mounting the new partitions
cat >> /etc/fstab << EOF
/dev/sdb2	none	swap	sw	0	0
/dev/sdb3	/mnt/lfs	ext4	defaults	0	2
/dev/sdb1	/mnt/lfs/boot	ext2	defaults	0	2
EOF

/sbin/swapon -v /dev/sdb2
mkdir -pv $LFS
mount -v -t ext4 /dev/sdb3 $LFS
mkdir -v $LFS/boot
mount -v -t ext2 /dev/sdb1 $LFS/boot
mkdir -v $LFS/home
mkdir -v $LFS/usr
mkdir -v $LFS/opt
mkdir -v $LFS/tmp
mkdir -v $LFS/usr/src

# Creating sources folders where downloaded packages will be stored
mkdir -v $LFS/sources

# Make this directory writable and sticky. “Sticky” means that even if multiple users have write permission on a directory, only the owner of a file can delete the file within a sticky directory
chmod -v a+wt $LFS/sources

# Download all of the packages and patches by using wget-list
#cd ~ && wget https://raw.githubusercontent.com/oulhafiane/1337-42-ft_linux/main/wget-list
#wget --input-file=wget-list --continue --directory-prefix=$LFS/sources 2&> /dev/null
cp -rv /tmp/sources/* $LFS/sources/
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
chown -v lfs $LFS/{usr{,/*},lib,var,etc,bin,sbin,tools}
case $(uname -m) in
  x86_64) chown -v lfs $LFS/lib64 ;;
esac
chown -v lfs $LFS/sources
mkdir /home/lfs/.ssh
cp ~/.ssh/authorized_keys /home/lfs/.ssh/authorized_keys
chown -v lfs /home/lfs/.ssh/authorized_keys
cp ~/ft_linux2.sh /home/lfs/ft_linux2.sh
chmod +r /home/lfs/ft_linux2.sh
su - lfs

# Setting Up The Environment

cat > ~/.bashrc << "EOF"
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
EOF
