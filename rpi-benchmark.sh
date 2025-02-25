#!/bin/bash

[ "$(whoami)" == "root" ] || { echo "Must be run as sudo!"; exit 1; }

# Install dependencies
if [ ! `which hdparm` ]; then
  apt-get install -y hdparm
fi
if [ ! `which sysbench` ]; then
  apt-get install -y sysbench
fi

# Skip the speed test if the user doesn't want it to run
case $1 in
    --no-speedtest|-ns )
        echo "Skipping speed test."
        echo
        ;;
    * )
        if [ ! `which speedtest-cli` ] && [ ! `which speedtest` ]; then
          apt-get install -y speedtest-cli
        fi
        ;;
esac

# Get root disk for hdparam test
ROOTDISK=`mount | grep " on / type" | cut -f 1 -d " "`

# Script start!
clear
sync
echo -e "\e[96mRaspberry Pi Benchmark Test"
echo -e "Authors: AikonCWD, Robert McKenzie, Aaron Covrig, Emanuele Ballarin"
echo -e "Version: 3.0.3\n\e[97m"

# Show current hardware
vcgencmd measure_temp
vcgencmd get_config int | grep arm_freq
vcgencmd get_config int | grep core_freq
vcgencmd get_config int | grep sdram_freq
vcgencmd get_config int | grep gpu_freq
printf "sd_clock="
grep "actual clock" /sys/kernel/debug/mmc0/ios 2>/dev/null | awk '{printf("%0.3f MHz", $3/1000000)}'
echo -e "\n\e[93m"

# Skip the speed test if the user doesn't want it to run
case $1 in
    --no-speedtest|-ns )
        echo "Skipping speed test."
        echo
        ;;
    * )
        # Identify the installed version of speedtest
        SPEEDTEST=``
        if [ `which speedtest` ]; then
                SPEEDTEST="$(which speedtest) --progress=yes"
        elif [ `which speedtest-cli` ]; then
                SPEEDTEST="$(which speedtest-cli) --simple"
        else
                echo -e "Failed to identify installed speedtest software\e[94m"
        fi
        if [ ! -z "$SPEEDTEST" ]; then
                echo -e "Internet connection speed test will proceed with $SPEEDTEST\e[94m"
                echo -e "Running InternetSpeed test...\e[94m"
                eval $SPEEDTEST
                echo -e "\e[93m"
        fi
        ;;
esac

echo -e "Running CPU test...\e[94m"
sysbench --num-threads=4 --validate=on --cpu-max-prime=5000 cpu run | grep 'total time:\|min:\|avg:\|max:' | tr -s [:space:]
vcgencmd measure_temp
echo -e "\e[93m"

echo -e "Running THREADS test...\e[94m"
sysbench --num-threads=4 --validate=on --thread-yields=4000 --thread-locks=6 threads run | grep 'total time:\|min:\|avg:\|max:' | tr -s [:space:]
vcgencmd measure_temp
echo -e "\e[93m"

echo -e "Running MEMORY test...\e[94m"
sysbench --num-threads=4 --validate=on --memory-block-size=1K --memory-total-size=3G --memory-access-mode=seq memory run | grep 'Operations\|transferred\|total time:\|min:\|avg:\|max:' | tr -s [:space:]
vcgencmd measure_temp
echo -e "\e[93m"

echo -e "Running HDPARM test on ${ROOTDISK}...\e[94m"
hdparm -t ${ROOTDISK} | grep Timing
vcgencmd measure_temp
echo -e "\e[93m"

echo -e "Running DD WRITE test...\e[94m"
rm -f ~/test.tmp && sync && dd if=/dev/zero of=~/test.tmp bs=1M count=512 conv=fsync 2>&1 | grep -v records
vcgencmd measure_temp
echo -e "\e[93m"

echo -e "Running DD READ test...\e[94m"
echo -e 3 > /proc/sys/vm/drop_caches && sync && dd if=~/test.tmp of=/dev/null bs=1M 2>&1 | grep -v records
vcgencmd measure_temp
rm -f ~/test.tmp
echo -e "\e[0m"

echo -e "\e[91mrpi-benchmark completed!\e[0m\n"
