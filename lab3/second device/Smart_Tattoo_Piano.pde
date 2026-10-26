import processing.serial.*;

Serial port;

String connection = "Disconnected";

String[] songs = {
  "Twinkle Twinkle Little Star",
  "Mary Had a Little Lamb",
  "Ode to Joy"
};

String songName = songs[0];

String[] keys = {
  "C", "D", "E", "F",
  "G", "A", "B", "C5"
};

boolean[] touching = new boolean[10];

float[] changeValue = new float[10];

final float PRESS_THRESHOLD = 2.0;
final float SPECIAL_PRESS_THRESHOLD = 3.5;
final float RELEASE_THRESHOLD = 1.0;

int selectedPort = 0;

int songIndex = 0;
boolean playing = false;


void setup() {
  size(920, 620);

  surface.setTitle("Smart Tattoo Piano");

  textFont(createFont("Arial", 18));

  println("Available serial ports:");
  printArray(Serial.list());

  println();
  println("Use LEFT / RIGHT arrows to select port.");
  println("Press C to connect.");
}


void draw() {
  background(20, 24, 35);


  // ---------------- TITLE ----------------

  fill(245);
  textAlign(LEFT, CENTER);
  textSize(30);

  text(
    "SMART TATTOO PIANO",
    45,
    55
  );


  // ---------------- CONNECTION ----------------

  textSize(15);
  fill(160, 175, 197);

  text(
    "Connection: " + connection,
    45,
    100
  );

  String[] ports = Serial.list();

  String portName = "None";

  if (ports.length > 0) {
    int safePort =
      constrain(
        selectedPort,
        0,
        ports.length - 1
      );

    portName = ports[safePort];
  }

  text(
    "Port: " +
    portName +
    "   (LEFT/RIGHT to select, C to connect)",
    45,
    126
  );


  // ---------------- SONG PANEL ----------------

  fill(38, 45, 63);

  rect(
    40,
    165,
    840,
    155,
    16
  );

  fill(160, 175, 197);
  textSize(14);

  text(
    "CURRENT SONG",
    65,
    195
  );

  fill(245);
  textSize(26);

  text(
    songName,
    65,
    235
  );


  // ---------------- PLAYING STATUS ----------------

  textSize(16);

  if (playing) {
    fill(90, 220, 150);

    text(
      "PLAYING",
      65,
      275
    );
  }
  else {
    fill(235, 180, 90);

    text(
      "PAUSED",
      65,
      275
    );
  }


  // ---------------- E8 BUTTON ----------------

  drawButton(
    560,
    190,
    135,
    55,
    playing
      ? "E8 PAUSE"
      : "E8 PLAY",
    touching[8]
  );


  // ---------------- E9 BUTTON ----------------

  drawButton(
    710,
    190,
    135,
    55,
    "E9 NEXT",
    touching[9]
  );


  // ---------------- E8/E9 VALUES ----------------

  fill(160, 175, 197);
  textSize(13);

  text(
    "E8 change: " +
    nf(changeValue[8], 1, 1),
    560,
    275
  );

  text(
    "E9 change: " +
    nf(changeValue[9], 1, 1),
    710,
    275
  );


  // ---------------- LIVE VALUES ----------------

  fill(170);
  textSize(15);

  text(
    "Live piano keys:",
    45,
    355
  );


  // ---------------- PIANO KEYS ----------------

  for (int i = 0; i < 8; i++) {

    int x =
      45 + i * 105;


    // Key highlight
    if (touching[i]) {
      fill(
        99,
        175,
        255
      );
    }
    else {
      fill(236);
    }

    rect(
      x,
      395,
      93,
      145,
      8
    );


    // Note name
    fill(25);
    textAlign(CENTER, CENTER);
    textSize(20);

    text(
      keys[i],
      x + 46,
      425
    );


    // Current change value
    textSize(14);

    text(
      nf(changeValue[i], 1, 1),
      x + 46,
      465
    );


    // Threshold
    textSize(11);

    if (i == 1 || i == 7) {
      text(
        "THRESH 3.5",
        x + 46,
        495
      );
    }
    else {
      text(
        "THRESH 2.0",
        x + 46,
        495
      );
    }


    // Status
    textSize(12);

    if (touching[i]) {
      text(
        "PRESSED",
        x + 46,
        520
      );
    }
    else {
      text(
        "OFF",
        x + 46,
        520
      );
    }
  }

  textAlign(LEFT, CENTER);


  // ---------------- SONG LIST ----------------

  fill(160, 175, 197);
  textSize(13);

  text(
    "Songs:  1. Twinkle Twinkle Little Star   2. Mary Had a Little Lamb   3. Ode to Joy",
    45,
    575
  );

  text(
    "Touch E8 to Play/Pause • Touch E9 to change song",
    45,
    598
  );
}


// ---------------- BUTTON ----------------

void drawButton(
  int x,
  int y,
  int w,
  int h,
  String label,
  boolean active
) {

  if (active) {
    fill(
      99,
      175,
      255
    );
  }
  else {
    fill(
      66,
      113,
      190
    );
  }

  rect(
    x,
    y,
    w,
    h,
    12
  );

  fill(255);

  textAlign(
    CENTER,
    CENTER
  );

  textSize(15);

  text(
    label,
    x + w / 2,
    y + h / 2
  );

  textAlign(
    LEFT,
    CENTER
  );
}


// ---------------- KEYBOARD CONTROLS ----------------

void keyPressed() {

  if (keyCode == LEFT) {
    selectedPort =
      max(
        0,
        selectedPort - 1
      );
  }

  if (keyCode == RIGHT) {
    selectedPort =
      min(
        max(
          0,
          Serial.list().length - 1
        ),
        selectedPort + 1
      );
  }

  if (
    key == 'c' ||
    key == 'C'
  ) {
    connectPort();
  }
}


// ---------------- SERIAL CONNECTION ----------------

void connectPort() {

  try {

    if (port != null) {
      port.stop();
    }

    String[] ports =
      Serial.list();

    if (ports.length == 0) {

      connection =
        "No serial ports found";

      return;
    }

    int safePort =
      constrain(
        selectedPort,
        0,
        ports.length - 1
      );

    String selected =
      ports[safePort];

    port =
      new Serial(
        this,
        selected,
        115200
      );

    port.clear();

    port.bufferUntil('\n');

    connection =
      "Connected - waiting for Arduino";

    println(
      "Connected to: " +
      selected
    );
  }

  catch (Exception e) {

    connection =
      "Failed: " +
      e.getMessage();

    println(
      "Connection failed: " +
      e.getMessage()
    );
  }
}


// ---------------- SERIAL DATA ----------------

void serialEvent(Serial p) {

  String line =
    p.readStringUntil('\n');

  if (line == null) {
    return;
  }

  line =
    trim(line);

  if (line.length() == 0) {
    return;
  }

  println(line);


  // ---------------- READY ----------------

  if (line.indexOf("READY") >= 0) {

    connection =
      "Ready";
  }


  // ---------------- SONG STATUS ----------------

  int songPosition =
    line.indexOf("SONG,");

  if (songPosition >= 0) {

    String songData =
      line.substring(songPosition);

    String[] parts =
      split(songData, ',');

    if (parts.length >= 2) {

      try {

        songIndex =
          int(trim(parts[1]));

        if (
          songIndex >= 0 &&
          songIndex < songs.length
        ) {

          songName =
            songs[songIndex];

          println(
            "UI SONG CHANGED TO: " +
            songName
          );
        }
      }

      catch (Exception e) {

        println(
          "Could not read song status."
        );
      }
    }
  }


  // ---------------- PLAY / PAUSE STATUS ----------------

  int playingPosition =
    line.indexOf("PLAYING,");

  if (playingPosition >= 0) {

    String playingData =
      line.substring(
        playingPosition
      );

    int valueStart =
      playingData.indexOf(",") + 1;

    if (valueStart > 0) {

      String valueText =
        playingData.substring(
          valueStart
        );

      valueText =
        trim(valueText);

      if (valueText.length() > 0) {

        char state =
          valueText.charAt(0);

        if (state == '1') {

          playing = true;

          println(
            "UI STATUS = PLAYING"
          );
        }

        else if (state == '0') {

          playing = false;

          println(
            "UI STATUS = PAUSED"
          );
        }
      }
    }
  }


  // ---------------- IGNORE CALIBRATION ----------------

  if (
    line.startsWith("KEEP") ||
    line.startsWith("Calibrating") ||
    line.startsWith("Press") ||
    line.startsWith("Sound") ||
    line.startsWith("E0 starting") ||
    line.startsWith("E1 starting") ||
    line.startsWith("E2 starting") ||
    line.startsWith("E3 starting") ||
    line.startsWith("E4 starting") ||
    line.startsWith("E5 starting") ||
    line.startsWith("E6 starting") ||
    line.startsWith("E7 starting") ||
    line.startsWith("E8 starting") ||
    line.startsWith("E9 starting")
  ) {

    return;
  }


  // ---------------- ELECTRODE DATA ----------------

  for (int i = 0; i < 10; i++) {

    String label =
      "E" + i + ":";

    int start =
      line.indexOf(label);

    if (start == -1) {
      continue;
    }


    int openBracket =
      line.indexOf(
        '(',
        start
      );

    if (openBracket == -1) {
      continue;
    }


    int closeBracket =
      line.indexOf(
        ')',
        openBracket
      );

    if (closeBracket == -1) {
      continue;
    }


    String valueText =
      line.substring(
        openBracket + 1,
        closeBracket
      );


    try {

      float change =
        float(valueText);

      changeValue[i] =
        change;


      // ---------------- THRESHOLD ----------------

      float threshold =
        PRESS_THRESHOLD;


      // D = E1
      // C5 = E7
      if (
        i == 1 ||
        i == 7
      ) {

        threshold =
          SPECIAL_PRESS_THRESHOLD;
      }


      // ---------------- PRESS ----------------

      if (!touching[i]) {

        if (
          change >
          threshold
        ) {

          touching[i] =
            true;

          println(
            "E" +
            i +
            " PRESSED"
          );
        }
      }


      // ---------------- RELEASE ----------------

      else {

        if (
          change <
          RELEASE_THRESHOLD
        ) {

          touching[i] =
            false;

          println(
            "E" +
            i +
            " RELEASED"
          );
        }
      }
    }

    catch (Exception e) {

      println(
        "Could not parse E" +
        i +
        ": " +
        valueText
      );
    }
  }
}