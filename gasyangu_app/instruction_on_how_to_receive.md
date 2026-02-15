# How to receive weight data from GasYangu (Flutter / flutter_blue_plus)

## Constants

Define these once, shared across your BLE code:

```dart
const String kDeviceName   = 'GasYangu';
const String kServiceUuid  = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
const String kWeightUuid   = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
```

---

## Step 1 – Scan for the device

```dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

BluetoothDevice? foundDevice;

void startScan() {
  FlutterBluePlus.startScan(
    withServices: [Guid(kServiceUuid)],
    timeout: const Duration(seconds: 10),
  );

  FlutterBluePlus.scanResults.listen((results) {
    for (final r in results) {
      if (r.device.platformName == kDeviceName) {
        foundDevice = r.device;
        FlutterBluePlus.stopScan();
        connect(foundDevice!);
        break;
      }
    }
  });
}
```

Filtering by `withServices` means only devices advertising the GasYangu service UUID appear — no need to check the name explicitly, but it adds a safety check.

---

## Step 2 – Connect

```dart
Future<void> connect(BluetoothDevice device) async {
  await device.connect(autoConnect: false);
  discoverAndSubscribe(device);
}
```

---

## Step 3 – Discover service and subscribe to notifications

```dart
Future<void> discoverAndSubscribe(BluetoothDevice device) async {
  final services = await device.discoverServices();

  for (final service in services) {
    if (service.uuid == Guid(kServiceUuid)) {
      for (final char in service.characteristics) {
        if (char.uuid == Guid(kWeightUuid)) {
          // Enable notifications
          await char.setNotifyValue(true);

          // Listen for incoming weight values
          char.lastValueStream.listen((value) {
            if (value.isNotEmpty) {
              final raw    = String.fromCharCodes(value);
              final weight = double.tryParse(raw);
              if (weight != null) {
                onWeightReceived(weight);
              }
            }
          });

          // Also read the last known value immediately on connect
          final initial = await char.read();
          if (initial.isNotEmpty) {
            final weight = double.tryParse(String.fromCharCodes(initial));
            if (weight != null) onWeightReceived(weight);
          }
        }
      }
    }
  }
}

void onWeightReceived(double weightKg) {
  // Update your state / UI here
  print('Weight: $weightKg kg');
}
```

---

## Step 4 – Handle disconnection and reconnect

The ESP32 sleeps between readings. Any active BLE connection is dropped during sleep. Listen for the disconnect event and attempt to reconnect — the device will re-advertise on the next wakeup (at most 5 minutes later, or immediately on button press).

```dart
void listenForDisconnect(BluetoothDevice device) {
  device.connectionState.listen((state) {
    if (state == BluetoothConnectionState.disconnected) {
      // Wait for the device to start advertising again, then scan
      Future.delayed(const Duration(seconds: 5), startScan);
    }
  });
}
```

Call `listenForDisconnect(device)` right after `connect()` returns.

---

## Data format reference

| Field       | Detail                                          |
|-------------|------------------------------------------------|
| Encoding    | UTF-8 string                                   |
| Example     | `"12.34"`                                      |
| Unit        | kilograms (kg)                                 |
| Precision   | 2 decimal places                               |
| Update rate | Every 5 minutes (timer) or on button press     |

---

## Minimal working example (StatefulWidget)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

const kServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
const kWeightUuid  = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';

class GasYanguPage extends StatefulWidget {
  const GasYanguPage({super.key});
  @override
  State<GasYanguPage> createState() => _GasYanguPageState();
}

class _GasYanguPageState extends State<GasYanguPage> {
  double? _weightKg;
  String  _status = 'Scanning...';

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() {
    setState(() => _status = 'Scanning...');
    FlutterBluePlus.startScan(
      withServices: [Guid(kServiceUuid)],
      timeout: const Duration(seconds: 10),
    );
    FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.device.platformName == 'GasYangu') {
          FlutterBluePlus.stopScan();
          _connect(r.device);
          break;
        }
      }
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() => _status = 'Connecting...');
    await device.connect(autoConnect: false);
    setState(() => _status = 'Connected');

    device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected) {
        setState(() { _status = 'Disconnected – reconnecting...'; });
        Future.delayed(const Duration(seconds: 5), _startScan);
      }
    });

    final services = await device.discoverServices();
    for (final svc in services) {
      if (svc.uuid != Guid(kServiceUuid)) continue;
      for (final c in svc.characteristics) {
        if (c.uuid != Guid(kWeightUuid)) continue;
        await c.setNotifyValue(true);
        c.lastValueStream.listen((v) {
          final w = double.tryParse(String.fromCharCodes(v));
          if (w != null) setState(() => _weightKg = w);
        });
        final initial = await c.read();
        final w = double.tryParse(String.fromCharCodes(initial));
        if (w != null) setState(() => _weightKg = w);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GasYangu')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status),
            const SizedBox(height: 24),
            Text(
              _weightKg != null ? '${_weightKg!.toStringAsFixed(2)} kg' : '--',
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
```