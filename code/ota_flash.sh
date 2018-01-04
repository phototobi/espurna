#!/bin/bash

ip=
board=
size=
auth=
flags=

export boards=()
ips=""

exists() {
    command -v "$1" >/dev/null 2>&1
}

echo_pad() {
    string=$1
    pad=$2
    printf '%s' "$string"
    printf '%*s' $(( $pad - ${#string} ))
}

useAvahi() {

    echo_pad "#" 4
    echo_pad "HOSTNAME" 25
    echo_pad "IP" 25
    echo_pad "APP" 15
    echo_pad "VERSION" 15
    echo_pad "DEVICE" 30
    echo_pad "MEM_SIZE" 10
    echo_pad "SDK_SIZE" 10
    echo

    printf -v line '%*s\n' 134
    echo ${line// /-}

    counter=0

    ip_file="/tmp/espurna.flash.ips"
    board_file="/tmp/espurna.flash.boards"
    count_file="/tmp/espurna.flash.count"
    size_file="/tmp/espurna.flash.size"
    echo -n "" > $ip_file
    echo -n "" > $board_file
    echo -n "" > $size_file
    echo -n "$counter" > $count_file

    avahi-browse -t -r -p  "_arduino._tcp" 2>/dev/null | grep ^= | sort -t ';' -k 3 | while read line; do

        (( counter++ ))
        echo "$counter" > $count_file

        hostname=`echo $line | cut -d ';' -f4`
        ip=`echo $line | cut -d ';' -f8`
        txt=`echo $line | cut -d ';' -f10`
        app_name=`echo $txt | sed -n "s/.*app_name=\([^\"]*\).*/\1/p"`
        app_version=`echo $txt | sed -n "s/.*app_version=\([^\"]*\).*/\1/p"`
        board=`echo $txt | sed -n "s/.*target_board=\([^\"]*\).*/\1/p"`
        mem_size=`echo $txt | sed -n "s/.*mem_size=\([^\"]*\).*/\1/p"`
        sdk_size=`echo $txt | sed -n "s/.*sdk_size=\([^\"]*\).*/\1/p"`

        echo_pad "$counter" 4
        echo_pad "$hostname" 25
        echo_pad "http://$ip" 25
        echo_pad "$app_name" 15
        echo_pad "$app_version" 15
        echo_pad "$board" 30
        echo_pad "$mem_size" 10
        echo_pad "$sdk_size" 10
        echo

        echo -n "$ip;" >> $ip_file
        echo -n "$board;" >> $board_file
        if [ "$mem_size" == "$sdk_size" ]; then
            mem_size=`echo $mem_size | head -c 1`
            echo -n "$mem_size;" >> $size_file
        else
            echo -n ";" >> $size_file
        fi

    done

    echo
    read -p "Choose the board you want to flash (empty if none of these): " num

    # None of these
    if [ "$num" == "" ]; then
        return
    fi

    # Check boundaries
    counter=`cat $count_file`
    if [ $num -lt 1 ] || [ $num -gt $counter ]; then
        echo "Board number must be between 1 and $counter"
        exit 1
    fi

    # Fill the fields
    ip=`cat $ip_file | cut -d ';' -f$num`
    board=`cat $board_file | cut -d ';' -f$num`
    size=`cat $size_file | cut -d ';' -f$num`

}

getBoard() {

    boards=(`cat espurna/config/hardware.h | grep "defined" | sed "s/.*(\(.*\)).*/\1/" | sort`)

    echo_pad "#" 4
    echo_pad "DEVICE" 30
    echo

    printf -v line '%*s\n' 34
    echo ${line// /-}

    counter=0
    for board in "${boards[@]}"; do
        (( counter++ ))
        echo_pad "$counter" 4
        echo_pad "$board" 30
        echo
    done

    echo
    read -p "Choose the board you want to flash (empty if none of these): " num

    # None of these
    if [ "$num" == "" ]; then
        return
    fi

    # Check boundaries
    counter=${#boards[*]}
    if [ $num -lt 1 ] || [ $num -gt $counter ]; then
        echo "Board code must be between 1 and $counter"
        exit 1
    fi

    # Fill the fields
    (( num -- ))
    board=${boards[$num]}

}

# ------------------------------------------------------------------------------

# Welcome
echo
echo "--------------------------------------------------------------"
echo "ESPURNA FIRMWARE OTA FLASHER"

# Get current version
version=`cat espurna/config/version.h | grep APP_VERSION | awk '{print $3}' | sed 's/"//g'`
echo "Building for version $version"

echo "--------------------------------------------------------------"
echo

if exists avahi-browse; then
    useAvahi
fi

if [ "$board" == "" ]; then
    getBoard
fi

if [ "$board" == "" ]; then
    read -p "Board type of the device to flash: " -e -i "NODEMCU_LOLIN" board
fi

if [ "$board" == "" ]; then
    echo "You must define the board type"
    exit 2
fi

if [ "$size" == "" ]; then
    read -p "Board memory size (1 for 1M, 4 for 4M): " -e size
fi

if [ "$size" == "" ]; then
    echo "You must define the board memory size"
    exit 2
fi

if [ "$ip" == "" ]; then
    read -p "IP of the device to flash: " -e -i 192.168.4.1 ip
fi

if [ "$ip" == "" ]; then
    echo "You must define the IP of the device"
    exit 2
fi

if [ "$auth" == "" ]; then
    read -p "Authorization key of the device to flash: " auth
fi

if [ "$flags" == "" ]; then
    read -p "Extra flags for the build: " -e -i "" flags
fi

env="esp8266-${size}m-ota"

echo
echo "ESPURNA_IP    = $ip"
echo "ESPURNA_BOARD = $board"
echo "ESPURNA_AUTH  = $auth"
echo "ESPURNA_FLAGS = $flags"
echo "ESPURNA_ENV   = $env"

echo
echo -n "Are these values corrent [y/N]: "
read response

if [ "$response" != "y" ]; then
    exit
fi

export ESPURNA_IP=$ip
export ESPURNA_BOARD=$board
export ESPURNA_AUTH=$auth
export ESPURNA_FLAGS=$flags

platformio run --silent --environment $env -t upload
