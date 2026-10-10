import processing.serial.*;
import java.util.ArrayList;

// LAB 2: ECG and FSR monitor
// Fitness, Stress, Meditation and Section IV
// Arduino serial input: ECG,FSR or !,FSR
// FSR graph: 10-sample average (including zeros), fixed scale 0-1023
// Respiratory detection: separate 50-sample average

final int NORMAL = 0;
final int BOLD = 1;
PFont regularFont;
PFont boldFont;

final int MODE_HOME = 0;
final int MODE_FITNESS = 1;
final int MODE_STRESS = 2;
final int MODE_MEDITATION = 3;
final int MODE_SECTION_IV = 4;
int mode = MODE_HOME;

// Graphs use a fixed vertical ADC scale, like the reference UI.
final float GRAPH_WINDOW_MS = 5000;
final float GRAPH_ADC_MIN = 0;
final float GRAPH_ADC_MAX = 1023;
final Object graphLock = new Object();
ArrayList<Float> graphTimes = new ArrayList<Float>();

// VISUALIZZAZIONE FSR: stesso filtro della UI_LAB2_NO_AI originale.
// Media mobile di 10 campioni, inclusi gli zeri. Non modifica updateFSR(),
// RR, Tinsp, Tex o il filtro fisiologico di 50 campioni.
final int FSR_GRAPH_WINDOW = 10;
float[] fsrGraphWindow = new float[FSR_GRAPH_WINDOW];
int fsrGraphIndex = 0;
int fsrGraphCount = 0;
float fsrGraphSum = 0;

float smoothFSRForGraph(int rawFSR) {
  if (fsrGraphCount == FSR_GRAPH_WINDOW) {
    fsrGraphSum -= fsrGraphWindow[fsrGraphIndex];
  } else {
    fsrGraphCount++;
  }
  fsrGraphWindow[fsrGraphIndex] = rawFSR;
  fsrGraphSum += rawFSR;
  fsrGraphIndex = (fsrGraphIndex + 1) % FSR_GRAPH_WINDOW;
  return fsrGraphSum / fsrGraphCount;
}

// Home buttons
final int homeButtonY = 585;
final int homeButtonW = 240;
final int homeButtonH = 50;
final int fitnessButtonX = 30;
final int stressButtonX = 290;
final int meditationButtonX = 550;
final int sectionButtonX = 810;

void setup() {
  size(1100, 720);
  frameRate(60);
  regularFont = createFont("Arial", 15);
  boldFont = createFont("Arial Bold", 15);
  textFont(regularFont);
  setupSignalProcessing();
}

void textStyle(int style) {
  textFont(style == BOLD ? boldFont : regularFont);
}

void draw() {
  background(255);
  drawHeader();
  if (mode == MODE_HOME) drawHome();
  else if (mode == MODE_FITNESS) drawFitness();
  else if (mode == MODE_STRESS) drawStress();
  else if (mode == MODE_MEDITATION) drawMeditation();
  else if (mode == MODE_SECTION_IV) drawSectionIV();
}

int getHeartRate() {
  return validHeartRate() ? BPM : 0;
}
float getRespRate() {
  return validRespRate() ? respiratoryRate : 0;
}
float getInhaleTime() {
  return validRespRate() && Tinsp > 0 ? Tinsp / 1000.0 : 0;
}
float getExhaleTime() {
  return validRespRate() && Tex > 0 ? Tex / 1000.0 : 0;
}
String oneDecimal(float value) {
  return nf(value, 0, 1).replace(',', '.');
}
String twoDecimals(float value) {
  return nf(value, 0, 2).replace(',', '.');
}

void drawHeader() {
  fill(0);
  textStyle(BOLD);
  textSize(18);
  text("ECG and Breathing Monitor", 20, 32);
  textStyle(NORMAL);
  textSize(10);
  if (myPort == null) {
    fill(180, 0, 0);
    text("NO SERIAL DEVICE", 920, 28);
  } else if (!hasFreshData()) {
    fill(180, 100, 0);
    text("WAITING FOR DATA", 920, 28);
  } else if (leadsOff) {
    fill(180, 0, 0);
    text("ECG LEADS OFF", 940, 28);
  } else {
    fill(20, 150, 50);
    text("SENSOR LIVE", 960, 28);
  }
  stroke(210);
  strokeWeight(1);
  line(20, 42, 1080, 42);
}

void drawHome() {
  int hr = getHeartRate();
  float rr = getRespRate();
  float tin = getInhaleTime();
  float tex = getExhaleTime();
  fill(0);
  textSize(15);
  text("Heart Rate", 20, 78);
  text("Respiratory Rate", 280, 78);
  text("Inspiration", 570, 78);
  text("Expiration", 810, 78);
  textStyle(BOLD);
  textSize(20);
  text(hr > 0 ? hr + " BPM" : "--", 20, 106);
  text(rr > 0 ? oneDecimal(rr) + " /min" : "--", 280, 106);
  text(tin > 0 ? twoDecimals(tin) + " s" : "--", 570, 106);
  text(tex > 0 ? twoDecimals(tex) + " s" : "--", 810, 106);
  textStyle(NORMAL);
  drawECGGraph(ecgPlot, 20, 145, 510, 320);
  drawRespGraph(fsrPlot, 570, 145, 510, 320);
  drawModeButton(fitnessButtonX, homeButtonY, homeButtonW, homeButtonH, "FITNESS MODE");
  drawModeButton(stressButtonX, homeButtonY, homeButtonW, homeButtonH, "STRESS MODE");
  drawModeButton(meditationButtonX, homeButtonY, homeButtonW, homeButtonH, "MEDITATION MODE");
  drawModeButton(sectionButtonX, homeButtonY, homeButtonW, homeButtonH, "SECTION IV");
}

// ----- SHARED GRAPH RENDERING -----
// Inspired by the reference UI's drawSignalGraph(): time window,
// 0..1023 Y mapping, polyline, no baseline subtraction or min/max zoom.
// FSR rendering receives the 10-sample graphical average, not current_mean.
// Only visualization data are copied under a lock, and the drawing happens
// AFTER releasing the lock. This avoids concurrent edits while drawing.

void drawECGGraph(ArrayList<Float> data, float x, float y, float w, float h) {
  drawADCSpectrum(data, x, y, w, h, "ECG", color(220, 45, 45));
}
void drawRespGraph(ArrayList<Float> data, float x, float y, float w, float h) {
  drawADCSpectrum(data, x, y, w, h, "FSR", color(50, 90, 220));
}

void drawADCSpectrum(ArrayList<Float> data, float x, float y, float w, float h,
                     String title, int lineColor) {
  fill(255);
  stroke(0);
  strokeWeight(1);
  rect(x, y, w, h);
  fill(0);
  textStyle(NORMAL);
  textSize(12);
  text(title, x + 10, y + 18);
  float left = x + 10;
  float right = x + w - 10;
  float top = y + 30;
  float bottom = y + h - 14;

  // Line at ADC 512, as in the example UI (NOT an FSR baseline).
  float middleY = map(512, GRAPH_ADC_MIN, GRAPH_ADC_MAX, bottom, top);
  stroke(230);
  line(left, middleY, right, middleY);
  float[] times;
  float[] values;
  synchronized (graphLock) {
    int n = min(data.size(), graphTimes.size());
    times = new float[n];
    values = new float[n];
    int dStart = data.size() - n;
    int tStart = graphTimes.size() - n;
    for (int i = 0; i < n; i++) {
      times[i] = graphTimes.get(tStart + i);
      values[i] = data.get(dStart + i);
    }
  }
  if (values.length < 2) return;

  // The reference sketch always displays the last 5 seconds.
  float latestTime = times[times.length - 1];
  float startTime = latestTime - GRAPH_WINDOW_MS;
  stroke(lineColor);
  strokeWeight(1);
  noFill();
  beginShape();
  for (int i = 0; i < values.length; i++) {
    if (times[i] < startTime) continue;
    float sx = map(times[i], startTime, latestTime, left, right);
    float sy = map(values[i], GRAPH_ADC_MIN, GRAPH_ADC_MAX, bottom, top);
    vertex(sx, constrain(sy, top, bottom));
  }
  endShape();
  strokeWeight(1);
  fill(0);
}

void clearGraphHistory() {
  synchronized (graphLock) {
    ecgPlot.clear();
    fsrPlot.clear();
    graphTimes.clear();
    plotCounter = 0;
  }
}

void drawModeButton(float x, float y, float w, float h, String label) {
  fill(240);
  stroke(0);
  strokeWeight(1);
  rect(x, y, w, h);
  fill(0);
  textStyle(NORMAL);
  textSize(13);
  textAlign(CENTER, CENTER);
  text(label, x + w / 2, y + h / 2);
  textAlign(LEFT);
}
boolean insideButton(float x, float y, float w, float h) {
  return mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
}

void mousePressed() {
  if (mode == MODE_HOME) {
    if (insideButton(fitnessButtonX, homeButtonY, homeButtonW, homeButtonH)) {
      mode = MODE_FITNESS;
    } else if (insideButton(stressButtonX, homeButtonY, homeButtonW, homeButtonH)) {
      mode = MODE_STRESS;
    } else if (insideButton(meditationButtonX, homeButtonY, homeButtonW, homeButtonH)) {
      mode = MODE_MEDITATION;
    } else if (insideButton(sectionButtonX, homeButtonY, homeButtonW, homeButtonH)) {
      mode = MODE_SECTION_IV;
    }
  } else if (mode == MODE_FITNESS) {
    fitnessMousePressed();
  } else if (mode == MODE_STRESS) {
    stressMousePressed();
  } else if (mode == MODE_MEDITATION) {
    meditationMousePressed();
  } else if (mode == MODE_SECTION_IV) {
    sectionIVMousePressed();
  }
}
void keyPressed() {
  if (mode == MODE_FITNESS) fitnessKeyPressed();
}

// ======= SIGNAL PROCESSING (original algorithms) =======

Serial myPort;

// Raw signals from Arduino
int ECG = 0;
int FSR = 0;

// Last valid packet received from Arduino
int lastPacketTime = 0;
final int DATA_TIMEOUT = 1500;

// ECG PROCESSING

// First short moving average: 3 samples
float[] ecgWindow = new float[3];
int ecgWindowIndex = 0;
int ecgWindowCount = 0;
float ecgSum = 0;
float ECG_filtered = 0;

// Baseline removal
// Arduino delay(5) -> approximately 200 Hz
// 200 samples correspond approximately to 1 second
final int baselineWindowSize = 200;
float[] baselineWindow = new float[baselineWindowSize];
int baselineIndex = 0;
int baselineCount = 0;
float baselineSum = 0;

float ECG_baseline = 0;
float ECG_centered = 0;

// Rectified centered ECG

float ECG_amplitude = 0;

// Moving average after rectification.
// 20 samples at approximately 200 Hz -> about 100 ms.
// This creates a simple ECG envelope used only for QRS detection.

final int envelopeWindowSize = 20;
float[] envelopeWindow = new float[envelopeWindowSize];
int envelopeWindowIndex = 0;
int envelopeWindowCount = 0;
float envelopeSum = 0;
float ECG_envelope = 0;

// Adaptive threshold
// 400 samples correspond approximately to 2 seconds
final int thresholdWindowSize = 400;
float[] thresholdWindow = new float[thresholdWindowSize];
int thresholdWindowIndex = 0;
int thresholdWindowCount = 0;

float threshold = 0;
float thresholdFraction = 0.65;

int lastThresholdUpdate = 0;
final int thresholdUpdateInterval = 100;

boolean below_threshold = true;

// Initial ECG calibration
// 0-5 s: stabilization
// 5-15 s: calibration
// after 15 s: adaptive threshold
boolean ecgCalibrated = false;
int ecgCalibrationStart = 0;
float ecgMin = 99999;
float ecgMax = 0;

// HEART RATE

int beat_old = 0;

float[] beats = new float[3];
int beatIndex = 0;
int beatCount = 0;

int BPM = 0;

// Physiological limits used only to reject clearly invalid measurements
final int MIN_VALID_HR = 30;
final int MAX_VALID_HR = 220;

// Minimum interval between two detected beats
// 300 ms corresponds to a maximum detectable HR of 200 bpm
final int REFRACTORY_PERIOD = 300;

// RESPIRATION PROCESSING

// FSR moving average: 50 samples
final int n_window_fsr = 50;
float[] fsrWindow = new float[n_window_fsr];

int fsrWindowIndex = 0;
int fsrWindowCount = 0;
float fsrSum = 0;
float current_mean = 0;

// Compare respiratory trend every 100 ms
int lastBreathingCheck = 0;
final int breathingCheckInterval = 100;

float previous_breath_mean = 0;
float dFSR = 0;

// Minimum FSR variation considered as a real trend
// To be tuned experimentally
float eps = 0.2;

// BREATHING PHASE

boolean breathingInitialized = false;
boolean inspiration_phase = false;
boolean expiration_phase = false;

int count_start_insp = 0;
int count_start_exp = 0;

// BREATHING TIMES

int in_start = 0;
int ex_start = 0;

int Tinsp = 0;
int Tex = 0;
int Tbreath = 0;

float respiratoryRate = 0;

final float MIN_VALID_RR = 4.0;
final float MAX_VALID_RR = 60.0;

// Used by Meditation Mode and Section IV
int breathCount = 0;
int lastBreathTime = 0;

// SENSOR STATUS

boolean leadsOff = false;

// GRAPH DATA

int plotCounter = 0;

ArrayList<Float> ecgPlot = new ArrayList<Float>();
ArrayList<Float> fsrPlot = new ArrayList<Float>();

int maxPlotPoints = 500;

// SETUP

void setupSignalProcessing() {

  // Change this if the FireBeetle uses another COM port
  String portName = "COM3";
  try {
    myPort = new Serial(this, portName, 115200);
    myPort.clear();
    myPort.bufferUntil('\n');
    println("Serial connected: " + portName);
  }
  catch (Exception e) {
    println("Serial connection failed: " + e.getMessage());
    myPort = null;
  }
}

// SERIAL COMMUNICATION

// Keep the original acquisition/processing pipeline. The lock protects
// graph buffers from being changed while the draw thread copies them.
void serialEvent(Serial p) {
  if (p == null) return;
  String incoming = p.readStringUntil('\n');
  if (incoming == null) return;
  incoming = trim(incoming);
  if (incoming.length() == 0) return;

  // Arduino: "ECG,FSR" oppure "!,FSR" quando gli elettrodi sono scollegati.
  String[] values = split(incoming, ',');
  if (values == null || values.length != 2) return;
  int newECG = 0;
  int newFSR;
  boolean ecgConnected = !trim(values[0]).equals("!");
  try {
    newFSR = Integer.parseInt(trim(values[1]));
    if (ecgConnected) newECG = Integer.parseInt(trim(values[0]));
  } catch (NumberFormatException e) {
    return;
  }

  synchronized (graphLock) {
    FSR = newFSR;
    leadsOff = !ecgConnected;
    lastPacketTime = millis();

    // Il FSR viene acquisito anche quando ECG = "!".
    updateFSR();
    if (ecgConnected) {
      ECG = newECG;
      updateECG();
    }

    // FILTRO SOLO GRAFICO: media di 10 campioni raw FSR, zeri inclusi.
    // Non usare current_mean: il rilevatore respiratorio ignora gli zeri.
    float displayFSR = smoothFSRForGraph(newFSR);
    plotCounter++;
    if (plotCounter >= 5) {
      ecgPlot.add(ECG_filtered);  // In assenza di ECG conserva l'ultimo campione grafico
      fsrPlot.add(displayFSR);
      graphTimes.add(float(lastPacketTime));
      plotCounter = 0;
      if (ecgPlot.size() > maxPlotPoints) ecgPlot.remove(0);
      if (fsrPlot.size() > maxPlotPoints) fsrPlot.remove(0);
      if (graphTimes.size() > maxPlotPoints) graphTimes.remove(0);
    }
  }
}

// SENSOR DATA VALIDITY

boolean hasFreshData() {
  return myPort != null && millis() - lastPacketTime < DATA_TIMEOUT;
}

boolean validHeartRate() {
  return hasFreshData() && !leadsOff && BPM >= MIN_VALID_HR && BPM <= MAX_VALID_HR;
}

boolean validRespRate() {
  return hasFreshData() && respiratoryRate >= MIN_VALID_RR && respiratoryRate <= MAX_VALID_RR;
}

// ECG PROCESSING

void updateECG() {

  // 1. SHORT MOVING AVERAGE
  // First simple smoothing against fast noise
  ecgSum -= ecgWindow[ecgWindowIndex];
  ecgWindow[ecgWindowIndex] = ECG;
  ecgSum += ECG;
  ecgWindowIndex = (ecgWindowIndex + 1) % 3;
  if (ecgWindowCount < 3) ecgWindowCount++;
  ECG_filtered = ecgSum / ecgWindowCount;

  // 2. BASELINE ESTIMATION
  // Long moving average estimates the slowly varying baseline
  baselineSum -= baselineWindow[baselineIndex];
  baselineWindow[baselineIndex] = ECG_filtered;
  baselineSum += ECG_filtered;
  baselineIndex = (baselineIndex + 1) % baselineWindowSize;
  if (baselineCount < baselineWindowSize) baselineCount++;
  ECG_baseline = baselineSum / baselineCount;

  // 3. BASELINE REMOVAL
  // The centered ECG is also the signal displayed in the graphs
  ECG_centered = ECG_filtered - ECG_baseline;

  // 4. RECTIFICATION
  // Positive and negative QRS deflections are brought to the same side
  ECG_amplitude = abs(ECG_centered);

  // 5. MOVING-WINDOW INTEGRATION
  // Smooth the rectified ECG over approximately 100 ms.
  // Close deflections belonging to the same QRS tend to form one broader peak.
  envelopeSum -= envelopeWindow[envelopeWindowIndex];
  envelopeWindow[envelopeWindowIndex] = ECG_amplitude;
  envelopeSum += ECG_amplitude;
  envelopeWindowIndex = (envelopeWindowIndex + 1) % envelopeWindowSize;
  if (envelopeWindowCount < envelopeWindowSize) envelopeWindowCount++;
  ECG_envelope = envelopeSum / envelopeWindowCount;

  // 6. STORE RECENT ENVELOPE VALUES FOR ADAPTIVE THRESHOLD
  thresholdWindow[thresholdWindowIndex] = ECG_envelope;
  thresholdWindowIndex = (thresholdWindowIndex + 1) % thresholdWindowSize;
  if (thresholdWindowCount < thresholdWindowSize) thresholdWindowCount++;

  // 7. INITIAL ECG CALIBRATION
  if (ecgCalibrationStart == 0) ecgCalibrationStart = millis();
  int elapsed = millis() - ecgCalibrationStart;
  if (!ecgCalibrated) {

    // First 5 seconds: allow the signal and filters to stabilize
    if (elapsed < 5000) return;

    // From 5 to 15 seconds: collect min/max of the ECG envelope
    if (elapsed < 15000) {
      if (ECG_envelope > ecgMax) ecgMax = ECG_envelope;
      if (ECG_envelope < ecgMin) ecgMin = ECG_envelope;
      return;
    }

    // Initial threshold calculated from envelope amplitude
    threshold = ecgMin + thresholdFraction * (ecgMax - ecgMin);
    ecgCalibrated = true;
    below_threshold = ECG_envelope < threshold;
    lastThresholdUpdate = millis();
    return;
  }

  // 8. ADAPTIVE THRESHOLD Recalculate every 100 ms from the recent ECG envelope
  if (millis() - lastThresholdUpdate >= thresholdUpdateInterval) {
    float recentMin = 99999;
    float recentMax = 0;
    for (int i = 0; i < thresholdWindowCount; i++) {                          // Read the window collecting ECG samples
                                                                              // to determine the new threshold
      if (thresholdWindow[i] < recentMin) recentMin = thresholdWindow[i];
      if (thresholdWindow[i] > recentMax) recentMax = thresholdWindow[i];
    }

    if (thresholdWindowCount > 0) {
      threshold = recentMin + thresholdFraction * (recentMax - recentMin);
    }

    lastThresholdUpdate = millis();
  }

// 9. QRS DETECTION
// Detect only the actual upward threshold crossing
if (ECG_envelope > threshold && below_threshold) {

  // The threshold crossing has occurred.
  // Set this immediately, even if the event is inside the refractory period.
  below_threshold = false;
  if (beat_old == 0 || millis() - beat_old >= REFRACTORY_PERIOD) {
    calculateBPM();
  }
}

else if (ECG_envelope < threshold) {
  below_threshold = true;
  }  

}

// HEART RATE

void calculateBPM() {
  int beat_new = millis();

  // First detected beat only establishes the reference time
  if (beat_old != 0) {
    int diff = beat_new - beat_old;

    // 300 ms -> 200 bpm
    // 2000 ms -> 30 bpm
    if (diff >= REFRACTORY_PERIOD && diff <= 2000) {
      float currentBPM = 60000.0 / diff;

      // If invalid, keep the previous valid BPM
      if (currentBPM >= MIN_VALID_HR && currentBPM <= MAX_VALID_HR) {
        beats[beatIndex] = currentBPM;         // create and array with the recent bpm computed
        beatIndex = (beatIndex + 1) % 3;       // circular buffer
        if (beatCount < 3) beatCount++;
        float total = 0;
        for (int i = 0; i < beatCount; i++) {    // mean of the bpm in the array window
          total += beats[i];
        }

        BPM = int(total / beatCount);
      }
    }
  }

  beat_old = beat_new;
}

// FSR PROCESSING

void updateFSR() {

  // Ignore zero if FSR is disconnected
  if (FSR == 0) return;

  // 1. MOVING AVERAGE
  // Respiratory signal changes more slowly than ECG,
  // so a larger window can be used for smoothing.
  fsrSum -= fsrWindow[fsrWindowIndex];
  fsrWindow[fsrWindowIndex] = FSR;
  fsrSum += FSR;
  fsrWindowIndex = (fsrWindowIndex + 1) % n_window_fsr;
  if (fsrWindowCount < n_window_fsr) fsrWindowCount++;
  current_mean = fsrSum / fsrWindowCount;

  // 2. RESPIRATORY TREND
  // Evaluate only when the moving-average window is full
  // Evaluate only when a certain time is passed
  if (fsrWindowCount == n_window_fsr && millis() - lastBreathingCheck >= breathingCheckInterval) {
    if (previous_breath_mean == 0) {
      previous_breath_mean = current_mean;
    }

    else {
      dFSR = current_mean - previous_breath_mean;
      previous_breath_mean = current_mean;
      calculateBreathingRate();
    }

    lastBreathingCheck = millis();
  }
}

// BREATHING RATE

void calculateBreathingRate() {

  // Current assumption:
  // increasing FSR -> inspiration
  // decreasing FSR -> expiration
  // If the real signal has opposite polarity, swap the two conditions.

  // INITIAL PHASE IDENTIFICATION
  if (!breathingInitialized) {
    if (dFSR > eps) {
      inspiration_phase = true;
      expiration_phase = false;
      in_start = millis();
      breathingInitialized = true;
    }

    else if (dFSR < -eps) {
      expiration_phase = true;
      inspiration_phase = false;
      ex_start = millis();
      breathingInitialized = true;
    }

    return;
  }

  // EXPIRATION -> INSPIRATION
  if (expiration_phase) {
    if (dFSR > eps) {
      count_start_insp++;

      // Three confirmations correspond to approximately 300 ms
      if (count_start_insp >= 3) {
        int new_in_start = millis();
        if (ex_start != 0) Tex = new_in_start - ex_start;
        if (in_start != 0) {
          int newTbreath = new_in_start - in_start;
          float newRR = 60000.0 / newTbreath;

          // Invalid RR does not overwrite the previous valid value
          if (newRR >= MIN_VALID_RR && newRR <= MAX_VALID_RR) {
            Tbreath = newTbreath;
            respiratoryRate = newRR;

            // One complete valid respiratory cycle has finished
            breathCount++;
            lastBreathTime = new_in_start;
          }
        }

        in_start = new_in_start;
        inspiration_phase = true;
        expiration_phase = false;
        count_start_insp = 0;
        count_start_exp = 0;
      }
    }

    else if (dFSR < -eps) {
      count_start_insp = 0;
    }
  }

  // INSPIRATION -> EXPIRATION
  else if (inspiration_phase) {
    if (dFSR < -eps) {
      count_start_exp++;
      if (count_start_exp >= 3) {
        ex_start = millis();
        if (in_start != 0) Tinsp = ex_start - in_start;
        inspiration_phase = false;
        expiration_phase = true;
        count_start_exp = 0;
        count_start_insp = 0;
      }
    }

    else if (dFSR > eps) {
      count_start_exp = 0;
    }
  }
}

// ======= FITNESS MODE (original algorithms) =======
// FitnessMode.pde

final int FITNESS_AGE = 0;
final int FITNESS_BASELINE = 1;
final int FITNESS_READY = 2;
final int FITNESS_ACTIVE = 3;
final int FITNESS_SUMMARY = 4;
final int FITNESS_BASELINE_FAILED = 5;

final int FITNESS_BASELINE_TIME = 30000;

int fitnessState = FITNESS_AGE;

String fitnessAgeInput = "";
int fitnessAge = 0;

int fitnessBaselineStart = 0;
int fitnessLastBaselineSample = 0;

float fitnessHRSum = 0;
float fitnessRRSum = 0;
int fitnessHRCount = 0;
int fitnessRRCount = 0;

float fitnessRestingHR = 0;
float fitnessRestingRR = 0;

int fitnessActivityStart = 0;
int fitnessActivityStop = 0;
int fitnessLastZoneUpdate = 0;
int fitnessLastHRGraphSample = 0;

float[] fitnessZoneTime = new float[5];
float fitnessBelowZoneTime = 0;

ArrayList<Float> fitnessHRHistory = new ArrayList<Float>();
ArrayList<Float> fitnessHRTime = new ArrayList<Float>();

String[] fitnessZoneNames = {
  "VERY LIGHT",
  "LIGHT",
  "MODERATE",
  "HARD",
  "MAXIMUM"
};

// MAIN FITNESS SCREEN

void drawFitness() {
  if (fitnessState == FITNESS_AGE) drawFitnessAge();
  else if (fitnessState == FITNESS_BASELINE) {
    updateFitnessBaseline();
    drawFitnessBaseline();
  }

  else if (fitnessState == FITNESS_READY) drawFitnessReady();
  else if (fitnessState == FITNESS_ACTIVE) {
    updateFitnessActivity();
    drawFitnessActive();
  }

  else if (fitnessState == FITNESS_SUMMARY) drawFitnessSummary();
  else if (fitnessState == FITNESS_BASELINE_FAILED) drawFitnessBaselineFailed();
}

// AGE INPUT

void drawFitnessAge() {
  fill(0);
  textStyle(BOLD);
  textSize(25);
  text("FITNESS MODE", 30, 100);
  textStyle(NORMAL);
  textSize(18);
  text("Enter your age:", 30, 160);
  fill(255);
  stroke(0);
  rect(30, 190, 220, 50);
  textSize(22);
  if (fitnessAgeInput.length() == 0) {
    fill(140);
    text("Type age...", 45, 223);
  }
  else {
    fill(0);
    text(fitnessAgeInput, 45, 223);
  }

  drawModeButton(30, 280, 220, 50, "START BASELINE");
  drawModeButton(270, 280, 180, 50, "BACK HOME");
  fill(80);
  textSize(14);
  text("Maximum heart rate = 220 - age", 30, 365);
}

// START BASELINE

void startFitnessBaseline() {
  if (fitnessAgeInput.length() == 0) return;
  fitnessAge = int(fitnessAgeInput);
  if (fitnessAge <= 0) return;
  fitnessState = FITNESS_BASELINE;
  fitnessBaselineStart = millis();
  fitnessLastBaselineSample = 0;
  fitnessHRSum = 0;
  fitnessRRSum = 0;
  fitnessHRCount = 0;
  fitnessRRCount = 0;
}

// BASELINE ACQUISITION

void updateFitnessBaseline() {
  int now = millis();

  // Take one representative HR/RR value every second
  if (fitnessLastBaselineSample == 0 || now - fitnessLastBaselineSample >= 1000) {
    fitnessLastBaselineSample = now;
    int hr = getHeartRate();
    float rr = getRespRate();

    // Invalid and old values return 0 and are not accumulated
    if (hr > 0) {
      fitnessHRSum += hr;
      fitnessHRCount++;
    }

    if (rr > 0) {
      fitnessRRSum += rr;
      fitnessRRCount++;
    }
  }

  if (now - fitnessBaselineStart >= FITNESS_BASELINE_TIME) {
    if (fitnessHRCount == 0 || fitnessRRCount == 0) {
      fitnessState = FITNESS_BASELINE_FAILED;
      return;
    }

    fitnessRestingHR = fitnessHRSum / fitnessHRCount;
    fitnessRestingRR = fitnessRRSum / fitnessRRCount;
    fitnessState = FITNESS_READY;
  }
}

// BASELINE SCREEN

void drawFitnessBaseline() {
  fill(0);
  textStyle(BOLD);
  textSize(25);
  text("FITNESS MODE - RESTING BASELINE", 30, 95);
  textStyle(NORMAL);
  drawFitnessLiveParameters(145, false);
  int remaining = max(0, 30 - (millis() - fitnessBaselineStart) / 1000);
  textStyle(BOLD);
  textSize(32);
  text("Baseline: " + remaining + " s remaining", 30, 255);
  textStyle(NORMAL);
  fill(80);
  textSize(14);
  text("Sit quietly while resting HR and respiratory rate are measured.", 30, 300);
}

// BASELINE FAILED

void drawFitnessBaselineFailed() {
  fill(0);
  textStyle(BOLD);
  textSize(25);
  text("FITNESS MODE", 30, 100);
  textStyle(NORMAL);
  fill(180, 0, 0);
  textSize(18);
  text("Not enough valid HR/RR data were collected.", 30, 165);
  fill(0);
  text("Check the sensors and repeat the baseline.", 30, 205);
  drawModeButton(30, 260, 220, 50, "REPEAT BASELINE");
  drawModeButton(270, 260, 180, 50, "BACK HOME");
}

// BASELINE COMPLETE

void drawFitnessReady() {
  fill(0);
  textStyle(BOLD);
  textSize(25);
  text("FITNESS MODE - BASELINE COMPLETE", 30, 95);
  textStyle(NORMAL);
  textSize(18);
  text("Age: " + fitnessAge, 30, 150);
  text("Estimated maximum HR: " + (220 - fitnessAge) + " BPM", 30, 185);
  text("Resting HR: " + oneDecimal(fitnessRestingHR) + " BPM", 30, 235);
  text("Resting RR: " + oneDecimal(fitnessRestingRR) + " breaths/min", 30, 270);
  drawModeButton(30, 330, 220, 55, "START ACTIVITY");
  drawModeButton(270, 330, 220, 55, "REPEAT BASELINE");
  drawModeButton(510, 330, 180, 55, "BACK HOME");
}

// START ACTIVITY

void startFitnessActivity() {
  fitnessState = FITNESS_ACTIVE;
  fitnessActivityStart = millis();
  fitnessActivityStop = 0;
  fitnessLastZoneUpdate = millis();
  fitnessLastHRGraphSample = 0;
  fitnessBelowZoneTime = 0;
  for (int i = 0; i < 5; i++) {
    fitnessZoneTime[i] = 0;
  }

  fitnessHRHistory.clear();
  fitnessHRTime.clear();
  clearGraphHistory();
}

// FITNESS ACTIVITY PROCESSING

void updateFitnessActivity() {
  int now = millis();
  int hr = getHeartRate();

  // TIME SPENT IN EACH ZONE
  int elapsed = now - fitnessLastZoneUpdate;
  fitnessLastZoneUpdate = now;
  if (hr > 0) {
    int zone = getFitnessZone(hr);
    if (zone >= 0) fitnessZoneTime[zone] += elapsed / 1000.0;
    else fitnessBelowZoneTime += elapsed / 1000.0;
  }

  // HR GRAPH
  // Store one valid HR point every second
  if (fitnessLastHRGraphSample == 0 || now - fitnessLastHRGraphSample >= 1000) {
    fitnessLastHRGraphSample = now;
    if (hr > 0) {
      float time = (now - fitnessActivityStart) / 1000.0;
      fitnessHRHistory.add(float(hr));
      fitnessHRTime.add(time);
    }
  }
}

// CARDIO ZONE

int getFitnessZone(float hr) {
  if (hr <= 0) return -1;
  float hrMax = 220.0 - fitnessAge;
  if (hrMax <= 0) return -1;
  float percent = 100.0 * hr / hrMax;
  if (percent < 50) return -1;
  if (percent < 60) return 0;
  if (percent < 70) return 1;
  if (percent < 80) return 2;
  if (percent < 90) return 3;
  return 4;
}

String getFitnessZoneLabel() {
  int hr = getHeartRate();
  if (hr <= 0) return "--";
  float hrMax = 220.0 - fitnessAge;
  if (hrMax <= 0) return "--";
  float percent = 100.0 * hr / hrMax;
  if (percent < 50) return "BELOW 50%";
  int zone = getFitnessZone(hr);
  if (zone >= 0) return fitnessZoneNames[zone];
  return "--";
}

int fitnessZoneColor(float hr) {
  int zone = getFitnessZone(hr);
  if (zone == 0) return color(110);
  if (zone == 1) return color(50, 130, 210);
  if (zone == 2) return color(35, 150, 75);
  if (zone == 3) return color(230, 135, 20);
  if (zone == 4) return color(205, 40, 45);
  return color(80);
}

// LIVE FITNESS SCREEN

void drawFitnessActive() {
  fill(0);
  textStyle(BOLD);
  textSize(24);
  text("FITNESS MODE - LIVE ACTIVITY", 30, 78);
  textStyle(NORMAL);
  drawFitnessLiveParameters(110, true);

  // ECG and respiration
  drawECGGraph(ecgPlot, 30, 165, 500, 190);
  drawRespGraph(fsrPlot, 570, 165, 500, 190);

  // HR vs time with cardio zones
  drawFitnessHRGraph(30, 390, 1040, 205);
  int elapsed = (millis() - fitnessActivityStart) / 1000;
  fill(0);
  textSize(13);
  text("Activity time: " + elapsed + " s", 30, 625);
  drawModeButton(820, 635, 250, 50, "STOP FITNESS SESSION");
}

// LIVE PARAMETERS

void drawFitnessLiveParameters(float y, boolean showZone) {
  int hr = getHeartRate();
  float rr = getRespRate();
  float tin = getInhaleTime();
  float tex = getExhaleTime();
  fill(0);
  textSize(15);
  text("HR", 30, y);
  text("RR", 200, y);
  text("Inspiration", 390, y);
  text("Expiration", 580, y);
  if (showZone) text("Cardio Zone", 800, y);
  textStyle(BOLD);
  textSize(19);
  text(hr > 0 ? hr + " BPM" : "--", 30, y + 27);
  text(rr > 0 ? oneDecimal(rr) + " /min" : "--", 200, y + 27);
  text(tin > 0 ? twoDecimals(tin) + " s" : "--", 390, y + 27);
  text(tex > 0 ? twoDecimals(tex) + " s" : "--", 580, y + 27);
  if (showZone) text(getFitnessZoneLabel(), 800, y + 27);
  textStyle(NORMAL);
}

// HR VS TIME GRAPH WITH CARDIO ZONES

void drawFitnessHRGraph(float x, float y, float w, float h) {
  fill(255);
  stroke(0);
  rect(x, y, w, h);
  fill(0);
  textSize(13);
  text("HEART RATE / CARDIO ZONES", x + 10, y + 18);
  float hrMax = 220.0 - fitnessAge;
  if (hrMax <= 0) return;
  float plotLeft = x + 45;
  float plotRight = x + w - 15;
  float plotTop = y + 30;
  float plotBottom = y + h - 25;

  // Fixed vertical scale for the session
  float graphMinHR = 30;
  float graphMaxHR = max(100, 1.05 * hrMax);
  float hr50 = 0.50 * hrMax;
  float hr60 = 0.60 * hrMax;
  float hr70 = 0.70 * hrMax;
  float hr80 = 0.80 * hrMax;
  float hr90 = 0.90 * hrMax;

  // COLORED BACKGROUND ZONES
  noStroke();

  // Below 50%
  drawFitnessZoneBackground(plotLeft, plotRight, plotTop, plotBottom,
                            graphMinHR, graphMaxHR,
                            graphMinHR, hr50,
                            color(248));

  // 50-60% gray
  drawFitnessZoneBackground(plotLeft, plotRight, plotTop, plotBottom,
                            graphMinHR, graphMaxHR,
                            hr50, hr60,
                            color(225));

  // 60-70% blue
  drawFitnessZoneBackground(plotLeft, plotRight, plotTop, plotBottom,
                            graphMinHR, graphMaxHR,
                            hr60, hr70,
                            color(220, 235, 250));

  // 70-80% green
  drawFitnessZoneBackground(plotLeft, plotRight, plotTop, plotBottom,
                            graphMinHR, graphMaxHR,
                            hr70, hr80,
                            color(220, 245, 225));

  // 80-90% orange
  drawFitnessZoneBackground(plotLeft, plotRight, plotTop, plotBottom,
                            graphMinHR, graphMaxHR,
                            hr80, hr90,
                            color(255, 235, 205));

  // >90% red
  drawFitnessZoneBackground(plotLeft, plotRight, plotTop, plotBottom,
                            graphMinHR, graphMaxHR,
                            hr90, graphMaxHR,
                            color(255, 220, 220));

  // ZONE THRESHOLD LINES + BPM LABELS
  float[] limits = {hr50, hr60, hr70, hr80, hr90};
  String[] labels = {"50%", "60%", "70%", "80%", "90%"};
  stroke(180);
  fill(70);
  textSize(10);
  for (int i = 0; i < limits.length; i++) {
    float lineY = map(limits[i], graphMinHR, graphMaxHR, plotBottom, plotTop);
    line(plotLeft, lineY, plotRight, lineY);
    text(
      labels[i] + "  " + int(limits[i]) + " BPM",
      plotLeft + 4,
      lineY - 3
    );
  }

  // AXES
  stroke(0);
  line(plotLeft, plotTop, plotLeft, plotBottom);
  line(plotLeft, plotBottom, plotRight, plotBottom);
  fill(0);
  textSize(10);
  text(int(graphMaxHR), x + 5, plotTop + 5);
  text(int(graphMinHR), x + 10, plotBottom);
  float currentTime = max(10, (millis() - fitnessActivityStart) / 1000.0);
  text("0 s", plotLeft, plotBottom + 17);
  text(int(currentTime) + " s", plotRight - 25, plotBottom + 17);

  // HR TRACE
  if (fitnessHRHistory.size() < 2) return;
  for (int i = 1; i < fitnessHRHistory.size(); i++) {
    float time1 = fitnessHRTime.get(i - 1);
    float time2 = fitnessHRTime.get(i);

    // If data were missing for more than 2.5 s, leave a visible gap
    if (time2 - time1 > 2.5) continue;
    float hr1 = fitnessHRHistory.get(i - 1);
    float hr2 = fitnessHRHistory.get(i);
    float x1 = map(time1, 0, currentTime, plotLeft, plotRight);
    float x2 = map(time2, 0, currentTime, plotLeft, plotRight);
    float y1 = map(constrain(hr1, graphMinHR, graphMaxHR),
                   graphMinHR, graphMaxHR, plotBottom, plotTop);
    float y2 = map(constrain(hr2, graphMinHR, graphMaxHR),
                   graphMinHR, graphMaxHR, plotBottom, plotTop);

    // Segment color depends on the cardio zone of the current HR
    stroke(fitnessZoneColor(hr2));
    strokeWeight(2.5);
    line(x1, y1, x2, y2);
  }

  strokeWeight(1);
  stroke(0);
}

// DRAW ONE COLORED CARDIO-ZONE BACKGROUND

void drawFitnessZoneBackground(float left, float right,
                               float top, float bottom,
                               float graphMin, float graphMax,
                               float zoneMin, float zoneMax,
                               int zoneColor) {
  float clippedMin = constrain(zoneMin, graphMin, graphMax);
  float clippedMax = constrain(zoneMax, graphMin, graphMax);
  if (clippedMax <= clippedMin) return;
  float yTop = map(clippedMax, graphMin, graphMax, bottom, top);
  float yBottom = map(clippedMin, graphMin, graphMax, bottom, top);
  fill(zoneColor);
  rect(left, yTop, right - left, yBottom - yTop);
}

// STOP ACTIVITY

void stopFitnessActivity() {
  fitnessActivityStop = millis();
  fitnessState = FITNESS_SUMMARY;
}

// SUMMARY

void drawFitnessSummary() {
  fill(0);
  textStyle(BOLD);
  textSize(25);
  text("FITNESS SESSION COMPLETE", 30, 85);
  textStyle(NORMAL);
  textSize(16);
  text("Resting HR: " + oneDecimal(fitnessRestingHR) + " BPM", 30, 130);
  text("Resting RR: " + oneDecimal(fitnessRestingRR) + " breaths/min", 300, 130);
  float totalTime = (fitnessActivityStop - fitnessActivityStart) / 1000.0;
  textStyle(BOLD);
  textSize(19);
  text("Time spent in each cardio zone", 30, 190);
  textStyle(NORMAL);
  drawFitnessSummaryRow("BELOW 50%", fitnessBelowZoneTime, color(235), 240);
  drawFitnessSummaryRow("VERY LIGHT  50-60%", fitnessZoneTime[0], color(170), 290);
  drawFitnessSummaryRow("LIGHT  60-70%", fitnessZoneTime[1], color(70, 150, 220), 340);
  drawFitnessSummaryRow("MODERATE  70-80%", fitnessZoneTime[2], color(50, 165, 90), 390);
  drawFitnessSummaryRow("HARD  80-90%", fitnessZoneTime[3], color(240, 155, 30), 440);
  drawFitnessSummaryRow("MAXIMUM  >90%", fitnessZoneTime[4], color(215, 45, 55), 490);
  textStyle(BOLD);
  textSize(18);
  fill(0);
  text("Total activity time: " + oneDecimal(totalTime) + " s", 30, 555);
  textStyle(NORMAL);
  drawModeButton(30, 610, 220, 50, "END ACTIVITY");
}

void drawFitnessSummaryRow(String label, float time, int zoneColor, float y) {
  fill(zoneColor);
  stroke(0);
  rect(30, y - 20, 25, 25);
  fill(0);
  textSize(16);
  text(label, 75, y);
  text(oneDecimal(time) + " s", 330, y);
}

// RESET FITNESS

void resetFitness() {
  fitnessState = FITNESS_AGE;
  fitnessAgeInput = "";
  fitnessAge = 0;
  fitnessBaselineStart = 0;
  fitnessLastBaselineSample = 0;
  fitnessHRSum = 0;
  fitnessRRSum = 0;
  fitnessHRCount = 0;
  fitnessRRCount = 0;
  fitnessRestingHR = 0;
  fitnessRestingRR = 0;
  fitnessActivityStart = 0;
  fitnessActivityStop = 0;
  fitnessLastZoneUpdate = 0;
  fitnessLastHRGraphSample = 0;
  fitnessBelowZoneTime = 0;
  for (int i = 0; i < 5; i++) {
    fitnessZoneTime[i] = 0;
  }

  fitnessHRHistory.clear();
  fitnessHRTime.clear();
}

// MOUSE INPUT

void fitnessMousePressed() {
  if (fitnessState == FITNESS_AGE) {
    if (insideButton(30, 280, 220, 50)) {
      startFitnessBaseline();
      return;
    }

    if (insideButton(270, 280, 180, 50)) {
      resetFitness();
      mode = MODE_HOME;
      return;
    }
  }

  else if (fitnessState == FITNESS_BASELINE_FAILED) {
    if (insideButton(30, 260, 220, 50)) {
      startFitnessBaseline();
      return;
    }

    if (insideButton(270, 260, 180, 50)) {
      resetFitness();
      mode = MODE_HOME;
      return;
    }
  }

  else if (fitnessState == FITNESS_READY) {
    if (insideButton(30, 330, 220, 55)) {
      startFitnessActivity();
      return;
    }

    if (insideButton(270, 330, 220, 55)) {
      startFitnessBaseline();
      return;
    }

    if (insideButton(510, 330, 180, 55)) {
      resetFitness();
      mode = MODE_HOME;
      return;
    }
  }

  else if (fitnessState == FITNESS_ACTIVE) {
    if (insideButton(820, 635, 250, 50)) {
      stopFitnessActivity();
      return;
    }
  }

  else if (fitnessState == FITNESS_SUMMARY) {
    if (insideButton(30, 610, 220, 50)) {
      resetFitness();
      mode = MODE_HOME;
      return;
    }
  }
}

// KEYBOARD INPUT

void fitnessKeyPressed() {
  if (fitnessState != FITNESS_AGE) return;
  if (key >= '0' && key <= '9') {
    fitnessAgeInput += key;
  }

  else if (key == BACKSPACE) {
    if (fitnessAgeInput.length() > 0) {
      fitnessAgeInput = fitnessAgeInput.substring(0, fitnessAgeInput.length() - 1);
    }
  }

  else if (key == ENTER || key == RETURN) {
    startFitnessBaseline();
  }
}

// ======= STRESS MODE (original algorithms) =======
// StressMode.pde

final int STRESS_REST_READY = 0;
final int STRESS_REST_ACTIVE = 1;
final int STRESS_STRESS_READY = 2;
final int STRESS_STRESS_ACTIVE = 3;
final int STRESS_CALM_READY = 4;
final int STRESS_CALM_ACTIVE = 5;
final int STRESS_SUMMARY = 6;
final int STRESS_LIVE = 7;

final int STRESS_CALIBRATION_TIME = 30000;

int stressState = STRESS_REST_READY;
int stressPhaseStart = 0;
int stressLastSample = 0;

float stressHRSum = 0;
float stressRRSum = 0;
int stressHRCount = 0;
int stressRRCount = 0;

float stressRestHR = 0;
float stressRestRR = 0;

float stressStressHR = 0;
float stressStressRR = 0;

float stressCalmHR = 0;
float stressCalmRR = 0;

String stressLiveState = "WAITING";
String stressMessage = "";

// MAIN STRESS SCREEN

void drawStress() {
  if (stressState == STRESS_REST_READY) drawStressReadyScreen("RESTING BASELINE", "Sit quietly and relax.", "START BASELINE");
  else if (stressState == STRESS_REST_ACTIVE) {
    updateStressCalibration();
    drawStressAcquisition("RESTING BASELINE");
  }

  else if (stressState == STRESS_STRESS_READY) drawStressReadyScreen("STRESS CALIBRATION", "Perform the stressful task.", "START STRESS CALIBRATION");
  else if (stressState == STRESS_STRESS_ACTIVE) {
    updateStressCalibration();
    drawStressAcquisition("STRESS CALIBRATION");
  }

  else if (stressState == STRESS_CALM_READY) drawStressReadyScreen("CALM CALIBRATION", "Stop the task and relax.", "START CALM CALIBRATION");
  else if (stressState == STRESS_CALM_ACTIVE) {
    updateStressCalibration();
    drawStressAcquisition("CALM CALIBRATION");
  }

  else if (stressState == STRESS_SUMMARY) drawStressSummary();
  else if (stressState == STRESS_LIVE) {
    updateStressLiveState();
    drawStressLive();
  }
}

// READY SCREEN BEFORE EACH 30 s ACQUISITION

void drawStressReadyScreen(String title, String instruction, String buttonLabel) {
  fill(0);
  textStyle(BOLD);
  textSize(25);
  text("STRESS MODE - " + title, 30, 100);
  textStyle(NORMAL);
  textSize(17);
  text(instruction, 30, 155);
  if (stressState != STRESS_REST_READY) {
    text("Resting HR: " + oneDecimal(stressRestHR) + " BPM", 30, 210);
    text("Resting RR: " + oneDecimal(stressRestRR) + " breaths/min", 30, 245);
  }

  if (stressMessage.length() > 0) {
    fill(180, 0, 0);
    text(stressMessage, 30, 300);
    fill(0);
  }

  drawModeButton(30, 340, 300, 55, buttonLabel);
  drawModeButton(350, 340, 180, 55, "BACK HOME");
}

// START CURRENT CALIBRATION

void startStressCalibration() {
  stressPhaseStart = millis();
  stressLastSample = 0;
  stressHRSum = 0;
  stressRRSum = 0;
  stressHRCount = 0;
  stressRRCount = 0;
  stressMessage = "";
  if (stressState == STRESS_REST_READY) stressState = STRESS_REST_ACTIVE;
  else if (stressState == STRESS_STRESS_READY) stressState = STRESS_STRESS_ACTIVE;
  else if (stressState == STRESS_CALM_READY) stressState = STRESS_CALM_ACTIVE;
}

// ACQUIRE ONE HR/RR VALUE PER SECOND

void updateStressCalibration() {
  int now = millis();
  if (stressLastSample == 0 || now - stressLastSample >= 1000) {
    stressLastSample = now;
    int hr = getHeartRate();
    float rr = getRespRate();
    if (hr > 0) {
      stressHRSum += hr;
      stressHRCount++;
    }

    if (rr > 0) {
      stressRRSum += rr;
      stressRRCount++;
    }
  }

  if (now - stressPhaseStart >= STRESS_CALIBRATION_TIME) finishStressCalibration();
}

// FINISH CURRENT 30 s PHASE

void finishStressCalibration() {
  if (stressHRCount == 0 || stressRRCount == 0) {
    stressMessage = "Not enough valid HR/RR data. Repeat this acquisition.";
    if (stressState == STRESS_REST_ACTIVE) stressState = STRESS_REST_READY;
    else if (stressState == STRESS_STRESS_ACTIVE) stressState = STRESS_STRESS_READY;
    else if (stressState == STRESS_CALM_ACTIVE) stressState = STRESS_CALM_READY;
    return;
  }

  float averageHR = stressHRSum / stressHRCount;
  float averageRR = stressRRSum / stressRRCount;
  if (stressState == STRESS_REST_ACTIVE) {
    stressRestHR = averageHR;
    stressRestRR = averageRR;
    stressState = STRESS_STRESS_READY;
  }

  else if (stressState == STRESS_STRESS_ACTIVE) {
    stressStressHR = averageHR;
    stressStressRR = averageRR;
    stressState = STRESS_CALM_READY;
  }

  else if (stressState == STRESS_CALM_ACTIVE) {
    stressCalmHR = averageHR;
    stressCalmRR = averageRR;
    stressState = STRESS_SUMMARY;
  }
}

// CALIBRATION SCREEN

void drawStressAcquisition(String title) {
  fill(0);
  textStyle(BOLD);
  textSize(25);
  text("STRESS MODE - " + title, 30, 95);
  textStyle(NORMAL);
  int hr = getHeartRate();
  float rr = getRespRate();
  textSize(16);
  text("Current HR", 30, 155);
  text("Current RR", 250, 155);
  textStyle(BOLD);
  textSize(22);
  text(hr > 0 ? hr + " BPM" : "--", 30, 185);
  text(rr > 0 ? oneDecimal(rr) + " breaths/min" : "--", 250, 185);
  textStyle(NORMAL);
  if (stressState != STRESS_REST_ACTIVE) {
    textSize(15);
    text("Resting HR: " + oneDecimal(stressRestHR) + " BPM", 550, 160);
    text("Resting RR: " + oneDecimal(stressRestRR) + " breaths/min", 550, 190);
  }

  int remaining = max(0, 30 - (millis() - stressPhaseStart) / 1000);
  textStyle(BOLD);
  textSize(30);
  text(remaining + " s remaining", 30, 270);
  textStyle(NORMAL);
  textSize(14);
  text("Valid HR samples: " + stressHRCount, 30, 315);
  text("Valid RR samples: " + stressRRCount, 250, 315);
}

// SUMMARY AFTER ALL THREE CALIBRATIONS

void drawStressSummary() {
  fill(0);
  textStyle(BOLD);
  textSize(25);
  text("STRESS CALIBRATION COMPLETE", 30, 95);
  textStyle(NORMAL);
  textSize(17);
  text("Condition", 30, 155);
  text("Heart Rate", 260, 155);
  text("Respiratory Rate", 500, 155);
  text("Resting", 30, 205);
  text(oneDecimal(stressRestHR) + " BPM", 260, 205);
  text(oneDecimal(stressRestRR) + " breaths/min", 500, 205);
  text("Stressed", 30, 250);
  text(oneDecimal(stressStressHR) + " BPM", 260, 250);
  text(oneDecimal(stressStressRR) + " breaths/min", 500, 250);
  text("Calm", 30, 295);
  text(oneDecimal(stressCalmHR) + " BPM", 260, 295);
  text(oneDecimal(stressCalmRR) + " breaths/min", 500, 295);
  drawModeButton(30, 370, 260, 55, "START LIVE DETECTION");
  drawModeButton(310, 370, 230, 55, "REPEAT CALIBRATION");
  drawModeButton(560, 370, 180, 55, "BACK HOME");
}

// LIVE CLASSIFICATION

void updateStressLiveState() {
  int hr = getHeartRate();
  float rr = getRespRate();
  boolean validHR = hr > 0;
  boolean validRR = rr > 0;
  if (!validHR && !validRR) {
    stressLiveState = "NO VALID DATA";
    return;
  }

  // Pre-AI simple rule:
  // either HR OR RR above stressed calibration -> STRESSED
  if ((validHR && hr >= stressStressHR) ||
      (validRR && rr >= stressStressRR)) {
    stressLiveState = "STRESSED";
  }

  // either HR OR RR below calm calibration -> CALM
  else if ((validHR && hr <= stressCalmHR) ||
           (validRR && rr <= stressCalmRR)) {
    stressLiveState = "CALM";
  }

  else {
    stressLiveState = "NEUTRAL";
  }
}

// LIVE MONITORING SCREEN

void drawStressLive() {
  fill(0);
  textStyle(BOLD);
  textSize(24);
  text("STRESS MODE - LIVE DETECTION", 30, 85);
  textStyle(NORMAL);
  int hr = getHeartRate();
  float rr = getRespRate();
  float tin = getInhaleTime();
  float tex = getExhaleTime();
  textSize(15);
  text("HR", 30, 125);
  text("RR", 180, 125);
  text("Inspiration", 350, 125);
  text("Expiration", 520, 125);
  textStyle(BOLD);
  textSize(19);
  text(hr > 0 ? hr + " BPM" : "--", 30, 152);
  text(rr > 0 ? oneDecimal(rr) + " /min" : "--", 180, 152);
  text(tin > 0 ? twoDecimals(tin) + " s" : "--", 350, 152);
  text(tex > 0 ? twoDecimals(tex) + " s" : "--", 520, 152);
  textStyle(NORMAL);

  // State on the right
  textSize(15);
  fill(0);
  text("STATE", 790, 120);
  if (stressLiveState.equals("STRESSED")) fill(200, 30, 30);
  else if (stressLiveState.equals("CALM")) fill(20, 140, 60);
  else fill(100);
  textStyle(BOLD);
  textSize(25);
  text(stressLiveState, 790, 153);
  textStyle(NORMAL);

  // Compact calibration values
  fill(0);
  textSize(12);
  text("HR Calm: " + oneDecimal(stressCalmHR), 790, 178);
  text("HR Stress: " + oneDecimal(stressStressHR), 790, 196);
  text("RR Calm: " + oneDecimal(stressCalmRR), 920, 178);
  text("RR Stress: " + oneDecimal(stressStressRR), 920, 196);

  // Live signals
  drawECGGraph(ecgPlot, 30, 225, 500, 290);
  drawRespGraph(fsrPlot, 570, 225, 500, 290);
  drawModeButton(30, 590, 230, 50, "REPEAT CALIBRATION");
  drawModeButton(280, 590, 200, 50, "END ACTIVITY");
}

// RESET EVERYTHING

void resetStress() {
  stressState = STRESS_REST_READY;
  stressPhaseStart = 0;
  stressLastSample = 0;
  stressHRSum = 0;
  stressRRSum = 0;
  stressHRCount = 0;
  stressRRCount = 0;
  stressRestHR = 0;
  stressRestRR = 0;
  stressStressHR = 0;
  stressStressRR = 0;
  stressCalmHR = 0;
  stressCalmRR = 0;
  stressLiveState = "WAITING";
  stressMessage = "";
}

// MOUSE INPUT

void stressMousePressed() {
  if (stressState == STRESS_REST_READY ||
      stressState == STRESS_STRESS_READY ||
      stressState == STRESS_CALM_READY) {
    if (insideButton(30, 340, 300, 55)) {
      startStressCalibration();
      return;
    }

    if (insideButton(350, 340, 180, 55)) {
      resetStress();
      mode = MODE_HOME;
      return;
    }
  }

  else if (stressState == STRESS_SUMMARY) {
    if (insideButton(30, 370, 260, 55)) {
      stressState = STRESS_LIVE;
      stressLiveState = "WAITING";
      return;
    }

    if (insideButton(310, 370, 230, 55)) {
      resetStress();
      return;
    }

    if (insideButton(560, 370, 180, 55)) {
      resetStress();
      mode = MODE_HOME;
      return;
    }
  }

  else if (stressState == STRESS_LIVE) {
    if (insideButton(30, 590, 230, 50)) {
      resetStress();
      return;
    }

    if (insideButton(280, 590, 200, 50)) {
      resetStress();
      mode = MODE_HOME;
      return;
    }
  }
}

// MEDITATION MODE - same algorithm and GUI as the supplied tab.
final int MEDITATION_BASELINE_READY = 0;
final int MEDITATION_BASELINE = 1;
final int MEDITATION_READY = 2;
final int MEDITATION_ACTIVE = 3;
final int MEDITATION_BASELINE_FAILED = 4;
final int MEDITATION_BASELINE_TIME = 30000;
final float MEDITATION_TOLERANCE = 0.3; // seconds (original rule)

int meditationState = MEDITATION_BASELINE_READY;
int meditationBaselineStart = 0;
int meditationLastSample = 0;
float meditationHRSum = 0;
float meditationRRSum = 0;
int meditationHRCount = 0;
int meditationRRCount = 0;
float meditationRestHR = 0;
float meditationRestRR = 0;
int meditationLastCheckedBreath = 0;
int meditationBadBreaths = 0;
boolean meditationCurrentBreathGood = true;

void drawMeditation() {
  if (meditationState == MEDITATION_BASELINE_READY) drawMeditationBaselineReady();
  else if (meditationState == MEDITATION_BASELINE) {
    updateMeditationBaseline();
    drawMeditationBaseline();
  } else if (meditationState == MEDITATION_READY) drawMeditationReady();
  else if (meditationState == MEDITATION_ACTIVE) {
    updateMeditationBreathing();
    drawMeditationActive();
  } else if (meditationState == MEDITATION_BASELINE_FAILED) drawMeditationBaselineFailed();
}

void drawMeditationBaselineReady() {
  fill(0);
  textStyle(BOLD);
  textSize(25);
  text("MEDITATION MODE", 30, 100);
  textStyle(NORMAL);
  textSize(17);
  text("First collect a 30-second resting baseline.", 30, 160);
  text("Sit quietly and breathe normally.", 30, 195);
  drawModeButton(30, 255, 240, 55, "START BASELINE");
  drawModeButton(290, 255, 180, 55, "BACK HOME");
}

void startMeditationBaseline() {
  meditationState = MEDITATION_BASELINE;
  meditationBaselineStart = millis();
  meditationLastSample = 0;
  meditationHRSum = 0;
  meditationRRSum = 0;
  meditationHRCount = 0;
  meditationRRCount = 0;
}

void updateMeditationBaseline() {
  int now = millis();
  if (meditationLastSample == 0 || now - meditationLastSample >= 1000) {
    meditationLastSample = now;
    int hr = getHeartRate();
    float rr = getRespRate();
    if (hr > 0) {
      meditationHRSum += hr;
      meditationHRCount++;
    }
    if (rr > 0) {
      meditationRRSum += rr;
      meditationRRCount++;
    }
  }
  if (now - meditationBaselineStart >= MEDITATION_BASELINE_TIME) {
    if (meditationHRCount == 0 || meditationRRCount == 0) {
      meditationState = MEDITATION_BASELINE_FAILED;
      return;
    }
    meditationRestHR = meditationHRSum / meditationHRCount;
    meditationRestRR = meditationRRSum / meditationRRCount;
    meditationState = MEDITATION_READY;
  }
}

void drawMeditationBaseline() {
  fill(0);
  textStyle(BOLD);
  textSize(25);
  text("MEDITATION MODE - RESTING BASELINE", 30, 95);
  textStyle(NORMAL);
  int hr = getHeartRate();
  float rr = getRespRate();
  float tin = getInhaleTime();
  float tex = getExhaleTime();
  textSize(16);
  text("HR", 30, 150);
  text("RR", 220, 150);
  text("Inspiration", 430, 150);
  text("Expiration", 650, 150);
  textStyle(BOLD);
  textSize(20);
  text(hr > 0 ? hr + " BPM" : "--", 30, 180);
  text(rr > 0 ? oneDecimal(rr) + " /min" : "--", 220, 180);
  text(tin > 0 ? twoDecimals(tin) + " s" : "--", 430, 180);
  text(tex > 0 ? twoDecimals(tex) + " s" : "--", 650, 180);
  textStyle(NORMAL);
  int remaining = max(0, 30 - (millis() - meditationBaselineStart) / 1000);
  textStyle(BOLD);
  textSize(31);
  text("Baseline: " + remaining + " s remaining", 30, 260);
  textStyle(NORMAL);
  textSize(14);
  fill(80);
  text("Valid HR samples: " + meditationHRCount, 30, 310);
  text("Valid RR samples: " + meditationRRCount, 250, 310);
}

void drawMeditationBaselineFailed() {
  fill(0);
  textStyle(BOLD);
  textSize(25);
  text("MEDITATION MODE", 30, 100);
  textStyle(NORMAL);
  fill(180, 0, 0);
  textSize(18);
  text("Not enough valid HR/RR data were collected.", 30, 165);
  fill(0);
  text("Check the sensors and repeat the baseline.", 30, 205);
  drawModeButton(30, 260, 220, 50, "REPEAT BASELINE");
  drawModeButton(270, 260, 180, 50, "BACK HOME");
}

void drawMeditationReady() {
  fill(0);
  textStyle(BOLD);
  textSize(25);
  text("MEDITATION MODE - BASELINE COMPLETE", 30, 95);
  textStyle(NORMAL);
  textSize(18);
  text("Resting HR: " + oneDecimal(meditationRestHR) + " BPM", 30, 160);
  text("Resting RR: " + oneDecimal(meditationRestRR) + " breaths/min", 30, 200);
  textSize(17);
  text("Meditation target:", 30, 265);
  textStyle(BOLD);
  textSize(22);
  text("Expiration time = 3 x Inspiration time", 30, 300);
  textStyle(NORMAL);
  textSize(14);
  text("Allowed timing difference: +/-" + oneDecimal(MEDITATION_TOLERANCE) + " s", 30, 335);
  drawModeButton(30, 390, 230, 55, "START MEDITATION");
  drawModeButton(280, 390, 220, 55, "REPEAT BASELINE");
  drawModeButton(520, 390, 180, 55, "BACK HOME");
}

void startMeditationSession() {
  meditationState = MEDITATION_ACTIVE;
  meditationBadBreaths = 0;
  meditationCurrentBreathGood = true;
  meditationLastCheckedBreath = breathCount;
  clearGraphHistory();
}

void updateMeditationBreathing() {
  if (breathCount == meditationLastCheckedBreath) return;
  meditationLastCheckedBreath = breathCount;
  float tin = Tinsp / 1000.0;
  float tex = Tex / 1000.0;
  if (tin <= 0 || tex <= 0) return;
  float difference = abs(tex - 3.0 * tin);
  if (difference <= MEDITATION_TOLERANCE) {
    meditationCurrentBreathGood = true;
    meditationBadBreaths = 0;
  } else {
    meditationCurrentBreathGood = false;
    meditationBadBreaths++;
  }
}

void drawMeditationActive() {
  fill(0);
  textStyle(BOLD);
  textSize(24);
  text("MEDITATION MODE - LIVE", 30, 80);
  textStyle(NORMAL);
  int hr = getHeartRate();
  float rr = getRespRate();
  float tin = getInhaleTime();
  float tex = getExhaleTime();
  textSize(15);
  text("HR", 30, 120);
  text("RR", 180, 120);
  text("Inspiration", 340, 120);
  text("Expiration", 510, 120);
  textStyle(BOLD);
  textSize(19);
  text(hr > 0 ? hr + " BPM" : "--", 30, 147);
  text(rr > 0 ? oneDecimal(rr) + " /min" : "--", 180, 147);
  text(tin > 0 ? twoDecimals(tin) + " s" : "--", 340, 147);
  text(tex > 0 ? twoDecimals(tex) + " s" : "--", 510, 147);
  textStyle(NORMAL);
  fill(0);
  textSize(14);
  text("Target: Texp = 3 x Tinsp", 740, 115);
  text("Consecutive breaths outside target: " + meditationBadBreaths, 740, 140);
  if (meditationBadBreaths >= 3) {
    fill(200, 30, 30);
    textStyle(BOLD);
    textSize(24);
    text("ADJUST BREATHING", 740, 180);
  } else {
    fill(20, 140, 60);
    textStyle(BOLD);
    textSize(24);
    text("KEEP BREATHING", 740, 180);
  }
  textStyle(NORMAL);
  drawECGGraph(ecgPlot, 30, 230, 500, 270);
  drawRespGraph(fsrPlot, 570, 230, 500, 270);
  fill(0);
  textSize(12);
  text("Resting HR: " + oneDecimal(meditationRestHR) + " BPM", 30, 535);
  text("Resting RR: " + oneDecimal(meditationRestRR) + " breaths/min", 250, 535);
  drawModeButton(30, 590, 220, 50, "REPEAT BASELINE");
  drawModeButton(270, 590, 200, 50, "END ACTIVITY");
}

void resetMeditation() {
  meditationState = MEDITATION_BASELINE_READY;
  meditationBaselineStart = 0;
  meditationLastSample = 0;
  meditationHRSum = 0;
  meditationRRSum = 0;
  meditationHRCount = 0;
  meditationRRCount = 0;
  meditationRestHR = 0;
  meditationRestRR = 0;
  meditationLastCheckedBreath = breathCount;
  meditationBadBreaths = 0;
  meditationCurrentBreathGood = true;
}

void meditationMousePressed() {
  if (meditationState == MEDITATION_BASELINE_READY) {
    if (insideButton(30, 255, 240, 55)) {
      startMeditationBaseline();
      return;
    }
    if (insideButton(290, 255, 180, 55)) {
      resetMeditation();
      mode = MODE_HOME;
      return;
    }
  } else if (meditationState == MEDITATION_BASELINE_FAILED) {
    if (insideButton(30, 260, 220, 50)) {
      startMeditationBaseline();
      return;
    }
    if (insideButton(270, 260, 180, 50)) {
      resetMeditation();
      mode = MODE_HOME;
      return;
    }
  } else if (meditationState == MEDITATION_READY) {
    if (insideButton(30, 390, 230, 55)) {
      startMeditationSession();
      return;
    }
    if (insideButton(280, 390, 220, 55)) {
      startMeditationBaseline();
      return;
    }
    if (insideButton(520, 390, 180, 55)) {
      resetMeditation();
      mode = MODE_HOME;
      return;
    }
  } else if (meditationState == MEDITATION_ACTIVE) {
    if (insideButton(30, 590, 220, 50)) {
      resetMeditation();
      startMeditationBaseline();
      return;
    }
    if (insideButton(270, 590, 200, 50)) {
      resetMeditation();
      mode = MODE_HOME;
      return;
    }
  }
}

// ======= SECTION IV (original algorithms) =======
// SectionIV.pde
// Cardiorespiratory Pattern Monitor

final int SECTION_BASELINE_READY = 0;
final int SECTION_BASELINE = 1;
final int SECTION_READY = 2;
final int SECTION_ACTIVE = 3;
final int SECTION_BASELINE_FAILED = 4;

final int SECTION_BASELINE_TIME = 30000;
final int BREATHING_PAUSE_TIME = 10000;

int sectionState = SECTION_BASELINE_READY;

int sectionBaselineStart = 0;
int sectionLastSample = 0;

float sectionHRSum = 0;
float sectionRRSum = 0;
int sectionHRCount = 0;
int sectionRRCount = 0;

float sectionRestHR = 0;
float sectionRestRR = 0;

int sectionMonitoringStart = 0;
int sectionBreathCountAtStart = 0;

String sectionHeartState = "WAITING";
String sectionBreathingState = "WAITING";
String sectionResponse = "WAITING";

// MAIN SECTION IV SCREEN

void drawSectionIV() {
  if (sectionState == SECTION_BASELINE_READY) drawSectionBaselineReady();
  else if (sectionState == SECTION_BASELINE) {
    updateSectionBaseline();
    drawSectionBaseline();
  }

  else if (sectionState == SECTION_READY) drawSectionReady();
  else if (sectionState == SECTION_ACTIVE) {
    updateSectionClassification();
    drawSectionActive();
  }

  else if (sectionState == SECTION_BASELINE_FAILED) drawSectionBaselineFailed();
}

// BASELINE READY

void drawSectionBaselineReady() {
  fill(0);
  textStyle(BOLD);
  textSize(25);
  text("CARDIORESPIRATORY PATTERN MONITOR", 30, 100);
  textStyle(NORMAL);
  textSize(17);
  text("First collect a 30-second resting baseline.", 30, 160);
  text("Heart rate and breathing rate will then be compared with resting values.", 30, 195);
  drawModeButton(30, 255, 240, 55, "START BASELINE");
  drawModeButton(290, 255, 180, 55, "BACK HOME");
}

// START BASELINE

void startSectionBaseline() {
  sectionState = SECTION_BASELINE;
  sectionBaselineStart = millis();
  sectionLastSample = 0;
  sectionHRSum = 0;
  sectionRRSum = 0;
  sectionHRCount = 0;
  sectionRRCount = 0;
}

// UPDATE BASELINE

void updateSectionBaseline() {
  int now = millis();
  if (sectionLastSample == 0 || now - sectionLastSample >= 1000) {
    sectionLastSample = now;
    int hr = getHeartRate();
    float rr = getRespRate();
    if (hr > 0) {
      sectionHRSum += hr;
      sectionHRCount++;
    }

    if (rr > 0) {
      sectionRRSum += rr;
      sectionRRCount++;
    }
  }

  if (now - sectionBaselineStart >= SECTION_BASELINE_TIME) {
    if (sectionHRCount == 0 || sectionRRCount == 0) {
      sectionState = SECTION_BASELINE_FAILED;
      return;
    }

    sectionRestHR = sectionHRSum / sectionHRCount;
    sectionRestRR = sectionRRSum / sectionRRCount;
    sectionState = SECTION_READY;
  }
}

// BASELINE SCREEN

void drawSectionBaseline() {
  fill(0);
  textStyle(BOLD);
  textSize(25);
  text("SECTION IV - RESTING BASELINE", 30, 95);
  textStyle(NORMAL);
  int hr = getHeartRate();
  float rr = getRespRate();
  float tin = getInhaleTime();
  float tex = getExhaleTime();
  textSize(16);
  text("HR", 30, 150);
  text("RR", 220, 150);
  text("Inspiration", 430, 150);
  text("Expiration", 650, 150);
  textStyle(BOLD);
  textSize(20);
  text(hr > 0 ? hr + " BPM" : "--", 30, 180);
  text(rr > 0 ? oneDecimal(rr) + " /min" : "--", 220, 180);
  text(tin > 0 ? twoDecimals(tin) + " s" : "--", 430, 180);
  text(tex > 0 ? twoDecimals(tex) + " s" : "--", 650, 180);
  textStyle(NORMAL);
  int remaining = max(0, 30 - (millis() - sectionBaselineStart) / 1000);
  textStyle(BOLD);
  textSize(31);
  text("Baseline: " + remaining + " s remaining", 30, 260);
  textStyle(NORMAL);
  textSize(14);
  fill(80);
  text("Valid HR samples: " + sectionHRCount, 30, 310);
  text("Valid RR samples: " + sectionRRCount, 250, 310);
}

// BASELINE FAILED

void drawSectionBaselineFailed() {
  fill(0);
  textStyle(BOLD);
  textSize(25);
  text("CARDIORESPIRATORY PATTERN MONITOR", 30, 100);
  textStyle(NORMAL);
  fill(180, 0, 0);
  textSize(18);
  text("Not enough valid HR/RR data were collected.", 30, 165);
  fill(0);
  text("Check the sensors and repeat the baseline.", 30, 205);
  drawModeButton(30, 260, 220, 50, "REPEAT BASELINE");
  drawModeButton(270, 260, 180, 50, "BACK HOME");
}

// BASELINE COMPLETE

void drawSectionReady() {
  fill(0);
  textStyle(BOLD);
  textSize(25);
  text("CARDIORESPIRATORY PATTERN MONITOR", 30, 95);
  textStyle(NORMAL);
  textSize(18);
  text("Resting HR: " + oneDecimal(sectionRestHR) + " BPM", 30, 155);
  text("Resting RR: " + oneDecimal(sectionRestRR) + " breaths/min", 30, 195);
  textSize(15);
  text("Classification is based on ±10% from the resting values.", 30, 255);
  text("A breathing pause is detected if no complete breath is detected for 10 seconds.", 30, 285);
  drawModeButton(30, 350, 250, 55, "START MONITORING");
  drawModeButton(300, 350, 220, 55, "REPEAT BASELINE");
  drawModeButton(540, 350, 180, 55, "BACK HOME");
}

// START MONITORING

void startSectionMonitoring() {
  sectionState = SECTION_ACTIVE;
  sectionMonitoringStart = millis();
  sectionBreathCountAtStart = breathCount;
  sectionHeartState = "WAITING";
  sectionBreathingState = "WAITING";
  sectionResponse = "WAITING";
  clearGraphHistory();
}

// LIVE CLASSIFICATION

void updateSectionClassification() {
  int hr = getHeartRate();
  float rr = getRespRate();
  boolean validHR = hr > 0;
  boolean validRR = rr > 0;

  // HEART RATE CLASSIFICATION
  if (!validHR) {
    sectionHeartState = "NO VALID HR";
  }

  else if (hr < 0.90 * sectionRestHR) {
    sectionHeartState = "SLOW HR";
  }

  else if (hr > 1.10 * sectionRestHR) {
    sectionHeartState = "FAST HR";
  }

  else {
    sectionHeartState = "NORMAL HR";
  }

  // BREATHING PAUSE CHECK
  // Before the first new breath, count from monitoring start.
  // After that, count from the last detected complete breath.
  int breathReferenceTime;
  if (breathCount > sectionBreathCountAtStart && lastBreathTime > 0) {
    breathReferenceTime = lastBreathTime;
  }
  else {
    breathReferenceTime = sectionMonitoringStart;
  }

  boolean breathingPause = millis() - breathReferenceTime >= BREATHING_PAUSE_TIME;

  // BREATHING RATE CLASSIFICATION
  if (breathingPause) {
    sectionBreathingState = "BREATHING PAUSE";
  }

  else if (!validRR) {
    sectionBreathingState = "NO VALID RR";
  }

  else if (rr < 0.90 * sectionRestRR) {
    sectionBreathingState = "SLOW BREATHING";
  }

  else if (rr > 1.10 * sectionRestRR) {
    sectionBreathingState = "FAST BREATHING";
  }

  else {
    sectionBreathingState = "NORMAL BREATHING";
  }

  // CARDIORESPIRATORY RESPONSE
  if (breathingPause) {
    sectionResponse = "BREATHING PAUSE DETECTED";
  }

  else if (!validHR || !validRR) {
    sectionResponse = "INSUFFICIENT DATA";
  }

  else if (
    (sectionHeartState.equals("SLOW HR") && sectionBreathingState.equals("SLOW BREATHING")) ||
    (sectionHeartState.equals("NORMAL HR") && sectionBreathingState.equals("NORMAL BREATHING")) ||
    (sectionHeartState.equals("FAST HR") && sectionBreathingState.equals("FAST BREATHING"))
  ) {
    sectionResponse = "MATCHED";
  }

  else {
    sectionResponse = "NOT MATCHED";
  }
}

// LIVE MONITORING SCREEN

void drawSectionActive() {
  fill(0);
  textStyle(BOLD);
  textSize(24);
  text("CARDIORESPIRATORY PATTERN MONITOR", 30, 80);
  textStyle(NORMAL);
  int hr = getHeartRate();
  float rr = getRespRate();
  float tin = getInhaleTime();
  float tex = getExhaleTime();

  // Live physiological values
  textSize(15);
  text("HR", 30, 120);
  text("RR", 170, 120);
  text("Inspiration", 330, 120);
  text("Expiration", 500, 120);
  textStyle(BOLD);
  textSize(19);
  text(hr > 0 ? hr + " BPM" : "--", 30, 147);
  text(rr > 0 ? oneDecimal(rr) + " /min" : "--", 170, 147);
  text(tin > 0 ? twoDecimals(tin) + " s" : "--", 330, 147);
  text(tex > 0 ? twoDecimals(tex) + " s" : "--", 500, 147);
  textStyle(NORMAL);

  // Current states
  fill(0);
  textSize(14);
  text("Heart state", 700, 110);
  text("Breathing state", 700, 160);
  textStyle(BOLD);
  textSize(19);
  if (sectionHeartState.equals("FAST HR")) fill(200, 50, 40);
  else if (sectionHeartState.equals("SLOW HR")) fill(40, 100, 200);
  else fill(40, 140, 70);
  text(sectionHeartState, 700, 135);
  if (sectionBreathingState.equals("BREATHING PAUSE")) fill(200, 30, 30);
  else if (sectionBreathingState.equals("FAST BREATHING")) fill(200, 80, 30);
  else if (sectionBreathingState.equals("SLOW BREATHING")) fill(40, 100, 200);
  else fill(40, 140, 70);
  text(sectionBreathingState, 700, 185);
  textStyle(NORMAL);

  // Main response
  fill(0);
  textSize(14);
  text("Cardiorespiratory response", 700, 215);
  if (sectionResponse.equals("MATCHED")) fill(20, 140, 60);
  else if (sectionResponse.equals("NOT MATCHED")) fill(200, 120, 20);
  else if (sectionResponse.equals("BREATHING PAUSE DETECTED")) fill(200, 30, 30);
  else fill(100);
  textStyle(BOLD);
  textSize(22);
  text(sectionResponse, 700, 245);
  textStyle(NORMAL);

  // Live signals
  drawECGGraph(ecgPlot, 30, 285, 500, 245);
  drawRespGraph(fsrPlot, 570, 285, 500, 245);

  // Resting reference
  fill(0);
  textSize(12);
  text("Resting HR: " + oneDecimal(sectionRestHR) + " BPM", 30, 565);
  text("Resting RR: " + oneDecimal(sectionRestRR) + " breaths/min", 250, 565);
  drawModeButton(30, 620, 220, 50, "REPEAT BASELINE");
  drawModeButton(270, 620, 200, 50, "END ACTIVITY");
}

// RESET SECTION IV

void resetSectionIV() {
  sectionState = SECTION_BASELINE_READY;
  sectionBaselineStart = 0;
  sectionLastSample = 0;
  sectionHRSum = 0;
  sectionRRSum = 0;
  sectionHRCount = 0;
  sectionRRCount = 0;
  sectionRestHR = 0;
  sectionRestRR = 0;
  sectionMonitoringStart = 0;
  sectionBreathCountAtStart = breathCount;
  sectionHeartState = "WAITING";
  sectionBreathingState = "WAITING";
  sectionResponse = "WAITING";
}

// MOUSE INPUT

void sectionIVMousePressed() {
  if (sectionState == SECTION_BASELINE_READY) {
    if (insideButton(30, 255, 240, 55)) {
      startSectionBaseline();
      return;
    }

    if (insideButton(290, 255, 180, 55)) {
      resetSectionIV();
      mode = MODE_HOME;
      return;
    }
  }

  else if (sectionState == SECTION_BASELINE_FAILED) {
    if (insideButton(30, 260, 220, 50)) {
      startSectionBaseline();
      return;
    }

    if (insideButton(270, 260, 180, 50)) {
      resetSectionIV();
      mode = MODE_HOME;
      return;
    }
  }

  else if (sectionState == SECTION_READY) {
    if (insideButton(30, 350, 250, 55)) {
      startSectionMonitoring();
      return;
    }

    if (insideButton(300, 350, 220, 55)) {
      startSectionBaseline();
      return;
    }

    if (insideButton(540, 350, 180, 55)) {
      resetSectionIV();
      mode = MODE_HOME;
      return;
    }
  }

  else if (sectionState == SECTION_ACTIVE) {
    if (insideButton(30, 620, 220, 50)) {
      resetSectionIV();
      startSectionBaseline();
      return;
    }

    if (insideButton(270, 620, 200, 50)) {
      resetSectionIV();
      mode = MODE_HOME;
      return;
    }
  }
}
