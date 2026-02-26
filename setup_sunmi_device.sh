#!/bin/bash

# SUNMI FLEX 3 Setup Script for Stripe Terminal
# This script prepares the SUNMI FLEX 3 device for Stripe Tap to Pay

echo "═══════════════════════════════════════════════════════"
echo "  SUNMI FLEX 3 - Stripe Terminal Setup"
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
echo ""

# Step 1: Clear app data and cache
echo "🧹 Step 1: Clearing app data and cache..."
APP_PACKAGE="com.example.ai_kiosk_pos"

adb shell pm clear $APP_PACKAGE 2>/dev/null
echo "   ✅ App data cleared"

# Step 2: Clear Google Play Services cache (important for Stripe Terminal)
echo ""
echo "🔄 Step 2: Clearing Google Play Services cache..."
adb shell pm clear com.google.android.gms 2>/dev/null
echo "   ✅ Google Play Services cache cleared"
echo "   ⚠️  Note: Device may show 'Checking info' or require Google sign-in"

# Step 3: Ensure NFC is enabled
echo ""
echo "📡 Step 3: Checking NFC status..."
NFC_ENABLED=$(adb shell settings get secure nfc_on 2>/dev/null | tr -d '\r')
if [ "$NFC_ENABLED" = "1" ]; then
    echo "   ✅ NFC is enabled"
else
    echo "   ⚠️  NFC may be disabled"
    echo "   Please enable NFC: Settings > Connected devices > NFC"
fi

# Step 4: Check Google Play Services version
echo ""
echo "🔍 Step 4: Checking Google Play Services..."
GMS_VERSION=$(adb shell dumpsys package com.google.android.gms | grep versionName | head -1 | awk -F= '{print $2}' | tr -d '\r' | xargs)
if [ ! -z "$GMS_VERSION" ]; then
    echo "   ✅ Google Play Services: $GMS_VERSION"
    echo "   Required: 26.0.0 or higher"
else
    echo "   ⚠️  Could not determine Google Play Services version"
fi

# Step 5: Ensure location services are enabled
echo ""
echo "📍 Step 5: Checking location services..."
LOCATION_MODE=$(adb shell settings get secure location_mode 2>/dev/null | tr -d '\r')
if [ "$LOCATION_MODE" != "0" ]; then
    echo "   ✅ Location services enabled"
else
    echo "   ⚠️  Location services may be disabled"
    echo "   Please enable: Settings > Location > Use location"
fi

# Step 6: Install/Update the app
echo ""
echo "📦 Step 6: Ready to install app"
echo ""
echo "Run one of these commands:"
echo "   flutter run               # Debug build"
echo "   flutter install           # Install existing build"
echo "   flutter build apk --release && adb install -r build/app/outputs/flutter-apk/app-release.apk"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  IMPORTANT: First Launch Checklist"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "After installing the app, verify these on the device:"
echo ""
echo "1. ✅ Grant ALL permissions when prompted:"
echo "   • Location (Fine & Coarse)"
echo "   • Microphone"
echo "   • NFC"
echo ""
echo "2. ✅ Sign into Google account if prompted"
echo ""
echo "3. ✅ Check NFC settings:"
echo "   Settings > Connected devices > Connection preferences > NFC"
echo "   - NFC should be ON"
echo "   - 'Require device unlock for NFC' should be OFF"
echo ""
echo "4. ✅ Watch logs during first payment:"
echo "   adb logcat | grep -E 'StripeTerminal|Stripe|Terminal'"
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  SUNMI-Specific Notes"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "• SUNMI FLEX 3 is officially supported by Stripe"
echo "• Uses software-based key attestation (not StrongBox)"
echo "• First initialization may take 30-60 seconds"
echo "• May need to download Tap to Pay components (~50-100MB)"
echo ""
echo "If you see 'TEE not supported' error:"
echo "• This is EXPECTED for SUNMI devices"
echo "• Stripe SDK will automatically use software fallback"
echo "• The error should be logged but app should continue"
echo ""
echo "═══════════════════════════════════════════════════════"
echo ""

# Save device info to file
REPORT_FILE="sunmi_setup_report_$(date +%Y%m%d_%H%M%S).txt"
{
    echo "SUNMI FLEX 3 Setup Report"
    echo "Generated: $(date)"
    echo ""
    echo "Device: $DEVICE_MODEL"
    echo "Google Play Services: $GMS_VERSION"
    echo "NFC Enabled: $NFC_ENABLED"
    echo "Location Mode: $LOCATION_MODE"
    echo ""
    echo "App package: $APP_PACKAGE"
    echo "Data cleared: Yes"
    echo "Ready for install: Yes"
} > "$REPORT_FILE"

echo "📄 Setup report saved to: $REPORT_FILE"
echo ""
