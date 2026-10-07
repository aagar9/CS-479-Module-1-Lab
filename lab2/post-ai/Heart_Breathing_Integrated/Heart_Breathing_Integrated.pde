// ========================================
// HEART + BREATHING MONITOR
// BME/CS 479 - Lab 2
// Post-AI Integrated Processing UI
// ========================================

// 0 = Home
// 1 = Fitness
// 2 = Stress
// 3 = Meditation

int mode = 0;


// ========================================
// LIVE SENSOR VALUES
// ========================================

// Values are calculated in SignalProcessing.pde.
// The original calculation logic is not changed.

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
  drawButtons();

  if (mode == 0) {
    drawHome();
  }

  else if (mode == 1) {
    drawFitness();
  }

  else if (mode == 2) {
    drawStress();
  }

  else if (mode == 3) {
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
    45
  );
}


// ========================================
// MODE BUTTONS
// ========================================

void drawButtons() {

  stroke(0);

  // Fitness button
  fill(220);
  rect(30, 70, 150, 50);

  // Stress button
  fill(220);
  rect(200, 70, 150, 50);

  // Meditation button
  fill(220);
  rect(370, 70, 150, 50);


  fill(0);
  textSize(16);

  text("FITNESS", 65, 100);

  text("STRESS", 245, 100);

  text("MEDITATION", 390, 100);
}


// ========================================
// HOME SCREEN
// ========================================

void drawHome() {

  fill(0);

  textSize(24);

  text(
    "Select a mode",
    30,
    180
  );


  textSize(18);

  text(
    "Heart Rate: " + getHeartRate() + " BPM",
    30,
    240
  );

  text(
    "Respiratory Rate: "
    + nf(getRespRate(), 0, 1)
    + " breaths/min",
    30,
    280
  );


  // Signal status

  textSize(14);

  if (leadsOff == true) {

    fill(255, 0, 0);

    text(
      "ECG electrodes disconnected",
      30,
      330
    );
  }

  else {

    fill(0);

    text(
      "Waiting for / receiving sensor data",
      30,
      330
    );
  }
}


// ========================================
// FITNESS MODE
// ========================================

void drawFitness() {

  fill(0);

  textSize(24);

  text(
    "FITNESS MODE",
    30,
    170
  );


  textSize(20);

  text(
    "Heart Rate: "
    + getHeartRate()
    + " BPM",
    30,
    220
  );

  text(
    "Resp Rate: "
    + nf(getRespRate(), 0, 1)
    + " breaths/min",
    30,
    255
  );


  // Cardio-zone calculation will be
  // connected in the next stage.

  text(
    "Cardio Zone: --",
    30,
    300
  );


  // --------------------------------
  // ECG GRAPH
  // --------------------------------

  stroke(0);
  noFill();

  rect(
    30,
    340,
    600,
    100
  );


  fill(0);
  textSize(16);

  text(
    "ECG",
    40,
    365
  );


  // Plot real ECG data from
  // SignalProcessing.pde

  if (ecgPlot.size() > 1) {

    stroke(255, 0, 0);

    noFill();

    beginShape();

    for (int i = 0; i < ecgPlot.size(); i++) {

      float x =
        map(
          i,
          0,
          maxPlotPoints - 1,
          50,
          610
        );

      float y =
        map(
          ecgPlot.get(i),
          0,
          1023,
          425,
          375
        );

      vertex(x, y);
    }

    endShape();
  }


  // --------------------------------
  // CARDIO ZONE GRAPH
  // --------------------------------

  stroke(0);
  noFill();

  rect(
    30,
    470,
    600,
    70
  );


  fill(0);

  text(
    "CARDIO ZONE",
    40,
    495
  );


  // Very light
  fill(180);

  rect(
    50,
    510,
    100,
    15
  );


  // Light
  fill(100, 180, 255);

  rect(
    150,
    510,
    100,
    15
  );


  // Moderate
  fill(0, 200, 0);

  rect(
    250,
    510,
    100,
    15
  );


  // Hard
  fill(255, 150, 0);

  rect(
    350,
    510,
    100,
    15
  );


  // Maximum
  fill(255, 0, 0);

  rect(
    450,
    510,
    100,
    15
  );


  // --------------------------------
  // RESPIRATORY GRAPH
  // --------------------------------

  stroke(0);
  noFill();

  rect(
    30,
    570,
    600,
    90
  );


  fill(0);

  text(
    "RESPIRATION",
    40,
    595
  );


  // Plot real FSR data from
  // SignalProcessing.pde

  if (fsrPlot.size() > 1) {

    stroke(0, 0, 255);

    noFill();

    beginShape();

    for (int i = 0; i < fsrPlot.size(); i++) {

      float x =
        map(
          i,
          0,
          maxPlotPoints - 1,
          50,
          610
        );

      float y =
        map(
          fsrPlot.get(i),
          0,
          1023,
          650,
          605
        );

      vertex(x, y);
    }

    endShape();
  }


  stroke(0);
}


// ========================================
// STRESS MODE
// ========================================

void drawStress() {

  fill(0);

  textSize(24);

  text(
    "STRESS MONITORING MODE",
    30,
    170
  );


  textSize(20);


  // Baseline will be calculated during
  // the 30-second baseline stage.

  text(
    "Baseline Heart Rate: -- BPM",
    30,
    230
  );


  text(
    "Current Heart Rate: "
    + getHeartRate()
    + " BPM",
    30,
    270
  );


  text(
    "Baseline Resp Rate: -- breaths/min",
    30,
    320
  );


  text(
    "Current Resp Rate: "
    + nf(getRespRate(), 0, 1)
    + " breaths/min",
    30,
    360
  );


  textSize(28);

  fill(0);

  // Stress classification will be
  // implemented after baseline collection.

  text(
    "STRESS STATE: --",
    30,
    430
  );
}


// ========================================
// MEDITATION MODE
// ========================================

void drawMeditation() {

  fill(0);

  textSize(24);

  text(
    "MEDITATION MODE",
    30,
    170
  );


  textSize(20);


  text(
    "Heart Rate: "
    + getHeartRate()
    + " BPM",
    30,
    230
  );


  text(
    "Resp Rate: "
    + nf(getRespRate(), 0, 1)
    + " breaths/min",
    30,
    270
  );


  text(
    "Inhale: "
    + nf(getInhaleTime(), 0, 2)
    + " sec",
    30,
    330
  );


  text(
    "Exhale: "
    + nf(getExhaleTime(), 0, 2)
    + " sec",
    30,
    370
  );


  text(
    "Target: Exhale = 3 x Inhale",
    30,
    430
  );


  fill(0);

  textSize(28);

  // Three-breath meditation feedback
  // will be implemented in the next stage.

  text(
    "BREATHING: --",
    30,
    500
  );
}


// ========================================
// MOUSE CLICKS
// ========================================

void mousePressed() {

  // FITNESS BUTTON

  if (
    mouseX > 30 &&
    mouseX < 180 &&
    mouseY > 70 &&
    mouseY < 120
  ) {

    mode = 1;
  }


  // STRESS BUTTON

  if (
    mouseX > 200 &&
    mouseX < 350 &&
    mouseY > 70 &&
    mouseY < 120
  ) {

    mode = 2;
  }


  // MEDITATION BUTTON

  if (
    mouseX > 370 &&
    mouseX < 520 &&
    mouseY > 70 &&
    mouseY < 120
  ) {

    mode = 3;
  }
}