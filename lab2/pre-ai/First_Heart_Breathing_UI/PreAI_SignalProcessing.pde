import processing.serial.*;
import java.util.ArrayList;

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
  String selected = null;
  for (String port : Serial.list()) {
    if (port.equals("COM3")) { selected = port; break; }
  }
  if (selected == null) {
    for (String port : Serial.list()) {
      if (port.contains("usbmodem") || port.contains("usbserial") ||
          port.contains("wchusbserial") || port.contains("SLAB_USBtoUART")) {
        selected = port;
        break;
      }
    }
  }
  if (selected == null) {
    println("No FireBeetle serial port found. Connect device and restart.");
    frameRate(30);
    return;
  }
  try {
    myPort = new Serial(this, selected, 115200);
    preAIPortName = selected;
  } catch (Exception e) {
    println("Unable to open serial port: " + e.getMessage());
    myPort = null;
    frameRate(30);
    return;
  }         // serialEvent() is called when a complete line
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
  preAILastPacket = millis();

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



