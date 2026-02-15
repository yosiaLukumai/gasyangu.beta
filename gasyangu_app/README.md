# GasYangu Flutter App

Companion mobile app for the GasYangu ESP32 gas cylinder monitor. Connects to the device over BLE and displays real-time weight readings.

## What it does

- Scans for the GasYangu BLE device by name
- Connects and subscribes to weight notifications
- Displays the current cylinder weight in kg
- Receives updates every 5 minutes (timer-driven from the device) or immediately after a manual button press on the hardware

## Dependency

```yaml
# pubspec.yaml
dependencies:
  flutter_blue_plus: ^1.32.0
```

## Platform setup

**Android** — add to `android/app/src/main/AndroidManifest.xml` inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<!-- Legacy – required for Android 11 and below -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

**iOS** — add to `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>GasYangu needs Bluetooth to read the gas cylinder sensor.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>GasYangu needs Bluetooth to read the gas cylinder sensor.</string>
```

## BLE identifiers

| Field              | Value                                  |
|--------------------|----------------------------------------|
| Device name        | `GasYangu`                             |
| Service UUID       | `4fafc201-1fb5-459e-8fcc-c5c9c331914b` |
| Characteristic UUID| `beb5483e-36e1-4688-b7f5-ea07361b26a8` |
| Properties         | READ + NOTIFY                          |

## Data format

The characteristic value is a plain UTF-8 string — the weight in kilograms rounded to 2 decimal places:

```
"12.34"
```

Parse with:

```dart
double weight = double.parse(String.fromCharCodes(value));
```

## Connection behaviour

The ESP32 sleeps between readings and wakes every 5 minutes to publish. When the device wakes:

1. It re-starts BLE advertising
2. Updates the characteristic value and notifies any connected client
3. Goes back to sleep

If the app was connected before the device slept, the connection is dropped during sleep. The app should listen for disconnection events and attempt to reconnect — the device will be advertising again within 5 minutes (or immediately after a button press).

The characteristic value is always READ-able, so the app can fetch the last known reading on reconnect without waiting for a notification.