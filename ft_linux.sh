#!/bin/bash
# FT_LINUX/LFS script made by zoulhafi Tested on UBUNTU SERVER 20.04.3 LTS
# Source : https://www.linuxfromscratch.org/lfs/view/11.0/

sudo su -

apt update
apt upgrade -y

# Note that the symlinks mentioned above are required to build an LFS system using the instructions contained within this book. Symlinks that point to other software (such as dash, mawk, etc.) may work, but are not tested or supported by the LFS development team, and may require either deviation from the instructions or additional patches to some packages.
rm /bin/sh
ln -sv bash /bin/sh

# https://www.linuxfromscratch.org/lfs/view/stable/chapter02/hostreqs.html
# Your host system should have the following software with the minimum versions indicated. This should not be an issue for most modern Linux distributions
apt install -y binutils
apt install -y bison
apt install -y gcc
apt install -y g++
apt install -y make
apt install -y texinfo

# Creating Patitions Needed for The LFS system
# I used another hard drive seperated from the host hard drive for this operations mounted as => /dev/sdb
# https://www.linuxfromscratch.org/lfs/view/stable/chapter02/creatingpartition.html
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

+8G
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
logout
sudo su -
echo $LFS

#Mounting the new partitions
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

mount -a

#Creating sources folders where downloaded packages will be stored
mkdir -v $LFS/sources

#Make this directory writable and sticky. “Sticky” means that even if multiple users have write permission on a directory, only the owner of a file can delete the file within a sticky directory
chmod -v a+wt $LFS/sources

#download all of the packages and patches by using wget-list
cd ~ && wget https://www.linuxfromscratch.org/lfs/view/stable/wget-list
wget --input-file=wget-list --continue --directory-prefix=$LFS/sources
