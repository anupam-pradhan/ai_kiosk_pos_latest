# Quick Reference - SUNMI FLEX 3 TEE Issue

## TL;DR

**Problem:** SUNMI FLEX 3 doesn't have TEE/StrongBox → Stripe Terminal fails  
**Solution:** Need a device with hardware security OR contact Stripe/SUNMI for workaround

## Run This First

```bash
# Connect your SUNMI FLEX 3 via USB
cd /Users/anupampradhan/Desktop/ai_kiosk_pos_latest
./check_device_compatibility.sh
```

This will tell you definitively if the device is compatible.

## What I Changed

1. **Better error messages** - You'll now see exactly why it fails
2. **Device capability check** - Automatic detection of TEE/StrongBox
3. **Clear logging** - Easy to understand what's happening
4. **ProGuard fixes** - Won't strip security classes

## View Logs

```bash
# Clear logs and watch in real-time
adb logcat -c && adb logcat | grep StripeTerminal
```

## Expected Output on SUNMI FLEX 3

```
StripeTerminal: ═══════════════════════════════════════
StripeTerminal:   DEVICE COMPATIBILITY NOTICE
StripeTerminal: ═══════════════════════════════════════
StripeTerminal:   This device does not support hardware-backed security
StripeTerminal:   Device: SUNMI FLEX3
StripeTerminal:   POSSIBLE SOLUTIONS:
StripeTerminal:   1. Use a device with TEE/StrongBox support
StripeTerminal:   2. Contact Stripe support
StripeTerminal:   3. Check for firmware updates
```

## Compatible Devices (Known to Work)

- ✅ Google Pixel 4+
- ✅ Samsung Galaxy S9+
- ✅ Samsung Galaxy Note 9+
- ✅ OnePlus 7+
- ✅ Most 2019+ flagships

## Next Steps

### 1. Verify the Issue

```bash
flutter run
# Watch logcat for detailed error
```

### 2. Test with Compatible Device

If you have access to a Pixel/Samsung, test there first

### 3. Contact Support

**Stripe Support:**

- URL: https://support.stripe.com/
- Include: Device report from compatibility check script
- Ask: "Does SUNMI FLEX 3 support Tap to Pay?"

**SUNMI Support:**

- URL: https://www.sunmi.com/en-US/support/
- Ask: "Does FLEX 3 have TEE/StrongBox? Can it run Stripe Terminal?"
- Request: Firmware update or alternative model

## Build Commands

```bash
# Clean build
flutter clean
flutter pub get
flutter build apk --release

# Debug build with logs
flutter run --verbose

# Install on device
flutter install
```

## Files Changed

- `android/app/src/main/kotlin/.../MainActivity.kt` - Enhanced error handling
- `android/app/proguard-rules.pro` - Added security class rules
- `SUNMI_DEVICE_TEE_ISSUE.md` - Full documentation
- `TEE_FIX_SUMMARY.md` - Implementation details
- `check_device_compatibility.sh` - Device test script

## Troubleshooting

### App crashes on startup?

```bash
adb logcat | grep -E "FATAL|AndroidRuntime"
```

### Stripe Terminal not initializing?

```bash
adb logcat | grep -E "StripeTerminal|Terminal"
```

### NFC not working?

```bash
adb shell pm list features | grep nfc
adb shell settings get secure nfc_enabled
```

## Important Notes

⚠️ **These changes are diagnostic only** - they help you understand the problem but don't bypass Stripe's hardware requirements.

✅ **App won't crash** - Graceful error handling added  
✅ **Better logs** - Clear understanding of what's wrong  
✅ **Device detection** - Automatic capability checking

## Documentation Files

1. **`SUNMI_DEVICE_TEE_ISSUE.md`** - Read this for full explanation
2. **`TEE_FIX_SUMMARY.md`** - Read this for technical implementation
3. **`QUICK_REFERENCE.md`** - This file (quick commands)

## Support Information

| What                | Where                                                    |
| ------------------- | -------------------------------------------------------- |
| Stripe Docs         | https://stripe.com/docs/terminal/sdk/android             |
| Device Requirements | https://stripe.com/docs/terminal/references/device-setup |
| KeyStore Docs       | https://developer.android.com/training/articles/keystore |
| Issue Tracker       | https://github.com/stripe/stripe-terminal-android        |

---

**Quick Help:** If you're stuck, run the compatibility check script and share the output with Stripe/SUNMI support.
