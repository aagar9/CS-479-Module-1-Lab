# Group testing package (post-AI)

## Test these exact files

1. **Arduino IDE:** `Group_Test_Arduino/Group_Test_Arduino.ino`
2. **Processing IDE:** `Group_Test_Bundle/Group_Test_Bundle.pde`

The Processing sketch contains these original tabs, unchanged in logic:
- Heart_Breathing_Integrated.pde
- FitnessMode.pde
- MeditationMode.pde
- SignalProcessing.pde
- StressMode.pde

Firmware copied from: `lab2/pre-ai/First_Heart_Breathing_UI/arduino_Lab02.ino`

## Test order
1. Close Processing and the Arduino Serial Monitor before changing which app uses the serial port.
2. Upload the Arduino sketch to the FireBeetle using the correct board and port.
3. Open the single Processing `.pde` file. Confirm the serial port and baud rate match the board (the current UI may have a hardcoded `COM3`).
4. Verify live ECG and respiration data, HR/RR and inhale/exhale times.
5. Fitness: baseline, activity selection, all five animations (especially stairs), cardio zones, graphs, end/results.
6. Stress: all three 30-second calibration phases, monitoring status and graphs.
7. Meditation: baseline, 1:3 breathing target, alert after three consecutive missed breaths.
8. Test on Windows and macOS if available; record screenshots and Processing console errors.

**Important:** Combining files does not guarantee compilation or hardware compatibility. Test with the actual board. Do not open the original multi-tab sketch at the same time when checking this bundle.
