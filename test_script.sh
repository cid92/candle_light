#!/bin/bash
#
# unified_loopback_test.sh — USB serial loopback (/dev/ttyUSB3), ACM0 printout, and CAN receive test
#

DEVICE="/dev/ttyUSB3"
BAUD=115200

echo "=== Listing USB devices... ==="
lsusb
echo

echo "=== USB SERIAL LOOPBACK TEST (5 iterations) ==="
# Check if the device exists
if [ ! -e "$DEVICE" ]; then
    echo "Error: $DEVICE not found."
    DEVICE="/dev/ttyUSB0"
fi
if [ ! -e "$DEVICE" ]; then
    echo "Error: $DEVICE not found."
    exit
fi
echo "Configuring $DEVICE at ${BAUD} baud..."
stty -F "$DEVICE" $BAUD cs8 -cstopb -parenb -echo -icanon raw || exit 1

for i in $(seq 1 5); do
    echo
    echo "--- Iteration $i ---"

    TX="Loop test $(date)"

    # Background receiver – reads characters for 2 seconds
    RECEIVED=""
    {
        timeout 2 dd if="$DEVICE" bs=1 status=none |
        while IFS= read -r -n1 ch; do
            RECEIVED+="$ch"
        done
        echo "$RECEIVED" > /tmp/loopback_recv_$i
    } &
    READER_PID=$!

    sleep 0.3

    # Transmit
    echo "Sending: $TX"
    printf "%s" "$TX" > "$DEVICE"

    wait $READER_PID

    RX=$(cat /tmp/loopback_recv_$i)

    echo "Received: $RX"
    echo "TX length: ${#TX}, RX length: ${#RX}"

    if [[ "$TX" == "$RX" ]]; then
        echo "RESULT: ✓ MATCH"
    else
        echo "RESULT: ✗ MISMATCH"
    fi
done

echo
echo "=== Testing F9R Output (/dev/ttyACM0 for 3 seconds) ==="

if [ -e "/dev/ttyACM0" ]; then
    timeout 3 cat /dev/ttyACM0 | while IFS= read -r line; do
        size=${#line}
        echo "ACM0 (${size} bytes): $line"
    done
else
    echo "Error: /dev/ttyACM0 not found."
fi

echo
echo "=== CAN RECEIVE TEST (can0 + can1 for 3 seconds) ==="

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


