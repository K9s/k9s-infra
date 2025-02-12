#!/bin/sh

cpupower idle-set -D 11

echo "Setting IOSCHED"

modprobe bfq
hdd_scheduler='mq-deadline'
if grep -q bfq /sys/block/sd*/queue/scheduler; then
  hdd_scheduler='bfq'
else
  echo "bfq scheduler unavailable. Falling back to ${hdd_scheduler} for HDDs"
fi
echo "${hdd_scheduler} to be used for hdd devices!"

modprobe kyber-iosched
ssd_scheduler='none'
if grep -q kyber /sys/block/nvme*/queue/scheduler; then
  ssd_scheduler='kyber'
else
  echo "kyber scheduler unavailable. Falling back to ${ssd_scheduler} for SSDs"
fi
echo "${ssd_scheduler} to be used for SSDs!"

for DISK in /sys/block/nvme*; do echo ${ssd_scheduler} > "${DISK}"/queue/scheduler; done
for DISK in /sys/block/sd*; do grep -q 0 "${DISK}"/queue/rotational && echo ${ssd_scheduler} > "${DISK}"/queue/scheduler; done
for DISK in /sys/block/sd*; do grep -q 1 "${DISK}"/queue/rotational && echo ${hdd_scheduler} > "${DISK}"/queue/scheduler; done

for DISK in /sys/block/sd*; do grep -q 0 "${DISK}"/queue/rotational && (hdparm -A 1 /dev/"$(echo "$DISK" | cut -d / -f 4)"); done
for DISK in /sys/block/sd*; do grep -q 1 "${DISK}"/queue/rotational && (hdparm -A 1 -B 255 -S 0 /dev/"$(echo "$DISK" | cut -d / -f 4)"); done

echo "Configuring Queue Settings"
# https://gist.github.com/v-fox/b7adbc2414da46e2c49e571929057429

hdd_read_ahead_kb=2048

for DISK in /sys/block/md*; do
  echo $hdd_read_ahead_kb > "${DISK}"/queue/read_ahead_kb
done

for DISK in /sys/block/sd*; do
  echo $hdd_read_ahead_kb > "${DISK}"/queue/read_ahead_kb

  echo 1 > "${DISK}"/queue/add_random
  echo 1024 > "${DISK}"/queue/nr_requests
  cat "${DISK}"/queue/max_hw_sectors_kb > "${DISK}"/queue/max_sectors_kb
  echo 1 > "${DISK}"/queue/io_poll
  echo 0 > "${DISK}"/queue/io_poll_delay

  smartctl -s wcache,off /dev/$(basename $DISK)
done

for DISK in /sys/block/nvme*; do
  echo 256 > "${DISK}"/queue/read_ahead_kb

  echo 0 > "${DISK}"/queue/add_random
  echo 64 > "${DISK}"/queue/nr_requests
  cat "${DISK}"/queue/max_hw_sectors_kb > "${DISK}"/queue/max_sectors_kb
  echo 1 > "${DISK}"/queue/io_poll
  echo 0 > "${DISK}"/queue/io_poll_delay
  echo 2000 > "${DISK}"/queue/wbt_lat_usec # Default 2000
  echo 2000000 > "${DISK}"/queue/iosched/read_lat_nsec # Default 2000000
  echo 10000000 > "${DISK}"/queue/iosched/write_lat_nsec # Default 10000000
done

echo "-----------------------------------------------------------"
for DISK in /sys/block/bcache*; do
  echo 0 > ${DISK}/queue/read_ahead_kb
  echo "Processing ${DISK}...."

  echo writeback > "${DISK}"/bcache/cache_mode
#  echo writearound > "${DISK}"/bcache/cache_mode
#  echo none > "${DISK}"/bcache/cache_mode

  cat "${DISK}"/bcache/cache_mode

#  echo $(numfmt --from=iec 64M) > "${DISK}"/bcache/sequential_cutoff
  echo 0 > "${DISK}"/bcache/sequential_cutoff

  echo 40 > "${DISK}"/bcache/writeback_percent

  echo 30 > "${DISK}"/bcache/writeback_delay

  backing_drive_count=$(lsblk | grep $(cat "${DISK}/bcache/backing_dev_name") | wc -l)
  echo "... backing device count ${backing_drive_count}"

  echo $(($(numfmt --from=iec $(( 16 * backing_drive_count ))M) / 512)) > "${DISK}/bcache/writeback_rate_minimum"
#  echo 0 > "${DISK}/bcache/writeback_rate_minimum"

  echo 1 > "${DISK}"/bcache/cache/internal/gc_after_writeback
  echo lru > "${DISK}"/bcache/cache/cache0/cache_replacement_policy

  echo 0 > "${DISK}"/bcache/cache/congested_read_threshold_us
  echo 0 > "${DISK}"/bcache/cache/congested_write_threshold_us
  echo "-------------------------------"
done
echo "-----------------------------------------------------------"

ceph config set osd bluestore_cache_meta_ratio 0.10
ceph config set global client_force_lazyio true

ceph config set osd osd_memory_target $(numfmt --from=iec 4G)

/bin/bash $(dirname "$(readlink -f "$0")")/ceph-osd-mclock.sh hdd 2000
/bin/bash $(dirname "$(readlink -f "$0")")/ceph-osd-mclock.sh nvme 12000
