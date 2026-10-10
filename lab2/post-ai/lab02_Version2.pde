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
// Display annotations only; beat detection and BPM calculations are unchanged.
ArrayList<Float> ecgBeatMarkerTimes = new ArrayList<Float>();
ArrayList<Float> ecgBeatMarkerBaselines = new ArrayList<Float>();

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
  background(uiBackground);
  drawHeader();
  if (mode == MODE_HOME) drawHome();
  else if (mode == MODE_FITNESS) drawFitness();
  else if (mode == MODE_STRESS) drawStress();
  else if (mode == MODE_MEDITATION) drawMeditation();
  else if (mode == MODE_SECTION_IV) drawSectionIV();
}


// ===== LAB 2 BIOMEDICAL DASHBOARD - PRESENTATION ONLY =====
// v2: 25-pixel button padding inside white panels + 5-Hz Fitness HR chart
// v3: Stress Monitoring classification only: 3-s persistence, 50% hysteresis,
//     minimum 1-BPM / 1-breath/min calibration differences, and disagreement.
// Standard Processing drawing commands. No external UI libraries.
color uiBackground = color(19, 80, 137);
color uiNavy = color(15, 47, 86);
color uiBlue = color(34, 112, 193);
color uiBlueLight = color(219, 237, 254);
color uiGreen = color(37, 166, 111);
color uiRed = color(212, 65, 79);
color uiAmber = color(204, 125, 39);
color uiInk = color(28, 48, 75);
color uiMuted = color(107, 127, 151);
color uiLine = color(223, 234, 244);

void drawPanel(float x, float y, float w, float h) {
  noStroke();
  fill(3, 29, 67, 38);
  rect(x + 2, y + 5, w, h, 17);
  fill(255);
  rect(x, y, w, h, 17);
}

void uiText(String message, float x, float y, float size, color c, boolean bold) {
  textAlign(LEFT, BASELINE);
  textStyle(bold ? BOLD : NORMAL);
  textSize(size);
  fill(c);
  text(message, x, y);
}

void pageHeading(String title, String subtitle) {
  uiText(title, 30, 88, 23, color(255), true);
  uiText(subtitle, 31, 109, 12, color(203, 228, 249), false);
}

void drawMetricCard(float x, float y, float w, float h, String label, String value, color accent) {
  drawPanel(x, y, w, h);
  noStroke();
  fill(accent);
  rect(x + 16, y + 16, 4, h - 32, 2);
  uiText(label.toUpperCase(), x + 30, y + 30, 11, uiMuted, true);
  float valueSize = value.length() > 16 ? 16 : (value.length() > 12 ? 20 : 26);
  // Fit values even in the narrow four-column live-measurement cards.
  valueSize = min(valueSize, max(14, (w - 43) / max(1, 0.57 * value.length())));
  uiText(value, x + 30, y + h - 17, valueSize, uiInk, true);
}

void drawVitals(float y, boolean showZone) {
  int hr = getHeartRate();
  float rr = getRespRate();
  float tin = getInhaleTime();
  float tex = getExhaleTime();
  drawMetricCard(30, y, 162, 84, "Heart rate", hr > 0 ? hr + " BPM" : "--", uiRed);
  drawMetricCard(207, y, 162, 84, "Resp. rate", rr > 0 ? oneDecimal(rr) + " /min" : "--", uiBlue);
  drawMetricCard(384, y, 162, 84, "Inspiration", tin > 0 ? twoDecimals(tin) + " s" : "--", uiGreen);
  drawMetricCard(561, y, 162, 84, "Expiration", tex > 0 ? twoDecimals(tex) + " s" : "--", uiBlue);
  if (showZone) {
    drawStatusCard(738, y, 332, 84, "CURRENT CARDIO ZONE",
                   getFitnessZoneLabel(), fitnessZoneColor(getHeartRate()));
  }
}

void drawStatusCard(float x, float y, float w, float h, String label, String value, color accent) {
  drawPanel(x, y, w, h);
  fill(accent);
  noStroke();
  rect(x + 15, y + 15, 5, h - 30, 3);
  uiText(label, x + 31, y + (h < 75 ? 18 : 30), 11, uiMuted, true);
  float valueSize = value.length() > 23 ? 16 : (value.length() > 16 ? 19 : 25);
  // Shrink long physiological-state labels to fit narrow cards.
  valueSize = min(valueSize, max(11, (w - 42) / max(1, 0.59 * value.length())));
  uiText(value, x + 31, y + h - (h < 75 ? 9 : 18), valueSize, accent, true);
}

color colorForStatus(String s) {
  if (s.equals("CALM") || s.equals("MATCHED") || s.equals("NORMAL HR") ||
      s.equals("NORMAL BREATHING")) return uiGreen;
  if (s.equals("STRESSED") || s.equals("FAST HR") ||
      s.equals("BREATHING PAUSE") || s.equals("BREATHING PAUSE DETECTED")) return uiRed;
  if (s.equals("SLOW HR") || s.equals("SLOW BREATHING")) return uiBlue;
  if (s.equals("NOT MATCHED") || s.equals("FAST BREATHING")) return uiAmber;
  return uiMuted;
}

void drawInstructions(float x, float y, float w, float h,
                      String title, String line1, String line2) {
  drawPanel(x, y, w, h);
  uiText(title.toUpperCase(), x + 24, y + 36, 12, uiBlue, true);
  uiText(line1, x + 24, y + 77, 19, uiInk, true);
  if (line2.length() > 0) uiText(line2, x + 24, y + 107, 14, uiMuted, false);
}

void drawCountdownPanel(int start, int durationMs, String phase,
                        String advice, int hrCount, int rrCount) {
  float progress = constrain(1.0 - (millis() - start) / float(durationMs), 0, 1);
  int remaining = max(0, (int)ceil((durationMs - (millis() - start)) / 1000.0));
  drawPanel(30, 239, 1040, 173);
  uiText(phase.toUpperCase(), 55, 270, 12, uiBlue, true);
  uiText(remaining + " s", 55, 319, 37, uiInk, true);
  uiText("remaining", 175, 317, 16, uiMuted, false);
  uiText(advice, 55, 385, 13, uiMuted, false);
  uiText("VALID SAMPLES   HR " + hrCount + "  /  RR " + rrCount,
         790, 272, 11, uiMuted, true);
  noStroke();
  fill(226, 237, 243);
  rect(55, 340, 990, 16, 8);
  if (progress > 0) {
    fill(uiGreen);
    rect(55, 340, 990 * progress, 16, 8);
  }
}

void drawCalibrationSignals() {
  drawECGGraph(ecgPlot, 30, 435, 505, 214);
  drawRespGraph(fsrPlot, 565, 435, 505, 214);
}

void drawReferenceStrip(float hr, float rr, float y) {
  drawPanel(30, y, 1040, 48);
  uiText("RESTING REFERENCE", 48, y + 29, 11, uiMuted, true);
  uiText("HR " + oneDecimal(hr) + " BPM", 274, y + 30, 15, uiInk, true);
  uiText("RR " + oneDecimal(rr) + " breaths/min", 530, y + 30, 15, uiInk, true);
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
  noStroke();
  fill(uiNavy);
  rect(0, 0, width, 57);
  fill(uiBlue);
  rect(0, 55, width, 3);
  uiText("BIO / MONITOR", 30, 35, 22, color(255), true);
  uiText("LAB 02   |   ECG + RESPIRATION", 264, 33, 11, color(187, 211, 236), true);
  String label;
  color signalColor;
  if (myPort == null) {
    label = "NO SERIAL DEVICE"; signalColor = uiRed;
  } else if (!hasFreshData()) {
    label = "WAITING FOR DATA"; signalColor = uiAmber;
  } else if (leadsOff) {
    label = "ECG LEADS OFF"; signalColor = uiRed;
  } else {
    label = "SENSOR LIVE"; signalColor = uiGreen;
  }
  noStroke();
  fill(255, 255, 255, 18);
  rect(862, 13, 208, 31, 15);
  fill(signalColor);
  ellipse(882, 29, 9, 9);
  uiText(label, 896, 33, 12, color(255), true);
}

void drawHome() {
  pageHeading("Physiological monitoring", "Real-time ECG and breathing signals  /  Choose a monitoring mode below");
  int hr = getHeartRate();
  float rr = getRespRate();
  float tin = getInhaleTime();
  float tex = getExhaleTime();
  drawMetricCard(30, 125, 249, 90, "Heart rate", hr > 0 ? hr + " BPM" : "--", uiRed);
  drawMetricCard(294, 125, 249, 90, "Respiratory rate", rr > 0 ? oneDecimal(rr) + " /min" : "--", uiBlue);
  drawMetricCard(558, 125, 249, 90, "Inspiration", tin > 0 ? twoDecimals(tin) + " s" : "--", uiGreen);
  drawMetricCard(822, 125, 248, 90, "Expiration", tex > 0 ? twoDecimals(tex) + " s" : "--", uiBlue);
  drawECGGraph(ecgPlot, 30, 236, 505, 284);
  drawRespGraph(fsrPlot, 565, 236, 505, 284);
  uiText("SELECT A MODE", 30, 562, 13, color(222, 239, 255), true);
  drawModeButton(fitnessButtonX, homeButtonY, homeButtonW, homeButtonH, "FITNESS MODE");
  drawModeButton(stressButtonX, homeButtonY, homeButtonW, homeButtonH, "STRESS MONITORING");
  drawModeButton(meditationButtonX, homeButtonY, homeButtonW, homeButtonH, "MEDITATION");
  drawModeButton(sectionButtonX, homeButtonY, homeButtonW, homeButtonH, "SECTION IV");
  uiText("ECG: red trace + blue QRS markers    |    FSR: 10-sample moving average    |    ADC scale: 0-1023",
         31, 680, 12, color(213, 234, 255), false);
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
  drawPanel(x, y, w, h);
  uiText(title.equals("ECG") ? "ECG  /  CARDIAC SIGNAL" : "FSR  /  RESPIRATORY SIGNAL",
         x + 20, y + 27, 12, uiInk, true);
  uiText(title.equals("ECG") ? "Blue dots: detected QRS events" : "10-sample moving average",
         x + w - 215, y + 27, 10, uiMuted, false);
  float left = x + 43;
  float right = x + w - 20;
  float top = y + 44;
  float bottom = y + h - 29;

  // Fixed ADC mapping and 512 guide: no baseline correction, zoom or
  // modification to the existing FSR 10-point graphic moving average.
  stroke(uiLine);
  strokeWeight(1);
  float middleY = map(512, GRAPH_ADC_MIN, GRAPH_ADC_MAX, bottom, top);
  line(left, top, right, top);
  line(left, middleY, right, middleY);
  line(left, bottom, right, bottom);
  uiText("1023", x + 8, top + 4, 10, uiMuted, false);
  uiText("512", x + 14, middleY + 4, 10, uiMuted, false);
  uiText("0", x + 24, bottom + 4, 10, uiMuted, false);
  uiText("last 5 s", right - 42, bottom + 18, 10, uiMuted, false);

  float[] times;
  float[] values;
  float[] markTimes;
  float[] markBases;
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
    int m = title.equals("ECG") ? ecgBeatMarkerTimes.size() : 0;
    markTimes = new float[m];
    markBases = new float[m];
    for (int i = 0; i < m; i++) {
      markTimes[i] = ecgBeatMarkerTimes.get(i);
      markBases[i] = ecgBeatMarkerBaselines.get(i);
    }
  }
  if (values.length < 2) return;
  float latestTime = times[times.length - 1];
  float startTime = latestTime - GRAPH_WINDOW_MS;
  stroke(lineColor);
  strokeWeight(1.6);
  noFill();
  beginShape();
  for (int i = 0; i < values.length; i++) {
    if (times[i] < startTime) continue;
    float sx = map(times[i], startTime, latestTime, left, right);
    float sy = map(values[i], GRAPH_ADC_MIN, GRAPH_ADC_MAX, bottom, top);
    vertex(sx, constrain(sy, top, bottom));
  }
  endShape();

  // A detection comes from the original envelope threshold, not a precise
  // ECG maximum. Snap the visual marker to the strongest LOCAL displayed
  // deflection in the preceding 230 ms, without changing the detection time.
  // This is only a graphical positioning operation.
  if (title.equals("ECG")) {
    for (int j = 0; j < markTimes.length; j++) {
      if (markTimes[j] < startTime || markTimes[j] > latestTime + 40) continue;
      int candidate = -1;
      float maxDeviation = -1;
      for (int i = 0; i < values.length; i++) {
        if (times[i] < markTimes[j] - 230 || times[i] > markTimes[j] + 30) continue;
        if (times[i] < startTime) continue;
        float deviation = abs(values[i] - markBases[j]);
        if (deviation > maxDeviation) {
          maxDeviation = deviation;
          candidate = i;
        }
      }
      if (candidate >= 0) {
        float px = map(times[candidate], startTime, latestTime, left, right);
        float py = map(values[candidate], GRAPH_ADC_MIN, GRAPH_ADC_MAX, bottom, top);
        stroke(255);
        strokeWeight(1.6);
        fill(uiBlue);
        ellipse(px, constrain(py, top, bottom), 10, 10);
      }
    }
  }
  strokeWeight(1);
  noStroke();
}

void clearGraphHistory() {
  synchronized (graphLock) {
    ecgPlot.clear();
    fsrPlot.clear();
    graphTimes.clear();
    ecgBeatMarkerTimes.clear();
    ecgBeatMarkerBaselines.clear();
    plotCounter = 0;
  }
}

void drawModeButton(float x, float y, float w, float h, String label) {
  boolean hover = insideButton(x, y, w, h);
  boolean danger = label.startsWith("STOP") || label.startsWith("END ACTIVITY") ||
                   label.startsWith("END SESSION");
  boolean secondary = label.equals("BACK HOME") || label.startsWith("REPEAT");
  boolean onHome = mode == MODE_HOME;
  color bg = danger ? uiRed : (secondary ? color(232, 242, 251) : (onHome ? color(255) : uiBlue));
  color fg = (secondary || onHome) ? uiNavy : color(255);
  if (hover) bg = lerpColor(bg, onHome ? uiBlueLight : color(255), 0.14);
  noStroke();
  fill(7, 34, 67, 32);
  rect(x + 1, y + 4, w, h, 13);
  fill(bg);
  rect(x, y, w, h, 13);
  textStyle(BOLD);
  textSize(13);
  fill(fg);
  textAlign(CENTER, CENTER);
  text(label, x + w / 2, y + h / 2);
  textAlign(LEFT, BASELINE);
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
  // A QRS detection is recorded for the GRAPH ONLY. It does not affect BPM.
  ecgBeatMarkerTimes.add(float(beat_new));
  ecgBeatMarkerBaselines.add(ECG_baseline);
  if (ecgBeatMarkerTimes.size() > 120) {
    ecgBeatMarkerTimes.remove(0);
    ecgBeatMarkerBaselines.remove(0);
  }
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
  pageHeading("Fitness mode", "Step 1 of 3  /  Enter age to personalize your cardio zones");
  drawInstructions(30, 130, 690, 325, "PERSONAL INFORMATION",
                   "Enter your age to begin", "Estimated maximum heart rate = 220 - age");
  noStroke();
  fill(239, 246, 252);
  rect(490, 199, 170, 67, 10);
  uiText(fitnessAgeInput.length() == 0 ? "Type age..." : fitnessAgeInput,
         512, 241, 24, fitnessAgeInput.length() == 0 ? uiMuted : uiInk, true);
  drawModeButton(55, 280, 220, 50, "START BASELINE");
  drawModeButton(295, 280, 180, 50, "BACK HOME");
  // Buttons are drawn over a separate footer strip to retain click coordinates.
  drawPanel(750, 130, 320, 195);
  uiText("WHAT HAPPENS NEXT", 775, 164, 12, uiBlue, true);
  uiText("01   30-second resting baseline", 775, 205, 14, uiInk, false);
  uiText("02   Start activity tracking", 775, 242, 14, uiInk, false);
  uiText("03   Review cardio-zone times", 775, 279, 14, uiInk, false);
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
  pageHeading("Fitness  /  Resting baseline", "Step 2 of 3  /  Rest quietly for 30 seconds");
  drawVitals(129, false);
  drawStatusCard(738, 129, 332, 84, "CALIBRATION", "ACQUIRING", uiBlue);
  drawCountdownPanel(fitnessBaselineStart, FITNESS_BASELINE_TIME, "Resting baseline",
                     "Stay still. HR and RR are averaged only when valid.",
                     fitnessHRCount, fitnessRRCount);
  drawCalibrationSignals();
}

// BASELINE FAILED

void drawFitnessBaselineFailed() {
  pageHeading("Fitness  /  Baseline not completed", "Sensor quality  /  Resting measurements unavailable");
  drawInstructions(30, 129, 780, 225, "ACQUISITION UNSUCCESSFUL",
                   "Not enough valid HR/RR data collected",
                   "Check electrode contact and the FSR sensor, then repeat.");
  drawModeButton(55, 260, 220, 50, "REPEAT BASELINE");
  drawModeButton(295, 260, 180, 50, "BACK HOME");
}

// BASELINE COMPLETE

void drawFitnessReady() {
  pageHeading("Fitness  /  Baseline complete", "Step 3 of 3  /  Your resting reference is ready");
  drawMetricCard(30, 139, 241, 105, "Resting HR", oneDecimal(fitnessRestingHR) + " BPM", uiRed);
  drawMetricCard(287, 139, 241, 105, "Resting RR", oneDecimal(fitnessRestingRR) + " /min", uiBlue);
  drawMetricCard(544, 139, 241, 105, "Estimated HR max", (220 - fitnessAge) + " BPM", uiGreen);
  drawMetricCard(801, 139, 269, 105, "Age", str(fitnessAge) + " years", uiBlue);
  drawPanel(30, 274, 1040, 155);
  uiText("BASELINE ACQUIRED", 55, 306, 13, uiGreen, true);
  uiText("Begin tracking activity and cardio-zone times.",
         55, 338, 16, uiInk, false);
  drawModeButton(55, 355, 220, 55, "START ACTIVITY");
  drawModeButton(295, 355, 220, 55, "REPEAT BASELINE");
  drawModeButton(535, 355, 180, 55, "BACK HOME");
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

  // HR GRAPH - DISPLAY ONLY
  // Plot at 5 Hz (one point every 200 ms), using the most recent REAL BPM
  // produced by the original ECG algorithm. No physiological calculation,
  // baseline averaging or cardio-zone threshold is changed here.
  if (fitnessLastHRGraphSample == 0 || now - fitnessLastHRGraphSample >= 200) {
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
  pageHeading("Fitness  /  Live activity", "Live heart-rate zones and ECG / FSR signals");
  drawFitnessLiveParameters(117, true);
  drawECGGraph(ecgPlot, 30, 215, 505, 178);
  drawRespGraph(fsrPlot, 565, 215, 505, 178);
  drawFitnessHRGraph(30, 416, 1040, 204);
  int elapsed = (millis() - fitnessActivityStart) / 1000;
  uiText("ACTIVITY TIME   " + elapsed + " s", 31, 668, 14, color(255), true);
  drawModeButton(820, 635, 250, 50, "STOP FITNESS SESSION");
}

// LIVE PARAMETERS

void drawFitnessLiveParameters(float y, boolean showZone) {
  drawVitals(y, showZone);
}

// HR VS TIME GRAPH WITH CARDIO ZONES

void drawFitnessHRGraph(float x, float y, float w, float h) {
  drawPanel(x, y, w, h);
  uiText("HEART RATE  /  CARDIO ZONES", x + 20, y + 26, 12, uiInk, true);
  float hrMax = 220.0 - fitnessAge;
  if (hrMax <= 0) return;
  float plotLeft = x + 52;
  float plotRight = x + w - 23;
  float plotTop = y + 40;
  float plotBottom = y + h - 28;

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
  pageHeading("Fitness  /  Activity summary", "Session complete  /  Time spent in each heart-rate zone");
  drawPanel(30, 127, 1040, 453);
  float totalTime = (fitnessActivityStop - fitnessActivityStart) / 1000.0;
  uiText("Resting HR: " + oneDecimal(fitnessRestingHR) + " BPM", 57, 163, 15, uiInk, true);
  uiText("Resting RR: " + oneDecimal(fitnessRestingRR) + " breaths/min", 371, 163, 15, uiInk, true);
  uiText("CARDIO-ZONE DISTRIBUTION", 57, 207, 13, uiBlue, true);
  drawFitnessSummaryRow("BELOW 50%", fitnessBelowZoneTime, color(205), 240);
  drawFitnessSummaryRow("VERY LIGHT  50-60%", fitnessZoneTime[0], color(170), 290);
  drawFitnessSummaryRow("LIGHT  60-70%", fitnessZoneTime[1], color(70, 150, 220), 340);
  drawFitnessSummaryRow("MODERATE  70-80%", fitnessZoneTime[2], color(50, 165, 90), 390);
  drawFitnessSummaryRow("HARD  80-90%", fitnessZoneTime[3], color(240, 155, 30), 440);
  drawFitnessSummaryRow("MAXIMUM  >90%", fitnessZoneTime[4], color(215, 45, 55), 490);
  uiText("Total activity duration  " + oneDecimal(totalTime) + " s", 57, 555, 17, uiInk, true);
  drawModeButton(30, 610, 220, 50, "END ACTIVITY");
}

void drawFitnessSummaryRow(String label, float time, int zoneColor, float y) {
  noStroke();
  fill(zoneColor);
  rect(58, y - 19, 22, 22, 6);
  uiText(label, 98, y, 15, uiInk, false);
  uiText(oneDecimal(time) + " s", 430, y, 16, uiInk, true);
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
    if (insideButton(55, 280, 220, 50)) {
      startFitnessBaseline();
      return;
    }

    if (insideButton(295, 280, 180, 50)) {
      resetFitness();
      mode = MODE_HOME;
      return;
    }
  }

  else if (fitnessState == FITNESS_BASELINE_FAILED) {
    if (insideButton(55, 260, 220, 50)) {
      startFitnessBaseline();
      return;
    }

    if (insideButton(295, 260, 180, 50)) {
      resetFitness();
      mode = MODE_HOME;
      return;
    }
  }

  else if (fitnessState == FITNESS_READY) {
    if (insideButton(55, 355, 220, 55)) {
      startFitnessActivity();
      return;
    }

    if (insideButton(295, 355, 220, 55)) {
      startFitnessBaseline();
      return;
    }

    if (insideButton(535, 355, 180, 55)) {
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

// === STRESS CLASSIFIER PARAMETERS (do not modify the calibrations) ===
// For each physiological variable, stressed and calm entry thresholds must
// be at least 1 unit away from the resting average. A small or reversed
// measured response produces a recommendation to repeat calibration.
final float STRESS_MIN_HR_DIFFERENCE = 1.0; // BPM
final float STRESS_MIN_RR_DIFFERENCE = 1.0; // breaths/min
final float STRESS_HYSTERESIS_FRACTION = 0.50;
final int STRESS_TRANSITION_MS = 3000;

// The confirmed code distinguishes ordinary NEUTRAL from disagreement.
// Both appear as NEUTRAL on the physiological-state display.
String stressConfirmedCode = "WAITING";
String stressCandidateCode = "";
int stressCandidateStart = 0;
boolean stressLiveHasHR = false;
boolean stressLiveHasRR = false;
String stressHRIndication = "UNAVAILABLE";
String stressRRIndication = "UNAVAILABLE";

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
  pageHeading("Stress monitoring  /  " + title, "Calibration  /  Rest, stressed and calm reference measurements");
  drawPanel(30, 128, 1040, 323);
  String step = stressState == STRESS_REST_READY ? "01 / 03" :
                stressState == STRESS_STRESS_READY ? "02 / 03" : "03 / 03";
  uiText("CALIBRATION PHASE   " + step, 55, 173, 13, uiBlue, true);
  uiText(title, 55, 222, 29, uiInk, true);
  uiText(instruction, 55, 260, 17, uiMuted, false);
  if (stressState != STRESS_REST_READY) {
    uiText("Resting HR  " + oneDecimal(stressRestHR) + " BPM", 600, 222, 16, uiInk, true);
    uiText("Resting RR  " + oneDecimal(stressRestRR) + " /min", 600, 259, 16, uiInk, true);
  }
  if (stressMessage.length() > 0) uiText(stressMessage, 55, 310, 13, uiRed, true);
  drawModeButton(55, 340, 300, 55, buttonLabel);
  drawModeButton(375, 340, 180, 55, "BACK HOME");
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
  String phase = stressState == STRESS_REST_ACTIVE ? "PHASE 1 OF 3" :
                 stressState == STRESS_STRESS_ACTIVE ? "PHASE 2 OF 3" : "PHASE 3 OF 3";
  pageHeading("Stress monitoring  /  " + title, phase + "  /  Acquisition in progress");
  drawVitals(129, false);
  drawStatusCard(738, 129, 332, 84, "CALIBRATION", "PHASE " +
                 (stressState == STRESS_REST_ACTIVE ? "1 / 3" :
                  stressState == STRESS_STRESS_ACTIVE ? "2 / 3" : "3 / 3"), uiBlue);
  drawCountdownPanel(stressPhaseStart, STRESS_CALIBRATION_TIME, title,
                     "Keep following the instruction until the timer reaches zero.",
                     stressHRCount, stressRRCount);
  drawCalibrationSignals();
}

// SUMMARY AFTER ALL THREE CALIBRATIONS

void drawStressSummary() {
  pageHeading("Stress monitoring  /  Calibration complete", "Three 30-second measurements  /  Ready for live classification");
  drawPanel(30, 130, 1040, 323);
  uiText("CONDITION", 58, 169, 12, uiMuted, true);
  uiText("HEART RATE", 338, 169, 12, uiMuted, true);
  uiText("RESPIRATORY RATE", 643, 169, 12, uiMuted, true);
  stroke(uiLine);
  line(56, 186, 1045, 186);
  uiText("Resting", 58, 224, 19, uiInk, true);
  uiText(oneDecimal(stressRestHR) + " BPM", 338, 224, 19, uiInk, true);
  uiText(oneDecimal(stressRestRR) + " breaths/min", 643, 224, 19, uiInk, true);
  line(56, 245, 1045, 245);
  uiText("Stressed", 58, 284, 19, uiRed, true);
  uiText(oneDecimal(stressStressHR) + " BPM", 338, 284, 19, uiInk, true);
  uiText(oneDecimal(stressStressRR) + " breaths/min", 643, 284, 19, uiInk, true);
  line(56, 305, 1045, 305);
  uiText("Calm", 58, 344, 19, uiGreen, true);
  uiText(oneDecimal(stressCalmHR) + " BPM", 338, 344, 19, uiInk, true);
  uiText(oneDecimal(stressCalmRR) + " breaths/min", 643, 344, 19, uiInk, true);
  drawModeButton(55, 370, 260, 55, "START LIVE DETECTION");
  drawModeButton(335, 370, 230, 55, "REPEAT CALIBRATION");
  drawModeButton(585, 370, 180, 55, "BACK HOME");
  drawStressCalibrationCheck();
}

// Display checks only. The three calibration acquisitions, measured means
// and their validity rules are preserved exactly as in the previous sketch.
boolean stressWeakStressHR() {
  return stressStressHR - stressRestHR < STRESS_MIN_HR_DIFFERENCE;
}
boolean stressWeakCalmHR() {
  return stressRestHR - stressCalmHR < STRESS_MIN_HR_DIFFERENCE;
}
boolean stressWeakStressRR() {
  return stressStressRR - stressRestRR < STRESS_MIN_RR_DIFFERENCE;
}
boolean stressWeakCalmRR() {
  return stressRestRR - stressCalmRR < STRESS_MIN_RR_DIFFERENCE;
}

void drawStressCalibrationCheck() {
  boolean weak = stressWeakStressHR() || stressWeakCalmHR() ||
                 stressWeakStressRR() || stressWeakCalmRR();
  drawPanel(30, 468, 1040, 152);
  uiText(weak ? "CALIBRATION CHECK  /  REPEAT RECOMMENDED" :
                "CALIBRATION CHECK  /  ACCEPTABLE RESPONSE",
         55, 499, 13, weak ? uiAmber : uiGreen, true);
  uiText("Stress HR change: " + oneDecimal(stressStressHR - stressRestHR) + " BPM" +
         (stressWeakStressHR() ? "  /  BELOW 1" : "  /  OK"),
         55, 533, 14, stressWeakStressHR() ? uiAmber : uiInk, true);
  uiText("Calm HR change: " + oneDecimal(stressRestHR - stressCalmHR) + " BPM" +
         (stressWeakCalmHR() ? "  /  BELOW 1" : "  /  OK"),
         553, 533, 14, stressWeakCalmHR() ? uiAmber : uiInk, true);
  uiText("Stress RR change: " + oneDecimal(stressStressRR - stressRestRR) + " /min" +
         (stressWeakStressRR() ? "  /  BELOW 1" : "  /  OK"),
         55, 567, 14, stressWeakStressRR() ? uiAmber : uiInk, true);
  uiText("Calm RR change: " + oneDecimal(stressRestRR - stressCalmRR) + " /min" +
         (stressWeakCalmRR() ? "  /  BELOW 1" : "  /  OK"),
         553, 567, 14, stressWeakCalmRR() ? uiAmber : uiInk, true);
  uiText(weak ? "A weak/reversed response may affect classification. Consider REPEAT CALIBRATION; live thresholds use at least 1 unit." :
                "All differences meet the 1-BPM / 1-breath/min minimum. Live detection uses 3-s persistence and 50% hysteresis.",
         55, 601, 12, uiMuted, false);
}

// === THRESHOLDS FOR LIVE CLASSIFICATION ONLY ===
// Stressed entry: rest + max(1, stressed calibration - rest).
// Calm entry:     rest - max(1, rest - calm calibration).
// The measured calibration averages are never overwritten.
float stressEnterHR() {
  return stressRestHR + max(STRESS_MIN_HR_DIFFERENCE, stressStressHR - stressRestHR);
}
float calmEnterHR() {
  return stressRestHR - max(STRESS_MIN_HR_DIFFERENCE, stressRestHR - stressCalmHR);
}
float stressEnterRR() {
  return stressRestRR + max(STRESS_MIN_RR_DIFFERENCE, stressStressRR - stressRestRR);
}
float calmEnterRR() {
  return stressRestRR - max(STRESS_MIN_RR_DIFFERENCE, stressRestRR - stressCalmRR);
}

// A 50% hysteresis margin corresponds to the midpoint of the effective
// calm/stressed entry thresholds, separately for HR and RR.
float stressMiddle(float calmThreshold, float stressThreshold) {
  return stressThreshold - STRESS_HYSTERESIS_FRACTION *
                           (stressThreshold - calmThreshold);
}

// A recently received serial packet does not guarantee a NEW ECG beat or
// respiratory cycle. The checks below reject old estimated rates without
// changing BPM, RR, their acquisition, or their original validity functions.
boolean stressRecentHR() {
  return validHeartRate() && beat_old > 0 && millis() - beat_old <= 4000;
}
boolean stressRecentRR() {
  if (!validRespRate() || lastBreathTime <= 0 || Tbreath <= 0) return false;
  // At low respiratory rates, allow longer inter-breath intervals.
  float maxAge = constrain(2.0 * Tbreath, 8000, 30000);
  return millis() - lastBreathTime <= maxAge;
}

// A signal is assigned an instantaneous indication using the original entry
// thresholds. Once a state is CONFIRMED, the exit of that state uses the
// hysteresis midpoint. An unconfirmed candidate still requires the original
// entry threshold for the entire three-second persistence period.
String stressVariableIndication(float measured, float calmThreshold,
                                 float stressedThreshold) {
  float middle = stressMiddle(calmThreshold, stressedThreshold);
  if (stressConfirmedCode.equals("STRESSED")) {
    if (measured >= middle) return "STRESSED";
    if (measured <= calmThreshold) return "CALM";
    return "NEUTRAL";
  }
  if (stressConfirmedCode.equals("CALM")) {
    if (measured <= middle) return "CALM";
    if (measured >= stressedThreshold) return "STRESSED";
    return "NEUTRAL";
  }
  if (measured >= stressedThreshold) return "STRESSED";
  if (measured <= calmThreshold) return "CALM";
  return "NEUTRAL";
}

// Either signal alone can trigger Calm or Stressed. Only opposite extreme
// indications (HR Calm + RR Stressed, or vice versa) are ambiguous.
String stressCombinedIndication(String fromHR, String fromRR) {
  boolean hrStress = fromHR.equals("STRESSED");
  boolean rrStress = fromRR.equals("STRESSED");
  boolean hrCalm = fromHR.equals("CALM");
  boolean rrCalm = fromRR.equals("CALM");
  if ((hrStress && rrCalm) || (rrStress && hrCalm)) return "DISAGREEMENT";
  if (hrStress || rrStress) return "STRESSED";
  if (hrCalm || rrCalm) return "CALM";
  return "NEUTRAL";
}

void resetStressCandidate() {
  stressCandidateCode = "";
  stressCandidateStart = 0;
}

void resetStressClassifier() {
  stressConfirmedCode = "WAITING";
  stressLiveState = "WAITING";
  stressLiveHasHR = false;
  stressLiveHasRR = false;
  stressHRIndication = "UNAVAILABLE";
  stressRRIndication = "UNAVAILABLE";
  resetStressCandidate();
}

// LIVE CLASSIFICATION: confirmed state changes only after an unbroken
// three-second candidate interval. This runs in draw(), but its timing is
// based on millis(), not the graphical frame count.
void updateStressLiveState() {
  stressLiveHasHR = stressRecentHR();
  stressLiveHasRR = stressRecentRR();
  stressHRIndication = "UNAVAILABLE";
  stressRRIndication = "UNAVAILABLE";

  if (!stressLiveHasHR && !stressLiveHasRR) {
    resetStressCandidate(); // Invalid/stale signals cannot complete a timer.
    return;                  // Keep last confirmed classification internally.
  }

  if (stressLiveHasHR) {
    stressHRIndication = stressVariableIndication(float(getHeartRate()),
                                                  calmEnterHR(), stressEnterHR());
  }
  if (stressLiveHasRR) {
    stressRRIndication = stressVariableIndication(getRespRate(),
                                                  calmEnterRR(), stressEnterRR());
  }
  String requested = stressCombinedIndication(stressHRIndication, stressRRIndication);
  if (requested.equals(stressConfirmedCode)) {
    resetStressCandidate();
    return;
  }

  int now = millis();
  if (!requested.equals(stressCandidateCode)) {
    stressCandidateCode = requested;
    stressCandidateStart = now;
    return;
  }

  if (now - stressCandidateStart >= STRESS_TRANSITION_MS) {
    stressConfirmedCode = requested;
    stressLiveState = requested.equals("DISAGREEMENT") ? "NEUTRAL" : requested;
    resetStressCandidate();
  }
}

// LIVE MONITORING SCREEN

void drawStressLive() {
  pageHeading("Stress monitoring  /  Live detection", "HR OR RR  /  3-second transitions  /  50% hysteresis  /  Conflicting extremes = Neutral");
  drawVitals(119, false);
  boolean hasAnySignal = stressLiveHasHR || stressLiveHasRR;
  String displayedState = hasAnySignal ? stressLiveState : "NO VALID DATA";
  drawStatusCard(738, 119, 332, 84, "CURRENT PHYSIOLOGICAL STATE",
                 displayedState, colorForStatus(displayedState));
  drawPanel(30, 215, 1040, 37);
  uiText("CALM  HR " + oneDecimal(calmEnterHR()) + "  |  RR " + oneDecimal(calmEnterRR()),
         49, 239, 12, uiGreen, true);
  uiText("STRESS  HR " + oneDecimal(stressEnterHR()) + "  |  RR " + oneDecimal(stressEnterRR()),
         534, 239, 12, uiRed, true);
  drawECGGraph(ecgPlot, 30, 270, 505, 280);
  drawRespGraph(fsrPlot, 565, 270, 505, 280);
  drawModeButton(30, 590, 230, 50, "REPEAT CALIBRATION");
  drawModeButton(280, 590, 200, 50, "END ACTIVITY");

  // Compact feedback panel below the graphs, separate from controls.
  drawPanel(30, 651, 1040, 56);
  String label;
  color labelColor = uiMuted;
  if (!hasAnySignal) {
    label = "No fresh HR/RR estimate - classification paused; previous confirmed state retained.";
  } else if (!stressCandidateCode.equals("")) {
    label = "CANDIDATE: " +
            (stressCandidateCode.equals("DISAGREEMENT") ? "NEUTRAL (HR/RR disagreement)" : stressCandidateCode) +
            "   |   Keep condition for 3 s";
    labelColor = uiBlue;
  } else if (stressConfirmedCode.equals("DISAGREEMENT")) {
    label = "NEUTRAL - HR/RR disagreement confirmed";
    labelColor = uiAmber;
  } else {
    label = "CONFIRMED: " + stressLiveState;
    labelColor = colorForStatus(stressLiveState);
  }
  uiText(label, 52, 673, 12, labelColor, true);
  String quality = "HR " + stressHRIndication + "    /    RR " + stressRRIndication;
  textStyle(NORMAL);
  textSize(11);
  fill(uiMuted);
  textAlign(RIGHT, BASELINE);
  text(quality, 1045, 673);
  textAlign(LEFT, BASELINE);
  noStroke();
  fill(uiLine);
  rect(52, 689, 994, 7, 4);
  if (hasAnySignal && !stressCandidateCode.equals("")) {
    float fraction = constrain((millis() - stressCandidateStart) / float(STRESS_TRANSITION_MS), 0, 1);
    fill(uiBlue);
    rect(52, 689, 994 * fraction, 7, 4);
  }
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
  stressMessage = "";
  resetStressClassifier();
}

// MOUSE INPUT

void stressMousePressed() {
  if (stressState == STRESS_REST_READY ||
      stressState == STRESS_STRESS_READY ||
      stressState == STRESS_CALM_READY) {
    if (insideButton(55, 340, 300, 55)) {
      startStressCalibration();
      return;
    }

    if (insideButton(375, 340, 180, 55)) {
      resetStress();
      mode = MODE_HOME;
      return;
    }
  }

  else if (stressState == STRESS_SUMMARY) {
    if (insideButton(55, 370, 260, 55)) {
      stressState = STRESS_LIVE;
      resetStressClassifier();
      return;
    }

    if (insideButton(335, 370, 230, 55)) {
      resetStress();
      return;
    }

    if (insideButton(585, 370, 180, 55)) {
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
  pageHeading("Meditation mode", "Step 1 of 2  /  Establish a resting respiratory baseline");
  drawInstructions(30, 129, 850, 220, "RESTING BASELINE",
                   "Start with a 30-second resting acquisition",
                   "Sit quietly and breathe normally while the sensors record HR and RR.");
  drawModeButton(55, 255, 240, 55, "START BASELINE");
  drawModeButton(315, 255, 180, 55, "BACK HOME");
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
  pageHeading("Meditation  /  Resting baseline", "Step 1 of 2  /  30-second calibration in progress");
  drawVitals(129, false);
  drawStatusCard(738, 129, 332, 84, "CALIBRATION", "ACQUIRING", uiBlue);
  drawCountdownPanel(meditationBaselineStart, MEDITATION_BASELINE_TIME, "Resting baseline",
                     "Breathe naturally. The session will advance automatically at 0 s.",
                     meditationHRCount, meditationRRCount);
  drawCalibrationSignals();
}

void drawMeditationBaselineFailed() {
  pageHeading("Meditation  /  Baseline not completed", "Calibration  /  Not enough valid HR and RR values");
  drawInstructions(30, 129, 845, 220, "ACQUISITION UNSUCCESSFUL",
                   "Not enough valid HR/RR data collected",
                   "Check the sensor contacts and repeat the baseline.");
  drawModeButton(55, 260, 220, 50, "REPEAT BASELINE");
  drawModeButton(295, 260, 180, 50, "BACK HOME");
}

void drawMeditationReady() {
  pageHeading("Meditation  /  Baseline complete", "Step 2 of 2  /  Follow the breathing pattern below");
  drawMetricCard(30, 139, 245, 94, "Resting HR", oneDecimal(meditationRestHR) + " BPM", uiRed);
  drawMetricCard(291, 139, 245, 94, "Resting RR", oneDecimal(meditationRestRR) + " /min", uiBlue);
  drawPanel(30, 255, 1040, 245);
  uiText("BREATHING TARGET", 55, 289, 13, uiBlue, true);
  uiText("Expiration time = 3 x Inspiration time", 55, 336, 24, uiInk, true);
  uiText("Allowed timing difference: +/-" + oneDecimal(MEDITATION_TOLERANCE) + " s", 55, 373, 14, uiMuted, false);
  drawModeButton(55, 390, 230, 55, "START MEDITATION");
  drawModeButton(305, 390, 220, 55, "REPEAT BASELINE");
  drawModeButton(545, 390, 180, 55, "BACK HOME");
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
  pageHeading("Meditation  /  Live guidance", "Keep the expiration duration approximately three times the inspiration duration");
  drawVitals(119, false);
  String feedback = meditationBadBreaths >= 3 ? "ADJUST BREATHING" : "KEEP BREATHING";
  color feedbackColor = meditationBadBreaths >= 3 ? uiRed : uiGreen;
  drawStatusCard(738, 119, 332, 84, "BREATHING GUIDANCE", feedback, feedbackColor);
  drawPanel(30, 213, 1040, 34);
  uiText("TARGET   Texp = 3 x Tinsp", 48, 236, 12, uiBlue, true);
  uiText("Consecutive breaths outside target: " + meditationBadBreaths,
         558, 236, 12, uiMuted, true);
  drawECGGraph(ecgPlot, 30, 262, 505, 262);
  drawRespGraph(fsrPlot, 565, 262, 505, 262);
  drawReferenceStrip(meditationRestHR, meditationRestRR, 537);
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
    if (insideButton(55, 255, 240, 55)) {
      startMeditationBaseline();
      return;
    }
    if (insideButton(315, 255, 180, 55)) {
      resetMeditation();
      mode = MODE_HOME;
      return;
    }
  } else if (meditationState == MEDITATION_BASELINE_FAILED) {
    if (insideButton(55, 260, 220, 50)) {
      startMeditationBaseline();
      return;
    }
    if (insideButton(295, 260, 180, 50)) {
      resetMeditation();
      mode = MODE_HOME;
      return;
    }
  } else if (meditationState == MEDITATION_READY) {
    if (insideButton(55, 390, 230, 55)) {
      startMeditationSession();
      return;
    }
    if (insideButton(305, 390, 220, 55)) {
      startMeditationBaseline();
      return;
    }
    if (insideButton(545, 390, 180, 55)) {
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
  pageHeading("Section IV  /  Cardiorespiratory patterns", "Step 1 of 2  /  Collect resting HR and breathing-rate references");
  drawInstructions(30, 129, 1000, 225, "REFERENCE ACQUISITION",
                   "Start with a 30-second resting baseline",
                   "HR and RR will be compared with their reference values during monitoring.");
  drawModeButton(55, 255, 240, 55, "START BASELINE");
  drawModeButton(315, 255, 180, 55, "BACK HOME");
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
  pageHeading("Section IV  /  Resting baseline", "Step 1 of 2  /  Calibrating heart and respiratory rates");
  drawVitals(129, false);
  drawStatusCard(738, 129, 332, 84, "CALIBRATION", "ACQUIRING", uiBlue);
  drawCountdownPanel(sectionBaselineStart, SECTION_BASELINE_TIME, "Resting baseline",
                     "Remain relaxed. The next screen appears automatically at 0 s.",
                     sectionHRCount, sectionRRCount);
  drawCalibrationSignals();
}

// BASELINE FAILED

void drawSectionBaselineFailed() {
  pageHeading("Section IV  /  Baseline not completed", "Calibration  /  HR or RR reference unavailable");
  drawInstructions(30, 129, 870, 225, "ACQUISITION UNSUCCESSFUL",
                   "Not enough valid HR/RR data collected",
                   "Check electrode and respiratory sensor contact, then repeat.");
  drawModeButton(55, 260, 220, 50, "REPEAT BASELINE");
  drawModeButton(295, 260, 180, 50, "BACK HOME");
}

// BASELINE COMPLETE

void drawSectionReady() {
  pageHeading("Section IV  /  Baseline complete", "Step 2 of 2  /  Cardiorespiratory monitoring is ready");
  drawMetricCard(30, 130, 248, 91, "Resting HR", oneDecimal(sectionRestHR) + " BPM", uiRed);
  drawMetricCard(294, 130, 248, 91, "Resting RR", oneDecimal(sectionRestRR) + " /min", uiBlue);
  drawPanel(30, 240, 1040, 228);
  uiText("CLASSIFICATION RULES", 55, 272, 13, uiBlue, true);
  uiText("Normal range: +/-10% around resting HR and RR", 55, 314, 18, uiInk, true);
  uiText("A breathing pause is flagged after 10 seconds without a detected complete breath.",
         55, 333, 13, uiMuted, false);
  drawModeButton(55, 350, 250, 55, "START MONITORING");
  drawModeButton(325, 350, 220, 55, "REPEAT BASELINE");
  drawModeButton(565, 350, 180, 55, "BACK HOME");
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
  pageHeading("Section IV  /  Live pattern monitoring", "Heart-rate and breathing classifications with their cardiorespiratory response");
  drawVitals(118, false);
  drawStatusCard(738, 118, 155, 84, "HEART STATE", sectionHeartState,
                 colorForStatus(sectionHeartState));
  drawStatusCard(908, 118, 162, 84, "BREATHING STATE", sectionBreathingState,
                 colorForStatus(sectionBreathingState));
  drawStatusCard(30, 216, 1040, 57, "CARDIORESPIRATORY RESPONSE", sectionResponse,
                 colorForStatus(sectionResponse));
  drawECGGraph(ecgPlot, 30, 290, 505, 245);
  drawRespGraph(fsrPlot, 565, 290, 505, 245);
  drawReferenceStrip(sectionRestHR, sectionRestRR, 548);
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
    if (insideButton(55, 255, 240, 55)) {
      startSectionBaseline();
      return;
    }

    if (insideButton(315, 255, 180, 55)) {
      resetSectionIV();
      mode = MODE_HOME;
      return;
    }
  }

  else if (sectionState == SECTION_BASELINE_FAILED) {
    if (insideButton(55, 260, 220, 50)) {
      startSectionBaseline();
      return;
    }

    if (insideButton(295, 260, 180, 50)) {
      resetSectionIV();
      mode = MODE_HOME;
      return;
    }
  }

  else if (sectionState == SECTION_READY) {
    if (insideButton(55, 350, 250, 55)) {
      startSectionMonitoring();
      return;
    }

    if (insideButton(325, 350, 220, 55)) {
      startSectionBaseline();
      return;
    }

    if (insideButton(565, 350, 180, 55)) {
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
