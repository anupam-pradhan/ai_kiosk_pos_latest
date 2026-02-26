#!/bin/bash

# Stripe Terminal Debug Log Capture Script
# Captures all relevant logs from your SUNMI FLEX 3 device

echo "═══════════════════════════════════════════════════════"
echo "  Stripe Terminal - Live Debug Logs"
echo "═══════════════════════════════════════════════════════"
echo ""

# Check if adb is available
if ! command -v adb &> /dev/null; then
    echo "❌ Error: adb command not found"
    exit 1
fi

# Check if device is connected
if ! adb devices | grep -q "device$"; then
    echo "❌ Error: No device connected"
    exit 1
fi

DEVICE_MODEL=$(adb shell getprop ro.product.model | tr -d '\r')
echo "📱 Device: $DEVICE_MODEL"
echo "🕐 Started: $(date)"
echo ""
echo "Watching for Stripe Terminal activity..."
echo "Press Ctrl+C to stop"
echo "─────────────────────────────────────────────────────────"
echo ""

# Clear old logs
adb logcat -c

# Capture logs with colors and filters
adb logcat \
  -v color \
  -v time \
  StripeTerminal:V \
  Stripe:V \
  Terminal:V \
  MainActivity:V \
  KioskApplication:V \
  flutter:V \
  *:E \
  | grep -E "Stripe|Terminal|MainActivity|Kiosk|TEE|StrongBox|KeyStore|attestation|NFC|hardware|security|flutter" \
  | while IFS= read -r line; do
    # Highlight important messages
    if echo "$line" | grep -qi "error\|fail\|exception"; then
      echo -e "\033[1;31m$line\033[0m"  # Red for errors
    elif echo "$line" | grep -qi "success\|connected\|initialized"; then
      echo -e "\033[1;32m$line\033[0m"  # Green for success
    elif echo "$line" | grep -qi "warn\|⚠️"; then
      echo -e "\033[1;33m$line\033[0m"  # Yellow for warnings
    elif echo "$line" | grep -qi "sunmi\|flex"; then
      echo -e "\033[1;36m$line\033[0m"  # Cyan for SUNMI-specific
    else
      echo "$line"
    fi
  done
