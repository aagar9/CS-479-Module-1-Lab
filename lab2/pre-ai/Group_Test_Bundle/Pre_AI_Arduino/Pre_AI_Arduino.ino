// ARDUINO CODE --> ACQUIRE ECG SIGNAL

const int LO_PLUS_PIN = 10;    // da definire
const int LO_MINUS_PIN = 11;   // da definire

int ECG;
int FSR;

int FSR_PIN = A1; // A1 //  --> analog input pin on which FSR sensor is connected
int ECG_PIN = A0;  // A0 // --> analog input pin on which ECG sensor is connected

void setup() {
  // initialize the serial communication:
  Serial.begin(115200);
  pinMode(LO_PLUS_PIN, INPUT); // Setup for leads off detection LO +  --> D10 --> check whether the electrode is connected
  pinMode(LO_MINUS_PIN, INPUT); // Setup for leads off detection LO -   --> D11 --> check whether the electrode is connected
  pinMode(FSR_PIN, INPUT);  // pin di ingresso del segnale FSR

}

void loop() {

  int ECG = analogRead(A0);  // int ECG = analogRead(ECG_PIN);
  int FSR = analogRead(A1);  // int FSR = analogRead(FSR_PIN);

  if((digitalRead(10) == 1)||(digitalRead(11) == 1)){     // electrodes not connected
    Serial.print('!');
    Serial.print(",");
    Serial.println(FSR);
  }
  else{                   // send the value of analog input 0 and 1:
      Serial.print(ECG);
      Serial.print(",");
      Serial.println(FSR); // sends --> ECG,FSR/n
  }
  //Wait for a bit to keep serial data from saturating
  delay(5);
}
