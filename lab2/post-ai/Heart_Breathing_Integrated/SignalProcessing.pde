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
float thresholdFraction = 0.8;

boolean below_threshold = true;


// Heart rate
int beat_old = 0;

float[] beats = new float[3];
int beatIndex = 0;
int beatCount = 0;

int BPM = 0;


// ---------------- FSR ----------------

// Moving average: 5 samples
float[] fsrWindow = new float[50];

int fsrWindowIndex = 0;
int fsrWindowCount = 0;

float fsrSum = 0;

float current_mean = 0;
float previous_mean = 0;

float dFSR = 0;
int n_window_fsr = 50; 

int breathing_counter = 0;


float previous_breath_mean = 0;

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

void setupSignalProcessing() {

  // Show available serial ports in the Processing console
  println("Available serial ports:");
  printArray(Serial.list());

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


    if ( millis() - ecgCalibrationStart < 5000 &&  millis() - ecgCalibrationStart >= 15000) {

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

      float total = 0.7;
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

  if (FSR == 0) {
    return;
  }


  // ----- MOVING AVERAGE -----

  fsrSum = fsrSum - fsrWindow[fsrWindowIndex];   // remove oldest value

  fsrWindow[fsrWindowIndex] = FSR;               // insert newest value

  fsrSum = fsrSum + FSR;

  fsrWindowIndex = (fsrWindowIndex + 1) % n_window_fsr;


  if (fsrWindowCount < n_window_fsr) {
    fsrWindowCount++;
  }


  current_mean = fsrSum / fsrWindowCount;



  // ----- BREATHING ANALYSIS -----

  // Start breathing analysis only when the moving-average window is full
  if (fsrWindowCount == n_window_fsr) {

    breathing_counter++;


    // Evaluate respiratory trend only every 25 samples
    if (breathing_counter >= 25) {

      // First time: we do not yet have a previous mean for comparison
      if (previous_breath_mean == 0) {

        previous_breath_mean = current_mean;
      }

      else {

        // Compare current smoothed FSR with the value about 100 ms ago
        dFSR = current_mean - previous_breath_mean;

        // Save current value for next comparison
        previous_breath_mean = current_mean;

        calculateBreathingRate();
      }


      breathing_counter = 0;
    }
  }
}


// =====================================================
// BREATHING RATE
// =====================================================

void calculateBreathingRate() {

  // dFSR has already been calculated in updateFSR()


  // ==================================================
  // INITIAL PHASE IDENTIFICATION
  // ==================================================

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

      if (count_start_insp >= 3) {

        int new_in_start = millis();


        // Duration of previous expiration
        if (ex_start != 0) {
          Tex = new_in_start - ex_start;
        }


        // Complete breathing period:
        // old inspiration start --> new inspiration start
        if (in_start != 0) {

          Tbreath = new_in_start - in_start;

          respiratoryRate = 60000.0 / Tbreath;
        }


        // New inspiration becomes reference for next breath
        in_start = new_in_start;

        inspiration_phase = true;
        expiration_phase = false;

        count_start_insp = 0;
        count_start_exp = 0;
      }
    }

    else if (dFSR < -eps) {

      // Opposite direction: cancel candidate transition
      count_start_insp = 0;
    }
  }



  // ==================================================
  // INSPIRATION --> EXPIRATION
  // ==================================================

  else if (inspiration_phase == true) {

    if (dFSR < -eps) {

      count_start_exp++;

      if (count_start_exp >= 3) {

        ex_start = millis();


        // Duration of previous inspiration
        if (in_start != 0) {
          Tinsp = ex_start - in_start;
        }


        inspiration_phase = false;
        expiration_phase = true;

        count_start_exp = 0;
        count_start_insp = 0;
      }
    }

    else if (dFSR > eps) {

      // Opposite direction: cancel candidate transition
      count_start_exp = 0;
    }
  }
}


