// ========================================
// PERSONALIZED STRESS MONITORING
// Three 30-second calibrations + live monitoring
// ========================================
final int STRESS_REST = 0;
final int STRESS_STRESSED = 1;
final int STRESS_CALM = 2;
final int STRESS_READY = 3;
final int STRESS_MONITORING = 4;

final int STRESS_CALIBRATION_MS = 30000;
final int STRESS_SAMPLE_MS = 1000;

int stressState = STRESS_REST;
boolean stressStarted = false;
boolean stressAwaitingStart = true;
int stressPhaseStart = 0;
int stressLastSample = 0;
float stressHRSum = 0;
float stressRRSum = 0;
int stressHRCount = 0;
int stressRRCount = 0;

float[] stressAverageHR = new float[3];
float[] stressAverageRR = new float[3];
int[] stressCountsHR = new int[3];
int[] stressCountsRR = new int[3];

float stressHRThreshold = 0;
float stressRRThreshold = 0;
boolean stressHRUsable = false;
boolean stressRRUsable = false;
String stressStatus = "WAITING";
String stressMessage = "";

void drawStress() {
  if (!stressStarted) {
    stressStarted = true;
    prepareStressPhase(STRESS_REST);
  }

  if (stressState <= STRESS_CALM) {
    if (!stressAwaitingStart) updateStressCalibration();
    drawStressCalibration();
  } else if (stressState == STRESS_READY) {
    drawStressReady();
  } else {
    updateStressClassification();
    drawStressDashboard();
  }
}

void prepareStressPhase(int phase) {
  stressState = phase;
  stressAwaitingStart = true;
  stressPhaseStart = 0;
  stressLastSample = 0;
  stressHRSum = 0;
  stressRRSum = 0;
  stressHRCount = 0;
  stressRRCount = 0;
  stressMessage = "";
}

void beginStressPhase() {
  if (stressState > STRESS_CALM) return;
  stressAwaitingStart = false;
  stressPhaseStart = millis();
  stressLastSample = 0;
  stressHRSum = 0;
  stressRRSum = 0;
  stressHRCount = 0;
  stressRRCount = 0;
  stressMessage = "";
}

void updateStressCalibration() {
  int now = millis();
  if (stressLastSample == 0 || now - stressLastSample >= STRESS_SAMPLE_MS) {
    stressLastSample = now;
    int hr = getHeartRate();
    float rr = getRespRate();
    if (hr > 0) { stressHRSum += hr; stressHRCount++; }
    if (rr > 0) { stressRRSum += rr; stressRRCount++; }
  }

  if (now - stressPhaseStart >= STRESS_CALIBRATION_MS) {
    if (stressHRCount == 0 || stressRRCount == 0) {
      stressMessage = "Insufficient sensor data. Collecting again...";
      stressPhaseStart = now;
      stressLastSample = 0;
      stressHRSum = 0;
      stressRRSum = 0;
      stressHRCount = 0;
      stressRRCount = 0;
      return;
    }
    stressAverageHR[stressState] = stressHRSum / stressHRCount;
    stressAverageRR[stressState] = stressRRSum / stressRRCount;
    stressCountsHR[stressState] = stressHRCount;
    stressCountsRR[stressState] = stressRRCount;
    if (stressState < STRESS_CALM) {
      prepareStressPhase(stressState + 1);
    } else {
      finishStressCalibration();
    }
  }
}

void finishStressCalibration() {
  // Thresholds are the midpoints between the measured calm and stressed averages.
  stressHRThreshold = (stressAverageHR[STRESS_CALM] + stressAverageHR[STRESS_STRESSED]) / 2.0;
  stressRRThreshold = (stressAverageRR[STRESS_CALM] + stressAverageRR[STRESS_STRESSED]) / 2.0;
  stressHRUsable = stressAverageHR[STRESS_STRESSED] > stressAverageHR[STRESS_CALM];
  stressRRUsable = stressAverageRR[STRESS_STRESSED] > stressAverageRR[STRESS_CALM];
  stressState = STRESS_READY;
}

void drawStressCalibration() {
  fill(0);
  textSize(24);
  String title = stressState == STRESS_REST ? "RESTING BASELINE" :
                 stressState == STRESS_STRESSED ? "STRESSED CALIBRATION" : "CALM CALIBRATION";
  text("STRESS MODE - " + title, 30, 170);
  textSize(17);
  String instruction = stressState == STRESS_REST ? "Sit quietly and relax." :
                       stressState == STRESS_STRESSED ? "Perform the assigned stressful task." :
                       "Stop the task and calm down.";
  text(instruction, 30, 215);
  text("Stage " + (stressState + 1) + " of 3", 30, 255);
  float remaining = stressAwaitingStart ? 30.0 :
    max(0, (STRESS_CALIBRATION_MS - (millis() - stressPhaseStart)) / 1000.0);
  textSize(26);
  text(stressAwaitingStart ? "Ready to acquire 30-second measurement" :
    nf(remaining, 0, 1) + " seconds remaining", 30, 305);
  textSize(18);
  text("Current HR: " + getHeartRate() + " BPM", 30, 350);
  text("Current RR: " + nf(getRespRate(), 0, 1) + " breaths/min", 30, 385);
  fill(0, 140, 190);
  noStroke();
  rect(30, 425, 500 * constrain(1 - remaining / 30.0, 0, 1), 25);
  stroke(0);
  noFill();
  rect(30, 425, 500, 25);
  fill(160, 0, 0);
  textSize(15);
  text(stressMessage, 30, 490);
  if (stressAwaitingStart) {
    fill(0, 145, 0);
    noStroke();
    rect(30, 525, 310, 55);
    fill(255);
    textSize(17);
    text("START 30-SECOND ACQUISITION", 42, 560);
    stroke(0);
  } else {
    fill(0);
    textSize(15);
    text("Acquiring measurements...", 30, 550);
  }
}

void drawStressReady() {
  fill(0);
  textSize(23);
  text("PERSONALIZED STRESS CALIBRATION COMPLETE", 30, 160);
  textSize(16);
  text("                 Resting        Stressed        Calm", 30, 215);
  text("HR (BPM):      " + nf(stressAverageHR[0], 0, 1) + "             " + nf(stressAverageHR[1], 0, 1) + "             " + nf(stressAverageHR[2], 0, 1), 30, 250);
  text("RR (breaths/min): " + nf(stressAverageRR[0], 0, 1) + "             " + nf(stressAverageRR[1], 0, 1) + "             " + nf(stressAverageRR[2], 0, 1), 30, 285);
  text("HR threshold: " + nf(stressHRThreshold, 0, 1) + (stressHRUsable ? " BPM" : " (unusable: stress did not raise HR)"), 30, 330);
  text("RR threshold: " + nf(stressRRThreshold, 0, 1) + (stressRRUsable ? " breaths/min" : " (unusable: stress did not raise RR)"), 30, 365);
  if (!stressHRUsable && !stressRRUsable) {
    fill(180, 0, 0);
    text("Neither signal separates calm from stressed. Recalibrate.", 30, 410);
  }
  fill(0, 145, 0);
  rect(30, 455, 265, 55);
  fill(255);
  textSize(17);
  text("START MONITORING", 48, 490);
  fill(120);
  rect(315, 455, 220, 55);
  fill(255);
  text("RECALIBRATE", 340, 490);
}

void startStressMonitoring() {
  stressStatus = "INSUFFICIENT DATA";
  stressState = STRESS_MONITORING;
}

void updateStressClassification() {
  int hr = getHeartRate();
  float rr = getRespRate();
  boolean validHR = stressHRUsable && hr > 0;
  boolean validRR = stressRRUsable && rr > 0;
  if (!validHR && !validRR) {
    stressStatus = "INSUFFICIENT DATA";
    return;
  }
  // OR rule: either valid signal above its personalized threshold indicates stress.
  if ((validHR && hr >= stressHRThreshold) || (validRR && rr >= stressRRThreshold)) {
    stressStatus = "STRESSED";
  } else {
    stressStatus = "CALM";
  }
}

void drawStressDashboard() {
  fill(0);
  textSize(24);
  text("STRESS MONITORING MODE", 30, 160);
  textSize(17);
  text("Heart Rate: " + getHeartRate() + " BPM", 30, 205);
  text("Resp Rate: " + nf(getRespRate(), 0, 1) + " breaths/min", 260, 205);
  textSize(14);
  text("HR threshold: " + (stressHRUsable ? nf(stressHRThreshold, 0, 1) : "N/A"), 30, 245);
  text("RR threshold: " + (stressRRUsable ? nf(stressRRThreshold, 0, 1) : "N/A"), 260, 245);
  fill(stressStatus.equals("STRESSED") ? color(220, 0, 0) :
       stressStatus.equals("CALM") ? color(0, 150, 0) : color(120));
  textSize(24);
  text("Status: " + stressStatus, 560, 205);
  fill(0);
  textSize(13);
  text("Calibrated using 30s rest + 30s stressed + 30s calm", 560, 245);

  // ECG graph: dynamic centered-signal scaling, contained in plot.
  stroke(0); noFill(); rect(30, 295, 900, 120);
  fill(0); textSize(14); text("ECG", 40, 315);
  if (ecgPlot.size() > 1) {
    float low = Float.MAX_VALUE;
    float high = -Float.MAX_VALUE;
    for (int i = 0; i < ecgPlot.size(); i++) {
      low = min(low, ecgPlot.get(i));
      high = max(high, ecgPlot.get(i));
    }
    float pad = max(10, (high - low) * 0.15);
    low -= pad; high += pad;
    stroke(255, 0, 0); noFill(); beginShape();
    for (int i = 0; i < ecgPlot.size(); i++) {
      float x = map(i, 0, maxPlotPoints - 1, 50, 910);
      float y = constrain(map(ecgPlot.get(i), low, high, 405, 325), 325, 405);
      vertex(x, y);
    }
    endShape();
  }

  stroke(0); noFill(); rect(30, 445, 900, 130);
  fill(0); textSize(14); text("RESPIRATION", 40, 465);
  if (fsrPlot.size() > 1) {
    stroke(0, 0, 255); noFill(); beginShape();
    for (int i = 0; i < fsrPlot.size(); i++) {
      float x = map(i, 0, maxPlotPoints - 1, 50, 910);
      float y = constrain(map(fsrPlot.get(i), 0, 1023, 565, 475), 475, 565);
      vertex(x, y);
    }
    endShape();
  }
  stroke(0);
}

void stressMousePressed() {
  if (stressState <= STRESS_CALM && stressAwaitingStart) {
    if (mouseX >= 30 && mouseX <= 340 &&
        mouseY >= 525 && mouseY <= 580) {
      beginStressPhase();
    }
    return;
  }
  if (stressState == STRESS_READY && mouseY >= 455 && mouseY <= 510) {
    if (mouseX >= 30 && mouseX <= 295 && (stressHRUsable || stressRRUsable)) {
      startStressMonitoring();
    } else if (mouseX >= 315 && mouseX <= 535) {
      prepareStressPhase(STRESS_REST);
    }
  }
}
