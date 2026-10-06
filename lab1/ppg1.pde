import processing.serial.*;


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

// millis() in Processing returns an int.
// Therefore all timestamps are stored as int.
int lastSampleTime = 0;


// ============================================================
// PROGRAM STATES
// ============================================================

final int STATE_AGE_INPUT       = 0;
final int STATE_WAITING_SIGNAL  = 1;
final int STATE_SIGNAL_ACQUIRED = 2;
final int STATE_BASELINE        = 3;
final int STATE_BASELINE_FAILED = 4;
final int STATE_FITNESS_READY   = 5;
final int STATE_FITNESS_ACTIVE  = 6;
final int STATE_FITNESS_COMPLETE = 7;

int state = STATE_AGE_INPUT;


// ============================================================
// USER INFORMATION
// ============================================================

String ageText = "";
String ageError = "";

int userAge = 0;
int maxHR = 0;


// ============================================================
// INITIAL SIGNAL ACQUISITION
// ============================================================

final int WINDOW_SIZE = 10;
final int MIN_VALID_IN_WINDOW = 7;

boolean[] signalWindow = new boolean[WINDOW_SIZE];

int windowIndex = 0;
int windowCount = 0;


// ============================================================
// SIGNAL ACQUIRED SCREEN
// ============================================================

int signalAcquiredTime = 0;

final int SIGNAL_ACQUIRED_DISPLAY_MS = 1500;


// ============================================================
// BASELINE ACQUISITION
// ============================================================

final int BASELINE_DURATION_MS = 30000;

// Minimum acceptable percentage of valid HR samples
final float MIN_BASELINE_QUALITY = 0.70;

// Safeguard against a major serial interruption.
// At approximately 2 samples/s we expect ~60 samples in 30 s.
final int MIN_BASELINE_SAMPLES = 30;

int baselineStartTime = 0;

int baselineTotalSamples = 0;
int baselineValidSamples = 0;

float baselineHRSum = 0;

float baselineQuality = 0;
float restingHR = 0;


// ============================================================
// FITNESS MODE - ZONES
// ============================================================

final int ZONE_RECOVERY   = 0;
final int ZONE_VERY_LIGHT = 1;
final int ZONE_LIGHT      = 2;
final int ZONE_MODERATE   = 3;
final int ZONE_HARD       = 4;
final int ZONE_MAXIMUM    = 5;

final int NUMBER_OF_ZONES = 6;

float[] zoneTimes_s = new float[NUMBER_OF_ZONES];


// ============================================================
// FITNESS MODE - TIMING
// ============================================================

int activityStartTime = 0;
int activityEndTime = 0;

int previousFitnessSampleTime = 0;

// If two received samples are separated by more than this,
// the interval is not assigned to any HR zone.
final int MAX_CLASSIFIABLE_INTERVAL_MS = 1500;


// ============================================================
// FITNESS MODE - DATA
// ============================================================

int fitnessTotalSamples = 0;
int fitnessValidSamples = 0;
int fitnessInvalidSamples = 0;

float fitnessHRSum = 0;
float averageHR = 0;

float fitnessQuality = 0;

float currentHRPercent = 0;
int currentZone = -1;

// Store last valid fitness values for the final screen
int lastFitnessHR = 0;
int lastFitnessSpO2 = 0;
int lastFitnessConfidence = 0;

float lastFitnessBeatInterval = 0;
float lastFitnessHRPercent = 0;

int lastFitnessZone = -1;


// ============================================================
// FITNESS GRAPH DATA
// ============================================================

// One element for every VALID HR sample.

ArrayList<Float> graphTime =
  new ArrayList<Float>();

ArrayList<Float> graphHR =
  new ArrayList<Float>();

ArrayList<Integer> graphZone =
  new ArrayList<Integer>();

// true = connect this point to the previous valid point
// false = start a new segment (gap)
ArrayList<Boolean> graphConnected =
  new ArrayList<Boolean>();

boolean previousFitnessSampleWasValid = false;


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

color successColor;
color warningColor;

color startGreen;
color stopRed;

color whiteColor;


// ============================================================
// BUTTON POSITIONS
// ============================================================

// Retry baseline
float retryX = 500;
float retryY = 660;
float retryW = 300;
float retryH = 65;

// Start Fitness
float startX = 450;
float startY = 675;
float startW = 400;
float startH = 70;

// Stop Fitness
float stopX = 1090;
float stopY = 48;
float stopW = 160;
float stopH = 50;


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

  successColor = color(50, 150, 100);
  warningColor = color(205, 75, 75);

  startGreen = color(45, 160, 95);
  stopRed = color(205, 65, 65);

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

    // Trigger serialEvent() only after receiving '\n'
    myPort.bufferUntil('\n');

    serialConnected = true;
  }

  catch (Exception e)
  {
    serialConnected = false;

    println(
      "Could not open serial port " +
      PORT_NAME
    );

    println(e);
  }


  resetSignalWindow();
}


// ============================================================
// MAIN DRAW LOOP
// ============================================================

void draw()
{
  background(backgroundColor);


  switch(state)
  {
    case STATE_AGE_INPUT:

      drawAgeInput();

      break;


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


    case STATE_FITNESS_READY:

      drawFitnessReady();

      break;


    case STATE_FITNESS_ACTIVE:

      drawFitnessDashboard(false);

      break;


    case STATE_FITNESS_COMPLETE:

      drawFitnessDashboard(true);

      break;
  }


  // ----------------------------------------------------------
  // Serial connection warning
  // ----------------------------------------------------------

  if (!serialConnected)
  {
    fill(warningColor);

    textAlign(CENTER, CENTER);
    textSize(15);

    text(
      "Serial connection unavailable - check "
      + PORT_NAME,
      width / 2,
      height - 20
    );
  }
}


// ============================================================
// SERIAL DATA
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
  // Expected Arduino line:
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


  // Ignore initialization messages or malformed lines
  if (values == null)
  {
    return;
  }


  // ----------------------------------------------------------
  // Extract values
  // ----------------------------------------------------------

  heartRate =
    int(values[1]);

  confidence =
    int(values[2]);

  oxygen =
    int(values[3]);

  sensorStatus =
    int(values[4]);


  lastSampleTime = millis();


  // ----------------------------------------------------------
  // Sample validity
  //
  // HR > 0 is our current validity criterion.
  // ----------------------------------------------------------

  lastSampleValid =
    heartRate > 0;


  // ----------------------------------------------------------
  // Beat interval
  // ----------------------------------------------------------

  if (heartRate > 0)
  {
    beatInterval_ms =
      60000.0 / heartRate;
  }

  else
  {
    beatInterval_ms = 0;
  }


  // ==========================================================
  // WAITING FOR INITIAL SIGNAL
  // ==========================================================

  if (state == STATE_WAITING_SIGNAL)
  {
    addSignalSample(
      lastSampleValid
    );


    int validInWindow =
      countValidWindowSamples();


    // Require:
    //
    // - complete 10-sample window
    // - at least 7/10 valid
    // - latest sample valid

    if (
      windowCount == WINDOW_SIZE &&
      validInWindow >= MIN_VALID_IN_WINDOW &&
      lastSampleValid
    )
    {
      state =
        STATE_SIGNAL_ACQUIRED;

      signalAcquiredTime =
        millis();
    }
  }


  // ==========================================================
  // BASELINE ACQUISITION
  // ==========================================================

  else if (state == STATE_BASELINE)
  {
    if (
      millis() - baselineStartTime
      <= BASELINE_DURATION_MS
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
  // FITNESS ACTIVE
  // ==========================================================

  else if (state == STATE_FITNESS_ACTIVE)
  {
    processFitnessSample(
      millis()
    );
  }
}


// ============================================================
// INITIAL SIGNAL WINDOW
// ============================================================

void addSignalSample(boolean valid)
{
  signalWindow[windowIndex] =
    valid;


  windowIndex++;


  if (windowIndex >= WINDOW_SIZE)
  {
    windowIndex = 0;
  }


  if (windowCount < WINDOW_SIZE)
  {
    windowCount++;
  }
}


int countValidWindowSamples()
{
  int valid = 0;


  for (
    int i = 0;
    i < windowCount;
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


void resetSignalWindow()
{
  for (
    int i = 0;
    i < WINDOW_SIZE;
    i++
  )
  {
    signalWindow[i] = false;
  }


  windowIndex = 0;
  windowCount = 0;
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


  // ----------------------------------------------------------
  // Baseline successful
  // ----------------------------------------------------------

  if (
    baselineQuality
      >= MIN_BASELINE_QUALITY
    &&
    baselineValidSamples > 0
    &&
    baselineTotalSamples
      >= MIN_BASELINE_SAMPLES
  )
  {
    restingHR =
      baselineHRSum
      /
      float(baselineValidSamples);


    state =
      STATE_FITNESS_READY;
  }


  // ----------------------------------------------------------
  // Baseline failed
  // ----------------------------------------------------------

  else
  {
    state =
      STATE_BASELINE_FAILED;
  }
}


// ============================================================
// FITNESS SESSION CONTROL
// ============================================================

void startFitnessSession()
{
  // Reset timing
  activityStartTime =
    millis();

  activityEndTime = 0;

  previousFitnessSampleTime = 0;

  previousFitnessSampleWasValid =
    false;


  // Reset sample statistics
  fitnessTotalSamples = 0;
  fitnessValidSamples = 0;
  fitnessInvalidSamples = 0;

  fitnessHRSum = 0;
  averageHR = 0;

  fitnessQuality = 0;

  currentHRPercent = 0;
  currentZone = -1;


  // Reset last valid fitness values
  lastFitnessHR = 0;
  lastFitnessSpO2 = 0;
  lastFitnessConfidence = 0;

  lastFitnessBeatInterval = 0;
  lastFitnessHRPercent = 0;
  lastFitnessZone = -1;


  // Reset zone times
  for (
    int i = 0;
    i < NUMBER_OF_ZONES;
    i++
  )
  {
    zoneTimes_s[i] = 0;
  }


  // Reset graph
  graphTime.clear();
  graphHR.clear();
  graphZone.clear();
  graphConnected.clear();


  state =
    STATE_FITNESS_ACTIVE;
}


void stopFitnessSession()
{
  activityEndTime =
    millis();


  state =
    STATE_FITNESS_COMPLETE;
}


// ============================================================
// FITNESS SAMPLE PROCESSING
// ============================================================

void processFitnessSample(
  int currentSampleTime
)
{
  fitnessTotalSamples++;


  // ----------------------------------------------------------
  // Calculate real time interval from previous received sample
  // ----------------------------------------------------------

  int deltaTime_ms = 0;


  if (previousFitnessSampleTime > 0)
  {
    deltaTime_ms =
      currentSampleTime
      -
      previousFitnessSampleTime;
  }


  // ==========================================================
  // VALID HR SAMPLE
  // ==========================================================

  if (lastSampleValid)
  {
    fitnessValidSamples++;


    fitnessHRSum +=
      heartRate;


    averageHR =
      fitnessHRSum
      /
      float(fitnessValidSamples);


    // --------------------------------------------------------
    // Percentage of estimated maximum HR
    // --------------------------------------------------------

    currentHRPercent =
      100.0
      *
      float(heartRate)
      /
      float(maxHR);


    // --------------------------------------------------------
    // Determine cardio zone
    // --------------------------------------------------------

    currentZone =
      classifyZone(
        currentHRPercent
      );


    // --------------------------------------------------------
    // Assign delta time to current zone
    //
    // Only if:
    // - there was a previous sample
    // - delta is positive
    // - delta is not abnormally large
    // --------------------------------------------------------

    if (
      previousFitnessSampleTime > 0
      &&
      deltaTime_ms > 0
      &&
      deltaTime_ms
        <= MAX_CLASSIFIABLE_INTERVAL_MS
    )
    {
      float deltaTime_s =
        deltaTime_ms
        /
        1000.0;


      zoneTimes_s[currentZone]
        += deltaTime_s;
    }


    // --------------------------------------------------------
    // Save graph point
    // --------------------------------------------------------

    float elapsedTime_s =
      (
        currentSampleTime
        -
        activityStartTime
      )
      /
      1000.0;


    // Connect only if previous sample was valid
    // AND timing is reasonable.

    boolean connectPoint =
      previousFitnessSampleWasValid
      &&
      deltaTime_ms > 0
      &&
      deltaTime_ms
        <= MAX_CLASSIFIABLE_INTERVAL_MS;


    graphTime.add(
      elapsedTime_s
    );

    graphHR.add(
      float(heartRate)
    );

    graphZone.add(
      currentZone
    );

    graphConnected.add(
      connectPoint
    );


    // --------------------------------------------------------
    // Store last valid values
    // --------------------------------------------------------

    lastFitnessHR =
      heartRate;

    lastFitnessSpO2 =
      oxygen;

    lastFitnessConfidence =
      confidence;

    lastFitnessBeatInterval =
      beatInterval_ms;

    lastFitnessHRPercent =
      currentHRPercent;

    lastFitnessZone =
      currentZone;
  }


  // ==========================================================
  // INVALID HR SAMPLE
  // ==========================================================

  else
  {
    fitnessInvalidSamples++;

    // No graph point.
    // No zone time.
    // No average HR update.

    currentZone = -1;
    currentHRPercent = 0;
  }


  // ----------------------------------------------------------
  // Quality index
  // ----------------------------------------------------------

  if (fitnessTotalSamples > 0)
  {
    fitnessQuality =
      float(fitnessValidSamples)
      /
      float(fitnessTotalSamples);
  }


  // ----------------------------------------------------------
  // IMPORTANT:
  //
  // Update previous sample timestamp even if HR = 0.
  //
  // Therefore, after a dropout:
  //
  // valid -> 0 -> 0 -> valid
  //
  // the final valid sample only receives the delta from
  // the immediately preceding zero sample, not the entire
  // dropout duration.
  // ----------------------------------------------------------

  previousFitnessSampleTime =
    currentSampleTime;


  previousFitnessSampleWasValid =
    lastSampleValid;
}


// ============================================================
// CARDIO ZONE CLASSIFICATION
// ============================================================

int classifyZone(
  float percentage
)
{
  if (percentage < 50.0)
  {
    return ZONE_RECOVERY;
  }

  else if (percentage < 60.0)
  {
    return ZONE_VERY_LIGHT;
  }

  else if (percentage < 70.0)
  {
    return ZONE_LIGHT;
  }

  else if (percentage < 80.0)
  {
    return ZONE_MODERATE;
  }

  else if (percentage < 90.0)
  {
    return ZONE_HARD;
  }

  else
  {
    return ZONE_MAXIMUM;
  }
}


// ============================================================
// FITNESS TIME FUNCTIONS
// ============================================================

float getActivityTime_s()
{
  if (
    state == STATE_FITNESS_ACTIVE
  )
  {
    return
      (
        millis()
        -
        activityStartTime
      )
      /
      1000.0;
  }


  else if (
    state == STATE_FITNESS_COMPLETE
  )
  {
    return
      (
        activityEndTime
        -
        activityStartTime
      )
      /
      1000.0;
  }


  return 0;
}


float getClassifiedTime_s()
{
  float total = 0;


  for (
    int i = 0;
    i < NUMBER_OF_ZONES;
    i++
  )
  {
    total +=
      zoneTimes_s[i];
  }


  return total;
}


// ============================================================
// AGE INPUT SCREEN
// ============================================================

void drawAgeInput()
{
  drawMainTitle(
    "Fitness Mode",
    "User setup"
  );


  drawCard(
    350,
    190,
    600,
    390
  );


  fill(darkBlue);

  textAlign(
    CENTER,
    CENTER
  );

  textSize(28);

  text(
    "Enter your age",
    width / 2,
    255
  );


  fill(secondaryText);

  textSize(15);

  text(
    "Your age will be used to estimate maximum heart rate.",
    width / 2,
    300
  );


  // Input box
  fill(veryLightBlue);

  stroke(lightBlue);

  strokeWeight(2);

  rect(
    500,
    355,
    300,
    90,
    18
  );

  noStroke();


  fill(darkBlue);

  textSize(38);


  String displayedAge =
    ageText;


  if (
    displayedAge.length() == 0
  )
  {
    fill(secondaryText);

    displayedAge =
      "Age";
  }


  text(
    displayedAge,
    width / 2,
    400
  );


  fill(secondaryText);

  textSize(15);

  text(
    "Type your age and press ENTER",
    width / 2,
    490
  );


  if (ageError.length() > 0)
  {
    fill(warningColor);

    textSize(14);

    text(
      ageError,
      width / 2,
      530
    );
  }
}


// ============================================================
// WAITING FOR SIGNAL SCREEN
// ============================================================

void drawWaitingForSignal()
{
  drawMainTitle(
    "Resting Heart Rate Baseline",
    "Waiting for a stable PPG signal"
  );


  int validWindow =
    countValidWindowSamples();


  drawMetricCard(
    80,
    180,
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
    180,
    340,
    160,
    "OXYGEN SATURATION",
    oxygen > 0
      ? str(oxygen)
      : "--",
    "%"
  );


  drawMetricCard(
    880,
    180,
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
    250
  );


  fill(darkBlue);

  textAlign(
    LEFT,
    CENTER
  );

  textSize(21);

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
      "Valid signal detected",
      125,
      480
    );
  }

  else
  {
    fill(warningColor);

    textSize(16);

    text(
      "No valid signal - keep your finger still on the sensor",
      125,
      480
    );
  }


  fill(textColor);

  textSize(18);

  text(
    "Valid samples in recent window: "
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
    "Baseline starts when at least 7 of the last 10 samples are valid and the latest sample is valid.",
    125,
    575
  );


  drawSignalWindowBar(
    125,
    605,
    1030,
    16,
    validWindow
  );
}


// ============================================================
// SIGNAL ACQUIRED SCREEN
// ============================================================

void drawSignalAcquired()
{
  drawMainTitle(
    "Resting Heart Rate Baseline",
    "Signal check"
  );


  drawCard(
    340,
    190,
    620,
    370
  );


  fill(successColor);

  textAlign(
    CENTER,
    CENTER
  );

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
// BASELINE SCREEN
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


  float elapsedSeconds =
    elapsed
    /
    1000.0;


  float progress =
    elapsed
    /
    float(
      BASELINE_DURATION_MS
    );


  fill(darkBlue);

  textAlign(
    LEFT,
    CENTER
  );

  textSize(22);

  text(
    "Baseline acquisition",
    105,
    400
  );


  fill(textColor);

  textAlign(
    RIGHT,
    CENTER
  );

  textSize(18);

  text(
    nf(
      elapsedSeconds,
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


  textAlign(
    LEFT,
    CENTER
  );


  if (isCurrentSignalValid())
  {
    fill(successColor);

    textSize(17);

    text(
      "Signal: valid",
      105,
      520
    );
  }

  else
  {
    fill(warningColor);

    textSize(17);

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


  textAlign(
    RIGHT,
    CENTER
  );

  text(
    "Minimum required quality: 70%",
    1200,
    565
  );
}


// ============================================================
// BASELINE FAILED SCREEN
// ============================================================

void drawBaselineFailed()
{
  drawMainTitle(
    "Resting Heart Rate Baseline",
    "Acquisition problem"
  );


  drawCard(
    300,
    155,
    700,
    555
  );


  fill(warningColor);

  textAlign(
    CENTER,
    CENTER
  );

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


  if (
    baselineTotalSamples
      < MIN_BASELINE_SAMPLES
  )
  {
    text(
      "Too few samples were received during the 30-second acquisition.",
      width / 2,
      380
    );
  }

  else
  {
    text(
      "Too many invalid heart-rate samples were detected.",
      width / 2,
      380
    );
  }


  text(
    "Please reposition your finger and retry the measurement.",
    width / 2,
    425
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
    retryX
      +
      retryW / 2,
    retryY
      +
      retryH / 2
  );
}


// ============================================================
// FITNESS READY SCREEN
// ============================================================

void drawFitnessReady()
{
  drawMainTitle(
    "Fitness Mode",
    "Baseline acquired - ready to begin"
  );


  // ----------------------------------------------------------
  // LEFT HALF - BASELINE INFORMATION
  // ----------------------------------------------------------

  drawCard(
    70,
    155,
    560,
    450
  );


  fill(darkBlue);

  textAlign(
    CENTER,
    CENTER
  );

  textSize(23);

  text(
    "Baseline summary",
    350,
    205
  );


  fill(successColor);

  textSize(49);

  text(
    nf(
      restingHR,
      0,
      1
    ),
    350,
    295
  );


  fill(secondaryText);

  textSize(16);

  text(
    "Resting heart rate (bpm)",
    350,
    345
  );


  fill(textColor);

  textSize(18);

  text(
    "Baseline quality: "
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
    350,
    420
  );


  text(
    "Estimated HRmax: "
    +
    maxHR
    +
    " bpm",
    350,
    465
  );


  text(
    "Age: "
    +
    userAge
    +
    " years",
    350,
    510
  );


  // ----------------------------------------------------------
  // RIGHT HALF - LIVE SIGNAL
  // ----------------------------------------------------------

  drawCard(
    670,
    155,
    560,
    450
  );


  fill(darkBlue);

  textSize(23);

  text(
    "Live signal",
    950,
    205
  );


  if (isCurrentSignalValid())
  {
    fill(successColor);

    textSize(46);

    text(
      heartRate,
      950,
      285
    );


    fill(secondaryText);

    textSize(16);

    text(
      "Current HR (bpm)",
      950,
      330
    );


    fill(textColor);

    textSize(17);

    text(
      "Beat interval: "
      +
      nf(
        beatInterval_ms,
        0,
        0
      )
      +
      " ms",
      950,
      405
    );


    text(
      "SpO2: "
      +
      oxygen
      +
      "%",
      950,
      450
    );


    text(
      "Confidence: "
      +
      confidence
      +
      "%",
      950,
      495
    );
  }

  else
  {
    fill(warningColor);

    textSize(31);

    text(
      "SIGNAL LOST",
      950,
      320
    );


    fill(secondaryText);

    textSize(16);

    text(
      "You may still start the session,",
      950,
      400
    );

    text(
      "or wait until HR is detected again.",
      950,
      430
    );
  }


  // ----------------------------------------------------------
  // START BUTTON
  // ----------------------------------------------------------

  fill(startGreen);

  noStroke();

  rect(
    startX,
    startY,
    startW,
    startH,
    20
  );


  fill(whiteColor);

  textAlign(
    CENTER,
    CENTER
  );

  textSize(21);

  text(
    "START FITNESS SESSION",
    startX
      +
      startW / 2,
    startY
      +
      startH / 2
  );
}


// ============================================================
// FITNESS DASHBOARD
// ============================================================

void drawFitnessDashboard(
  boolean completed
)
{
  String subtitle;


  if (completed)
  {
    subtitle =
      "Session complete";
  }

  else
  {
    subtitle =
      "Live exercise monitoring";
  }


  drawMainTitle(
    "Fitness Mode",
    subtitle
  );


  // ----------------------------------------------------------
  // STOP BUTTON
  // ----------------------------------------------------------

  if (!completed)
  {
    fill(stopRed);

    noStroke();

    rect(
      stopX,
      stopY,
      stopW,
      stopH,
      16
    );


    fill(whiteColor);

    textAlign(
      CENTER,
      CENTER
    );

    textSize(18);

    text(
      "STOP",
      stopX
        +
        stopW / 2,
      stopY
        +
        stopH / 2
    );
  }


  // ----------------------------------------------------------
  // TOP METRIC CARDS
  // ----------------------------------------------------------

  float cardY = 125;
  float cardW = 190;
  float cardH = 115;
  float gap = 12;

  float x1 = 40;
  float x2 = x1 + cardW + gap;
  float x3 = x2 + cardW + gap;
  float x4 = x3 + cardW + gap;
  float x5 = x4 + cardW + gap;
  float x6 = x5 + cardW + gap;


  // Current / Last HR
  String currentHRText;

  if (completed)
  {
    currentHRText =
      lastFitnessHR > 0
      ? str(lastFitnessHR)
      : "--";
  }

  else
  {
    currentHRText =
      isCurrentSignalValid()
      ? str(heartRate)
      : "--";
  }


  drawMetricCard(
    x1,
    cardY,
    cardW,
    cardH,
    completed
      ? "LAST HR"
      : "CURRENT HR",
    currentHRText,
    "bpm"
  );


  drawMetricCard(
    x2,
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
    x3,
    cardY,
    cardW,
    cardH,
    "AVERAGE HR",
    fitnessValidSamples > 0
      ? nf(
          averageHR,
          0,
          1
        )
      : "--",
    "bpm"
  );


  float shownBeatInterval;

  if (completed)
  {
    shownBeatInterval =
      lastFitnessBeatInterval;
  }

  else
  {
    shownBeatInterval =
      isCurrentSignalValid()
      ? beatInterval_ms
      : 0;
  }


  drawMetricCard(
    x4,
    cardY,
    cardW,
    cardH,
    "BEAT INTERVAL",
    shownBeatInterval > 0
      ? nf(
          shownBeatInterval,
          0,
          0
        )
      : "--",
    "ms"
  );


  int shownSpO2 =
    completed
    ? lastFitnessSpO2
    : oxygen;


  drawMetricCard(
    x5,
    cardY,
    cardW,
    cardH,
    "SpO2",
    shownSpO2 > 0
      ? str(shownSpO2)
      : "--",
    "%"
  );


  int shownConfidence =
    completed
    ? lastFitnessConfidence
    : confidence;


  drawMetricCard(
    x6,
    cardY,
    cardW,
    cardH,
    "CONFIDENCE",
    str(shownConfidence),
    "%"
  );


  // ----------------------------------------------------------
  // SIGNAL LOST MESSAGE
  // ----------------------------------------------------------

  if (
    !completed
    &&
    !isCurrentSignalValid()
  )
  {
    fill(warningColor);

    textAlign(
      CENTER,
      CENTER
    );

    textSize(17);

    text(
      "SIGNAL LOST - graph and zone timing temporarily paused",
      650,
      258
    );
  }


  // ----------------------------------------------------------
  // GRAPH LEFT
  // ----------------------------------------------------------

  drawFitnessGraph(
    40,
    285,
    845,
    480
  );


  // ----------------------------------------------------------
  // STATISTICS RIGHT
  // ----------------------------------------------------------

  drawFitnessStatistics(
    910,
    285,
    350,
    480,
    completed
  );
}


// ============================================================
// FITNESS GRAPH
// ============================================================

void drawFitnessGraph(
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
    panelX + 65;

  float graphY =
    panelY + 45;

  float graphW =
    panelW - 95;

  float graphH =
    panelH - 100;


  // ----------------------------------------------------------
  // X-axis range
  // ----------------------------------------------------------

  float activityTime =
    getActivityTime_s();


  float xMax =
    max(
      10.0,
      ceil(
        activityTime
        /
        10.0
      )
      *
      10.0
    );


  // ----------------------------------------------------------
  // Y-axis range
  // ----------------------------------------------------------

  float yMin = 40.0;


  float maxMeasuredHR =
    getMaximumGraphHR();


  float yMax =
    max(
      120.0,
      max(
        maxHR * 1.05,
        maxMeasuredHR + 10.0
      )
    );


  // ----------------------------------------------------------
  // Background zone bands
  // ----------------------------------------------------------

  drawZoneBand(
    graphX,
    graphY,
    graphW,
    graphH,
    yMin,
    maxHR * 0.50,
    getZoneColor(
      ZONE_RECOVERY
    ),
    yMin,
    yMax
  );


  drawZoneBand(
    graphX,
    graphY,
    graphW,
    graphH,
    maxHR * 0.50,
    maxHR * 0.60,
    getZoneColor(
      ZONE_VERY_LIGHT
    ),
    yMin,
    yMax
  );


  drawZoneBand(
    graphX,
    graphY,
    graphW,
    graphH,
    maxHR * 0.60,
    maxHR * 0.70,
    getZoneColor(
      ZONE_LIGHT
    ),
    yMin,
    yMax
  );


  drawZoneBand(
    graphX,
    graphY,
    graphW,
    graphH,
    maxHR * 0.70,
    maxHR * 0.80,
    getZoneColor(
      ZONE_MODERATE
    ),
    yMin,
    yMax
  );


  drawZoneBand(
    graphX,
    graphY,
    graphW,
    graphH,
    maxHR * 0.80,
    maxHR * 0.90,
    getZoneColor(
      ZONE_HARD
    ),
    yMin,
    yMax
  );


  drawZoneBand(
    graphX,
    graphY,
    graphW,
    graphH,
    maxHR * 0.90,
    yMax,
    getZoneColor(
      ZONE_MAXIMUM
    ),
    yMin,
    yMax
  );


  // ----------------------------------------------------------
  // Axes
  // ----------------------------------------------------------

  stroke(
    150,
    160,
    175
  );

  strokeWeight(1);


  line(
    graphX,
    graphY,
    graphX,
    graphY + graphH
  );


  line(
    graphX,
    graphY + graphH,
    graphX + graphW,
    graphY + graphH
  );


  // ----------------------------------------------------------
  // Y-axis ticks
  // ----------------------------------------------------------

  fill(secondaryText);

  textAlign(
    RIGHT,
    CENTER
  );

  textSize(11);


  int firstYTick =
    int(
      ceil(
        yMin
        /
        20.0
      )
      *
      20
    );


  for (
    int hrTick = firstYTick;
    hrTick <= yMax;
    hrTick += 20
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
      215,
      220,
      225
    );


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
  // X-axis ticks
  // ----------------------------------------------------------

  textAlign(
    CENTER,
    TOP
  );


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
      215,
      220,
      225
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
  // Axis labels
  // ----------------------------------------------------------

  fill(textColor);

  textAlign(
    LEFT,
    CENTER
  );

  textSize(13);

  text(
    "Heart rate (bpm)",
    graphX,
    panelY + 20
  );


  textAlign(
    CENTER,
    CENTER
  );

  text(
    "Activity time (s)",
    graphX + graphW / 2,
    panelY + panelH - 20
  );


  // ----------------------------------------------------------
  // Plot HR data
  // ----------------------------------------------------------

  strokeWeight(3);


  for (
    int i = 0;
    i < graphTime.size();
    i++
  )
  {
    float currentTime =
      graphTime.get(i);

    float currentHR =
      graphHR.get(i);


    float px =
      map(
        currentTime,
        0,
        xMax,
        graphX,
        graphX + graphW
      );


    float py =
      map(
        currentHR,
        yMin,
        yMax,
        graphY + graphH,
        graphY
      );


    int zone =
      graphZone.get(i);


    color zoneColor =
      getZoneColor(zone);


    // Draw segment only if data continuity exists
    if (
      i > 0
      &&
      graphConnected.get(i)
    )
    {
      float previousTime =
        graphTime.get(i - 1);

      float previousHR =
        graphHR.get(i - 1);


      float previousPX =
        map(
          previousTime,
          0,
          xMax,
          graphX,
          graphX + graphW
        );


      float previousPY =
        map(
          previousHR,
          yMin,
          yMax,
          graphY + graphH,
          graphY
        );


      stroke(zoneColor);


      line(
        previousPX,
        previousPY,
        px,
        py
      );
    }


    // Point marker
    noStroke();

    fill(zoneColor);

    ellipse(
      px,
      py,
      5,
      5
    );
  }


  noStroke();
}


// ============================================================
// FITNESS STATISTICS PANEL
// ============================================================

void drawFitnessStatistics(
  float x,
  float y,
  float w,
  float h,
  boolean completed
)
{
  drawCard(
    x,
    y,
    w,
    h
  );


  // ----------------------------------------------------------
  // Current / final zone
  // ----------------------------------------------------------

  int shownZone;

  float shownPercent;


  if (completed)
  {
    shownZone =
      lastFitnessZone;

    shownPercent =
      lastFitnessHRPercent;
  }

  else if (isCurrentSignalValid())
  {
    shownZone =
      currentZone;

    shownPercent =
      currentHRPercent;
  }

  else
  {
    shownZone = -1;
    shownPercent = 0;
  }


  textAlign(
    CENTER,
    CENTER
  );


  if (shownZone >= 0)
  {
    fill(
      getZoneColor(
        shownZone
      )
    );

    textSize(23);

    text(
      getZoneName(
        shownZone
      ),
      x + w / 2,
      y + 42
    );


    fill(secondaryText);

    textSize(14);

    text(
      nf(
        shownPercent,
        0,
        1
      )
      +
      "% HRmax",
      x + w / 2,
      y + 72
    );
  }

  else
  {
    fill(warningColor);

    textSize(21);

    text(
      completed
        ? "NO VALID FINAL HR"
        : "SIGNAL LOST",
      x + w / 2,
      y + 52
    );
  }


  // ----------------------------------------------------------
  // Activity times
  // ----------------------------------------------------------

  fill(textColor);

  textAlign(
    LEFT,
    CENTER
  );

  textSize(15);


  text(
    "Activity time",
    x + 25,
    y + 112
  );


  textAlign(
    RIGHT,
    CENTER
  );

  text(
    formatTime(
      getActivityTime_s()
    ),
    x + w - 25,
    y + 112
  );


  textAlign(
    LEFT,
    CENTER
  );

  text(
    "Classified time",
    x + 25,
    y + 142
  );


  textAlign(
    RIGHT,
    CENTER
  );

  text(
    formatTime(
      getClassifiedTime_s()
    ),
    x + w - 25,
    y + 142
  );


  textAlign(
    LEFT,
    CENTER
  );

  text(
    "Signal quality",
    x + 25,
    y + 172
  );


  textAlign(
    RIGHT,
    CENTER
  );

  text(
    nf(
      fitnessQuality
      *
      100.0,
      0,
      1
    )
    +
    "%",
    x + w - 25,
    y + 172
  );


  // Divider
  stroke(
    225,
    230,
    235
  );

  line(
    x + 25,
    y + 198,
    x + w - 25,
    y + 198
  );

  noStroke();


  // ----------------------------------------------------------
  // Zone times
  // ----------------------------------------------------------

  float zoneStartY =
    y + 225;

  float zoneSpacing =
    40;


  for (
    int zone = 0;
    zone < NUMBER_OF_ZONES;
    zone++
  )
  {
    float currentY =
      zoneStartY
      +
      zone
      *
      zoneSpacing;


    color zColor =
      getZoneColor(zone);


    fill(zColor);

    rect(
      x + 25,
      currentY - 7,
      12,
      12,
      3
    );


    fill(textColor);

    textAlign(
      LEFT,
      CENTER
    );

    textSize(13);

    text(
      getZoneName(zone),
      x + 48,
      currentY
    );


    textAlign(
      RIGHT,
      CENTER
    );

    text(
      formatTime(
        zoneTimes_s[zone]
      ),
      x + w - 25,
      currentY
    );
  }
}


// ============================================================
// GRAPH ZONE BAND
// ============================================================

void drawZoneBand(
  float x,
  float y,
  float w,
  float h,
  float lowHR,
  float highHR,
  color zoneColor,
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
    zoneColor,
    32
  );


  rect(
    x,
    top,
    w,
    bottom - top
  );
}


// ============================================================
// GRAPH MAX HR
// ============================================================

float getMaximumGraphHR()
{
  float maxValue =
    restingHR;


  for (
    int i = 0;
    i < graphHR.size();
    i++
  )
  {
    if (
      graphHR.get(i)
      >
      maxValue
    )
    {
      maxValue =
        graphHR.get(i);
    }
  }


  return maxValue;
}


// ============================================================
// ZONE COLORS AND NAMES
// ============================================================

color getZoneColor(
  int zone
)
{
  switch(zone)
  {
    case ZONE_RECOVERY:

      return color(
        145,
        155,
        165
      );


    case ZONE_VERY_LIGHT:

      return color(
        175,
        185,
        195
      );


    case ZONE_LIGHT:

      return color(
        70,
        155,
        220
      );


    case ZONE_MODERATE:

      return color(
        55,
        165,
        100
      );


    case ZONE_HARD:

      return color(
        235,
        160,
        40
      );


    case ZONE_MAXIMUM:

      return color(
        215,
        70,
        70
      );
  }


  return secondaryText;
}


String getZoneName(
  int zone
)
{
  switch(zone)
  {
    case ZONE_RECOVERY:

      return "Recovery / Below zone";


    case ZONE_VERY_LIGHT:

      return "Very Light";


    case ZONE_LIGHT:

      return "Light";


    case ZONE_MODERATE:

      return "Moderate";


    case ZONE_HARD:

      return "Hard";


    case ZONE_MAXIMUM:

      return "Maximum";
  }


  return "Unknown";
}


// ============================================================
// TIME FORMAT
// ============================================================

String formatTime(
  float seconds
)
{
  int totalSeconds =
    int(seconds);


  int minutes =
    totalSeconds / 60;


  int remainingSeconds =
    totalSeconds % 60;


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
// KEYBOARD INPUT
// ============================================================

void keyPressed()
{
  if (
    state != STATE_AGE_INPUT
  )
  {
    return;
  }


  // Numeric input
  if (
    key >= '0'
    &&
    key <= '9'
  )
  {
    if (
      ageText.length()
      <
      3
    )
    {
      ageText += key;
    }


    ageError = "";
  }


  // Backspace
  else if (
    key == BACKSPACE
  )
  {
    if (
      ageText.length()
      >
      0
    )
    {
      ageText =
        ageText.substring(
          0,
          ageText.length() - 1
        );
    }
  }


  // Enter
  else if (
    key == ENTER
    ||
    key == RETURN
  )
  {
    if (
      ageText.length() == 0
    )
    {
      ageError =
        "Please enter a valid age.";

      return;
    }


    int enteredAge =
      int(ageText);


    if (
      enteredAge < 1
      ||
      enteredAge > 120
    )
    {
      ageError =
        "Please enter an age between 1 and 120.";

      return;
    }


    userAge =
      enteredAge;


    maxHR =
      220
      -
      userAge;


    resetSignalWindow();


    state =
      STATE_WAITING_SIGNAL;
  }
}


// ============================================================
// MOUSE INPUT
// ============================================================

void mousePressed()
{
  // ----------------------------------------------------------
  // Retry baseline
  // ----------------------------------------------------------

  if (
    state == STATE_BASELINE_FAILED
  )
  {
    if (
      mouseX >= retryX
      &&
      mouseX <= retryX + retryW
      &&
      mouseY >= retryY
      &&
      mouseY <= retryY + retryH
    )
    {
      resetSignalWindow();


      baselineTotalSamples = 0;
      baselineValidSamples = 0;

      baselineHRSum = 0;
      baselineQuality = 0;


      state =
        STATE_WAITING_SIGNAL;
    }
  }


  // ----------------------------------------------------------
  // Start Fitness
  // ----------------------------------------------------------

  else if (
    state == STATE_FITNESS_READY
  )
  {
    if (
      mouseX >= startX
      &&
      mouseX <= startX + startW
      &&
      mouseY >= startY
      &&
      mouseY <= startY + startH
    )
    {
      startFitnessSession();
    }
  }


  // ----------------------------------------------------------
  // Stop Fitness
  // ----------------------------------------------------------

  else if (
    state == STATE_FITNESS_ACTIVE
  )
  {
    if (
      mouseX >= stopX
      &&
      mouseX <= stopX + stopW
      &&
      mouseY >= stopY
      &&
      mouseY <= stopY + stopH
    )
    {
      stopFitnessSession();
    }
  }
}


// ============================================================
// CURRENT SIGNAL STATE
// ============================================================

boolean isCurrentSignalValid()
{
  // Don't continue showing an old HR if no new samples
  // have arrived for more than 1.5 seconds.

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
// GUI HELPERS
// ============================================================

void drawMainTitle(
  String title,
  String subtitle
)
{
  fill(darkBlue);

  textAlign(
    LEFT,
    CENTER
  );

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


  if (
    state != STATE_AGE_INPUT
  )
  {
    textAlign(
      RIGHT,
      CENTER
    );


    fill(textColor);

    textSize(14);


    text(
      "Age: "
      +
      userAge
      +
      "    |    Estimated HRmax: "
      +
      maxHR
      +
      " bpm",
      1045,
      65
    );
  }
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

  textAlign(
    CENTER,
    CENTER
  );

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


void drawSignalWindowBar(
  float x,
  float y,
  float w,
  float h,
  int validCount
)
{
  float progress =
    float(validCount)
    /
    float(
      MIN_VALID_IN_WINDOW
    );


  progress =
    constrain(
      progress,
      0,
      1
    );


  drawSimpleProgress(
    x,
    y,
    w,
    h,
    progress
  );
}
