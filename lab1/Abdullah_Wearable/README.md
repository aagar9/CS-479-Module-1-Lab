# Wearable PPG Monitor — BME/CS 479

Arduino firmware and a single-file Processing interface for the wearable heart-rate and blood-oxygen lab project.

## Files

- `WearableLabComplete/WearableLabComplete.pde`: Processing application. Open this file in Processing; keep its enclosing folder name unchanged.
- `WearableLabSensor/WearableLabSensor.ino`: firmware for the wearable FireBeetle carrying BOTH the PPG sensor and buzzer.

No separate Java source files, verification tools, recordings, or exported participant data are needed to run the application.

## Hardware and wiring

Two already-paired DFRobot FireBeetle 328P BLE 4.1 boards, a SparkFun MAX30101/MAX32664 sensor board, and a buzzer. This setup assumes the existing BLE pairing and transport configuration; these sketches do not establish pairing.

| Wearable FireBeetle | Sensor board |
| --- | --- |
| 3V3 | 3V3 |
| GND | GND |
| SDA | SDA |
| SCL | SCL |
| D4 | RST |
| D5 | MFIO |

Buzzer positive connects to D12; negative connects to GND. The USB-connected FireBeetle has no external sensor or buzzer.

## Run Processing

1. Install Processing 4 (developed with 4.5.6). Its desktop distribution includes a Java runtime; no separate Java installation is needed.
2. Ensure the Processing Serial library is available (`processing.serial`).
3. Copy the entire `WearableLabComplete` folder and open its `.pde` file.
4. Connect the empty bridge board by USB and power the paired wearable board.
5. Close Arduino Serial Monitor and other applications using the serial port.
6. Run the sketch and select the bridge's actual port on the setup screen. COM3 is only the original computer's default. Communication uses 115200 baud.
7. Check live readings and use Test buzzer. Enter the wearer's age and record a new resting baseline and calibrations.

If the boards already have the correct firmware, uploading Arduino code again is unnecessary.

## Upload Arduino firmware

Install Arduino IDE, the board support for your FireBeetle, and **SparkFun Bio Sensor Hub Library** through Library Manager. `Wire` comes with the Arduino core. Use the board configuration previously confirmed for the physical FireBeetle 328P, which runs at 3.3 V / 8 MHz.

1. Stop Processing and close Serial Monitor.
2. Disconnect/power off the computer-side FireBeetle. Connect the sensor-and-buzzer board directly by USB and upload `WearableLabSensor` to it.
3. Restore normal power and the existing paired wireless arrangement, then run Processing.

Keep only the intended target powered during the upload: the paired FireBeetle link supports wireless programming. The computer-side board is already configured and needs no sketch from this package.

## Application behavior

- Heart rate, oxygen saturation, confidence, and signal-quality display.
- 30-second resting baseline.
- Fitness mode with colored heart-rate zones, recovery graph, and time in each zone.
- Calm calibration lasting at least 30 seconds and stress calibration lasting 60 seconds.
- Monitoring uses smoothed heart rate and requires a sustained threshold crossing for 2 seconds before entering STRESSED. Entry triggers two beeps; it does not continuously repeat while remaining STRESSED.
- Test buzzer sends the same command path and displays board acknowledgments.
- Raw PPG pulse-interval detection; legacy heart-rate-only data uses a clearly labeled estimated interval.
- Optional CSV export. Generated exports are ignored by Git.

If calibration has sufficient valid data but does not produce the expected heart-rate change, the interface labels its fallback thresholds as defaults. Stress labels are heart-rate-based classifications, not confirmation of a person's emotional state.

## Signal failures and validation

Firmware checks sensor replies, rejects incomplete samples, and attempts sensor reinitialization after failures. Processing clears stale readings on sensor faults. Persistent FIFO errors still require checking sensor power and connections.

Before packaging, the source version was compiled for AVR ATmega328P 3.3 V / 8 MHz (Arduino AVR core 1.8.6), and the Processing version passed 36 behavior checks. This package preserves those source files unchanged. Physical fault recovery, long-duration BLE reliability, and operation on another computer have not been verified here.

Raw packets are limited to 25 per second. Pulse intervals therefore have roughly 40 ms sample spacing plus polling jitter; they are not ECG beat-interval measurements.

## Add to the shared GitHub repository

Copy the two sketch folders, this README, and `.gitignore` into the desired project directory of the shared repository. Preserve each sketch's folder and filename. If that repository already has a README or `.gitignore`, merge these contents rather than replacing the existing files.

Review and commit the files through your usual GitHub workflow. Do not upload the ZIP itself as a substitute for the source folders. No license is assigned by this package; the team can choose one if needed.

