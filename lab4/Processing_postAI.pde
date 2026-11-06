import processing.serial.*;
import java.util.Locale;

// ========== SERIAL COMMUNICATION ==========
final String PORT = "COM3";
final int BAUD = 115200;
final int DATA_TIMEOUT = 1500;                    // No valid packet for 1.5 s = interrupted data
Serial port;
int lastData = -1;                               // Processing time of last valid CSV packet
String serialError = "";
boolean mpuOK = false;
float[] accel = new float[3];                    // ax, ay, az [m/s^2]
float[] gyro = new float[3];                     // gx, gy, gz [rad/s]

// ========== FSR MOVING AVERAGE ==========
final int FSR_WINDOW_SIZE = 3;                   // Number of samples in each moving window
float[][] fsrWindow = new float[4][FSR_WINDOW_SIZE];
// Matrix: 4 ROWS (one per FSR), 3 COLUMNS (successive sample slots).
// fsrWindow[i][fsrPos] = slot fsrPos for sensor i. The oldest slot is overwritten.
float[] fsrSum = new float[4];                   // Running sum of each sensor's window
float[] fsr = new float[4];                      // Filtered values (ADC) shared by all sections
int fsrPos = 0;                                 // Next column to replace (0, 1, 2, then 0...)
int fsrCount = 0;                               // Number of filled columns during startup

// ========== GRAPH HISTORY ==========
final int GRAPH_MS = 12000;
final int HISTORY_N = 600;                       // 600 samples at 25 Hz = up to 24 s of history
int[] graphTime = new int[HISTORY_N];           // Time stamp of each stored FSR sample
float[][] graphFSR = new float[4][HISTORY_N];   // [sensor][time index]: same index for all 4
int graphPos = 0;                               // Next slot to overwrite in circular history
int graphCount = 0;
int[] graphColor = new int[4];
String[] fsrName = {"Medial Forefoot", "Lateral Forefoot", "Medial Midfoot", "Heel"};

// ========== UI AND TEST CONTROL ==========
final int SECTION_I_MS = 120000;
final int SECTION_II_MS = 30000;
int section = 0;                                // Tabs: 0=I, 1=II, 2=III, 3=IV
boolean recording = false;                     // One active recording at a time
int test = -1;                                  // -1=I; 0..4=II calibration; 5=recognition; 6=III; 7=IV
int startMs = 0;
int elapsedI = 0, elapsedII = 0, elapsedIII = 0, elapsedIV = 0;
int field = -1;                                 // -1=no active input; 0=first; 1=second

// ========== SECTION I: WALKING ==========
final int CONTACT_ON = 400;                     // High threshold, SUM of four FSRs (0..4092)
final int CONTACT_OFF = 180;                    // Lower threshold: hysteresis prevents double counts
final int MIN_STRIDE_MS = 500;
boolean footDown = false;
boolean sectionIResult = false;
boolean interruptedI = false;                   // Remember if data stopped during the test
int contacts = 0;                               // Contacts of the ONE instrumented foot
long firstContact = -1, lastContact = -1;       // Arduino times, -1 = not assigned yet
String stepLength = "", stepWidth = "";
String noteI = "";

// ========== SECTION II: FIVE GAIT PROFILES ==========
final float AMBIG_MARGIN = 5.0f;                // Min distance separation for unambiguous match
String[] gait = {"Normal", "In-toeing", "Out-toeing", "Tiptoeing", "Heel walking"};
float[] refMFP = new float[5];                   // Mean Medial Force Percentage reference
float[] refFFP = new float[5];                   // Mean Forefoot Force Percentage reference
boolean[] hasRef = new boolean[5];              // True when a profile has been calibrated/saved
int editing = -1;                               // Profile whose MFP/FFP text fields are open
String[] editText = {"", ""};                    // User-entered MFP and FFP values
float sumMFP = 0, sumFFP = 0;
int validSamples = 0;
float resultMFP = Float.NaN, resultFFP = Float.NaN;
String detected = "--", noteII = "";
boolean interruptedII = false;

// ========== SECTION III: MOTION DETECTION ==========
final int IMU_WINDOW_SIZE = 4;
final int MOTION_ON_MS = 160;                  // Motion must persist 160 ms before changing state
final int STILL_MS = 500;                      // Both measures below threshold for 500 ms => STILL
final float ACC_THRESHOLD = 0.8f;               // Initial acceleration threshold [m/s^2]
final float GYRO_THRESHOLD = 0.40f;             // Initial angular velocity threshold [rad/s]
float[] aWindow = new float[IMU_WINDOW_SIZE];   // Last 4 values of | |a_vector| - 9.81 |
float[] wWindow = new float[IMU_WINDOW_SIZE];   // Last 4 angular-speed magnitudes
float aSum = 0, wSum = 0;
float aMotion = 0, wMotion = 0;                 // Filtered measures shown in Section III
int imuPos = 0, imuCount = 0;
boolean inMotion = false;
long lastImuTime = -1, belowSince = -1, aboveSince = -1; // MPU timestamps; -1=unset
long activityMs = 0;
String noteIII = "";

// ========== SECTION IV: SINGLE-LEG BALANCE ==========
final int IV_CAL_MS = 5000;                     // Separate 5 s reference acquisition
final int IV_EXERCISE_MS = 15000;                // Separate 15 s exercise
// 0=not calibrated, 1=calibrating, 2=reference ready, 3=exercising, 4=results
int ivPhase = 0;
final int MIN_PERCENT_TOTAL = 30;               // Below this total, MFP/FFP ratios are undefined
final float MFP_TOL = 6, FFP_TOL = 6;           // Balance bands in percentage points
final float HEEL_TOL = 80;                      // Heel target tolerance [ADC]
float[] refIV = new float[3];                    // Reference: MFP%, FFP%, HEEL ADC
float[] refSumIV = new float[3];                 // Accumulate reference during calibration only
float[] targetIV = new float[3];                 // Active exercise target lines
float[] accRef = new float[3];                   // Mean acceleration reference [m/s^2]
float[] accRefSum = new float[3];
int refSamples = 0;
boolean refReady = false;
long[] insideMs = new long[3];                   // Balance: duration within each target band
long exerciseMs = 0;                            // Sum of consecutive valid sample intervals
long lastBalanceTime = -1;
float tiltNow = Float.NaN;                       // Original unsigned tilt from reference
float angleSquares = 0, gyroSquares = 0;         // Original tilt/gyro RMS accumulators
int imuSamplesIV = 0;
// NEW: signed AP/ML relative tilt (not the anatomical ankle joint angle).
// Assumed mounting: +Y along shank, +X posterior, Z mediolateral; verify signs on shoe.
float[] tiltRefIV = new float[2];                // [AP, ML] reference orientation [deg]
float[] tiltSumIV = new float[2];                // Signed exercise angle sums [deg]
int tiltSamplesIV = 0;
String directionIV = "--", noteIV = "";

// ========== SECTION IV: SESSION GRAPH HISTORY ==========
// Keep only samples acquired after Start; preserve them after Stop.
final int IV_HISTORY_N = 600;                     // More than 15 s at 25 samples/s
int[] balanceTime = new int[IV_HISTORY_N];       // Processing time for each test sample
float[][] balanceValue = new float[3][IV_HISTORY_N];  // [MFP, FFP, HEEL][sample slot]
float[][] balanceTarget = new float[3][IV_HISTORY_N]; // Target active WHEN sample was acquired
int balancePos = 0, balanceCount = 0;            // Circular index and filled positions
int balanceEndMs = 0;                            // Freeze IV graph after Stop, even if other tests run


// ========== DASHBOARD VISUALS (UI ONLY) ==========
final int NAVY = 0xFF17365D, BLUE = 0xFF1769BF, SKY = 0xFF42A6DC;
final int BG = 0xFFF3F7FC, WHITE = 0xFFFFFFFF, PALE = 0xFFE8F1FB;
final int INK = 0xFF223D5D, MUTED = 0xFF7287A0, BORDER = 0xFFD7E3F1;
final int TEAL = 0xFF168D82, RED = 0xFFD94A48, AMBER = 0xFFE6A03E;
final int GREEN_PALE = 0xFFE1F3EB, RED_PALE = 0xFFFFEAE8;
PFont uiFont;
int viewII = 0;                         // 0=choose; 1=calibration; 2=recognition

// A short history of the ORIGINAL filtered motion measurements, for display only.
int[] motionTime = new int[HISTORY_N];
float[] motionAccHistory = new float[HISTORY_N];
float[] motionGyroHistory = new float[HISTORY_N];
int motionPos = 0, motionCount = 0;

// Section I: extra timing statistics; original steps and cadence remain untouched.
long timingIC = -1, timingTO = -1;     // Previous accepted initial contact and release
long strideTimeSum = 0, stanceTimeSum = 0, swingTimeSum = 0;
int completedCycles = 0;               // Count only complete IC -> TO -> next IC cycles

// Smooth heatmap: fixed FSR positions and influence fields, calculated only once.
final int FOOT_W = 258, FOOT_H = 364;
final float[] sensorX = {158, 83, 154, 126}; // MF, LF, MM, heel (left foot)
final float[] sensorY = {102, 113, 209, 313};
PGraphics footMask, footOutline;
PImage footHeatImage;
float[][] heatWeights = new float[4][FOOT_W*FOOT_H];
boolean[] footInside = new boolean[FOOT_W*FOOT_H];
boolean heatDirty = true;
boolean heatWasLive = false;
final int[] HEAT_COLORS = {0xFF164A9D, 0xFF257BCD, 0xFF65C3EE,
                           0xFFF6DE67, 0xFFF59D3B, 0xFFD94343};
final float[] HEAT_STOPS = {0, 0.14f, 0.30f, 0.49f, 0.72f, 1};

// ========== SETUP ==========
void setup() {
  size(1400, 900);                              // Processing window dimensions [pixels]
  frameRate(30);                                // UI refresh; sensor rate comes from Arduino
  Locale.setDefault(Locale.US);                 // Use dot for decimal numbers

  uiFont = createFont("SansSerif", 13, true);  // One clean font for the dashboard
  smooth(4);
  graphColor[0] = color(217, 74, 72);           // MF: coral
  graphColor[1] = color(45, 116, 201);          // LF: blue
  graphColor[2] = color(22, 141, 130);          // MM: teal
  graphColor[3] = color(221, 144, 48);          // Heel: amber
  prepareFootHeatmap();                         // Precompute foot mask and soft fields

  try {                                         // Catch errors opening the serial connection
    port = new Serial(this, PORT, BAUD);        // Serial port name and transmission speed
    port.clear();                               // Discard bytes already present
    port.bufferUntil('\n');                     // Run serialEvent() upon receiving a newline
  } catch (Exception e) {
    serialError = "Cannot open " + PORT + " - close Arduino Serial Monitor";
  }
}


// ========== RECEIVE ONE CSV PACKET ==========
// Arduino sends 12 fields: time,MF,LF,MM,HEEL,ax,ay,az,gx,gy,gz,mpuValid
void serialEvent(Serial p) {
  String line = p.readStringUntil('\n');        // Receive one complete line of serial text
  if (line == null) return;                     // return: leave function if line unavailable

  String[] values = split(trim(line), ',');     // trim removes outer spaces; split divides at commas
  if (values.length != 12) return;              // Reject incomplete or unexpected packets

  try {
    long sampleTime = Long.parseLong(trim(values[0])); // String -> long integer (Arduino millis)
    int[] fsrReadings = new int[4];              // Latest four UNSMOOTHED FSR ADC readings
    float[] imuReadings = new float[6];          // Latest 3 accelerations + 3 angular velocities

    // ----- Extract the four FSR readings -----
    for (int i = 0; i < 4; i++) {
      fsrReadings[i] = Integer.parseInt(trim(values[i+1])); // String -> int (whole number)
      if (fsrReadings[i] < 0 || fsrReadings[i] > 1023) return;
    }

    // ----- Correct LF/MM sensor mapping -----
    int temp = fsrReadings[1];                   // Store current value at LF index
    fsrReadings[1] = fsrReadings[2];             // Physical LF belongs to index 1
    fsrReadings[2] = temp;                       // Physical MM belongs to index 2

    // ----- Extract six MPU values and validity flag -----
    for (int i = 0; i < 6; i++) {
      imuReadings[i] = Float.parseFloat(trim(values[i+5])); // String -> float (decimal number)
      if (Float.isNaN(imuReadings[i]) || Float.isInfinite(imuReadings[i])) return;
    }

    int valid = Integer.parseInt(trim(values[11])); // 1=MPU good, 0=MPU unavailable
    if (valid != 0 && valid != 1) return;

    for (int i = 0; i < 3; i++) {
      accel[i] = imuReadings[i];                 // ax, ay, az [m/s^2]
      gyro[i] = imuReadings[i+3];                // gx, gy, gz [rad/s]
    }
    mpuOK = (valid == 1);                       // == compares values; = assigns a value

    // ----- FSR MOVING AVERAGE: 4x3 matrix, one window per sensor -----
    // Example: fsrWindow[2][1] = slot 1 of the MM sensor (i=2).
    // The same column fsrPos is updated for ALL FOUR rows at each new packet.
    for (int i = 0; i < 4; i++) {
      if (fsrCount == FSR_WINDOW_SIZE) {
        fsrSum[i] -= fsrWindow[i][fsrPos];     // 1. Subtract oldest slot from the sum
      }
      fsrWindow[i][fsrPos] = fsrReadings[i];   // 2. Overwrite that slot with this FSR sample
      fsrSum[i] += fsrReadings[i];             // 3. Add new reading to running sum
      int n = min(fsrCount + 1, FSR_WINDOW_SIZE); // First packets may have fewer than 3 samples
      fsr[i] = fsrSum[i] / n;                 // 4. Average = updated sum / valid window size
    }
    fsrPos = (fsrPos + 1) % FSR_WINDOW_SIZE;   // Circular index: 0 -> 1 -> 2 -> 0 ...
    if (fsrCount < FSR_WINDOW_SIZE) fsrCount++;

    // ----- Shared scrolling graph buffer -----
    int arrival = millis();                   // Local Processing time for graph X axis
    if (recording && lastData >= 0 && arrival - lastData > DATA_TIMEOUT) {
      markInterrupted();                      // Remember a long gap even if data just resumed
    }
    lastData = arrival;
    heatDirty = true;                           // Recolor the map when a new sample arrives
    graphTime[graphPos] = arrival;             // Circular buffer: timestamp at current slot

    for (int i = 0; i < 4; i++) {
      graphFSR[i][graphPos] = fsr[i];          // Save synchronized filtered FSR readings
    }
    graphPos = (graphPos + 1) % HISTORY_N;    // Next slot; wrap and replace oldest when full
    if (graphCount < HISTORY_N) graphCount++;

    // ----- Update continuous motion recognition (also when III is not open) -----
    if (mpuOK) {
      updateMotion(sampleTime);
      motionTime[motionPos] = arrival;         // Only a display buffer; no effect on detection
      motionAccHistory[motionPos] = aMotion;
      motionGyroHistory[motionPos] = wMotion;
      motionPos = (motionPos + 1) % HISTORY_N;
      if (motionCount < HISTORY_N) motionCount++;
    } else resetMotionFilter();                 // MPU invalid: discard old window and state

    // ----- Feed the recording that is currently active -----
    if (recording) {
      if (test == -1) detectStep(sampleTime); // Section I
      else if (test <= 5) collectGait();      // Section II
      else if (test == 7) collectBalance(sampleTime); // Section IV
      // Section III is handled by updateMotion() above.
    }
  } catch (Exception e) {
    // Ignore malformed numeric fields without freezing the UI.
  }
}


// ========== SHARED SENSOR CALCULATIONS ==========
float totalFSR() {
  return fsr[0] + fsr[1] + fsr[2] + fsr[3];   // Total RELATIVE load (ADC, not Newtons)
}

boolean dataLive() {
  return lastData >= 0 && millis() - lastData < DATA_TIMEOUT; // A recent valid CSV exists
}

float magnitude(float x, float y, float z) {
  return sqrt(x*x + y*y + z*z);                // Length of 3D vector (square root of sum of squares)
}

float medialPct(float total) {
  return 100.0f * (fsr[0] + fsr[2]) / total;   // MFP: medial forefoot + medial midfoot
}

float forefootPct(float total) {
  return 100.0f * (fsr[0] + fsr[1]) / total;   // FFP: medial + lateral forefoot
}

void markInterrupted() {
  if (test == -1) {
    interruptedI = true;
    timingIC = timingTO = -1;              // Never bridge a missing-data gap in NEW timing metrics
  }
  else if (test >= 0 && test <= 5) interruptedII = true;
  // Section I/II continue; the operator can repeat tests if necessary.
}


// ========== SECTION I: DETECT CONTACTS OF ONE FOOT ==========
void detectStep(long t) {                      // t = Arduino time of CURRENT sample, in ms
  float total = totalFSR();

  if (!footDown && total >= CONTACT_ON) {     // Foot was up AND total crossed upper threshold
    footDown = true;                         // Do not count again until the foot is released

    if (lastContact < 0 || t - lastContact >= MIN_STRIDE_MS) {
      // First contact (lastContact=-1) OR at least 500 ms after previous accepted contact.
      contacts++;
      if (firstContact < 0) firstContact = t; // First contact time is saved only ONCE
      lastContact = t;                        // Last contact time is updated EVERY accepted contact
      recordTimingContact(t);                 // Extra IC->TO->IC statistics, independent of steps
    }
  } else if (footDown && total <= CONTACT_OFF) {
    footDown = false;                        // Below lower threshold -> allow next contact
    recordTimingRelease(t);                   // Extra toe-off timestamp; no change to detection
  }
}

float cadence() {
  if (contacts < 2 || lastContact <= firstContact) return Float.NaN;
  float seconds = (lastContact - firstContact) / 1000.0f; // Time between first and last contacts
  return 120.0f * (contacts - 1) / seconds;   // 2 steps/stride, converting to steps per minute
}


// ========== SECTION II: COLLECT MFP / FFP ==========
void collectGait() {
  float total = totalFSR();
  if (total < CONTACT_ON) return;              // Skip low-load/swing samples

  sumMFP += medialPct(total);                 // Add current percentage (not raw ADC sum)
  sumFFP += forefootPct(total);
  validSamples++;                             // Mean = accumulated percentages / samples
}

String classify(float mfp, float ffp) {
  float nearest = Float.MAX_VALUE;            // Distance of closest reference so far
  float second = Float.MAX_VALUE;             // Distance of SECOND closest reference so far
  int best = -1;                              // Index of closest profile; -1 means none found

  for (int i = 0; i < 5; i++) {
    if (!hasRef[i]) continue;                 // Skip uncalibrated profile, go to next i

    float dx = mfp - refMFP[i];               // Difference between test and reference MFP
    float dy = ffp - refFFP[i];               // Difference between test and reference FFP
    float distance = sqrt(dx*dx + dy*dy);     // Euclidean distance in MFP/FFP plane

    if (distance < nearest) {                 // This profile is now the closest one
      second = nearest;                      // Previous closest becomes second-closest
      nearest = distance;                    // Update best distance
      best = i;                              // Remember its gait profile index
    } else if (distance < second) {          // Not best, but closer than previous second?
      second = distance;                     // Update only second-closest distance
    }
  }

  if (best == -1) return "NO REFERENCES";
  if (second < Float.MAX_VALUE && second - nearest < AMBIG_MARGIN) {
    return "AMBIGUOUS";                       // Two profiles are almost equally close
  }
  return gait[best];                          // Convert best index into profile name
}


// ========== SECTION III: CONTINUOUS MOTION DETECTION ==========
void resetMotionFilter() {
  aSum = 0;                                  // Discard old acceleration running sum
  wSum = 0;                                  // Discard old angular-speed running sum
  aMotion = 0;
  wMotion = 0;
  imuPos = 0;                                // Restart both five-sample circular buffers
  imuCount = 0;                              // Old array slots are ignored until overwritten
  lastImuTime = -1;                          // No valid previous timestamp
  belowSince = -1;                           // Cancel countdown to STANDING STILL
  aboveSince = -1;                           // Cancel countdown to IN MOTION
  inMotion = false;
}

void updateMotion(long t) {                   // Called for each valid MPU sample (Arduino ms)
  if (lastImuTime >= 0 && (t <= lastImuTime || t - lastImuTime > 300)) {
    resetMotionFilter();                      // Discard samples separated by a large gap/reset
  }

  float a = abs(magnitude(accel[0], accel[1], accel[2]) - 9.81f);
  // Deviation of acceleration magnitude from gravity, NOT individual a_x/a_y/a_z.
  float w = magnitude(gyro[0], gyro[1], gyro[2]); // Angular-speed magnitude [rad/s]

  // ----- TWO 4-SAMPLE MOVING WINDOWS (a and omega) -----
  if (imuCount == IMU_WINDOW_SIZE) {
    aSum -= aWindow[imuPos];               // Remove oldest a from its running sum
    wSum -= wWindow[imuPos];               // Remove oldest omega from its running sum
  }
  aWindow[imuPos] = a;                     // Replace a's oldest slot with new value
  aSum += a;                              // Add new a to its running sum
  wWindow[imuPos] = w;                     // Replace omega's oldest slot
  wSum += w;

  imuPos = (imuPos + 1) % IMU_WINDOW_SIZE; // Next slot, wrapping around the array
  if (imuCount < IMU_WINDOW_SIZE) imuCount++;
  aMotion = aSum / imuCount;               // Filtered a = average of available samples
  wMotion = wSum / imuCount;               // Filtered omega

  // ----- ACTIVITY TIME: count only intervals with valid consecutive samples -----
  if (lastImuTime >= 0 && t > lastImuTime && t - lastImuTime <= 300) {
    if (recording && test == 6 && inMotion) {
      activityMs += t - lastImuTime;         // Time elapsed while previous state was IN MOTION
    }
  }
  lastImuTime = t;

  // ----- OR criterion with persistence BOTH when entering and leaving motion -----
  boolean above = aMotion > ACC_THRESHOLD || wMotion > GYRO_THRESHOLD;
  if (above) {
    belowSince = -1;                       // A new motion signal cancels STILL countdown
    if (!inMotion) {
      if (aboveSince < 0) aboveSince = t;  // First sample above either threshold
      if (t - aboveSince >= MOTION_ON_MS) {
        inMotion = true;                   // Motion persisted long enough to be accepted
      }
    }
  } else {
    aboveSince = -1;                       // A short spike cannot trigger IN MOTION
    if (inMotion) {
      if (belowSince < 0) belowSince = t;  // Both measures below threshold: start timer
      if (t - belowSince >= STILL_MS) {
        inMotion = false;                  // Return to STILL after the configured delay
      }
    }
  }
}


// ========== SECTION IV: SAVE ONE SESSION GRAPH SAMPLE ==========
void saveBalancePoint(float[] current) {
  balanceTime[balancePos] = millis();            // X coordinate, relative to the current session
  for (int i = 0; i < 3; i++) {
    balanceValue[i][balancePos] = current[i];    // MFP/FFP may be NaN if total load is too low
    balanceTarget[i][balancePos] = refReady ? targetIV[i] : Float.NaN;
    // The fixed personal target is stored with every exercise sample.
  }
  balancePos = (balancePos + 1) % IV_HISTORY_N;  // Next circular slot
  if (balanceCount < IV_HISTORY_N) balanceCount++;
}


// ========== SECTION IV: PROCESS ONE CALIBRATION OR EXERCISE SAMPLE ==========
void collectBalance(long t) {                  // t is Arduino time [ms], not the UI frame time
  if (!mpuOK) {
    stopTest(false);
    noteIV = "MPU unavailable: phase stopped.";
    return;
  }
  // Avoid including a late serial sample after either phase has timed out.
  if ((ivPhase == 1 && millis()-startMs >= IV_CAL_MS) ||
      (ivPhase == 3 && millis()-startMs >= IV_EXERCISE_MS)) {
    stopTest(true);
    return;
  }

  float total = totalFSR();
  boolean validLoad = total >= MIN_PERCENT_TOTAL;
  float[] current = {
    validLoad ? medialPct(total) : Float.NaN, // MFP requires meaningful FSR loading
    validLoad ? forefootPct(total) : Float.NaN,
    fsr[3]                                   // Heel ADC, including zero
  };

  if (ivPhase == 1) {                         // CALIBRATION: exactly the first 5 s phase
    saveBalancePoint(current);               // Show FSRs, without a target line
    if (!validLoad) return;                  // Never divide by a near-zero total
    for (int i = 0; i < 3; i++) {
      refSumIV[i] += current[i];             // Accumulate MFP, FFP, heel values
      accRefSum[i] += accel[i];              // Accumulate the gravity-dominated vector
    }
    refSamples++;
    return;
  }
  if (ivPhase != 3 || !refReady) return;      // Only the separate exercise changes scores

  directionIV = "MAINTAIN YOUR REFERENCE";  // Fixed target throughout the balance exercise
  saveBalancePoint(current);                 // Preserve active target with each graph sample
  if (!validLoad) {
    lastBalanceTime = -1;                    // Do not bridge invalid intervals in scoring
    return;
  }

  long dt = 0;
  if (lastBalanceTime >= 0 && t > lastBalanceTime && t-lastBalanceTime <= 300) {
    dt = t-lastBalanceTime;                  // Only consecutive valid Arduino timestamps
  }
  lastBalanceTime = t;
  exerciseMs += dt;

  // Existing time-in-target scores, unchanged for Single-Leg Balance.
  if (abs(current[0]-targetIV[0]) <= MFP_TOL) insideMs[0] += dt;
  if (abs(current[1]-targetIV[1]) <= FFP_TOL) insideMs[1] += dt;
  if (abs(current[2]-targetIV[2]) <= HEEL_TOL) insideMs[2] += dt;

  // ----- Preserve original unsigned reference-vector tilt and gyro RMS -----
  float dot = accel[0]*accRef[0] + accel[1]*accRef[1] + accel[2]*accRef[2];
  float lengthNow = magnitude(accel[0], accel[1], accel[2]);
  float lengthRef = magnitude(accRef[0], accRef[1], accRef[2]);
  if (lengthNow > 0.01f && lengthRef > 0.01f) {
    float cosAngle = constrain(dot/(lengthNow*lengthRef), -1, 1);
    tiltNow = degrees(acos(cosAngle));       // Unsigned 3D angle between acceleration vectors
    angleSquares += tiltNow*tiltNow;
    float w = magnitude(gyro[0], gyro[1], gyro[2]);
    gyroSquares += w*w;
    imuSamplesIV++;
  }

  // ----- NEW signed AP and ML deviations: quasi-static tilt approximation -----
  float ap = degrees(atan2(accel[0], -accel[1]));
  float ml = degrees(atan2(accel[2], -accel[1]));
  float deviationAP = ap - tiltRefIV[0];    // Forward/backward change from reference
  float deviationML = ml - tiltRefIV[1];    // Side-to-side change from reference
  tiltSumIV[0] += deviationAP;
  tiltSumIV[1] += deviationML;
  tiltSamplesIV++;
}

float meanTiltIV(int axis) {
  return tiltSamplesIV > 0 ? tiltSumIV[axis]/tiltSamplesIV : Float.NaN;
}

// ========== SECTION IV: SEPARATE USER-ACTIVATED PHASES ==========
void startIVCalibration() {
  if (recording) return;
  if (!dataLive() || !mpuOK) {
    noteIV = "FSR / MPU data unavailable: cannot calibrate.";
    return;
  }
  clearIVDisplay();                           // New baseline invalidates old exercise results
  test = 7;
  recording = true;
  startMs = millis();                         // 5 s calibration timer starts HERE
  ivPhase = 1;
  directionIV = "STAND STILL ON YOUR LEFT FOOT";
}

void startIVExercise() {
  if (recording || !refReady || (ivPhase != 2 && ivPhase != 4)) return;
  if (!dataLive() || !mpuOK) {
    noteIV = "FSR / MPU data unavailable: cannot start exercise.";
    return;
  }
  test = 7;
  recording = true;
  startMs = millis();                         // Separate 15 s exercise timer starts HERE
  ivPhase = 3;
  elapsedIV = 0;
  noteIV = "";
  balancePos = balanceCount = balanceEndMs = 0; // Only exercise data in the final plots
  exerciseMs = 0;
  lastBalanceTime = -1;
  tiltNow = Float.NaN;
  angleSquares = gyroSquares = 0;
  imuSamplesIV = tiltSamplesIV = 0;
  for (int i = 0; i < 3; i++) insideMs[i] = 0;
  for (int i = 0; i < 2; i++) tiltSumIV[i] = 0;
  for (int i = 0; i < 3; i++) targetIV[i] = refIV[i];
  directionIV = "MAINTAIN YOUR REFERENCE";
}

void finishIVCalibration(boolean completed) {
  if (!completed) {
    refReady = false;
    ivPhase = 0;
    noteIV = "Calibration cancelled. Press Calibrate to retry.";
    return;
  }
  if (refSamples == 0) {
    refReady = false;
    ivPhase = 0;
    noteIV = "No valid FSR reference samples. Repeat calibration.";
    return;
  }
  for (int i = 0; i < 3; i++) {
    refIV[i] = refSumIV[i]/refSamples;
    accRef[i] = accRefSum[i]/refSamples;
    targetIV[i] = refIV[i];
  }
  // Same AP/ML formulas as the supplied alternate sketch.
  tiltRefIV[0] = degrees(atan2(accRef[0], -accRef[1]));
  tiltRefIV[1] = degrees(atan2(accRef[2], -accRef[1]));
  refReady = true;
  ivPhase = 2;                                // Stay here until Start Exercise is clicked
  noteIV = "Reference saved. Ready for the 15-second exercise.";
}

// ========== START A TEST ==========
void startTest(int selected) {
  if (selected == 7) { startIVCalibration(); return; }
  if (!dataLive() || (selected >= 6 && !mpuOK)) {
    if (selected == -1) noteI = "No live FSR data.";
    else if (selected <= 5) noteII = "No live FSR data.";
    else if (selected == 6) noteIII = "MPU unavailable.";
    else noteIV = "FSR / MPU data unavailable.";
    return;
  }

  test = selected;
  recording = true;
  startMs = millis();                     // Common timer; only one active test
  field = -1;
  editing = -1;

  if (test == -1) {                        // ----- Section I -----
    contacts = 0;
    resetGaitTiming();                       // Only NEW timing measurements are cleared
    firstContact = -1;
    lastContact = -1;
    footDown = totalFSR() > CONTACT_OFF; // Avoid counting a foot already resting
    elapsedI = 0;
    sectionIResult = false;
    interruptedI = false;
    noteI = "";
  } else if (test <= 5) {                 // ----- Section II -----
    sumMFP = 0;
    sumFFP = 0;
    validSamples = 0;
    elapsedII = 0;
    interruptedII = false;
    noteII = "";

    if (test == 5) {
      resultMFP = Float.NaN;
      resultFFP = Float.NaN;
      detected = "Recording...";
    }
  } else if (test == 6) {                  // ----- Section III -----
    activityMs = 0;
    elapsedIII = 0;
    noteIII = "";
  } // Section IV is started through its own Calibrate / Start Exercise buttons.


}


// ========== STOP A TEST ==========
void stopTest(boolean completed) {
  if (!recording) return;

  int elapsed = millis() - startMs;
  recording = false;

  if (test == -1) {
    elapsedI = min(elapsed, SECTION_I_MS);
    sectionIResult = true;                 // Keep results visible until new Start
  } else if (test <= 5) {
    elapsedII = min(elapsed, SECTION_II_MS);

    if (test < 5 && !completed) {
      noteII = "Calibration cancelled; previous values kept.";
      return;                              // Early Stop cancels calibration, not recognition
    }
    if (validSamples == 0) {
      if (test == 5) detected = "NO CONTACT DATA";
      else noteII = "No contact samples: calibration not saved.";
      return;
    }

    float mfp = sumMFP / validSamples;      // Mean of instantaneous percentages
    float ffp = sumFFP / validSamples;
    if (test == 5) {
      resultMFP = mfp;
      resultFFP = ffp;
      detected = classify(mfp, ffp);
    } else {
      refMFP[test] = mfp;
      refFFP[test] = ffp;
      hasRef[test] = true;                 // Reference available in later recognition tests
    }
  } else if (test == 6) {
    elapsedIII = elapsed;                   // Freeze session timer and activity duration
  } else {                                   // ----- Section IV -----
    elapsedIV = min(elapsed, ivPhase == 1 ? IV_CAL_MS : IV_EXERCISE_MS);
    balanceEndMs = millis();                 // Freeze the graph at the end of this phase
    if (ivPhase == 1) {
      finishIVCalibration(completed);        // Never automatically start the exercise
    } else if (ivPhase == 3) {
      ivPhase = 4;
      noteIV = completed ? "Exercise completed. Results are shown below." :
        "Exercise stopped early. Results are based on collected samples.";
    }


  }
}


// ========== EXTRA SECTION I GAIT TIMING (NEW; independent of existing steps) ==========
void resetGaitTiming() {
  timingIC = -1;
  timingTO = -1;
  strideTimeSum = stanceTimeSum = swingTimeSum = 0;
  completedCycles = 0;
}

void recordTimingContact(long t) {
  // A valid cycle requires IC -> toe-off -> next IC, all using Arduino timestamps.
  if (timingIC >= 0 && timingTO > timingIC && t > timingTO) {
    long stance = timingTO - timingIC;
    long swing = t - timingTO;
    stanceTimeSum += stance;
    swingTimeSum += swing;
    strideTimeSum += t - timingIC;
    completedCycles++;                  // Do not include partial first/last cycles
  }
  timingIC = t;                         // Start a new cycle at this accepted contact
  timingTO = -1;
}

void recordTimingRelease(long t) {
  if (timingIC >= 0 && timingTO < 0 && t > timingIC) {
    timingTO = t;                       // Lower FSR threshold: proxy for toe-off
  }
}

String avgTime(long sum) {
  return completedCycles > 0 ? dec(sum / (1000.0f * completedCycles)) + " s" : "--";
}

String stanceFraction() {
  return strideTimeSum > 0 ? dec(100.0f * stanceTimeSum / strideTimeSum) + "%" : "--";
}


// ========== NEW DASHBOARD LAYOUT; ALL EXISTING TEST TIMERS ARE PRESERVED ==========
void draw() {
  if (recording) {
    if (!dataLive()) {                     // Original interruption behavior
      if (test <= 5) markInterrupted();
      else {
        stopTest(false);
        if (test == 6) noteIII = "DATA INTERRUPTED: session stopped.";
        else noteIV = "DATA INTERRUPTED: session stopped.";
        resetMotionFilter();
      }
    }
    if (recording && test >= 6 && !mpuOK) {
      stopTest(false);
      if (test == 6) noteIII = "MPU unavailable: session stopped.";
      else noteIV = "MPU unavailable: test stopped.";
    }
    if (recording) {
      if (test == -1 && millis() - startMs >= SECTION_I_MS) stopTest(true);
      else if (test >= 0 && test <= 5 && millis() - startMs >= SECTION_II_MS) stopTest(true);
      else if (test == 7 && ivPhase == 1 && millis()-startMs >= IV_CAL_MS) stopTest(true);
      else if (test == 7 && ivPhase == 3 && millis()-startMs >= IV_EXERCISE_MS) stopTest(true);
    }
  }

  boolean liveNow = dataLive();
  if (liveNow != heatWasLive) { heatDirty = true; heatWasLive = liveNow; }
  background(BG);                        // UI only: repaint once per screen frame
  textFont(uiFont);
  drawHeader();
  if (section == 0) drawSectionI();
  else if (section == 1) drawSectionII();
  else if (section == 2) drawSectionIII();
  else drawSectionIV();
}


// ========== REUSABLE DASHBOARD ELEMENTS ==========
void panel(float x, float y, float w, float h) {
  stroke(BORDER);
  strokeWeight(1);
  fill(WHITE);
  rect(x, y, w, h, 13);
}

void labelText(String s, float x, float y, int size, int ink) {
  fill(ink);
  textAlign(LEFT, BASELINE);
  textSize(size);
  text(s, x, y);
}

void centeredText(String s, float x, float y, int size, int ink) {
  fill(ink);
  textAlign(CENTER, CENTER);
  textSize(size);
  text(s, x, y);
}

void sectionHeading(String name, String description) {
  labelText(name, 48, 169, 21, NAVY);
  labelText(description, 49, 194, 12, MUTED);
}

void tag(String caption, float x, float y, int w, int backgroundColor, int textColor) {
  noStroke();
  fill(backgroundColor);
  rect(x, y, w, 24, 12);
  centeredText(caption, x+w/2, y+12, 11, textColor);
}

void button(String caption, int x, int y, int w, boolean enabled) {
  buttonStyled(caption, x, y, w, enabled, true);
}

void buttonStyled(String caption, int x, int y, int w, boolean enabled, boolean primary) {
  stroke(enabled ? (primary ? BLUE : BORDER) : BORDER);
  fill(enabled ? (primary ? BLUE : WHITE) : BG);
  rect(x, y, w, 34, 7);
  centeredText(caption, x+w/2, y+17, 12,
    enabled ? (primary ? WHITE : NAVY) : MUTED);
}

void modeButton(String caption, int x, int y, int w, boolean selected) {
  stroke(selected ? BLUE : BORDER);
  fill(selected ? PALE : WHITE);
  rect(x, y, w, 35, 7);
  centeredText(caption, x+w/2, y+17, 12, selected ? BLUE : MUTED);
}

void inputBox(int x, int y, int w, String value, boolean selected) {
  stroke(selected ? BLUE : BORDER);
  strokeWeight(selected ? 2 : 1);
  fill(WHITE);
  rect(x, y, w, 32, 6);
  labelText(value.length() == 0 ? "Enter" : value, x+10, y+21, 12,
    value.length() == 0 ? MUTED : INK);
  strokeWeight(1);
}

void warning(String message, int x, int y) {
  labelText(message, x, y, 12, RED);
}

void metricCard(String name, String value, int x, int y, int w, int h) {
  noStroke();
  fill(BG);
  rect(x, y, w, h, 9);
  labelText(name, x+13, y+18, 11, MUTED);
  labelText(value, x+13, y+h-10, 18, NAVY);
}

boolean hit(int x, int y, int w, int h) {
  return mouseX >= x && mouseX <= x+w && mouseY >= y && mouseY <= y+h;
  // Hitbox must match the visible control dimensions.
}


// ========== TOP BAR AND THE FOUR ORIGINAL SECTIONS ==========
void drawHeader() {
  noStroke();
  fill(WHITE);
  rect(0, 0, width, 133);
  labelText("SMART INSOLE", 45, 44, 27, NAVY);
  labelText("GAIT ANALYSIS  /  WEARABLES LAB", 46, 66, 12, MUTED);

  if (dataLive()) {
    tag("FSR LIVE", 1100, 23, 100, GREEN_PALE, TEAL);
    tag(mpuOK ? "MPU OK" : "MPU OFF", 1210, 23, 95,
      mpuOK ? GREEN_PALE : RED_PALE, mpuOK ? TEAL : RED);
  } else {
    tag("WAITING FOR DATA", 1100, 23, 205, RED_PALE, RED);
  }
  if (recording) tag("RECORDING", 971, 23, 115, RED_PALE, RED);
  if (!dataLive() && serialError.length() > 0) {
    labelText(serialError, 826, 65, 11, RED);
  }

  String[] names = {"I  NORMAL WALKING", "II  CLASSIFICATION", "III  MOTION", "IV  BALANCE"};
  for (int i = 0; i < 4; i++) {
    int x = 45 + i*333;
    stroke(i == section ? BLUE : BORDER);
    strokeWeight(i == section ? 1.5f : 1);
    fill(i == section ? PALE : WHITE);
    rect(x, 84, 320, 38, 8);
    centeredText(names[i], x+160, 103, 12,
      (recording && i != section) ? MUTED : (i == section ? BLUE : INK));
  }
  strokeWeight(1);
}


// ========== LEFT FOOT: SMOOTH SHADED FOUR-SENSOR HEATMAP ==========
void footContour(PGraphics g) {
  // Original insole outline from Processing_Code.pde (exact Bezier control points).
  // The old sketch drew this with scale(1.30, 1.05); preserve those proportions.
  // A small translation fits the contour inside the current dashboard panel.
  g.pushMatrix();
  g.translate(-11, 8);
  g.scale(1.30f, 1.05f);
  g.beginShape();
  g.vertex(108, 12);
  g.bezierVertex(80, 12, 54, 21, 43, 48);
  g.bezierVertex(25, 76, 33, 123, 47, 151);
  g.bezierVertex(64, 183, 70, 196, 63, 223);
  g.bezierVertex(57, 250, 54, 277, 67, 300);
  g.bezierVertex(83, 327, 120, 324, 141, 310);
  g.bezierVertex(166, 293, 163, 267, 152, 237);
  g.bezierVertex(144, 209, 153, 185, 165, 152);
  g.bezierVertex(186, 110, 184, 71, 163, 39);
  g.bezierVertex(151, 21, 136, 12, 108, 12);
  g.endShape(CLOSE);
  g.popMatrix();
}

void prepareFootHeatmap() {
  footMask = createGraphics(FOOT_W, FOOT_H);
  footOutline = createGraphics(FOOT_W, FOOT_H);
  footHeatImage = createImage(FOOT_W, FOOT_H, ARGB);

  footMask.beginDraw();
  footMask.clear();
  footMask.noStroke();
  footMask.fill(255);
  footContour(footMask);                   // Build alpha mask for the foot only
  footMask.endDraw();
  footMask.loadPixels();

  footOutline.beginDraw();
  footOutline.clear();
  footOutline.noFill();
  footOutline.stroke(48, 93, 148);
  footOutline.strokeWeight(2.2f);
  footContour(footOutline);                // Crisp outline on top of the soft color map
  footOutline.endDraw();

  // Store four smooth Gaussian fields once, not in every draw() frame.
  for (int y = 0; y < FOOT_H; y++) {
    for (int x = 0; x < FOOT_W; x++) {
      int p = y*FOOT_W+x;
      footInside[p] = ((footMask.pixels[p] >>> 24) & 255) > 20;
      if (!footInside[p]) continue;
      for (int s = 0; s < 4; s++) {
        float sx = (s == 3 ? 55 : 54);     // Fixed blur width: pixels, not force-dependent
        float sy = (s == 2 ? 68 : 60);
        float dx = (x-sensorX[s])/sx;
        float dy = (y-sensorY[s])/sy;
        heatWeights[s][p] = exp(-0.5f*(dx*dx + dy*dy));
      }
    }
  }
}

int heatColor(float level) {
  // The only heatmap scale is the fixed ADC range 0..1023.
  float v = constrain(level, 0, 1);
  for (int i = 0; i < HEAT_STOPS.length-1; i++) {
    if (v <= HEAT_STOPS[i+1]) {
      float f = (v-HEAT_STOPS[i])/(HEAT_STOPS[i+1]-HEAT_STOPS[i]);
      return lerpColor(HEAT_COLORS[i], HEAT_COLORS[i+1], f);
    }
  }
  return HEAT_COLORS[HEAT_COLORS.length-1];
}

void updateFootHeatmap() {
  if (!heatDirty) return;                  // Update only when new serial FSR data arrive
  footHeatImage.loadPixels();
  boolean live = dataLive();
  float[] levels = new float[4];
  for (int i = 0; i < 4; i++) levels[i] = live ? fsr[i]/1023.0f : 0;
  // Snapshot all 4 FSR values once: a coherent map even during serial reception.
  for (int p = 0; p < FOOT_W*FOOT_H; p++) {
    if (!footInside[p]) {
      footHeatImage.pixels[p] = 0x00000000; // Transparent outside the silhouette
      continue;
    }
    float intensity = 0;
    for (int s = 0; s < 4; s++) {
      intensity = max(intensity, levels[s]*heatWeights[s][p]);
      // Maximum of four soft fields: avoids false accumulation of force.
    }
    footHeatImage.pixels[p] = heatColor(intensity);
  }
  footHeatImage.updatePixels();
  heatDirty = false;
}

void drawHeatmap() {
  panel(40, 150, 326, 450);
  labelText("LEFT FOOT  /  RELATIVE LOADING", 56, 178, 13, NAVY);
  updateFootHeatmap();
  image(footHeatImage, 74, 194);          // Same exact pixels for outline and heat shading
  image(footOutline, 74, 194);

  String[] shortName = {"MF", "LF", "MM", "H"};
  for (int i = 0; i < 4; i++) {
    float x = 74 + sensorX[i], y = 194 + sensorY[i];
    stroke(WHITE);
    strokeWeight(2);
    noFill();
    ellipse(x, y, 9, 9);                  // Fixed-size sensor position (never a force bubble)
    noStroke();
    fill(NAVY);
    textAlign(CENTER, CENTER);
    textSize(10);
    text(shortName[i], x, y-14);
  }
  strokeWeight(1);

  for (int i = 0; i < 90; i++) {         // Discrete samples form a continuous-looking legend
    noStroke();
    fill(heatColor(i/89.0f));
    rect(79+i*2.7f, 565, 3, 9);
  }
  labelText("0 ADC", 79, 590, 10, MUTED);
  labelText("1023 ADC", 270, 590, 10, MUTED);
}


// ========== FOUR REQUIRED LIVE FSR GRAPHS (SAME 12 s DATA BUFFER) ==========
void drawGraph(int channel, int x, int y) {
  int w = 480, h = 218;
  panel(x, y, w, h);
  noStroke();
  fill(graphColor[channel]);
  ellipse(x+21, y+22, 9, 9);
  labelText(fsrName[channel], x+36, y+28, 14, NAVY);
  labelText(dataLive() ? ((int)fsr[channel])+" ADC" : "-- ADC", x+374, y+28, 13, BLUE);

  int left = x+51, top = y+53, pw = w-77, ph = 119;
  for (int j = 0; j < 3; j++) {
    float yy = top+j*ph/2.0f;
    stroke(BORDER);
    line(left, yy, left+pw, yy);
    fill(MUTED);
    textSize(11);
    textAlign(RIGHT, CENTER);
    text(j==0 ? "1023" : (j==1 ? "512" : "0"), left-9, yy);
  }
  stroke(174, 190, 211);
  line(left, top, left, top+ph);
  line(left, top+ph, left+pw, top+ph);

  int now = millis(), from = now-GRAPH_MS, previous = -1;
  noFill();
  stroke(graphColor[channel]);
  strokeWeight(2.2f);
  beginShape();
  for (int k = 0; k < graphCount; k++) {
    int idx = (graphPos-graphCount+k+HISTORY_N) % HISTORY_N;
    // Circular history, oldest to newest; same original sample order.
    int t = graphTime[idx];
    if (t < from) continue;
    if (previous >= 0 && t-previous > 300) {
      endShape();
      beginShape();                      // Never connect lines across a reception gap
    }
    vertex(map(t, from, now, left, left+pw),
      map(graphFSR[channel][idx], 0, 1023, top+ph, top));
    previous = t;
  }
  endShape();
  strokeWeight(1);
  centeredText("-12", left, top+ph+17, 10, MUTED);
  centeredText("-6", left+pw/2, top+ph+17, 10, MUTED);
  centeredText("0", left+pw, top+ph+17, 10, MUTED);
  centeredText("Time (s)", left+pw/2, top+ph+34, 11, MUTED);
}


// ========== SECTION I: RECORDING, 4 GRAPHS, HEATMAP, METRICS ==========
void drawSectionI() {
  drawHeatmap();
  for (int i = 0; i < 4; i++) {
    drawGraph(i, 380+500*(i%2), 150+232*(i/2));
  }

  panel(40, 618, 1320, 265);
  labelText("SECTION I  /  NORMAL WALKING", 58, 644, 16, NAVY);
  if (interruptedI) warning("DATA INTERRUPTED - repeat if needed", 1042, 644);
  else if (noteI.length() > 0) warning(noteI, 1042, 644);

  labelText("Step length (cm)", 58, 684, 12, MUTED);
  inputBox(179, 655, 106, stepLength, field == 0);
  labelText("Step width (cm)", 302, 684, 12, MUTED);
  inputBox(417, 655, 106, stepWidth, field == 1);
  button("Start Recording", 612, 653, 171, !recording);
  buttonStyled("Stop", 795, 653, 85, recording && test == -1, false);
  int elapsed = (recording && test == -1) ? min(SECTION_I_MS, millis()-startMs) : elapsedI;
  labelText("SESSION", 1030, 666, 11, MUTED);
  labelText(clock(elapsed)+" / 02:00", 1030, 685, 19, NAVY);

  float L = parsePositive(stepLength), W = parsePositive(stepWidth);
  float C = cadence();                   // Unmodified existing cadence calculation
  int colW = 419;
  int[] xx = {55, 491, 927};
  metricCard("EST. STEPS (BOTH FEET)",
    sectionIResult || (recording && test == -1) ? str(2*contacts) : "--", xx[0], 706, colW, 51);
  metricCard("CADENCE", Float.isNaN(C) ? "--" : dec(C)+" steps/min", xx[1], 706, colW, 51);
  metricCard("STRIDE TIME", avgTime(strideTimeSum), xx[2], 706, colW, 51);
  metricCard("FSR CONTACT TIME", avgTime(stanceTimeSum), xx[0], 762, colW, 51);
  metricCard("FSR SWING TIME", avgTime(swingTimeSum), xx[1], 762, colW, 51);
  metricCard("STANCE / STRIDE", stanceFraction(), xx[2], 762, colW, 51);
  metricCard("STEP LENGTH (MEASURED)", cm(L), xx[0], 818, colW, 51);
  metricCard("STRIDE LENGTH (EST.)", cm(2*L), xx[1], 818, colW, 51);
  metricCard("STEP WIDTH (MEASURED)", cm(W), xx[2], 818, colW, 51);
}


// ========== SECTION II: CHOOSE, CALIBRATION, RECOGNITION ==========
void drawSectionII() {
  sectionHeading("SECTION II  /  GAIT CLASSIFICATION",
    "Five reference profiles. Classification uses the existing mean MFP / FFP and Euclidean distance.");
  if (viewII == 0) drawIIHome();
  else if (viewII == 1) drawIICalibration();
  else drawIIRecognition();
}

void drawIIHome() {
  panel(98, 259, 571, 431);
  panel(728, 259, 571, 431);
  noStroke();
  fill(PALE);
  ellipse(383, 369, 94, 94);
  ellipse(1014, 369, 94, 94);
  centeredText("01", 383, 369, 32, BLUE);
  centeredText("02", 1014, 369, 32, BLUE);
  centeredText("CALIBRATION", 383, 450, 23, NAVY);
  centeredText("RECOGNITION", 1014, 450, 23, NAVY);
  centeredText("Calibrate or manually edit any of the five profiles", 383, 494, 13, MUTED);
  centeredText("Classify a walking trial using saved references", 1014, 494, 13, MUTED);
  button("Manage References", 284, 554, 200, !recording);
  button("Start Recognition View", 912, 554, 205, !recording);
  labelText("References ready: "+countReferences()+" / 5", 99, 751, 15, NAVY);
  labelText("References are retained until this Processing sketch is closed.", 99, 778, 12, MUTED);
  if (noteII.length() > 0) warning(noteII, 99, 816);
}

int countReferences() {
  int n = 0;
  for (int i = 0; i < 5; i++) if (hasRef[i]) n++;
  return n;
}

void drawIICalibration() {
  labelText("CALIBRATION  /  SELECT ANY PROFILE", 49, 221, 13, BLUE);
  int elapsed = (recording && test >= 0 && test < 5) ?
    min(SECTION_II_MS, millis()-startMs) : elapsedII;
  labelText(clock(elapsed)+" / 00:30", 1046, 222, 15, NAVY);
  buttonStyled("Stop Calibration", 1166, 202, 175,
    recording && test >= 0 && test < 5, false);

  for (int i = 0; i < 5; i++) {
    int y = 236+i*108;
    panel(45, y, 1310, 98);
    if (recording && test == i) {
      noStroke();
      fill(PALE);
      rect(46, y+1, 8, 96, 5);
    }
    labelText(gait[i], 65, y+32, 17, NAVY);
    labelText(recording && test == i ? "RECORDING  /  30 s" :
      (hasRef[i] ? "Reference available" : "Not calibrated"),
      65, y+57, 12, recording && test == i ? BLUE : MUTED);

    labelText("MFP", 472, y+25, 11, MUTED);
    labelText("FFP", 667, y+25, 11, MUTED);
    if (editing == i) {
      inputBox(470, y+38, 123, editText[0], field == 0);
      inputBox(665, y+38, 123, editText[1], field == 1);
      buttonStyled("Save", 1182, y+34, 148, !recording, false);
    } else {
      labelText(hasRef[i] ? dec(refMFP[i])+"%" : "--", 472, y+63, 19, INK);
      labelText(hasRef[i] ? dec(refFFP[i])+"%" : "--", 667, y+63, 19, INK);
      buttonStyled("Edit Values", 1182, y+34, 148, !recording, false);
    }
    button("Calibrate 30 s", 997, y+34, 172, !recording);
  }
  buttonStyled("Done  /  Back to Classification", 45, 800, 270, !recording, false);
  if (interruptedII) warning("DATA INTERRUPTED - check connection; repeat calibration if needed.", 355, 823);
  else if (noteII.length() > 0) warning(noteII, 355, 823);
}

void drawIIRecognition() {
  panel(45, 218, 1310, 113);
  labelText("DETECTED GAIT", 65, 247, 11, MUTED);
  labelText(detected, 65, 285, 26, NAVY);
  labelText("MEAN MFP", 475, 249, 11, MUTED);
  labelText(pct(resultMFP), 475, 285, 22, NAVY);
  labelText("MEAN FFP", 658, 249, 11, MUTED);
  labelText(pct(resultFFP), 658, 285, 22, NAVY);
  button("Record 30 s", 934, 253, 179, !recording);
  buttonStyled("Stop", 1123, 253, 120, recording && test == 5, false);
  int elapsed = (recording && test == 5) ? min(SECTION_II_MS, millis()-startMs) : elapsedII;
  labelText(clock(elapsed), 1262, 275, 18, INK);

  panel(45, 347, 876, 454);
  labelText("MFP–FFP REFERENCE SPACE", 65, 377, 14, NAVY);
  labelText("The measured point appears after the recognition recording ends.", 65, 396, 11, MUTED);
  drawReferenceScatter(45, 347);
  panel(936, 347, 419, 454);
  labelText("SAVED REFERENCES", 953, 378, 14, NAVY);
  for (int i = 0; i < 5; i++) {
    int yy = 421+i*67;
    stroke(BORDER);
    line(953, yy+42, 1335, yy+42);
    noStroke();
    fill(profileColor(i));
    ellipse(969, yy-3, 12, 12);
    labelText(gait[i], 991, yy+2, 13, INK);
    labelText(hasRef[i] ? "MFP "+dec(refMFP[i])+"%    FFP "+dec(refFFP[i])+"%" :
      "No reference", 991, yy+24, 11, MUTED);
  }
  buttonStyled("Back to Classification", 45, 820, 226, !recording, false);
  if (interruptedII) warning("DATA INTERRUPTED - repeat test if needed.", 294, 843);
  else if (noteII.length() > 0) warning(noteII, 294, 843);
}

int profileColor(int i) {
  int[] c = {0xFF198E81, 0xFF2F77CD, 0xFFE9A134, 0xFFD95053, 0xFF9C6DD5};
  return c[i];
}

void drawReferenceScatter(int boxX, int boxY) {
  int left = boxX+70, top = boxY+76, w = 737, h = 310;
  for (int j = 0; j <= 5; j++) {
    float x = left+w*j/5.0f, y = top+h*j/5.0f;
    stroke(BORDER);
    strokeWeight(1);
    line(x, top, x, top+h);
    line(left, y, left+w, y);
    centeredText(str(j*20), x, top+h+18, 10, MUTED);
    fill(MUTED);
    textAlign(RIGHT, CENTER);
    textSize(10);
    text(str(100-j*20), left-8, y);
  }
  labelText("MFP (%)", left+w/2-23, top+h+44, 12, INK);
  pushMatrix();
  translate(left-47, top+h/2+28);
  rotate(-HALF_PI);
  centeredText("FFP (%)", 0, 0, 12, INK);
  popMatrix();

  for (int i = 0; i < 5; i++) {
    if (!hasRef[i]) continue;
    float x = map(refMFP[i], 0, 100, left, left+w);
    float y = map(refFFP[i], 0, 100, top+h, top);
    noStroke();
    fill(profileColor(i));
    ellipse(x, y, 13, 13);
    centeredText(str(i+1), x+14, y-12, 11, profileColor(i));
  }
  if (!Float.isNaN(resultMFP) && !Float.isNaN(resultFFP)) {
    float x = map(resultMFP, 0, 100, left, left+w);
    float y = map(resultFFP, 0, 100, top+h, top);
    stroke(NAVY);
    strokeWeight(2.5f);
    line(x-10, y, x+10, y);
    line(x, y-10, x, y+10);           // Measured data: cross, references: filled dots
    strokeWeight(1);
  }
}


// ========== SECTION III: READ ONLY ORIGINAL FILTERED ACCEL/GYRO VALUES ==========
void drawSectionIII() {
  sectionHeading("SECTION III  /  MOTION DETECTION",
    "Existing accelerometer / gyroscope moving averages and persistence thresholds are unchanged.");
  panel(45, 221, 434, 134);
  panel(493, 221, 294, 134);
  panel(801, 221, 554, 134);
  labelText("MOTION STATUS", 65, 253, 12, MUTED);
  String status = (!dataLive() || !mpuOK) ? "WAITING FOR MPU" :
    (inMotion ? "IN MOTION" : "STANDING STILL");
  labelText(status, 65, 310, 27,
    !dataLive() || !mpuOK ? AMBER : (inMotion ? TEAL : NAVY));
  labelText("ACTIVITY DURATION", 511, 253, 12, MUTED);
  labelText(clock(activityMs), 511, 308, 29, NAVY);
  int elapsed = (recording && test == 6) ? millis()-startMs : elapsedIII;
  labelText("SESSION DURATION  "+clock(elapsed), 821, 260, 17, NAVY);
  button("Start Session", 821, 286, 179, !recording);
  buttonStyled("Stop", 1014, 286, 118, recording && test == 6, false);

  drawMotionGraph("ACCELERATION DEVIATION  |  | ||a|| - 9.81 |", 45, 374,
    637, 389, motionAccHistory, 3.0f, "m/s²");
  drawMotionGraph("ANGULAR SPEED  |  ||omega||", 698, 374,
    657, 389, motionGyroHistory, 1.5f, "rad/s");
  panel(45, 779, 1310, 88);
  labelText("MOTION RULE", 64, 808, 12, BLUE);
  labelText("Motion starts when either filtered measure exceeds its threshold for 160 ms.", 64, 833, 14, INK);
  labelText("Returns to still after both remain below threshold for 500 ms.", 64, 853, 12, MUTED);
  if (noteIII.length() > 0) warning(noteIII, 827, 807);
}

void drawMotionGraph(String name, int x, int y, int w, int h,
                     float[] values, float minAxis, String unit) {
  panel(x, y, w, h);
  labelText(name, x+19, y+30, 14, NAVY);
  float value = name.startsWith("ACCELERATION") ? aMotion : wMotion;
  labelText(dataLive() && mpuOK ? dec2(value)+" "+unit : "-- "+unit,
    x+w-183, y+30, 16, BLUE);

  int left = x+65, top = y+67, pw = w-93, ph = 255;
  int now = millis(), from = now-GRAPH_MS;
  float maxSeen = minAxis;
  for (int k = 0; k < motionCount; k++) {
    int idx = (motionPos-motionCount+k+HISTORY_N) % HISTORY_N;
    if (motionTime[idx] >= from) maxSeen = max(maxSeen, values[idx]);
  }
  float maxAxis = max(minAxis, maxSeen*1.18f); // Display scale only, not a new detection threshold
  for (int j = 0; j < 5; j++) {
    float yy = top+ph*j/4.0f;
    stroke(BORDER);
    line(left, yy, left+pw, yy);
    fill(MUTED);
    textAlign(RIGHT, CENTER);
    textSize(11);
    text(dec(maxAxis*(4-j)/4), left-8, yy);
  }
  stroke(BLUE);
  strokeWeight(2.2f);
  noFill();
  beginShape();
  int previous = -1;
  for (int k = 0; k < motionCount; k++) {
    int idx = (motionPos-motionCount+k+HISTORY_N) % HISTORY_N;
    int t = motionTime[idx];
    if (t < from) continue;
    if (previous >= 0 && t-previous > 300) {
      endShape();
      beginShape();
    }
    vertex(map(t, from, now, left, left+pw),
      map(constrain(values[idx], 0, maxAxis), 0, maxAxis, top+ph, top));
    previous = t;
  }
  endShape();
  strokeWeight(1);
  centeredText("-12 s", left, top+ph+20, 11, MUTED);
  centeredText("-6 s", left+pw/2, top+ph+20, 11, MUTED);
  centeredText("Now", left+pw, top+ph+20, 11, MUTED);
  centeredText("Time (s)", left+pw/2, top+ph+44, 11, MUTED);
}


// ========== SECTION IV: LIVE SESSION GRAPHS ==========
void drawBalanceGraph(int channel, int x, int y) {
  String[] name = {"MFP (%)", "FFP (%)", "HEEL (ADC)"};
  int maximum = channel == 2 ? 1023 : 100;
  int left = x+44, top = y+34, w = 333, h = 120;
  labelText(name[channel], x+3, y+15, 14, NAVY);
  for (int j = 0; j < 3; j++) {
    float yy = top+j*h/2.0f;
    stroke(BORDER);
    line(left, yy, left+w, yy);
    fill(MUTED);
    textAlign(RIGHT, CENTER);
    textSize(10);
    text(j==0 ? str(maximum) : j==1 ? str(maximum/2) : "0", left-7, yy);
  }

  // Use a fixed 15 s window for the exercise; the plot freezes when a phase ends.
  int now = (recording && test == 7) ? millis() : (balanceEndMs > 0 ? balanceEndMs : millis());
  int from = now-IV_EXERCISE_MS;
  float tolerance = channel == 2 ? HEEL_TOL : (channel == 0 ? MFP_TOL : FFP_TOL);

  int previous = -1;
  float previousTarget = Float.NaN, previousX = 0;
  for (int k = 0; k < balanceCount; k++) {
    int idx = (balancePos-balanceCount+k+IV_HISTORY_N) % IV_HISTORY_N;
    int t = balanceTime[idx];
    if (t < from) continue;
    float target = balanceTarget[channel][idx];
    if (Float.isNaN(target)) { previous = -1; continue; }
    float px = map(t, from, now, left, left+w);
    if (previous >= 0 && t-previous <= 300) {
      float upper = map(constrain(previousTarget+tolerance, 0, maximum), 0, maximum, top+h, top);
      float lower = map(constrain(previousTarget-tolerance, 0, maximum), 0, maximum, top+h, top);
      noStroke();
      fill(221, 242, 233);                    // Green tolerance band
      rect(previousX, upper, max(0, px-previousX), max(1, lower-upper));
      stroke(TEAL);
      float py = map(previousTarget, 0, maximum, top+h, top);
      float ty = map(target, 0, maximum, top+h, top);
      line(previousX, py, px, py);
      if (abs(target-previousTarget) > 0.01f) line(px, py, px, ty);
    }
    previous = t;
    previousTarget = target;
    previousX = px;
  }

  previous = -1;
  noFill();
  stroke(BLUE);
  strokeWeight(2);
  beginShape();
  for (int k = 0; k < balanceCount; k++) {
    int idx = (balancePos-balanceCount+k+IV_HISTORY_N) % IV_HISTORY_N;
    int t = balanceTime[idx];
    if (t < from) continue;
    float value = balanceValue[channel][idx];
    if (Float.isNaN(value) || (previous >= 0 && t-previous > 300)) {
      endShape();
      beginShape();
    }
    if (Float.isNaN(value)) { previous = -1; continue; }
    vertex(map(t, from, now, left, left+w), map(value, 0, maximum, top+h, top));
    previous = t;
  }
  endShape();
  strokeWeight(1);
  centeredText("-15", left, top+h+17, 10, MUTED);
  centeredText("0", left+w, top+h+17, 10, MUTED);
  centeredText("Time (s)", left+w/2, top+h+37, 11, MUTED);
}

void drawSectionIV() {
  sectionHeading("SECTION IV  /  SINGLE-LEG BALANCE",
    "First calibrate for 5 s, then start a separate 15 s balance assessment.");
  tag("BALANCE CHALLENGE", 988, 161, 188, PALE, BLUE);
  tag(refReady ? "REFERENCE READY" : "NO REFERENCE", 1190, 161, 155,
    refReady ? GREEN_PALE : PALE, refReady ? TEAL : MUTED);

  // ----- Phase controls: the second button is enabled only after calibration -----
  panel(45, 214, 1310, 99);
  labelText("01   PERSONAL CALIBRATION", 64, 241, 12, MUTED);
  labelText("02   BALANCE EXERCISE", 368, 241, 12, MUTED);
  buttonStyled("Calibrate 5 s", 64, 255, 180, !recording, true);
  buttonStyled("Start Exercise 15 s", 368, 255, 200,
    !recording && (ivPhase == 2 || ivPhase == 4) && refReady, true);
  buttonStyled("Stop", 589, 255, 94, recording && test == 7, false);
  int phaseLength = ivPhase <= 2 ? IV_CAL_MS : IV_EXERCISE_MS;
  int ms = (recording && test == 7) ? min(phaseLength, millis()-startMs) : elapsedIV;
  String timerName = ivPhase == 1 ? "CALIBRATION" : "EXERCISE";
  if (ivPhase == 0) timerName = "READY TO CALIBRATE";
  else if (ivPhase == 2) timerName = "REFERENCE SAVED";
  else if (ivPhase == 4) timerName = "EXERCISE FINISHED";
  labelText(timerName, 915, 243, 12, MUTED);
  labelText(clock(ms)+" / "+clock(phaseLength), 915, 282, 25, NAVY);

  // ----- Current instructions and progress bar -----
  panel(45, 325, 1310, 79);
  labelText("CURRENT INSTRUCTION", 64, 351, 11, MUTED);
  String instruction;
  if (ivPhase == 1) instruction = "Keep your initial posture steady while the reference is measured";
  else if (ivPhase == 3) instruction = directionIV;
  else if (ivPhase == 2) instruction = "Reference saved. Press Start Exercise when you are ready";
  else if (ivPhase == 4) instruction = "Exercise complete. Review results or press Start Exercise again";
  else instruction = "Stand on your left foot, then press Calibrate 5 s";
  labelText(instruction, 64, 379, 17, NAVY);
  noStroke();
  fill(PALE);
  rect(1015, 368, 317, 11, 6);
  float progress = (recording && test == 7) ? constrain((float)ms/phaseLength, 0, 1) :
    (ivPhase == 2 || ivPhase == 4 ? 1 : 0);
  fill(TEAL);
  rect(1015, 368, 317*progress, 11, 6);

  // ----- Three large FSR target graphs -----
  for (int i = 0; i < 3; i++) {
    int x = 45+445*i;
    panel(x, 417, 422, 229);
    drawBalanceGraph(i, x+16, 432);
  }

  // ----- Outcomes: original FSR scoring plus signed AP/ML tilt -----
  panel(45, 660, 1310, 222);
  boolean showResults = ivPhase == 4 && tiltSamplesIV > 0;
  String apMean = showResults ? String.format(Locale.US, "%+.1f°", meanTiltIV(0)) : "--";
  String mlMean = showResults ? String.format(Locale.US, "%+.1f°", meanTiltIV(1)) : "--";
  metricCard("MFP IN TARGET", ivPhase >= 3 ? ratio(insideMs[0], exerciseMs) : "--", 64, 681, 406, 61);
  metricCard("FFP IN TARGET", ivPhase >= 3 ? ratio(insideMs[1], exerciseMs) : "--", 487, 681, 406, 61);
  metricCard("HEEL IN TARGET", ivPhase >= 3 ? ratio(insideMs[2], exerciseMs) : "--", 910, 681, 422, 61);
  metricCard("MEAN AP TILT (RELATIVE)", apMean, 64, 752, 615, 74);
  metricCard("MEAN ML TILT (RELATIVE)", mlMean, 697, 752, 635, 74);

  String tilt = (ivPhase == 4 && imuSamplesIV > 0) ? dec(sqrt(angleSquares/imuSamplesIV))+"°" : "--";
  String angular = (ivPhase == 4 && imuSamplesIV > 0) ? dec2(sqrt(gyroSquares/imuSamplesIV))+" rad/s" : "--";
  labelText("3D TILT RMS: "+tilt+"    |    ANGULAR SPEED RMS: "+angular+
    "    |    AP/ML tilt is relative to the stationary reference", 64, 854, 12, MUTED);
  if (noteIV.length() > 0) labelText(noteIV, 64, 873, 11, noteIV.startsWith("Reference saved") || noteIV.startsWith("Exercise completed") ? TEAL : RED);
}

void clearIVDisplay() {
  // A new calibration invalidates the previous reference and exercise results.
  ivPhase = 0;
  refReady = false;
  elapsedIV = 0;
  balancePos = balanceCount = balanceEndMs = 0;
  exerciseMs = 0;
  refSamples = 0;
  lastBalanceTime = -1;
  tiltNow = Float.NaN;
  angleSquares = gyroSquares = 0;
  imuSamplesIV = tiltSamplesIV = 0;
  directionIV = "--";
  noteIV = "";
  for (int i = 0; i < 3; i++) {
    refIV[i] = refSumIV[i] = targetIV[i] = 0;
    accRef[i] = accRefSum[i] = 0;
    insideMs[i] = 0;
  }
  for (int i = 0; i < 2; i++) {
    tiltRefIV[i] = tiltSumIV[i] = 0;
  }
}

// ========== MOUSE: VISIBLE BUTTON LOCATIONS MATCH THE DRAW ROUTINES ==========
void mousePressed() {
  for (int i = 0; i < 4; i++) {          // Four top-level sections only
    if (hit(45+333*i, 84, 320, 38)) {
      if (!recording) {
        section = i;
        field = -1;
        editing = -1;
      }
      return;
    }
  }

  if (section == 0) {
    field = -1;
    if (!recording && hit(179, 655, 106, 32)) field = 0;
    else if (!recording && hit(417, 655, 106, 32)) field = 1;
    else if (!recording && hit(612, 653, 171, 34)) startTest(-1);
    else if (recording && test == -1 && hit(795, 653, 85, 34)) stopTest(false);
  }
  else if (section == 1) {
    field = -1;
    if (viewII == 0) {
      if (!recording && hit(284, 554, 200, 34)) viewII = 1;
      else if (!recording && hit(912, 554, 205, 34)) viewII = 2;
    }
    else if (viewII == 1) {
      if (recording && test >= 0 && test < 5 && hit(1166, 202, 175, 34)) {
        stopTest(false);
        return;
      }
      for (int i = 0; i < 5; i++) {
        int y = 236+i*108;
        if (!recording && hit(997, y+34, 172, 34)) {
          startTest(i);                   // Calibrate only the chosen profile
          return;
        }
        if (!recording && editing == i) {
          if (hit(470, y+38, 123, 32)) { field = 0; return; }
          if (hit(665, y+38, 123, 32)) { field = 1; return; }
          if (hit(1182, y+34, 148, 34)) { saveEdit(i); return; }
        } else if (!recording && hit(1182, y+34, 148, 34)) {
          editing = i;
          editText[0] = hasRef[i] ? dec(refMFP[i]) : "";
          editText[1] = hasRef[i] ? dec(refFFP[i]) : "";
          noteII = "";
          return;
        }
      }
      if (!recording && hit(45, 800, 270, 34)) {
        viewII = 0;
        editing = -1;
      }
    }
    else {                                // Recognition view
      if (!recording && hit(934, 253, 179, 34)) startTest(5);
      else if (recording && test == 5 && hit(1123, 253, 120, 34)) stopTest(false);
      else if (!recording && hit(45, 820, 226, 34)) viewII = 0;
    }
  }
  else if (section == 2) {
    if (!recording && hit(821, 286, 179, 34)) startTest(6);
    else if (recording && test == 6 && hit(1014, 286, 118, 34)) stopTest(false);
  }
  else {
    if (!recording && hit(64, 255, 180, 34)) {
      startIVCalibration();                   // Independently start the 5 s calibration
    } else if (!recording && hit(368, 255, 200, 34) && (ivPhase == 2 || ivPhase == 4) && refReady) {
      startIVExercise();                      // The 15 s exercise requires another click
    } else if (recording && test == 7 && hit(589, 255, 94, 34)) {
      stopTest(false);                        // Stop only the active phase
    }
  }
}

// ========== KEYBOARD: MANUAL NUMERIC INPUT ==========
void keyPressed() {                            // Called when the user presses a key
  if (recording || field < 0 || section > 1) return;

  String s = section == 0 ? (field == 0 ? stepLength : stepWidth) : editText[field];
  // Pick active text field: Section I lengths OR Section II MFP/FFP.

  if (key == ENTER || key == RETURN) {
    field = -1;                               // Confirm input by leaving the field
    return;
  }
  if (key == BACKSPACE && s.length() > 0) {
    s = s.substring(0, s.length()-1);         // Remove last character from string
  } else if (key >= '0' && key <= '9' && s.length() < 7) {
    s += key;                                 // Add typed digit to string (not number yet)
  } else if (key == '.' && s.indexOf('.') < 0 && s.length() < 7) {
    s += '.';                                 // Allow a decimal point only once
  }

  if (section == 0) {
    if (field == 0) stepLength = s;
    else stepWidth = s;
  } else {
    editText[field] = s;                     // Keep edited text until Save is pressed
  }
}

void saveEdit(int i) {
  float m = parsePercent(editText[0]);         // String -> MFP percentage
  float f = parsePercent(editText[1]);         // String -> FFP percentage
  if (Float.isNaN(m) || Float.isNaN(f)) {
    noteII = "Enter MFP and FFP between 0 and 100.";
    return;
  }
  refMFP[i] = m;
  refFFP[i] = f;
  hasRef[i] = true;                           // Recognition may now use this profile
  editing = -1;
  field = -1;
  noteII = "";
}


// ========== INPUT CONVERSION AND TEXT FORMATTING ==========
float parsePositive(String s) {
  try {
    float v = Float.parseFloat(s);           // Convert String -> decimal float
    return v > 0 && !Float.isInfinite(v) ? v : Float.NaN;
  } catch (Exception e) {
    return Float.NaN;                        // Empty/invalid input: display --
  }
}

float parsePercent(String s) {
  try {
    float v = Float.parseFloat(s);
    return v >= 0 && v <= 100 && !Float.isNaN(v) ? v : Float.NaN;
  } catch (Exception e) {
    return Float.NaN;
  }
}

String dec(float v) {
  return String.format(Locale.US, "%.1f", v); // One decimal digit, dot separator
}

String dec2(float v) {
  return String.format(Locale.US, "%.2f", v); // Two decimal digits
}

String cm(float v) {
  return Float.isNaN(v) ? "--" : dec(v)+" cm";
}

String pct(float v) {
  return Float.isNaN(v) ? "--" : dec(v)+"%";
}

String clock(long ms) {
  int s = (int)(ms/1000);
  return nf(s/60, 2) + ":" + nf(s%60, 2);     // Milliseconds -> mm:ss
}

String ratio(long inside, long total) {
  return total > 0 ? dec(100.0f*inside/total)+"%" : "--";
}
