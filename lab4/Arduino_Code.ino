
#include <Wire.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

// ========== PINS AND SETTINGS ========== //
const int fsrPins[4] = {A0, A1, A2, A3};  // FSR inputs: MF, LF, MM, HEEL
const int ledPins[4] = {3, 5, 6, 9};     // PWM LED outputs

const bool LED_ENABLED = true;          // false = LEDs OFF, true = LEDs ON
const int FSR_ZERO_THRESHOLD = 15;       // Readings below 15 ADC become zero
const int LED_THRESHOLD = 70;            // Minimum FSR value to activate LED

const unsigned long SAMPLE_INTERVAL = 40; // 40 ms = 25 samples/second
unsigned long lastSample = 0;             // Time of previous acquisition

// ========== SENSOR VARIABLES ========== //
int fsrValues[4] = {0, 0, 0, 0};          // Latest FSR readings (0-1023)

Adafruit_MPU6050 mpu;                     // Create MPU-6050 sensor object
bool mpuConnected = false;                // True if initialization succeeds


// ========== INITIALIZATION ========== //
void setup() {

  Serial.begin(115200);                   // Serial communication with Processing
  Wire.begin();                           // Initialize I2C communication

  // Configure LED pins
  for (int i = 0; i < 4; i++) {
    if (LED_ENABLED) {
      pinMode(ledPins[i], OUTPUT);         // Enable LED output
      analogWrite(ledPins[i], 0);         // Start with LEDs OFF
    }
    else {
      pinMode(ledPins[i], INPUT);          // High impedance: do not drive LEDs
    }
  }

  // Initialize MPU-6050
  mpuConnected = mpu.begin();             // Check MPU connection

  if (mpuConnected) {
    mpu.setAccelerometerRange(MPU6050_RANGE_4_G);  // +/- 4g
    mpu.setGyroRange(MPU6050_RANGE_500_DEG);       // +/- 500 deg/s
    mpu.setFilterBandwidth(MPU6050_BAND_10_HZ);    // 10 Hz low-pass filter
  }

  // If MPU initialization fails, FSR acquisition continues.
}


// ========== CONTINUOUS ACQUISITION ========== //
void loop() {

  unsigned long now = millis();            // Current Arduino time (ms)

  if (now - lastSample < SAMPLE_INTERVAL) {
    return;                                 // Not time for next sample yet
  }

  lastSample = now;                         // Update acquisition timestamp


  // ========== FSR READINGS AND LED CONTROL ========== //
  for (int i = 0; i < 4; i++) {

    int fsrValue = analogRead(fsrPins[i]);  // Read FSR value (0-1023)

    if (fsrValue < FSR_ZERO_THRESHOLD) {
      fsrValue = 0;                        // Eliminate small no-load offset
    }

    fsrValues[i] = fsrValue;               // Store latest reading

    // LED brightness proportional to FSR reading
    if (LED_ENABLED) {
      int brightness = 0;                  // LED OFF by default

      if (fsrValue > LED_THRESHOLD) {
        brightness = map(fsrValue, LED_THRESHOLD, 1023, 40, 255);  // Map FSR range to PWM brightness (40-255)
      }
      brightness = constrain(brightness, 0, 255); // Limit brightness to valid PWM range
      analogWrite(ledPins[i], brightness); // Set corresponding LED brightness
    }
  }


  // ========== MPU-6050 READINGS ========== //
  float ax = 0, ay = 0, az = 0;            // Acceleration (m/s^2)
  float gx = 0, gy = 0, gz = 0;            // Angular velocity (rad/s)
  bool mpuValid = false;                   // Status of current MPU reading

  if (mpuConnected) {

    sensors_event_t a, g, temp;            // Sensor event structures

    if (mpu.getEvent(&a, &g, &temp)) {      // Read accelerometer and gyroscope

      ax = a.acceleration.x;               // X acceleration
      ay = a.acceleration.y;               // Y acceleration
      az = a.acceleration.z;               // Z acceleration

      gx = g.gyro.x;                       // X angular velocity
      gy = g.gyro.y;                       // Y angular velocity
      gz = g.gyro.z;                       // Z angular velocity

      mpuValid = true;                     // Successful sensor reading
    }
  }


  // ========== SERIAL DATA TRANSMISSION ========== //
  // Format: time,MF,LF,MM,HEEL,ax,ay,az,gx,gy,gz,mpuValid
  // One CSV line for each acquisition (25 Hz)

  Serial.print(now);                       // Timestamp (ms)

  for (int i = 0; i < 4; i++) {
    Serial.print(",");
    Serial.print(fsrValues[i]);            // Four FSR readings (ADC)
  }

  Serial.print(",");
  Serial.print(ax, 2);
  Serial.print(",");
  Serial.print(ay, 2);
  Serial.print(",");
  Serial.print(az, 2);                     // Acceleration values (m/s^2)

  Serial.print(",");
  Serial.print(gx, 2);
  Serial.print(",");
  Serial.print(gy, 2);
  Serial.print(",");
  Serial.print(gz, 2);                     // Angular velocity values (rad/s)

  Serial.print(",");
  Serial.println(mpuValid ? 1 : 0);        // MPU status + end of data line
}


// map --> takes a value from the FSR force range (0-1023) and converts into a brightness value of the LED (0-255)
// applies a linear transformation --> y = y_min + ((x-x_min)/(x_max-x_min))*(y_max - y_min)
// constrain(value, min, max) --> prevent the value 'value' from being below 'min' or grater than 'max'