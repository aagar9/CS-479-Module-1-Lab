#include <Wire.h>
#include <Adafruit_MPU6050.h>
#include <Adafruit_Sensor.h>

// ========== PINS AND SETTINGS ========== //
const int FLEX_PIN = A0;                // Flex sensor voltage divider
const int FSR_THUMB_PIN = A1;           // Thumb FSR voltage divider
const int FSR_INDEX_PIN = A2;           // Index finger FSR voltage divider

const unsigned long SAMPLE_INTERVAL = 40;  // 40 ms = 25 Hz
unsigned long lastSample = 0;

// ========== SENSOR OBJECTS ========== //
Adafruit_MPU6050 mpu;
bool mpuConnected = false;

// ========== INITIALIZATION ========== //
void setup() {
  Serial.begin(115200);                // Arduino -> BLE -> Processing
  Wire.begin();                       // MPU-6050 over I2C (A4 SDA, A5 SCL)

  pinMode(FLEX_PIN, INPUT);           // Analog input: flex
  pinMode(FSR_THUMB_PIN, INPUT);      // Analog input: thumb FSR
  pinMode(FSR_INDEX_PIN, INPUT);      // Analog input: index FSR

  mpuConnected = mpu.begin();         // Detect MPU-6050 at I2C address 0x68
  if (mpuConnected) {
    mpu.setAccelerometerRange(MPU6050_RANGE_4_G);  // +/- 4 g
    mpu.setGyroRange(MPU6050_RANGE_500_DEG);       // +/- 500 deg/s
    mpu.setFilterBandwidth(MPU6050_BAND_10_HZ);    // Sensor low-pass filter
  }
  // Even without the MPU, the analog inputs continue to be transmitted.
}

// ========== CONTINUOUS ACQUISITION ========== //
void loop() {
  unsigned long now = millis();
  if (now - lastSample < SAMPLE_INTERVAL) return;
  lastSample = now;

  // Keep RAW ADC values: calibration must not discard small variations.
  int flexADC = analogRead(FLEX_PIN);           // 0..1023
  int thumbADC = analogRead(FSR_THUMB_PIN);     // 0..1023
  int indexADC = analogRead(FSR_INDEX_PIN);     // 0..1023

  float ax = 0, ay = 0, az = 0;                 // m/s^2
  float gx = 0, gy = 0, gz = 0;                 // rad/s
  bool mpuValid = false;

  if (mpuConnected) {
    sensors_event_t a, g, temp;
    if (mpu.getEvent(&a, &g, &temp)) {
      ax = a.acceleration.x;
      ay = a.acceleration.y;
      az = a.acceleration.z;
      gx = g.gyro.x;
      gy = g.gyro.y;
      gz = g.gyro.z;
      mpuValid = true;
    }
  }

  // ========== SERIAL CSV ========== //
  // time_ms,flexADC,thumbADC,indexADC,ax,ay,az,gx,gy,gz,mpuValid
  // Do not add debug messages on Serial: Processing expects CSV lines.
  Serial.print(now);
  Serial.print(','); Serial.print(flexADC);
  Serial.print(','); Serial.print(thumbADC);
  Serial.print(','); Serial.print(indexADC);
  Serial.print(','); Serial.print(ax, 2);
  Serial.print(','); Serial.print(ay, 2);
  Serial.print(','); Serial.print(az, 2);
  Serial.print(','); Serial.print(gx, 3);
  Serial.print(','); Serial.print(gy, 3);
  Serial.print(','); Serial.print(gz, 3);
  Serial.print(','); Serial.println(mpuValid ? 1 : 0);
}
