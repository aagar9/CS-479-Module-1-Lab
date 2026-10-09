# Pre-AI group testing package

## Exact files to open
- **Processing:** `Pre_AI_Group_Test/Pre_AI_Group_Test.pde`
- **Arduino IDE:** `Pre_AI_Arduino/Pre_AI_Arduino.ino`

## Testing checklist
1. Select the correct FireBeetle board and port in Arduino IDE. Verify, then upload firmware.
2. Close Arduino Serial Monitor before starting Processing (only one app can own the port).
3. Open the Processing `.pde` and press Run. Confirm it compiles.
4. Confirm serial port connects and ECG and FSR graphs receive live samples.
5. Test ECG lead removal and reconnection; Arduino sends `!,FSR` when leads are off.
6. Test Home, Fitness, Stress and Meditation buttons and 30-second baseline behavior.
7. Record screenshots, actual HR/RR readings, and any compilation or serial errors.

## Notes
The Processing source is consolidated from the three existing pre-AI tabs.
The additional `Hearth_breathing_integrated.pde` is deliberately excluded because it is a separate overlapping sketch.
The firmware is copied from `arduino_Lab02.ino`.
The bundle is not hardware-validated by this script.
