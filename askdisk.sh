#!/bin/bash

#########################################################
## Allow manual partitioning when installing instantOS ##
## Supports editing partitions and using existing ones ##
#########################################################

# todo: warning and confirmation messages

source /root/instantARCH/askutils.sh

# first displayed menu
startchoice() {
    STARTCHOICE="$(echo 'edit partitions
choose partitions' | imenu -l)"

    case "$STARTCHOICE" in
    edit*)
        editparts
        ;;
    choose*)
        chooseparts
        ;;
    esac
}

# cfdisk wrapper to modify partition table during installation
editparts() {
    echo 'instantOS requires the following paritions: 
 - a root partition, all data on it will be erased
 - an optional home partition.
    If not specified, the same partition as root will be used. 
    Gives you the option to keep existing data on the partition
 - an optional swap partition. 
    If not specified a swap file will be used. 
The Bootloader requires

 - an EFI partition on uefi systems
 - a disk to install it to on legacy-bios systems
' | imenu -M

    EDITDISK="$(fdisk -l | grep -i '^Disk /.*:' | imenu -l 'choose disk to edit> ' | grep -o '/dev/[^:]*')"
    echo "editing disk $EDITDISK"
    if guimode; then
        if command -v st; then
            st -e bash -c "cfdisk $EDITDISK"
        elif command -v st; then
            st -e bash -c "cfdisk $EDITDISK"
        else
            xterm -e bash -c "cfdisk $EDITDISK"
        fi
    else
        cfdisk "$EDITDISK"
    fi

    iroot disk "$EDITDISK"
    startchoice
}

# choose all partitions
chooseparts() {
    chooseroot
    choosehome
    chooseswap
    choosegrub
}

# menu that allows choosing a partition and put it in stdout
choosepart() {
    unset RETURNPART
    while [ -z "$RETURNPART" ]; do
        fdisk -l | grep '^/dev' | sed 's/\*/ b /g' | imenu -l "$1" | grep -o '^[^ ]*' >/tmp/diskchoice
        RETURNPART="$(cat /tmp/diskchoice)"
        if ! [ -e "$RETURNPART" ]; then
            imenu -m "$RETURNPART does not exist" &>/dev/null
            unset RETURNPART
        fi

        for i in /root/instantARCH/config/part*; do
            if grep "^$RETURNPART$" "$i"; then
                echo "partition $RETURNPART already taken"
                imenu -m "partition $RETURNPART is already selected for $i"
                CANCELOPTION="$(echo '> alternative options
select another partition
cancel partition selection' | imenu -l ' ')"
                if grep -q 'cancel' <<<"$CANCELOPTION"; then
                    touch /tmp/loopaskdisk
                    rm /tmp/homecancel
                    iroot r manualpartitioning
                    exit 1
                fi
                unset RETURNPART
            fi
        done

    done
    echo "$RETURNPART"
}

# choose home partition, allow using existing content or reformatting
choosehome() {
    if ! imenu -c "do you want to use a seperate home partition?"; then
        return
    fi


    HOMEPART="$(choosepart 'choose home partition >')"
    case "$(echo 'keep current home data
erase partition to start fresh' | imenu -l)" in
    keep*)
        echo "keeping data"

        if imenu -c "do not overwrite dotfiles? ( warning, this can impact functionality )"
        then
            iroot keepdotfiles 1
        fi

        ;;
    erase*)
        echo "erasing"
        iroot erasehome 1
        ;;
    esac
    iroot parthome "$HOMEPART"
    echo "$HOMEPART" >/root/instantARCH/config/parthome

}

# choose swap partition or swap file
chooseswap() {
    case "$(echo 'use a swap file
use a swap partition' | imenu -l)" in

    *file)
        echo "using a swap file"
        ;;
    *partition)
        echo "using a swap partition"
        while [ -z "$SWAPCONFIRM" ]; do
            PARTSWAP="$(choosepart 'choose swap partition> ')"
            if imenu -c "This will erase all data on that partition. It should also be on a fast drive. Continue?"; then
                SWAPCONFIRM="true"
                echo "$PARTSWAP will be used as swap"
                echo "$PARTSWAP" | iroot i partswap
            fi
        done
        ;;
    esac

}

# choose root partition for programs etc
chooseroot() {
    while [ -z "$ROOTCONFIRM" ]; do
        PARTROOT="$(choosepart 'choose root partition (required) ')"
        if imenu -c "This will erase all data on that partition. Continue?"; then
            ROOTCONFIRM="true"
            echo "instantOS will be installed on $PARTROOT"
        fi
        echo "$PARTROOT" | iroot i partroot
    done
}

# choose wether to install grub and where to install it
choosegrub() {

    while [ -z "$BOOTLOADERCONFIRM" ]; do
        if ! imenu -c "install bootloader (grub) ? (recommended)"; then
            if imenu -c "are you sure? This could make the system unbootable. "; then
                iroot nobootloader 1
                return
            fi
        else
            BOOTLOADERCONFIRM="true"
        fi
    done

    if efibootmgr; then

        while [ -z "$EFICONFIRM" ]; do
            choosepart 'select efi partition' | iroot i partefi
            if echo "This will format $(iroot partefi)
In most cases it *only* contains the bootloader
Operating systems that are already installed will remain bootable" | imenu -C; then
                EFICONFIRM="true"
            else
                rm /root/instantARCH/config/partefi
            fi
        done

    else
        GRUBDISK=$(fdisk -l | grep -i '^Disk /.*:' | imenu -l "select disk for grub " | grep -o '/dev/[^:]*')
        echo "$GRUBDISK"
        iroot grubdisk "$GRUBDISK"
    fi
}

startchoice
iroot manualpartitioning 1
