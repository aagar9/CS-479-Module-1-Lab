#include <Wire.h>
#include <SparkFun_Bio_Sensor_Hub_Library.h>

int resPin = 4;
int mfioPin = 5;

SparkFun_Bio_Sensor_Hub bioHub(resPin, mfioPin);

bioData body;

// Estimated beat-to-beat interval [ms]
float beatInterval_ms = 0;


void setup()
{
  Serial.begin(115200);
  Wire.begin();

  int result = bioHub.begin();

  if (result == 0)
  {
    Serial.println("Sensor started!");
  }
  else
  {
    Serial.println("Could not communicate with the sensor!");
  }

  Serial.println("Configuring Sensor....");

  int error = bioHub.configBpm(MODE_ONE);

  if (error == 0)
  {
    Serial.println("Sensor configured.");
  }
  else
  {
    Serial.println("Error configuring sensor.");
  }

  delay(4000);

  Serial.println("Loading up the buffer with data....");
}


void loop()
{
  // Read processed data from MAX32664
  body = bioHub.readBpm();


  // -----------------------------------------
  // Calculate estimated beat interval
  // -----------------------------------------

  if (body.heartRate > 0)
  {
    beatInterval_ms = 60000.0 / body.heartRate;
  }
  else
  {
    beatInterval_ms = 0;
  }


  // -----------------------------------------
  // Serial Monitor output
  // -----------------------------------------

  Serial.print("Heartrate: ");
  Serial.print(body.heartRate);
  Serial.print(" bpm | ");

  Serial.print("Confidence: ");
  Serial.print(body.confidence);
  Serial.print(" % | ");

  Serial.print("Oxygen: ");
  Serial.print(body.oxygen);
  Serial.print(" % | ");

  Serial.print("Status: ");
  Serial.println(body.status);


  delay(500);
}