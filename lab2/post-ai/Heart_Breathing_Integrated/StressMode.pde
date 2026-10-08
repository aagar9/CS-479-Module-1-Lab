// ========================================
// STRESS MONITORING MODE
// BME/CS 479 - Lab 2
// ========================================

// Stress states
final int STRESS_BASELINE = 0;
final int STRESS_READY = 1;
final int STRESS_MONITORING = 2;

int stressState = STRESS_BASELINE;


// ----------------------------------------
// 30 SECOND BASELINE
// ----------------------------------------

final int STRESS_BASELINE_DURATION = 30000;

int stressBaselineStart = 0;
boolean stressBaselineStarted = false;

float stressBaselineHRSum = 0;
float stressBaselineRRSum = 0;

int stressBaselineHRSamples = 0;
int stressBaselineRRSamples = 0;

float stressBaselineHR = 0;
float stressBaselineRR = 0;


// ----------------------------------------
// CURRENT STRESS INFORMATION
// ----------------------------------------

String stressStatus = "WAITING";

float stressHRChange = 0;
float stressRRChange = 0;


// These are UI-level classification thresholds.
// They do NOT change ECG or respiratory calculations.
//
// We can tune these after hardware testing.

final float STRESS_HR_INCREASE_PERCENT = 10.0;
final float STRESS_RR_INCREASE_PERCENT = 10.0;


// ========================================
// MAIN STRESS DRAW FUNCTION
// ========================================

void drawStress() {

  if (!stressBaselineStarted) {
    startStressBaseline();
  }

  if (stressState == STRESS_BASELINE) {

    updateStressBaseline();
    drawStressBaseline();
  }

  else if (stressState == STRESS_READY) {

    drawStressReady();
  }

  else if (stressState == STRESS_MONITORING) {

    updateStressClassification();
    drawStressDashboard();
  }
}


// ========================================
// START BASELINE
// ========================================

void startStressBaseline() {

  stressBaselineStarted = true;

  stressBaselineStart = millis();

  stressBaselineHRSum = 0;
  stressBaselineRRSum = 0;

  stressBaselineHRSamples = 0;
  stressBaselineRRSamples = 0;

  stressBaselineHR = 0;
  stressBaselineRR = 0;

  stressStatus = "WAITING";

  stressState = STRESS_BASELINE;
}


// ========================================
// UPDATE BASELINE
// ========================================

void updateStressBaseline() {

  int currentHR = getHeartRate();
  float currentRR = getRespRate();


  if (currentHR > 0) {

    stressBaselineHRSum += currentHR;
    stressBaselineHRSamples++;
  }


  if (currentRR > 0) {

    stressBaselineRRSum += currentRR;
    stressBaselineRRSamples++;
  }


  if (
    millis() - stressBaselineStart
    >= STRESS_BASELINE_DURATION
  ) {

    finishStressBaseline();
  }
}


// ========================================
// FINISH BASELINE
// ========================================

void finishStressBaseline() {

  if (stressBaselineHRSamples > 0) {

    stressBaselineHR =
      stressBaselineHRSum
      / stressBaselineHRSamples;
  }


  if (stressBaselineRRSamples > 0) {

    stressBaselineRR =
      stressBaselineRRSum
      / stressBaselineRRSamples;
  }


  stressState = STRESS_READY;
}


// ========================================
// BASELINE SCREEN
// ========================================

void drawStressBaseline() {

  float elapsed =
    millis() - stressBaselineStart;

  float remaining =
    max(
      0,
      STRESS_BASELINE_DURATION - elapsed
    );

  float secondsRemaining =
    remaining / 1000.0;


  fill(0);

  textSize(24);

  text(
    "STRESS MODE - BASELINE",
    30,
    170
  );


  textSize(18);

  text(
    "Remain relaxed while a 30-second baseline is recorded.",
    30,
    215
  );


  textSize(32);

  text(
    nf(secondsRemaining, 0, 1)
    + " sec remaining",
    30,
    270
  );


  textSize(18);

  text(
    "Heart Rate: "
    + getHeartRate()
    + " BPM",
    30,
    330
  );


  text(
    "Respiratory Rate: "
    + nf(getRespRate(), 0, 1)
    + " breaths/min",
    30,
    370
  );


  // Progress bar

  float progress =
    constrain(
      elapsed
      / STRESS_BASELINE_DURATION,
      0,
      1
    );


  stroke(0);
  noFill();

  rect(
    30,
    420,
    500,
    25
  );


  noStroke();
  fill(0, 150, 0);

  rect(
    30,
    420,
    500 * progress,
    25
  );
}


// ========================================
// READY SCREEN
// ========================================

void drawStressReady() {

  fill(0);

  textSize(24);

  text(
    "STRESS MODE - BASELINE COMPLETE",
    30,
    170
  );


  textSize(18);

  text(
    "Baseline Heart Rate: "
    + nf(stressBaselineHR, 0, 1)
    + " BPM",
    30,
    230
  );


  text(
    "Baseline Respiratory Rate: "
    + nf(stressBaselineRR, 0, 1)
    + " breaths/min",
    30,
    270
  );


  text(
    "Begin the stress-monitoring portion when ready.",
    30,
    320
  );


  fill(0, 150, 0);

  rect(
    30,
    360,
    250,
    55
  );


  fill(255);

  textSize(18);

  text(
    "START MONITORING",
    65,
    395
  );
}


// ========================================
// START MONITORING
// ========================================

void startStressMonitoring() {

  stressStatus = "MONITORING";

  stressState = STRESS_MONITORING;
}


// ========================================
// STRESS CLASSIFICATION
// ========================================

void updateStressClassification() {

  int currentHR = getHeartRate();
  float currentRR = getRespRate();


  stressHRChange = 0;
  stressRRChange = 0;


  if (
    stressBaselineHR > 0 &&
    currentHR > 0
  ) {

    stressHRChange =
      100.0
      * (
        currentHR
        - stressBaselineHR
      )
      / stressBaselineHR;
  }


  if (
    stressBaselineRR > 0 &&
    currentRR > 0
  ) {

    stressRRChange =
      100.0
      * (
        currentRR
        - stressBaselineRR
      )
      / stressBaselineRR;
  }


  // Require both HR and RR to be elevated.
  //
  // This is deliberately isolated from
  // SignalProcessing.pde so it can be tuned
  // after the hardware test.

  if (
    stressHRChange
    >= STRESS_HR_INCREASE_PERCENT
    &&
    stressRRChange
    >= STRESS_RR_INCREASE_PERCENT
  ) {

    stressStatus = "STRESSED";
  }

  else {

    stressStatus = "CALM";
  }
}


// ========================================
// STRESS DASHBOARD
// ========================================

void drawStressDashboard() {

  fill(0);

  textSize(24);

  text(
    "STRESS MONITORING MODE",
    30,
    160
  );


  // --------------------------------------
  // Current measurements
  // --------------------------------------

  textSize(18);

  text(
    "Heart Rate: "
    + getHeartRate()
    + " BPM",
    30,
    205
  );


  text(
    "Resp Rate: "
    + nf(getRespRate(), 0, 1)
    + " breaths/min",
    260,
    205
  );


  text(
    "Baseline HR: "
    + nf(stressBaselineHR, 0, 1),
    30,
    245
  );


  text(
    "Baseline RR: "
    + nf(stressBaselineRR, 0, 1),
    260,
    245
  );


  // --------------------------------------
  // Stress result
  // --------------------------------------

  textSize(28);


  if (stressStatus.equals("STRESSED")) {

    fill(255, 0, 0);
  }

  else {

    fill(0, 150, 0);
  }


  text(
    "Status: "
    + stressStatus,
    600,
    205
  );


  fill(0);

  textSize(14);

  text(
    "HR change: "
    + nf(stressHRChange, 0, 1)
    + "%",
    600,
    240
  );


  text(
    "RR change: "
    + nf(stressRRChange, 0, 1)
    + "%",
    600,
    265
  );


  // =====================================
  // ECG GRAPH
  // =====================================

  stroke(0);
  noFill();

  rect(
    30,
    295,
    900,
    120
  );


  fill(0);

  textSize(14);

  text(
    "ECG",
    40,
    315
  );


  float ecgDisplayMin = Float.MAX_VALUE;
    float ecgDisplayMax = -Float.MAX_VALUE;

    for (int j = 0; j < ecgPlot.size(); j++) {
      float value = ecgPlot.get(j);
      ecgDisplayMin = min(ecgDisplayMin, value);
      ecgDisplayMax = max(ecgDisplayMax, value);
    }

    float ecgPadding = max(
      10,
      (ecgDisplayMax - ecgDisplayMin) * 0.15
    );

    ecgDisplayMin -= ecgPadding;
    ecgDisplayMax += ecgPadding;

    if (ecgPlot.size() > 1) {

    stroke(255, 0, 0);

    noFill();

    beginShape();


    for (
      int i = 0;
      i < ecgPlot.size();
      i++
    ) {

      float x =
        map(
          i,
          0,
          maxPlotPoints - 1,
          50,
          910
        );


float y =
        map(
          ecgPlot.get(i),
          ecgDisplayMin,
          ecgDisplayMax,
          405,
          325
        );

      y = constrain(y, 325, 405);


      vertex(x, y);
    }


    endShape();
  }


  // =====================================
  // RESPIRATORY GRAPH
  // =====================================

  stroke(0);

  noFill();

  rect(
    30,
    445,
    900,
    130
  );


  fill(0);

  text(
    "RESPIRATION",
    40,
    465
  );


  if (fsrPlot.size() > 1) {

    stroke(0, 0, 255);

    noFill();

    beginShape();


    for (
      int i = 0;
      i < fsrPlot.size();
      i++
    ) {

      float x =
        map(
          i,
          0,
          maxPlotPoints - 1,
          50,
          910
        );


      float y =
        map(
          fsrPlot.get(i),
          0,
          1023,
          565,
          475
        );


      vertex(x, y);
    }


    endShape();
  }


  stroke(0);
}


// ========================================
// STRESS MOUSE INPUT
// ========================================

void stressMousePressed() {

  if (
    stressState
    == STRESS_READY
  ) {

    if (
      mouseX >= 30 &&
      mouseX <= 280 &&
      mouseY >= 360 &&
      mouseY <= 415
    ) {

      startStressMonitoring();
    }
  }
}