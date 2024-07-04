#!/usr/bin/env bash
set -e

# Wait for the diagnostics app to be loaded
until wget -q -T 10 -O - http://diagnostics/json > /dev/null 2>&1
do
    echo "Diagnostics container not ready. Going to sleep."
    sleep 10
done

# Verify that all the required varibles are set before starting up the application.

echo "Verifying settings..."
echo " "
sleep 2

missing_variables=false

if [ -f /var/nebra/wingbits.json ]; then
    echo "Wingbits config JSON found!"
    WINGBITS_DEVICE_ID=$(cat /var/nebra/wingbits.json | jq -r '.node_name')
    LAT=$(cat /var/nebra/wingbits.json | jq -r '.latitude')
    LON=$(cat /var/nebra/wingbits.json | jq -r '.longitude')
else
    echo "Wingbits config JSON not found!"
fi

if [ -n "$WINGBITS_DEVICE_ID_OVERRIDE" ]; then
    WINGBITS_DEVICE_ID="$WINGBITS_DEVICE_ID_OVERRIDE"
    echo "Wingbits Device ID Override Set - using instead of JSON value."
fi

if [ -n "$LAT_OVERRIDE" ]; then
    LAT="$LAT_OVERRIDE"
    echo "Wingbits Latitude Override Set - using instead of JSON value."
fi

if [ -n "$LON_OVERRIDE" ]; then
    LON="$LON_OVERRIDE"
    echo "Wingbits Longitude Override Set - using instead of JSON value."
fi

# Begin defining all the required configuration variables.

[ -z "$WINGBITS_DEVICE_ID" ] && echo "Wingbits Device ID is missing, will abort startup." && missing_variables=true || echo "Wingbits Device ID is set: $WINGBITS_DEVICE_ID"
[ -z "$LAT" ] && echo "Receiver latitude is missing, will abort startup." && missing_variables=true || echo "Receiver latitude is set: $LAT"
[ -z "$LON" ] && echo "Receiver longitude is missing, will abort startup." && missing_variables=true || echo "Receiver longitude is set: $LON"

# End defining all the required configuration variables.

echo " "

if [ "$missing_variables" = true ]
then
        echo "Settings missing, aborting..."
        echo " "
        sleep infinity
fi

echo "Settings verified, proceeding with startup."
echo " "

# Check if Wingbits is latest version

local_version=$(cat /etc/wingbits/version)
echo "Current local version: $local_version"

SCRIPT_URL="https://gitlab.com/wingbits/config/-/raw/master/download.sh"
script=$(curl $SCRIPT_URL)
version=$(echo "$script" | grep -oP '(?<=WINGBITS_CONFIG_VERSION=")[^"]*')
echo "Latest available wingbits version: $version"

if [ "$version" != "$local_version" ] || [ -z "$version" ]; then
    echo "WARNING: You are not running the latest Wingbits version. Please update at your earliest convenience."
else
    echo "Wingbits is up to date"
fi

echo " "

# Variables are verified – continue with startup procedure.

# Start vector and readsb and put in the background.
/usr/bin/vector --watch-config &
/usr/bin/feed-wingbits --device-type rtlsdr --device "$DUMP1090_DEVICE" --lat "$LAT" --lon "$LON" --ppm "$DUMP1090_PPM" --max-range "$DUMP1090_MAX_RANGE" --net --debug=n --quiet --net-connector localhost,30006,json_out --write-json /run/wingbits-feed --write-json /run/readsb/ --net-beast-reduce-interval 0.5 --net-heartbeat 60 --net-ro-size 1280 --net-ro-interval 0.2 --net-ro-port 30002,30102 --net-sbs-port 30003 --net-bi-port 30004,30104 --net-bo-port 30005,30105 --net-ri-port 0 --raw --json-location-accuracy 2 2>&1 | stdbuf -o0 sed --unbuffered '/^$/d' |  awk -W interactive '{print "[readsb-wingbits]     " $0}' &
  
# Start lighthttpd and put it in the background.
/usr/sbin/lighttpd -D -f /etc/lighttpd/lighttpd.conf &

# Wait for any services to exit.
wait -n
