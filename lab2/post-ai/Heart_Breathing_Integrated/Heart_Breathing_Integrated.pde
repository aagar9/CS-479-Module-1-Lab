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

  background(255);

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

  fill(0);
  textSize(30);

  text(
    "Heart + Breathing Monitor",
    30,
    42
  );
}


// ========================================
// NAVIGATION
// ========================================

void drawNavigation() {

  stroke(0);


  // HOME

  if (mode == MODE_HOME) {
    fill(180);
  }
  else {
    fill(220);
  }

  rect(
    30,
    65,
    120,
    50
  );


  // FITNESS

  if (mode == MODE_FITNESS) {
    fill(180);
  }
  else {
    fill(220);
  }

  rect(
    165,
    65,
    150,
    50
  );


  // STRESS

  if (mode == MODE_STRESS) {
    fill(180);
  }
  else {
    fill(220);
  }

  rect(
    330,
    65,
    150,
    50
  );


  // MEDITATION

  if (mode == MODE_MEDITATION) {
    fill(180);
  }
  else {
    fill(220);
  }

  rect(
    495,
    65,
    170,
    50
  );


  fill(0);

  textSize(16);

  text(
    "HOME",
    67,
    96
  );

  text(
    "FITNESS",
    205,
    96
  );

  text(
    "STRESS",
    375,
    96
  );

  text(
    "MEDITATION",
    525,
    96
  );


  // --------------------------------------
  // Sensor status
  // --------------------------------------

  textSize(13);


  if (leadsOff) {

    fill(255, 0, 0);

    text(
      "ECG LEADS OFF",
      790,
      95
    );
  }

  else {

    fill(0, 150, 0);

    text(
      "SENSOR ACTIVE",
      790,
      95
    );
  }
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