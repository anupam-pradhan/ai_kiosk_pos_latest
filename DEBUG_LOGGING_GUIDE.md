# Debug Logging Guide for Stripe Terminal on SUNMI FLEX 3

## Quick Start - Watch Logs Live

```bash
# Method 1: Use our watch script (recommended)
cd /Users/anupampradhan/Desktop/ai_kiosk_pos_latest
chmod +x watch_logs.sh
./watch_logs.sh
```

This will show color-coded logs in real-time:

- 🔴 Red = Errors
- 🟢 Green = Success
- 🟡 Yellow = Warnings
- 🔵 Cyan = SUNMI-specific messages

## Collect Full Logs for Analysis

```bash
# Method 2: Collect all logs to file
chmod +x collect_logs.sh
./collect_logs.sh

# This creates: stripe_terminal_logs_YYYYMMDD_HHMMSS.txt
```

## Manual Log Commands

### View All Stripe Terminal Logs

```bash
adb logcat -c  # Clear old logs
adb logcat | grep -E "StripeTerminal|Stripe|Terminal"
```

### View Only Errors

```bash
adb logcat *:E | grep -E "Stripe|Terminal|MainActivity"
```

### View Initialization Logs

```bash
adb logcat | grep -E "Terminal.*init|initialized|Terminal pre-initialized"
```

### View TEE/StrongBox Messages

```bash
adb logcat | grep -E "TEE|StrongBox|KeyStore|attestation|hardware"
```

### View NFC Activity

```bash
adb logcat | grep -E "NFC|nfc|prewarmup|Reader"
```

## Filter by Time

```bash
# Last 100 lines
adb logcat -t 100

# Last 5 minutes
adb logcat -t '01-01 00:00:00.000'

# Since app start
adb logcat -c && flutter run
# Then in another terminal:
adb logcat | grep Stripe
```

## Save Logs to File

```bash
# Capture next 2 minutes of logs
adb logcat > debug_logs.txt
# Press Ctrl+C after test
```

## What to Look For

### ✅ Successful Initialization

```
StripeTerminal: Initializing Terminal SDK on SUNMI FLEX3
StripeTerminal: Terminal pre-initialized at startup ✅
StripeTerminal: SUNMI FLEX3 is OFFICIALLY SUPPORTED by Stripe
StripeTerminal: Device will use SOFTWARE key attestation (this is OK)
StripeTerminal: Terminal initialized successfully
```

### ❌ TEE Error (Before Fix)

```
StripeTerminal: Terminal initialization failed: SecurityException
Device does not use Trusted Execution Environment, or does not support hardware-backed key attestation.
```

### ⚠️ Expected SUNMI Warnings

```
StripeTerminal: ⚠️  Device does not support hardware-backed security (TEE/StrongBox)
StripeTerminal:    Stripe Terminal will use software-based security instead
```

**This is NORMAL for SUNMI - not an error!**

### 🔍 Component Download

```
StripeTerminal: Downloading Tap to Pay components...
StripeTerminal: Download progress: 45%
StripeTerminal: Download complete
```

## Debug While Running App

### Terminal 1: Run App

```bash
cd /Users/anupampradhan/Desktop/ai_kiosk_pos_latest
flutter run
```

### Terminal 2: Watch Logs

```bash
./watch_logs.sh
```

### Terminal 3: Interact

```bash
# Trigger payment
# Watch logs in Terminal 2 in real-time
```

## Check Specific Issues

### Check if Terminal Initialized

```bash
adb logcat -d | grep "Terminal.*initialized"
```

### Check for Exceptions

```bash
adb logcat -d | grep -E "Exception|FATAL"
```

### Check Google Play Services

```bash
adb shell dumpsys package com.google.android.gms | grep versionName
```

### Check App Permissions

```bash
adb shell dumpsys package com.example.ai_kiosk_pos | grep -A 20 "runtime permissions"
```

### Check NFC Status

```bash
adb shell settings get secure nfc_on
# 1 = enabled, 0 = disabled
```

## Advanced Debugging

### Increase Log Buffer Size

```bash
adb logcat -G 16M  # Set to 16MB
adb logcat -g      # Check current size
```

### Filter Multiple Tags

```bash
adb logcat StripeTerminal:V MainActivity:V flutter:V *:S
```

Tag meanings:

- `V` = Verbose (everything)
- `D` = Debug
- `I` = Info
- `W` = Warning
- `E` = Error
- `S` = Silent (hide)

### Export to Computer and Analyze

```bash
# Collect logs
./collect_logs.sh

# View in VS Code
code stripe_terminal_logs_*.txt

# Search for errors
grep -i "error\|exception\|fail" stripe_terminal_logs_*.txt

# Search for success
grep -i "success\|connected\|initialized" stripe_terminal_logs_*.txt
```

## Real-Time Testing Workflow

1. **Clear logs:**

   ```bash
   adb logcat -c
   ```

2. **Start watching:**

   ```bash
   ./watch_logs.sh
   ```

3. **In another terminal, run app:**

   ```bash
   flutter run
   ```

4. **Test payment flow** and watch logs update in real-time

5. **Save logs if error occurs:**
   ```bash
   # In watch terminal: Press Ctrl+C
   # Then:
   ./collect_logs.sh
   ```

## Troubleshooting Log Issues

### No Logs Appearing?

```bash
# Check if device is connected
adb devices

# Check if app is running
adb shell pidof com.example.ai_kiosk_pos

# Restart adb server
adb kill-server
adb start-server
```

### Too Many Logs?

```bash
# Use stricter filter
adb logcat StripeTerminal:V *:S

# Or just errors
adb logcat StripeTerminal:E *:S
```

### App Crashes Before Logs?

```bash
# Check crash logs
adb logcat -d | grep "FATAL\|AndroidRuntime"

# Or use our script
./collect_logs.sh
# Then search for "FATAL" in the file
```

## Share Logs with Support

When contacting Stripe or SUNMI support:

1. **Collect full logs:**

   ```bash
   ./collect_logs.sh
   ```

2. **Reproduce the issue** while logs are being collected

3. **Send the generated file** (stripe*terminal_logs*\*.txt)

4. **Include specific error messages** from the logs

## Common Log Patterns

### Initialization Sequence (Normal)

```
01:23:45.678 StripeTerminal: Initializing Terminal SDK
01:23:45.789 StripeTerminal: Token provider configured
01:23:45.890 StripeTerminal: Terminal pre-initialized ✅
01:23:46.123 StripeTerminal: Device security check
01:23:46.234 StripeTerminal: ⚠️ Software key attestation
01:23:46.345 StripeTerminal: NFC prewarmup started
```

### Payment Flow (Normal)

```
01:30:00.123 StripeTerminal: Starting payment
01:30:00.234 StripeTerminal: Discovering readers...
01:30:00.567 StripeTerminal: Reader found: FLEX3_MOBILE
01:30:00.890 StripeTerminal: Connecting to reader...
01:30:01.234 StripeTerminal: Reader connected ✅
01:30:01.567 StripeTerminal: Retrieving payment intent...
01:30:01.890 StripeTerminal: Collecting payment method...
01:30:15.123 StripeTerminal: Card detected
01:30:16.456 StripeTerminal: Payment collected
01:30:17.789 StripeTerminal: Payment confirmed ✅
```

## Quick Reference Commands

| What                    | Command                           |
| ----------------------- | --------------------------------- |
| **Live logs (colored)** | `./watch_logs.sh`                 |
| **Save all logs**       | `./collect_logs.sh`               |
| **Clear logs**          | `adb logcat -c`                   |
| **Only errors**         | `adb logcat *:E`                  |
| **Stripe only**         | `adb logcat StripeTerminal:V *:S` |
| **Last 100 lines**      | `adb logcat -t 100`               |
| **Check crashes**       | `adb logcat -d \| grep FATAL`     |

---

**Pro Tip:** Keep `./watch_logs.sh` running in a separate terminal window whenever testing. You'll see exactly what's happening in real-time!
