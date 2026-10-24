/*
  PAD REHAB - simple version, Processing / Java mode.
  Arduino: MPR121_Flex_Test, 115200 baud, flex on A1.
  Close Arduino Serial Monitor before running.
  8 = Slow, 9 = Fast. Calibrate -> Start -> Results.
  Timing uses receipt on the PC, so it includes serial/UI latency.
  Flex tolerance is a percentage of the ADC value, NOT of wrist angle.
*/
import processing.serial.*;

Serial arduino;
final String PORT = "COM3";
final int CAL_MS = 5000, SLOW_MS = 5000, FAST_MS = 2500;
final float TOLERANCE = 0.05f;
// Fixed vertical scale, in ADC counts. Set these to your measured flex range.
final int FLEX_MIN = 0, FLEX_MAX = 1023;
final int GRAPH_MS = 10000;
int[] graphTime = new int[300];
int[] graphValue = new int[300];
int graphCount = 0, graphEnd = 0;
int[] sequence = {0, 6, 2, 5, 4, 1, 7, 3, 6, 0, 5, 2, 1, 4, 3, 7};
int[] layout = {0, 1, 2, 3, 4, 6, 7, 5, 8, 9};
boolean[] pressed = new boolean[12];

// One view, four task stages: ready, calibrating, running, finished.
final int READY = 0, CALIBRATING = 1, RUNNING = 2, FINISHED = 3;
int stage = READY;
boolean fast = false, calibrated = false, hit = false, released = false;
int flex = 0, lastFlex = -1, calStart, samples = 0;
float calSum = 0, reference = 0;
int trial = 0, targetStart, touchStart, lastClock;
int hits = 0, misses = 0, contacts = 0;
float responseSum = 0, contactSum = 0, insideTime = 0, totalTime = 0;
String error = "";

void setup() {
  size(980, 760);
  textFont(createFont("SansSerif", 18));
  frameRate(60);
  try {
    arduino = new Serial(this, PORT, 115200);
    arduino.clear();
  } catch (Exception e) {
    error = "Cannot open Arduino. Close Serial Monitor and restart.";
  }
}

void draw() {
  // Only show an error if data stop; no connection controls.
  if ((stage == CALIBRATING || stage == RUNNING) && !freshData()) {
    resetTask();
    error = "Data interrupted. Check Arduino and calibrate again.";
  }
  if (stage == RUNNING) {
    int now = millis();
    int dt = now - lastClock;
    totalTime += dt;
    if (abs(flex - reference) <= max(1.0f, reference * TOLERANCE)) insideTime += dt;
    lastClock = now;
  }
  readArduino();
  updateTask();
  drawUI();
}

boolean freshData() {
  return lastFlex >= 0 && millis() - lastFlex < 1500;
}

// Read complete lines only. Arduino's startup messages are ignored.
void readArduino() {
  if (arduino == null) return;
  try {
    while (arduino.available() > 0) {
      String line = arduino.readStringUntil('\n');
      if (line == null) break;
      receive(trim(line));
    }
  } catch (Exception e) {
    resetTask();
    lastFlex = -1;
    error = "Serial error. Check Arduino and restart the sketch.";
  }
}

void receive(String line) {
  if (line.startsWith("Flex:")) {
    try {
      int value = Integer.parseInt(trim(line.substring(5)));
      if (value < 0) return;
      flex = value;
      lastFlex = millis();
      if (calibrated && stage != FINISHED) addFlexPoint();
      if (stage == CALIBRATING && millis() - calStart < CAL_MS) {
        calSum += flex;
        samples++;
      }
    } catch (NumberFormatException e) { }
    return;
  }
  String[] p = splitTokens(line);
  if (p.length != 2 || (!p[1].equals("touched") && !p[1].equals("released"))) return;
  int id;
  try { id = Integer.parseInt(p[0]); }
  catch (NumberFormatException e) { return; }
  if (id < 0 || id >= 12) return;
  boolean down = p[1].equals("touched");
  boolean newTouch = down && !pressed[id];
  pressed[id] = down;
  println(line);  // Optional diagnostic log; never displayed on the UI.

  if (stage == READY && newTouch) {
    if (id == 8) fast = false;
    if (id == 9) fast = true;
  }
  // Other pads never count or light up during the exercise.
  if (stage != RUNNING || id != sequence[trial]) return;
  if (!hit && newTouch && millis() - targetStart < limitMs()) {
    hit = true;
    hits++;
    touchStart = millis();
    responseSum += touchStart - targetStart;
  } else if (hit && !down && !released) {
    released = true;
    contacts++;
    contactSum += millis() - touchStart;
  }
}

int limitMs() { return fast ? FAST_MS : SLOW_MS; }

void updateTask() {
  if (stage == CALIBRATING && millis() - calStart >= CAL_MS) {
    stage = READY;
    if (samples >= 20 && freshData()) {
      reference = calSum / samples;
      calibrated = true;
      graphCount = 0;
      addFlexPoint();
    } else error = "Not enough samples. Repeat calibration.";
  }
  if (stage != RUNNING) return;
  if (!hit && millis() - targetStart >= limitMs()) {
    misses++;
    nextTarget();
  } else if (hit && released && millis() - touchStart >= 200) {
    nextTarget();  // Keep green visible for at least 200 ms.
  }
}

void nextTarget() {
  trial++;
  if (trial == sequence.length) {
    stage = FINISHED;
    graphEnd = millis();
  }
  else {
    targetStart = millis();
    hit = false;
    released = false;
  }
}

void resetTask() {
  stage = READY;
  calibrated = false;
  graphCount = 0;
  trial = hits = misses = contacts = 0;
  responseSum = contactSum = insideTime = totalTime = 0;
  hit = released = false;
  error = "";
}

// A single button changes function without opening another screen.
void mousePressed() {
  if (mouseX < 650 || mouseX > 930 || mouseY < 660 || mouseY > 710) return;
  if (stage == CALIBRATING || stage == RUNNING || stage == FINISHED) {
    resetTask();
  } else if (!freshData()) {
    error = "No sensor data. Check Arduino and try again.";
  } else if (!calibrated) {
    error = "";
    calSum = 0;
    samples = 0;
    calStart = millis();
    stage = CALIBRATING;
  } else {
    error = "";
    trial = hits = misses = contacts = 0;
    responseSum = contactSum = insideTime = totalTime = 0;
    hit = released = false;
    targetStart = lastClock = millis();
    stage = RUNNING;
    graphCount = 0;
    addFlexPoint();
  }
}

void drawUI() {
  background(240, 245, 251);
  fill(27, 47, 77);
  textAlign(LEFT, TOP);
  textSize(28);
  text("PAD REHAB", 40, 45);

  for (int i = 0; i < 10; i++) {
    int id = layout[i];
    float x = i < 8 ? 40 + (i % 4) * 140 : 180 + (i - 8) * 140;
    float y = i < 8 ? 160 + (i / 4) * 125 : 410;
    int shade = color(255);
    if (stage == READY && ((id == 8 && !fast) || (id == 9 && fast))) shade = color(170, 210, 250);
    if (stage == RUNNING && id == sequence[trial]) shade = hit ? color(103, 215, 157) : color(245, 116, 119);
    stroke(205, 218, 232);
    fill(shade);
    rect(x, y, 115, 100, 12);
    fill(27, 47, 77);
    textAlign(CENTER, CENTER);
    textSize(27);
    text(id, x + 57, y + 42);
    textSize(14);
    if (id >= 8) text(id == 8 ? "SLOW" : "FAST", x + 57, y + 80);
  }

  noStroke();
  fill(255);
  rect(625, 145, 330, 490, 14);
  fill(27, 47, 77);
  textAlign(LEFT, TOP);
  textSize(21);
  text("Mode: " + (fast ? "Fast" : "Slow"), 650, 170);
  text("Target: " + (stage == RUNNING ? str(sequence[trial]) : "--"), 650, 215);
  textSize(17);
  String info = "";
  if (stage == READY) info = calibrated ? "Ready" : "Hold the chosen wrist posture\nand press Calibrate.";
  if (stage == CALIBRATING) info = "Hold still\n\n" + nf(max(0, CAL_MS - (millis() - calStart)) / 1000.0f, 0, 1) + " s";
  if (stage == RUNNING) {
    info = "Trial " + (trial + 1) + " / " + sequence.length;
    info += hit ? "\n\nRelease" : "\n\n" + nf(max(0, limitMs() - (millis() - targetStart)) / 1000.0f, 0, 1) + " s";
  }
  if (stage == FINISHED) {
    info = "Completed";
    String results = "Reached: " + hits + " / " + sequence.length + "     Missed: " + misses;
    results += "\nMean response: " + meanSeconds(responseSum, hits);
    results += "\nMean contact: " + meanSeconds(contactSum, contacts);
    results += "\nWrist in range: " + (totalTime > 0 ? nf(100.0f * insideTime / totalTime, 0, 1) + "%" : "--");
    text(results, 40, 550, 550, 150);
  }
  text(info, 650, 265, 285, 90);
  if (calibrated) drawFlexGraph();
  String label = stage == READY ? (calibrated ? "Start" : "Calibrate") : (stage == FINISHED ? "Restart" : "Stop");
  noStroke();
  fill(40, 100, 175);
  rect(650, 660, 280, 50, 9);
  fill(255);
  textSize(17);
  textAlign(CENTER, CENTER);
  text(label, 790, 684);
  textAlign(LEFT, TOP);
  fill(170, 50, 50);
  textSize(15);
  text(error, 40, 725);
}

// Store only received readings, with their arrival time.
void addFlexPoint() {
  if (graphCount == graphValue.length) {
    for (int i = 1; i < graphCount; i++) {
      graphValue[i - 1] = graphValue[i];
      graphTime[i - 1] = graphTime[i];
    }
    graphCount--;
  }
  graphValue[graphCount] = flex;
  graphTime[graphCount] = millis();
  graphCount++;
}

void drawFlexGraph() {
  float x = 680, y = 405, w = 245, h = 155;
  int now = stage == FINISHED ? graphEnd : millis();
  float tolerance = max(1.0f, reference * TOLERANCE);
  fill(27, 47, 77);
  textAlign(LEFT, TOP);
  textSize(17);
  text("Flex (ADC)", 650, 365);

  stroke(205, 218, 232);
  fill(248, 250, 253);
  rect(x, y, w, h);
  textSize(12);
  fill(27, 47, 77);
  textAlign(RIGHT, CENTER);
  text(FLEX_MAX, x - 7, y);
  text(FLEX_MIN, x - 7, y + h);
  textAlign(LEFT, TOP);
  text("-10 s", x, y + h + 8);
  textAlign(RIGHT, TOP);
  text("0 s", x + w, y + h + 8);

  // Clip the signal and thresholds to the fixed plotting area.
  clip(x, y, w, h);
  stroke(60, 150, 100);
  for (int side = -1; side <= 1; side += 2) {
    float limitY = map(reference + side * tolerance, FLEX_MIN, FLEX_MAX, y + h, y);
    for (float dx = 0; dx < w; dx += 12) {
      line(x + dx, limitY, x + min(dx + 7, w), limitY);
    }
  }
  noFill();
  stroke(40, 100, 175);
  strokeWeight(2);
  beginShape();
  for (int i = 0; i < graphCount; i++) {
    float px = map(graphTime[i], now - GRAPH_MS, now, x, x + w);
    float py = map(graphValue[i], FLEX_MIN, FLEX_MAX, y + h, y);
    vertex(px, py);
  }
  endShape();
  strokeWeight(1);
  noClip();
  fill(60, 130, 90);
  textAlign(LEFT, TOP);
  text("Target: " + nf(reference - tolerance, 0, 0) + " - "
    + nf(reference + tolerance, 0, 0) + " ADC", 680, 600);
}

String meanSeconds(float sum, int count) {
  return count > 0 ? nf(sum / count / 1000.0f, 0, 2) + " s" : "--";
}
