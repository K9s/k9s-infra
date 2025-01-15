#!/bin/sh
set -e
set -o pipefail

cpupower idle-set -D 11

#sst set -ssd 1 PowerGovernorMode=2 || true

echo "Setting IOSCHED"

modprobe bfq || true
hdd_scheduler='mq-deadline'
if grep -q bfq /sys/block/sd*/queue/scheduler; then
  hdd_scheduler='bfq'
else
  echo "bfq scheduler unavailable. Falling back to ${hdd_scheduler} for HDDs"
fi
echo "${hdd_scheduler} to be used for hdd devices!"

modprobe kyber-iosched || true
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

for DISK in /sys/block/sd*; do grep -q 0 "${DISK}"/queue/rotational && (hdparm -W 0 -A 1 /dev/"$(echo "$DISK" | cut -d / -f 4)" || true); done
for DISK in /sys/block/sd*; do grep -q 1 "${DISK}"/queue/rotational && (hdparm -B 254 -S 120 -W 0 -A 1 /dev/"$(echo "$DISK" | cut -d / -f 4)" || true); done

echo "Configuring Queue Settings"
# https://gist.github.com/v-fox/b7adbc2414da46e2c49e571929057429

for DISK in /sys/block/sd*; do
  echo 1 > "${DISK}"/queue/add_random
  echo 2048 > "${DISK}"/queue/nr_requests
  cat "${DISK}"/queue/max_hw_sectors_kb > "${DISK}"/queue/max_sectors_kb || true
  cat "${DISK}"/queue/max_hw_sectors_kb > "${DISK}"/queue/read_ahead_kb || true
  echo 1 > "${DISK}"/queue/rq_affinity
  echo 0 > "${DISK}"/queue/io_poll_delay
  echo 0 > "${DISK}"/queue/nomerges
done

for DISK in /sys/block/nvme*; do
  echo 0 > "${DISK}"/queue/add_random
  echo 8 > "${DISK}"/queue/nr_requests
  cat "${DISK}"/queue/max_hw_sectors_kb > "${DISK}"/queue/max_sectors_kb || true
  cat "${DISK}"/queue/max_hw_sectors_kb > "${DISK}"/queue/read_ahead_kb || true
  echo 1 > "${DISK}"/queue/rq_affinity
  echo 0 > "${DISK}"/queue/io_poll_delay
  echo 1 > "${DISK}"/queue/nomerges
  echo 3333 > "${DISK}"/queue/wbt_lat_usec
  echo 3333111 > "${DISK}"/queue/iosched/read_lat_nsec
  echo 333111111 > "${DISK}"/queue/iosched/write_lat_nsec
done

echo "-----------------------------------------------------------"
for DISK in /sys/block/bcache*; do
  echo "Processing ${DISK}...."
  # shellcheck disable=SC2086
  echo 0 > ${DISK}/queue/read_ahead_kb

#  echo writearound > "${DISK}"/bcache/cache_mode
  echo writeback > "${DISK}"/bcache/cache_mode
#  echo none > "${DISK}"/bcache/cache_mode

  cat "${DISK}"/bcache/cache_mode

#  echo $(numfmt --from=iec 64M) > "${DISK}"/bcache/sequential_cutoff
  echo 0 > "${DISK}"/bcache/sequential_cutoff

  echo 40 > "${DISK}"/bcache/writeback_percent

  echo $((60 * 2)) > "${DISK}"/bcache/writeback_delay

  # Hack to support hw raid on pve1 that has more perf available than the # of backing devices would indicate
  if (hostname | grep -q pve1) && grep -q sdb "${DISK}/bcache/backing_dev_name"; then
    backing_drive_count=16
  else
    backing_drive_count=$(lsblk | grep $(cat "${DISK}/bcache/backing_dev_name") | wc -l)
  fi
  echo "... backing device count ${backing_drive_count}"

  echo $(($(numfmt --from=iec $(( 8 * backing_drive_count ))M) / 512)) > "${DISK}/bcache/writeback_rate_minimum"
#  echo 0 > "${DISK}/bcache/writeback_rate_minimum"

  echo 0 > "${DISK}"/bcache/cache/internal/gc_after_writeback

#  WARNING DO NOT SET TO 1 THIS WILL RESULT IN DATALOSS
  echo 0 > "${DISK}"/bcache/cache/cache0/discard

  echo lru > "${DISK}"/bcache/cache/cache0/cache_replacement_policy

  echo 0 > "${DISK}"/bcache/cache/congested_read_threshold_us
  echo 0 > "${DISK}"/bcache/cache/congested_write_threshold_us
#  echo 2000 > "${DISK}"/bcache/cache/congested_read_threshold_us
#  echo 20000 > "${DISK}"/bcache/cache/congested_write_threshold_us
  echo "-------------------------------"
done
echo "-----------------------------------------------------------"
