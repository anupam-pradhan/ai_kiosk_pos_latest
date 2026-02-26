# SUNMI FLEX 3 Device - TEE/Hardware Attestation Issue

## Issue Summary

**Error Message:**

```
Device does not use Trusted Execution Environment, or does not support hardware-backed key attestation.
```

**Device Information:**

- **Manufacturer:** SUNMI
- **Model:** FLEX 3
- **Android Version:** 13 (API 33)
- **Build:** TKQ1.220915.002 (user/release-keys)
- **Platform:** lahaina
- **Build Date:** 05.11.2025

## Problem Explanation

The Stripe Terminal SDK 5.2.0 requires **Trusted Execution Environment (TEE)** or **StrongBox** hardware-backed key attestation for security purposes. The SUNMI FLEX 3 device does not support these hardware security features, which is causing the initialization error.

### What is TEE/StrongBox?

- **TEE (Trusted Execution Environment):** A secure area within the main processor that ensures sensitive data is stored, processed, and protected in an isolated, trusted environment.
- **StrongBox:** An enhanced hardware security module (HSM) available on newer Android devices (API 28+) that provides even stronger key protection.

### Why Stripe Requires This

Stripe Terminal SDK uses hardware-backed key attestation to:

1. Verify the integrity of cryptographic keys
2. Ensure payment data is protected at the hardware level
3. Comply with PCI-DSS security standards
4. Prevent key extraction and tampering

## Current Implementation

The app has been updated with:

1. **Enhanced Error Detection:** Better logging to identify TEE/hardware attestation issues
2. **Device Capability Checking:** Automatic detection of TEE/StrongBox support
3. **Informative Error Messages:** Clear guidance when the device lacks required features
4. **ProGuard Rules:** Updated to preserve security-related classes

## Solutions

### Option 1: Use a Compatible Device (Recommended)

Replace the SUNMI FLEX 3 with a device that supports TEE/StrongBox:

**Recommended Devices for Stripe Tap to Pay:**

- **Google Pixel** (Pixel 4+) - Full StrongBox support
- **Samsung Galaxy S/Note** series (S9+, Note 9+)
- **OnePlus** (7+)
- **Most flagship devices from 2019+**

**Verification:** Use this command to check device support:

```bash
adb shell pm list features | grep android.hardware.strongbox
```

If you see `android.hardware.strongbox_keystore`, the device supports StrongBox.

### Option 2: Contact SUNMI Support

SUNMI may have:

1. **Firmware updates** that enable TEE support
2. **Special builds** for payment processing
3. **Alternative POS devices** in their lineup with TEE support

**Contact:** Check SUNMI's official support channels for device-specific guidance.

### Option 3: Contact Stripe Support

Stripe may have:

1. **Device-specific workarounds** for certain POS hardware
2. **SDK configuration options** to relax hardware requirements for specific use cases
3. **Alternative SDK versions** that work with software-only security

**Note:** Stripe typically requires hardware-backed security for production use, but they may have solutions for specific device types.

### Option 4: Downgrade SDK (Not Recommended)

Older versions of the Stripe Terminal SDK (pre-5.0) may have less strict hardware requirements, but:

- ⚠️ May not support latest Tap to Pay features
- ⚠️ May have security vulnerabilities
- ⚠️ May not comply with current PCI-DSS standards
- ⚠️ May not be supported by Stripe for new integrations

## Testing Checklist

Before deploying to production:

- [ ] Verify device has NFC hardware enabled
- [ ] Check for TEE/StrongBox support
- [ ] Test with a known-compatible device first
- [ ] Review Stripe Terminal SDK device compatibility list
- [ ] Confirm Google Play Services is up to date
- [ ] Test in simulated mode (if supported without TEE)

## Debug Information

The app now logs detailed device capability information on startup. Check logcat for:

```
StripeTerminal: Initializing Terminal SDK on SUNMI FLEX3 (API 33)
StripeTerminal: ⚠️  Device does not support hardware-backed security (TEE/StrongBox)
StripeTerminal:    Stripe Terminal will use software-based security instead
```

To view these logs:

```bash
adb logcat | grep StripeTerminal
```

## Technical Details

### Hardware Security Check Code

The app now includes a runtime check for device capabilities:

```kotlin
private fun logDeviceSecurityCapabilities() {
    // Attempts to create a test key with StrongBox requirement
    // Logs success or failure with device-specific information
}
```

This runs automatically on app startup and provides diagnostic information.

### ProGuard Rules Updated

Added rules to preserve security-related classes:

```proguard
-keep class android.security.keystore.** { *; }
-keep class java.security.** { *; }
-keep class javax.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
```

## Alternative Solutions for Development

If you need to develop/test without a TEE-capable device:

1. **Use Android Emulator:** Recent emulator images support software-backed KeyStore
2. **Simulated Reader Mode:** Stripe Terminal SDK supports simulated readers for testing
3. **Backend Integration Testing:** Test payment flows without actual card reading

## Additional Resources

- [Stripe Terminal SDK Documentation](https://stripe.com/docs/terminal)
- [Android KeyStore System](https://developer.android.com/training/articles/keystore)
- [Hardware-backed Keystore](https://source.android.com/docs/security/features/keystore)
- [StrongBox Documentation](https://developer.android.com/training/articles/keystore#HardwareSecurityModule)

## Support Contacts

- **Stripe Support:** https://support.stripe.com/
- **SUNMI Support:** https://www.sunmi.com/en-US/support/
- **Android KeyStore Issues:** https://issuetracker.google.com/

## Updated Files

The following files have been modified to handle this issue:

1. `android/app/src/main/kotlin/com/example/ai_kiosk_pos/MainActivity.kt`
   - Added device capability checking
   - Enhanced error logging
   - Added TEE/StrongBox detection

2. `android/app/proguard-rules.pro`
   - Added security class preservation rules
   - Added Tink crypto library rules

## Next Steps

1. **Immediate:** Review logcat output to confirm the exact error
2. **Short-term:** Test with a TEE-capable device if available
3. **Long-term:** Consider switching to recommended hardware for production deployment

---

**Last Updated:** February 26, 2026
**SDK Version:** Stripe Terminal 5.2.0
**Min SDK:** Android 26 (Android 8.0)
**Target SDK:** Android 33 (Android 13)
