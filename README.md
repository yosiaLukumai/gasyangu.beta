<div align="center">

<!-- Replace the path below with the actual university logo file once available -->
<img src="build/image.png" alt="Arusha Technical College Logo" width="120"/>

# GasYangu

**Smart Gas Cylinder Weight Monitor**

*Project on Sensors and Actuators*

**Arusha Technical College**

Supervised by **Mr. Dickson** — MSc in Robotics

</div>

---

## Overview

GasYangu is an IoT system that continuously monitors the fill level of a domestic liquefied-petroleum gas (LPG) cylinder. A load cell mounted beneath the cylinder measures its weight; an ESP32 microcontroller processes the reading and broadcasts it over Bluetooth Low Energy (BLE). A Flutter companion app on a smartphone picks up the reading, converts it to a fill percentage, and presents it in a clear dashboard.

The system removes the common inconvenience of not knowing how much gas remains — no more shaking cylinders or running out unexpectedly.

---

## System Architecture

```
 ┌───────────────────────────────────────────┐
 │           GasYangu Hardware Node           │
 │                                           │
 │  Load Cell ──► HX711 ──► ESP32 DevKit     │
 │                            │              │
 │  Pushbutton ───────────────┤              │
 │  Potentiometer ────────────┤              │
 │  LCD Display ◄─────────────┘              │
 └───────────────────┬───────────────────────┘
                     │  Bluetooth Low Energy
                     │  (notify every 5 min
                     │   or on button press)
 ┌───────────────────▼───────────────────────┐
 │         GasYangu Mobile App (Flutter)      │
 │                                           │
 │  BLE scan → connect → subscribe           │
 │  Weight (kg) → fill percentage → UI       │
 └───────────────────────────────────────────┘
```

---

## Repository Structure

```
gasyangu/
├── firmware/
│   └── gasyangu/          # ESP32 PlatformIO project (C++ / Arduino)
│       ├── src/main.cpp   # All firmware logic
│       └── platformio.ini # Build configuration
│
├── gasyangu_app/          # Flutter companion app (Dart)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/          # App-wide constants and colors
│   │   ├── presentation/  # Screens (landing, home)
│   │   └── services/      # Local storage helpers
│   └── pubspec.yaml
│
├── CAD/                   # Mechanical design files (enclosure, mounting plate)
├── PCB/                   # PCB schematic and layout files
└── README.md              # This file
```

---

## Hardware

| Component | Purpose |
|---|---|
| ESP32 DevKit v1 | Main microcontroller — runs BLE and measurement logic |
| HX711 amplifier | Conditions the load cell signal for the ESP32 ADC |
| Load cell sensor | Measures the weight of the gas cylinder |
| LCD display (I2C) | Shows live weight, fill percentage, and menu prompts |
| Pushbutton | Short press → wake from sleep; long press → config menu |
| Potentiometer | Scrolls through and adjusts values in the config menu |

**Pin assignments**

| Signal | GPIO |
|---|---|
| HX711 DOUT | 18 |
| HX711 SCK | 19 |

---

## Firmware

Built with [PlatformIO](https://platformio.org/) targeting the ESP32 Arduino framework.

### Dependencies

| Library | Version |
|---|---|
| `bogde/HX711` | `^0.7.5` |
| `marcoschwartz/LiquidCrystal_I2C` | `^1.1.4` |

### Quick start

```bash
cd firmware/gasyangu

# Build
pio run

# Build and flash to connected ESP32
pio run --target upload

# Open serial monitor (115200 baud)
pio device monitor --baud 115200
```

See [`firmware/gasyangu/README.md`](firmware/gasyangu/README.md) for full details.

---

## Mobile App

Cross-platform Flutter app (Android, iOS, macOS, Windows, Linux, Web).

### Dependencies

| Package | Version |
|---|---|
| `flutter_blue_plus` | `^1.32.0` |
| `permission_handler` | `^11.0.0` |
| `shared_preferences` | `^2.3.0` |

### Quick start

```bash
cd gasyangu_app

flutter pub get
flutter run
```

See [`gasyangu_app/README.md`](gasyangu_app/README.md) for platform permission setup and full build commands.

---

## BLE Protocol

| Field | Value |
|---|---|
| Device name | `GasYangu` |
| Service UUID | `4fafc201-1fb5-459e-8fcc-c5c9c331914b` |
| Weight characteristic UUID | `beb5483e-36e1-4688-b7f5-ea07361b26a8` |
| Properties | READ + NOTIFY |
| Encoding | UTF-8 string, e.g. `"12.34"` |
| Unit | kilograms, 2 decimal places |
| Update rate | Every 5 minutes (timer) or immediately on hardware button press |

---

## Configuration

The firmware configuration menu (accessed via long press on the pushbutton) lets you set:

- **Dead weight** — empty cylinder weight (kg)
- **Full weight** — full cylinder weight (kg)

The firmware uses these to calculate the fill percentage displayed on the LCD and transmitted to the app.

---

## Academic Context

| | |
|---|---|
| **Institution** | Arusha Technical College (ATC), Arusha, Tanzania |
| **Programme** | Bachelors in Mechatronics and Material Engineering |
| **Supervisor** | Mr. Dickson, MSc in Robotics |
| **Purpose** | Final-year capstone project |

---

## License

This project is licensed under the [MIT License](LICENSE).