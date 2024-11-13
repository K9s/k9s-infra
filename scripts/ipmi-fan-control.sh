#!/usr/bin/env bash
set -e
set -o pipefail

# ----------------------------------------------------------------------------------
# Automatically setting fan speed via IPMI 
#
# Requires:
# ipmitool = apt-get install ipmitool
# bc = apt-get install bc
# ----------------------------------------------------------------------------------

#### Config
## IPMI
IPMI_HOST=${IPMI_HOST:-$(hostname).mgmt.$(hostname -d)}
IPMI_USER=${IPMI_USER:-root}
IPMI_PW=${IPMI_PW:-calvin}
IPMI_EK=${IPMI_EK:-0000000000000000000000000000000000000000}
#IPMI_BASE_CMD="ipmitool -I lanplus -H ${IPMI_HOST} -U ${IPMI_USER} -P ${IPMI_PW} -y ${IPMI_EK}"
IPMI_BASE_CMD="ipmitool -y ${IPMI_EK}"

## Temp
# Ambient
AMBIENT_TEMP_CMD=${AMBIENT_TEMP_CMD:-"${IPMI_BASE_CMD} sensor reading 'Ambient Temp' | tr -s '  ' ' ' | cut -d ' ' -f 4"}
AMBIENT_TEMP_MIN=${AMBIENT_TEMP_MIN:-25}
AMBIENT_TEMP_MAX=${AMBIENT_TEMP_MAX:-40}
# Device
DEVICE_TEMP_CMD=${DEVICE_TEMP_CMD:-"smartctl --all /dev/nvme0n1 | grep 'Temperature:' | tr -s '  ' ' ' | cut -d ' ' -f 2"}
DEVICE_TEMP_BIAS=${DEVICE_TEMP_BIAS:-4}
DEVICE_TEMP_MIN=${DEVICE_TEMP_MIN:-35}
DEVICE_TEMP_MIN_OVERRIDE='AMBIENT'
DEVICE_TEMP_MAX=${DEVICE_TEMP_MAX:-70}
## Fan
FAN_PERCENT_MIN=${FAN_PERCENT_MIN:-10}
FAN_PERCENT_MAX=${FAN_PERCENT_MAX:-80}

## Misc
CHECK_INTERVAL=10

#### Trap
fallback() {
  echo 'Stopping Active Control, fallback to automatic fan control'
  $IPMI_BASE_CMD raw 0x30 0x30 0x02 0xff "0x$(printf '%x\n' 100)" >/dev/null # 100% Fan
  sleep 5
  ## Enable automatic fan control
  $IPMI_BASE_CMD raw 0x30 0x30 0x01 0x01 >/dev/null
}

trap fallback ERR
trap fallback EXIT
trap fallback SIGTERM

#--------------Do not edit below this line--------------

scriptupdate=$(mktemp)

#### Script
echo "Beginning active fan control....  Ambient Temp Min(Max):${AMBIENT_TEMP_MIN}c(${AMBIENT_TEMP_MAX}c) Device Temp Min(Max):${DEVICE_TEMP_MIN_OVERRIDE:-"${DEVICE_TEMP_MIN}c"}(${DEVICE_TEMP_MAX}c) Fan Min(Max):${FAN_PERCENT_MIN}%(${FAN_PERCENT_MAX}%) Device Temp Bias: ${DEVICE_TEMP_BIAS}X"
echo "--- IPMI_HOST: ${IPMI_HOST} IPMI_USER: ${IPMI_USER}"

# Disable automatic fan control
$IPMI_BASE_CMD raw 0x30 0x30 0x01 0x00 >/dev/null

# Spin up to 100%
$IPMI_BASE_CMD raw 0x30 0x30 0x02 0xff "0x$(printf '%x\n' 100)" >/dev/null
sleep 2

# Main loop
while true
do
  if [[ $0 -nt $scriptupdate ]]; then
    echo '--- New version detected, terminating main loop!'
    break
  fi
  check_count=$((check_count+1))

  DEVICE_TEMP=$(bash -c "$DEVICE_TEMP_CMD")
  AMBIENT_TEMP=$(bash -c "$AMBIENT_TEMP_CMD")

  if ! [ -z DEVICE_TEMP_MIN_OVERRIDE ]; then
    DEVICE_TEMP_MIN=$AMBIENT_TEMP
  fi

  if [ -z "${DEVICE_TEMP}" ] || [ -z "${AMBIENT_TEMP}" ]; then
    # If the condition that caused this to trigger is not resolved fans will spin up and down repeatedly as the service starts and then ends in error
    echo "Unable to determine DEVICE_TEMP (${DEVICE_TEMP}) or AMBIENT_TEMP (${AMBIENT_TEMP}). Exiting!"
    exit -1
  fi

  ## Clamp scalers to ensure curve remains between MIN/MAX
  # Device
  if [ "$DEVICE_TEMP" -ge $DEVICE_TEMP_MAX ]; then
    FAN_SCALER_DEVICE=1
  elif [ "$DEVICE_TEMP" -lt $DEVICE_TEMP_MIN ]; then
    FAN_SCALER_DEVICE=0
  else
    FAN_SCALER_DEVICE=$(echo "scale=4;($DEVICE_TEMP - $DEVICE_TEMP_MIN) / ($DEVICE_TEMP_MAX - $DEVICE_TEMP_MIN)" | bc)
  fi
  # Ambient
  if [ "$AMBIENT_TEMP" -ge $AMBIENT_TEMP_MAX ]; then
    FAN_SCALER_AMBIENT=1
  elif [ "$AMBIENT_TEMP" -lt $AMBIENT_TEMP_MIN ]; then
    FAN_SCALER_AMBIENT=0
  else
    FAN_SCALER_AMBIENT=$(echo "scale=4;($AMBIENT_TEMP - $AMBIENT_TEMP_MIN) / ($AMBIENT_TEMP_MAX - $AMBIENT_TEMP_MIN)" | bc)
  fi

  # Unless ambient or device temps are at MAX add bias and then average scalers
  if [[ "$FAN_SCALER_DEVICE" == "1" ]] || [[ "$FAN_SCALER_AMBIENT" == "1" ]]; then
    echo "Device ${DEVICE_TEMP}c(${DEVICE_TEMP_MAX}c) and/or ambient ${AMBIENT_TEMP}c(${AMBIENT_TEMP_MAX}c) temp is above MAX allowed threashold(s)!"
    FAN_SCALER=1
  else
    FAN_SCALER=$(echo "scale=4;(($FAN_SCALER_DEVICE * $DEVICE_TEMP_BIAS) + $FAN_SCALER_AMBIENT) / ($DEVICE_TEMP_BIAS + 1)" | bc)
  fi

  FAN_PERCENT_LAST=${FAN_PERCENT:-255}
  FAN_PERCENT=$(echo "scale=2;(($FAN_PERCENT_MAX - $FAN_PERCENT_MIN) * $FAN_SCALER + $FAN_PERCENT_MIN)" | bc | cut -d '.' -f 1)

  # Continue if $FAN_PERCENT is unchanged from last iteration
  if [ $FAN_PERCENT_LAST -eq $FAN_PERCENT ]; then
    sleep $CHECK_INTERVAL
    continue
  fi

  # Set fan speed
  FAN_PERCENT_HEX="0x$(printf '%x\n' $FAN_PERCENT)"
  $IPMI_BASE_CMD raw 0x30 0x30 0x02 0xff "${FAN_PERCENT_HEX}" >/dev/null

  sleep $CHECK_INTERVAL

  # Log
  log="Device ${DEVICE_TEMP}c Ambient Temp(+device): ${AMBIENT_TEMP}c(+$((DEVICE_TEMP - AMBIENT_TEMP))c) Scaler(Device/Ambient): ${FAN_SCALER}(${FAN_SCALER_DEVICE}/${FAN_SCALER_AMBIENT}) Fan%(hex):${FAN_PERCENT}(${FAN_PERCENT_HEX})"
  FAN_RPM=$(${IPMI_BASE_CMD} sensor reading "FAN 1 RPM" | tr -s "  " " " | cut -d " " -f 5)
  echo "${log} RPM: ${FAN_RPM} Checks Since Last Change: ${check_count}"
  check_count=0
done

echo '--- Graceful exit all is well!'
