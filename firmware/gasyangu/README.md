# GasYangu Firmware

GasYangu Firmware is a lightweight ESP32-based system for monitoring domestic gas usage using a load cell.  
The firmware measures the weight of the gas cylinder, forwards the data via Bluetooth, and integrates with the **GasYangu mobile app** for calibration and visualization.

---

## Features
- **Load Cell Measurement**: Uses HX711 to measure cylinder weight.
- **Bluetooth Communication**: Sends weight data to the GasYangu mobile app.
- **App-Based Calibration**: Calibration (tare, full weight, dead weight) is handled entirely in the mobile app.
- **User Interface**:
  - **Pushbutton**:  
    - Short press → Wake device from sleep.  
    - Long press → Enter configuration menu.  
  - **Potentiometer**: Used for adjusting values in the configuration menu.
  - **LCD Display**: Shows current status, weight, and configuration prompts.

---

## Configuration Menu
The configuration menu allows the user to set:
- **Dead Weight**: The empty cylinder weight.
- **Full Weight**: The maximum (full cylinder) weight.

Using these values, the firmware calculates the **fill percentage** of the cylinder.

**Navigation:**
- Press button → Confirm selection / enter next step.
- Rotate potentiometer → Adjust values.

---

## Mobile App Integration
- The ESP32 forwards weight readings via Bluetooth.
- The GasYangu mobile app:
  - Handles calibration.
  - Displays cylinder fill percentage.
  - Provides a user-friendly interface for monitoring gas levels.

---

##  Hardware Requirements
- ESP32 DevKit
- HX711 load cell amplifier
- Load cell sensor
- Pushbutton
- Potentiometer
- LCD display
- GasYangu mobile app (for calibration and monitoring)

---

## License
This project is licensed under the MIT License.
