#!/bin/bash

# Function to set osd_mclock_max_capacity_iops_ssd value for a given OSD
set_osd_mclock_capacity() {
  local osd_id="$1"
  local capacity="$2"
  local device_class="$3"

  # Check if capacity is provided
  if [[ -z "$capacity" ]]; then
    echo "Error: capacity is a required argument."
    return 1
  fi

  # Check if capacity is a valid integer
  if [[ ! "$capacity" =~ ^[0-9]+$ ]]; then
    echo "Error: capacity must be a non-negative integer."
    return 1
  fi

  ceph config rm osd."$osd_id" osd_mclock_max_capacity_iops_ssd
  ceph config rm osd."$osd_id" osd_mclock_max_capacity_iops_hdd
  ceph config rm osd."$osd_id" osd_mclock_max_sequential_bandwidth_hdd

  if [[ "$device_class" == "hdd" ]]; then
    device_class='ssd' # Hack for force all to use SSD until I can figure out how to get hdd backed bcache block device to NOT be detected as an SSD
    ceph config set osd."$osd_id" osd_mclock_max_sequential_bandwidth_ssd "150Mi"
    ceph config set osd."$osd_id" bluestore_throttle_cost_per_io_ssd "100000"
    ceph config set osd."$osd_id" bluestore_deferred_batch_ops_ssd "2048" # Should this align with nr_requests? Current 2x hdd nr_requests
  else
    device_class='ssd'
    ceph config rm osd."$osd_id" osd_mclock_max_sequential_bandwidth_ssd
  fi

  ceph config set osd."$osd_id" osd_mclock_max_capacity_iops_"${device_class}" "$capacity"

  if [[ $? -eq 0 ]]; then
    echo "Successfully set osd_mclock_max_capacity_iops_${device_class} to $capacity for OSD $osd_id"
  else
    echo "Error: Failed to set osd_mclock_max_capacity_iops_${device_class} for OSD $osd_id"
    return 1
  fi
}

# Main script logic

# Check if enough arguments are provided
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <device_class> <capacity>"
  echo "Example: $0 ssd 1000"
  exit 1
fi

device_class="$1"

# Get OSD IDs of the specified device class
osd_ids=$(ceph osd crush tree --format json | jq -r ".nodes[] | select(.type == \"osd\" and .device_class == \"$device_class\") | .id")

# Check if any OSDs were found for the specified class
if [[ -z "$osd_ids" ]]; then
  echo "No OSDs found for device class: $device_class"
  exit 0
fi

# Iterate through each OSD ID
for osd_id in $osd_ids; do
  capacity="$2"

  # Only process local OSDs
  if [ "$(ceph osd metadata "$osd_id" | jq -r '.hostname')" = "$(hostname)" ]; then
    echo "Processing local ${device_class} OSD.${osd_id}"
    backing_device=$(ceph osd metadata osd.${osd_id} | jq -r '.bluestore_bdev_devices')

    # Scale capacity by the number of drives backing the OSD
    if [[ $backing_device =~ bcache* ]]; then
      backing_drive_count=$(lsblk | grep "└─${backing_device}" | wc -l)
      capacity=$(( capacity * backing_drive_count ))
      echo "  Scaling capacity by backing_drive_count: ${backing_drive_count}"
    fi

    if [[ "$device_class" == "hdd" ]]; then
      echo 1 > /sys/block/${backing_device}/queue/rotational
    fi

    set_osd_mclock_capacity "$osd_id" "$capacity" "$device_class"
  fi
  echo "Skip processing non-local ${device_class} OSD.${osd_id}"
done

exit 0
