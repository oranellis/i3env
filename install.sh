#!/bin/bash

printf "
####################
# System installer #
####################\n\n"

if [ $UID -ne 0 ]; then
	printf "Script must be run as root\n\n"
	exit 1
fi
if [ -n "$SUDO_COMMAND" ]; then
	printf "Script must be run as root and not with sudo\n\n"
	exit 1
fi

echo 'Enter Username: '
read username
echo 'Enter password: '
read -s password
echo ; read -p 'Perform auto grub install? ' -n 1 -r grubconfirm
if [[ $grubconfirm =~ ^[Yy]$ ]]; then
echo ; read -p 'Setup device as removable? ' -n 1 -r removable
else
removable="n"
fi
printf "\n\n\n"

dir=$(pwd)
scriptdir=$(dirname $0)

pacman -Sy archlinux-keyring
pacstrap $dir base linux linux-firmware
ln -sf $dir/usr/share/zoneinfo/Europe/London $dir/etc/localtime
genfstab -U $dir >> $dir/etc/fstab
echo 'oDesktop-i3' >> $dir/etc/hostname
sed -i -e's/#en_US.UTF-8/en_US.UTF-8/g' $dir/etc/locale.gen
sed -i -e's/#en_GB.UTF-8/en_GB.UTF-8/g' $dir/etc/locale.gen
sed -i -e's/#ja_JP.UTF-8/ja_JP.UTF-8/g' $dir/etc/locale.gen
cp -r "$(dirname $scriptdir)" "$dir"

printf "\n\nChrooting into target device...\n\n"
arch-chroot $dir /bin/bash <<EOT
sourcedir="/linextras"
source $sourcedir/archi3/pkgs

locale-gen
echo "[multilib]" >> /etc/pacman.conf
echo "Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
pacman -Sy archlinux-keyring && pacman -Su

useradd -m -G wheel $username
echo "root:$password" | chpasswd
echo "$username:$password" | chpasswd

pacman -S --noconfirm --needed $reqpkgs $pkgs
! test /bin/sudo && break

sed -i -e's/# %wheel ALL=(ALL:ALL) NOPASSWD/%wheel ALL=(ALL:ALL) NOPASSWD/g' $dir/etc/sudoers
localectl set-x11-keymap gb
timedatectl set-timezone GB

chown -R $username:$username $sourcedir
cp -f $sourcedir/configs/* /root
cp -rf $sourcedir/scripts/* /usr/local/bin

sudo -u $username -H bash -c "
mkdir -p /home/$username/Dev /home/$username/Downloads /home/$username/Media/Backgrounds
cp -r $sourcedir/configs/.[^.]* /home/$username
cp $sourcedir/archi3/assets/bg2.png /home/$username/Media/Backgrounds

$sourcedir/archi3/scripts/aurinstall $reqpkgsaur
"

systemctl enable $services
systemctl enable --user $servicesuser

if [[ $grubconfirm =~ ^[Yy]$ ]]; then
	rootdev=$(echo $(findmnt --output source --noheadings -T . ) | sed "s/[p]\?[1-9]$//")
	efidevice=$(lsblk -o PATH,PARTTYPENAME $rootdev | sed -n 's/[ ]*EFI System//p')
	echo "Installing bootloader to device: $efidevice"
	mkdir -p /boot/efi
	mount $efidevice /boot/efi

	if [[ $removable =~ ^[Yy]$ ]]; then
		bash -c "grub-install --removable --boot-directory=/boot --efi-directory=/boot/efi --themes=starlight"
	else
		bash -c "grub-install --bootloader-id=\"Archi3\" --boot-directory=/boot --efi-directory=/boot/efi --themes=starlight"
	fi

	sed -i'' -e'/GRUB_TIMEOUT=.*/d' -e'/GRUB_DISTRIBUTOR=.*/d' -e'/GRUB_CMDLINE_LINUX_DEFAULT=.*/d' -e'/GRUB_TIMEOUT_STYLE=.*/d' /etc/default/grub
	printf "GRUB_TIMEOUT=0\nGRUB_DISTRIBUTOR=\"Archi3\"\nGRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 nomodeset\"\nGRUB_TIMEOUT_STYLE=hidden" >> /etc/default/grub
	grub-mkconfig -o /boot/grub/grub.cfg

	umount $efidevice
fi
EOT
