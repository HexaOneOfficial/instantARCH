#!/bin/bash

# This is run as root by instantautostart
# on the actual installation after the first reboot

cd /root/instantARCH

bash ./lang/xorg.sh
sleep 1
bash ./lang/locale.sh
