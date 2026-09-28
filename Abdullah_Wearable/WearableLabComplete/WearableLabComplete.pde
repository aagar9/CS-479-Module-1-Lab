import processing.serial.*;
import java.util.concurrent.ConcurrentLinkedQueue;
// BME/CS 479: both lab modes, one wearer per running sketch.
// Single-file Processing sketch. Upload the companion Arduino sketch
// for measured pulse intervals; legacy firmware shows a labeled estimate.
Serial myPort;
String PORT_NAME = "COM3"; // Select another port on the setup screen.
final int BAUD_RATE = 115200;
boolean serialConnected = false;
int heartRate = 0;
int confidence = 0;
int oxygen = 0;
int sensorStatus = 0;
float beatInterval_ms = 0;
boolean lastSampleValid = false;
int lastSampleTime = 0;
final int STATE_AGE_INPUT = 0;
final int STATE_WAITING_SIGNAL = 1;
final int STATE_SIGNAL_ACQUIRED = 2;
final int STATE_BASELINE = 3;
final int STATE_BASELINE_FAILED = 4;
final int STATE_FITNESS_READY = 5;
final int STATE_FITNESS_ACTIVE = 6;
final int STATE_FITNESS_COMPLETE = 7;
int state = STATE_AGE_INPUT;
String ageText = "";
String ageError = "";
int userAge = 0;
int maxHR = 0;
final int WINDOW_SIZE = 10;
final int MIN_VALID_IN_WINDOW = 7;
boolean[] signalWindow = new boolean[WINDOW_SIZE];
int windowIndex = 0;
int windowCount = 0;
int signalAcquiredTime = 0;
final int SIGNAL_ACQUIRED_DISPLAY_MS = 1500;
final int BASELINE_DURATION_MS = 30000;
final float MIN_BASELINE_QUALITY = 0.70;
final int MIN_BASELINE_SAMPLES = 30;
int baselineStartTime = 0;
int baselineTotalSamples = 0;
int baselineValidSamples = 0;
float baselineHRSum = 0;
float baselineQuality = 0;
float restingHR = 0;
final int ZONE_RECOVERY = 0;
final int ZONE_VERY_LIGHT = 1;
final int ZONE_LIGHT = 2;
final int ZONE_MODERATE = 3;
final int ZONE_HARD = 4;
final int ZONE_MAXIMUM = 5;
final int NUMBER_OF_ZONES = 6;
float[] zoneTimes_s = new float[NUMBER_OF_ZONES];
int activityStartTime = 0;
int activityEndTime = 0;
int previousFitnessSampleTime = 0;
final int MAX_CLASSIFIABLE_INTERVAL_MS = 1500;
int fitnessTotalSamples = 0;
int fitnessValidSamples = 0;
int fitnessInvalidSamples = 0;
float fitnessHRSum = 0;
float averageHR = 0;
float fitnessQuality = 0;
float currentHRPercent = 0;
int currentZone = - 1;
int lastFitnessHR = 0;
int lastFitnessSpO2 = 0;
int lastFitnessConfidence = 0;
float lastFitnessBeatInterval = 0;
float lastFitnessHRPercent = 0;
int lastFitnessZone = - 1;
ArrayList < Float > graphTime = new ArrayList < Float >();
ArrayList < Float > graphHR = new ArrayList < Float >();
ArrayList < Integer > graphZone = new ArrayList < Integer >();
ArrayList < Boolean > graphConnected = new ArrayList < Boolean >();
boolean previousFitnessSampleWasValid = false;
color backgroundColor;
color primaryBlue;
color darkBlue;
color lightBlue;
color veryLightBlue;
color textColor;
color secondaryText;
color successColor;
color warningColor;
color startGreen;
color stopRed;
color whiteColor;
float retryX = 500;
float retryY = 660;
float retryW = 300;
float retryH = 65;
float startX = 450;
float startY = 675;
float startW = 400;
float startH = 70;
float stopX = 1090;
float stopY = 48;
float stopW = 160;
float stopH = 50;
// Initialize the display and discover serial ports without opening a device automatically.
void setup() {
  size(1300, 900);
  backgroundColor = color(244, 248, 252);
  primaryBlue = color(37, 99, 180);
  darkBlue = color(25, 67, 125);
  lightBlue = color(215, 232, 249);
  veryLightBlue = color(234, 243, 252);
  textColor = color(35, 45, 60);
  secondaryText = color(105, 115, 130);
  successColor = color(50, 150, 100);
  warningColor = color(205, 75, 75);
  startGreen = color(45, 160, 95);
  stopRed = color(205, 65, 65);
  whiteColor = color(255);
  surface.setTitle("Wearable Lab - Fitness and Calm / Stress");
  refreshPorts();
  resetSignalWindow();
}

// Process queued samples, update timers, then render the current screen.
void draw() {
  drainSerial();
  updateLab();
  background(backgroundColor);
  switch (state) {
    case STATE_STRESS:
    drawStress();
    break;
    case STATE_AGE_INPUT:
    drawAgeInput();
    break;
    case STATE_WAITING_SIGNAL:
    drawWaitingForSignal();
    break;
    case STATE_SIGNAL_ACQUIRED:
    drawSignalAcquired();
    if (millis() - signalAcquiredTime >= SIGNAL_ACQUIRED_DISPLAY_MS) {
      startBaseline();
    }
    break;
    case STATE_BASELINE:
    drawBaseline();
    if (millis() - baselineStartTime >= BASELINE_DURATION_MS) {
      finishBaseline();
    }
    break;
    case STATE_BASELINE_FAILED:
    drawBaselineFailed();
    break;
    case STATE_FITNESS_READY:
    drawModeMenu();
    break;
    case STATE_FITNESS_ACTIVE:
    drawFitnessDashboard(false);
    break;
    case STATE_FITNESS_COMPLETE:
    drawFitnessDashboard(true);
    break;
  }
  if(showPulse) drawPulseOverlay();
  drawNavigation();
  if (!serialConnected) {
    fill(warningColor);
    textAlign(CENTER, CENTER);
    textSize(15);
    text("Serial connection unavailable - check " + PORT_NAME, width / 2, height - 20);
  }
}

// Serial callbacks only enqueue data; UI and statistics update on draw().
void serialEvent(Serial p) {
  String line = p.readStringUntil('\n');
  if (line != null) {
    if (pendingLines.size() > 2000) { pendingLines.clear(); queueDropped = true; }
    pendingLines.add(new ReceivedLine(line.trim(), millis()));
  }
}

// Maintain the ten-sample signal-quality window.
void addSignalSample(boolean valid) {
  signalWindow[windowIndex] = valid;
  windowIndex++;
  if (windowIndex >= WINDOW_SIZE) {
    windowIndex = 0;
  }
  if (windowCount < WINDOW_SIZE) {
    windowCount++;
  }
}

// Count valid readings in the current acquisition window.
int countValidWindowSamples() {
  int valid = 0;
  for (int i = 0; i < windowCount; i++) {
    if (signalWindow[i]) {
      valid++;
    }
  }
  return valid;
}

// Clear old signal history before acquiring a new baseline.
void resetSignalWindow() {
  for (int i = 0; i < WINDOW_SIZE; i++) {
    signalWindow[i] = false;
  }
  windowIndex = 0;
  windowCount = 0;
}

// Start a fresh 30-second baseline and invalidate old wearer calibrations.
void startBaseline() {
  resetCalibrations();
  baselineCoveredMs = 0;
  previousBaselineTime = 0;
  previousBaselineValid = false;
  baselineStartTime = millis();
  baselineTotalSamples = 0;
  baselineValidSamples = 0;
  baselineHRSum = 0;
  baselineQuality = 0;
  restingHR = 0;
  state = STATE_BASELINE;
}

// Calculate the valid fraction of received baseline readings.
void updateBaselineQuality() {
  if (baselineTotalSamples > 0) {
    baselineQuality = float(baselineValidSamples) / float(baselineTotalSamples);
  } else {
    baselineQuality = 0;
  }
}

// Require both sufficient samples and actual time coverage before accepting baseline.
void finishBaseline() {
  updateBaselineQuality();
  if (baselineQuality >= MIN_BASELINE_QUALITY && baselineValidSamples > 0 && baselineTotalSamples >= MIN_BASELINE_SAMPLES && baselineCoveredMs >= BASELINE_DURATION_MS * MIN_BASELINE_QUALITY) {
    restingHR = baselineHRSum / float(baselineValidSamples);
    state = STATE_FITNESS_READY;
  } else {
    state = STATE_BASELINE_FAILED;
  }
}

// Clear previous fitness results and begin a new timed activity.
void startFitnessSession() {
  activityStartTime = millis();
  activityEndTime = 0;
  previousFitnessSampleTime = 0;
  previousFitnessSampleWasValid = false;
  fitnessTotalSamples = 0;
  fitnessValidSamples = 0;
  fitnessInvalidSamples = 0;
  fitnessHRSum = 0;
  averageHR = 0;
  fitnessQuality = 0;
  currentHRPercent = 0;
  currentZone = - 1;
  lastFitnessHR = 0;
  lastFitnessSpO2 = 0;
  lastFitnessConfidence = 0;
  lastFitnessBeatInterval = 0;
  lastFitnessHRPercent = 0;
  lastFitnessZone = - 1;
  for (int i = 0; i < NUMBER_OF_ZONES; i++) {
    zoneTimes_s[i] = 0;
  }
  graphTime.clear();
  graphHR.clear();
  graphZone.clear();
  graphConnected.clear();
  state = STATE_FITNESS_ACTIVE;
}

// Freeze the activity duration and keep the results available for review.
void stopFitnessSession() {
  activityEndTime = millis();
  state = STATE_FITNESS_COMPLETE;
  notice = "Fitness stopped. Export CSV before starting a new session.";
}

// Update fitness statistics and graph; never count missing-signal gaps as zone time.
void processFitnessSample(int currentSampleTime) {
  fitnessTotalSamples++;
  int deltaTime_ms = 0;
  if (previousFitnessSampleTime > 0) {
    deltaTime_ms = currentSampleTime - previousFitnessSampleTime;
  }
  if (lastSampleValid) {
    fitnessValidSamples++;
    fitnessHRSum += heartRate;
    averageHR = fitnessHRSum / float(fitnessValidSamples);
    currentHRPercent = 100.0 * float(heartRate) / float(maxHR);
    currentZone = classifyZone(currentHRPercent);
    if (previousFitnessSampleWasValid && previousFitnessSampleTime > 0 && deltaTime_ms > 0 && deltaTime_ms <= MAX_CLASSIFIABLE_INTERVAL_MS) {
      float deltaTime_s = deltaTime_ms / 1000.0;
      // Attribute an interval only when both bounding samples are valid.
      zoneTimes_s[lastFitnessZone] += deltaTime_s;
    }
    float elapsedTime_s =(currentSampleTime - activityStartTime) / 1000.0;
    boolean connectPoint = previousFitnessSampleWasValid && deltaTime_ms > 0 && deltaTime_ms <= MAX_CLASSIFIABLE_INTERVAL_MS;
    graphTime.add(elapsedTime_s);
    graphHR.add(float(heartRate));
    graphZone.add(currentZone);
    graphConnected.add(connectPoint);
    lastFitnessHR = heartRate;
    lastFitnessSpO2 = oxygen;
    lastFitnessConfidence = confidence;
    lastFitnessBeatInterval = currentInterval();
    lastFitnessIntervalLabel = intervalLabel();
    lastFitnessHRPercent = currentHRPercent;
    lastFitnessZone = currentZone;
  } else {
    fitnessInvalidSamples++;
    currentZone = - 1;
    currentHRPercent = 0;
  }
  if (fitnessTotalSamples > 0) {
    fitnessQuality = float(fitnessValidSamples) / float(fitnessTotalSamples);
  }
  previousFitnessSampleTime = currentSampleTime;
  previousFitnessSampleWasValid = lastSampleValid;
}

// Classify percentage of estimated maximum HR using the original zone boundaries.
int classifyZone(float percentage) {
  if (percentage < 50.0) {
    return ZONE_RECOVERY;
  } else if (percentage < 60.0) {
    return ZONE_VERY_LIGHT;
  } else if (percentage < 70.0) {
    return ZONE_LIGHT;
  } else if (percentage < 80.0) {
    return ZONE_MODERATE;
  } else if (percentage < 90.0) {
    return ZONE_HARD;
  } else {
    return ZONE_MAXIMUM;
  }
}

// Return elapsed or frozen fitness-session duration.
float getActivityTime_s() {
  if (state == STATE_FITNESS_ACTIVE) {
    return(millis() - activityStartTime) / 1000.0;
  } else if (state == STATE_FITNESS_COMPLETE) {
    return(activityEndTime - activityStartTime) / 1000.0;
  }
  return 0;
}

// Sum valid time assigned to exercise zones.
float getClassifiedTime_s() {
  float total = 0;
  for (int i = 0; i < NUMBER_OF_ZONES; i++) {
    total += zoneTimes_s[i];
  }
  return total;
}

// Draw age input.
void drawAgeInput() {
  drawMainTitle("Wearable Technology Lab", "One device per window - select a port and enter this wearer's age");
  drawPortControls();
  drawCard(350, 190, 600, 390);
  fill(darkBlue);
  textAlign(CENTER, CENTER);
  textSize(28);
  text("Enter your age", width / 2, 255);
  fill(secondaryText);
  textSize(15);
  text("Your age will be used to estimate maximum heart rate.", width / 2, 300);
  fill(veryLightBlue);
  stroke(lightBlue);
  strokeWeight(2);
  rect(500, 355, 300, 90, 18);
  noStroke();
  fill(darkBlue);
  textSize(38);
  String displayedAge = ageText;
  if (displayedAge.length() == 0) {
    fill(secondaryText);
    displayedAge = "Age";
  }
  text(displayedAge, width / 2, 400);
  fill(secondaryText);
  textSize(15);
  text("Type your age and press ENTER", width / 2, 490);
  if (ageError.length() > 0) {
    fill(warningColor);
    textSize(14);
    text(ageError, width / 2, 530);
  }
}

// Draw waiting for signal.
void drawWaitingForSignal() {
  drawMainTitle("Resting Heart Rate Baseline", "Waiting for a stable PPG signal");
  int validWindow = countValidWindowSamples();
  drawMetricCard(80, 180, 340, 160, "CURRENT HEART RATE", isCurrentSignalValid() ? str(heartRate) : "--", "bpm");
  drawMetricCard(480, 180, 340, 160, "OXYGEN SATURATION", isCurrentSignalValid() && oxygen > 0 ? str(oxygen) : "--", "%");
  drawMetricCard(880, 180, 340, 160, "CONFIDENCE", isCurrentSignalValid() ? str(confidence) : "--", "%");
  drawCard(80, 390, 1140, 250);
  fill(darkBlue);
  textAlign(LEFT, CENTER);
  textSize(21);
  text("Signal acquisition", 125, 435);
  if (isCurrentSignalValid()) {
    fill(successColor);
    textSize(16);
    text("Valid signal detected", 125, 480);
  } else {
    fill(warningColor);
    textSize(16);
    text("No valid signal - keep your finger still on the sensor", 125, 480);
  }
  fill(textColor);
  textSize(18);
  text("Valid samples in recent window: " + validWindow + " / " + WINDOW_SIZE, 125, 530);
  fill(secondaryText);
  textSize(14);
  text("Baseline starts when at least 7 of the last 10 samples are valid and the latest sample is valid.", 125, 575);
  drawSignalWindowBar(125, 605, 1030, 16, validWindow);
}

// Draw signal acquired.
void drawSignalAcquired() {
  drawMainTitle("Resting Heart Rate Baseline", "Signal check");
  drawCard(340, 190, 620, 370);
  fill(successColor);
  textAlign(CENTER, CENTER);
  textSize(36);
  text("Signal acquired", width / 2, 290);
  fill(textColor);
  textSize(23);
  text("Current HR: " + heartRate + " bpm", width / 2, 365);
  fill(secondaryText);
  textSize(16);
  text("Starting 30-second resting baseline...", width / 2, 430);
  drawSimpleProgress(430, 490, 440, 16, constrain(float(millis() - signalAcquiredTime) / float(SIGNAL_ACQUIRED_DISPLAY_MS), 0, 1));
}

// Draw baseline.
void drawBaseline() {
  drawMainTitle("Resting Heart Rate Baseline", "30-second acquisition");
  drawMetricCard(60, 155, 270, 150, "CURRENT HR", isCurrentSignalValid() ? str(heartRate) : "--", "bpm");
  drawMetricCard(365, 155, 270, 150, intervalLabel(), intervalText(), "ms");
  drawMetricCard(670, 155, 270, 150, "SpO2", isCurrentSignalValid() && oxygen > 0 ? str(oxygen) : "--", "%");
  drawMetricCard(975, 155, 270, 150, "CONFIDENCE", isCurrentSignalValid() ? str(confidence) : "--", "%");
  drawCard(60, 350, 1185, 320);
  float elapsed = constrain(millis() - baselineStartTime, 0, BASELINE_DURATION_MS);
  float elapsedSeconds = elapsed / 1000.0;
  float progress = elapsed / float(BASELINE_DURATION_MS);
  fill(darkBlue);
  textAlign(LEFT, CENTER);
  textSize(22);
  text("Baseline acquisition", 105, 400);
  fill(textColor);
  textAlign(RIGHT, CENTER);
  textSize(18);
  text(nf(elapsedSeconds, 0, 1) + " / 30.0 s", 1200, 400);
  drawSimpleProgress(105, 445, 1095, 20, progress);
  textAlign(LEFT, CENTER);
  if (isCurrentSignalValid()) {
    fill(successColor);
    textSize(17);
    text("Signal: valid", 105, 520);
  } else {
    fill(warningColor);
    textSize(17);
    text("Signal temporarily lost - invalid samples are ignored", 105, 520);
  }
  fill(textColor);
  text("Signal quality: " + nf(baselineQuality * 100.0, 0, 1) + "%", 105, 565);
  fill(secondaryText);
  text("Valid samples: " + baselineValidSamples + " / " + baselineTotalSamples, 105, 610);
  textAlign(RIGHT, CENTER);
  text("Minimum required quality: 70%", 1200, 565);
}

// Draw baseline failed.
void drawBaselineFailed() {
  drawMainTitle("Resting Heart Rate Baseline", "Acquisition problem");
  drawCard(300, 155, 700, 555);
  fill(warningColor);
  textAlign(CENTER, CENTER);
  textSize(32);
  text("Acquisition not valid", width / 2, 235);
  fill(textColor);
  textSize(19);
  text("Signal quality: " + nf(baselineQuality * 100.0, 0, 1) + "%", width / 2, 315);
  fill(secondaryText);
  textSize(16);
  if (baselineTotalSamples < MIN_BASELINE_SAMPLES) {
    text("Too few samples were received during the 30-second acquisition.", width / 2, 380);
  } else {
    text("Signal quality or time coverage was below 70%.", width / 2, 380);
  }
  text("Please reposition your finger and retry the measurement.", width / 2, 425);
  fill(primaryBlue);
  noStroke();
  rect(retryX, retryY, retryW, retryH, 18);
  fill(whiteColor);
  textSize(19);
  text("RETRY", retryX + retryW / 2, retryY + retryH / 2);
}

// Draw fitness ready.
void drawFitnessReady() {
  drawMainTitle("Fitness Mode", "Baseline acquired - ready to begin");
  drawCard(70, 155, 560, 450);
  fill(darkBlue);
  textAlign(CENTER, CENTER);
  textSize(23);
  text("Baseline summary", 350, 205);
  fill(successColor);
  textSize(49);
  text(nf(restingHR, 0, 1), 350, 295);
  fill(secondaryText);
  textSize(16);
  text("Resting heart rate (bpm)", 350, 345);
  fill(textColor);
  textSize(18);
  text("Baseline quality: " + nf(baselineQuality * 100.0, 0, 1) + "%", 350, 420);
  text("Estimated HRmax: " + maxHR + " bpm", 350, 465);
  text("Age: " + userAge + " years", 350, 510);
  drawCard(670, 155, 560, 450);
  fill(darkBlue);
  textSize(23);
  text("Live signal", 950, 205);
  if (isCurrentSignalValid()) {
    fill(successColor);
    textSize(46);
    text(heartRate, 950, 285);
    fill(secondaryText);
    textSize(16);
    text("Current HR (bpm)", 950, 330);
    fill(textColor);
    textSize(17);
    text("Beat interval: " + nf(beatInterval_ms, 0, 0) + " ms", 950, 405);
    text("SpO2: " + oxygen + "%", 950, 450);
    text("Confidence: " + confidence + "%", 950, 495);
  } else {
    fill(warningColor);
    textSize(31);
    text("SIGNAL LOST", 950, 320);
    fill(secondaryText);
    textSize(16);
    text("You may still start the session,", 950, 400);
    text("or wait until HR is detected again.", 950, 430);
  }
  fill(startGreen);
  noStroke();
  rect(startX, startY, startW, startH, 20);
  fill(whiteColor);
  textAlign(CENTER, CENTER);
  textSize(21);
  text("START FITNESS SESSION", startX + startW / 2, startY + startH / 2);
}

// Draw fitness dashboard.
void drawFitnessDashboard(boolean completed) {
  String subtitle;
  if (completed) {
    subtitle = "Session complete";
  } else {
    subtitle = "Live exercise monitoring";
  }
  drawMainTitle("Fitness Mode", subtitle);
  if (!completed) {
    fill(stopRed);
    noStroke();
    rect(stopX, stopY, stopW, stopH, 16);
    fill(whiteColor);
    textAlign(CENTER, CENTER);
    textSize(18);
    text("STOP", stopX + stopW / 2, stopY + stopH / 2);
  }
  float cardY = 125;
  float cardW = 190;
  float cardH = 115;
  float gap = 12;
  float x1 = 40;
  float x2 = x1 + cardW + gap;
  float x3 = x2 + cardW + gap;
  float x4 = x3 + cardW + gap;
  float x5 = x4 + cardW + gap;
  float x6 = x5 + cardW + gap;
  String currentHRText;
  if (completed) {
    currentHRText = lastFitnessHR > 0 ? str(lastFitnessHR) : "--";
  } else {
    currentHRText = isCurrentSignalValid() ? str(heartRate) : "--";
  }
  drawMetricCard(x1, cardY, cardW, cardH, completed ? "LAST HR" : "CURRENT HR", currentHRText, "bpm");
  drawMetricCard(x2, cardY, cardW, cardH, "RESTING HR", nf(restingHR, 0, 1), "bpm");
  drawMetricCard(x3, cardY, cardW, cardH, "AVERAGE HR", fitnessValidSamples > 0 ? nf(averageHR, 0, 1) : "--", "bpm");
  float shownBeatInterval;
  if (completed) {
    shownBeatInterval = lastFitnessBeatInterval;
  } else {
    shownBeatInterval = currentInterval();
  }
  drawMetricCard(x4, cardY, cardW, cardH, (completed ? lastFitnessIntervalLabel : intervalLabel()), shownBeatInterval > 0 ? nf(shownBeatInterval, 0, 0) : "--", "ms");
  int shownSpO2 = completed ? lastFitnessSpO2 : (isCurrentSignalValid() ? oxygen : 0);
  drawMetricCard(x5, cardY, cardW, cardH, "SpO2", shownSpO2 > 0 ? str(shownSpO2) : "--", "%");
  int shownConfidence = completed ? lastFitnessConfidence : (isCurrentSignalValid() ? confidence : 0);
  drawMetricCard(x6, cardY, cardW, cardH, "CONFIDENCE", str(shownConfidence), "%");
  if (!completed && !isCurrentSignalValid()) {
    fill(warningColor);
    textAlign(CENTER, CENTER);
    textSize(17);
    text("SIGNAL LOST - graph and zone timing temporarily paused", 650, 258);
  }
  drawFitnessGraph(40, 285, 845, 480);
  drawFitnessStatistics(910, 285, 350, 480, completed);
}

// Draw fitness graph.
void drawFitnessGraph(float panelX, float panelY, float panelW, float panelH) {
  drawCard(panelX, panelY, panelW, panelH);
  float graphX = panelX + 65;
  float graphY = panelY + 45;
  float graphW = panelW - 95;
  float graphH = panelH - 100;
  float activityTime = getActivityTime_s();
  float xMax = max(10.0, ceil(activityTime / 10.0) * 10.0);
  float yMin = 30.0;
  float maxMeasuredHR = getMaximumGraphHR();
  float yMax = max(120.0, max(maxHR * 1.05, maxMeasuredHR + 10.0));
  drawZoneBand(graphX, graphY, graphW, graphH, yMin, maxHR * 0.50, getZoneColor(ZONE_RECOVERY), yMin, yMax);
  drawZoneBand(graphX, graphY, graphW, graphH, maxHR * 0.50, maxHR * 0.60, getZoneColor(ZONE_VERY_LIGHT), yMin, yMax);
  drawZoneBand(graphX, graphY, graphW, graphH, maxHR * 0.60, maxHR * 0.70, getZoneColor(ZONE_LIGHT), yMin, yMax);
  drawZoneBand(graphX, graphY, graphW, graphH, maxHR * 0.70, maxHR * 0.80, getZoneColor(ZONE_MODERATE), yMin, yMax);
  drawZoneBand(graphX, graphY, graphW, graphH, maxHR * 0.80, maxHR * 0.90, getZoneColor(ZONE_HARD), yMin, yMax);
  drawZoneBand(graphX, graphY, graphW, graphH, maxHR * 0.90, yMax, getZoneColor(ZONE_MAXIMUM), yMin, yMax);
  stroke(150, 160, 175);
  strokeWeight(1);
  line(graphX, graphY, graphX, graphY + graphH);
  line(graphX, graphY + graphH, graphX + graphW, graphY + graphH);
  fill(secondaryText);
  textAlign(RIGHT, CENTER);
  textSize(11);
  int firstYTick = int(ceil(yMin / 20.0) * 20);
  for (int hrTick = firstYTick; hrTick <= yMax; hrTick += 20) {
    float py = map(hrTick, yMin, yMax, graphY + graphH, graphY);
    stroke(215, 220, 225);
    line(graphX, py, graphX + graphW, py);
    noStroke();
    fill(secondaryText);
    text(hrTick, graphX - 8, py);
  }
  textAlign(CENTER, TOP);
  for (int i = 0; i <= 4; i++) {
    float t = xMax * i / 4.0;
    float px = map(t, 0, xMax, graphX, graphX + graphW);
    stroke(215, 220, 225);
    line(px, graphY, px, graphY + graphH);
    noStroke();
    fill(secondaryText);
    text(nf(t, 0, 0), px, graphY + graphH + 8);
  }
  fill(textColor);
  textAlign(LEFT, CENTER);
  textSize(13);
  text("Heart rate (bpm)", graphX, panelY + 20);
  textAlign(CENTER, CENTER);
  text("Activity time (s)", graphX + graphW / 2, panelY + panelH - 20);
  strokeWeight(3);
  for (int i = 0; i < graphTime.size(); i++) {
    float currentTime = graphTime.get(i);
    float currentHR = graphHR.get(i);
    float px = map(currentTime, 0, xMax, graphX, graphX + graphW);
    float py = map(currentHR, yMin, yMax, graphY + graphH, graphY);
    int zone = graphZone.get(i);
    color zoneColor = getZoneColor(zone);
    if (i > 0 && graphConnected.get(i)) {
      float previousTime = graphTime.get(i - 1);
      float previousHR = graphHR.get(i - 1);
      float previousPX = map(previousTime, 0, xMax, graphX, graphX + graphW);
      float previousPY = map(previousHR, yMin, yMax, graphY + graphH, graphY);
      stroke(zoneColor);
      line(previousPX, previousPY, px, py);
    }
    noStroke();
    fill(zoneColor);
    ellipse(px, py, 5, 5);
  }
  noStroke();
}

// Draw fitness statistics.
void drawFitnessStatistics(float x, float y, float w, float h, boolean completed) {
  drawCard(x, y, w, h);
  int shownZone;
  float shownPercent;
  if (completed) {
    shownZone = lastFitnessZone;
    shownPercent = lastFitnessHRPercent;
  } else if (isCurrentSignalValid()) {
    shownZone = currentZone;
    shownPercent = currentHRPercent;
  } else {
    shownZone = - 1;
    shownPercent = 0;
  }
  textAlign(CENTER, CENTER);
  if (shownZone >= 0) {
    fill(getZoneColor(shownZone));
    textSize(23);
    text(getZoneName(shownZone), x + w / 2, y + 42);
    fill(secondaryText);
    textSize(14);
    text(nf(shownPercent, 0, 1) + "% HRmax", x + w / 2, y + 72);
  } else {
    fill(warningColor);
    textSize(21);
    text(completed ? "NO VALID FINAL HR" : "SIGNAL LOST", x + w / 2, y + 52);
  }
  fill(textColor);
  textAlign(LEFT, CENTER);
  textSize(15);
  text("Activity time", x + 25, y + 112);
  textAlign(RIGHT, CENTER);
  text(formatTime(getActivityTime_s()), x + w - 25, y + 112);
  textAlign(LEFT, CENTER);
  text("Classified time", x + 25, y + 142);
  textAlign(RIGHT, CENTER);
  text(formatTime(getClassifiedTime_s()), x + w - 25, y + 142);
  textAlign(LEFT, CENTER);
  text("Signal quality", x + 25, y + 172);
  textAlign(RIGHT, CENTER);
  text(nf(fitnessQuality * 100.0, 0, 1) + "%", x + w - 25, y + 172);
  stroke(225, 230, 235);
  line(x + 25, y + 198, x + w - 25, y + 198);
  noStroke();
  float zoneStartY = y + 225;
  float zoneSpacing = 40;
  for (int zone = 0; zone < NUMBER_OF_ZONES; zone++) {
    float currentY = zoneStartY + zone * zoneSpacing;
    color zColor = getZoneColor(zone);
    fill(zColor);
    rect(x + 25, currentY - 7, 12, 12, 3);
    fill(textColor);
    textAlign(LEFT, CENTER);
    textSize(13);
    text(getZoneName(zone), x + 48, currentY);
    textAlign(RIGHT, CENTER);
    text(formatTime(zoneTimes_s[zone]), x + w - 25, currentY);
  }
}

// Draw zone band.
void drawZoneBand(float x, float y, float w, float h, float lowHR, float highHR, color zoneColor, float yMin, float yMax) {
  float low = max(lowHR, yMin);
  float high = min(highHR, yMax);
  if (high <= low) {
    return;
  }
  float top = map(high, yMin, yMax, y + h, y);
  float bottom = map(low, yMin, yMax, y + h, y);
  noStroke();
  fill(zoneColor, 32);
  rect(x, top, w, bottom - top);
}

// Return get maximum graph h r.
float getMaximumGraphHR() {
  float maxValue = restingHR;
  for (int i = 0; i < graphHR.size(); i++) {
    if (graphHR.get(i) > maxValue) {
      maxValue = graphHR.get(i);
    }
  }
  return maxValue;
}

// Return get zone color.
color getZoneColor(int zone) {
  switch (zone) {
    case ZONE_RECOVERY:
    return color(145, 155, 165);
    case ZONE_VERY_LIGHT:
    return color(175, 185, 195);
    case ZONE_LIGHT:
    return color(70, 155, 220);
    case ZONE_MODERATE:
    return color(55, 165, 100);
    case ZONE_HARD:
    return color(235, 160, 40);
    case ZONE_MAXIMUM:
    return color(215, 70, 70);
  }
  return secondaryText;
}

// Return get zone name.
String getZoneName(int zone) {
  switch (zone) {
    case ZONE_RECOVERY:
    return "Recovery / Below zone";
    case ZONE_VERY_LIGHT:
    return "Very Light";
    case ZONE_LIGHT:
    return "Light";
    case ZONE_MODERATE:
    return "Moderate";
    case ZONE_HARD:
    return "Hard";
    case ZONE_MAXIMUM:
    return "Maximum";
  }
  return "Unknown";
}

// Return format time.
String formatTime(float seconds) {
  int totalSeconds = int(seconds);
  int minutes = totalSeconds / 60;
  int remainingSeconds = totalSeconds % 60;
  return nf(minutes, 2) + ":" + nf(remainingSeconds, 2);
}

// Accept age input; E exports data from measurement screens.
void keyPressed() {
  if (state != STATE_AGE_INPUT) {
    if (key == 'e' || key == 'E') exportData();
    return;
  }
  if (key >= '0' && key <= '9') {
    if (ageText.length() < 3) {
      ageText += key;
    }
    ageError = "";
  } else if (key == BACKSPACE) {
    if (ageText.length() > 0) {
      ageText = ageText.substring(0, ageText.length() - 1);
    }
  } else if (key == ENTER || key == RETURN) {
    if (ageText.length() == 0) {
      ageError = "Please enter a valid age.";
      return;
    }
    int enteredAge = int(ageText);
    if (enteredAge < 1 || enteredAge > 120) {
      ageError = "Please enter an age between 1 and 120.";
      return;
    }
    if (!serialConnected) { ageError = "Connect a serial port first."; return; }
    userAge = enteredAge;
    maxHR = 220 - userAge;
    resetSignalWindow();
    state = STATE_WAITING_SIGNAL;
  }
}

// Dispatch setup, mode, calibration, and fitness controls.
void mousePressed() {
  if (handleLabClick()) return;
  if (state == STATE_BASELINE_FAILED) {
    if (mouseX >= retryX && mouseX <= retryX + retryW && mouseY >= retryY && mouseY <= retryY + retryH) {
      resetSignalWindow();
      baselineTotalSamples = 0;
      baselineValidSamples = 0;
      baselineHRSum = 0;
      baselineQuality = 0;
      state = STATE_WAITING_SIGNAL;
    }
  } else if (state == STATE_FITNESS_READY) {
    if (mouseX >= startX && mouseX <= startX + startW && mouseY >= startY && mouseY <= startY + startH) {
      startFitnessSession();
    }
  } else if (state == STATE_FITNESS_ACTIVE) {
    if (mouseX >= stopX && mouseX <= stopX + stopW && mouseY >= stopY && mouseY <= stopY + stopH) {
      stopFitnessSession();
    }
  }
}

// Reject missing contact, weak confidence, invalid values, and stale readings.
boolean isCurrentSignalValid() {
  boolean dataFresh = millis() - lastSampleTime < 1500;
  return lastSampleValid && dataFresh;
}

// Draw main title.
void drawMainTitle(String title, String subtitle) {
  fill(darkBlue);
  textAlign(LEFT, CENTER);
  textSize(30);
  text(title, 50, 55);
  fill(secondaryText);
  textSize(15);
  text(subtitle, 50, 92);
  if (state != STATE_AGE_INPUT) {
    textAlign(RIGHT, CENTER);
    fill(textColor);
    textSize(14);
    text("Age: " + userAge + "    |    Estimated HRmax: " + maxHR + " bpm", 1045, 65);
  }
}

// Draw card.
void drawCard(float x, float y, float w, float h) {
  noStroke();
  fill(whiteColor);
  rect(x, y, w, h, 20);
}

// Draw metric card.
void drawMetricCard(float x, float y, float w, float h, String label, String value, String unit) {
  drawCard(x, y, w, h);
  fill(secondaryText);
  textAlign(CENTER, CENTER);
  textSize(12);
  text(label, x + w / 2, y + 26);
  fill(darkBlue);
  textSize(31);
  text(value, x + w / 2, y + h / 2 + 4);
  fill(secondaryText);
  textSize(13);
  text(unit, x + w / 2, y + h - 22);
}

// Draw simple progress.
void drawSimpleProgress(float x, float y, float w, float h, float progress) {
  progress = constrain(progress, 0, 1);
  noStroke();
  fill(lightBlue);
  rect(x, y, w, h, h / 2);
  fill(primaryBlue);
  rect(x, y, w * progress, h, h / 2);
}

// Draw signal window bar.
void drawSignalWindowBar(float x, float y, float w, float h, int validCount) {
  float progress = float(validCount) / float(MIN_VALID_IN_WINDOW);
  progress = constrain(progress, 0, 1);
  drawSimpleProgress(x, y, w, h, progress);
}

// Connection, parsing, mode navigation, and export. No simulated readings are used.
final int STATE_STRESS = 8;
final int MIN_CONFIDENCE = 50; // Project quality threshold; adjustable after testing.
ConcurrentLinkedQueue<ReceivedLine> pendingLines = new ConcurrentLinkedQueue<ReceivedLine>();
volatile boolean queueDropped = false;
String[] ports = new String[0];
int portIndex = 0, previousBaselineTime = 0, lastMetricTime = -1000;
float baselineCoveredMs = 0;
boolean previousBaselineValid = false, rawFirmware = false;
String notice = "", lastFitnessIntervalLabel = "EST. INTERVAL";
String buzzerStatus="Not tested";
boolean buzzerPending=false;
int buzzerSentAt=0;
ArrayList<String> recorded = new ArrayList<String>();

class ReceivedLine {
  String text; int time;
  ReceivedLine(String value, int timestamp) { text = value; time = timestamp; }
}

// Refresh the list without taking control of any port.
void refreshPorts() {
  ports = Serial.list(); portIndex = 0;
  for (int i=0; i<ports.length; i++) if (ports[i].equals(PORT_NAME)) portIndex=i;
  if (ports.length>0) PORT_NAME=ports[portIndex];
}

// Connect on request, allowing two sketch instances to select different devices.
void connectPort() {
  if (myPort != null) { try { myPort.stop(); } catch(Exception e) {} }
  serialConnected=false; lastSampleValid=false; rawFirmware=false;
  buzzerPending=false; buzzerStatus="Not tested";
  pendingLines.clear(); resetPulse(); lastMetricTime=-1000; resetSignalWindow();
  try {
    myPort=new Serial(this, PORT_NAME, BAUD_RATE);
    myPort.clear(); myPort.bufferUntil('\n'); serialConnected=true;
    notice="Port open. Waiting for sensor data.";
  } catch(Exception e) { notice="Cannot open "+PORT_NAME+". Close Serial Monitor or other users of this port."; }
}

// Drain on the drawing thread so graph lists are never mutated while drawing.
void drainSerial() {
  if (queueDropped) { resetPulse(); resetSignalWindow(); clearSmooth(); queueDropped=false; }
  ReceivedLine item;
  while ((item=pendingLines.poll()) != null) {
    if (millis()-item.time > 1500) { resetPulse(); clearSmooth(); continue; }
    parseLine(item.text,item.time);
  }
}

// Accept the original labeled protocol and the companion firmware's raw packets.
void parseLine(String line, int receivedAt) {
  try {
    if (line.startsWith("PPG,")) {
      String[] f=split(line, ',');
      if(f.length!=9) return;
      long deviceTime=Long.parseLong(f[1]);
      float ir=Float.parseFloat(f[2]);
      float hr=Float.parseFloat(f[4]), spo2=Float.parseFloat(f[6]);
      int conf=Integer.parseInt(f[5]), status=Integer.parseInt(f[7]);
      if(!Float.isFinite(ir) || !Float.isFinite(hr) || !Float.isFinite(spo2)) return;
      rawFirmware=true;
      boolean valid=qualityValid(round(hr),conf,status);
      processPulse(ir, deviceTime, valid && f[8].equals("1"), receivedAt);
      // Raw PPG is processed at full speed; lab statistics remain at about 2 Hz.
      if(receivedAt-lastMetricTime>=500) {
        lastMetricTime=receivedAt;
        acceptMetrics(round(hr),conf,round(spo2),status,receivedAt);
      }
      return;
    }
    String[] v=match(line,"^Heartrate:\\s*(\\d+)\\s*bpm\\s*\\|\\s*Confidence:\\s*(\\d+)\\s*%\\s*\\|\\s*Oxygen:\\s*(\\d+)\\s*%\\s*\\|\\s*Status:\\s*(\\d+)\\s*$");
    if(v!=null) {
      rawFirmware=false;
      acceptMetrics(Integer.parseInt(v[1]),Integer.parseInt(v[2]),Integer.parseInt(v[3]),Integer.parseInt(v[4]),receivedAt);
    } else if(line.equals("BUZZER started")) {
      buzzerStatus="Board started tone"; notice="Board received the buzzer command and started its tone routine.";
    } else if(line.equals("BUZZER complete")) {
      buzzerPending=false; buzzerStatus="Board finished tone";
      notice="Board completed the double-beep routine. If silent, check D12/GND wiring and the buzzer.";
    } else if(line.startsWith("ERROR") || line.startsWith("READY")) {
      notice=line;
      // A sensor fault/restart breaks waveform continuity even if the board's
      // millisecond clock continues. Hide old values until valid samples return.
      if(line.startsWith("ERROR FIFO") || line.startsWith("ERROR sensor") || line.startsWith("READY raw PPG")) {
        lastSampleValid=false; resetPulse(); clearSmooth(); resetSignalWindow(); candidate=-1;
      }
    }
  } catch(NumberFormatException e) { /* Ignore truncated/malformed packets. */ }
}

// A quality gate improves on the original HR > 0 rule; SpO2 is checked separately.
boolean qualityValid(int hr,int conf,int status) {
  return hr>=30 && hr<=240 && conf>=MIN_CONFIDENCE && conf<=100 && status==3;
}

// Route one biometric update to the active evaluation section.
void acceptMetrics(int hr,int conf,int spo2,int status,int now) {
  int gap=now-lastSampleTime;
  if(gap>1500) { resetSignalWindow(); clearSmooth(); candidate=-1; }
  heartRate=hr; confidence=conf; oxygen=(spo2>0 && spo2<=100)?spo2:0;
  sensorStatus=status; lastSampleTime=now; lastSampleValid=qualityValid(hr,conf,status);
  beatInterval_ms=rawFirmware ? currentInterval() : (lastSampleValid ? 60000.0/hr : 0);
  if(state==STATE_WAITING_SIGNAL) {
    addSignalSample(lastSampleValid);
    if(windowCount==WINDOW_SIZE && countValidWindowSamples()>=MIN_VALID_IN_WINDOW && lastSampleValid) {
      state=STATE_SIGNAL_ACQUIRED; signalAcquiredTime=now;
    }
  } else if(state==STATE_BASELINE && now-baselineStartTime<=BASELINE_DURATION_MS) {
    baselineTotalSamples++;
    if(lastSampleValid) { baselineValidSamples++; baselineHRSum+=hr; }
    int dt=now-previousBaselineTime;
    if(lastSampleValid && previousBaselineValid && previousBaselineTime>0 && dt>0 && dt<=1500) baselineCoveredMs+=dt;
    previousBaselineTime=now; previousBaselineValid=lastSampleValid; updateBaselineQuality();
  } else if(state==STATE_FITNESS_ACTIVE) processFitnessSample(now);
  else if(state==STATE_STRESS) processStress(now);
  if(state==STATE_BASELINE || state==STATE_FITNESS_ACTIVE || state==STATE_STRESS) {
    recorded.add(now+","+state+","+hr+","+spo2+","+conf+","+status+","+lastSampleValid+","+
      currentInterval()+","+intervalLabel()+","+restingHR+","+currentZone+","+stressPhase+","+mood+","+smoothHR);
  }
}

// Invalidate stale pulse intervals and unconfirmed stress candidates promptly.
void updateLab() {
  if(buzzerPending && millis()-buzzerSentAt>=3000) {
    buzzerPending=false; buzzerStatus="No board confirmation";
    notice="No buzzer acknowledgment. Check uploaded firmware and return serial path; older sketches do not acknowledge.";
  }
  if(!isCurrentSignalValid()) {
    candidate=-1;
    if(state==STATE_STRESS) clearSmooth();
  }
  if(state==STATE_STRESS && stressPhase==STRESS_CAL && millis()-calStart>=60000) finishCalibration();
}

// Show the source of the interval explicitly; never pass a BPM-derived estimate off as measured.
String intervalLabel() { return rawFirmware ? "PULSE INTERVAL" : "EST. INTERVAL"; }
float currentInterval() {
  if(!isCurrentSignalValid()) return 0;
  if(!rawFirmware) return heartRate>0 ? 60000.0/heartRate : 0;
  return millis()-lastBeatReceived<2500 ? measuredInterval : 0;
}
String intervalText() { float value=currentInterval(); return value>0 ? str(round(value)) : "--"; }

// Shared button drawing and hit-testing for the added screens.
void button(String label,float x,float y,float w,float h,boolean enabled) {
  fill(enabled?primaryBlue:color(180,190,200)); noStroke(); rect(x,y,w,h,10);
  fill(255); textAlign(CENTER,CENTER); textSize(16); text(label,x+w/2,y+h/2);
}
boolean hit(float x,float y,float w,float h) { return mouseX>=x && mouseX<=x+w && mouseY>=y && mouseY<=y+h; }

// Select a COM port before connecting; a second instance uses another port.
void drawPortControls() {
  button("Next port",50,125,140,42,!serialConnected);
  button("Refresh",200,125,120,42,!serialConnected);
  button(serialConnected?"Reconnect":"Connect",850,125,150,42,true);
  fill(textColor); textAlign(CENTER,CENTER); textSize(17);
  text(ports.length>0?PORT_NAME:"No serial ports found",575,146);
  button("Test buzzer",1020,125,220,42,serialConnected && !buzzerPending);
  textSize(15); text("Buzzer: "+buzzerStatus,650,620);
}

// Both modes share the wearer baseline; fitness and stress histories remain separate.
void drawModeMenu() {
  drawMainTitle("Choose an evaluation mode", "Both modes are available for each wearable device");
  drawMetricCard(50,135,280,130,"RESTING HR",nf(restingHR,0,1),"bpm");
  drawMetricCard(355,135,280,130,"CURRENT HR",isCurrentSignalValid()?str(heartRate):"--","bpm");
  drawMetricCard(660,135,280,130,"SpO2",isCurrentSignalValid() && oxygen>0?str(oxygen):"--","%");
  drawMetricCard(965,135,280,130,intervalLabel(),intervalText(),"ms");
  drawCard(50,315,570,350); drawCard(660,315,585,350);
  fill(darkBlue); textAlign(LEFT,TOP); textSize(26);
  text("Section I - Fitness",80,350); text("Section II - Calm / Stressed",690,350);
  fill(textColor); textSize(18);
  text("Exercise zones based on 220 - age\nColor-coded heart-rate graph\nActivity time and time in each zone",80,410);
  text("Play calming music and record calibration\nRecall stress for at least 60 seconds\nDetect changes and send two buzzer beeps",690,410);
  button("Start fitness",80,565,250,55,true);
  button("Open calm / stress",690,565,280,55,true);
  fill(secondaryText); textSize(15); textAlign(LEFT,TOP);
  text("Return to rest before calm/stress calibration after exercise. Re-record baseline if needed.",60,700);
  text(rawFirmware?"Pulse intervals are detected from raw PPG; verify the peaks on the pulse trace.":
    "Legacy Arduino data: interval is estimated from BPM. Upload the companion sketch for detected pulse intervals.",60,735);
}

// Footer controls remain outside the original graph/card area.
void drawNavigation() {
  if(state>=STATE_FITNESS_READY) {
    button("Modes",40,790,125,40,true); button("Export CSV",180,790,150,40,true);
    button("New baseline",345,790,170,40,state!=STATE_FITNESS_ACTIVE && !(state==STATE_STRESS && stressPhase!=STRESS_READY));
    button(showPulse?"Close pulse trace":"Pulse trace",530,790,180,40,true);
    button("Test buzzer",725,790,165,40,serialConnected && !buzzerPending);
  }
  fill(secondaryText); textAlign(LEFT,CENTER); textSize(13);
  text(notice,40,852);
  if(serialConnected) text(PORT_NAME+" | "+(isCurrentSignalValid()?"Signal valid":"Waiting / weak signal")+" | confidence threshold "+MIN_CONFIDENCE+"%",40,876);
}

// Handle shared controls before dispatching original fitness buttons.
boolean handleLabClick() {
  if(state==STATE_AGE_INPUT) {
    if(hit(50,125,140,42) && !serialConnected && ports.length>0) { portIndex=(portIndex+1)%ports.length; PORT_NAME=ports[portIndex]; }
    if(hit(200,125,120,42) && !serialConnected) refreshPorts();
    if(hit(850,125,150,42)) connectPort();
    if(hit(1020,125,220,42)) requestBuzzer("Manual test");
    return true;
  }
  if(state>=STATE_FITNESS_READY && hit(40,790,125,40)) {
    if(state==STATE_FITNESS_ACTIVE) stopFitnessSession();
    if(state==STATE_STRESS) { stressPhase=STRESS_READY; candidate=-1; }
    state=STATE_FITNESS_READY; showPulse=false; return true;
  }
  if(state>=STATE_FITNESS_READY && hit(180,790,150,40)) { exportData(); return true; }
  if(state>=STATE_FITNESS_READY && hit(725,790,165,40)) { requestBuzzer("Manual test"); return true; }
  if(state>=STATE_FITNESS_READY && hit(530,790,180,40)) { showPulse=!showPulse; return true; }
  if(showPulse) return true;
  if(state>=STATE_FITNESS_READY && hit(345,790,170,40)) {
    if(state!=STATE_FITNESS_ACTIVE && !(state==STATE_STRESS && stressPhase!=STRESS_READY)) {
      resetSignalWindow(); state=STATE_WAITING_SIGNAL;
    }
    return true;
  }
  if(state==STATE_FITNESS_READY) {
    if(hit(80,565,250,55)) startFitnessSession();
    if(hit(690,565,280,55)) { state=STATE_STRESS; stressPhase=STRESS_READY; }
    return true;
  }
  if(state==STATE_STRESS) { handleStressClick(); return true; }
  return false;
}

// Export measurements plus fitness totals and calibration results for the report.
void exportData() {
  try {
    String id=year()+nf(month(),2)+nf(day(),2)+"_"+nf(hour(),2)+nf(minute(),2)+nf(second(),2)+"_"+millis();
    String folder=sketchPath("exports"); new java.io.File(folder).mkdirs();
    String[] lines=new String[recorded.size()+1];
    lines[0]="elapsed_app_ms,screen,hr_bpm,spo2_percent,confidence_percent,sensor_status,valid,interval_ms,interval_source,baseline_bpm,fitness_zone,stress_phase,stress_state,smoothed_bpm";
    for(int i=0;i<recorded.size();i++) lines[i+1]=recorded.get(i);
    saveStrings(folder+"/measurements_"+id+".csv",lines);
    ArrayList<String> summary=new ArrayList<String>(); summary.add("metric,value");
    summary.add("age,"+userAge); summary.add("max_hr,"+maxHR); summary.add("baseline_bpm,"+restingHR);
    float total=activityStartTime==0?0:((state==STATE_FITNESS_ACTIVE?millis():activityEndTime)-activityStartTime)/1000.0;
    summary.add("fitness_elapsed_s,"+total); summary.add("unclassified_s,"+max(0,total-getClassifiedTime_s()));
    for(int i=0;i<6;i++) summary.add(getZoneName(i)+"_seconds,"+zoneTimes_s[i]);
    summary.add("calm_mean_bpm,"+calmMean); summary.add("stress_mean_bpm,"+stressMean);
    summary.add("calm_threshold,"+calmThreshold); summary.add("stress_threshold,"+stressThreshold);
    summary.add("calm_ready,"+calmOK); summary.add("stress_ready,"+stressOK);
    summary.add("calm_uses_default_threshold,"+calmDefault); summary.add("stress_uses_default_threshold,"+stressDefault);
    saveStrings(folder+"/summary_"+id+".csv",summary.toArray(new String[0]));
    saveStrings(folder+"/pulse_intervals_"+id+".csv",pulseLog.toArray(new String[0]));
    notice="Saved measurements, pulse intervals and summary to the sketch's exports folder.";
  } catch(Exception e) { notice="Export failed: "+e.getMessage(); }
}

// Beat-to-beat pulse timing from raw infrared PPG, not from 60000 / BPM.
// Timing is approximate: firmware timestamps promptly read, unbuffered samples.
// Backlogged samples are marked unusable; motion and signal gaps reset detection.
float dcLevel=0, filteredPulse=0, envelope=0, previousPulse=0, olderPulse=0;
float measuredInterval=0;
long previousDeviceTime=-1, previousPeakTime=-1, warmupStart=0;
int lastBeatReceived=0;
boolean peakArmed=false;
ArrayList<Float> pulseTrace=new ArrayList<Float>();
ArrayList<Boolean> pulseMarkers=new ArrayList<Boolean>();
ArrayList<String> pulseLog=new ArrayList<String>(java.util.Arrays.asList("device_peak_ms,interval_ms"));
boolean showPulse=false;

// Reset timing and filter history after loss of contact, backlog, or reconnect.
void resetPulse() {
  previousDeviceTime=-1; previousPeakTime=-1; measuredInterval=0;
  filteredPulse=previousPulse=olderPulse=envelope=0; peakArmed=false;
  pulseTrace.clear(); pulseMarkers.clear();
}

// Remove slow baseline drift, smooth high-frequency noise, then detect one peak per pulse.
void processPulse(float ir,long deviceTime,boolean usable,int receivedAt) {
  if(!usable || ir<=0 || ir>=16777215) { resetPulse(); return; }
  if(previousDeviceTime<0) {
    dcLevel=ir; previousDeviceTime=deviceTime; warmupStart=deviceTime; return;
  }
  long delta=deviceTime-previousDeviceTime;
  if(delta<=0 || delta>100 || abs(ir-dcLevel)>max(2000,dcLevel*0.15)) {
    resetPulse(); return;
  }
  float dt=delta/1000.0;
  dcLevel+=dt/(0.5+dt)*(ir-dcLevel);
  filteredPulse+=dt/(0.04+dt)*((ir-dcLevel)-filteredPulse);
  envelope+=dt/(1.0+dt)*(abs(filteredPulse)-envelope);
  if(filteredPulse<0) peakArmed=true;
  boolean peak=false;
  if(deviceTime-warmupStart>=2000 && peakArmed && previousPulse>olderPulse && previousPulse>=filteredPulse && previousPulse>max(5,envelope*0.6)) {
    long peakTime=previousDeviceTime;
    long interval=previousPeakTime<0?0:peakTime-previousPeakTime;
    if(previousPeakTime<0 || interval>=300) {
      peakArmed=false; peak=true;
      if(interval>=300 && interval<=2000) {
        measuredInterval=interval; lastBeatReceived=receivedAt;
        pulseLog.add(peakTime+","+interval);
      } else measuredInterval=0;
      previousPeakTime=peakTime;
    }
  }
  if(previousPeakTime>=0 && deviceTime-previousPeakTime>2500) { measuredInterval=0; previousPeakTime=-1; }
  pulseTrace.add(filteredPulse); pulseMarkers.add(false);
  if(peak && pulseMarkers.size()>1) pulseMarkers.set(pulseMarkers.size()-2,true);
  if(pulseTrace.size()>500) { pulseTrace.remove(0); pulseMarkers.remove(0); }
  olderPulse=previousPulse; previousPulse=filteredPulse; previousDeviceTime=deviceTime;
}

// Optional waveform view helps check whether detected peaks match the optical pulse.
void drawPulseOverlay() {
  fill(244,248,252); rect(20,110,1260,660,16);
  fill(darkBlue); textAlign(LEFT,TOP); textSize(24);
  text("Raw PPG verification",50,135);
  fill(textColor); textSize(16);
  text(rawFirmware?"Filtered infrared PPG; red markers show detected peaks. Check for one marker per pulse.":
    "Upload the companion Arduino sketch to receive raw PPG samples.",50,180);
  float scale=10;
  for(float v:pulseTrace) scale=max(scale,abs(v));
  stroke(205); line(60,430,1230,430);
  for(int i=1;i<pulseTrace.size();i++) {
    float x1=map(i-1,0,499,60,1230), x2=map(i,0,499,60,1230);
    float y1=map(pulseTrace.get(i-1),-scale,scale,650,230), y2=map(pulseTrace.get(i),-scale,scale,650,230);
    stroke(primaryBlue); line(x1,y1,x2,y2);
    if(pulseMarkers.get(i)) { noStroke(); fill(stopRed); ellipse(x2,y2,8,8); }
  }
  noStroke(); fill(textColor); textSize(18);
  text("Pulse interval: "+intervalText()+" ms",60,690);
  textSize(14); text("Last 500 usable samples. Timing and peak detection require validation on your sensor.",60,730);
}

// Section II: personalized thresholds, smoothing, hysteresis, and buzzer feedback.
// These are heart-rate-based classifications for the lab, not a diagnosis of emotion.
final int STRESS_READY=0, CALM_CAL=1, STRESS_CAL=2, MONITOR=3;
final int NEUTRAL=0, CALM=1, STRESSED=2;
int stressPhase=STRESS_READY, mood=NEUTRAL, candidate=-1, candidateStart=0;
int calStart=0, calTotal=0, calValid=0, calPrevious=0, stressStart=0;
boolean calPreviousValid=false, calmOK=false, stressOK=false, previousStressValid=false;
boolean calmDefault=false, stressDefault=false;
final float DEFAULT_OFFSET_BPM=3; // Explicit lab heuristic when calibration has no clear directional response.
float calSum=0, calCoverage=0, calmMean=0, stressMean=0, calmThreshold=0, stressThreshold=0;
float smoothHR=0;
ArrayList<Float> smoothWindow=new ArrayList<Float>();
ArrayList<Float> stressTimes=new ArrayList<Float>(), stressHRs=new ArrayList<Float>();
ArrayList<Integer> stressColors=new ArrayList<Integer>();
ArrayList<Boolean> stressLinks=new ArrayList<Boolean>();
int previousStressTime=0, buzzerCommands=0;

// A new baseline invalidates thresholds from any previous wearer or resting state.
void resetCalibrations() {
  calmOK=false; stressOK=false; calmMean=stressMean=0; calmThreshold=stressThreshold=0;
  calmDefault=false; stressDefault=false;
  stressPhase=STRESS_READY; mood=NEUTRAL; candidate=-1; clearSmooth();
}
// Clear the smoothing window across signal loss; never reuse pre-gap evidence.
void clearSmooth() { smoothWindow.clear(); smoothHR=0; }

// Start a calibration; music duration is user-controlled, stress duration is 60 s.
void startCalibration(int phase) {
  stressPhase=phase; calStart=millis(); calTotal=calValid=0; calSum=calCoverage=0;
  calPrevious=0; calPreviousValid=false; clearSmooth(); resetStressGraph();
  if(phase==CALM_CAL) { calmOK=false; calmDefault=false; calmMean=0; }
  else { stressOK=false; stressDefault=false; stressMean=0; }
  notice=phase==CALM_CAL?"Play your calming music. Stop calibration when the song ends (minimum 30 s).":
    "Recall a stressful event for 60 seconds. Keep the sensor still.";
}

// Accept completed, good-quality recordings regardless of HR direction.
// A weak/opposite response uses an explicitly labeled default, not a claimed calibration effect.
void finishCalibration() {
  int duration=millis()-calStart;
  if(stressPhase!=CALM_CAL && stressPhase!=STRESS_CAL) return;
  if(stressPhase==CALM_CAL && duration<30000) { notice="Calm calibration needs at least 30 seconds."; return; }
  int phase=stressPhase; stressPhase=STRESS_READY;
  if(calValid<30 || calTotal==0 || (float)calValid/calTotal<0.7 || calCoverage<duration*0.7) {
    notice="Calibration failed: insufficient valid coverage. Reposition sensor and retry."; return;
  }
  float average=calSum/calValid;
  if(phase==CALM_CAL) {
    calmMean=average; calmOK=true; calmDefault=restingHR-calmMean<1;
    calmThreshold=restingHR-(calmDefault?DEFAULT_OFFSET_BPM:max(1,(restingHR-calmMean)*0.5));
    notice="Music mean: "+nf(average,0,1)+" bpm; change from baseline: "+nf(average-restingHR,0,1)+
      (calmDefault?" bpm. Saved; no clear decrease. Using baseline - 3 BPM default.":" bpm. Calm calibration saved.");
  } else {
    stressMean=average; stressOK=true; stressDefault=stressMean-restingHR<1;
    stressThreshold=restingHR+(stressDefault?DEFAULT_OFFSET_BPM:max(1,(stressMean-restingHR)*0.5));
    notice="Stress mean: "+nf(average,0,1)+" bpm; change from baseline: "+nf(average-restingHR,0,1)+
      (stressDefault?" bpm. Saved; no clear increase. Using baseline + 3 BPM default.":" bpm. Stress calibration saved.");
  }
}

// Start a fresh monitoring trace after both calibrations have usable results.
void startMonitoring() {
  if(!calmOK || !stressOK) { notice="Finish both calibrations with sufficient valid signal. See the status above the buttons."; return; }
  stressPhase=MONITOR; mood=NEUTRAL; candidate=-1; clearSmooth(); resetStressGraph();
  notice=(calmDefault || stressDefault)?"Monitoring with labeled default threshold(s): calibration had no clear HR response.":
    "Monitoring HR-based state changes. Two beeps are requested on entry into STRESSED.";
}
// Begin a new trace without deleting calibration results.
void resetStressGraph() {
  stressStart=millis(); previousStressTime=0; previousStressValid=false;
  stressTimes.clear(); stressHRs.clear(); stressColors.clear(); stressLinks.clear();
}

// Collect calibration statistics or classify the rolling five-second HR average.
void processStress(int now) {
  if(stressPhase==STRESS_READY) return;
  int dt=now-previousStressTime;
  boolean connected=lastSampleValid && previousStressValid && dt>0 && dt<=1500;
  if(stressPhase==CALM_CAL || stressPhase==STRESS_CAL) {
    calTotal++;
    if(lastSampleValid) { calValid++; calSum+=heartRate; }
    int cdt=now-calPrevious;
    if(calPreviousValid && lastSampleValid && calPrevious>0 && cdt>0 && cdt<=1500) calCoverage+=cdt;
    calPrevious=now; calPreviousValid=lastSampleValid;
  }
  if(lastSampleValid) {
    smoothWindow.add((float)heartRate);
    if(smoothWindow.size()>10) smoothWindow.remove(0);
    smoothHR=0; for(float v:smoothWindow) smoothHR+=v; smoothHR/=smoothWindow.size();
    if(stressPhase==MONITOR && smoothWindow.size()==10) updateMood(now,smoothHR);
    stressTimes.add((now-stressStart)/1000.0); stressHRs.add((float)heartRate);
    stressColors.add(stressPhase==MONITOR?mood:NEUTRAL); stressLinks.add(connected);
  } else { clearSmooth(); candidate=-1; }
  previousStressTime=now; previousStressValid=lastSampleValid;
}

// Require two seconds of evidence and use separate exit thresholds to prevent chatter.
void updateMood(int now,float hr) {
  int desired=NEUTRAL;
  if(hr>=stressThreshold) desired=STRESSED;
  else if(hr<=calmThreshold) desired=CALM;
  else if(mood==STRESSED && hr>restingHR+(stressThreshold-restingHR)*0.5) desired=STRESSED;
  else if(mood==CALM && hr<restingHR-(restingHR-calmThreshold)*0.5) desired=CALM;
  if(desired==mood) { candidate=-1; return; }
  if(candidate!=desired) { candidate=desired; candidateStart=now; return; }
  if(now-candidateStart>=2000) {
    int previous=mood; mood=desired; candidate=-1;
    if(mood==STRESSED && previous!=STRESSED) {
      requestBuzzer("Stress detected");
    }
  }
}

// Map the HR-based state to a consistent label and color.
String moodName(int m) { return m==CALM?"CALM":m==STRESSED?"STRESSED":"NEUTRAL"; }
color moodColor(int m) { return m==CALM?successColor:m==STRESSED?stopRed:primaryBlue; }

// Draw calibration outcomes, live metrics, trace, and accessible controls.
void drawStress() {
  drawMainTitle("Calm / Stressed Mode", "Section II - compare heart-rate changes with the resting baseline");
  drawMetricCard(40,125,230,115,"HEART RATE",isCurrentSignalValid()?str(heartRate):"--","bpm");
  drawMetricCard(285,125,230,115,"RESTING HR",nf(restingHR,0,1),"bpm");
  drawMetricCard(530,125,230,115,"SpO2",isCurrentSignalValid() && oxygen>0?str(oxygen):"--","%");
  drawMetricCard(775,125,230,115,"CONFIDENCE",isCurrentSignalValid()?str(confidence):"--","%");
  drawMetricCard(1020,125,230,115,intervalLabel(),intervalText(),"ms");
  drawCard(40,260,805,380); drawStressGraph(95,310,715,275);
  drawCard(865,260,385,380);
  fill(moodColor(mood)); textAlign(LEFT,TOP); textSize(26);
  String label=stressPhase==CALM_CAL?"CALM CALIBRATION":stressPhase==STRESS_CAL?"STRESS CALIBRATION":
    stressPhase==MONITOR?(isCurrentSignalValid() && smoothWindow.size()==10?moodName(mood):"ACQUIRING SIGNAL"):"CALIBRATION / READY";
  text(label,885,285); fill(textColor); textSize(16);
  text("Calm mean: "+(calmMean>0?nf(calmMean,0,1):"--")+" bpm"+(calmOK?" (saved)":""),885,345);
  text("Stress mean: "+(stressMean>0?nf(stressMean,0,1):"--")+" bpm"+(stressOK?" (saved)":""),885,378);
  text("Calm threshold: "+(calmOK?nf(calmThreshold,0,1):"--")+(calmDefault?" (default)":""),885,420);
  text("Stress threshold: "+(stressOK?nf(stressThreshold,0,1):"--")+(stressDefault?" (default)":""),885,453);
  text("Smoothed HR: "+(smoothHR>0?nf(smoothHR,0,1):"--"),885,490);
  text("Buzzer commands: "+buzzerCommands,885,523);
  textSize(13); text("Buzzer: "+buzzerStatus,885,548); textSize(16);
  if(stressPhase==CALM_CAL || stressPhase==STRESS_CAL) {
    text("Elapsed: "+formatTime((millis()-calStart)/1000.0),885,565);
    text("Valid readings: "+calValid+" / "+calTotal,885,596);
  }
  boolean idle=stressPhase==STRESS_READY;
  fill(secondaryText); textAlign(LEFT,CENTER); textSize(14);
  String readiness=stressPhase==CALM_CAL?"Click Finish music after the song ends (at least 30 seconds).":
    stressPhase==STRESS_CAL?"Stress calibration finishes automatically at 60 seconds. Do not click Stop early.":
    !idle?"Monitoring active.":calmOK && stressOK?"Both recordings saved. Start monitoring is ready.":
    "Still needed: "+(!calmOK?"valid music recording":"")+(!calmOK && !stressOK?" and ":"")+(!stressOK?"valid stress recording":"");
  text(readiness,40,647);
  button("Calibrate with music",40,660,250,50,idle);
  button("Calibrate stress (60 s)",310,660,260,50,idle);
  button("Start monitoring",590,660,230,50,idle && calmOK && stressOK);
  button(stressPhase==CALM_CAL?"Finish music":"Stop / cancel",845,660,220,50,!idle);
  fill(secondaryText); textSize(14); textAlign(LEFT,TOP);
  text("Music plays outside this app. HR alone cannot establish an emotional state; these labels follow your calibration.",40,725);
  text(rawFirmware?"Pulse interval uses detected raw-PPG peaks. Keep still and verify the waveform during testing.":
    "Interval is currently estimated as 60000 / BPM. Companion Arduino firmware enables raw-PPG detection.",40,750);
}

// Test and automatic alerts share this exact path. A successful write is not
// proof of sound; the new Arduino firmware reports starting and finishing tone().
void requestBuzzer(String reason) {
  if(buzzerPending) return; // Avoid overlapping tests/alerts; no automatic retries.
  if(!serialConnected) {
    buzzerStatus="No serial connection"; notice=reason+": connect the device first."; return;
  }
  try {
    writeBuzzerCommand(); buzzerCommands++; buzzerSentAt=millis(); buzzerPending=true;
    buzzerStatus="Sent; awaiting board"; notice=reason+": B sent to "+PORT_NAME+". Waiting for board acknowledgment.";
  } catch(Exception e) {
    buzzerStatus="Send failed"; notice="Buzzer send failed: "+e.getMessage();
  }
}

// Keep the transport separate so automated tests can verify alerts without hardware.
void writeBuzzerCommand() {
  if(myPort==null) throw new IllegalStateException("No open serial port");
  myPort.write('B');
}

// Plot raw HR and baseline/threshold guides, leaving breaks across invalid data.
void drawStressGraph(float x,float y,float w,float h) {
  float low=restingHR-20, high=restingHR+30, end=10;
  for(float v:stressHRs) { low=min(low,v-5); high=max(high,v+5); }
  if(stressTimes.size()>0) end=max(10,stressTimes.get(stressTimes.size()-1));
  low=max(0,low); float[] levels={restingHR,calmThreshold,stressThreshold};
  fill(secondaryText); textSize(13); textAlign(LEFT,TOP); text("Heart rate (bpm) - time (s)",x,y-32);
  for(int i=0;i<=4;i++) {
    float v=lerp(low,high,i/4.0), py=map(v,low,high,y+h,y);
    stroke(225); line(x,py,x+w,py); fill(secondaryText); textAlign(RIGHT,CENTER); text(nf(v,0,0),x-8,py);
    textAlign(CENTER,TOP); text(nf(end*i/4,0,0),x+w*i/4,y+h+8);
  }
  for(int i=0;i<3;i++) if(i==0 || (i==1?calmOK:stressOK)) {
    stroke(i==0?secondaryText:i==1?successColor:stopRed);
    float py=map(levels[i],low,high,y+h,y); line(x,py,x+w,py);
  }
  for(int i=0;i<stressTimes.size();i++) {
    float px=map(stressTimes.get(i),0,end,x,x+w), py=map(stressHRs.get(i),low,high,y+h,y);
    stroke(moodColor(stressColors.get(i))); strokeWeight(2);
    if(i>0 && stressLinks.get(i)) line(map(stressTimes.get(i-1),0,end,x,x+w),map(stressHRs.get(i-1),low,high,y+h,y),px,py);
    point(px,py);
  }
  strokeWeight(1); noStroke();
}

// Prevent overlapping calibrations and preserve completed results when stopping monitoring.
void handleStressClick() {
  if(stressPhase==STRESS_READY) {
    if(hit(40,660,250,50)) startCalibration(CALM_CAL);
    if(hit(310,660,260,50)) startCalibration(STRESS_CAL);
    if(hit(590,660,230,50)) startMonitoring();
  } else if(hit(845,660,220,50)) {
    if(stressPhase==CALM_CAL) finishCalibration();
    else { stressPhase=STRESS_READY; candidate=-1; notice="Stopped. Completed calibration results are retained."; }
  }
}


