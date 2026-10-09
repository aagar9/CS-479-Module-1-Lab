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
