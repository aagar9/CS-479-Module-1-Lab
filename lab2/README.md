# BME/CS 479 – Lab 2

## Heart Rate and Breathing Rate Wearable

## Overview

The goal of Lab 2 is to develop a wearable chest strap capable of monitoring a user's heart rate and respiratory rate.

The system uses an AD8232 heart monitor to collect an ECG signal and a Force Sensitive Resistor (FSR) to measure changes associated with inhalation and exhalation.

The collected signals will be processed and displayed through a Processing-based user interface.

---

## Hardware

The Lab 2 wearable uses:

- FireBeetle Board-328P with BLE 4.1
- Micro USB Interface Cable
- Rechargeable Lithium Battery
- FireBeetle Proto Board
- AD8232 Heart Monitor
- ECG Leads
- Snap-On ECG Electrodes
- Force Sensitive Resistor (FSR)
- 10 kOhm Resistor
- Elastic Band
- Tape or Glue
- 3D Printed FSR Backing
- 3D Printed Clasp
- Wire and Wire Wrapping Tool
- Solder and Soldering Iron
- Athletic Tape
- Female Headers

---

## System Design

The wearable collects two primary biosignals:

### ECG

The AD8232 heart monitor records the user's ECG signal.

The ECG signal will be used to calculate and display:

- Heart rate
- Resting heart rate
- Cardio zone
- ECG activity over time

### Respiration

The FSR detects changes caused by expansion and contraction of the chest during inhalation and exhalation.

The respiratory signal will be used to calculate and display:

- Respiratory rate
- Resting respiratory rate
- Inhalation duration
- Exhalation duration
- Respiratory activity over time

---

## User Interface

The user interface is being developed using **Processing (Java Mode)**.

The interface provides three primary operating modes:

1. Fitness Mode
2. Stress Monitoring Mode
3. Meditation Mode

The initial rough Processing UI prototype is located at:

`First_Heart_Breathing_UI/First_Heart_Breathing_UI.pde`

The initial UI currently uses simulated values and placeholder graphs. These will later be replaced with data collected from the wearable sensors.

---

## Fitness Mode

Fitness Mode will begin by collecting a **30-second baseline** from the user.

The baseline will be used to determine:

- Resting heart rate
- Resting respiratory rate

After baseline collection, the interface will display the user's current cardio zone.

Maximum heart rate will be estimated using:

`Maximum Heart Rate = 220 - age`

During physical activity, the interface will monitor the user's ECG and respiratory signals.

The interface will display:

- Current heart rate
- Current respiratory rate
- Cardio zone
- ECG activity
- Cardio-zone activity
- Respiratory activity
- Inhalation duration
- Exhalation duration

The activity graph will eventually be color-coded based on the amount of time spent in each cardio zone.

---

## Stress Monitoring Mode

Stress Monitoring Mode will also begin by collecting a **30-second baseline**.

The baseline will be used to determine:

- Resting heart rate
- Resting respiratory rate

The user's heart rate and respiratory rate will then be monitored during different activities.

The interface will compare the collected data with the user's baseline and use the input analysis to determine whether the user is:

- Calm
- Stressed

The final interface will automatically display the detected state.

---

## Meditation Mode

Meditation Mode will begin by collecting a **30-second baseline**.

The baseline will display:

- Resting heart rate
- Resting respiratory rate

During meditation, the interface will monitor:

- Current heart rate
- Current respiratory rate
- Inhalation duration
- Exhalation duration

The target breathing pattern is:

`Inhalation Period = 1/3 of Exhalation Period`

The interface will continually determine whether the user is maintaining this breathing pattern.

If the breathing criterion is not met for **three consecutive breaths**, an indicator will be activated on the interface.

---

## Required Interface Graphs

The final interface must display all three required graphs:

1. ECG
2. Cardio Zone
3. Respiratory Signal

The respiratory portion of the interface will also display:

- Respiratory rate
- Inhalation duration
- Exhalation duration

---

## Signal Processing

The ECG and respiratory signals may require signal processing to reduce noise and improve the accuracy of the calculated measurements.

Future development may include:

- Signal filtering
- Peak detection
- Heartbeat detection
- Breath detection
- Baseline calculation
- Heart-rate calculation
- Respiratory-rate calculation
- Inhalation and exhalation detection

---

## Current Progress

### Completed

- Repository reorganized into separate `lab1` and `lab2` folders
- Processing development environment configured
- Initial Processing UI created
- Fitness Mode button implemented
- Stress Monitoring Mode button implemented
- Meditation Mode button implemented
- Mode switching implemented
- Initial heart-rate display implemented using placeholder data
- Initial respiratory-rate display implemented using placeholder data
- Initial ECG graph implemented using simulated data
- Initial cardio-zone display implemented
- Initial respiratory graph implemented using simulated data
- Initial Stress Mode screen implemented
- Initial Meditation Mode screen implemented

### In Progress

- 30-second baseline collection
- FireBeetle integration
- AD8232 ECG sensor integration
- FSR respiratory sensor integration
- Live sensor communication with Processing
- ECG signal processing
- Heart-rate calculation
- Respiratory-rate calculation
- Inhalation and exhalation detection
- Cardio-zone calculation
- Cardio-zone activity graph
- Stress/calm classification
- Meditation breathing-pattern detection
- Three-consecutive-breath warning indicator

---

## Project Structure

```text
lab2/
├── README.md
└── First_Heart_Breathing_UI/
    └── First_Heart_Breathing_UI.pde