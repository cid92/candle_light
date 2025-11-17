#!/bin/bash
#
# unified_loopback_test.sh — Serial + CAN loopback test
#

DEVICE="/dev/ttyUSB3"
BAUD=115200
MESSAGE="HELLO LOOPBACK"

echo "=== USB SERIAL LOOPBACK TEST ==="

# Check if the device exists
if [ ! -e "$DEVICE" ]; then
    echo "Error: $DEVICE not found."
else
    echo "Listing USB devices..."
    lsusb
    echo

    echo "Configuring $DEVICE at ${BAUD} baud..."
    stty -F "$DEVICE" $BAUD cs8 -cstopb -parenb -echo -icanon raw || exit 1


# Loop 10 times
for i in $(seq 1 10); do
    echo
    echo "--- Iteration $i ---"

    # Start background reader for 2 seconds
    {
        timeout 2 cat "$DEVICE" | while IFS= read -r line; do
            size=${#line}
            echo "Recv (${size} bytes): $line"
        done
    } &
    READER_PID=$!

    sleep 0.5

    # Send test message
    echo "Sending: $MESSAGE"
    echo "$MESSAGE" > "$DEVICE"

    wait $READER_PID
    echo "Iteration $i complete."
done

echo
echo "=== USB LOOPBACK TESTS DONE ==="
fi

echo
echo "=== CAN RECEIVE TEST ==="

# Configure CAN interfaces
echo "Configuring CAN interfaces..."
ip link set can0 down 2>/dev/null
ip link set can1 down 2>/dev/null
ip link set can0 type can bitrate 500000
ip link set can1 type can bitrate 500000
ip link set can0 up
ip link set can1 up

# Start candump for 3 seconds (receive-only)
echo "Listening on can0 and can1 for 3 seconds..."
candump can0 &
PID0=$!
candump can1 &
PID1=$!

sleep 3

# Stop candump
kill $PID0 $PID1 2>/dev/null
wait $PID0 $PID1 2>/dev/null

echo "CAN receive-only test done."
echo
echo "=== ALL TESTS COMPLETE ==="
