#!/bin/bash

touch /opt/livebuilder

useradd -m -s /bin/bash instantos
echo "instantos:instantos" | chpasswd

rgroup() {
    groupadd "$1" &>/dev/null
    sudo gpasswd -a "instantos" "$1"
}

rgroup "autologin"
rgroup "video"
rgroup "video"
rgroup "wheel"
rgroup "input"

cd
mkdir tmparch
cd tmparch

sudo pacman -Sy --noconfirm git wget
git clone --depth 1 https://github.com/instantOS/instantARCH
git clone --depth 1 https://github.com/instantOS/instantOS

bash instantARCH/depend/depend.sh
bash instantARCH/depend/system.sh
bash instantOS/repo.sh

# install instantOS packages
sudo pacman -Sy --noconfirm instantos
sudo pacman -Sy --noconfirm instantdepend
# declare as live session
sudo pacman -Sy --noconfirm liveutils

bash instantOS/rootinstall.sh

[ -e /etc/lightdm ] || mkdir -p /etc/lightdm
cat /usr/share/instantdotfiles/lightdm-gtk-greeter.conf >/etc/lightdm/lightdm-gtk-greeter.conf

# enable greeter
sed -i 's/^\[Seat:\*\]/\[Seat:\*\]\ngreeter-session=lightdm-gtk-greeter/g' /etc/lightdm.conf
# enable autologin
sed -i "s/^\[Seat:\*\]/[Seat:*]\nautologin-user=instantos/g" /etc/lightdm/lightdm.conf
# allow sudo
sed -i 's/# %wheel/%wheel/g' /etc/sudoers
# clear sudo password
echo "root ALL=(ALL) NOPASSWD:ALL #instantosroot" >>/etc/sudoers
echo "" >>/etc/sudoers

rm /opt/livebuilder