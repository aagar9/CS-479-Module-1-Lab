// ========================================
// HEART + BREATHING MONITOR
// BME/CS 479 - Lab 2
// Rough Processing UI
// ========================================

// 0 = Home
// 1 = Fitness
// 2 = Stress
// 3 = Meditation

int mode = 0;


// ----------------------------------------
// FAKE DATA FOR NOW
// Later this will come from the FireBeetle
// ----------------------------------------

int heartRate = 72;
int respRate = 14;

float inhaleTime = 1.5;
float exhaleTime = 4.5;


// ========================================
// SETUP
// ========================================

void setup() {

  size(1000, 700);

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

  text("Heart + Breathing Monitor", 30, 45);

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

  text("Select a mode", 30, 180);


  textSize(18);

  text(
    "Heart Rate: " + heartRate + " BPM",
    30,
    240
  );

  text(
    "Respiratory Rate: " + respRate + " breaths/min",
    30,
    280
  );
}


// ========================================
// FITNESS MODE
// ========================================

void drawFitness() {

  fill(0);

  textSize(24);

  text("FITNESS MODE", 30, 170);


  textSize(20);

  text(
    "Heart Rate: " + heartRate + " BPM",
    30,
    220
  );

  text(
    "Resp Rate: " + respRate + " breaths/min",
    30,
    255
  );

  text(
    "Cardio Zone: MODERATE",
    30,
    300
  );


  // --------------------------------
  // ECG GRAPH
  // --------------------------------

  stroke(0);
  noFill();

  rect(30, 340, 600, 100);


  fill(0);
  textSize(16);

  text("ECG", 40, 365);


  // Fake ECG waveform

  stroke(255, 0, 0);

  for (int x = 50; x < 600; x += 60) {

    line(x, 400,
         x + 15, 400);

    line(x + 15, 400,
         x + 20, 370);

    line(x + 20, 370,
         x + 25, 420);

    line(x + 25, 420,
         x + 30, 400);

    line(x + 30, 400,
         x + 60, 400);
  }


  // --------------------------------
  // CARDIO ZONE GRAPH
  // --------------------------------

  stroke(0);
  noFill();

  rect(30, 470, 600, 70);


  fill(0);

  text(
    "CARDIO ZONE",
    40,
    495
  );


  // Very light
  fill(180);
  rect(50, 510, 100, 15);


  // Light
  fill(100, 180, 255);
  rect(150, 510, 100, 15);


  // Moderate
  fill(0, 200, 0);
  rect(250, 510, 100, 15);


  // Hard
  fill(255, 150, 0);
  rect(350, 510, 100, 15);


  // Maximum
  fill(255, 0, 0);
  rect(450, 510, 100, 15);


  // --------------------------------
  // RESPIRATORY GRAPH
  // --------------------------------

  stroke(0);
  noFill();

  rect(30, 570, 600, 90);


  fill(0);

  text(
    "RESPIRATION",
    40,
    595
  );


  // Fake breathing waveform

  stroke(0, 0, 255);

  noFill();

  beginShape();

  for (int x = 50; x < 610; x++) {

    float y =
      625 + sin(x * 0.05) * 20;

    vertex(x, y);
  }

  endShape();

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

  text(
    "Baseline Heart Rate: 72 BPM",
    30,
    230
  );

  text(
    "Current Heart Rate: 91 BPM",
    30,
    270
  );


  text(
    "Baseline Resp Rate: 14 breaths/min",
    30,
    320
  );

  text(
    "Current Resp Rate: 20 breaths/min",
    30,
    360
  );


  textSize(28);

  fill(255, 0, 0);

  text(
    "STRESS STATE: STRESSED",
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
    "Heart Rate: 68 BPM",
    30,
    230
  );

  text(
    "Resp Rate: 10 breaths/min",
    30,
    270
  );


  text(
    "Inhale: " + inhaleTime + " sec",
    30,
    330
  );

  text(
    "Exhale: " + exhaleTime + " sec",
    30,
    370
  );


  text(
    "Target: Exhale = 3 x Inhale",
    30,
    430
  );


  fill(0, 180, 0);

  textSize(28);

  text(
    "BREATHING: GOOD",
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
