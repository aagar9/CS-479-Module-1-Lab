# PPG Wearable – Fitness and Calm/Stress Monitoring

This repository contains the software developed for the PPG module of the Wearables and Nearables Technology Laboratory.

The project implements two main applications:

- **Task I – Fitness Mode**
- **Task II – Calm / Stress Detection**

An additional version of Task I also includes an **estimated calorie expenditure feature**.

---

## System Architecture

The wearable uses a peripheral/central BLE architecture:

MAX30101 / MAX32664  
→ Peripheral FireBeetle  
→ BLE  
→ Central FireBeetle  
→ USB / Serial  
→ Processing

The **peripheral FireBeetle** is connected to the PPG sensor and runs the Arduino firmware.

The **central FireBeetle** is connected to the computer and acts as a BLE-to-USB bridge.

The MAX32664 biometric hub performs the low-level PPG processing and provides already processed values such as:

- Heart rate
- SpO2
- Confidence
- Sensor status

The Processing applications therefore perform the higher-level logic, including signal validation, baseline acquisition, classification, graphing, and user-interface control.

---

# Repository Files

## `ppg1`

Processing application implementing **Task I – Fitness Mode**.

Before starting the task, the program checks whether the PPG signal has been reliably acquired using a rolling window containing the latest 10 HR samples.

A sample is considered valid when:

- `HR > 0`

The signal is accepted when:

- at least **7 of the latest 10 samples are valid**
- the most recent sample is also valid

After signal acquisition, a **30-second resting baseline** is recorded.

Resting HR is calculated as the mean of the valid HR samples acquired during this phase.

Signal quality is calculated as:

`valid samples / total received samples`

If baseline quality is below **70%**, the acquisition must be repeated.

### Fitness Mode

The estimated maximum heart rate is calculated as:

`HRmax = 220 - age`

Each valid HR measurement is expressed as a percentage of HRmax and assigned to the corresponding exercise-intensity zone.

The interface displays:

- Current HR
- Resting HR
- Average HR
- Beat interval
- SpO2
- Confidence
- Current cardio zone
- Activity time
- Classified time
- Signal quality
- Time spent in each cardio zone

The HR graph is color-coded according to the cardio zone.

When `HR = 0`, the sample is treated as missing data and is excluded from:

- HR averages
- cardio-zone classification
- zone-time accumulation
- graph points

This creates a graph gap instead of displaying an artificial HR value.

After pressing **STOP**, the complete session remains visible for review.

---

## `ppg_fitness_calories_no_age_limit`

Extended version of `ppg1`.

It implements the same **Fitness Mode**, while also estimating **energy expenditure and calories burned**.

The calorie calculation uses:

- Heart rate
- Age
- Sex
- Body mass

Energy expenditure is estimated from HR using sex-specific equations and is integrated over time.

Calorie integration is performed only during valid HR intervals.

If signal loss occurs, the integration is interrupted instead of estimating calories across missing data.

The interface additionally displays:

- Estimated calories

This feature is an additional project implementation and is not required for the basic Fitness Mode.

---

## `ppg2`

Processing application implementing **Task II – Calm / Stress Detection**.

The initial signal acquisition and 30-second resting baseline use the same logic as Task I.

The Task II workflow is:

Resting baseline  
→ Calm calibration  
→ Stress calibration  
→ Live detection

### Calm Calibration

During Calm calibration, HR is recorded while the user attempts to relax.

A **time-weighted mean HR** is calculated, giving slightly greater importance to the later samples of the calibration.

The calibration is accepted only if HR decreases by at least **1 bpm** relative to resting HR.

### Stress Calibration

During Stress calibration, HR is recorded while the user performs the stress task.

The Stress calibration must last at least **60 seconds**.

The same time-weighted averaging method is used.

The calibration is accepted only if HR increases by at least **1 bpm** relative to resting HR.

If a new calibration is too weak, the previously accepted calibration is retained.

### Live Detection

During live detection, the latest **10 HR samples** are stored in a rolling window.

If at least **7 of the 10 samples are valid**, a smoothed HR is calculated from the valid values.

The smoothed HR is compared with personalized Calm and Stress thresholds obtained from the calibration phase.

The possible detected states are:

- `CALM`
- `NEUTRAL`
- `STRESSED`

A **2-second persistence requirement** is used before confirming a state transition.

This prevents brief threshold crossings from being interpreted as real state changes.

The algorithm also uses **hysteresis**, with different entry and exit thresholds, to avoid repeated switching when HR oscillates near a decision boundary.

When a transition to `STRESSED` is confirmed, Processing sends the command:

`'B'`

to the wearable, which triggers two buzzer tones.

The Task II interface displays:

- Current HR
- Smoothed HR
- Resting HR
- Beat interval
- SpO2
- Confidence
- Calm threshold
- Stress threshold
- Current detected state
- Signal quality
- Detection time
- Measured and smoothed HR curves

---

# Arduino Firmware

## `arduino_sensor`

Arduino firmware used for **Task I**.

The peripheral FireBeetle communicates with the MAX32664 biometric hub and reads the processed biometric outputs.

The firmware transmits:

- Heart rate
- Confidence
- SpO2
- Status

The data flow is:

PPG sensor  
→ Peripheral FireBeetle  
→ BLE  
→ Central FireBeetle  
→ USB  
→ Processing

The Processing applications `ppg1` and `ppg_fitness_calories_no_age_limit` read these data and perform the application-level processing.

---

## `arduino_sensor_buzzer`

Arduino firmware used for **Task II**.

It performs the same sensor acquisition and transmission as `arduino_sensor`, but it also receives the buzzer command from Processing.

When the peripheral receives:

`'B'`

the buzzer produces two tones.

The feedback path is:

Processing detects `STRESSED`  
→ sends `'B'`  
→ Central FireBeetle  
→ BLE  
→ Peripheral FireBeetle  
→ buzzer sounds twice

---

# Processing Program Structure

The Processing applications use an event-driven structure.

## `setup()`

Runs once when the program starts.

It initializes:

- the graphical interface
- serial communication
- colors and layout variables
- program variables

## `draw()`

Runs continuously.

It is mainly responsible for:

- drawing the current interface screen
- updating graphical elements
- checking time-based transitions

Sensor sample counters are not updated inside `draw()`.

## `serialEvent()`

Runs whenever a complete sensor record is received.

It:

1. Reads the serial data.
2. Extracts HR, SpO2 and confidence.
3. Determines whether the HR sample is valid.
4. Records the sample time.
5. Sends the sample to the correct algorithm according to the current program state.

For example:

- `WAITING_SIGNAL` → update the 10-sample validity window
- `BASELINE` → process the resting-baseline sample
- `FITNESS_ACTIVE` → process the Fitness sample
- `CALM_ACTIVE / STRESS_ACTIVE` → process the calibration sample
- `DETECTION_ACTIVE` → update the live-detection algorithm

## `mousePressed()`

Runs only when the user clicks.

It handles actions such as:

- START
- STOP
- Retry
- Calm Calibration
- Stress Calibration
- Start Detection

---

# Data Quality Strategy

The software includes several checks to manage temporary PPG signal loss.

| Stage | Strategy |
|---|---|
| Initial acquisition | At least 7 valid samples among the latest 10 |
| Latest sample | Must also be valid |
| Resting baseline | 30-second acquisition |
| Baseline acceptance | At least 70% valid samples |
| Invalid HR | HR = 0 treated as missing data |
| Fitness graph | Missing samples shown as gaps |
| Task II | 10-sample rolling mean |
| State transition | 2-second persistence |
| State stability | Hysteresis with different entry/exit thresholds |

---

# Beat Interval

The beat interval displayed by the interface is estimated from the current HR as:

`Beat interval [ms] = 60000 / HR`

It is therefore an HR-derived estimate rather than a direct beat-to-beat measurement extracted from individual PPG peaks.

---

# How to Run

1. Pair the peripheral and central FireBeetle boards.
2. Upload the appropriate Arduino firmware to the peripheral board:
   - `arduino_sensor` for Task I
   - `arduino_sensor_buzzer` for Task II
3. Connect the central FireBeetle to the PC through USB.
4. Close the Arduino Serial Monitor.
5. Open the corresponding Processing application:
   - `ppg1`
   - `ppg_fitness_calories_no_age_limit`
   - `ppg2`
6. Select the correct serial port if necessary.
7. Position the PPG sensor correctly.
8. Wait for stable signal acquisition.
9. Follow the instructions shown in the Processing interface.

---

# File Summary

| File | Platform | Function |
|---|---|---|
| `ppg1` | Processing | Task I – Fitness Mode |
| `ppg_fitness_calories_no_age_limit` | Processing | Task I + calorie estimation |
| `ppg2` | Processing | Task II – Calm / Stress Detection |
| `arduino_sensor` | Arduino | PPG acquisition and transmission for Task I |
| `arduino_sensor_buzzer` | Arduino | PPG acquisition, transmission, and buzzer feedback for Task II |

---

## Notes

The MAX32664 performs the low-level PPG filtering and biometric processing.

The custom Processing software implements the application-level algorithms developed for this project, including:

- signal validation
- resting-HR estimation
- cardio-zone classification
- personalized Calm/Stress calibration
- temporal smoothing
- persistence
- hysteresis
- graphical visualization
- buzzer feedback
