/*********************************************************
This is a library for the MPR121 12-channel Capacitive touch sensor

Designed specifically to work with the MPR121 Breakout in the Adafruit shop
  ----> https://www.adafruit.com/products/

These sensors use I2C communicate, at least 2 pins are required
to interface

Adafruit invests time and resources providing this open source code,
please support Adafruit and open-source hardware by purchasing
products from Adafruit!

Written by Limor Fried/Ladyada for Adafruit Industries.
BSD license, all text above must be included in any redistribution
**********************************************************/

#include <Wire.h>
#include "Adafruit_MPR121.h"

#ifndef _BV
#define _BV(bit) (1 << (bit))
#endif

Adafruit_MPR121 cap = Adafruit_MPR121();

uint16_t lasttouched = 0;
uint16_t currtouched = 0;

// Flex: connected to A1
const int FLEX_PIN = A1;

// print value every 50 ms ( 20 readings every second).
const unsigned long FLEX_INTERVAL_MS = 50;
unsigned long lastFlexTime = 0;

void setup() {
  Serial.begin(115200);

  while (!Serial) {
    delay(10);
  }

  pinMode(FLEX_PIN, INPUT);

  Serial.println("Adafruit MPR121 + flex sensor test");

  if (!cap.begin(0x5A)) {
    Serial.println("MPR121 not found, check wiring?");
    while (1);
  }

  Serial.println("MPR121 found!");
  Serial.println("Running auto configuration.");
  cap.setAutoconfig(true);

  Serial.println("Initialization complete.");
}

void loop() {
  // 1. check if pad are touched or not
  currtouched = cap.touched();

  for (uint8_t i = 0; i < 12; i++) {
    if ((currtouched & _BV(i)) && !(lasttouched & _BV(i))) {
      Serial.print(i);
      Serial.println(" touched");
    }

    if (!(currtouched & _BV(i)) && (lasttouched & _BV(i))) {
      Serial.print(i);
      Serial.println(" released");
    }
  }

  lasttouched = currtouched;

  // 2. Leggi e stampa il flex ogni 50 ms.
  // millis() permette di aspettare senza bloccare il controllo dei pad.
  unsigned long currentTime = millis();

  if (currentTime - lastFlexTime >= FLEX_INTERVAL_MS) {
    lastFlexTime = currentTime;

    int flexValue = analogRead(FLEX_PIN);

    Serial.print("Flex: ");
    Serial.println(flexValue);
  }
}

