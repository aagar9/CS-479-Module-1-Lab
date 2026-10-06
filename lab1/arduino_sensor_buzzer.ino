#include <Wire.h>
#include <SparkFun_Bio_Sensor_Hub_Library.h>


// ============================================================
// SENSOR
// ============================================================

int resPin = 4;
int mfioPin = 5;

SparkFun_Bio_Sensor_Hub bioHub(
  resPin,
  mfioPin
);

bioData body;


// ============================================================
// BUZZER
// ============================================================

const int BUZZER_PIN = 12;


// ============================================================
// SETUP
// ============================================================

void setup()
{
  Serial.begin(115200);

  Wire.begin();


  // ----------------------------------------------------------
  // Buzzer
  // ----------------------------------------------------------

  pinMode(
    BUZZER_PIN,
    OUTPUT
  );

  noTone(
    BUZZER_PIN
  );


  // ----------------------------------------------------------
  // PPG sensor
  // ----------------------------------------------------------

  int result =
    bioHub.begin();


  if (result == 0)
  {
    Serial.println(
      "Sensor started!"
    );
  }

  else
  {
    Serial.println(
      "Could not communicate with the sensor!"
    );
  }


  Serial.println(
    "Configuring Sensor...."
  );


  int error =
    bioHub.configBpm(
      MODE_ONE
    );


  if (error == 0)
  {
    Serial.println(
      "Sensor configured."
    );
  }

  else
  {
    Serial.println(
      "Error configuring sensor."
    );
  }


  delay(4000);


  Serial.println(
    "Loading up the buffer with data...."
  );
}


// ============================================================
// MAIN LOOP
// ============================================================

void loop()
{
  // ----------------------------------------------------------
  // 1. Check commands received from Processing
  // ----------------------------------------------------------

  checkBuzzerCommand();


  // ----------------------------------------------------------
  // 2. Read PPG sensor
  // ----------------------------------------------------------

  body =
    bioHub.readBpm();


  // ----------------------------------------------------------
  // 3. Send sensor data to Processing
  // ----------------------------------------------------------

  Serial.print(
    "Heartrate: "
  );

  Serial.print(
    body.heartRate
  );

  Serial.print(
    " bpm | "
  );


  Serial.print(
    "Confidence: "
  );

  Serial.print(
    body.confidence
  );

  Serial.print(
    " % | "
  );


  Serial.print(
    "Oxygen: "
  );

  Serial.print(
    body.oxygen
  );

  Serial.print(
    " % | "
  );


  Serial.print(
    "Status: "
  );

  Serial.println(
    body.status
  );


  delay(500);
}


// ============================================================
// RECEIVE BUZZER COMMAND
// ============================================================

void checkBuzzerCommand()
{
  if (
    Serial.available() > 0
  )
  {
    char command =
      Serial.read();


    if (
      command == 'B'
    )
    {
      beepTwice();
    }
  }
}


// ============================================================
// DOUBLE BEEP
// ============================================================

void beepTwice()
{
  // First beep

  tone(
    BUZZER_PIN,
    1800
  );

  delay(300);

  noTone(
    BUZZER_PIN
  );


  // Pause

  delay(250);


  // Second beep

  tone(
    BUZZER_PIN,
    1800
  );

  delay(300);

  noTone(
    BUZZER_PIN
  );
}