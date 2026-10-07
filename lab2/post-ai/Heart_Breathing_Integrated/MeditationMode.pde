// ========================================
// MEDITATION MODE
// BME/CS 479 - Lab 2
// ========================================

// Meditation states
final int MEDITATION_BASELINE = 0;
final int MEDITATION_READY = 1;
final int MEDITATION_ACTIVE = 2;

int meditationState = MEDITATION_BASELINE;


// ----------------------------------------
// BASELINE
// ----------------------------------------

final int MEDITATION_BASELINE_DURATION = 30000;

boolean meditationBaselineStarted = false;
int meditationBaselineStart = 0;

float meditationHRSum = 0;
float meditationRRSum = 0;
float meditationInhaleSum = 0;
float meditationExhaleSum = 0;

int meditationHRSamples = 0;
int meditationRRSamples = 0;
int meditationBreathSamples = 0;

float meditationBaselineHR = 0;
float meditationBaselineRR = 0;
float meditationBaselineInhale = 0;
float meditationBaselineExhale = 0;


// ----------------------------------------
// BREATH TRACKING
// ----------------------------------------

int meditationFailedBreaths = 0;

float meditationLastInhale = -1;
float meditationLastExhale = -1;

String meditationBreathingStatus = "WAITING";


// Target:
//
// inhale period = 1/3 exhale period
//
// Therefore:
//
// exhale ~= 3 * inhale
//
// A tolerance is necessary because real breathing
// will not produce an exact floating-point ratio.

final float MEDITATION_RATIO_TARGET = 3.0;
final float MEDITATION_RATIO_TOLERANCE = 0.5;


// ========================================
// MAIN MEDITATION FUNCTION
// ========================================

void drawMeditation() {

  if (!meditationBaselineStarted) {
    startMeditationBaseline();
  }


  if (meditationState == MEDITATION_BASELINE) {

    updateMeditationBaseline();
    drawMeditationBaseline();
  }

  else if (meditationState == MEDITATION_READY) {

    drawMeditationReady();
  }

  else if (meditationState == MEDITATION_ACTIVE) {

    updateMeditationBreathing();
    drawMeditationDashboard();
  }
}


// ========================================
// START BASELINE
// ========================================

void startMeditationBaseline() {

  meditationBaselineStarted = true;

  meditationBaselineStart = millis();

  meditationHRSum = 0;
  meditationRRSum = 0;
  meditationInhaleSum = 0;
  meditationExhaleSum = 0;

  meditationHRSamples = 0;
  meditationRRSamples = 0;
  meditationBreathSamples = 0;

  meditationBaselineHR = 0;
  meditationBaselineRR = 0;
  meditationBaselineInhale = 0;
  meditationBaselineExhale = 0;

  meditationLastInhale = -1;
  meditationLastExhale = -1;

  meditationFailedBreaths = 0;

  meditationBreathingStatus = "BASELINE";

  meditationState = MEDITATION_BASELINE;
}


// ========================================
// UPDATE BASELINE
// ========================================

void updateMeditationBaseline() {

  int currentHR = getHeartRate();
  float currentRR = getRespRate();

  float currentInhale = getInhaleTime();
  float currentExhale = getExhaleTime();


  if (currentHR > 0) {

    meditationHRSum += currentHR;
    meditationHRSamples++;
  }


  if (currentRR > 0) {

    meditationRRSum += currentRR;
    meditationRRSamples++;
  }


  // Only count a breath measurement when the
  // inhale/exhale values change.

  if (
    currentInhale > 0 &&
    currentExhale > 0 &&
    (
      currentInhale != meditationLastInhale ||
      currentExhale != meditationLastExhale
    )
  ) {

    meditationInhaleSum += currentInhale;
    meditationExhaleSum += currentExhale;

    meditationBreathSamples++;

    meditationLastInhale = currentInhale;
    meditationLastExhale = currentExhale;
  }


  if (
    millis() - meditationBaselineStart
    >= MEDITATION_BASELINE_DURATION
  ) {

    finishMeditationBaseline();
  }
}


// ========================================
// FINISH BASELINE
// ========================================

void finishMeditationBaseline() {

  if (meditationHRSamples > 0) {

    meditationBaselineHR =
      meditationHRSum /
      meditationHRSamples;
  }


  if (meditationRRSamples > 0) {

    meditationBaselineRR =
      meditationRRSum /
      meditationRRSamples;
  }


  if (meditationBreathSamples > 0) {

    meditationBaselineInhale =
      meditationInhaleSum /
      meditationBreathSamples;

    meditationBaselineExhale =
      meditationExhaleSum /
      meditationBreathSamples;
  }


  meditationState = MEDITATION_READY;
}


// ========================================
// BASELINE SCREEN
// ========================================

void drawMeditationBaseline() {

  float elapsed =
    millis() - meditationBaselineStart;

  float remaining =
    max(
      0,
      MEDITATION_BASELINE_DURATION - elapsed
    );

  float secondsRemaining =
    remaining / 1000.0;


  fill(0);

  textSize(24);

  text(
    "MEDITATION MODE - BASELINE",
    30,
    170
  );


  textSize(18);

  text(
    "Breathe normally while a 30-second baseline is recorded.",
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


  float progress =
    constrain(
      elapsed /
      MEDITATION_BASELINE_DURATION,
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

void drawMeditationReady() {

  fill(0);

  textSize(24);

  text(
    "MEDITATION MODE - BASELINE COMPLETE",
    30,
    170
  );


  textSize(18);

  text(
    "Baseline HR: "
    + nf(meditationBaselineHR, 0, 1)
    + " BPM",
    30,
    225
  );


  text(
    "Baseline RR: "
    + nf(meditationBaselineRR, 0, 1)
    + " breaths/min",
    30,
    260
  );


  text(
    "Baseline inhale: "
    + nf(meditationBaselineInhale, 0, 2)
    + " sec",
    30,
    295
  );


  text(
    "Baseline exhale: "
    + nf(meditationBaselineExhale, 0, 2)
    + " sec",
    30,
    330
  );


  text(
    "Meditation target: exhale for approximately 3x the inhale period.",
    30,
    375
  );


  fill(0, 150, 0);

  rect(
    30,
    415,
    250,
    55
  );


  fill(255);

  textSize(18);

  text(
    "START MEDITATION",
    65,
    450
  );
}


// ========================================
// START MEDITATION
// ========================================

void startMeditationSession() {

  meditationFailedBreaths = 0;

  meditationLastInhale = -1;
  meditationLastExhale = -1;

  meditationBreathingStatus =
    "WAITING FOR BREATH";

  meditationState =
    MEDITATION_ACTIVE;
}


// ========================================
// UPDATE BREATHING
// ========================================

void updateMeditationBreathing() {

  float inhale = getInhaleTime();
  float exhale = getExhaleTime();


  if (
    inhale <= 0 ||
    exhale <= 0
  ) {

    return;
  }


  // Don't evaluate the same breath repeatedly
  // on every Processing frame.

  if (
    inhale == meditationLastInhale &&
    exhale == meditationLastExhale
  ) {

    return;
  }


  meditationLastInhale = inhale;
  meditationLastExhale = exhale;


  float ratio =
    exhale / inhale;


  boolean targetMet =
    abs(
      ratio -
      MEDITATION_RATIO_TARGET
    )
    <=
    MEDITATION_RATIO_TOLERANCE;


  if (targetMet) {

    meditationFailedBreaths = 0;

    meditationBreathingStatus =
      "TARGET MET";
  }

  else {

    meditationFailedBreaths++;


    if (
      meditationFailedBreaths >= 3
    ) {

      meditationBreathingStatus =
        "ADJUST BREATHING";
    }

    else {

      meditationBreathingStatus =
        "KEEP TRYING";
    }
  }
}


// ========================================
// DASHBOARD
// ========================================

void drawMeditationDashboard() {

  float inhale = getInhaleTime();
  float exhale = getExhaleTime();

  float ratio = 0;

  if (inhale > 0) {
    ratio = exhale / inhale;
  }


  fill(0);

  textSize(24);

  text(
    "MEDITATION MODE",
    30,
    160
  );


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
    "Inhale: "
    + nf(inhale, 0, 2)
    + " sec",
    30,
    245
  );


  text(
    "Exhale: "
    + nf(exhale, 0, 2)
    + " sec",
    260,
    245
  );


  text(
    "Exhale / Inhale: "
    + nf(ratio, 0, 2),
    500,
    245
  );


  // --------------------------------------
  // Breathing target
  // --------------------------------------

  textSize(14);

  fill(0);

  text(
    "Target: Exhale ≈ 3 × Inhale",
    30,
    280
  );


  textSize(25);


  if (
    meditationFailedBreaths >= 3
  ) {

    fill(255, 0, 0);
  }

  else if (
    meditationBreathingStatus.equals(
      "TARGET MET"
    )
  ) {

    fill(0, 150, 0);
  }

  else {

    fill(0);
  }


  text(
    meditationBreathingStatus,
    500,
    285
  );


  fill(0);

  textSize(14);

  text(
    "Consecutive breaths outside target: "
    + meditationFailedBreaths,
    680,
    285
  );


  // =====================================
  // ECG GRAPH
  // =====================================

  stroke(0);
  noFill();

  rect(
    30,
    315,
    900,
    120
  );


  fill(0);

  text(
    "ECG",
    40,
    335
  );


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
          0,
          1023,
          425,
          345
        );


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
    465,
    900,
    130
  );


  fill(0);

  text(
    "RESPIRATION",
    40,
    485
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
          585,
          495
        );


      vertex(x, y);
    }


    endShape();
  }


  stroke(0);
}


// ========================================
// MEDITATION MOUSE INPUT
// ========================================

void meditationMousePressed() {

  if (
    meditationState ==
    MEDITATION_READY
  ) {

    if (
      mouseX >= 30 &&
      mouseX <= 280 &&
      mouseY >= 415 &&
      mouseY <= 470
    ) {

      startMeditationSession();
    }
  }
}