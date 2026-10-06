import processing.serial.*;
import java.util.ArrayList;


// ============================================================
// SERIAL COMMUNICATION
// ============================================================

Serial myPort;

final String PORT_NAME = "COM3";
final int BAUD_RATE = 115200;

boolean serialConnected = false;

int heartRate = 0;
int confidence = 0;
int oxygen = 0;
int sensorStatus = 0;

float beatInterval_ms = 0;

boolean lastSampleValid = false;

// millis() returns int in Processing
int lastSampleTime = 0;


// ============================================================
// MAIN PROGRAM STATES
// ============================================================

final int STATE_WAITING_SIGNAL    = 0;
final int STATE_SIGNAL_ACQUIRED   = 1;
final int STATE_BASELINE          = 2;
final int STATE_BASELINE_FAILED   = 3;

final int STATE_MODE_MENU         = 4;

final int STATE_CALM_ACTIVE       = 5;
final int STATE_CALM_RESULT       = 6;

final int STATE_STRESS_ACTIVE     = 7;
final int STATE_STRESS_RESULT     = 8;

final int STATE_DETECTION_ACTIVE  = 9;

int state = STATE_WAITING_SIGNAL;


// ============================================================
// INITIAL SIGNAL ACQUISITION
// ============================================================

final int WINDOW_SIZE = 10;
final int MIN_VALID_IN_WINDOW = 7;

boolean[] signalWindow = new boolean[WINDOW_SIZE];

int signalWindowIndex = 0;
int signalWindowCount = 0;


// ============================================================
// SIGNAL ACQUIRED SCREEN
// ============================================================

int signalAcquiredTime = 0;

final int SIGNAL_ACQUIRED_DISPLAY_MS = 1500;


// ============================================================
// BASELINE
// ============================================================

final int BASELINE_DURATION_MS = 30000;

final float MIN_BASELINE_QUALITY = 0.70;

final int MIN_BASELINE_SAMPLES = 30;

int baselineStartTime = 0;

int baselineTotalSamples = 0;
int baselineValidSamples = 0;

float baselineHRSum = 0;

float baselineQuality = 0;
float restingHR = 0;


// ============================================================
// CALIBRATION PARAMETERS
// ============================================================

// The last part of each calibration has slightly more weight.
//
// Weight increases approximately from 1.0 to 1.3.

final float CALIBRATION_WEIGHT_GAIN = 0.30;


// Minimum HR change required to accept a Calm or Stress
// calibration.

final float MIN_CALIBRATION_DELTA_BPM = 1.0;


// Even if the measured calibration delta is very small,
// the state-entry threshold must remain at least 1 bpm
// away from resting HR.

final float MIN_THRESHOLD_OFFSET_BPM = 1.0;


// Stress calibration must last at least 60 seconds.

final int MIN_STRESS_DURATION_MS = 60000;


// ============================================================
// SHARED CALIBRATION RECORDING VARIABLES
// ============================================================

int calibrationStartTime = 0;

int calibrationTotalSamples = 0;
int calibrationValidSamples = 0;

ArrayList<Float> calibrationHR =
  new ArrayList<Float>();

ArrayList<Float> calibrationTime =
  new ArrayList<Float>();


// ============================================================
// CALM CALIBRATION
// ============================================================

boolean calmCalibrationValid = false;

float calmCalibrationHR = 0;
float deltaCalm = 0;

float lastCalmTrialHR = 0;
float lastCalmTrialDelta = 0;
float lastCalmTrialQuality = 0;
float lastCalmTrialDuration_s = 0;


// ============================================================
// CALIBRATION RESULT TYPES
// ============================================================

final int RESULT_NONE       = 0;
final int RESULT_ACCEPTED   = 1;
final int RESULT_WEAK       = 2;
final int RESULT_INCOMPLETE = 3;
final int RESULT_NO_DATA    = 4;

int calmLastResult = RESULT_NONE;


// ============================================================
// STRESS CALIBRATION
// ============================================================

boolean stressCalibrationValid = false;

float stressCalibrationHR = 0;
float deltaStress = 0;

float lastStressTrialHR = 0;
float lastStressTrialDelta = 0;
float lastStressTrialQuality = 0;
float lastStressTrialDuration_s = 0;

int stressLastResult = RESULT_NONE;


// ============================================================
// LIVE DETECTION PARAMETERS
// ============================================================

// Latest 10 RECEIVED samples.
//
// Zero samples remain inside the window so that recent signal
// quality is represented correctly.
//
// However, zero samples are excluded from the HR average.

final int DETECTION_WINDOW_SIZE = 10;
final int DETECTION_MIN_VALID = 7;

int[] detectionWindow =
  new int[DETECTION_WINDOW_SIZE];

int detectionWindowIndex = 0;
int detectionWindowCount = 0;


// State condition must persist for 2 seconds before
// confirming a transition.

final int STATE_PERSISTENCE_MS = 2000;


// ============================================================
// DETECTED STATES
// ============================================================

final int DETECT_NEUTRAL  = 0;
final int DETECT_CALM     = 1;
final int DETECT_STRESSED = 2;

int detectedState = DETECT_NEUTRAL;


// ============================================================
// INTERNAL CANDIDATE STATES
// ============================================================

// Candidate states are internal only.
// They are not shown to the user.

final int CANDIDATE_NONE          = 0;
final int CANDIDATE_ENTER_CALM    = 1;
final int CANDIDATE_ENTER_STRESS  = 2;
final int CANDIDATE_EXIT_CALM     = 3;
final int CANDIDATE_EXIT_STRESS   = 4;

int candidateType = CANDIDATE_NONE;

int candidateStartTime = 0;


// ============================================================
// DETECTION SESSION
// ============================================================

int detectionStartTime = 0;

int detectionTotalSamples = 0;
int detectionValidSamples = 0;

float detectionQuality = 0;

float currentRollingHR = 0;

boolean rollingAvailable = false;

int currentWindowValidSamples = 0;


// ============================================================
// DETECTION GRAPH - MEASURED HR
// ============================================================

ArrayList<Float> rawGraphTime =
  new ArrayList<Float>();

ArrayList<Float> rawGraphHR =
  new ArrayList<Float>();

ArrayList<Boolean> rawGraphConnected =
  new ArrayList<Boolean>();

int previousDetectionSampleTime = 0;

boolean previousDetectionSampleWasValid = false;


// ============================================================
// DETECTION GRAPH - SMOOTHED HR
// ============================================================

ArrayList<Float> rollingGraphTime =
  new ArrayList<Float>();

ArrayList<Float> rollingGraphHR =
  new ArrayList<Float>();

ArrayList<Boolean> rollingGraphConnected =
  new ArrayList<Boolean>();

int previousRollingPointTime = 0;

boolean previousRollingAvailable = false;


// ============================================================
// GUI COLORS
// ============================================================

color backgroundColor;

color primaryBlue;
color darkBlue;
color lightBlue;
color veryLightBlue;

color textColor;
color secondaryText;

color calmGreen;
color stressRed;
color neutralColor;

color warningColor;
color successColor;

color whiteColor;


// ============================================================
// BUTTON POSITIONS
// ============================================================

// Baseline retry

float retryX = 500;
float retryY = 680;
float retryW = 300;
float retryH = 60;


// Main menu

float calmButtonX = 110;
float calmButtonY = 560;
float calmButtonW = 300;
float calmButtonH = 75;

float stressButtonX = 500;
float stressButtonY = 560;
float stressButtonW = 300;
float stressButtonH = 75;

float detectionButtonX = 890;
float detectionButtonY = 560;
float detectionButtonW = 300;
float detectionButtonH = 75;


// Calibration STOP

float calibrationStopX = 1070;
float calibrationStopY = 50;
float calibrationStopW = 170;
float calibrationStopH = 50;


// Result BACK button

float backButtonX = 500;
float backButtonY = 690;
float backButtonW = 300;
float backButtonH = 60;


// Detection STOP

float detectionStopX = 1060;
float detectionStopY = 50;
float detectionStopW = 180;
float detectionStopH = 50;


// ============================================================
// SETUP
// ============================================================

void setup()
{
  size(1300, 820);


  // ----------------------------------------------------------
  // Colors
  // ----------------------------------------------------------

  backgroundColor = color(244, 248, 252);

  primaryBlue = color(37, 99, 180);
  darkBlue = color(25, 67, 125);

  lightBlue = color(215, 232, 249);
  veryLightBlue = color(234, 243, 252);

  textColor = color(35, 45, 60);
  secondaryText = color(105, 115, 130);

  calmGreen = color(55, 160, 100);
  stressRed = color(205, 65, 65);

  neutralColor = color(105, 125, 150);

  warningColor = color(205, 75, 75);
  successColor = color(50, 150, 100);

  whiteColor = color(255);


  // ----------------------------------------------------------
  // Serial connection
  // ----------------------------------------------------------

  try
  {
    myPort = new Serial(
      this,
      PORT_NAME,
      BAUD_RATE
    );

    myPort.clear();

    myPort.bufferUntil('\n');

    serialConnected = true;
  }

  catch (Exception e)
  {
    serialConnected = false;

    println(
      "Could not open serial port "
      + PORT_NAME
    );

    println(e);
  }


  resetInitialSignalWindow();
}


// ============================================================
// MAIN DRAW LOOP
// ============================================================

void draw()
{
  background(backgroundColor);


  switch(state)
  {
    case STATE_WAITING_SIGNAL:

      drawWaitingForSignal();

      break;


    case STATE_SIGNAL_ACQUIRED:

      drawSignalAcquired();


      if (
        millis() - signalAcquiredTime
        >= SIGNAL_ACQUIRED_DISPLAY_MS
      )
      {
        startBaseline();
      }

      break;


    case STATE_BASELINE:

      drawBaseline();


      if (
        millis() - baselineStartTime
        >= BASELINE_DURATION_MS
      )
      {
        finishBaseline();
      }

      break;


    case STATE_BASELINE_FAILED:

      drawBaselineFailed();

      break;


    case STATE_MODE_MENU:

      drawModeMenu();

      break;


    case STATE_CALM_ACTIVE:

      drawCalibrationScreen(true);

      break;


    case STATE_CALM_RESULT:

      drawCalmResult();

      break;


    case STATE_STRESS_ACTIVE:

      drawCalibrationScreen(false);

      break;


    case STATE_STRESS_RESULT:

      drawStressResult();

      break;


    case STATE_DETECTION_ACTIVE:

      drawDetectionScreen();

      break;
  }


  // ----------------------------------------------------------
  // Serial warning
  // ----------------------------------------------------------

  if (!serialConnected)
  {
    fill(warningColor);

    textAlign(CENTER, CENTER);

    textSize(14);

    text(
      "Serial connection unavailable - check "
      + PORT_NAME,
      width / 2,
      height - 18
    );
  }
}


// ============================================================
// SERIAL EVENT
// ============================================================

void serialEvent(Serial p)
{
  String incoming =
    p.readStringUntil('\n');


  if (incoming == null)
  {
    return;
  }


  incoming = trim(incoming);


  if (incoming.length() == 0)
  {
    return;
  }


  // ----------------------------------------------------------
  // Expected Arduino format:
  //
  // Heartrate: 72 bpm | Confidence: 99 % |
  // Oxygen: 98 % | Status: 3
  // ----------------------------------------------------------

  String pattern =
    "Heartrate:\\s*(\\d+)\\s*bpm\\s*\\|\\s*" +
    "Confidence:\\s*(\\d+)\\s*%\\s*\\|\\s*" +
    "Oxygen:\\s*(\\d+)\\s*%\\s*\\|\\s*" +
    "Status:\\s*(\\d+)";


  String[] values =
    match(incoming, pattern);


  // Ignore Arduino initialization messages
  // or other serial strings.

  if (values == null)
  {
    return;
  }


  heartRate =
    int(values[1]);

  confidence =
    int(values[2]);

  oxygen =
    int(values[3]);

  sensorStatus =
    int(values[4]);


  int currentSampleTime =
    millis();


  lastSampleTime =
    currentSampleTime;


  lastSampleValid =
    heartRate > 0;


  // ----------------------------------------------------------
  // Estimated beat interval
  // ----------------------------------------------------------

  if (lastSampleValid)
  {
    beatInterval_ms =
      60000.0
      /
      float(heartRate);
  }

  else
  {
    beatInterval_ms = 0;
  }


  // ==========================================================
  // INITIAL SIGNAL ACQUISITION
  // ==========================================================

  if (state == STATE_WAITING_SIGNAL)
  {
    addInitialSignalSample(
      lastSampleValid
    );


    int valid =
      countInitialValidSamples();


    if (
      signalWindowCount == WINDOW_SIZE
      &&
      valid >= MIN_VALID_IN_WINDOW
      &&
      lastSampleValid
    )
    {
      state =
        STATE_SIGNAL_ACQUIRED;


      signalAcquiredTime =
        currentSampleTime;
    }
  }


  // ==========================================================
  // BASELINE
  // ==========================================================

  else if (state == STATE_BASELINE)
  {
    if (
      currentSampleTime
      -
      baselineStartTime
      <=
      BASELINE_DURATION_MS
    )
    {
      baselineTotalSamples++;


      if (lastSampleValid)
      {
        baselineValidSamples++;

        baselineHRSum +=
          heartRate;
      }


      updateBaselineQuality();
    }
  }


  // ==========================================================
  // CALM CALIBRATION
  // ==========================================================

  else if (state == STATE_CALM_ACTIVE)
  {
    processCalibrationSample(
      currentSampleTime
    );
  }


  // ==========================================================
  // STRESS CALIBRATION
  // ==========================================================

  else if (state == STATE_STRESS_ACTIVE)
  {
    processCalibrationSample(
      currentSampleTime
    );
  }


  // ==========================================================
  // LIVE DETECTION
  // ==========================================================

  else if (state == STATE_DETECTION_ACTIVE)
  {
    processDetectionSample(
      currentSampleTime
    );
  }
}


// ============================================================
// INITIAL SIGNAL ACQUISITION
// ============================================================

void addInitialSignalSample(
  boolean valid
)
{
  signalWindow[signalWindowIndex] =
    valid;


  signalWindowIndex++;


  if (
    signalWindowIndex >= WINDOW_SIZE
  )
  {
    signalWindowIndex = 0;
  }


  if (
    signalWindowCount < WINDOW_SIZE
  )
  {
    signalWindowCount++;
  }
}


int countInitialValidSamples()
{
  int valid = 0;


  for (
    int i = 0;
    i < signalWindowCount;
    i++
  )
  {
    if (signalWindow[i])
    {
      valid++;
    }
  }


  return valid;
}


void resetInitialSignalWindow()
{
  for (
    int i = 0;
    i < WINDOW_SIZE;
    i++
  )
  {
    signalWindow[i] = false;
  }


  signalWindowIndex = 0;
  signalWindowCount = 0;
}


// ============================================================
// BASELINE CONTROL
// ============================================================

void startBaseline()
{
  baselineStartTime =
    millis();


  baselineTotalSamples = 0;
  baselineValidSamples = 0;

  baselineHRSum = 0;

  baselineQuality = 0;

  restingHR = 0;


  state =
    STATE_BASELINE;
}


void updateBaselineQuality()
{
  if (baselineTotalSamples > 0)
  {
    baselineQuality =
      float(baselineValidSamples)
      /
      float(baselineTotalSamples);
  }

  else
  {
    baselineQuality = 0;
  }
}


void finishBaseline()
{
  updateBaselineQuality();


  if (
    baselineQuality >= MIN_BASELINE_QUALITY
    &&
    baselineValidSamples > 0
    &&
    baselineTotalSamples >= MIN_BASELINE_SAMPLES
  )
  {
    restingHR =
      baselineHRSum
      /
      float(baselineValidSamples);


    state =
      STATE_MODE_MENU;
  }

  else
  {
    state =
      STATE_BASELINE_FAILED;
  }
}


// ============================================================
// START CALIBRATION
// ============================================================

void startCalibration(
  boolean calm
)
{
  calibrationStartTime =
    millis();


  calibrationTotalSamples = 0;
  calibrationValidSamples = 0;


  calibrationHR.clear();
  calibrationTime.clear();


  if (calm)
  {
    calmLastResult =
      RESULT_NONE;


    state =
      STATE_CALM_ACTIVE;
  }

  else
  {
    stressLastResult =
      RESULT_NONE;


    state =
      STATE_STRESS_ACTIVE;
  }
}


// ============================================================
// PROCESS CALIBRATION SAMPLE
// ============================================================

void processCalibrationSample(
  int currentSampleTime
)
{
  calibrationTotalSamples++;


  if (lastSampleValid)
  {
    calibrationValidSamples++;


    float elapsed_s =
      (
        currentSampleTime
        -
        calibrationStartTime
      )
      /
      1000.0;


    calibrationHR.add(
      float(heartRate)
    );


    calibrationTime.add(
      elapsed_s
    );
  }
}


// ============================================================
// CALIBRATION QUALITY
// ============================================================

float getCalibrationQuality()
{
  if (calibrationTotalSamples == 0)
  {
    return 0;
  }


  return
    float(calibrationValidSamples)
    /
    float(calibrationTotalSamples);
}


// ============================================================
// CALIBRATION ELAPSED TIME
// ============================================================

float getCalibrationElapsed_s()
{
  return
    (
      millis()
      -
      calibrationStartTime
    )
    /
    1000.0;
}


// ============================================================
// WEIGHTED CALIBRATION AVERAGE
// ============================================================

float computeWeightedCalibrationAverage(
  float totalDuration_s
)
{
  if (calibrationHR.size() == 0)
  {
    return 0;
  }


  float safeDuration =
    max(
      totalDuration_s,
      0.001
    );


  float weightedSum = 0;
  float totalWeight = 0;


  for (
    int i = 0;
    i < calibrationHR.size();
    i++
  )
  {
    float relativeTime =
      calibrationTime.get(i)
      /
      safeDuration;


    relativeTime =
      constrain(
        relativeTime,
        0,
        1
      );


    float weight =
      1.0
      +
      CALIBRATION_WEIGHT_GAIN
      *
      relativeTime;


    weightedSum +=
      calibrationHR.get(i)
      *
      weight;


    totalWeight +=
      weight;
  }


  if (totalWeight <= 0)
  {
    return 0;
  }


  return
    weightedSum
    /
    totalWeight;
}


// ============================================================
// FINISH CALM CALIBRATION
// ============================================================

void finishCalmCalibration()
{
  lastCalmTrialDuration_s =
    (
      millis()
      -
      calibrationStartTime
    )
    /
    1000.0;


  lastCalmTrialQuality =
    getCalibrationQuality();


  if (calibrationValidSamples == 0)
  {
    lastCalmTrialHR = 0;

    lastCalmTrialDelta = 0;


    calmLastResult =
      RESULT_NO_DATA;


    state =
      STATE_CALM_RESULT;


    return;
  }


  lastCalmTrialHR =
    computeWeightedCalibrationAverage(
      lastCalmTrialDuration_s
    );


  lastCalmTrialDelta =
    restingHR
    -
    lastCalmTrialHR;


  // ----------------------------------------------------------
  // Accept calibration if HR decreased by at least 1 bpm.
  //
  // A new valid calibration replaces the previous one.
  // A weak trial does NOT delete the previous valid one.
  // ----------------------------------------------------------

  if (
    lastCalmTrialDelta
    >=
    MIN_CALIBRATION_DELTA_BPM
  )
  {
    calmCalibrationHR =
      lastCalmTrialHR;


    deltaCalm =
      lastCalmTrialDelta;


    calmCalibrationValid =
      true;


    calmLastResult =
      RESULT_ACCEPTED;
  }

  else
  {
    calmLastResult =
      RESULT_WEAK;
  }


  state =
    STATE_CALM_RESULT;
}


// ============================================================
// FINISH STRESS CALIBRATION
// ============================================================

void finishStressCalibration()
{
  lastStressTrialDuration_s =
    (
      millis()
      -
      calibrationStartTime
    )
    /
    1000.0;


  lastStressTrialQuality =
    getCalibrationQuality();


  // ----------------------------------------------------------
  // Stress calibration shorter than 60 seconds:
  // incomplete test.
  // ----------------------------------------------------------

  if (
    millis()
    -
    calibrationStartTime
    <
    MIN_STRESS_DURATION_MS
  )
  {
    lastStressTrialHR = 0;

    lastStressTrialDelta = 0;


    stressLastResult =
      RESULT_INCOMPLETE;


    state =
      STATE_STRESS_RESULT;


    return;
  }


  if (calibrationValidSamples == 0)
  {
    lastStressTrialHR = 0;

    lastStressTrialDelta = 0;


    stressLastResult =
      RESULT_NO_DATA;


    state =
      STATE_STRESS_RESULT;


    return;
  }


  lastStressTrialHR =
    computeWeightedCalibrationAverage(
      lastStressTrialDuration_s
    );


  lastStressTrialDelta =
    lastStressTrialHR
    -
    restingHR;


  // ----------------------------------------------------------
  // Accept calibration if HR increased by at least 1 bpm.
  // ----------------------------------------------------------

  if (
    lastStressTrialDelta
    >=
    MIN_CALIBRATION_DELTA_BPM
  )
  {
    stressCalibrationHR =
      lastStressTrialHR;


    deltaStress =
      lastStressTrialDelta;


    stressCalibrationValid =
      true;


    stressLastResult =
      RESULT_ACCEPTED;
  }

  else
  {
    stressLastResult =
      RESULT_WEAK;
  }


  state =
    STATE_STRESS_RESULT;
}


// ============================================================
// PERSONALIZED THRESHOLDS
// ============================================================

// Entry offsets are normally half the measured calibration
// delta, but can never be smaller than 1 bpm.

float getStressOffset()
{
  return
    max(
      MIN_THRESHOLD_OFFSET_BPM,
      0.50 * deltaStress
    );
}


float getCalmOffset()
{
  return
    max(
      MIN_THRESHOLD_OFFSET_BPM,
      0.50 * deltaCalm
    );
}


// ------------------------------------------------------------
// STRESS THRESHOLDS
// ------------------------------------------------------------

float getStressEnterThreshold()
{
  return
    restingHR
    +
    getStressOffset();
}


float getStressExitThreshold()
{
  // Hysteresis:
  //
  // once STRESSED, HR must return closer to resting HR
  // before leaving the state.

  return
    restingHR
    +
    0.50
    *
    getStressOffset();
}


// ------------------------------------------------------------
// CALM THRESHOLDS
// ------------------------------------------------------------

float getCalmEnterThreshold()
{
  return
    restingHR
    -
    getCalmOffset();
}


float getCalmExitThreshold()
{
  return
    restingHR
    -
    0.50
    *
    getCalmOffset();
}


// ============================================================
// START LIVE DETECTION
// ============================================================

void startDetection()
{
  if (
    !calmCalibrationValid
    ||
    !stressCalibrationValid
  )
  {
    return;
  }


  detectionStartTime =
    millis();


  detectionTotalSamples = 0;
  detectionValidSamples = 0;

  detectionQuality = 0;


  detectedState =
    DETECT_NEUTRAL;


  candidateType =
    CANDIDATE_NONE;

  candidateStartTime = 0;


  currentRollingHR = 0;

  rollingAvailable = false;

  currentWindowValidSamples = 0;


  resetDetectionWindow();


  rawGraphTime.clear();
  rawGraphHR.clear();
  rawGraphConnected.clear();


  rollingGraphTime.clear();
  rollingGraphHR.clear();
  rollingGraphConnected.clear();


  previousDetectionSampleTime = 0;

  previousDetectionSampleWasValid =
    false;


  previousRollingPointTime = 0;

  previousRollingAvailable =
    false;


  state =
    STATE_DETECTION_ACTIVE;
}


// ============================================================
// STOP LIVE DETECTION
// ============================================================

void stopDetection()
{
  state =
    STATE_MODE_MENU;
}


// ============================================================
// DETECTION WINDOW
// ============================================================

void resetDetectionWindow()
{
  for (
    int i = 0;
    i < DETECTION_WINDOW_SIZE;
    i++
  )
  {
    detectionWindow[i] = 0;
  }


  detectionWindowIndex = 0;
  detectionWindowCount = 0;
}


void addDetectionSampleToWindow(
  int hr
)
{
  detectionWindow[detectionWindowIndex] =
    hr;


  detectionWindowIndex++;


  if (
    detectionWindowIndex
    >=
    DETECTION_WINDOW_SIZE
  )
  {
    detectionWindowIndex = 0;
  }


  if (
    detectionWindowCount
    <
    DETECTION_WINDOW_SIZE
  )
  {
    detectionWindowCount++;
  }
}


// ============================================================
// DETECTION WINDOW STATISTICS
// ============================================================

int countDetectionWindowValid()
{
  int valid = 0;


  for (
    int i = 0;
    i < detectionWindowCount;
    i++
  )
  {
    if (
      detectionWindow[i] > 0
    )
    {
      valid++;
    }
  }


  return valid;
}


float computeDetectionRollingMean()
{
  float sum = 0;

  int valid = 0;


  for (
    int i = 0;
    i < detectionWindowCount;
    i++
  )
  {
    if (
      detectionWindow[i] > 0
    )
    {
      sum +=
        detectionWindow[i];


      valid++;
    }
  }


  if (valid == 0)
  {
    return 0;
  }


  return
    sum
    /
    float(valid);
}


// ============================================================
// PROCESS DETECTION SAMPLE
// ============================================================

void processDetectionSample(
  int currentSampleTime
)
{
  detectionTotalSamples++;


  if (lastSampleValid)
  {
    detectionValidSamples++;
  }


  if (detectionTotalSamples > 0)
  {
    detectionQuality =
      float(detectionValidSamples)
      /
      float(detectionTotalSamples);
  }


  // ----------------------------------------------------------
  // Measured HR graph
  // ----------------------------------------------------------

  int deltaTime_ms = 0;


  if (
    previousDetectionSampleTime > 0
  )
  {
    deltaTime_ms =
      currentSampleTime
      -
      previousDetectionSampleTime;
  }


  if (lastSampleValid)
  {
    float elapsed_s =
      (
        currentSampleTime
        -
        detectionStartTime
      )
      /
      1000.0;


    boolean connectRaw =
      previousDetectionSampleWasValid
      &&
      deltaTime_ms > 0
      &&
      deltaTime_ms <= 1500;


    rawGraphTime.add(
      elapsed_s
    );


    rawGraphHR.add(
      float(heartRate)
    );


    rawGraphConnected.add(
      connectRaw
    );
  }


  previousDetectionSampleTime =
    currentSampleTime;


  previousDetectionSampleWasValid =
    lastSampleValid;


  // ----------------------------------------------------------
  // Add every received HR sample to the rolling window.
  //
  // HR = 0 is intentionally included in the window,
  // but excluded from the mean.
  // ----------------------------------------------------------

  addDetectionSampleToWindow(
    heartRate
  );


  currentWindowValidSamples =
    countDetectionWindowValid();


  // ----------------------------------------------------------
  // Classification requires:
  //
  // complete 10-sample window
  // AND
  // at least 7 valid HR samples
  // ----------------------------------------------------------

  if (
    detectionWindowCount
    ==
    DETECTION_WINDOW_SIZE
    &&
    currentWindowValidSamples
    >=
    DETECTION_MIN_VALID
  )
  {
    currentRollingHR =
      computeDetectionRollingMean();


    rollingAvailable =
      true;


    // --------------------------------------------------------
    // Save Smoothed HR graph point
    // --------------------------------------------------------

    float elapsed_s =
      (
        currentSampleTime
        -
        detectionStartTime
      )
      /
      1000.0;


    int rollingDelta_ms = 0;


    if (
      previousRollingPointTime > 0
    )
    {
      rollingDelta_ms =
        currentSampleTime
        -
        previousRollingPointTime;
    }


    boolean connectRolling =
      previousRollingAvailable
      &&
      rollingDelta_ms > 0
      &&
      rollingDelta_ms <= 1500;


    rollingGraphTime.add(
      elapsed_s
    );


    rollingGraphHR.add(
      currentRollingHR
    );


    rollingGraphConnected.add(
      connectRolling
    );


    previousRollingPointTime =
      currentSampleTime;


    previousRollingAvailable =
      true;


    // --------------------------------------------------------
    // Calm / Neutral / Stress classifier
    // --------------------------------------------------------

    updateDetectedState(
      currentRollingHR,
      currentSampleTime
    );
  }

  else
  {
    // Insufficient recent data for a reliable rolling mean.

    rollingAvailable =
      false;


    previousRollingAvailable =
      false;


    clearCandidate();
  }
}


// ============================================================
// CANDIDATE PERSISTENCE
// ============================================================

boolean candidateConfirmed(
  int requestedCandidate,
  int currentTime
)
{
  // First sample satisfying this candidate condition.

  if (
    candidateType
    !=
    requestedCandidate
  )
  {
    candidateType =
      requestedCandidate;


    candidateStartTime =
      currentTime;


    return false;
  }


  // Same condition has persisted continuously.

  return
    currentTime
    -
    candidateStartTime
    >=
    STATE_PERSISTENCE_MS;
}


void clearCandidate()
{
  candidateType =
    CANDIDATE_NONE;


  candidateStartTime = 0;
}


// ============================================================
// STATE CLASSIFIER
// ============================================================

void updateDetectedState(
  float smoothedHR,
  int currentTime
)
{
  // ==========================================================
  // CURRENT STATE = NEUTRAL
  // ==========================================================

  if (
    detectedState
    ==
    DETECT_NEUTRAL
  )
  {
    // --------------------------------------------------------
    // Candidate Stress
    // --------------------------------------------------------

    if (
      smoothedHR
      >=
      getStressEnterThreshold()
    )
    {
      if (
        candidateConfirmed(
          CANDIDATE_ENTER_STRESS,
          currentTime
        )
      )
      {
        detectedState =
          DETECT_STRESSED;


        clearCandidate();


        triggerStressAlert();
      }
    }


    // --------------------------------------------------------
    // Candidate Calm
    // --------------------------------------------------------

    else if (
      smoothedHR
      <=
      getCalmEnterThreshold()
    )
    {
      if (
        candidateConfirmed(
          CANDIDATE_ENTER_CALM,
          currentTime
        )
      )
      {
        detectedState =
          DETECT_CALM;


        clearCandidate();
      }
    }


    else
    {
      clearCandidate();
    }
  }


  // ==========================================================
  // CURRENT STATE = STRESSED
  // ==========================================================

  else if (
    detectedState
    ==
    DETECT_STRESSED
  )
  {
    // Hysteresis:
    //
    // Stay stressed until Smoothed HR falls below the lower
    // stress-exit threshold for 2 consecutive seconds.

    if (
      smoothedHR
      <=
      getStressExitThreshold()
    )
    {
      if (
        candidateConfirmed(
          CANDIDATE_EXIT_STRESS,
          currentTime
        )
      )
      {
        detectedState =
          DETECT_NEUTRAL;


        clearCandidate();
      }
    }

    else
    {
      clearCandidate();
    }
  }


  // ==========================================================
  // CURRENT STATE = CALM
  // ==========================================================

  else if (
    detectedState
    ==
    DETECT_CALM
  )
  {
    // Symmetric hysteresis for Calm.

    if (
      smoothedHR
      >=
      getCalmExitThreshold()
    )
    {
      if (
        candidateConfirmed(
          CANDIDATE_EXIT_CALM,
          currentTime
        )
      )
      {
        detectedState =
          DETECT_NEUTRAL;


        clearCandidate();
      }
    }

    else
    {
      clearCandidate();
    }
  }
}


// ============================================================
// STRESS ALERT
// ============================================================

void triggerStressAlert()
{
  println(
    "STRESSED state confirmed -> BEEP BEEP"
  );


  if (
    serialConnected
    &&
    myPort != null
  )
  {
    myPort.write('B');
  }
}

// ============================================================
// CURRENT SIGNAL VALIDITY
// ============================================================

boolean isCurrentSignalValid()
{
  boolean dataFresh =
    millis()
    -
    lastSampleTime
    <
    1500;


  return
    lastSampleValid
    &&
    dataFresh;
}


// ============================================================
// DRAW - WAITING FOR SIGNAL
// ============================================================

void drawWaitingForSignal()
{
  drawMainTitle(
    "Calm vs Stressed Mode",
    "Acquiring resting PPG signal"
  );


  int validWindow =
    countInitialValidSamples();


  drawMetricCard(
    80,
    170,
    340,
    160,
    "CURRENT HEART RATE",
    isCurrentSignalValid()
      ? str(heartRate)
      : "--",
    "bpm"
  );


  drawMetricCard(
    480,
    170,
    340,
    160,
    "SpO2",
    oxygen > 0
      ? str(oxygen)
      : "--",
    "%"
  );


  drawMetricCard(
    880,
    170,
    340,
    160,
    "CONFIDENCE",
    str(confidence),
    "%"
  );


  drawCard(
    80,
    390,
    1140,
    240
  );


  fill(darkBlue);

  textAlign(LEFT, CENTER);

  textSize(22);

  text(
    "Signal acquisition",
    125,
    435
  );


  if (isCurrentSignalValid())
  {
    fill(successColor);

    textSize(16);

    text(
      "Valid PPG signal detected",
      125,
      480
    );
  }

  else
  {
    fill(warningColor);

    textSize(16);

    text(
      "Waiting for a valid PPG signal",
      125,
      480
    );
  }


  fill(textColor);

  textSize(18);

  text(
    "Valid samples: "
    +
    validWindow
    +
    " / "
    +
    WINDOW_SIZE,
    125,
    530
  );


  fill(secondaryText);

  textSize(14);

  text(
    "Keep your finger still while the signal stabilizes.",
    125,
    570
  );


  drawSimpleProgress(
    125,
    600,
    1030,
    16,
    constrain(
      float(validWindow)
      /
      float(MIN_VALID_IN_WINDOW),
      0,
      1
    )
  );
}


// ============================================================
// DRAW - SIGNAL ACQUIRED
// ============================================================

void drawSignalAcquired()
{
  drawMainTitle(
    "Calm vs Stressed Mode",
    "Signal check"
  );


  drawCard(
    340,
    190,
    620,
    360
  );


  fill(successColor);

  textAlign(CENTER, CENTER);

  textSize(36);

  text(
    "Signal acquired",
    width / 2,
    290
  );


  fill(textColor);

  textSize(23);

  text(
    "Current HR: "
    +
    heartRate
    +
    " bpm",
    width / 2,
    365
  );


  fill(secondaryText);

  textSize(16);

  text(
    "Starting 30-second resting baseline...",
    width / 2,
    430
  );


  drawSimpleProgress(
    430,
    490,
    440,
    16,
    constrain(
      float(
        millis()
        -
        signalAcquiredTime
      )
      /
      float(
        SIGNAL_ACQUIRED_DISPLAY_MS
      ),
      0,
      1
    )
  );
}


// ============================================================
// DRAW - BASELINE
// ============================================================

void drawBaseline()
{
  drawMainTitle(
    "Resting Heart Rate Baseline",
    "30-second acquisition"
  );


  drawMetricCard(
    60,
    155,
    270,
    150,
    "CURRENT HR",
    isCurrentSignalValid()
      ? str(heartRate)
      : "--",
    "bpm"
  );


  drawMetricCard(
    365,
    155,
    270,
    150,
    "BEAT INTERVAL",
    isCurrentSignalValid()
      ? nf(
          beatInterval_ms,
          0,
          0
        )
      : "--",
    "ms"
  );


  drawMetricCard(
    670,
    155,
    270,
    150,
    "SpO2",
    oxygen > 0
      ? str(oxygen)
      : "--",
    "%"
  );


  drawMetricCard(
    975,
    155,
    270,
    150,
    "CONFIDENCE",
    str(confidence),
    "%"
  );


  drawCard(
    60,
    350,
    1185,
    320
  );


  float elapsed =
    constrain(
      millis()
      -
      baselineStartTime,
      0,
      BASELINE_DURATION_MS
    );


  float elapsed_s =
    elapsed
    /
    1000.0;


  float progress =
    elapsed
    /
    float(BASELINE_DURATION_MS);


  fill(darkBlue);

  textAlign(LEFT, CENTER);

  textSize(22);

  text(
    "Resting baseline",
    105,
    400
  );


  fill(textColor);

  textAlign(RIGHT, CENTER);

  textSize(18);

  text(
    nf(
      elapsed_s,
      0,
      1
    )
    +
    " / 30.0 s",
    1200,
    400
  );


  drawSimpleProgress(
    105,
    445,
    1095,
    20,
    progress
  );


  textAlign(LEFT, CENTER);

  textSize(17);


  if (isCurrentSignalValid())
  {
    fill(successColor);

    text(
      "Signal: valid",
      105,
      520
    );
  }

  else
  {
    fill(warningColor);

    text(
      "Signal temporarily lost - invalid samples are ignored",
      105,
      520
    );
  }


  fill(textColor);

  text(
    "Signal quality: "
    +
    nf(
      baselineQuality
      *
      100.0,
      0,
      1
    )
    +
    "%",
    105,
    565
  );


  fill(secondaryText);

  text(
    "Valid samples: "
    +
    baselineValidSamples
    +
    " / "
    +
    baselineTotalSamples,
    105,
    610
  );
}


// ============================================================
// DRAW - BASELINE FAILED
// ============================================================

void drawBaselineFailed()
{
  drawMainTitle(
    "Resting Heart Rate Baseline",
    "Acquisition problem"
  );


  drawCard(
    300,
    160,
    700,
    500
  );


  fill(warningColor);

  textAlign(CENTER, CENTER);

  textSize(32);

  text(
    "Acquisition not valid",
    width / 2,
    235
  );


  fill(textColor);

  textSize(19);

  text(
    "Signal quality: "
    +
    nf(
      baselineQuality
      *
      100.0,
      0,
      1
    )
    +
    "%",
    width / 2,
    315
  );


  fill(secondaryText);

  textSize(16);

  text(
    "Please reposition your finger and repeat the resting baseline.",
    width / 2,
    395
  );


  fill(primaryBlue);

  noStroke();

  rect(
    retryX,
    retryY,
    retryW,
    retryH,
    18
  );


  fill(whiteColor);

  textSize(19);

  text(
    "RETRY",
    retryX + retryW / 2,
    retryY + retryH / 2
  );
}


// ============================================================
// DRAW - MODE MENU
// ============================================================

void drawModeMenu()
{
  drawMainTitle(
    "Calm vs Stressed Mode",
    "Personalized HR-based calibration and detection"
  );


  // ----------------------------------------------------------
  // Main metrics
  // ----------------------------------------------------------

  drawMetricCard(
    70,
    145,
    270,
    150,
    "RESTING HR",
    nf(
      restingHR,
      0,
      1
    ),
    "bpm"
  );


  drawMetricCard(
    365,
    145,
    270,
    150,
    "CURRENT HR",
    isCurrentSignalValid()
      ? str(heartRate)
      : "--",
    "bpm"
  );


  drawMetricCard(
    660,
    145,
    270,
    150,
    "SpO2",
    oxygen > 0
      ? str(oxygen)
      : "--",
    "%"
  );


  drawMetricCard(
    955,
    145,
    270,
    150,
    "CONFIDENCE",
    str(confidence),
    "%"
  );


  // ----------------------------------------------------------
  // Calm calibration
  // ----------------------------------------------------------

  drawCard(
    110,
    345,
    300,
    175
  );


  textAlign(CENTER, CENTER);

  fill(darkBlue);

  textSize(18);

  text(
    "CALM CALIBRATION",
    260,
    380
  );


  if (calmCalibrationValid)
  {
    fill(calmGreen);

    textSize(17);

    text(
      "READY",
      260,
      420
    );


    fill(textColor);

    textSize(14);

    text(
      "Calm HR: "
      +
      nf(
        calmCalibrationHR,
        0,
        1
      )
      +
      " bpm",
      260,
      458
    );


    text(
      "Change: -"
      +
      nf(
        deltaCalm,
        0,
        1
      )
      +
      " bpm",
      260,
      485
    );
  }

  else
  {
    fill(secondaryText);

    textSize(16);

    text(
      "Not available",
      260,
      438
    );
  }


  // ----------------------------------------------------------
  // Stress calibration
  // ----------------------------------------------------------

  drawCard(
    500,
    345,
    300,
    175
  );


  fill(darkBlue);

  textSize(18);

  text(
    "STRESS CALIBRATION",
    650,
    380
  );


  if (stressCalibrationValid)
  {
    fill(stressRed);

    textSize(17);

    text(
      "READY",
      650,
      420
    );


    fill(textColor);

    textSize(14);

    text(
      "Stress HR: "
      +
      nf(
        stressCalibrationHR,
        0,
        1
      )
      +
      " bpm",
      650,
      458
    );


    text(
      "Change: +"
      +
      nf(
        deltaStress,
        0,
        1
      )
      +
      " bpm",
      650,
      485
    );
  }

  else
  {
    fill(secondaryText);

    textSize(16);

    text(
      "Not available",
      650,
      438
    );
  }


  // ----------------------------------------------------------
  // Detection status
  // ----------------------------------------------------------

  drawCard(
    890,
    345,
    300,
    175
  );


  fill(darkBlue);

  textSize(18);

  text(
    "LIVE DETECTION",
    1040,
    380
  );


  if (
    calmCalibrationValid
    &&
    stressCalibrationValid
  )
  {
    fill(successColor);

    textSize(17);

    text(
      "READY",
      1040,
      420
    );


    fill(textColor);

    textSize(13);

    text(
      "Personal thresholds available",
      1040,
      465
    );
  }

  else
  {
    fill(secondaryText);

    textSize(14);

    text(
      "Complete both calibrations",
      1040,
      445
    );
  }


  // ----------------------------------------------------------
  // Buttons
  // ----------------------------------------------------------

  fill(calmGreen);

  noStroke();

  rect(
    calmButtonX,
    calmButtonY,
    calmButtonW,
    calmButtonH,
    20
  );


  fill(whiteColor);

  textSize(19);

  text(
    "START CALM TEST",
    calmButtonX + calmButtonW / 2,
    calmButtonY + calmButtonH / 2
  );


  fill(stressRed);

  rect(
    stressButtonX,
    stressButtonY,
    stressButtonW,
    stressButtonH,
    20
  );


  fill(whiteColor);

  text(
    "START STRESS TEST",
    stressButtonX + stressButtonW / 2,
    stressButtonY + stressButtonH / 2
  );


  if (
    calmCalibrationValid
    &&
    stressCalibrationValid
  )
  {
    fill(primaryBlue);
  }

  else
  {
    fill(
      175,
      185,
      195
    );
  }


  rect(
    detectionButtonX,
    detectionButtonY,
    detectionButtonW,
    detectionButtonH,
    20
  );


  fill(whiteColor);

  text(
    "START DETECTION",
    detectionButtonX + detectionButtonW / 2,
    detectionButtonY + detectionButtonH / 2
  );
}


// ============================================================
// DRAW - CALIBRATION SCREEN
// ============================================================

void drawCalibrationScreen(
  boolean calm
)
{
  String modeName =
    calm
    ?
    "Calm Calibration"
    :
    "Stress Calibration";


  String subtitle =
    calm
    ?
    "Relax while listening to calming music"
    :
    "Recall a stressful event - minimum duration 60 seconds";


  drawMainTitle(
    modeName,
    subtitle
  );


  // ----------------------------------------------------------
  // STOP button
  // ----------------------------------------------------------

  fill(stressRed);

  noStroke();

  rect(
    calibrationStopX,
    calibrationStopY,
    calibrationStopW,
    calibrationStopH,
    16
  );


  fill(whiteColor);

  textAlign(CENTER, CENTER);

  textSize(18);

  text(
    "STOP",
    calibrationStopX
      +
      calibrationStopW / 2,
    calibrationStopY
      +
      calibrationStopH / 2
  );


  // ----------------------------------------------------------
  // Metrics
  // ----------------------------------------------------------

  drawMetricCard(
    60,
    145,
    270,
    145,
    "CURRENT HR",
    isCurrentSignalValid()
      ? str(heartRate)
      : "--",
    "bpm"
  );


  drawMetricCard(
    365,
    145,
    270,
    145,
    "RESTING HR",
    nf(
      restingHR,
      0,
      1
    ),
    "bpm"
  );


  drawMetricCard(
    670,
    145,
    270,
    145,
    "BEAT INTERVAL",
    isCurrentSignalValid()
      ? nf(
          beatInterval_ms,
          0,
          0
        )
      : "--",
    "ms"
  );


  drawMetricCard(
    975,
    145,
    270,
    145,
    "CONFIDENCE",
    str(confidence),
    "%"
  );


  // ----------------------------------------------------------
  // Recording panel
  // ----------------------------------------------------------

  drawCard(
    120,
    345,
    1060,
    335
  );


  float elapsed_s =
    getCalibrationElapsed_s();


  float quality =
    getCalibrationQuality();


  textAlign(CENTER, CENTER);


  if (calm)
  {
    fill(calmGreen);
  }

  else
  {
    fill(stressRed);
  }


  textSize(30);

  text(
    calm
      ?
      "CALM RECORDING"
      :
      "STRESS RECORDING",
    width / 2,
    400
  );


  fill(textColor);

  textSize(42);

  text(
    formatTimeDetailed(
      elapsed_s
    ),
    width / 2,
    475
  );


  fill(secondaryText);

  textSize(15);

  text(
    "Recording time",
    width / 2,
    515
  );


  fill(textColor);

  textSize(17);

  text(
    "Signal quality: "
    +
    nf(
      quality * 100.0,
      0,
      1
    )
    +
    "%",
    width / 2,
    565
  );


  text(
    "Valid samples: "
    +
    calibrationValidSamples
    +
    " / "
    +
    calibrationTotalSamples,
    width / 2,
    600
  );


  if (!calm)
  {
    float progress =
      constrain(
        elapsed_s
        /
        60.0,
        0,
        1
      );


    drawSimpleProgress(
      300,
      635,
      700,
      16,
      progress
    );


    fill(secondaryText);

    textSize(13);

    text(
      elapsed_s >= 60.0
      ?
      "Minimum duration reached"
      :
      "Minimum required duration: 60 seconds",
      width / 2,
      660
    );
  }


  if (!isCurrentSignalValid())
  {
    fill(warningColor);

    textSize(16);

    text(
      "SIGNAL LOST - invalid HR samples are ignored",
      width / 2,
      320
    );
  }
}


// ============================================================
// DRAW - CALM RESULT
// ============================================================

void drawCalmResult()
{
  drawMainTitle(
    "Calm Calibration",
    "Test result"
  );


  drawCard(
    260,
    145,
    780,
    510
  );


  textAlign(CENTER, CENTER);


  if (
    calmLastResult
    ==
    RESULT_ACCEPTED
  )
  {
    fill(calmGreen);

    textSize(31);

    text(
      "CALM RESPONSE DETECTED",
      width / 2,
      205
    );
  }

  else if (
    calmLastResult
    ==
    RESULT_WEAK
  )
  {
    fill(warningColor);

    textSize(29);

    text(
      "WEAK CALM RESPONSE",
      width / 2,
      205
    );
  }

  else
  {
    fill(warningColor);

    textSize(29);

    text(
      "NO VALID CALM DATA",
      width / 2,
      205
    );
  }


  fill(textColor);

  textSize(17);


  text(
    "Resting HR: "
    +
    nf(
      restingHR,
      0,
      1
    )
    +
    " bpm",
    width / 2,
    290
  );


  if (
    calmLastResult
    !=
    RESULT_NO_DATA
  )
  {
    text(
      "Weighted Calm HR: "
      +
      nf(
        lastCalmTrialHR,
        0,
        1
      )
      +
      " bpm",
      width / 2,
      335
    );


    text(
      "HR change: "
      +
      nf(
        lastCalmTrialDelta,
        0,
        1
      )
      +
      " bpm",
      width / 2,
      380
    );
  }


  text(
    "Duration: "
    +
    formatTimeDetailed(
      lastCalmTrialDuration_s
    ),
    width / 2,
    440
  );


  text(
    "Signal quality: "
    +
    nf(
      lastCalmTrialQuality
      *
      100.0,
      0,
      1
    )
    +
    "%",
    width / 2,
    485
  );


  if (
    calmLastResult
    ==
    RESULT_WEAK
  )
  {
    fill(secondaryText);

    textSize(14);

    text(
      calmCalibrationValid
      ?
      "Response below 1 bpm. Previous valid Calm calibration retained."
      :
      "Response below 1 bpm. Consider repeating the Calm test.",
      width / 2,
      545
    );
  }


  fill(primaryBlue);

  noStroke();

  rect(
    backButtonX,
    backButtonY,
    backButtonW,
    backButtonH,
    18
  );


  fill(whiteColor);

  textSize(18);

  text(
    "BACK TO MENU",
    backButtonX + backButtonW / 2,
    backButtonY + backButtonH / 2
  );
}


// ============================================================
// DRAW - STRESS RESULT
// ============================================================

void drawStressResult()
{
  drawMainTitle(
    "Stress Calibration",
    "Test result"
  );


  drawCard(
    260,
    145,
    780,
    510
  );


  textAlign(CENTER, CENTER);


  if (
    stressLastResult
    ==
    RESULT_ACCEPTED
  )
  {
    fill(stressRed);

    textSize(31);

    text(
      "STRESS RESPONSE DETECTED",
      width / 2,
      205
    );
  }

  else if (
    stressLastResult
    ==
    RESULT_INCOMPLETE
  )
  {
    fill(warningColor);

    textSize(29);

    text(
      "TEST INCOMPLETE",
      width / 2,
      205
    );
  }

  else if (
    stressLastResult
    ==
    RESULT_WEAK
  )
  {
    fill(warningColor);

    textSize(29);

    text(
      "WEAK STRESS RESPONSE",
      width / 2,
      205
    );
  }

  else
  {
    fill(warningColor);

    textSize(29);

    text(
      "NO VALID STRESS DATA",
      width / 2,
      205
    );
  }


  fill(textColor);

  textSize(17);


  text(
    "Resting HR: "
    +
    nf(
      restingHR,
      0,
      1
    )
    +
    " bpm",
    width / 2,
    285
  );


  if (
    stressLastResult
    ==
    RESULT_ACCEPTED
    ||
    stressLastResult
    ==
    RESULT_WEAK
  )
  {
    text(
      "Weighted Stress HR: "
      +
      nf(
        lastStressTrialHR,
        0,
        1
      )
      +
      " bpm",
      width / 2,
      330
    );


    text(
      "HR change: +"
      +
      nf(
        lastStressTrialDelta,
        0,
        1
      )
      +
      " bpm",
      width / 2,
      375
    );
  }


  text(
    "Duration: "
    +
    formatTimeDetailed(
      lastStressTrialDuration_s
    ),
    width / 2,
    435
  );


  text(
    "Signal quality: "
    +
    nf(
      lastStressTrialQuality
      *
      100.0,
      0,
      1
    )
    +
    "%",
    width / 2,
    480
  );


  fill(secondaryText);

  textSize(14);


  if (
    stressLastResult
    ==
    RESULT_INCOMPLETE
  )
  {
    text(
      "Minimum required duration is 60 seconds. Calibration was not updated.",
      width / 2,
      540
    );
  }

  else if (
    stressLastResult
    ==
    RESULT_WEAK
  )
  {
    text(
      stressCalibrationValid
      ?
      "Response below 1 bpm. Previous valid Stress calibration retained."
      :
      "Response below 1 bpm. Consider repeating the Stress test.",
      width / 2,
      540
    );
  }


  fill(primaryBlue);

  noStroke();

  rect(
    backButtonX,
    backButtonY,
    backButtonW,
    backButtonH,
    18
  );


  fill(whiteColor);

  textSize(18);

  text(
    "BACK TO MENU",
    backButtonX + backButtonW / 2,
    backButtonY + backButtonH / 2
  );
}


// ============================================================
// DRAW - LIVE DETECTION
// ============================================================

void drawDetectionScreen()
{
  drawMainTitle(
    "Live Calm / Stress Detection",
    "Personalized HR-based state recognition"
  );


  // ----------------------------------------------------------
  // STOP button
  // ----------------------------------------------------------

  fill(stressRed);

  noStroke();

  rect(
    detectionStopX,
    detectionStopY,
    detectionStopW,
    detectionStopH,
    16
  );


  fill(whiteColor);

  textAlign(CENTER, CENTER);

  textSize(17);

  text(
    "STOP DETECTION",
    detectionStopX
      +
      detectionStopW / 2,
    detectionStopY
      +
      detectionStopH / 2
  );


  // ----------------------------------------------------------
  // Top metric cards
  // ----------------------------------------------------------

  float cardY = 125;
  float cardW = 190;
  float cardH = 112;
  float gap = 12;

  float x1 = 40;
  float x2 = x1 + cardW + gap;
  float x3 = x2 + cardW + gap;
  float x4 = x3 + cardW + gap;
  float x5 = x4 + cardW + gap;
  float x6 = x5 + cardW + gap;


  drawMetricCard(
    x1,
    cardY,
    cardW,
    cardH,
    "CURRENT HR",
    isCurrentSignalValid()
      ? str(heartRate)
      : "--",
    "bpm"
  );


  drawMetricCard(
    x2,
    cardY,
    cardW,
    cardH,
    "SMOOTHED HR",
    rollingAvailable
      ? nf(
          currentRollingHR,
          0,
          1
        )
      : "--",
    "bpm"
  );


  drawMetricCard(
    x3,
    cardY,
    cardW,
    cardH,
    "RESTING HR",
    nf(
      restingHR,
      0,
      1
    ),
    "bpm"
  );


  drawMetricCard(
    x4,
    cardY,
    cardW,
    cardH,
    "BEAT INTERVAL",
    isCurrentSignalValid()
      ? nf(
          beatInterval_ms,
          0,
          0
        )
      : "--",
    "ms"
  );


  drawMetricCard(
    x5,
    cardY,
    cardW,
    cardH,
    "SpO2",
    oxygen > 0
      ? str(oxygen)
      : "--",
    "%"
  );


  drawMetricCard(
    x6,
    cardY,
    cardW,
    cardH,
    "CONFIDENCE",
    str(confidence),
    "%"
  );


  // ----------------------------------------------------------
  // Signal message
  // ----------------------------------------------------------

  if (!isCurrentSignalValid())
  {
    fill(warningColor);

    textAlign(CENTER, CENTER);

    textSize(16);

    text(
      "SIGNAL LOST",
      width / 2,
      260
    );
  }

  else if (
    detectionWindowCount
    <
    DETECTION_WINDOW_SIZE
  )
  {
    fill(primaryBlue);

    textAlign(CENTER, CENTER);

    textSize(15);

    text(
      "Analyzing heart-rate signal...",
      width / 2,
      260
    );
  }

  else if (!rollingAvailable)
  {
    fill(warningColor);

    textAlign(CENTER, CENTER);

    textSize(15);

    text(
      "Signal quality temporarily too low for classification",
      width / 2,
      260
    );
  }


  // ----------------------------------------------------------
  // Graph
  // ----------------------------------------------------------

  drawDetectionGraph(
    40,
    290,
    850,
    475
  );


  // ----------------------------------------------------------
  // State panel
  // ----------------------------------------------------------

  drawDetectionStatePanel(
    915,
    290,
    345,
    475
  );
}


// ============================================================
// DRAW - DETECTION GRAPH
// ============================================================

void drawDetectionGraph(
  float panelX,
  float panelY,
  float panelW,
  float panelH
)
{
  drawCard(
    panelX,
    panelY,
    panelW,
    panelH
  );


  float graphX =
    panelX + 70;

  float graphY =
    panelY + 45;

  float graphW =
    panelW - 100;

  float graphH =
    panelH - 105;


  float elapsed_s =
    (
      millis()
      -
      detectionStartTime
    )
    /
    1000.0;


  float xMax =
    max(
      10.0,
      ceil(
        elapsed_s
        /
        10.0
      )
      *
      10.0
    );


  float maxMeasuredHR =
    getDetectionMaximumHR();


  float minMeasuredHR =
    getDetectionMinimumHR();


  float yMin =
    max(
      30.0,
      min(
        restingHR - 25.0,
        minMeasuredHR - 10.0
      )
    );


  float yMax =
    max(
      restingHR + 35.0,
      maxMeasuredHR + 10.0
    );


  float calmThreshold =
    getCalmEnterThreshold();


  float stressThreshold =
    getStressEnterThreshold();


  // ----------------------------------------------------------
  // Calm region
  // ----------------------------------------------------------

  drawHRRegion(
    graphX,
    graphY,
    graphW,
    graphH,
    yMin,
    calmThreshold,
    calmGreen,
    yMin,
    yMax
  );


  // ----------------------------------------------------------
  // Neutral region
  // ----------------------------------------------------------

  drawHRRegion(
    graphX,
    graphY,
    graphW,
    graphH,
    calmThreshold,
    stressThreshold,
    neutralColor,
    yMin,
    yMax
  );


  // ----------------------------------------------------------
  // Stress region
  // ----------------------------------------------------------

  drawHRRegion(
    graphX,
    graphY,
    graphW,
    graphH,
    stressThreshold,
    yMax,
    stressRed,
    yMin,
    yMax
  );


  // ----------------------------------------------------------
  // Y-axis grid
  // ----------------------------------------------------------

  int firstY =
    int(
      ceil(
        yMin
        /
        10.0
      )
      *
      10
    );


  textSize(11);

  textAlign(RIGHT, CENTER);


  for (
    int hrTick = firstY;
    hrTick <= yMax;
    hrTick += 10
  )
  {
    float py =
      map(
        hrTick,
        yMin,
        yMax,
        graphY + graphH,
        graphY
      );


    stroke(
      220,
      225,
      230
    );

    strokeWeight(1);


    line(
      graphX,
      py,
      graphX + graphW,
      py
    );


    noStroke();

    fill(secondaryText);

    text(
      hrTick,
      graphX - 8,
      py
    );
  }


  // ----------------------------------------------------------
  // X-axis grid
  // ----------------------------------------------------------

  textAlign(CENTER, TOP);


  for (
    int i = 0;
    i <= 4;
    i++
  )
  {
    float t =
      xMax
      *
      i
      /
      4.0;


    float px =
      map(
        t,
        0,
        xMax,
        graphX,
        graphX + graphW
      );


    stroke(
      220,
      225,
      230
    );


    line(
      px,
      graphY,
      px,
      graphY + graphH
    );


    noStroke();

    fill(secondaryText);


    text(
      nf(
        t,
        0,
        0
      ),
      px,
      graphY + graphH + 8
    );
  }


  // ----------------------------------------------------------
  // Threshold lines
  // ----------------------------------------------------------

  drawThresholdLine(
    graphX,
    graphY,
    graphW,
    graphH,
    restingHR,
    yMin,
    yMax,
    darkBlue
  );


  drawThresholdLine(
    graphX,
    graphY,
    graphW,
    graphH,
    calmThreshold,
    yMin,
    yMax,
    calmGreen
  );


  drawThresholdLine(
    graphX,
    graphY,
    graphW,
    graphH,
    stressThreshold,
    yMin,
    yMax,
    stressRed
  );


  // ----------------------------------------------------------
  // GRAPH LEGEND
  // ----------------------------------------------------------

  float legendY =
    panelY + 20;


  // Measured HR

  stroke(
    145,
    155,
    165
  );

  strokeWeight(2);


  line(
    panelX + 460,
    legendY,
    panelX + 490,
    legendY
  );


  noStroke();

  fill(secondaryText);

  textAlign(LEFT, CENTER);

  textSize(11);


  text(
    "Measured HR",
    panelX + 500,
    legendY
  );


  // Smoothed HR

  stroke(primaryBlue);

  strokeWeight(3);


  line(
    panelX + 610,
    legendY,
    panelX + 640,
    legendY
  );


  noStroke();

  fill(secondaryText);


  text(
    "Smoothed HR",
    panelX + 650,
    legendY
  );


  // ----------------------------------------------------------
  // MEASURED HR
  // ----------------------------------------------------------

  strokeWeight(1.5);


  for (
    int i = 0;
    i < rawGraphTime.size();
    i++
  )
  {
    float px =
      map(
        rawGraphTime.get(i),
        0,
        xMax,
        graphX,
        graphX + graphW
      );


    float py =
      map(
        rawGraphHR.get(i),
        yMin,
        yMax,
        graphY + graphH,
        graphY
      );


    if (
      i > 0
      &&
      rawGraphConnected.get(i)
    )
    {
      float previousPX =
        map(
          rawGraphTime.get(i - 1),
          0,
          xMax,
          graphX,
          graphX + graphW
        );


      float previousPY =
        map(
          rawGraphHR.get(i - 1),
          yMin,
          yMax,
          graphY + graphH,
          graphY
        );


      stroke(
        145,
        155,
        165
      );


      line(
        previousPX,
        previousPY,
        px,
        py
      );
    }


    noStroke();

    fill(
      145,
      155,
      165
    );


    ellipse(
      px,
      py,
      4,
      4
    );
  }


  // ----------------------------------------------------------
  // SMOOTHED HR
  // ----------------------------------------------------------

  strokeWeight(3);


  for (
    int i = 0;
    i < rollingGraphTime.size();
    i++
  )
  {
    float px =
      map(
        rollingGraphTime.get(i),
        0,
        xMax,
        graphX,
        graphX + graphW
      );


    float py =
      map(
        rollingGraphHR.get(i),
        yMin,
        yMax,
        graphY + graphH,
        graphY
      );


    if (
      i > 0
      &&
      rollingGraphConnected.get(i)
    )
    {
      float previousPX =
        map(
          rollingGraphTime.get(i - 1),
          0,
          xMax,
          graphX,
          graphX + graphW
        );


      float previousPY =
        map(
          rollingGraphHR.get(i - 1),
          yMin,
          yMax,
          graphY + graphH,
          graphY
        );


      stroke(primaryBlue);


      line(
        previousPX,
        previousPY,
        px,
        py
      );
    }


    noStroke();

    fill(primaryBlue);


    ellipse(
      px,
      py,
      5,
      5
    );
  }


  // ----------------------------------------------------------
  // Axis labels
  // ----------------------------------------------------------

  fill(textColor);

  textAlign(LEFT, CENTER);

  textSize(13);


  text(
    "Heart rate (bpm)",
    graphX,
    panelY + 20
  );


  textAlign(CENTER, CENTER);


  text(
    "Detection time (s)",
    graphX + graphW / 2,
    panelY + panelH - 20
  );


  noStroke();
}


// ============================================================
// DRAW - STATE PANEL
// ============================================================

void drawDetectionStatePanel(
  float x,
  float y,
  float w,
  float h
)
{
  drawCard(
    x,
    y,
    w,
    h
  );


  textAlign(CENTER, CENTER);


  fill(secondaryText);

  textSize(13);


  text(
    "CURRENT STATE",
    x + w / 2,
    y + 30
  );


  color stateColor =
    getDetectedStateColor();


  fill(stateColor);

  textSize(31);


  text(
    getDetectedStateName(),
    x + w / 2,
    y + 72
  );


  // ----------------------------------------------------------
  // Smoothed HR
  // ----------------------------------------------------------

  fill(textColor);

  textSize(15);


  if (rollingAvailable)
  {
    text(
      "Smoothed HR: "
      +
      nf(
        currentRollingHR,
        0,
        1
      )
      +
      " bpm",
      x + w / 2,
      y + 115
    );
  }

  else
  {
    text(
      "Smoothed HR: --",
      x + w / 2,
      y + 115
    );
  }


  // Divider

  stroke(
    225,
    230,
    235
  );


  line(
    x + 25,
    y + 145,
    x + w - 25,
    y + 145
  );


  noStroke();


  // ----------------------------------------------------------
  // Thresholds
  // ----------------------------------------------------------

  textAlign(LEFT, CENTER);

  textSize(14);


  fill(calmGreen);


  text(
    "Calm threshold",
    x + 25,
    y + 190
  );


  fill(textColor);

  textAlign(RIGHT, CENTER);


  text(
    nf(
      getCalmEnterThreshold(),
      0,
      1
    )
    +
    " bpm",
    x + w - 25,
    y + 190
  );


  fill(neutralColor);

  textAlign(LEFT, CENTER);


  text(
    "Resting HR",
    x + 25,
    y + 235
  );


  fill(textColor);

  textAlign(RIGHT, CENTER);


  text(
    nf(
      restingHR,
      0,
      1
    )
    +
    " bpm",
    x + w - 25,
    y + 235
  );


  fill(stressRed);

  textAlign(LEFT, CENTER);


  text(
    "Stress threshold",
    x + 25,
    y + 280
  );


  fill(textColor);

  textAlign(RIGHT, CENTER);


  text(
    nf(
      getStressEnterThreshold(),
      0,
      1
    )
    +
    " bpm",
    x + w - 25,
    y + 280
  );


  // Divider

  stroke(
    225,
    230,
    235
  );


  line(
    x + 25,
    y + 315,
    x + w - 25,
    y + 315
  );


  noStroke();


  // ----------------------------------------------------------
  // Session statistics
  // ----------------------------------------------------------

  fill(textColor);

  textAlign(LEFT, CENTER);


  text(
    "Signal quality",
    x + 25,
    y + 360
  );


  textAlign(RIGHT, CENTER);


  text(
    nf(
      detectionQuality
      *
      100.0,
      0,
      1
    )
    +
    "%",
    x + w - 25,
    y + 360
  );


  float detectionTime_s =
    (
      millis()
      -
      detectionStartTime
    )
    /
    1000.0;


  textAlign(LEFT, CENTER);


  text(
    "Detection time",
    x + 25,
    y + 410
  );


  textAlign(RIGHT, CENTER);


  text(
    formatTimeDetailed(
      detectionTime_s
    ),
    x + w - 25,
    y + 410
  );
}


// ============================================================
// DETECTION GRAPH HELPERS
// ============================================================

float getDetectionMaximumHR()
{
  float maxValue =
    max(
      restingHR,
      getStressEnterThreshold()
    );


  for (
    int i = 0;
    i < rawGraphHR.size();
    i++
  )
  {
    maxValue =
      max(
        maxValue,
        rawGraphHR.get(i)
      );
  }


  return maxValue;
}


float getDetectionMinimumHR()
{
  float minValue =
    min(
      restingHR,
      getCalmEnterThreshold()
    );


  for (
    int i = 0;
    i < rawGraphHR.size();
    i++
  )
  {
    minValue =
      min(
        minValue,
        rawGraphHR.get(i)
      );
  }


  return minValue;
}


void drawHRRegion(
  float x,
  float y,
  float w,
  float h,
  float lowHR,
  float highHR,
  color regionColor,
  float yMin,
  float yMax
)
{
  float low =
    max(
      lowHR,
      yMin
    );


  float high =
    min(
      highHR,
      yMax
    );


  if (high <= low)
  {
    return;
  }


  float top =
    map(
      high,
      yMin,
      yMax,
      y + h,
      y
    );


  float bottom =
    map(
      low,
      yMin,
      yMax,
      y + h,
      y
    );


  noStroke();


  fill(
    regionColor,
    28
  );


  rect(
    x,
    top,
    w,
    bottom - top
  );
}


void drawThresholdLine(
  float x,
  float y,
  float w,
  float h,
  float hr,
  float yMin,
  float yMax,
  color lineColor
)
{
  float py =
    map(
      hr,
      yMin,
      yMax,
      y + h,
      y
    );


  stroke(lineColor);

  strokeWeight(1.5);


  line(
    x,
    py,
    x + w,
    py
  );


  noStroke();
}


// ============================================================
// DETECTED STATE HELPERS
// ============================================================

String getDetectedStateName()
{
  if (!isCurrentSignalValid())
  {
    return "SIGNAL LOST";
  }


  // Signal exists, but the first complete rolling window
  // has not yet been obtained.

  if (!rollingAvailable)
  {
    return "ANALYZING";
  }


  switch(detectedState)
  {
    case DETECT_CALM:

      return "CALM";


    case DETECT_STRESSED:

      return "STRESSED";


    default:

      return "NEUTRAL";
  }
}


color getDetectedStateColor()
{
  if (!isCurrentSignalValid())
  {
    return warningColor;
  }


  if (!rollingAvailable)
  {
    return primaryBlue;
  }


  switch(detectedState)
  {
    case DETECT_CALM:

      return calmGreen;


    case DETECT_STRESSED:

      return stressRed;


    default:

      return neutralColor;
  }
}


// ============================================================
// MOUSE INPUT
// ============================================================

void mousePressed()
{
  // ----------------------------------------------------------
  // Baseline Retry
  // ----------------------------------------------------------

  if (
    state
    ==
    STATE_BASELINE_FAILED
  )
  {
    if (
      insideButton(
        retryX,
        retryY,
        retryW,
        retryH
      )
    )
    {
      resetInitialSignalWindow();


      baselineTotalSamples = 0;
      baselineValidSamples = 0;

      baselineHRSum = 0;

      baselineQuality = 0;


      state =
        STATE_WAITING_SIGNAL;
    }
  }


  // ----------------------------------------------------------
  // Main menu
  // ----------------------------------------------------------

  else if (
    state
    ==
    STATE_MODE_MENU
  )
  {
    if (
      insideButton(
        calmButtonX,
        calmButtonY,
        calmButtonW,
        calmButtonH
      )
    )
    {
      startCalibration(
        true
      );
    }


    else if (
      insideButton(
        stressButtonX,
        stressButtonY,
        stressButtonW,
        stressButtonH
      )
    )
    {
      startCalibration(
        false
      );
    }


    else if (
      insideButton(
        detectionButtonX,
        detectionButtonY,
        detectionButtonW,
        detectionButtonH
      )
    )
    {
      if (
        calmCalibrationValid
        &&
        stressCalibrationValid
      )
      {
        startDetection();
      }
    }
  }


  // ----------------------------------------------------------
  // Calm STOP
  // ----------------------------------------------------------

  else if (
    state
    ==
    STATE_CALM_ACTIVE
  )
  {
    if (
      insideButton(
        calibrationStopX,
        calibrationStopY,
        calibrationStopW,
        calibrationStopH
      )
    )
    {
      finishCalmCalibration();
    }
  }


  // ----------------------------------------------------------
  // Stress STOP
  // ----------------------------------------------------------

  else if (
    state
    ==
    STATE_STRESS_ACTIVE
  )
  {
    if (
      insideButton(
        calibrationStopX,
        calibrationStopY,
        calibrationStopW,
        calibrationStopH
      )
    )
    {
      finishStressCalibration();
    }
  }


  // ----------------------------------------------------------
  // Calm result -> menu
  // ----------------------------------------------------------

  else if (
    state
    ==
    STATE_CALM_RESULT
  )
  {
    if (
      insideButton(
        backButtonX,
        backButtonY,
        backButtonW,
        backButtonH
      )
    )
    {
      state =
        STATE_MODE_MENU;
    }
  }


  // ----------------------------------------------------------
  // Stress result -> menu
  // ----------------------------------------------------------

  else if (
    state
    ==
    STATE_STRESS_RESULT
  )
  {
    if (
      insideButton(
        backButtonX,
        backButtonY,
        backButtonW,
        backButtonH
      )
    )
    {
      state =
        STATE_MODE_MENU;
    }
  }


  // ----------------------------------------------------------
  // Detection STOP
  // ----------------------------------------------------------

  else if (
    state
    ==
    STATE_DETECTION_ACTIVE
  )
  {
    if (
      insideButton(
        detectionStopX,
        detectionStopY,
        detectionStopW,
        detectionStopH
      )
    )
    {
      stopDetection();
    }
  }
}


// ============================================================
// BUTTON HIT TEST
// ============================================================

boolean insideButton(
  float x,
  float y,
  float w,
  float h
)
{
  return
    mouseX >= x
    &&
    mouseX <= x + w
    &&
    mouseY >= y
    &&
    mouseY <= y + h;
}


// ============================================================
// TIME FORMAT
// ============================================================

String formatTimeDetailed(
  float seconds
)
{
  int totalSeconds =
    int(seconds);


  int minutes =
    totalSeconds
    /
    60;


  int remainingSeconds =
    totalSeconds
    %
    60;


  return
    nf(
      minutes,
      2
    )
    +
    ":"
    +
    nf(
      remainingSeconds,
      2
    );
}


// ============================================================
// GENERAL GUI HELPERS
// ============================================================

void drawMainTitle(
  String title,
  String subtitle
)
{
  fill(darkBlue);

  textAlign(LEFT, CENTER);

  textSize(30);


  text(
    title,
    50,
    55
  );


  fill(secondaryText);

  textSize(15);


  text(
    subtitle,
    50,
    92
  );
}


void drawCard(
  float x,
  float y,
  float w,
  float h
)
{
  noStroke();

  fill(whiteColor);


  rect(
    x,
    y,
    w,
    h,
    20
  );
}


void drawMetricCard(
  float x,
  float y,
  float w,
  float h,
  String label,
  String value,
  String unit
)
{
  drawCard(
    x,
    y,
    w,
    h
  );


  fill(secondaryText);

  textAlign(CENTER, CENTER);

  textSize(12);


  text(
    label,
    x + w / 2,
    y + 26
  );


  fill(darkBlue);

  textSize(31);


  text(
    value,
    x + w / 2,
    y + h / 2 + 4
  );


  fill(secondaryText);

  textSize(13);


  text(
    unit,
    x + w / 2,
    y + h - 22
  );
}


void drawSimpleProgress(
  float x,
  float y,
  float w,
  float h,
  float progress
)
{
  progress =
    constrain(
      progress,
      0,
      1
    );


  noStroke();

  fill(lightBlue);


  rect(
    x,
    y,
    w,
    h,
    h / 2
  );


  fill(primaryBlue);


  rect(
    x,
    y,
    w * progress,
    h,
    h / 2
  );
}
