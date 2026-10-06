import processing.serial.*;
import java.util.ArrayList;

Serial myPort;


// =====================================================
// VARIABLES
// =====================================================

// Raw signals
int ECG = 0;
int FSR = 0;


// ---------------- ECG ----------------

// Moving average: 3 samples
float[] ecgWindow = new float[3];
int ecgWindowIndex = 0;
int ecgWindowCount = 0;
float ecgSum = 0;

float ECG_filtered = 0;


// Threshold calibration
boolean ecgCalibrated = false;
int ecgCalibrationStart = 0;

float ecgMin = 1023;
float ecgMax = 0;

float threshold = 0;
float thresholdFraction = 0.65;

boolean below_threshold = true;


// Heart rate
int beat_old = 0;

float[] beats = new float[3];
int beatIndex = 0;
int beatCount = 0;

int BPM = 0;


// ---------------- FSR ----------------

// Moving average: 5 samples
float[] fsrWindow = new float[5];

int fsrWindowIndex = 0;
int fsrWindowCount = 0;

float fsrSum = 0;

float current_mean = 0;
float previous_mean = 0;

float dFSR = 0;


// Change this value after looking at the real signal
float eps = 0.2;


// Breathing phase
boolean breathingInitialized = false;

boolean inspiration_phase = false;
boolean expiration_phase = false;

int count_start_insp = 0;
int count_start_exp = 0;


// Breathing times
int in_start = 0;
int ex_start = 0;

int Tinsp = 0;
int Tex = 0;
int Tbreath = 0;

float respiratoryRate = 0;


// ---------------- Signal status ----------------

boolean leadsOff = false;


// ---------------- Graph data ----------------

// We do NOT need to plot all 250 samples/s.
// Every 5 samples we save one point only for visualization.

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



// =====================================================
// SETUP
// =====================================================

void setup() {

  size(1300, 800);

  myPort = new Serial(this, "COM3", 115200);
  myPort.clear();
  myPort.bufferUntil('\n');

  frameRate(30);
}



// =====================================================
// SERIAL EVENT
// =====================================================

void serialEvent(Serial p) {

  String incoming = p.readStringUntil('\n');   // Read the complete line that triggered the event.

  if (incoming == null) {
    return;
  }

  incoming = trim(incoming);    // Remove spaces/newline characters at the ends


  if (incoming.equals("!")) {      // ECG electrodes disconnected
  leadsOff = true;
  return;
  }


  String[] values = split(incoming, ',');   // split the two Numbers where there is the ',' (eg. ECG,FSR)
                                                     // string[] values means that values is an array made of strings

  // Check that Arduino actually sent two values
  if (values.length != 2) {
    return;
  }


  ECG = int(values[0]);   // Convert the string into an integer --> values[0] = 'ECG' but it is a string
  FSR = int(values[1]);    // this gives back the integer corresponding to ECG
 
  leadsOff = false;


  // Process signals

  updateECG();
  updateFSR();


  // Save fewer samples only for plotting

  plotCounter++;

  if (plotCounter >= 5) {

    ecgPlot.add(ECG_filtered);
    fsrPlot.add(current_mean);

    plotCounter = 0;


    if (ecgPlot.size() > maxPlotPoints) {
      ecgPlot.remove(0);
    }

    if (fsrPlot.size() > maxPlotPoints) {
      fsrPlot.remove(0);
    }
  }
}



// =====================================================
// ECG MOVING AVERAGE + HEART RATE
// =====================================================

void updateECG() {

  // Remove the oldest value from the sum
  ecgSum = ecgSum - ecgWindow[ecgWindowIndex];

  // Put new ECG value in the window
  ecgWindow[ecgWindowIndex] = ECG;

  // Add new value
  ecgSum = ecgSum + ECG;


  // Move circularly through array
  ecgWindowIndex = (ecgWindowIndex + 1) % 3;   //  it never arrives up to 3 --> valid indeces are 0,1,2
                                               // when ecgWindowIndex is 0, the operation gives: 1%3 which is 0 with rest of 1. 
                                                // then ecgWindowIndex = 1 --> operation is 2%3 which is 2...then ecgWinwowIndex = (2+1)%3 which is 0 --> starts again from zero
  if (ecgWindowCount < 3) {                      // the variable and counter are not updated directly because: index = (index+1)%n alone updates it at every iteration, from 0 to n 
    ecgWindowCount++;
  }


  ECG_filtered = ecgSum / ecgWindowCount;



  // -----------------------------------------
  // First 5 seconds: determine ECG threshold
  // -----------------------------------------

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


    if (millis() - ecgCalibrationStart >= 5000) {

      threshold =  ecgMin + thresholdFraction * (ecgMax - ecgMin);
      ecgCalibrated = true;
      below_threshold = ECG_filtered < threshold;
    }

    return;
  }



  // -----------------------------------------
  // R peak detection
  // -----------------------------------------

  if (ECG_filtered > threshold && below_threshold == true && (beat_old == 0 || millis() - beat_old > 250)) {
    calculateBPM();
    below_threshold = false;
  }

  else if (ECG_filtered < threshold) {
    below_threshold = true;
  }
}



// =====================================================
// HEART RATE
// =====================================================

void calculateBPM() {

  int beat_new = millis();


  // First detected beat: we still do not have an RR interval

  if (beat_old != 0) {

      int diff = beat_new - beat_old;

      if (diff > 250 && diff < 2000) {     // Ignore clearly unreasonable intervals

      float currentBPM = 60000.0 / diff;
      beats[beatIndex] = currentBPM;
      beatIndex = (beatIndex + 1) % 3;

      if (beatCount < 3) {                 // increase up to three, stops when reaches 3
        beatCount++;
      }

      float total = 0;7
      for (int i = 0; i < beatCount; i++) {     // sum of the samples in the window
        total = total + beats[i];
      }

      BPM = int(total / beatCount);   // BPM is the average of the last three samples
    }
  }


  beat_old = beat_new;
}



// =====================================================
// FSR MOVING AVERAGE
// =====================================================

void updateFSR() {

    if (FSR == 0) {     // For now ignore zero values
    return;
  }

  previous_mean = current_mean;

  fsrSum = fsrSum - fsrWindow[fsrWindowIndex];   // Remove oldest value
  fsrWindow[fsrWindowIndex] = FSR;             // Insert newest value
  fsrSum = fsrSum + FSR;                        // Add newest value

  fsrWindowIndex = (fsrWindowIndex + 1) % 5;


  if (fsrWindowCount < 5) {
    fsrWindowCount++;
  }

  current_mean = fsrSum / fsrWindowCount;

  // Start breathing detection only when window is full
  if (fsrWindowCount == 5 && previous_mean != 0) {
    calculateBreathingRate();
  }
}



// =====================================================
// BREATHING RATE
// =====================================================

void calculateBreathingRate() {

  dFSR = current_mean - previous_mean;

  // -----------------------------------------
  // Initial phase identification
  // -----------------------------------------

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



  // ==================================================
  // EXPIRATION --> INSPIRATION
  // ==================================================

  if (expiration_phase == true) {

    if (dFSR > eps) {

      count_start_insp++;

        if (count_start_insp >= 3) {     // Require 3 consecutive increasing values
         int new_in_start = millis();      // store starting time of the new inspiration cycle

          if (ex_start != 0) {              // Exhalation duration
          Tex = new_in_start - ex_start;
        }


        // Full breathing period:  inspiration start --> next inspiration start
        if (in_start != 0) {                          // at the beginning in_start is zero: used if i have a valid precedent sample
          Tbreath = new_in_start - in_start;
          respiratoryRate = 60000.0 / Tbreath;
        }

        in_start = new_in_start;    // in_start --> starting time of the previous inspiration cycle 
                                     // new_in_start becomes now the starting time of the previous inspiration cycle
                                      // when the next cycle will begin, its starting time will be stored in "new_in_start" while 
                                       // in_start will preserve the information about the previous one
        inspiration_phase = true;
        expiration_phase = false;

        count_start_insp = 0;
        count_start_exp = 0;
      }
    }


    // Opposite trend --> candidate was wrong
      else if (dFSR < -eps) {
      count_start_insp = 0;
    }
  }



  // ==================================================
  // INSPIRATION --> EXPIRATION
  // ==================================================

  else if (inspiration_phase == true) {

    if (dFSR < -eps) {
      count_start_exp++;

      // Require 3 consecutive decreasing values
      if (count_start_exp >= 3) {

        ex_start = millis();

        if (in_start != 0) {
          Tinsp = ex_start - in_start;
        }

        inspiration_phase = false;
        expiration_phase = true;

        count_start_exp = 0;
        count_start_insp = 0;
      }
    }

    // Opposite trend --> candidate was wrong
      else if (dFSR > eps) {
      count_start_exp = 0;
    }
  }
}



// =====================================================
// GUI
// =====================================================

void draw() {

  background(240);

  fill(0);
  textSize(22);
  text("ECG and Respiratory Monitor", 70, 35);


  // ==================================================
  // VALUE BOXES
  // ==================================================

  String bpmText = "--";

  if (BPM > 0) {
    bpmText = str(BPM) + " bpm";
  }


  String rrText = "--";

  if (respiratoryRate > 0) {
    rrText = nf(respiratoryRate, 0, 1) + " breaths/min";
  }


  String tinText = "--";

  if (Tinsp > 0) {
    tinText = nf(Tinsp / 1000.0, 0, 2) + " s";
  }


  String texText = "--";

  if (Tex > 0) {
    texText = nf(Tex / 1000.0, 0, 2) + " s";
  }


  String tbreathText = "--";

  if (Tbreath > 0) {
    tbreathText = nf(Tbreath / 1000.0, 0, 2) + " s";
  }


  drawValueBox("Heart Rate", bpmText, 70, 70, 215, 90);
  drawValueBox("Respiratory Rate", rrText, 305, 70, 215, 90);
  drawValueBox("Inspiration", tinText, 540, 70, 215, 90);
  drawValueBox("Expiration", texText, 775, 70, 215, 90);
  drawValueBox("Breathing Period", tbreathText, 1010, 70, 215, 90);



  // ==================================================
  // ECG GRAPH
  // ==================================================

  drawSignalGraph(ecgPlot, graphX, ecgGraphY, graphW, ecgGraphH, "ECG");

  // Draw ECG threshold
  if (ecgCalibrated == true) {

    float thresholdY =
      map(threshold, 0, 1023, ecgGraphY + ecgGraphH, ecgGraphY);

    stroke(150);

    line(graphX, thresholdY, graphX + graphW, thresholdY);

    fill(100);
    textSize(12);

    text("Threshold", graphX + 5, thresholdY - 5);
  }



  // ==================================================
  // FSR GRAPH
  // ==================================================

  drawSignalGraph(fsrPlot,
                  graphX,
                  fsrGraphY,
                  graphW,
                  fsrGraphH,
                  "Respiratory signal (FSR)");



  // ==================================================
  // STATUS
  // ==================================================

  fill(0);
  textSize(14);


  if (leadsOff == true) {

    text("ECG electrodes disconnected",
         70, 775);
  }

  else if (ecgCalibrated == false) {

    text("ECG threshold calibration...",
         70, 775);
  }

  else {

    text("Signal acquisition active",
         70, 775);
  }
}



// =====================================================
// SIMPLE VALUE BOX
// =====================================================

void drawValueBox(String title, String value, float x, float y, float w, float h) {

  stroke(0);
  fill(255);

  rect(x, y, w, h);

  fill(0);

  textSize(14);
  text(title, x + 10, y + 25);

  textSize(20);
  text(value, x + 10, y + 60);
}



// =====================================================
// SIMPLE GRAPH
// =====================================================

void drawSignalGraph(ArrayList<Float> data,
                     float x,
                     float y,
                     float w,
                     float h,
                     String title) {

  fill(255);
  stroke(0);

  rect(x, y, w, h);


  fill(0);
  textSize(15);

  text(title, x, y - 10);


  if (data.size() < 2) {
    return;
  }


  stroke(0);


  for (int i = 1; i < data.size(); i++) {

    float x1 =
      map(i - 1,
          0, maxPlotPoints - 1,
          x, x + w);

    float x2 =
      map(i,
          0, maxPlotPoints - 1,
          x, x + w);


    float y1 =
      map(data.get(i - 1),
          0, 1023,
          y + h, y);

    float y2 =
      map(data.get(i),
          0, 1023,
          y + h, y);


    line(x1, y1, x2, y2);
  }
}
