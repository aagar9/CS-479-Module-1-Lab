#include <Wire.h>
#include <Adafruit_MPR121.h>

Adafruit_MPR121 sensor;

const byte KEY_COUNT = 10;
const byte BUZZER_PIN = 9;
const byte FLEX_PIN = A1;

const int OCTAVE_THRESHOLD = 150;

const float PRESS_THRESHOLD = 2.0;
const float SPECIAL_PRESS_THRESHOLD = 3.5;
const float RELEASE_THRESHOLD = 1.0;

float baseline[KEY_COUNT];
float smoothed[KEY_COUNT];

bool pressed[KEY_COUNT] = {};

const unsigned int lowNotes[8] = {
  262, 294, 330, 349,
  392, 440, 494, 523
};

const unsigned int highNotes[8] = {
  523, 587, 659, 698,
  784, 880, 988, 1047
};

bool highOctave = false;
int activeKey = -1;


// ---------------- SONGS ----------------

// Twinkle Twinkle
const byte song0[] = {
  60,60,67,67,69,69,67,
  65,65,64,64,62,62,60,
  67,67,65,65,64,64,62,
  67,67,65,65,64,64,62,
  60,60,67,67,69,69,67,
  65,65,64,64,62,62,60
};

const byte beats0[] = {
  1,1,1,1,1,1,2,
  1,1,1,1,1,1,2,
  1,1,1,1,1,1,2,
  1,1,1,1,1,1,2,
  1,1,1,1,1,1,2,
  1,1,1,1,1,1,2
};

// Mary Had a Little Lamb
const byte song1[] = {
  64,62,60,62,64,64,64,
  62,62,62,64,67,67,
  64,62,60,62,64,64,64,64,
  62,62,64,62,60
};

const byte beats1[] = {
  1,1,1,1,1,1,2,
  1,1,2,1,1,2,
  1,1,1,1,1,1,1,1,
  1,1,1,1,2
};

// Ode to Joy
const byte song2[] = {
  64,64,65,67,67,65,64,62,
  60,60,62,64,64,62,62,
  64,64,65,67,67,65,64,62,
  60,60,62,64,62,60,60
};

const byte beats2[] = {
  1,1,1,1,1,1,1,1,
  1,1,1,1,2,1,2,
  1,1,1,1,1,1,1,1,
  1,1,1,1,1,2,2
};

const char* songNames[] = {
  "Twinkle Twinkle Little Star",
  "Mary Had a Little Lamb",
  "Ode to Joy"
};

const byte SONG_COUNT = 3;
const unsigned int BEAT_MS = 280;

byte songIndex = 0;
unsigned int noteIndex = 0;

bool playing = false;

unsigned long noteStarted = 0;
unsigned int noteDuration = 0;
bool noteSounding = false;


// ---------------- MIDI ----------------

unsigned int noteFrequency(byte midi) {
  if (midi == 0) return 0;

  const unsigned int freq[] = {
    262,277,294,311,330,
    349,370,392,415,440
  };

  if (midi >= 60 && midi <= 69) {
    return freq[midi - 60];
  }

  return 0;
}


// ---------------- SONG HELPERS ----------------

unsigned int songLength() {
  if (songIndex == 0) return sizeof(song0);
  if (songIndex == 1) return sizeof(song1);

  return sizeof(song2);
}

byte melodyNote(unsigned int i) {
  if (songIndex == 0) return song0[i];
  if (songIndex == 1) return song1[i];

  return song2[i];
}

byte melodyBeat(unsigned int i) {
  if (songIndex == 0) return beats0[i];
  if (songIndex == 1) return beats1[i];

  return beats2[i];
}


// ---------------- UI STATUS ----------------

void sendSongStatus() {
  Serial.print("SONG,");
  Serial.print(songIndex);
  Serial.print(",");
  Serial.println(songNames[songIndex]);
}

void sendPlayingStatus() {
  Serial.print("PLAYING,");
  Serial.println(playing ? 1 : 0);
}


// ---------------- SOUND ----------------

void stopSound() {
  noTone(BUZZER_PIN);
  digitalWrite(BUZZER_PIN, LOW);
}

void playPianoKey(byte key) {
  if (highOctave) {
    tone(BUZZER_PIN, highNotes[key]);
  } else {
    tone(BUZZER_PIN, lowNotes[key]);
  }
}


// ---------------- SONG PLAYER ----------------

void startSongNote(unsigned long now) {
  if (noteIndex >= songLength()) {
    playing = false;
    noteIndex = 0;

    stopSound();

    sendPlayingStatus();
    return;
  }

  byte pitch = melodyNote(noteIndex);

  noteDuration =
    (unsigned int)melodyBeat(noteIndex) * BEAT_MS;

  noteStarted = now;

  unsigned int hz = noteFrequency(pitch);

  if (hz > 0) {
    tone(BUZZER_PIN, hz);
    noteSounding = true;
  } else {
    stopSound();
    noteSounding = false;
  }
}

void togglePlayback() {
  playing = !playing;

  if (playing) {
    activeKey = -1;
    stopSound();

    startSongNote(millis());
  } else {
    stopSound();
  }

  sendPlayingStatus();
}

void nextSong() {
  songIndex =
    (songIndex + 1) % SONG_COUNT;

  noteIndex = 0;

  stopSound();

  sendSongStatus();

  if (playing) {
    startSongNote(millis());
  }
}


// ---------------- SETUP ----------------

void setup() {
  Serial.begin(115200);

  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(FLEX_PIN, INPUT);

  stopSound();

  Wire.begin();

  if (!sensor.begin(0x5A)) {
    Serial.println("ERROR: MPR121 not found");

    while (1) {
    }
  }

  Serial.println("KEEP ALL FINGERS OFF THE PADS");
  Serial.println("Calibrating...");

  delay(2000);

  long total[KEY_COUNT] = {};

  for (int sample = 0; sample < 100; sample++) {
    for (byte i = 0; i < KEY_COUNT; i++) {
      total[i] += sensor.filteredData(i);
    }

    delay(20);
  }

  for (byte i = 0; i < KEY_COUNT; i++) {
    baseline[i] =
      total[i] / 100.0;

    smoothed[i] =
      baseline[i];

    Serial.print("E");
    Serial.print(i);

    Serial.print(" starting baseline = ");
    Serial.println(baseline[i]);
  }

  int flexValue =
    analogRead(FLEX_PIN);

  highOctave =
    flexValue > OCTAVE_THRESHOLD;

  Serial.println("READY");

  sendSongStatus();
  sendPlayingStatus();
}


// ---------------- LOOP ----------------

void loop() {
  unsigned long now = millis();

  // Flex sensor
  int flexValue =
    analogRead(FLEX_PIN);

  bool previousOctave =
    highOctave;

  highOctave =
    flexValue > OCTAVE_THRESHOLD;

  if (
    activeKey >= 0 &&
    highOctave != previousOctave &&
    !playing
  ) {
    playPianoKey(activeKey);
  }


  // Touch pads
  for (byte i = 0; i < KEY_COUNT; i++) {
    float raw =
      sensor.filteredData(i);

    smoothed[i] =
      (0.6 * smoothed[i]) +
      (0.4 * raw);

    float change =
      smoothed[i] - baseline[i];

    if (change < 0) {
      change = -change;
    }

    // Keep this output for Processing
    Serial.print("E");
    Serial.print(i);

    Serial.print(":");
    Serial.print(smoothed[i], 1);

    Serial.print("(");
    Serial.print(change, 1);

    Serial.print(")");


    // ---------------- E0-E7 PIANO ----------------

    if (i < 8) {
      float currentThreshold =
        PRESS_THRESHOLD;

      if (i == 1 || i == 7) {
        currentThreshold =
          SPECIAL_PRESS_THRESHOLD;
      }

      if (
        !pressed[i] &&
        change > currentThreshold
      ) {
        pressed[i] = true;

        if (
          !playing &&
          activeKey == -1
        ) {
          activeKey = i;

          playPianoKey(i);
        }
      }

      if (
        pressed[i] &&
        change < RELEASE_THRESHOLD
      ) {
        pressed[i] = false;

        if (
          activeKey == i &&
          !playing
        ) {
          stopSound();

          activeKey = -1;
        }
      }
    }


    // ---------------- E8 PLAY / PAUSE ----------------

    else if (i == 8) {
      if (
        !pressed[i] &&
        change > PRESS_THRESHOLD
      ) {
        pressed[i] = true;

        togglePlayback();
      }

      if (
        pressed[i] &&
        change < RELEASE_THRESHOLD
      ) {
        pressed[i] = false;
      }
    }


    // ---------------- E9 NEXT SONG ----------------

    else if (i == 9) {
      if (
        !pressed[i] &&
        change > PRESS_THRESHOLD
      ) {
        pressed[i] = true;

        nextSong();
      }

      if (
        pressed[i] &&
        change < RELEASE_THRESHOLD
      ) {
        pressed[i] = false;
      }
    }

    Serial.print("   ");
  }

  Serial.println();


  // Song playback
  if (playing) {
    if (
      now - noteStarted >=
      noteDuration
    ) {
      noteIndex++;

      startSongNote(now);
    }
    else if (
      noteSounding &&
      now - noteStarted >=
      (noteDuration * 9UL) / 10UL
    ) {
      stopSound();

      noteSounding = false;
    }
  }

  delay(50);
}