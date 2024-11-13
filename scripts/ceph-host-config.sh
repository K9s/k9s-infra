#!/bin/sh
set -e
set -o pipefail

cpupower idle-set -D 11

echo "Setting IOSCHED"

modprobe bfq

sst set -ssd 1 PowerGovernorMode=0 || true

hdd_scheduler='mq-deadline'
if grep -q bfq /sys/block/sd*/queue/scheduler; then
  hdd_scheduler='bfq'
else
  echo "bfq scheduler unavailable. Falling back to ${hdd_scheduler}"
fi

echo "${hdd_scheduler} to be used!"

for DISK in /sys/block/nvme*; do echo mq-deadline > "${DISK}"/queue/scheduler; done
for DISK in /sys/block/sd*; do echo ${hdd_scheduler} > "${DISK}"/queue/scheduler; done

for DISK in /sys/block/sd*; do grep -q 0 "${DISK}"/queue/rotational && hdparm -W 0 -A 1 /dev/"$(echo "$DISK" | cut -d / -f 4)" ; done
for DISK in /sys/block/sd*; do grep -q 1 "${DISK}"/queue/rotational && hdparm -B 254 -S 120 -W 0 -A 1 /dev/"$(echo "$DISK" | cut -d / -f 4)" ; done

for DISK in /sys/block/sd*; do
  echo 64 > "${DISK}"/queue/nr_requests
  echo 4096 > "${DISK}"/queue/read_ahead_kb
  echo 1 > "${DISK}"/queue/rq_affinity
  echo 0 > "${DISK}"/queue/io_poll_delay
  echo 0 > "${DISK}"/queue/nomerges
done

for DISK in /sys/block/nvme*; do
  echo 1 > "${DISK}"/queue/add_random
  echo 8 > "${DISK}"/queue/nr_requests
  echo 512 > "${DISK}"/queue/read_ahead_kb
  echo 1 > "${DISK}"/queue/rq_affinity
  echo 0 > "${DISK}"/queue/io_poll_delay
  echo 1 > "${DISK}"/queue/nomerges
  echo 0 > "${DISK}"/queue/iosched/front_merges
  echo 4 > "${DISK}"/queue/iosched/fifo_batch
  echo 4 > "${DISK}"/queue/iosched/writes_starved
#  echo 100 > "${DISK}"/queue/iosched/read_expire
#  echo 1000 > "${DISK}"/queue/iosched/write_expire
done

for DISK in /sys/block/bcache*; do
  # shellcheck disable=SC2086
  echo 4096 > ${DISK}/queue/read_ahead_kb

#  echo writearound > "${DISK}"/bcache/cache_mode
  echo writeback > "${DISK}"/bcache/cache_mode
#  echo none > "${DISK}"/bcache/cache_mode

  cat "${DISK}"/bcache/cache_mode

#  echo $(numfmt --from=iec 64M) > "${DISK}"/bcache/sequential_cutoff
  echo 0 > "${DISK}"/bcache/sequential_cutoff

  echo 40 > "${DISK}"/bcache/writeback_percent

  echo 120 > "${DISK}"/bcache/writeback_delay

  echo $(($(numfmt --from=iec 16M) / 512)) > "${DISK}"/bcache/writeback_rate_minimum
#  echo 0 > "${DISK}"/bcache/writeback_rate_minimum

  echo 0 > "${DISK}"/bcache/cache/internal/gc_after_writeback

#  WARNING DO NOT SET TO 1 THIS WILL RESULT IN DATALOSS
  echo 0 > "${DISK}"/bcache/cache/cache0/discard

  echo lru > "${DISK}"/bcache/cache/cache0/cache_replacement_policy

  echo 0 > "${DISK}"/bcache/cache/congested_read_threshold_us
  echo 0 > "${DISK}"/bcache/cache/congested_write_threshold_us
#  echo 2000 > "${DISK}"/bcache/cache/congested_read_threshold_us
#  echo 20000 > "${DISK}"/bcache/cache/congested_write_threshold_us
done
