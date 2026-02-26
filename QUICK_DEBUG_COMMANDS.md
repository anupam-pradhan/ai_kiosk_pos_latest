# Quick Debug Commands for SUNMI FLEX 3

## 🚀 Quick Start (Copy & Paste)

### Watch Logs Live (Terminal 1)

```bash
cd /Users/anupampradhan/Desktop/ai_kiosk_pos_latest
./watch_logs.sh
```

### Run App (Terminal 2)

```bash
cd /Users/anupampradhan/Desktop/ai_kiosk_pos_latest
flutter run
```

## 📊 Check Current Status

```bash
# Is app installed?
adb shell pm list packages | grep ai_kiosk_pos

# Is app running?
adb shell pidof com.example.ai_kiosk_pos

# App version
adb shell dumpsys package com.example.ai_kiosk_pos | grep versionName

# Check permissions
adb shell dumpsys package com.example.ai_kiosk_pos | grep "android.permission" | head -20
```

## 🔍 View Recent Logs

```bash
# Last 50 Stripe logs
adb logcat -d | grep StripeTerminal | tail -50

# Last 20 errors
adb logcat -d | grep -E "error|Error|ERROR" | tail -20

# Find initialization
adb logcat -d | grep -i "initialized"

# Find TEE messages
adb logcat -d | grep -i "tee\|strongbox\|attestation"
```

## 🧹 Reset Everything

```bash
# Clear app + Google Play Services
adb shell pm clear com.example.ai_kiosk_pos
adb shell pm clear com.google.android.gms

# Reboot device
adb reboot

# Wait for reboot, then reinstall
flutter clean && flutter run
```

## 📸 Capture Issue

```bash
# Start capturing
adb logcat -c
./collect_logs.sh &

# Reproduce the issue in the app

# Stop capturing (Ctrl+C)
# Check the generated file: stripe_terminal_logs_*.txt
```

## 🔧 One-Line Checks

```bash
# Device info
adb shell getprop | grep "ro.product.model\|ro.product.manufacturer"

# NFC enabled?
adb shell settings get secure nfc_on

# Location enabled?
adb shell settings get secure location_mode

# Google Play Services version
adb shell dumpsys package com.google.android.gms | grep versionName | head -1

# Check for StrongBox
adb shell pm list features | grep strongbox

# Check for TEE
adb shell pm list features | grep keystore
```

## 🎯 Common Issues & Quick Fixes

### "No logs appearing"

```bash
adb kill-server && adb start-server
adb devices
```

### "App crashes immediately"

```bash
adb logcat -d | grep "FATAL" | tail -10
```

### "TEE error on SUNMI"

```bash
# This is EXPECTED - run setup script
./setup_sunmi_device.sh
flutter clean && flutter run
```

### "Can't see initialization logs"

```bash
# Clear and watch from scratch
adb logcat -c
flutter run
# In another terminal:
adb logcat | grep "Terminal.*init"
```

## 📋 Pre-Flight Checklist

Before testing, verify:

```bash
# 1. Device connected
adb devices
# Should show: "device" (not "unauthorized")

# 2. NFC enabled
adb shell settings get secure nfc_on
# Should show: 1

# 3. Location enabled
adb shell settings get secure location_mode
# Should show: 3 (high accuracy)

# 4. Google Play Services installed
adb shell pm list packages | grep "com.google.android.gms"
# Should show: package:com.google.android.gms

# 5. App installed
adb shell pm list packages | grep "ai_kiosk_pos"
# Should show: package:com.example.ai_kiosk_pos
```

## 🆘 Emergency Debug

If nothing works:

```bash
# Full log dump to file
adb logcat -d > full_debug_$(date +%Y%m%d_%H%M%S).txt

# Check file
ls -lh full_debug_*.txt

# Search for issues
grep -i "stripe\|terminal\|error" full_debug_*.txt
```

## 💡 Tips

- Keep `./watch_logs.sh` running in a separate terminal
- Use `./collect_logs.sh` when you encounter an error
- Check [DEBUG_LOGGING_GUIDE.md](DEBUG_LOGGING_GUIDE.md) for detailed explanations
- Colors in watch_logs.sh: Red=Error, Green=Success, Yellow=Warning
