#!/bin/bash

# Device Compatibility Check Script for Stripe Terminal
# Checks if connected Android device supports TEE/StrongBox

echo "═══════════════════════════════════════════════════════"
echo "  Stripe Terminal Device Compatibility Check"
echo "═══════════════════════════════════════════════════════"
echo ""

# Check if adb is available
if ! command -v adb &> /dev/null; then
    echo "❌ Error: adb command not found"
    echo "   Please install Android SDK platform-tools"
    exit 1
fi

# Check if device is connected
if ! adb devices | grep -q "device$"; then
    echo "❌ Error: No Android device connected"
    echo "   Please connect device via USB and enable USB debugging"
    exit 1
fi

echo "📱 Device Information:"
echo "────────────────────────────────────────────────────────"

# Get device details
MANUFACTURER=$(adb shell getprop ro.product.manufacturer | tr -d '\r')
MODEL=$(adb shell getprop ro.product.model | tr -d '\r')
BRAND=$(adb shell getprop ro.product.brand | tr -d '\r')
DEVICE=$(adb shell getprop ro.product.device | tr -d '\r')
SDK_VERSION=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
ANDROID_VERSION=$(adb shell getprop ro.build.version.release | tr -d '\r')
BUILD_ID=$(adb shell getprop ro.build.id | tr -d '\r')
FINGERPRINT=$(adb shell getprop ro.build.fingerprint | tr -d '\r')

echo "  Manufacturer: $MANUFACTURER"
echo "  Brand:        $BRAND"
echo "  Model:        $MODEL"
echo "  Device:       $DEVICE"
echo "  Android:      $ANDROID_VERSION (API $SDK_VERSION)"
echo "  Build ID:     $BUILD_ID"
echo ""

echo "🔐 Security Features:"
echo "────────────────────────────────────────────────────────"

# Check for StrongBox
if adb shell pm list features | grep -q "android.hardware.strongbox_keystore"; then
    echo "  ✅ StrongBox KeyStore:        Supported"
    STRONGBOX_SUPPORT=true
else
    echo "  ❌ StrongBox KeyStore:        NOT Supported"
    STRONGBOX_SUPPORT=false
fi

# Check for TEE (hardware keystore)
if adb shell pm list features | grep -q "android.hardware.keystore"; then
    echo "  ✅ Hardware KeyStore (TEE):   Supported"
    TEE_SUPPORT=true
else
    echo "  ❌ Hardware KeyStore (TEE):   NOT Supported"
    TEE_SUPPORT=false
fi

# Check for fingerprint sensor (indicator of secure hardware)
if adb shell pm list features | grep -q "android.hardware.fingerprint"; then
    echo "  ✅ Fingerprint Sensor:        Present"
else
    echo "  ⚠️  Fingerprint Sensor:        Not Present"
fi

# Check NFC
if adb shell pm list features | grep -q "android.hardware.nfc"; then
    echo "  ✅ NFC Hardware:              Present"
    NFC_ENABLED=$(adb shell settings get secure nfc_payment_default_component 2>/dev/null | tr -d '\r')
    if [ ! -z "$NFC_ENABLED" ] && [ "$NFC_ENABLED" != "null" ]; then
        echo "  ✅ NFC Payment:               Enabled"
    else
        echo "  ⚠️  NFC Payment:               May need configuration"
    fi
else
    echo "  ❌ NFC Hardware:              NOT Present"
fi

echo ""
echo "📊 Stripe Terminal Compatibility:"
echo "────────────────────────────────────────────────────────"

# Determine compatibility
if [ "$STRONGBOX_SUPPORT" = true ]; then
    echo "  ✅ FULLY COMPATIBLE"
    echo "     This device supports StrongBox and should work"
    echo "     perfectly with Stripe Terminal SDK 5.2.0"
    COMPATIBLE=true
elif [ "$TEE_SUPPORT" = true ]; then
    echo "  ✅ COMPATIBLE (TEE)"
    echo "     This device supports TEE hardware security."
    echo "     Should work with Stripe Terminal SDK."
    COMPATIBLE=true
else
    echo "  ❌ NOT COMPATIBLE"
    echo "     This device lacks hardware-backed key storage."
    echo "     Stripe Terminal SDK 5.2.0 will likely fail."
    COMPATIBLE=false
fi

echo ""

if [ "$COMPATIBLE" = true ]; then
    echo "✅ Recommendation: This device is suitable for Stripe Tap to Pay"
    echo ""
    echo "Next Steps:"
    echo "  1. Ensure NFC is enabled: Settings > Connected devices > Connection preferences > NFC"
    echo "  2. Install your app and test payment flow"
    echo "  3. Check logcat for any initialization messages"
else
    echo "❌ Recommendation: This device is NOT suitable for Stripe Tap to Pay"
    echo ""
    echo "Suggested Actions:"
    echo "  1. Use a device with TEE/StrongBox support"
    echo "  2. Recommended devices:"
    echo "     • Google Pixel (Pixel 4 or newer)"
    echo "     • Samsung Galaxy S series (S9 or newer)"
    echo "     • Samsung Galaxy Note (Note 9 or newer)"
    echo "     • Most flagship devices from 2019+"
    echo "  3. Contact device manufacturer for firmware updates"
    echo "  4. Contact Stripe support with this report"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Report Generated: $(date)"
echo "═══════════════════════════════════════════════════════"
echo ""

# Save report to file
REPORT_FILE="device_compatibility_report_$(date +%Y%m%d_%H%M%S).txt"
{
    echo "Stripe Terminal Device Compatibility Report"
    echo "Generated: $(date)"
    echo ""
    echo "Device Information:"
    echo "  Manufacturer: $MANUFACTURER"
    echo "  Brand:        $BRAND"
    echo "  Model:        $MODEL"
    echo "  Device:       $DEVICE"
    echo "  Android:      $ANDROID_VERSION (API $SDK_VERSION)"
    echo "  Build:        $FINGERPRINT"
    echo ""
    echo "Security Features:"
    if [ "$STRONGBOX_SUPPORT" = true ]; then
        echo "  StrongBox:    YES"
    else
        echo "  StrongBox:    NO"
    fi
    if [ "$TEE_SUPPORT" = true ]; then
        echo "  TEE:          YES"
    else
        echo "  TEE:          NO"
    fi
    echo ""
    if [ "$COMPATIBLE" = true ]; then
        echo "Compatibility: COMPATIBLE"
    else
        echo "Compatibility: NOT COMPATIBLE"
    fi
} > "$REPORT_FILE"

echo "📄 Full report saved to: $REPORT_FILE"
echo ""
