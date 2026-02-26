#!/bin/bash

# Comprehensive Log Collection Script
# Saves all relevant logs to a file for analysis

echo "═══════════════════════════════════════════════════════"
echo "  Stripe Terminal - Full Log Collection"
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

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="stripe_terminal_logs_${TIMESTAMP}.txt"

echo "📱 Collecting logs from device..."
echo ""

# Collect device information
{
    echo "═══════════════════════════════════════════════════════"
    echo "  DEVICE INFORMATION"
    echo "═══════════════════════════════════════════════════════"
    echo "Captured: $(date)"
    echo ""
    echo "Manufacturer: $(adb shell getprop ro.product.manufacturer | tr -d '\r')"
    echo "Brand: $(adb shell getprop ro.product.brand | tr -d '\r')"
    echo "Model: $(adb shell getprop ro.product.model | tr -d '\r')"
    echo "Device: $(adb shell getprop ro.product.device | tr -d '\r')"
    echo "Android: $(adb shell getprop ro.build.version.release | tr -d '\r') (API $(adb shell getprop ro.build.version.sdk | tr -d '\r'))"
    echo "Build: $(adb shell getprop ro.build.fingerprint | tr -d '\r')"
    echo ""
    
    echo "═══════════════════════════════════════════════════════"
    echo "  GOOGLE PLAY SERVICES"
    echo "═══════════════════════════════════════════════════════"
    GMS_VERSION=$(adb shell dumpsys package com.google.android.gms | grep versionName | head -1 | awk -F= '{print $2}' | tr -d '\r' | xargs)
    echo "Version: $GMS_VERSION"
    echo ""
    
    echo "═══════════════════════════════════════════════════════"
    echo "  DEVICE FEATURES"
    echo "═══════════════════════════════════════════════════════"
    echo "NFC:"
    adb shell pm list features | grep nfc
    echo ""
    echo "KeyStore/Security:"
    adb shell pm list features | grep -E "keystore|strongbox|security"
    echo ""
    
    echo "═══════════════════════════════════════════════════════"
    echo "  APP INFORMATION"
    echo "═══════════════════════════════════════════════════════"
    APP_VERSION=$(adb shell dumpsys package com.example.ai_kiosk_pos | grep versionName | head -1 | awk -F= '{print $2}' | tr -d '\r' | xargs)
    echo "App Version: $APP_VERSION"
    echo "Install Date: $(adb shell dumpsys package com.example.ai_kiosk_pos | grep firstInstallTime | head -1 | tr -d '\r')"
    echo ""
    
    echo "Permissions:"
    adb shell dumpsys package com.example.ai_kiosk_pos | grep -A 20 "runtime permissions:" | grep -E "android.permission"
    echo ""
    
    echo "═══════════════════════════════════════════════════════"
    echo "  SYSTEM SETTINGS"
    echo "═══════════════════════════════════════════════════════"
    NFC_ENABLED=$(adb shell settings get secure nfc_on 2>/dev/null | tr -d '\r')
    LOCATION_MODE=$(adb shell settings get secure location_mode 2>/dev/null | tr -d '\r')
    echo "NFC Enabled: $NFC_ENABLED"
    echo "Location Mode: $LOCATION_MODE"
    echo ""
    
    echo "═══════════════════════════════════════════════════════"
    echo "  APPLICATION LOGS"
    echo "═══════════════════════════════════════════════════════"
    echo ""
} > "$LOG_FILE"

# Collect logcat
echo "Collecting logcat (last 5000 lines)..."
adb logcat -d -t 5000 | grep -E "Stripe|Terminal|MainActivity|Kiosk|flutter|AndroidRuntime|FATAL" >> "$LOG_FILE"

echo ""
echo "✅ Logs saved to: $LOG_FILE"
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  LOG FILE READY"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "File: $LOG_FILE"
echo "Size: $(du -h "$LOG_FILE" | cut -f1)"
echo ""
echo "You can:"
echo "  1. View logs: cat $LOG_FILE"
echo "  2. Search errors: grep -i error $LOG_FILE"
echo "  3. Search Stripe: grep StripeTerminal $LOG_FILE"
echo "  4. Share with support: Send this file to Stripe/SUNMI"
echo ""
echo "Key sections to check:"
echo "  - Search for 'DEVICE INFORMATION' - device specs"
echo "  - Search for 'APPLICATION LOGS' - actual runtime logs"
echo "  - Search for 'error' or 'exception' - problems"
echo "  - Search for 'initialized' - successful startup"
echo ""
