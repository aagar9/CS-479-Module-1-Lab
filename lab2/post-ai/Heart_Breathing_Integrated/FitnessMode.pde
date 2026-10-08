// ========================================
// FITNESS MODE
// BME/CS 479 - Lab 2
// ========================================

// FITNESS STATES
final int FITNESS_AGE = 0;
final int FITNESS_BASELINE = 1;
final int FITNESS_READY = 2;
final int FITNESS_ACTIVE = 3;
final int FITNESS_COMPLETE = 4;

int fitnessState = FITNESS_AGE;


// ========================================
// USER INFORMATION
// ========================================

String fitnessAgeText = "";
String fitnessAgeError = "";

int fitnessAge = 0;
int fitnessMaxHR = 0;


// ========================================
// ACTIVITY SELECTION + ANIMATION
// ========================================

String[] fitnessActivities = {
  "WALKING",
  "RUNNING",
  "CYCLING",
  "STAIRS",
  "OTHER"
};

int fitnessSelectedActivity = -1;

float fitnessAnimationPhase = 0;


// ========================================
// BASELINE
// ========================================

final int FITNESS_BASELINE_DURATION = 30000;
final int FITNESS_SAMPLE_INTERVAL = 1000;

int fitnessBaselineStart = 0;
int fitnessLastBaselineSample = 0;

float fitnessBaselineHRSum = 0;
float fitnessBaselineRRSum = 0;

int fitnessBaselineHRSamples = 0;
int fitnessBaselineRRSamples = 0;

float fitnessRestingHR = 0;
float fitnessRestingRR = 0;


// Breathing-duration baseline

float fitnessBaselineInhaleSum = 0;
float fitnessBaselineExhaleSum = 0;

int fitnessBaselineBreathSamples = 0;

float fitnessBaselineInhale = 0;
float fitnessBaselineExhale = 0;

float fitnessLastBaselineInhale = -1;
float fitnessLastBaselineExhale = -1;


// ========================================
// CARDIO ZONES
// ========================================

final int ZONE_BELOW = 0;
final int ZONE_VERY_LIGHT = 1;
final int ZONE_LIGHT = 2;
final int ZONE_MODERATE = 3;
final int ZONE_HARD = 4;
final int ZONE_MAXIMUM = 5;

final int FITNESS_ZONE_COUNT = 6;

int fitnessCurrentZone = ZONE_BELOW;


// Time spent in each zone

float[] fitnessZoneTime =
  new float[FITNESS_ZONE_COUNT];


// Respiratory rate per zone

float[] fitnessZoneRRSum =
  new float[FITNESS_ZONE_COUNT];

int[] fitnessZoneRRSamples =
  new int[FITNESS_ZONE_COUNT];


// Inhale / exhale per zone

float[] fitnessZoneInhaleSum =
  new float[FITNESS_ZONE_COUNT];

float[] fitnessZoneExhaleSum =
  new float[FITNESS_ZONE_COUNT];

int[] fitnessZoneBreathSamples =
  new int[FITNESS_ZONE_COUNT];


// ========================================
// SESSION TRACKING
// ========================================

int fitnessSessionStart = 0;
int fitnessPreviousUpdate = 0;
int fitnessLastZoneSample = 0;

float fitnessLastSessionInhale = -1;
float fitnessLastSessionExhale = -1;


// ========================================
// MAIN FITNESS FUNCTION
// ========================================

void drawFitness() {

  if (fitnessState == FITNESS_AGE) {

    drawFitnessAge();
  }

  else if (fitnessState == FITNESS_BASELINE) {

    updateFitnessBaseline();
    drawFitnessBaseline();
  }

  else if (fitnessState == FITNESS_READY) {

    drawFitnessReady();
  }

  else if (fitnessState == FITNESS_ACTIVE) {

    updateFitnessSession();
    drawFitnessDashboard();
  }

  else if (fitnessState == FITNESS_COMPLETE) {

    drawFitnessResults();
  }
}


// ========================================
// AGE SCREEN
// ========================================

void drawFitnessAge() {

  fill(0);
  textSize(24);

  text(
    "FITNESS MODE",
    30,
    170
  );


  textSize(18);

  text(
    "Enter your age to calculate your maximum heart rate:",
    30,
    220
  );


  stroke(0);
  fill(255);

  rect(
    30,
    250,
    200,
    50
  );


  fill(0);
  textSize(22);


  if (fitnessAgeText.length() > 0) {

    text(
      fitnessAgeText,
      45,
      283
    );
  }

  else {

    fill(150);

    text(
      "Age",
      45,
      283
    );
  }


  fill(0);
  textSize(15);

  text(
    "Type your age and press ENTER",
    30,
    330
  );


  if (fitnessAgeError.length() > 0) {

    fill(255, 0, 0);

    text(
      fitnessAgeError,
      30,
      365
    );
  }
}


// ========================================
// START BASELINE
// ========================================

void startFitnessBaseline() {

  fitnessBaselineStart = millis();
  fitnessLastBaselineSample = 0;

  fitnessBaselineHRSum = 0;
  fitnessBaselineRRSum = 0;

  fitnessBaselineHRSamples = 0;
  fitnessBaselineRRSamples = 0;

  fitnessBaselineInhaleSum = 0;
  fitnessBaselineExhaleSum = 0;

  fitnessBaselineBreathSamples = 0;

  fitnessRestingHR = 0;
  fitnessRestingRR = 0;

  fitnessBaselineInhale = 0;
  fitnessBaselineExhale = 0;

  fitnessLastBaselineInhale = -1;
  fitnessLastBaselineExhale = -1;

  fitnessSelectedActivity = -1;

  fitnessState = FITNESS_BASELINE;
}


// ========================================
// UPDATE BASELINE
// ========================================

void updateFitnessBaseline() {

  int now = millis();


  // Sample HR/RR once per second.

  if (
    fitnessLastBaselineSample == 0 ||
    now - fitnessLastBaselineSample
    >= FITNESS_SAMPLE_INTERVAL
  ) {

    int currentHR = getHeartRate();
    float currentRR = getRespRate();


    if (currentHR > 0) {

      fitnessBaselineHRSum += currentHR;
      fitnessBaselineHRSamples++;
    }


    if (currentRR > 0) {

      fitnessBaselineRRSum += currentRR;
      fitnessBaselineRRSamples++;
    }


    fitnessLastBaselineSample = now;
  }


  // Record unique breath measurements.

  float inhale = getInhaleTime();
  float exhale = getExhaleTime();


  if (
    inhale > 0 &&
    exhale > 0 &&
    (
      inhale != fitnessLastBaselineInhale ||
      exhale != fitnessLastBaselineExhale
    )
  ) {

    fitnessBaselineInhaleSum += inhale;
    fitnessBaselineExhaleSum += exhale;

    fitnessBaselineBreathSamples++;

    fitnessLastBaselineInhale = inhale;
    fitnessLastBaselineExhale = exhale;
  }


  if (
    now - fitnessBaselineStart
    >= FITNESS_BASELINE_DURATION
  ) {

    finishFitnessBaseline();
  }
}


// ========================================
// FINISH BASELINE
// ========================================

void finishFitnessBaseline() {

  if (fitnessBaselineHRSamples > 0) {

    fitnessRestingHR =
      fitnessBaselineHRSum /
      fitnessBaselineHRSamples;
  }


  if (fitnessBaselineRRSamples > 0) {

    fitnessRestingRR =
      fitnessBaselineRRSum /
      fitnessBaselineRRSamples;
  }


  if (fitnessBaselineBreathSamples > 0) {

    fitnessBaselineInhale =
      fitnessBaselineInhaleSum /
      fitnessBaselineBreathSamples;


    fitnessBaselineExhale =
      fitnessBaselineExhaleSum /
      fitnessBaselineBreathSamples;
  }


  fitnessState = FITNESS_READY;
}


// ========================================
// BASELINE SCREEN
// ========================================

void drawFitnessBaseline() {

  float elapsed =
    millis() - fitnessBaselineStart;


  float remaining =
    max(
      0,
      FITNESS_BASELINE_DURATION - elapsed
    );


  float secondsRemaining =
    remaining / 1000.0;


  fill(0);

  textSize(24);

  text(
    "FITNESS MODE - BASELINE",
    30,
    170
  );


  textSize(18);

  text(
    "Remain still while a 30-second baseline is recorded.",
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


  text(
    "Inhale: "
    + nf(getInhaleTime(), 0, 2)
    + " sec",
    30,
    405
  );


  text(
    "Exhale: "
    + nf(getExhaleTime(), 0, 2)
    + " sec",
    260,
    405
  );


  float progress =
    constrain(
      elapsed /
      FITNESS_BASELINE_DURATION,
      0,
      1
    );


  stroke(0);
  noFill();

  rect(
    30,
    450,
    500,
    25
  );


  noStroke();
  fill(0, 150, 0);

  rect(
    30,
    450,
    500 * progress,
    25
  );
}


// ========================================
// READY / ACTIVITY SELECTION SCREEN
// ========================================

void drawFitnessReady() {

  fill(0);

  textSize(24);

  text(
    "FITNESS MODE - BASELINE COMPLETE",
    30,
    150
  );


  textSize(16);

  text(
    "Resting HR: "
    + nf(fitnessRestingHR, 0, 1)
    + " BPM",
    30,
    190
  );


  text(
    "Resting RR: "
    + nf(fitnessRestingRR, 0, 1)
    + " breaths/min",
    270,
    190
  );


  text(
    "Baseline inhale: "
    + nf(fitnessBaselineInhale, 0, 2)
    + " sec",
    30,
    225
  );


  text(
    "Baseline exhale: "
    + nf(fitnessBaselineExhale, 0, 2)
    + " sec",
    270,
    225
  );


  text(
    "Estimated Maximum HR: "
    + fitnessMaxHR
    + " BPM",
    30,
    260
  );


  // --------------------------------------
  // Activity selection
  // --------------------------------------

  textSize(18);

  text(
    "Select Activity:",
    30,
    315
  );


  for (
    int i = 0;
    i < fitnessActivities.length;
    i++
  ) {

    float x =
      30 + i * 185;

    float y = 340;


    if (
      fitnessSelectedActivity == i
    ) {

      fill(80, 160, 255);
    }

    else {

      fill(220);
    }


    stroke(0);

    rect(
      x,
      y,
      165,
      45
    );


    fill(0);
    textSize(14);

    text(
      fitnessActivities[i],
      x + 20,
      y + 28
    );
  }


  // Selected activity

  fill(0);
  textSize(16);


  if (
    fitnessSelectedActivity >= 0
  ) {

    text(
      "Selected: "
      + fitnessActivities[
          fitnessSelectedActivity
        ],
      30,
      425
    );
  }

  else {

    text(
      "Select an activity before starting.",
      30,
      425
    );
  }


  // --------------------------------------
  // Start button
  // --------------------------------------

  if (
    fitnessSelectedActivity >= 0
  ) {

    fill(0, 150, 0);
  }

  else {

    fill(150);
  }


  rect(
    30,
    460,
    250,
    55
  );


  fill(255);
  textSize(18);

  text(
    "START ACTIVITY",
    75,
    495
  );
}


// ========================================
// START FITNESS SESSION
// ========================================

void startFitnessSession() {

  fitnessSessionStart = millis();

  fitnessPreviousUpdate = millis();
  fitnessLastZoneSample = 0;

  fitnessLastSessionInhale = -1;
  fitnessLastSessionExhale = -1;

  fitnessAnimationPhase = 0;


  for (
    int i = 0;
    i < FITNESS_ZONE_COUNT;
    i++
  ) {

    fitnessZoneTime[i] = 0;

    fitnessZoneRRSum[i] = 0;
    fitnessZoneRRSamples[i] = 0;

    fitnessZoneInhaleSum[i] = 0;
    fitnessZoneExhaleSum[i] = 0;

    fitnessZoneBreathSamples[i] = 0;
  }


  fitnessCurrentZone =
    ZONE_BELOW;

  fitnessState =
    FITNESS_ACTIVE;
}


// ========================================
// UPDATE FITNESS SESSION
// ========================================

void updateFitnessSession() {

  int now = millis();

  int currentHR =
    getHeartRate();


  // --------------------------------------
  // Determine cardio zone
  // --------------------------------------

  if (
    currentHR > 0 &&
    fitnessMaxHR > 0
  ) {

    float percentage =
      100.0 *
      currentHR /
      fitnessMaxHR;


    fitnessCurrentZone =
      classifyFitnessZone(
        percentage
      );
  }

  else {

    fitnessCurrentZone =
      ZONE_BELOW;
  }


  // --------------------------------------
  // Track time in cardio zone
  // --------------------------------------

  float deltaSeconds =
    (
      now -
      fitnessPreviousUpdate
    )
    / 1000.0;


  if (
    fitnessCurrentZone >= 0 &&
    fitnessCurrentZone <
    FITNESS_ZONE_COUNT
  ) {

    fitnessZoneTime[
      fitnessCurrentZone
    ] += deltaSeconds;
  }


  fitnessPreviousUpdate = now;


  // --------------------------------------
  // Respiratory rate by zone
  // --------------------------------------

  if (
    fitnessLastZoneSample == 0 ||
    now - fitnessLastZoneSample
    >= FITNESS_SAMPLE_INTERVAL
  ) {

    float currentRR =
      getRespRate();


    if (
      currentRR > 0 &&
      fitnessCurrentZone >= 0 &&
      fitnessCurrentZone <
      FITNESS_ZONE_COUNT
    ) {

      fitnessZoneRRSum[
        fitnessCurrentZone
      ] += currentRR;


      fitnessZoneRRSamples[
        fitnessCurrentZone
      ]++;
    }


    fitnessLastZoneSample = now;
  }


  // --------------------------------------
  // Inhale / exhale by zone
  // --------------------------------------

  float inhale =
    getInhaleTime();

  float exhale =
    getExhaleTime();


  if (
    inhale > 0 &&
    exhale > 0 &&
    (
      inhale != fitnessLastSessionInhale ||
      exhale != fitnessLastSessionExhale
    )
  ) {

    if (
      fitnessCurrentZone >= 0 &&
      fitnessCurrentZone <
      FITNESS_ZONE_COUNT
    ) {

      fitnessZoneInhaleSum[
        fitnessCurrentZone
      ] += inhale;


      fitnessZoneExhaleSum[
        fitnessCurrentZone
      ] += exhale;


      fitnessZoneBreathSamples[
        fitnessCurrentZone
      ]++;
    }


    fitnessLastSessionInhale = inhale;
    fitnessLastSessionExhale = exhale;
  }
}


// ========================================
// CARDIO ZONE CLASSIFICATION
// ========================================

int classifyFitnessZone(
  float percentage
) {

  if (percentage < 50) {
    return ZONE_BELOW;
  }

  else if (percentage < 60) {
    return ZONE_VERY_LIGHT;
  }

  else if (percentage < 70) {
    return ZONE_LIGHT;
  }

  else if (percentage < 80) {
    return ZONE_MODERATE;
  }

  else if (percentage < 90) {
    return ZONE_HARD;
  }

  else {
    return ZONE_MAXIMUM;
  }
}


// ========================================
// ZONE NAME
// ========================================

String fitnessZoneName(
  int zone
) {

  if (zone == ZONE_VERY_LIGHT) {
    return "VERY LIGHT (50-60%)";
  }

  if (zone == ZONE_LIGHT) {
    return "LIGHT (60-70%)";
  }

  if (zone == ZONE_MODERATE) {
    return "MODERATE (70-80%)";
  }

  if (zone == ZONE_HARD) {
    return "HARD (80-90%)";
  }

  if (zone == ZONE_MAXIMUM) {
    return "MAXIMUM (90-100%)";
  }

  return "BELOW TRAINING ZONE";
}


// ========================================
// ZONE AVERAGE HELPERS
// ========================================

float getFitnessZoneRR(
  int zone
) {

  if (
    fitnessZoneRRSamples[zone]
    == 0
  ) {

    return 0;
  }


  return
    fitnessZoneRRSum[zone] /
    fitnessZoneRRSamples[zone];
}


float getFitnessZoneInhale(
  int zone
) {

  if (
    fitnessZoneBreathSamples[zone]
    == 0
  ) {

    return 0;
  }


  return
    fitnessZoneInhaleSum[zone] /
    fitnessZoneBreathSamples[zone];
}


float getFitnessZoneExhale(
  int zone
) {

  if (
    fitnessZoneBreathSamples[zone]
    == 0
  ) {

    return 0;
  }


  return
    fitnessZoneExhaleSum[zone] /
    fitnessZoneBreathSamples[zone];
}


// ========================================
// CHANGE FROM BASELINE
// ========================================

float getFitnessRRChange(
  int zone
) {

  if (
    fitnessZoneRRSamples[zone] == 0 ||
    fitnessRestingRR <= 0
  ) {

    return 0;
  }


  return
    getFitnessZoneRR(zone) -
    fitnessRestingRR;
}


float getFitnessInhaleChange(
  int zone
) {

  if (
    fitnessZoneBreathSamples[zone] == 0 ||
    fitnessBaselineInhale <= 0
  ) {

    return 0;
  }


  return
    getFitnessZoneInhale(zone) -
    fitnessBaselineInhale;
}


float getFitnessExhaleChange(
  int zone
) {

  if (
    fitnessZoneBreathSamples[zone] == 0 ||
    fitnessBaselineExhale <= 0
  ) {

    return 0;
  }


  return
    getFitnessZoneExhale(zone) -
    fitnessBaselineExhale;
}


// ========================================
// ACTIVE FITNESS DASHBOARD
// ========================================

void drawFitnessDashboard() {

  fill(0);

  textSize(23);

  text(
    "FITNESS MODE",
    30,
    145
  );


  // --------------------------------------
  // Live measurements
  // --------------------------------------

  textSize(15);

  text(
    "HR: "
    + getHeartRate()
    + " BPM",
    30,
    180
  );


  text(
    "RR: "
    + nf(getRespRate(), 0, 1),
    155,
    180
  );


  text(
    "Inhale: "
    + nf(getInhaleTime(), 0, 2)
    + " s",
    270,
    180
  );


  text(
    "Exhale: "
    + nf(getExhaleTime(), 0, 2)
    + " s",
    410,
    180
  );


  text(
    "Max HR: "
    + fitnessMaxHR,
    555,
    180
  );


  if (
    fitnessSelectedActivity >= 0
  ) {

    text(
      "Activity: "
      + fitnessActivities[
          fitnessSelectedActivity
        ],
      700,
      180
    );
  }


  // --------------------------------------
  // Current cardio zone
  // --------------------------------------

  textSize(19);

  text(
    "Cardio Zone: "
    + fitnessZoneName(
      fitnessCurrentZone
    ),
    30,
    215
  );


  // =====================================
  // ECG GRAPH
  // =====================================

  stroke(0);
  noFill();

  rect(
    30,
    240,
    560,
    105
  );


  fill(0);
  textSize(13);

  text(
    "ECG",
    40,
    260
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
          570
        );


float y =
        map(
          ecgPlot.get(i),
          ecgDisplayMin,
          ecgDisplayMax,
          335,
          270
        );

      y = constrain(y, 270, 335);


      vertex(x, y);
    }


    endShape();
  }


  // =====================================
  // ANIMATED PERSON
  // =====================================

  drawFitnessAnimation(
    790,
    300
  );


  // =====================================
  // CARDIO ZONE BAR
  // =====================================

  stroke(0);
  noFill();

  rect(
    30,
    365,
    560,
    85
  );


  fill(0);
  textSize(13);

  text(
    "CARDIO ZONES",
    40,
    385
  );


  drawFitnessZoneBar();


  // =====================================
  // RESPIRATION GRAPH
  // =====================================

  stroke(0);
  noFill();

  rect(
    30,
    470,
    560,
    110
  );


  fill(0);

  text(
    "RESPIRATION",
    40,
    490
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
          570
        );


      float y =
        map(
          fsrPlot.get(i),
          0,
          1023,
          570,
          505
        );


      vertex(x, y);
    }


    endShape();
  }


  // =====================================
  // CURRENT ZONE CHANGES
  // =====================================

  fill(0);
  textSize(14);

  text(
    "CURRENT ZONE CHANGE",
    650,
    455
  );


  text(
    "FROM BASELINE",
    650,
    475
  );


  if (
    fitnessZoneRRSamples[
      fitnessCurrentZone
    ] > 0
  ) {

    text(
      "RR: "
      + signedFitnessValue(
          getFitnessRRChange(
            fitnessCurrentZone
          )
        )
      + " breaths/min",
      650,
      510
    );
  }

  else {

    text(
      "RR: --",
      650,
      510
    );
  }


  if (
    fitnessZoneBreathSamples[
      fitnessCurrentZone
    ] > 0
  ) {

    text(
      "Inhale: "
      + signedFitnessValue(
          getFitnessInhaleChange(
            fitnessCurrentZone
          )
        )
      + " sec",
      650,
      540
    );


    text(
      "Exhale: "
      + signedFitnessValue(
          getFitnessExhaleChange(
            fitnessCurrentZone
          )
        )
      + " sec",
      650,
      570
    );
  }

  else {

    text(
      "Inhale: --",
      650,
      540
    );


    text(
      "Exhale: --",
      650,
      570
    );
  }


  // =====================================
  // END ACTIVITY BUTTON
  // =====================================

  fill(200, 0, 0);

  rect(
    650,
    610,
    220,
    50
  );


  fill(255);
  textSize(17);

  text(
    "END ACTIVITY",
    695,
    642
  );


  stroke(0);
}


// ========================================
// FITNESS ANIMATION
// ========================================

void drawFitnessAnimation(float centerX, float centerY) {
  fitnessAnimationPhase += getFitnessAnimationSpeed();
  float p = fitnessAnimationPhase;
  float stride = sin(p);
  float alternate = sin(p + PI);
  float intensity = 0.35 + 0.15 * max(0, fitnessCurrentZone);
  int activity = fitnessSelectedActivity;

  stroke(0);
  strokeWeight(1);
  noFill();
  rect(centerX - 145, centerY - 70, 290, 145);

  pushMatrix();
  translate(centerX, centerY);
  stroke(25);
  strokeWeight(4);
  noFill();

  if (activity == 2) {  // CYCLING: pedal around two wheels
    float crank = p * 1.5;
    strokeWeight(2);
    ellipse(-65, 40, 55, 55);
    ellipse(65, 40, 55, 55);
    line(-65, 40, -22, 0);
    line(-22, 0, 0, 40);
    line(0, 40, -65, 40);
    line(-22, 0, 65, 40);
    line(-22, 0, 8, -5);
    line(8, -5, 28, -5);
    strokeWeight(4);
    ellipse(-10, -43, 22, 22);
    line(-7, -32, -22, -4);
    line(-22, -4, 8, -5);
    line(-22, -4, -40, 7);
    line(-22, -4, 0, 40);
    line(0, 40, 13 * cos(crank), 40 + 13 * sin(crank));
    line(0, 40, -13 * cos(crank), 40 - 13 * sin(crank));
  } else if (activity == 3) {  // STAIRS: alternating step heights
    strokeWeight(2);
    line(-125, 60, -65, 60);
    line(-65, 60, -65, 38);
    line(-65, 38, -5, 38);
    line(-5, 38, -5, 16);
    line(-5, 16, 55, 16);
    line(55, 16, 55, -6);
    line(55, -6, 120, -6);
    strokeWeight(4);
    float lift = 15 * abs(stride) * intensity;
    ellipse(0, -42 - lift, 23, 23);
    line(0, -30 - lift, 0, 9 - lift);
    line(0, -18 - lift, -24, 2 - lift + 7 * stride);
    line(0, -18 - lift, 24, 2 - lift - 7 * stride);
    line(0, 9 - lift, -25, 42 - lift - 15 * stride);
    line(0, 9 - lift, 25, 42 - lift + 15 * stride);
  } else {  // WALKING, RUNNING, OTHER
    float amplitude = (activity == 1 ? 33 : activity == 4 ? 18 : 23) * intensity;
    float bounce = (activity == 1 ? 11 : activity == 4 ? 7 : 3) * abs(stride) * intensity;
    float arm = amplitude * stride;
    float leg = amplitude * stride;
    ellipse(0, -35 - bounce, 25, 25);
    line(0, -22 - bounce, 0, 18 - bounce);
    if (activity == 4) {  // OTHER: jumping-jack style exercise
      float spread = 12 + 16 * abs(stride) * intensity;
      line(0, -12 - bounce, -spread, -30 - bounce);
      line(0, -12 - bounce, spread, -30 - bounce);
      line(0, 18 - bounce, -spread, 49 - bounce);
      line(0, 18 - bounce, spread, 49 - bounce);
    } else {
      line(0, -12 - bounce, -27, 10 - bounce + arm);
      line(0, -12 - bounce, 27, 10 - bounce - arm);
      line(0, 18 - bounce, -24 - leg, 48 - bounce);
      line(0, 18 - bounce, 24 + leg, 48 - bounce);
    }
  }
  popMatrix();
  strokeWeight(1);
  fill(0);
  textAlign(CENTER);
  textSize(14);
  if (activity >= 0 && activity < fitnessActivities.length) {
    text(fitnessActivities[activity], centerX, centerY + 95);
  }
  textSize(13);
  text(fitnessAnimationLabel(), centerX, centerY + 115);
  textAlign(LEFT);
}


// ========================================
// ANIMATION SPEED
// ========================================

float getFitnessAnimationSpeed() {

  if (
    fitnessCurrentZone ==
    ZONE_BELOW
  ) {

    return 0.03;
  }


  if (
    fitnessCurrentZone ==
    ZONE_VERY_LIGHT
  ) {

    return 0.06;
  }


  if (
    fitnessCurrentZone ==
    ZONE_LIGHT
  ) {

    return 0.10;
  }


  if (
    fitnessCurrentZone ==
    ZONE_MODERATE
  ) {

    return 0.16;
  }


  if (
    fitnessCurrentZone ==
    ZONE_HARD
  ) {

    return 0.25;
  }


  return 0.38;
}


// ========================================
// ANIMATION EFFORT LABEL
// ========================================

String fitnessAnimationLabel() {

  if (
    fitnessCurrentZone ==
    ZONE_BELOW
  ) {

    return "WARMING UP";
  }


  if (
    fitnessCurrentZone ==
    ZONE_VERY_LIGHT
  ) {

    return "VERY LIGHT EFFORT";
  }


  if (
    fitnessCurrentZone ==
    ZONE_LIGHT
  ) {

    return "LIGHT EFFORT";
  }


  if (
    fitnessCurrentZone ==
    ZONE_MODERATE
  ) {

    return "MODERATE EFFORT";
  }


  if (
    fitnessCurrentZone ==
    ZONE_HARD
  ) {

    return "HARD EFFORT";
  }


  return "MAXIMUM EFFORT!";
}


// ========================================
// CARDIO ZONE BAR
// ========================================

void drawFitnessZoneBar() {
  // Reference palette: Very Light gray, Light blue,
  // Moderate green, Hard orange, Maximum red.
  // Each section occupies 95 px, matching the original dashboard.
  int[] zoneColors = {
    color(155, 155, 155),  // Very Light (50-60%)
    color(61, 157, 219),   // Light (60-70%)
    color(42, 157, 91),    // Moderate (70-80%)
    color(241, 169, 43),   // Hard (80-90%)
    color(215, 42, 61)     // Maximum (90-100%)
  };

  String[] zoneLabels = {
    "VERY LIGHT", "LIGHT", "MODERATE", "HARD", "MAXIMUM"
  };
  String[] zoneRanges = {
    "50-60%", "60-70%", "70-80%", "80-90%", "90-100%"
  };

  float left = 50;
  float top = 399;
  float segmentWidth = 95;
  float barHeight = 25;

  textAlign(CENTER, CENTER);
  textSize(10);
  noStroke();

  for (int i = 0; i < 5; i++) {
    float x = left + i * segmentWidth;
    fill(zoneColors[i]);
    rect(x, top, segmentWidth, barHeight);
    fill(255);
    text(zoneLabels[i], x + segmentWidth / 2, top + 7);
    text(zoneRanges[i], x + segmentWidth / 2, top + 18);
  }

  // Move the marker within its zone using the live heart-rate
  // percentage, rather than snapping to the center of a zone.
  if (fitnessCurrentZone >= ZONE_VERY_LIGHT && fitnessMaxHR > 0) {
    float percent = 100.0 * getHeartRate() / fitnessMaxHR;
    float markerX = map(constrain(percent, 50, 100),
                        50, 100, left, left + 5 * segmentWidth);
    markerX = constrain(markerX, left + 3, left + 5 * segmentWidth - 3);

    // White outline makes the colored pointer visible on every band.
    stroke(255);
    strokeWeight(2);
    fill(zoneColors[fitnessCurrentZone - ZONE_VERY_LIGHT]);
    triangle(markerX - 8, top + barHeight + 12,
             markerX + 8, top + barHeight + 12,
             markerX, top + barHeight + 1);
    strokeWeight(1);
    noStroke();
  } else {
    fill(90);
    textSize(10);
    text("Below 50% max HR", left + 5 * segmentWidth / 2,
         top + barHeight + 10);
  }

  // Restore default text alignment for other Fitness UI elements.
  textAlign(LEFT, BASELINE);
  stroke(0);
}


// ========================================
// SIGNED VALUE DISPLAY
// ========================================

String signedFitnessValue(
  float value
) {

  if (value > 0) {

    return "+"
      + nf(value, 0, 2);
  }


  return nf(value, 0, 2);
}


// ========================================
// FINISH FITNESS SESSION
// ========================================

void finishFitnessSession() {

  fitnessState =
    FITNESS_COMPLETE;
}


// ========================================
// RESULTS SCREEN
// ========================================

void drawFitnessResults() {

  fill(0);

  textSize(24);

  text(
    "FITNESS ACTIVITY RESULTS",
    30,
    145
  );


  textSize(15);


  if (
    fitnessSelectedActivity >= 0
  ) {

    text(
      "Activity: "
      + fitnessActivities[
          fitnessSelectedActivity
        ],
      30,
      175
    );
  }


  textSize(12);

  text(
    "Changes are relative to the 30-second resting baseline.",
    250,
    175
  );


  // Headers

  text(
    "ZONE",
    30,
    220
  );

  text(
    "TIME",
    260,
    220
  );

  text(
    "DELTA RR",
    365,
    220
  );

  text(
    "DELTA INHALE",
    490,
    220
  );

  text(
    "DELTA EXHALE",
    650,
    220
  );


  int y = 260;


  for (
    int zone = ZONE_VERY_LIGHT;
    zone <= ZONE_MAXIMUM;
    zone++
  ) {

    fill(0);


    text(
      fitnessZoneName(zone),
      30,
      y
    );


    text(
      nf(
        fitnessZoneTime[zone],
        0,
        1
      )
      + " s",
      260,
      y
    );


    if (
      fitnessZoneRRSamples[zone]
      > 0
    ) {

      text(
        signedFitnessValue(
          getFitnessRRChange(zone)
        ),
        365,
        y
      );
    }

    else {

      text(
        "--",
        365,
        y
      );
    }


    if (
      fitnessZoneBreathSamples[zone]
      > 0
    ) {

      text(
        signedFitnessValue(
          getFitnessInhaleChange(zone)
        )
        + " s",
        490,
        y
      );


      text(
        signedFitnessValue(
          getFitnessExhaleChange(zone)
        )
        + " s",
        650,
        y
      );
    }

    else {

      text(
        "--",
        490,
        y
      );


      text(
        "--",
        650,
        y
      );
    }


    y += 55;
  }


  // --------------------------------------
  // Baseline reference
  // --------------------------------------

  textSize(13);

  text(
    "Baseline HR: "
    + nf(fitnessRestingHR, 0, 1)
    + " BPM",
    30,
    565
  );


  text(
    "Baseline RR: "
    + nf(fitnessRestingRR, 0, 1),
    230,
    565
  );


  text(
    "Baseline inhale: "
    + nf(fitnessBaselineInhale, 0, 2)
    + " s",
    430,
    565
  );


  text(
    "Baseline exhale: "
    + nf(fitnessBaselineExhale, 0, 2)
    + " s",
    650,
    565
  );


  // --------------------------------------
  // New session button
  // --------------------------------------

  fill(0, 150, 0);

  rect(
    30,
    610,
    220,
    50
  );


  fill(255);

  textSize(16);

  text(
    "NEW FITNESS SESSION",
    52,
    642
  );
}


// ========================================
// RESET FITNESS
// ========================================

void resetFitnessMode() {

  fitnessAgeText = "";
  fitnessAgeError = "";

  fitnessAge = 0;
  fitnessMaxHR = 0;

  fitnessSelectedActivity = -1;

  fitnessAnimationPhase = 0;

  fitnessState =
    FITNESS_AGE;
}


// ========================================
// FITNESS MOUSE INPUT
// ========================================

void fitnessMousePressed() {

  // --------------------------------------
  // Activity selection / start
  // --------------------------------------

  if (
    fitnessState ==
    FITNESS_READY
  ) {

    // Activity buttons

    for (
      int i = 0;
      i < fitnessActivities.length;
      i++
    ) {

      float x =
        30 + i * 185;


      if (
        mouseX >= x &&
        mouseX <= x + 165 &&
        mouseY >= 340 &&
        mouseY <= 385
      ) {

        fitnessSelectedActivity = i;

        return;
      }
    }


    // Start activity

    if (
      fitnessSelectedActivity >= 0 &&
      mouseX >= 30 &&
      mouseX <= 280 &&
      mouseY >= 460 &&
      mouseY <= 515
    ) {

      startFitnessSession();

      return;
    }
  }


  // --------------------------------------
  // End activity
  // --------------------------------------

  if (
    fitnessState ==
    FITNESS_ACTIVE
  ) {

    if (
      mouseX >= 650 &&
      mouseX <= 870 &&
      mouseY >= 610 &&
      mouseY <= 660
    ) {

      finishFitnessSession();

      return;
    }
  }


  // --------------------------------------
  // New fitness session
  // --------------------------------------

  if (
    fitnessState ==
    FITNESS_COMPLETE
  ) {

    if (
      mouseX >= 30 &&
      mouseX <= 250 &&
      mouseY >= 610 &&
      mouseY <= 660
    ) {

      resetFitnessMode();

      return;
    }
  }
}


// ========================================
// FITNESS KEYBOARD INPUT
// ========================================

void fitnessKeyPressed() {

  if (
    fitnessState !=
    FITNESS_AGE
  ) {

    return;
  }


  if (
    key >= '0' &&
    key <= '9'
  ) {

    if (
      fitnessAgeText.length()
      < 3
    ) {

      fitnessAgeText += key;
    }
  }


  else if (
    key == BACKSPACE
  ) {

    if (
      fitnessAgeText.length()
      > 0
    ) {

      fitnessAgeText =
        fitnessAgeText.substring(
          0,
          fitnessAgeText.length() - 1
        );
    }
  }


  else if (
    key == ENTER ||
    key == RETURN
  ) {

    if (
      fitnessAgeText.length()
      == 0
    ) {

      fitnessAgeError =
        "Please enter an age.";

      return;
    }


    fitnessAge =
      int(
        fitnessAgeText
      );


    if (
      fitnessAge <= 0 ||
      fitnessAge > 120
    ) {

      fitnessAgeError =
        "Please enter a valid age.";

      return;
    }


    fitnessAgeError = "";


    // Lab 2 maximum HR approximation
    fitnessMaxHR =
      220 - fitnessAge;


    startFitnessBaseline();
  }
}