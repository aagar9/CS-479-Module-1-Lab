#include <Wire.h>
#include <Adafruit_MPR121.h>

Adafruit_MPR121 cap = Adafruit_MPR121();

void setup() {
  Serial.begin(115200);
  Wire.begin();

  if (!cap.begin(0x5A)) {
    Serial.println("ERROR: MPR121 not found");
    while (1) {
      delay(100);
    }
  }
}

void loop() {
  uint16_t touched = cap.touched();

  char direction = 'S';

  if (touched & (1 << 0)) {
    direction = 'U';
  }
  else if (touched & (1 << 1)) {
    direction = 'L';
  }
  else if (touched & (1 << 2)) {
    direction = 'R';
  }
  else if (touched & (1 << 3)) {
    direction = 'D';
  }

  Serial.println(direction);
  delay(30);
}
