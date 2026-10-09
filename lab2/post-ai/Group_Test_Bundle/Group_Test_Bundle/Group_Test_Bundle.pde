import processing.serial.*;
import java.util.ArrayList;

// ===== ORIGINAL TAB: Heart_Breathing_Integrated.pde =====
// ========================================
// HEART + BREATHING MONITOR
// BME/CS 479 - Lab 2
// Post-AI Integrated Processing UI
// ========================================

// MODES
final int MODE_HOME = 0;
final int MODE_FITNESS = 1;
final int MODE_STRESS = 2;
final int MODE_MEDITATION = 3;

int mode = MODE_HOME;


// ========================================
// LIVE SENSOR VALUES
// ========================================

int getHeartRate() {
  return BPM;
}

float getRespRate() {
  return respiratoryRate;
}

float getInhaleTime() {
  return Tinsp / 1000.0;
}

float getExhaleTime() {
  return Tex / 1000.0;
}


// ========================================
// SETUP
// ========================================

void setup() {

  size(1000, 700);

  setupSignalProcessing();
}


// ========================================
// MAIN LOOP
// ========================================

void draw() {

  background(245, 249, 254);

  drawAppChrome();
  drawHeader();
  drawNavigation();

  if (mode == MODE_HOME) {

    drawHome();
  }

  else if (mode == MODE_FITNESS) {

    drawFitness();
  }

  else if (mode == MODE_STRESS) {

    drawStress();
  }

  else if (mode == MODE_MEDITATION) {

    drawMeditation();
  }
}


// ========================================
// HEADER
// ========================================

void drawHeader() {
  pushStyle();
  fill(27, 49, 80);textAlign(LEFT,BASELINE);
  textSize(28);text("Heart + Breathing Monitor",30,42);
  fill(91,111,137);textSize(12);
  text("LIVE PHYSIOLOGICAL MONITORING",705,40);
  popStyle();
}


// ========================================
// NAVIGATION
// ========================================

void drawNavigation() {
  pushStyle();
  String[] names={"HOME","FITNESS","STRESS","MEDITATION"};
  int[] xs={30,165,330,495};
  int[] ws={120,150,150,170};
  for(int i=0;i<4;i++) {
    boolean active=mode==i;
    noStroke();fill(active?color(37,105,187):color(229,237,248));
    rect(xs[i],65,ws[i],50,12);
    fill(active?color(255):color(56,77,106));
    textAlign(CENTER,CENTER);textSize(15);
    text(names[i],xs[i]+ws[i]/2,90);
  }
  textAlign(LEFT,BASELINE);textSize(12);
  fill(leadsOff?color(194,58,67):color(29,139,106));
  ellipse(781,91,9,9);
  text(leadsOff?"ECG LEADS OFF":"SENSOR ACTIVE",795,95);
  popStyle();
}


// ========================================
// HOME SCREEN
// ========================================

void drawHome() {

  fill(0);

  textSize(26);

  text(
    "Live Sensor Monitor",
    30,
    175
  );


  textSize(20);

  text(
    "Heart Rate:",
    30,
    235
  );


  textSize(32);

  text(
    getHeartRate()
    + " BPM",
    175,
    235
  );


  textSize(20);

  text(
    "Respiratory Rate:",
    30,
    290
  );


  textSize(32);

  text(
    nf(
      getRespRate(),
      0,
      1
    )
    + " breaths/min",
    220,
    290
  );


  textSize(18);

  text(
    "Inhale: "
    + nf(
      getInhaleTime(),
      0,
      2
    )
    + " sec",
    30,
    345
  );


  text(
    "Exhale: "
    + nf(
      getExhaleTime(),
      0,
      2
    )
    + " sec",
    250,
    345
  );


  // =====================================
  // ECG GRAPH
  // =====================================

  stroke(0);
  noFill();

  rect(
    30,
    390,
    440,
    180
  );


  fill(0);
  textSize(14);

  text(
    "ECG",
    40,
    410
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
          45,
          455
        );


      float y =
        map(
          ecgPlot.get(i),
          -512,
          512,
          550,
          425
        );

      // Keep ECG spikes inside the graph box.
      y = constrain(y, 425, 550);


      vertex(x, y);
    }


    endShape();
  }


  // =====================================
  // RESPIRATION GRAPH
  // =====================================

  stroke(0);
  noFill();

  rect(
    500,
    390,
    440,
    180
  );


  fill(0);

  text(
    "RESPIRATION",
    510,
    410
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
          515,
          925
        );


      float y =
        map(
          fsrPlot.get(i),
          0,
          1023,
          555,
          420
        );


      vertex(x, y);
    }


    endShape();
  }


  stroke(0);
}


// ========================================
// MOUSE INPUT
// ========================================

void mousePressed() {

  // --------------------------------------
  // HOME
  // --------------------------------------

  if (
    mouseX >= 30 &&
    mouseX <= 150 &&
    mouseY >= 65 &&
    mouseY <= 115
  ) {

    mode = MODE_HOME;

    return;
  }


  // --------------------------------------
  // FITNESS
  // --------------------------------------

  if (
    mouseX >= 165 &&
    mouseX <= 315 &&
    mouseY >= 65 &&
    mouseY <= 115
  ) {

    mode = MODE_FITNESS;

    return;
  }


  // --------------------------------------
  // STRESS
  // --------------------------------------

  if (
    mouseX >= 330 &&
    mouseX <= 480 &&
    mouseY >= 65 &&
    mouseY <= 115
  ) {

    mode = MODE_STRESS;

    return;
  }


  // --------------------------------------
  // MEDITATION
  // --------------------------------------

  if (
    mouseX >= 495 &&
    mouseX <= 665 &&
    mouseY >= 65 &&
    mouseY <= 115
  ) {

    mode = MODE_MEDITATION;

    return;
  }


  // --------------------------------------
  // MODE-SPECIFIC BUTTONS
  // --------------------------------------

  if (mode == MODE_FITNESS) {

    fitnessMousePressed();
  }

  else if (mode == MODE_STRESS) {

    stressMousePressed();
  }

  else if (mode == MODE_MEDITATION) {

    meditationMousePressed();
  }
}


// ========================================
// KEYBOARD INPUT
// ========================================

void keyPressed() {

  if (mode == MODE_FITNESS) {

    fitnessKeyPressed();
  }
}

void drawAppChrome() {
  pushStyle();
  noStroke();fill(231,240,252);rect(0,0,width,126);
  fill(255);rect(16,130,width-32,height-146,16);
  stroke(220,231,245);noFill();
  rect(16,130,width-32,height-146,16);
  popStyle();
}

// ===== ORIGINAL TAB: FitnessMode.pde =====
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

// Activity animations: feet are grounded and the staircase figure climbs.
void drawFitnessAnimation(float centerX, float centerY) {
  fitnessAnimationPhase += getFitnessAnimationSpeed();
  float phase = fitnessAnimationPhase;
  int activity = fitnessSelectedActivity;
  pushStyle();
  noStroke(); fill(239, 246, 255);
  rect(centerX-145, centerY-70, 290, 145, 14);
  stroke(209, 224, 243); noFill();
  rect(centerX-145, centerY-70, 290, 145, 14);
  pushMatrix();
  translate(centerX, centerY);
  if (activity == 3) {
    // The avatar's feet follow each stair tread, rising with each step.
    float progress = (phase * 0.30) % 4.0;
    int step = floor(progress);
    float stepFraction = progress - step;
    float x = -93 + progress * 46;
    float groundY = 45 - 13 * step;
    float rise = 13 * sin(stepFraction * HALF_PI);
    stroke(116, 140, 170); strokeWeight(2);
    for (int i=0; i<5; i++) {
      float sx=-116+i*46;
      float sy=45-i*13;
      line(sx,sy,sx+46,sy);
      if(i<4) line(sx+46,sy,sx+46,sy-13);
    }
    drawFitnessAvatar(x,groundY-rise,sin(phase*2),0.48);
  } else if (activity == 2) {
    float groundY=48;
    stroke(66,91,124);strokeWeight(2);noFill();
    ellipse(-65,groundY-24,47,47);
    ellipse(65,groundY-24,47,47);
    line(-65,groundY-24,-20,groundY-53);
    line(-20,groundY-53,0,groundY-24);
    line(0,groundY-24,-65,groundY-24);
    line(-20,groundY-53,65,groundY-24);
    line(-20,groundY-53,-15,groundY-64);
    line(-30,groundY-64,-4,groundY-64);
    line(65,groundY-24,48,groundY-70);
    line(40,groundY-70,60,groundY-70);
    float crank=phase*2.0;
    float pedalX=13*cos(crank);
    float pedalY=groundY-24+13*sin(crank);
    stroke(37,105,187);strokeWeight(4);
    line(-19,groundY-89,-23,groundY-58);
    line(-23,groundY-58,pedalX,pedalY);
    line(-19,groundY-89,48,groundY-70);
    fill(37,105,187);noStroke();
    ellipse(-19,groundY-101,18,18);
  } else if (activity == 4) {
    float spread=abs(sin(phase));
    stroke(37,105,187);strokeWeight(4);strokeCap(ROUND);
    float hip=18;
    line(0,hip-40,0,hip);
    line(0,hip-30,-15-20*spread,hip-53-6*spread);
    line(0,hip-30,15+20*spread,hip-53-6*spread);
    line(0,hip,-11-22*spread,49);
    line(0,hip,11+22*spread,49);
    fill(37,105,187);noStroke();ellipse(0,hip-51,19,19);
  } else {
    // Walk and run use opposing arm/leg swings and different bounce.
    float pace=activity==1 ? 1.9 : 1.0;
    float swing=sin(phase*pace);
    float bounce=(activity==1?6:2)*abs(swing);
    drawFitnessAvatar(0,49-bounce,swing,activity==1?0.95:0.52);
  }
  popMatrix();
  fill(33,55,83);textAlign(CENTER,BASELINE);
  textSize(12);
  if(activity>=0 && activity<fitnessActivities.length)
    text(fitnessActivities[activity],centerX,centerY-54);
  textSize(11);
  text(fitnessAnimationLabel(),centerX,centerY+68);
  popStyle();
}

// footY is the actual ground contact, not the figure's body center.
void drawFitnessAvatar(float x, float footY, float swing, float amount) {
  float hip=footY-20, shoulder=footY-42;
  stroke(37,105,187);strokeWeight(4);strokeCap(ROUND);
  line(x,shoulder,x,hip);
  line(x,shoulder+5,x-14,shoulder+19+swing*11*amount);
  line(x,shoulder+5,x+14,shoulder+19-swing*11*amount);
  line(x,hip,x-12-swing*12*amount,footY);
  line(x,hip,x+12+swing*12*amount,footY);
  noStroke();fill(37,105,187);ellipse(x,shoulder-11,18,18);
}


// A person drawn relative to the surface beneath their feet.
void drawFitnessPerson(float x, float footY, float stride, float amount) {
  float hip = footY - 31;
  float shoulder = footY - 66;
  stroke(34, 105, 178);
  strokeWeight(4);
  strokeCap(ROUND);
  line(x, shoulder, x, hip);
  line(x, shoulder + 9, x - 18, shoulder + 27 + stride * 13 * amount);
  line(x, shoulder + 9, x + 18, shoulder + 27 - stride * 13 * amount);
  line(x, hip, x - 13 - stride * 15 * amount, footY);
  line(x, hip, x + 13 + stride * 15 * amount, footY);
  fill(34, 105, 178);
  noStroke();
  ellipse(x, shoulder - 12, 20, 20);
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

// ===== ORIGINAL TAB: MeditationMode.pde =====
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
    "Missed breaths in a row: "
    + meditationFailedBreaths,
    500,
    302
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
          425,
          345
        );

      y = constrain(y, 345, 425);


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

// ===== ORIGINAL TAB: SignalProcessing.pde =====
Serial myPort;


// =====================================================
// VARIABLES
// =====================================================

// Raw signals received from Arduino
int ECG = 0;
int FSR = 0;


// ECG VARIABLES

// 1. SHORT ECG SMOOTHING
// Moving average of 3 samples. At approximately 200 Hz, 3 samples correspond to about 15 ms.

float[] ecgWindow = new float[3];

int ecgWindowIndex = 0;
int ecgWindowCount = 0;

float ecgSum = 0;

float ECG_filtered = 0;


// 2. BASELINE REMOVAL
//
// Arduino delay(5) -> sampling frequency approximately 200 Hz.
// A window of 200 samples therefore represents approximately 1 second.
// The average over this long window estimates the slowly-changing ECG baseline.

final int baselineWindowSize = 200;

float[] baselineWindow = new float[baselineWindowSize];

int baselineIndex = 0;
int baselineCount = 0;

float baselineSum = 0;
float ECG_baseline = 0;

// ECG after removal of the slowly-varying baseline
float ECG_centered = 0;

// Absolute amplitude of centered ECG.
// This makes detection independent of QRS polarity.
float ECG_amplitude = 0;


// 3. ADAPTIVE THRESHOLD
// 400 samples are approximately 2 seconds of ECG. 
// The threshold is calculated from the recent minimum and maximum ECG amplitude.

final int thresholdWindowSize = 400;

float[] thresholdWindow = new float[thresholdWindowSize];

int thresholdWindowIndex = 0;
int thresholdWindowCount = 0;

float threshold = 0;
float thresholdFraction = 0.65;

// Recalculate adaptive threshold every 100 ms
int lastThresholdUpdate = 0;
final int thresholdUpdateInterval = 100;

boolean below_threshold = true;

// INITIAL ECG CALIBRATION
// 0 - 5 s: signal stabilization
// 5 - 15 s: threshold calibration
// after 15 s: adaptive threshold

boolean ecgCalibrated = false;
int ecgCalibrationStart = 0;
float ecgMin = 99999;
float ecgMax = 0;


// HEART RATE CALCULATION
int beat_old = 0;
float[] beats = new float[3];
int beatIndex = 0;
int beatCount = 0;
int BPM = 0;


// FSR / RESPIRATION VARIABLES
// Moving average of 50 samples.
// With approximately 200 Hz sampling this corresponds to about 250 ms of FSR signal.

final int n_window_fsr = 50;
float[] fsrWindow = new float[n_window_fsr];

int fsrWindowIndex = 0;
int fsrWindowCount = 0;
float fsrSum = 0;
float current_mean = 0;

// Respiratory trend is evaluated every 100 ms,
// independently of the exact Arduino sampling frequency.

int lastBreathingCheck = 0;
final int breathingCheckInterval = 100;

float previous_breath_mean = 0;
float dFSR = 0;

// Minimum change required to consider the FSR trend increasing or decreasing.
// NOTE: TO BE adjusted experimentally (NOT DONE YET)
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


// SIGNAL STATUS
boolean leadsOff = false;



// GRAPH DATA
// Do not save every sample for visualization.
// With approximately 200 samples/s, saving one every 5 samples gives about 40 displayed points/s.

int plotCounter = 0;
ArrayList<Float> ecgPlot = new ArrayList<Float>();
ArrayList<Float> fsrPlot = new ArrayList<Float>();
int maxPlotPoints = 500;

// Graph dimensions

float graphX = 70;
float graphW = 1160;

float ecgGraphY = 210;
float ecgGraphH = 220;

float fsrGraphY = 520;
float fsrGraphH = 220;



// START OF THE PROGRAM 
// SETUP --> INITIALIZATION AND SET UP

void setupSignalProcessing() {

  // Window size and draw() are managed by Heart_Breathing_Integrated.pde.

  println("Available serial ports:");
  printArray(Serial.list());
  myPort = new Serial(this, "COM3", 115200);         // serialEvent() is called when a complete line
  myPort.clear();                                   //  ending with '\n' is received.
  myPort.bufferUntil('\n');                 // myPort.clear --> clears the port 

  frameRate(30);
}


// SERIAL EVENT
// Function called every time a new sample from the sensor arrives
// read the date, process the incoming samples by calling the corresponding functions

void serialEvent(Serial p) {

  String incoming = p.readStringUntil('\n');      // read the incoming string from Arduino (string containing ECG,FSR ends with \n)

  if (incoming == null) {                    // handele the case in which nothing is coming from Arduino
    return;
  }

  // Remove spaces and newline characters  
  incoming = trim(incoming);

  // Arduino sends "!" if ECG electrodes are disconnected
  if (incoming.equals("!")) {
    leadsOff = true;
    return;
  }

  // Arduino sends: ECG,FSR --> Example: 520,410

  String[] values = split(incoming, ',');

  if (values.length != 2) {                     // Continue only if two values were received
    return;
  }

  // Convert the two strings into integers
  ECG = int(values[0]);
  FSR = int(values[1]);

  leadsOff = false;

  // Process both signals
  updateECG();
  updateFSR();

  // DATA FOR PLOTTING

  plotCounter++;

  // Save one point every 5 received samples  
  if (plotCounter >= 5) {

    ecgPlot.add(ECG_centered);    // Plot centered ECG instead of raw ECG
    fsrPlot.add(current_mean);    // Plot smoothed FSR signal

    plotCounter = 0;

    // Keep only the most recent points
    if (ecgPlot.size() > maxPlotPoints) {
      ecgPlot.remove(0);
    }

    if (fsrPlot.size() > maxPlotPoints) {
      fsrPlot.remove(0);
    }
  }
}




// ECG PROCESSING
// includes an initial smoothing over a 3 samples window (remove high frequency noise)
// computation of the threshold at the beginning to detect the heart beat
// computation of an adaptive threshold to adapt it to the signal amplitude
// computation of the baseline of the recent samples of the signal --> 
// the baseline is subracted to the ECG, giving ECG_cenertered --> acts as an high pass filter
// remove slow drift in the baseline of the signal 

void updateECG() {

  // 1. SHORT MOVING AVERAGE
  ecgSum = ecgSum - ecgWindow[ecgWindowIndex];     // Remove oldest value from running sum
  ecgWindow[ecgWindowIndex] = ECG;                 // Insert newest RAW ECG sample
  ecgSum = ecgSum + ECG;                           // Add new ECG sample
  
  ecgWindowIndex = (ecgWindowIndex + 1) % 3;      // Circular buffer: automatically adapts the index of the window
                                                  // 0 -> 1 -> 2 -> 0 -> ... --> add the most recent sample tpo the array

  // During startup the array is not full yet
  if (ecgWindowCount < 3) {
    ecgWindowCount++;
  }

  // Short moving average: first simple smoothing against fast noise
  ECG_filtered = ecgSum / ecgWindowCount;

  
  // 2. BASELINE ESTIMATION --> is the mean of the signal computed over a much wider range in time
  
  baselineSum = baselineSum - baselineWindow[baselineIndex];    // Remove oldest value from baseline running sum
  baselineWindow[baselineIndex] = ECG_filtered;                 // // Insert the new SMOOTHED ECG value
  baselineSum = baselineSum + ECG_filtered;                    // Add newest value to baseline sum

  baselineIndex = (baselineIndex + 1) %  baselineWindowSize;    // Circular buffer through approximately 1 s of ECG

  if (baselineCount < baselineWindowSize) {
    baselineCount++;
  }

  // Estimate slowly-varying ECG baseline --> mean of the component in baselineWindow[...]
  ECG_baseline = baselineSum / baselineCount;

  
  // 3. BASELINE REMOVAL  --> acts as an high pass --> remove low drift 
  
  ECG_centered =  ECG_filtered - ECG_baseline;      // Remove slow baseline drift

  // Use absolute amplitude for QRS detection --> positive and negative QRS complexes can both be detected.
  ECG_amplitude = abs(ECG_centered);

  
  // 4. UPDATE RECENT ECG WINDOW
  // The adaptive-threshold window is updated continuously, even during initial calibration.
  // the array contains the recent samples of ECG_centered --> those recent samples are used to compute the 
  // thereshold --> ech time abs(ECG_centered) is computed is used as an element of the array to estimate a current threshold
  
  thresholdWindow[thresholdWindowIndex] = ECG_amplitude;
  thresholdWindowIndex = (thresholdWindowIndex + 1) % thresholdWindowSize;

  if (thresholdWindowCount < thresholdWindowSize) {
    thresholdWindowCount++;
  }

 
  // 5. INITIAL ECG CALIBRATION

  if (ecgCalibrationStart == 0) {
    ecgCalibrationStart = millis();
  }

  if (ecgCalibrated == false) {

    if (ECG_filtered > ecgMax) {
      ecgMax = ECG_filtered;
    }

    if (ECG_filtered < ecgMin) {
      ecgMin = ECG_filtered;
    }

    if ( millis() - ecgCalibrationStart > 5000 &&  millis() - ecgCalibrationStart < 15000) {   // not use first seconds for initial calibration 

      threshold =  ecgMin + thresholdFraction * (ecgMax - ecgMin);
      ecgCalibrated = true;
      below_threshold = ECG_filtered < threshold;
    }

    return;
  }

  // 6. ADAPTIVE THRESHOLD TO DETECT THE QRS PEAK 
  // Recalculate threshold every 100 ms instead of every single ECG sample.

  if (millis() - lastThresholdUpdate >= thresholdUpdateInterval) {     // need to update --> search again for max and min

    float recentMin = 99999;
    float recentMax = 0;

    // Find recent minimum and maximum ECG amplitude
    for (int i = 0; i < thresholdWindowCount; i++) {    // thresholdwindow contains the recent ECG_centered samples 
      if (thresholdWindow[i] < recentMin) {             // i search for max and min in these samples and use them to estimate a new threshold 
         recentMin = thresholdWindow[i];
      }

      if (thresholdWindow[i] > recentMax) {
        recentMax = thresholdWindow[i];
      }
    }

    if (thresholdWindowCount > 0) {
      threshold =  recentMin + thresholdFraction * (recentMax - recentMin);             // thereshold overwritten 
    }

    lastThresholdUpdate = millis();     // save the time instant in which the threshold was updated the last time
  }


  // 7. QRS / HEART BEAT DETECTION  --> impose the condition in which bpm needs to be computed
  
  // A new QRS is accepted when:
  // 1. amplitude crosses above adaptive threshold
  // 2. previous sample was below threshold
  // 3. at least 250 ms passed since previous beat
  // if those conditions are satisfied, the function calculateBPM() is called

  if (ECG_amplitude > threshold && below_threshold == true && (beat_old == 0 || millis() - beat_old > 250)) {
    calculateBPM();
    below_threshold = false;                            // Do not detect another QRS until the signal returns below threshold
  }


  else if (ECG_amplitude < threshold) {
    below_threshold = true;
  }
}


// HEART RATE

void calculateBPM() {

  int beat_new = millis();

  // First detected QRS: there is not yet a previous RR interval.

  if (beat_old != 0) {
    int diff = beat_new - beat_old;

    // Ignore clearly unreasonable RR intervals ( too close or too distant from the previous one)
    if (diff > 250 && diff < 2000) {
      
      float currentBPM = 60000.0 / diff;

      beats[beatIndex] = currentBPM;      // Store BPM in circular buffer
      beatIndex = (beatIndex + 1) % 3;
      
      if (beatCount < 3) {                           // During the first beats, average only the
          beatCount++;                               // measurements actually available.
      }

      float total = 0.0;

      for (int i = 0; i < beatCount; i++) {        // sum of the number of the last bpm measurments 
        total = total + beats[i];
      }
      
      BPM = int(total / beatCount);        // Heart rate = average of last three BPM values
    }
  }
  
  beat_old = beat_new;    // Current beat becomes reference for the next beat
}


// FSR PROCESSING

void updateFSR() {

  // If the FSR is not connected or sends zero, do not process respiratory data.
  if (FSR == 0) {
    return;
  }

  // 1. FSR MOVING AVERAGE 
  // the average of the FSR has many more samples than the ecg --> 
  // this is signal varies slower in time so we can use more samples to smooth out higher frequencies
  // variations that are not representative of the breathing pattern

  fsrSum =  fsrSum - fsrWindow[fsrWindowIndex];   // Remove oldest sample
  fsrWindow[fsrWindowIndex] = FSR;                 // Insert newest FSR sample
  fsrSum = fsrSum + FSR;                        // Add newest sample
  
  fsrWindowIndex = (fsrWindowIndex + 1) % n_window_fsr;    // Circular buffer

  if (fsrWindowCount < n_window_fsr) {
    fsrWindowCount++;
  }

  // Smoothed respiratory signal
  current_mean =
    fsrSum /
    fsrWindowCount;



  // ===================================================
  // 2. RESPIRATORY TREND
  // ===================================================

  // Wait until the smoothing window is full
  if (fsrWindowCount ==
      n_window_fsr) {


    // Evaluate respiratory trend every 100 ms.
    // This is independent from exact Arduino Fs.

    if (millis() - lastBreathingCheck
        >= breathingCheckInterval) {



      // First measurement:
      // no previous respiratory value exists yet.

      if (previous_breath_mean == 0) {


        previous_breath_mean =
          current_mean;
      }



      else {


        // Compare current smoothed FSR with
        // smoothed FSR about 100 ms earlier.

        dFSR =
          current_mean -
          previous_breath_mean;



        // Current value becomes next reference
        previous_breath_mean =
          current_mean;



        calculateBreathingRate();
      }


      lastBreathingCheck =
        millis();
    }
  }
}



// =====================================================
// BREATHING RATE
// =====================================================

void calculateBreathingRate() {


  // NOTE:
  //
  // This code assumes:
  //
  // increasing FSR -> inspiration
  // decreasing FSR -> expiration
  //
  // If the real sensor has the opposite polarity,
  // the > eps and < -eps conditions must be swapped.



  // ===================================================
  // INITIAL PHASE IDENTIFICATION
  // ===================================================

  if (breathingInitialized == false) {


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



  // ===================================================
  // EXPIRATION --> INSPIRATION
  // ===================================================

  if (expiration_phase == true) {


    if (dFSR > eps) {


      count_start_insp++;



      // Require 3 confirmations.
      //
      // Since the respiratory trend is evaluated
      // every 100 ms, this corresponds to about
      // 300 ms of consistent increase.

      if (count_start_insp >= 3) {


        int new_in_start =
          millis();



        // Duration of previous expiration
        if (ex_start != 0) {


          Tex =
            new_in_start -
            ex_start;
        }



        // Complete breathing period:
        //
        // previous inspiration start
        //          ->
        // current inspiration start

        if (in_start != 0) {


          Tbreath =
            new_in_start -
            in_start;


          respiratoryRate =
            60000.0 /
            Tbreath;
        }



        // Current inspiration becomes the
        // reference for the next breathing cycle.

        in_start =
          new_in_start;


        inspiration_phase = true;
        expiration_phase = false;


        count_start_insp = 0;
        count_start_exp = 0;
      }
    }



    // Opposite trend:
    // cancel the candidate transition.

    else if (dFSR < -eps) {


      count_start_insp = 0;
    }
  }



  // ===================================================
  // INSPIRATION --> EXPIRATION
  // ===================================================

  else if (inspiration_phase == true) {


    if (dFSR < -eps) {


      count_start_exp++;



      // Require 3 consecutive confirmations

      if (count_start_exp >= 3) {


        ex_start =
          millis();



        // Inspiration duration
        if (in_start != 0) {


          Tinsp =
            ex_start -
            in_start;
        }



        inspiration_phase = false;
        expiration_phase = true;


        count_start_exp = 0;
        count_start_insp = 0;
      }
    }



    // Opposite trend:
    // cancel the candidate transition.

    else if (dFSR > eps) {


      count_start_exp = 0;
    }
  }
}

// ===== ORIGINAL TAB: StressMode.pde =====
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
