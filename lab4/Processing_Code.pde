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
final int SECTION_IV_MS = 20000;
final int IV_REFERENCE_MS = 3000;               // First 3 s reference, remaining 17 s exercise
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

// ========== SECTION IV: BALANCE AND WEIGHT SHIFT ==========
int modeIV = 0;                                 // 0=Balance; 1=Weight Shift Game
final int MIN_PERCENT_TOTAL = 30;             // Below this total, MFP/FFP percentages are unreliable
final float MFP_TOL = 6, FFP_TOL = 6;          // Balance bands: percentage points
final float HEEL_TOL = 80;                      // Balance and game HEEL band: ADC units
final float SHIFT_AMOUNT = 12;                 // Game MFP/FFP shift: percentage points
final float SHIFT_TOL = 5;                     // Game MFP/FFP target tolerance
final float HEEL_SHIFT = 100;                  // Game HEEL target change: ADC units
float[] refIV = new float[3];                   // Baseline: MFP%, FFP%, HEEL ADC
float[] refSumIV = new float[3];                // Running baseline sums
float[] targetIV = new float[3];                // Current green target lines on three graphs
float[] accRef = new float[3];                   // Mean 3D gravity vector from baseline
float[] accRefSum = new float[3];
int refSamples = 0;
boolean refReady = false;
long[] insideMs = new long[3];                 // Balance: time in each of three target bands
long gameHitMs = 0;                             // Weight Shift: time meeting requested targets
long exerciseMs = 0;                            // Valid exercise duration (after baseline)
long lastBalanceTime = -1;
float tiltNow = Float.NaN;                      // Approx. change in sensor orientation [degrees]
float angleSquares = 0, gyroSquares = 0;        // Sums of squares for RMS computation
int imuSamplesIV = 0;
String directionIV = "--", noteIV = "";

// ========== SECTION IV: SESSION GRAPH HISTORY ==========
// Keep only samples acquired after Start; preserve them after Stop.
final int IV_HISTORY_N = 600;                     // Enough for 20 s at about 25 samples/s
int[] balanceTime = new int[IV_HISTORY_N];       // Processing time for each test sample
float[][] balanceValue = new float[3][IV_HISTORY_N];  // [MFP, FFP, HEEL][sample slot]
float[][] balanceTarget = new float[3][IV_HISTORY_N]; // Target active WHEN sample was acquired
int balancePos = 0, balanceCount = 0;            // Circular index and filled positions
int balanceEndMs = 0;                            // Freeze IV graph after Stop, even if other tests run


// ========== SETUP ==========
void setup() {
  size(1400, 900);                              // Processing window dimensions [pixels]
  frameRate(30);                                // UI refresh; sensor rate comes from Arduino
  Locale.setDefault(Locale.US);                 // Use dot for decimal numbers

  graphColor[0] = color(215, 55, 55);           // Medial Forefoot: red
  graphColor[1] = color(45, 100, 210);          // Lateral Forefoot: blue
  graphColor[2] = color(25, 150, 85);           // Medial Midfoot: green
  graphColor[3] = color(220, 140, 30);          // Heel: orange

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
    graphTime[graphPos] = arrival;             // Circular buffer: timestamp at current slot

    for (int i = 0; i < 4; i++) {
      graphFSR[i][graphPos] = fsr[i];          // Save synchronized filtered FSR readings
    }
    graphPos = (graphPos + 1) % HISTORY_N;    // Next slot; wrap and replace oldest when full
    if (graphCount < HISTORY_N) graphCount++;

    // ----- Update continuous motion recognition (also when III is not open) -----
    if (mpuOK) updateMotion(sampleTime);
    else resetMotionFilter();                 // MPU invalid: discard old window and state

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
  if (test == -1) interruptedI = true;
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
    }
  } else if (footDown && total <= CONTACT_OFF) {
    footDown = false;                        // Below lower threshold -> allow next contact
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


// ========== SECTION IV: WEIGHT-SHIFT TARGETS ==========
void setShiftTarget(int phase) {
  for (int i = 0; i < 3; i++) {
    targetIV[i] = refIV[i];                 // Reset targets to personal baseline first
  }

  if (phase == 0) {
    directionIV = "SHIFT MEDIALLY";
    targetIV[0] = constrain(refIV[0] + SHIFT_AMOUNT, 0, 100); // Raise MFP
  } else if (phase == 1) {
    directionIV = "SHIFT LATERALLY";
    targetIV[0] = constrain(refIV[0] - SHIFT_AMOUNT, 0, 100); // Lower MFP
  } else if (phase == 2) {
    directionIV = "SHIFT TO FOREFOOT";
    targetIV[1] = constrain(refIV[1] + SHIFT_AMOUNT, 0, 100); // Raise FFP
    targetIV[2] = max(0, refIV[2] - HEEL_SHIFT);  // Unload heel
  } else {
    directionIV = "SHIFT TO HEEL";
    targetIV[1] = constrain(refIV[1] - SHIFT_AMOUNT, 0, 100); // Lower FFP
    targetIV[2] = min(1023, refIV[2] + HEEL_SHIFT); // Load heel
  }
}


// ========== SECTION IV: SAVE ONE SESSION GRAPH SAMPLE ==========
void saveBalancePoint(float[] current) {
  balanceTime[balancePos] = millis();            // X coordinate, relative to the current session
  for (int i = 0; i < 3; i++) {
    balanceValue[i][balancePos] = current[i];    // MFP/FFP may be NaN if total load is too low
    balanceTarget[i][balancePos] = refReady ? targetIV[i] : Float.NaN;
    // Save the target active AT THIS TIME (it changes during Weight Shift).
  }
  balancePos = (balancePos + 1) % IV_HISTORY_N;  // Next circular slot
  if (balanceCount < IV_HISTORY_N) balanceCount++;
}


// ========== SECTION IV: REFERENCE + 17 s EXERCISE ==========
void collectBalance(long t) {                 // t = Arduino time of current sample [ms]
  if (!mpuOK) {
    stopTest(false);
    noteIV = "MPU unavailable: test stopped.";
    return;
  }

  float total = totalFSR();
  boolean validLoad = total >= MIN_PERCENT_TOTAL;
  float[] current = {
    validLoad ? medialPct(total) : Float.NaN, // No meaningful percentage near zero total load
    validLoad ? forefootPct(total) : Float.NaN,
    fsr[3]                                  // HEEL is always plotted, including zero ADC
  };
  int elapsed = millis() - startMs;

  // ----- First 3 seconds: estimate personal reference without another UI state -----
  if (elapsed < IV_REFERENCE_MS) {
    saveBalancePoint(current);              // Plot calibration samples, without target yet
    if (!validLoad) return;                 // Skip invalid percentages, but NEVER stop test

    for (int i = 0; i < 3; i++) {
      refSumIV[i] += current[i];            // MFP, FFP and HEEL reference sums
      accRefSum[i] += accel[i];            // ax, ay, az reference sums
    }
    refSamples++;
    return;
  }

  // ----- Once, at first sample after 3 s: compute means -----
  if (!refReady) {
    if (refSamples == 0) {
      stopTest(false);
      noteIV = "No baseline data: test stopped.";
      return;
    }
    for (int i = 0; i < 3; i++) {
      refIV[i] = refSumIV[i] / refSamples;
      accRef[i] = accRefSum[i] / refSamples;
      targetIV[i] = refIV[i];              // Initial horizontal graph target
    }
    refReady = true;
  }

  // ----- Select current exercise target -----
  if (modeIV == 1) {
    int phase = min(3, (elapsed - IV_REFERENCE_MS) / 4250); // Four 4.25 s phases
    setShiftTarget(phase);
  } else {
    directionIV = "MAINTAIN YOUR REFERENCE";
  }

  saveBalancePoint(current);               // Store actual FSRs AND target for this phase
  if (!validLoad) {
    lastBalanceTime = -1;               // Ignore invalid percentages; no automatic Stop
    return;
  }

  // ----- Count only time intervals between consecutive valid exercise samples -----
  long dt = 0;
  if (lastBalanceTime >= 0 && t > lastBalanceTime && t - lastBalanceTime <= 300) {
    dt = t - lastBalanceTime;           // Valid time interval from previous sample
  }
  lastBalanceTime = t;
  exerciseMs += dt;

  // ----- Balance: three independent time-in-target percentages -----
  if (modeIV == 0) {
    if (abs(current[0] - targetIV[0]) <= MFP_TOL) insideMs[0] += dt;
    if (abs(current[1] - targetIV[1]) <= FFP_TOL) insideMs[1] += dt;
    if (abs(current[2] - targetIV[2]) <= HEEL_TOL) insideMs[2] += dt;
  } else {
    // ----- Game: HEEL participates when moving forward or backward -----
    boolean reached;
    if (directionIV.equals("SHIFT MEDIALLY") || directionIV.equals("SHIFT LATERALLY")) {
      reached = abs(current[0] - targetIV[0]) <= SHIFT_TOL; // MFP target only
    } else {
      boolean ffpOK = abs(current[1] - targetIV[1]) <= SHIFT_TOL;
      boolean heelOK = abs(current[2] - targetIV[2]) <= HEEL_TOL;
      reached = ffpOK && heelOK;         // BOTH FFP and HEEL must be near target
    }
    if (reached) gameHitMs += dt;
  }

  // ----- Accelerometer: change of gravity-vector direction relative to baseline -----
  float dot = accel[0]*accRef[0] + accel[1]*accRef[1] + accel[2]*accRef[2];
  float lengthNow = magnitude(accel[0], accel[1], accel[2]);
  float lengthRef = magnitude(accRef[0], accRef[1], accRef[2]);

  if (lengthNow > 0.01f && lengthRef > 0.01f) {
    float cosAngle = constrain(dot / (lengthNow*lengthRef), -1, 1);
    tiltNow = degrees(acos(cosAngle));    // Angle between current and reference vectors [deg]
    angleSquares += tiltNow * tiltNow;    // RMS numerator: sum of squared angles

    float w = magnitude(gyro[0], gyro[1], gyro[2]);
    gyroSquares += w*w;                   // RMS numerator: squared angular speed
    imuSamplesIV++;
  }
}


// ========== START A TEST ==========
void startTest(int selected) {
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
  } else {                                // ----- Section IV -----
    elapsedIV = 0;
    noteIV = "";
    refSamples = 0;
    refReady = false;
    lastBalanceTime = -1;
    balancePos = 0;                      // Clear old Section IV session graph
    balanceCount = 0;                    // Graph is empty until new Start
    balanceEndMs = 0;
    exerciseMs = 0;
    gameHitMs = 0;

    for (int i = 0; i < 3; i++) {
      refIV[i] = 0;
      refSumIV[i] = 0;
      targetIV[i] = 0;
      accRef[i] = 0;
      accRefSum[i] = 0;
      insideMs[i] = 0;
    }
    tiltNow = Float.NaN;
    angleSquares = 0;
    gyroSquares = 0;
    imuSamplesIV = 0;
    directionIV = "REFERENCE (FIRST 3 s)";
  }
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
  } else {
    elapsedIV = min(elapsed, SECTION_IV_MS);
    balanceEndMs = startMs + elapsedIV;    // Keep the graph frozen at this test's final time
    if (!refReady && noteIV.length() == 0) {
      noteIV = "Stopped before reference was ready.";
    }
  }
}


// ========== MAIN DRAW LOOP ==========
void draw() {                              // Processing calls draw() repeatedly
  if (recording) {
    // Check data loss BEFORE the automatic timeout, so the warning is never missed.
    if (!dataLive()) {
      if (test <= 5) {
        markInterrupted();                // I/II: keep the test running, show warning
      } else {
        stopTest(false);                  // III/IV: no reliable motion data, stop
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
      else if (test == 7 && millis() - startMs >= SECTION_IV_MS) stopTest(true);
    }
  }

  background(255);                         // Clear previous frame to white
  drawHeader();                            // Title, connection status and four tabs
  drawHeatmap();                           // Shared live foot map

  for (int i = 0; i < 4; i++) {
    int x = 430 + (i % 2)*460;           // Column 0 or 1 (% = division remainder)
    int y = 160 + (i / 2)*215;           // Row 0 or 1 (integer division)
    drawGraph(i, x, y);
  }

  stroke(215);                            // stroke() sets the color of drawn lines/borders
  line(45, 601, 1355, 601);              // Horizontal separator

  if (section == 0) drawSectionI();
  else if (section == 1) drawSectionII();
  else if (section == 2) drawSectionIII();
  else drawSectionIV();
}


// ========== HEADER AND SECTION TABS ==========
void drawHeader() {
  fill(25);                               // fill() sets text color or inside color of shapes
  textAlign(LEFT, BASELINE);             // Place text using its left edge/baseline
  textSize(27);                           // Font size in pixels
  text("SMART INSOLE", 45, 43);         // text(content, x, y)

  fill(110);
  textSize(13);
  text("Gait Analysis Lab", 47, 65);

  if (dataLive()) fill(35, 135, 70);     // Live serial = green
  else fill(175, 60, 50);               // Not live = red

  textAlign(RIGHT, BASELINE);
  String status = dataLive() ? "FSR LIVE  |  MPU " + (mpuOK ? "OK" : "OFF") : "WAITING FOR DATA";
  // condition ? trueValue : falseValue is a compact if/else expression.
  if (!dataLive() && serialError.length() > 0) status = serialError;
  text(status, 1355, 43);

  String[] tabs = {"SECTION I", "SECTION II", "SECTION III", "SECTION IV"};
  for (int i = 0; i < 4; i++) {
    int x = 45 + 330*i;
    stroke(i == section ? 90 : 195);    // Different outline for selected tab
    fill(i == section ? 230 : 255);    // Selected tab has light grey background
    rect(x, 83, 310, 42, 4);           // rect(x, y, width, height, corner radius)

    fill(30);
    textSize(14);
    textAlign(CENTER, CENTER);
    text(tabs[i], x+155, 104);
  }
}


// ========== LEFT-FOOT PRESSURE MAP ==========
void drawHeatmap() {
  stroke(185);
  fill(255);
  rect(45, 155, 340, 430, 4);          // Single box surrounding heatmap only
  fill(25);
  textAlign(LEFT, BASELINE);
  textSize(16);
  text("FSR Pressure Map - Left Foot", 60, 182);

  // ----- Outline of LEFT foot, drawn with joined Bezier curves -----
  pushMatrix();                         // Save original coordinate system
  translate(85, 210);                  // Move local origin to window position (85,210)
  scale(1.30f, 1.05f);                 // Multiply local X and Y coordinates
  stroke(90);
  strokeWeight(1.2f);                 // Outline thickness in pixels
  fill(250);

  beginShape();                        // Start one connected contour
  vertex(108, 12);                    // Starting point: (x,y)
  bezierVertex(80, 12, 54, 21, 43, 48);
  // bezierVertex(control1X,Y, control2X,Y, endX,Y): curved segment ending at last pair.
  bezierVertex(25, 76, 33, 123, 47, 151);
  bezierVertex(64, 183, 70, 196, 63, 223);
  bezierVertex(57, 250, 54, 277, 67, 300);
  bezierVertex(83, 327, 120, 324, 141, 310);
  bezierVertex(166, 293, 163, 267, 152, 237);
  bezierVertex(144, 209, 153, 185, 165, 152);
  bezierVertex(186, 110, 184, 71, 163, 39);
  bezierVertex(151, 21, 136, 12, 108, 12);
  endShape(CLOSE);                    // Join final point to initial point

  bubble(142, 72, dataLive() ? fsr[0] : 0, "MF");   // Medial forefoot: upper-right
  bubble(77, 141, dataLive() ? fsr[1] : 0, "LF");   // Lateral forefoot: left
  bubble(124, 127, dataLive() ? fsr[2] : 0, "MM");  // Medial midfoot
  bubble(108, 282, dataLive() ? fsr[3] : 0, "HEEL");// Heel
  popMatrix();                                         // Restore coordinates for other UI elements

  fill(105);
  textAlign(CENTER, BASELINE);
  textSize(12);
  text("Blue: low  |  Red: high", 215, 567);
}


void bubble(float x, float y, float value, String label) {
  float level = constrain(value/1023.0f, 0, 1);  // Normalize FSR ADC 0..1023 to 0..1
  int c = lerpColor(color(50, 125, 225), color(230, 55, 45), level);
  // lerpColor(blue, red, level): mix two colors according to relative load.
  noStroke();                          // Do not draw a border around the bubble
  fill(dataLive() && value >= 1 ? c : color(210));
  float diameter = 16 + 40*level;      // Bubble diameter grows with sensor reading
  ellipse(x, y, diameter, diameter);   // ellipse(centerX, centerY, width, height)

  fill(20);
  textAlign(CENTER, CENTER);
  textSize(9);
  text(label, x, y);
}


// ========== MAIN FSR GRAPHS ==========
void drawGraph(int channel, int x, int y) {
  int left = x+45, top = y+31, w = 357, h = 118;
  fill(25);
  textAlign(LEFT, BASELINE);
  textSize(15);
  String value = dataLive() ? ((int)fsr[channel])+" ADC" : "-- ADC";
  text(fsrName[channel] + "  (" + value + ")", x, y+16);

  // ----- Fixed ADC axis, three horizontal grid lines -----
  for (int j = 0; j < 3; j++) {
    float yy = top + j*h/2.0f;
    stroke(230);
    line(left, yy, left+w, yy);          // Horizontal guide line
    fill(100);
    textSize(11);
    textAlign(RIGHT, CENTER);
    text(j == 0 ? "1023" : (j == 1 ? "512" : "0"), left-7, yy);
  }
  stroke(55);
  line(left, top, left, top+h);        // Y axis
  line(left, top+h, left+w, top+h);    // X axis

  // ----- Read circular buffer in chronological order and plot last 12 s -----
  int now = millis();
  int from = now-GRAPH_MS;
  int previous = -1;
  noFill();                           // Plot as a line, not a filled shape
  stroke(graphColor[channel]);
  strokeWeight(2);
  beginShape();                       // Begin a connected line of points

  for (int k = 0; k < graphCount; k++) {
    int idx = (graphPos - graphCount + k + HISTORY_N) % HISTORY_N;
    // Recover chronological index: oldest first, newest last, despite circular storage.
    int t = graphTime[idx];
    if (t < from) continue;           // Ignore points older than the 12 s graph window

    if (previous >= 0 && t-previous > 300) {
      endShape();                     // End line across missing serial data
      beginShape();                   // Begin a new unconnected segment
    }
    float px = map(t, from, now, left, left+w); // map() converts time range -> X pixels
    float py = map(graphFSR[channel][idx], 0, 1023, top+h, top);
    // ADC 0 is bottom of plot; ADC 1023 is top (screen Y increases downwards).
    vertex(px, py);                  // Add this (x,y) sample to graph polyline
    previous = t;
  }
  endShape();                         // Finish and draw line
  strokeWeight(1);

  fill(85);
  textSize(11);
  textAlign(CENTER, BASELINE);
  text("-12", left, top+h+16);
  text("-6", left+w/2, top+h+16);
  text("0", left+w, top+h+16);
  text("Time (s)", left+w/2, top+h+32);
}


// ========== SECTION I: NORMAL WALKING UI ==========
void drawSectionI() {
  fill(25);
  textAlign(LEFT, BASELINE);
  textSize(19);
  text("Section I - Normal Walking", 45, 637);
  fill(95);
  textSize(13);
  text("Enter measured lengths (cm); record normal walking for up to 2 minutes.", 45, 660);

  fill(35);
  textSize(14);
  text("Step length (cm)", 45, 700);
  text("Step width (cm)", 370, 700);
  inputBox(188, 676, 135, stepLength, field == 0);
  inputBox(505, 676, 135, stepWidth, field == 1);
  button("Start Recording", 715, 676, 180, !recording);
  button("Stop", 909, 676, 90, recording && test == -1);

  int ms = (recording && test == -1) ? min(SECTION_I_MS, millis()-startMs) : elapsedI;
  fill(30);
  textSize(17);
  textAlign(RIGHT, CENTER);
  text(clock(ms) + " / 02:00", 1355, 696);

  float L = parsePositive(stepLength);         // Convert typed text -> measured length
  float W = parsePositive(stepWidth);
  float C = cadence();                         // From same-foot accepted contact timestamps
  fill(35);
  textSize(16);
  textAlign(LEFT, BASELINE);
  text("Estimated steps: " + (sectionIResult || recording ? str(2*contacts) : "--"), 45, 783);
  text("Cadence: " + (Float.isNaN(C) ? "--" : dec(C)+" steps/min"), 445, 783);
  text("Step length: " + cm(L), 920, 783);
  text("Stride length: " + cm(2*L), 45, 824); // Approximate: symmetric gait assumed
  text("Step width: " + cm(W), 445, 824);

  if (interruptedI) warning("DATA INTERRUPTED - check connection; repeat test if needed.", 45, 863);
  else if (noteI.length() > 0) warning(noteI, 45, 863);
}


// ========== SECTION II: FIVE CALIBRATIONS AND RECOGNITION UI ==========
void drawSectionII() {
  fill(25);
  textAlign(LEFT, BASELINE);
  textSize(19);
  text("Section II - Gait Classification", 45, 637);

  int ms = (recording && test >= 0 && test <= 5) ? min(SECTION_II_MS, millis()-startMs) : elapsedII;
  fill(65);
  textSize(13);
  textAlign(RIGHT, BASELINE);
  text(clock(ms) + " / 00:30", 1355, 637);

  // ----- Same simple panel for all five gait profiles -----
  for (int i = 0; i < 5; i++) {
    int x = 45 + 264*i;
    int y = 665;
    stroke(recording && test == i ? color(85, 135, 205) : color(195));
    fill(251);
    rect(x, y, 254, 138, 4);

    fill(25);
    textSize(13);
    textAlign(CENTER, CENTER);
    text(gait[i], x+127, y+18);
    button("Calibrate", x+12, y+36, 230, !recording);

    fill(45);
    textSize(12);
    textAlign(LEFT, CENTER);
    if (editing == i) {
      text("MFP", x+12, y+86);
      text("FFP", x+12, y+112);
      inputBox(x+55, y+74, 100, editText[0], field == 0);
      inputBox(x+55, y+100, 100, editText[1], field == 1);
      button("Save", x+182, y+109, 60, !recording);
    } else {
      text("MFP: " + (hasRef[i] ? dec(refMFP[i])+"%" : "--"), x+12, y+86);
      text("FFP: " + (hasRef[i] ? dec(refFFP[i])+"%" : "--"), x+12, y+108);
      button("Edit", x+182, y+109, 60, !recording);
    }
  }

  button("Automatic Recognition", 45, 824, 185, !recording);
  button("Stop", 242, 824, 85, recording && test >= 0 && test <= 5);
  fill(30);
  textSize(13);
  textAlign(LEFT, BASELINE);
  String result = "MFP: " + pct(resultMFP) + "   FFP: " + pct(resultFFP) + "   Detected: " + detected;
  text(result, 352, 848);                       // Keep results visible even if warning exists

  if (interruptedII) warning("DATA INTERRUPTED - check connection; repeat test if needed.", 45, 881);
  else if (noteII.length() > 0) warning(noteII, 45, 881);
}


// ========== SECTION III: MOTION STATUS AND DURATION UI ==========
void drawSectionIII() {
  fill(25);
  textAlign(LEFT, BASELINE);
  textSize(19);
  text("Section III - Motion Detection", 45, 637);

  String status = (!dataLive() || !mpuOK) ? "WAITING FOR MPU" :
    (inMotion ? "IN MOTION" : "STANDING STILL");
  fill(inMotion && dataLive() && mpuOK ? color(35, 135, 70) : color(45));
  textSize(24);
  text(status, 45, 705);
  fill(95);
  textSize(13);
  text("Motion Status", 45, 667);

  text("Activity Duration", 440, 667);
  fill(30);
  textSize(26);
  text(clock(activityMs), 440, 705);
  button("Start", 820, 673, 125, !recording);
  button("Stop", 959, 673, 125, recording && test == 6);

  int ms = (recording && test == 6) ? millis()-startMs : elapsedIII;
  fill(95);
  textSize(13);
  textAlign(RIGHT, BASELINE);
  text("Session: " + clock(ms), 1355, 693);

  stroke(230);
  line(45, 740, 1355, 740);
  fill(40);
  textAlign(LEFT, BASELINE);
  textSize(16);
  text("a = " + (dataLive() && mpuOK ? dec(aMotion) : "--") + " m/s²", 45, 795);
  text("Angular velocity = " + (dataLive() && mpuOK ? dec2(wMotion) : "--") + " rad/s", 440, 795);
  // a is deviation from 9.81, not raw 3D acceleration magnitude.
  if (noteIII.length() > 0) warning(noteIII, 45, 862);
}


// ========== SECTION IV: GRAPH OF MFP, FFP OR HEEL ==========
void drawBalanceGraph(int channel, int x, int y) {
  String[] label = {"MFP (%)", "FFP (%)", "HEEL (ADC)"};
  int maxY = channel == 2 ? 1023 : 100;
  int left = x+34, top = y+23, w = 345, h = 66;

  fill(35);
  textAlign(LEFT, BASELINE);
  textSize(13);
  text(label[channel], x, y+10);
  stroke(220);
  line(left, top, left, top+h);
  line(left, top+h, left+w, top+h);
  fill(110);
  textSize(10);
  textAlign(RIGHT, CENTER);
  text(str(maxY), left-5, top);
  text("0", left-5, top+h);

  // ----- Sliding 17 s window of THIS SESSION; freeze its X axis after Stop -----
  int now = (recording && test == 7) ? millis() : balanceEndMs;
  int from = now - 17000;
  float tolerance = channel == 2 ? HEEL_TOL :
    (modeIV == 0 ? (channel == 0 ? MFP_TOL : FFP_TOL) : SHIFT_TOL);

  // ----- Draw stored target and tolerance band: game targets change over time -----
  int previous = -1;
  float previousTarget = Float.NaN;
  float previousX = 0;
  for (int k = 0; k < balanceCount; k++) {
    int idx = (balancePos-balanceCount+k+IV_HISTORY_N) % IV_HISTORY_N;
    int t = balanceTime[idx];
    if (t < from) continue;
    float target = balanceTarget[channel][idx];
    if (Float.isNaN(target)) {               // Calibration: no target yet
      previous = -1;
      continue;
    }
    float px = map(t, from, now, left, left+w);
    if (previous >= 0 && t-previous <= 300) {
      float upper = map(constrain(previousTarget+tolerance, 0, maxY), 0, maxY, top+h, top);
      float lower = map(constrain(previousTarget-tolerance, 0, maxY), 0, maxY, top+h, top);
      noStroke();
      fill(225, 243, 225);
      rect(previousX, upper, max(0, px-previousX), max(1, lower-upper)); // Historical band

      stroke(40, 145, 75);
      float previousY = map(previousTarget, 0, maxY, top+h, top);
      float currentY = map(target, 0, maxY, top+h, top);
      line(previousX, previousY, px, previousY); // Horizontal target until this sample
      if (abs(target-previousTarget) > 0.01f) line(px, previousY, px, currentY);
      // Vertical jump when the requested Weight Shift direction changes
    }
    previous = t;
    previousTarget = target;
    previousX = px;
  }

  // ----- Plot saved FSR values; HEEL includes zero, MFP/FFP skip undefined ratios -----
  previous = -1;
  noFill();
  stroke(90, 100, 125);
  strokeWeight(1.7f);
  beginShape();
  for (int k = 0; k < balanceCount; k++) {
    int idx = (balancePos-balanceCount+k+IV_HISTORY_N) % IV_HISTORY_N;
    int t = balanceTime[idx];
    if (t < from) continue;

    float value = balanceValue[channel][idx];
    if (Float.isNaN(value) || (previous >= 0 && t-previous > 300)) {
      endShape();                           // Missing ratio or data gap: break the curve
      beginShape();
    }
    if (Float.isNaN(value)) {
      previous = -1;                       // No MFP/FFP when almost no FSR load
      continue;
    }
    float px = map(t, from, now, left, left+w);
    float py = map(value, 0, maxY, top+h, top);
    vertex(px, py);                        // Connect valid samples in chronological order
    previous = t;
  }
  endShape();
  strokeWeight(1);
  fill(110);
  textAlign(CENTER, BASELINE);
  textSize(10);
  text("-17 s", left, top+h+13);
  text("Now", left+w, top+h+13);
}


// ========== SECTION IV: BALANCE / WEIGHT SHIFT UI ==========
void drawSectionIV() {
  fill(25);
  textAlign(LEFT, BASELINE);
  textSize(19);
  text("Section IV - Single-Leg Balance Challenge", 45, 637);
  modeButton("Balance", 525, 615, 110, modeIV == 0);
  modeButton("Weight Shift Game", 647, 615, 165, modeIV == 1);

  int ms = (recording && test == 7) ? min(SECTION_IV_MS, millis()-startMs) : elapsedIV;
  fill(55);
  textSize(14);
  textAlign(RIGHT, BASELINE);
  text(clock(ms) + " / 00:20", 1355, 637);

  drawBalanceGraph(0, 45, 664);                 // MFP
  drawBalanceGraph(1, 485, 664);                // FFP
  drawBalanceGraph(2, 925, 664);                // HEEL

  fill(75);
  textSize(12);
  textAlign(LEFT, BASELINE);
  String instruction = (recording && test == 7 && ms < IV_REFERENCE_MS) ?
    "Calibrating reference (first 3 s)..." : directionIV;
  text(instruction, 45, 795);

  button("Start", 45, 812, 120, !recording);
  button("Stop", 178, 812, 90, recording && test == 7);

  fill(40);
  textSize(13);
  textAlign(LEFT, BASELINE);
  if (modeIV == 0) {
    String score = "Time in target:  MFP " + ratio(insideMs[0], exerciseMs) +
      "   FFP " + ratio(insideMs[1], exerciseMs) + "   HEEL " + ratio(insideMs[2], exerciseMs);
    text(score, 290, 833);
  } else {
    text("Target reached: " + ratio(gameHitMs, exerciseMs), 290, 833);
  }

  String tilt = imuSamplesIV > 0 ? dec(sqrt(angleSquares/imuSamplesIV))+"°" : "--";
  String angular = imuSamplesIV > 0 ? dec2(sqrt(gyroSquares/imuSamplesIV))+" rad/s" : "--";
  text("Ankle tilt RMS: " + tilt + "    Angular velocity RMS: " + angular, 45, 871);
  if (noteIV.length() > 0) warning(noteIV, 680, 871);
}


// ========== REUSABLE UI CONTROLS ==========
void inputBox(int x, int y, int w, String value, boolean selected) {
  stroke(selected ? color(45, 110, 200) : color(180)); // Blue border when selected
  fill(255);
  rect(x, y, w, 24, 3);                        // rect(x, y, width, height, corners)
  fill(value.length() == 0 ? 150 : 30);
  textSize(12);
  textAlign(LEFT, CENTER);
  text(value.length() == 0 ? "Enter" : value, x+8, y+12);
}

void button(String label, int x, int y, int w, boolean enabled) {
  stroke(180);
  fill(enabled ? 246 : 253);                   // Grey background when unavailable
  rect(x, y, w, 27, 4);
  fill(enabled ? 30 : 170);                    // Grey text when unavailable
  textSize(12);
  textAlign(CENTER, CENTER);
  text(label, x+w/2, y+13);
}

void modeButton(String label, int x, int y, int w, boolean selected) {
  stroke(selected ? 70 : 190);
  fill(selected ? 225 : 250);                 // Selected mode gets darker background
  rect(x, y, w, 27, 4);
  fill(30);
  textSize(12);
  textAlign(CENTER, CENTER);
  text(label, x+w/2, y+13);
}

void warning(String message, int x, int y) {
  fill(170, 65, 45);
  textSize(12);
  textAlign(LEFT, BASELINE);
  text(message, x, y);
}

boolean hit(int x, int y, int w, int h) {
  return mouseX >= x && mouseX <= x+w && mouseY >= y && mouseY <= y+h;
  // True only if click is inside rectangle boundaries.
}


// ========== MOUSE CLICKS AND NAVIGATION ==========
void mousePressed() {                          // Processing calls this once per mouse click
  // ----- Four tabs: switching disabled while recording -----
  for (int i = 0; i < 4; i++) {
    if (hit(45+330*i, 83, 310, 42)) {
      if (!recording) {
        section = i;
        field = -1;
        editing = -1;
      }
      return;
    }
  }

  // ----- Section I: manual inputs, Start and Stop -----
  if (section == 0) {
    field = -1;
    if (!recording && hit(188, 676, 135, 24)) {
      field = 0;                            // Edit step length
      return;
    }
    if (!recording && hit(505, 676, 135, 24)) {
      field = 1;                            // Edit step width
      return;
    }
    if (!recording && hit(715, 676, 180, 27)) startTest(-1);
    else if (recording && test == -1 && hit(909, 676, 90, 27)) stopTest(false);
  }

  // ----- Section II: five profile panels, editing and recognition -----
  else if (section == 1) {
    field = -1;
    for (int i = 0; i < 5; i++) {
      int x = 45 + 264*i, y = 665;
      if (!recording && hit(x+12, y+36, 230, 27)) {
        startTest(i);
        return;
      }
      if (!recording && editing == i) {
        if (hit(x+55, y+74, 100, 24)) {
          field = 0;                         // Edit MFP
          return;
        }
        if (hit(x+55, y+100, 100, 24)) {
          field = 1;                         // Edit FFP
          return;
        }
        if (hit(x+182, y+109, 60, 27)) {
          saveEdit(i);                       // Save manual MFP/FFP
          return;
        }
      } else if (!recording && hit(x+182, y+109, 60, 27)) {
        editing = i;                          // Open numeric fields for this profile
        editText[0] = hasRef[i] ? dec(refMFP[i]) : "";
        editText[1] = hasRef[i] ? dec(refFFP[i]) : "";
        noteII = "";
        return;
      }
    }
    if (!recording && hit(45, 824, 185, 27)) startTest(5);
    else if (recording && test <= 5 && hit(242, 824, 85, 27)) stopTest(false);
  }

  // ----- Section III: separate Start / Stop buttons -----
  else if (section == 2) {
    if (!recording && hit(820, 673, 125, 27)) startTest(6);
    else if (recording && test == 6 && hit(959, 673, 125, 27)) stopTest(false);
  }

  // ----- Section IV: choose mode or Start / Stop -----
  else {
    if (!recording && hit(525, 615, 110, 27)) {
      modeIV = 0;
      refReady = false;
      elapsedIV = 0;
      balancePos = 0;
      balanceCount = 0;
    } else if (!recording && hit(647, 615, 165, 27)) {
      modeIV = 1;
      refReady = false;
      elapsedIV = 0;
      balancePos = 0;
      balanceCount = 0;
    } else if (!recording && hit(45, 812, 120, 27)) {
      startTest(7);
    } else if (recording && test == 7 && hit(178, 812, 90, 27)) {
      stopTest(false);
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
