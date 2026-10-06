#include <Wire.h>
#include <SparkFun_Bio_Sensor_Hub_Library.h>

// FireBeetle 328P BLE 4.1: preserve the lab's wiring.
const uint8_t RESET_PIN=4, MFIO_PIN=5, BUZZER_PIN=12, HUB_ADDRESS=0x55;
SparkFun_Bio_Sensor_Hub bioHub(RESET_PIN, MFIO_PIN);
bool sensorReady=false;
uint8_t beepPhase=0;
unsigned long beepStarted=0, lastPoll=0;
uint8_t readFailureStage=0, readFailureCode=0;
unsigned long lastErrorReport=0;
bool errorReported=false;
unsigned long lastRecoveryAttempt=0, lastTransmit=0, lastGoodSample=0;
uint8_t recoveryAttempts=0, consecutiveCountErrors=0;
const unsigned long TRANSMIT_INTERVAL_MS=40; // At most 25 raw packets/s over BLE.

// Execute a hub read with explicit I2C/status/length checks. MODE_ONE sensor +
// algorithm output is 18 payload bytes, fitting the AVR Wire 32-byte buffer.
bool hubRead(uint8_t family,uint8_t index,uint8_t *data,uint8_t count) {
  readFailureStage=0; readFailureCode=0;
  Wire.beginTransmission(HUB_ADDRESS); Wire.write(family); Wire.write(index);
  uint8_t busResult=Wire.endTransmission();
  if(busResult!=0) { readFailureStage=1; readFailureCode=busResult; return false; }
  delay(2); // Required hub command response delay, not a sampling-rate delay.
  uint8_t got=Wire.requestFrom(HUB_ADDRESS,(uint8_t)(count+1));
  if(got!=count+1) {
    readFailureStage=2; readFailureCode=got;
    while(Wire.available()) Wire.read(); return false;
  }
  uint8_t status=Wire.read();
  for(uint8_t i=0;i<count;i++) data[i]=Wire.read();
  if(status!=0) { readFailureStage=3; readFailureCode=status; return false; }
  return true;
}

// Report the actual failure once per second instead of flooding the serial link.
// I2C write code 2 = address NACK; code 3 = data NACK. A nonzero hub status
// is a sensor command response, distinct from wiring/transport errors.
void reportReadError(bool fifoCount) {
  if(errorReported && millis()-lastErrorReport<1000) return;
  errorReported=true; lastErrorReport=millis();
  Serial.print(fifoCount?F("ERROR FIFO count | "):F("ERROR FIFO sample | "));
  if(readFailureStage==1) Serial.print(F("I2C write code="));
  else if(readFailureStage==2) Serial.print(F("short reply bytes="));
  else Serial.print(F("hub status="));
  Serial.println(readFailureCode);
}

// Decode the unsigned 24-bit optical channel values.
uint32_t value24(const uint8_t *p) { return ((uint32_t)p[0]<<16)|((uint32_t)p[1]<<8)|p[2]; }

// Start only one double-beep sequence at a time; do not block sensor polling.
void checkBuzzer() {
  while(Serial.available()) {
    char command=Serial.read();
    if(command=='B' && beepPhase==0) { beepPhase=1; beepStarted=millis(); tone(BUZZER_PIN,1800); Serial.println(F("BUZZER started")); }
  }
  unsigned long elapsed=millis()-beepStarted;
  if(beepPhase==1 && elapsed>=300) { noTone(BUZZER_PIN); beepPhase=2; beepStarted=millis(); }
  else if(beepPhase==2 && elapsed>=250) { tone(BUZZER_PIN,1800); beepPhase=3; beepStarted=millis(); }
  else if(beepPhase==3 && elapsed>=300) { noTone(BUZZER_PIN); beepPhase=0; Serial.println(F("BUZZER complete")); }
}

// Reinitialize both the I2C peripheral and the sensor after a broken FIFO read.
// Explicit pin arguments restore MFIO to OUTPUT before the reset sequence.
bool initializeSensor() {
  Wire.end(); Wire.begin(); Wire.setClock(100000);
  Wire.setWireTimeout(25000,true); // AVR Wire: bound a stuck bus and reset TWI on timeout.
  Wire.clearWireTimeoutFlag();
  if(bioHub.begin(Wire,RESET_PIN,MFIO_PIN)!=0) { Serial.println(F("ERROR sensor connection")); return false; }
  if(bioHub.configSensorBpm(MODE_ONE)!=0) { Serial.println(F("ERROR sensor configuration")); return false; }
  if(bioHub.agcAlgoControl(ENABLE)!=0) { Serial.println(F("ERROR automatic gain configuration")); return false; }
  sensorReady=true;
  consecutiveCountErrors=0; lastGoodSample=millis(); lastPoll=millis();
  lastTransmit=millis();
  Serial.println(F("READY raw PPG; BPM; confidence; SpO2; status"));
  return true;
}

// Discard partial frames. Never retry a partially consumed FIFO packet as new data.
void scheduleRecovery() {
  sensorReady=false;
  lastRecoveryAttempt=millis();
  Serial.println(F("ERROR sensor recovering; waiting to reset connection"));
}

// Retry automatically with backoff. Finish any active beep before a blocking reset.
void recoverSensor() {
  unsigned long waitMs=recoveryAttempts<3?1000:10000;
  if(beepPhase!=0 || millis()-lastRecoveryAttempt<waitMs) return;
  if(recoveryAttempts<255) recoveryAttempts++;
  Serial.println(F("ERROR sensor recovering; resetting sensor now"));
  initializeSensor();
  lastRecoveryAttempt=millis();
}

// Configure raw output only on the wireless board carrying the physical sensor.
void setup() {
  Serial.begin(115200); pinMode(BUZZER_PIN,OUTPUT); noTone(BUZZER_PIN);
  initializeSensor();
  lastRecoveryAttempt=millis();
}

// Read every available sample. Backlogs are excluded from pulse timing because
// their acquisition times are unknown; this avoids timing buffered reads as beats.
void loop() {
  checkBuzzer();
  if(!sensorReady) { recoverSensor(); return; }
  if(millis()-lastPoll<2) return;
  unsigned long pollTime=millis();
  bool promptPoll=(pollTime-lastPoll<=10);
  lastPoll=pollTime;
  uint8_t count=0;
  if(!hubRead(0x12,0x00,&count,1)) {
    reportReadError(true);
    if(++consecutiveCountErrors>=3) { consecutiveCountErrors=0; scheduleRecovery(); }
    return;
  }
  consecutiveCountErrors=0;
  if(count==0) {
    if(millis()-lastGoodSample>5000) {
      Serial.println(F("ERROR sensor stopped producing samples")); scheduleRecovery();
    }
    return;
  }
  bool timingUsable=(count==1 && promptPoll);
  for(uint8_t i=0;i<count;i++) {
    checkBuzzer(); uint8_t data[18];
    unsigned long timestamp=millis();
    if(!hubRead(0x12,0x01,data,18)) { reportReadError(false); scheduleRecovery(); return; }
    lastGoodSample=millis();
    if(millis()-lastRecoveryAttempt>30000) recoveryAttempts=0;
    // Drain every sensor sample, but transmit only the most recent sample of a
    // batch and cap the BLE traffic. Sending every 100 Hz text frame overloads
    // the board's nominal 4 KB/s wireless link. Missing timing stays flagged.
    if(i+1<count || timestamp-lastTransmit<TRANSMIT_INTERVAL_MS) continue;
    lastTransmit=timestamp;
    uint16_t hr=((uint16_t)data[12]<<8)|data[13];
    uint16_t spo2=((uint16_t)data[15]<<8)|data[16];
    // PPG,board_ms,IR,red,HR_bpm,confidence,SpO2,status,timing_usable
    Serial.print(F("PPG,")); Serial.print(timestamp); Serial.print(',');
    Serial.print(value24(data)); Serial.print(','); Serial.print(value24(data+3)); Serial.print(',');
    Serial.print(hr/10.0,1); Serial.print(','); Serial.print(data[14]); Serial.print(',');
    Serial.print(spo2/10.0,1); Serial.print(','); Serial.print(data[17]); Serial.print(',');
    Serial.println(timingUsable?1:0);
  }
}
