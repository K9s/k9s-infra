#!/bin/bash

# Function to set osd_mclock_max_capacity_iops_ssd value for a given OSD
set_osd_mclock_capacity() {
  local osd_id="$1"
  local capacity="$2"

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

  # Inject the configuration
  ceph config set osd."$osd_id" osd_mclock_max_capacity_iops_ssd "$capacity"

  if [[ $? -eq 0 ]]; then
    echo "Successfully set osd_mclock_max_capacity_iops_ssd to $capacity for OSD $osd_id"
  else
    echo "Error: Failed to set osd_mclock_max_capacity_iops_ssd for OSD $osd_id"
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
      backing_drive_count=$(lsblk | grep $backing_device | wc -l)
      capacity=$(( capacity * backing_drive_count ))
      echo "  Scaling capacity by backing_drive_count: ${backing_drive_count}"
    fi
    set_osd_mclock_capacity "$osd_id" "$capacity"

    if [[ "$device_class" == "hdd" ]]; then
#      ceph config rm osd."$osd_id" bluestore_deferred_batch_ops
#      ceph config rm osd."$osd_id" bluestore_prefer_deferred_size #$(numfmt --from=iec 32K)
#      ceph config rm osd."$osd_id" bluestore_compression_max_blob_size
#      ceph config rm osd."$osd_id" bluestore_max_blob_size
      ceph config rm osd."$osd_id" bluestore_cache_meta_ratio
      ceph config rm osd."$osd_id" bluestore_min_alloc_size
    fi
  fi
  echo "Skip processing non-local ${device_class} OSD.${osd_id}"
done

exit 0
