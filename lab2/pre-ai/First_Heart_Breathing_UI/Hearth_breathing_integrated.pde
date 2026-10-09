
 // Heart_Breathing_Integrated.pde
// Main program + Home screen
// FSR graph based on UI_LAB2_NO_AI.pde (fixed ADC scale).

final int NORMAL = 0;
final int BOLD = 1;

PFont regularFont;
PFont boldFont;

final int MODE_HOME = 0;
final int MODE_FITNESS = 1;
final int MODE_STRESS = 2;
final int MODE_MEDITATION = 3;
final int MODE_SECTION_IV = 4;

int mode = MODE_HOME;


// GRAPH SETTINGS

// ECG: fixed vertical scale centered around zero
final float ECG_GRAPH_RANGE = 400;
final int ECG_DISPLAY_POINTS = 180;

// FSR: fixed ADC scale 0-1023, no automatic zoom
// Approximately 5 seconds at 40 displayed points/second
final int RESP_DISPLAY_POINTS = 200;


// HOME BUTTONS

final int homeButtonY = 585;
final int homeButtonW = 240;
final int homeButtonH = 50;

final int fitnessButtonX = 30;
final int stressButtonX = 290;
final int meditationButtonX = 550;
final int sectionButtonX = 810;


// SETUP

void setup() {
  size(1100, 720);

  regularFont = createFont("Arial", 15);
  boldFont = createFont("Arial Bold", 15);
  textFont(regularFont);

  setupSignalProcessing();
}


// FONT STYLE

void textStyle(int style) {
  if (style == BOLD) textFont(boldFont);
  else textFont(regularFont);
}


// MAIN LOOP

void draw() {
  background(250);

  drawHeader();

  if (mode == MODE_HOME) drawHome();
  else if (mode == MODE_FITNESS) drawFitness();
  else if (mode == MODE_STRESS) drawStress();
  else if (mode == MODE_MEDITATION) drawMeditation();
  else if (mode == MODE_SECTION_IV) drawSectionIV();
}


// VALUES USED BY ALL MODES

int getHeartRate() {
  if (validHeartRate()) return BPM;
  return 0;
}

float getRespRate() {
  if (validRespRate()) return respiratoryRate;
  return 0;
}

float getInhaleTime() {
  if (validRespRate() && Tinsp > 0) return Tinsp / 1000.0;
  return 0;
}

float getExhaleTime() {
  if (validRespRate() && Tex > 0) return Tex / 1000.0;
  return 0;
}

String oneDecimal(float value) {
  return nf(value, 0, 1).replace(',', '.');
}

String twoDecimals(float value) {
  return nf(value, 0, 2).replace(',', '.');
}


// HEADER

void drawHeader() {

  fill(0);
  textStyle(BOLD);
  textSize(20);
  text("Heart + Breathing Monitor", 20, 32);
  textStyle(NORMAL);

  textSize(10);

  if (myPort == null) {
    fill(180, 0, 0);
    text("NO SERIAL DEVICE", 920, 28);
  }
  else if (!hasFreshData()) {
    fill(180, 100, 0);
    text("WAITING FOR DATA", 920, 28);
  }
  else if (leadsOff) {
    fill(180, 0, 0);
    text("ECG LEADS OFF", 940, 28);
  }
  else {
    fill(20, 150, 50);
    text("SENSOR LIVE", 960, 28);
  }

  stroke(210);
  strokeWeight(1);
  line(20, 42, 1080, 42);
}


// HOME

void drawHome() {

  int hr = getHeartRate();
  float rr = getRespRate();
  float tin = getInhaleTime();
  float tex = getExhaleTime();

  fill(0);
  textSize(15);

  text("Heart Rate", 20, 78);
  text("Respiratory Rate", 280, 78);
  text("Inspiration", 570, 78);
  text("Expiration", 810, 78);

  textStyle(BOLD);
  textSize(22);

  text(hr > 0 ? hr + " BPM" : "--", 20, 106);
  text(rr > 0 ? oneDecimal(rr) + " /min" : "--", 280, 106);
  text(tin > 0 ? twoDecimals(tin) + " s" : "--", 570, 106);
  text(tex > 0 ? twoDecimals(tex) + " s" : "--", 810, 106);

  textStyle(NORMAL);

  drawECGGraph(ecgPlot, 20, 145, 510, 320);
  drawRespGraph(fsrPlot, 570, 145, 510, 320);

  drawModeButton(fitnessButtonX, homeButtonY, homeButtonW, homeButtonH, "FITNESS MODE");
  drawModeButton(stressButtonX, homeButtonY, homeButtonW, homeButtonH, "STRESS MODE");
  drawModeButton(meditationButtonX, homeButtonY, homeButtonW, homeButtonH, "MEDITATION MODE");
  drawModeButton(sectionButtonX, homeButtonY, homeButtonW, homeButtonH, "SECTION IV");
}


// ECG GRAPH - UNCHANGED

void drawECGGraph(ArrayList<Float> data, float x, float y, float w, float h) {

  fill(255);
  stroke(0);
  strokeWeight(1);
  rect(x, y, w, h);

  fill(0);
  textSize(12);
  text("CENTERED ECG", x + 10, y + 18);

  float left = x + 10;
  float right = x + w - 10;
  float top = y + 30;
  float bottom = y + h - 15;

  float zeroY = map(0, -ECG_GRAPH_RANGE, ECG_GRAPH_RANGE, bottom, top);

  stroke(215);
  line(left, zeroY, right, zeroY);

  if (data.size() < 2) return;

  int numberOfPoints = min(data.size(), ECG_DISPLAY_POINTS);
  int firstPoint = max(0, data.size() - ECG_DISPLAY_POINTS);

  float dx = (right - left) / float(ECG_DISPLAY_POINTS - 1);

  stroke(230, 50, 50);
  strokeWeight(1.3);

  for (int j = 1; j < numberOfPoints; j++) {

    int i1 = firstPoint + j - 1;
    int i2 = firstPoint + j;

    float value1 = constrain(data.get(i1), -ECG_GRAPH_RANGE, ECG_GRAPH_RANGE);
    float value2 = constrain(data.get(i2), -ECG_GRAPH_RANGE, ECG_GRAPH_RANGE);

    float x1 = left + (j - 1) * dx;
    float x2 = left + j * dx;

    float y1 = map(value1, -ECG_GRAPH_RANGE, ECG_GRAPH_RANGE, bottom, top);
    float y2 = map(value2, -ECG_GRAPH_RANGE, ECG_GRAPH_RANGE, bottom, top);

    line(x1, y1, x2, y2);
  }

  strokeWeight(1);
}


// RESPIRATORY GRAPH
// Based on the method used in your friend's code.
//
// Fixed ADC vertical scale: 0 to 1023.
// No baseline subtraction.
// No zoom in / zoom out.
// No automatic recentering.
// The graph fills from left to right, then scrolls.
//
// Data still come from current_mean in SignalProcessing.pde.

void drawRespGraph(ArrayList<Float> data, float x, float y, float w, float h) {

  fill(255);
  stroke(0);
  strokeWeight(1);
  rect(x, y, w, h);

  fill(0);
  textSize(12);
  text("RESPIRATORY SIGNAL", x + 10, y + 18);

  float left = x + 10;
  float right = x + w - 10;
  float top = y + 30;
  float bottom = y + h - 15;

  int numberOfPoints = min(data.size(), RESP_DISPLAY_POINTS);

  if (numberOfPoints < 2) return;

  // Keep only the latest visible samples
  int firstPoint = data.size() - numberOfPoints;

  // Fixed horizontal spacing
  float dx = (right - left) / float(RESP_DISPLAY_POINTS - 1);

  // Draw the smoothed FSR signal using fixed ADC limits
  stroke(50, 90, 220);
  strokeWeight(1.5);
  noFill();

  beginShape();

  for (int j = 0; j < numberOfPoints; j++) {

    float value = data.get(firstPoint + j);

    float pointX = left + j * dx;

    // Fixed Y scale, exactly like your friend's graph
    float pointY = map(value, 0, 1023, bottom, top);

    vertex(pointX, pointY);
  }

  endShape();

  strokeWeight(1);
}


// COMMON BUTTON

void drawModeButton(float x, float y, float w, float h, String label) {

  fill(235);
  stroke(80);
  strokeWeight(1);
  rect(x, y, w, h);

  fill(0);
  textStyle(BOLD);
  textSize(14);

  textAlign(CENTER, CENTER);
  text(label, x + w / 2, y + h / 2);

  textAlign(LEFT);
  textStyle(NORMAL);
}


boolean insideButton(float x, float y, float w, float h) {

  return mouseX >= x &&
         mouseX <= x + w &&
         mouseY >= y &&
         mouseY <= y + h;
}


// MOUSE INPUT

void mousePressed() {

  if (mode == MODE_HOME) {

    if (insideButton(fitnessButtonX, homeButtonY, homeButtonW, homeButtonH)) {
      mode = MODE_FITNESS;
      return;
    }

    if (insideButton(stressButtonX, homeButtonY, homeButtonW, homeButtonH)) {
      mode = MODE_STRESS;
      return;
    }

    if (insideButton(meditationButtonX, homeButtonY, homeButtonW, homeButtonH)) {
      mode = MODE_MEDITATION;
      return;
    }

    if (insideButton(sectionButtonX, homeButtonY, homeButtonW, homeButtonH)) {
      mode = MODE_SECTION_IV;
      return;
    }
  }

  else if (mode == MODE_FITNESS) {
    fitnessMousePressed();
  }

  else if (mode == MODE_STRESS) {
    stressMousePressed();
  }

  else if (mode == MODE_MEDITATION) {
    meditationMousePressed();
  }

  else if (mode == MODE_SECTION_IV) {
    sectionIVMousePressed();
  }
}


// KEYBOARD INPUT

void keyPressed() {

  if (mode == MODE_FITNESS) {
    fitnessKeyPressed();
  }
}
