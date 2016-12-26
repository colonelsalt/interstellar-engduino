#include <EngduinoAccelerometer.h>
#include <EngduinoButton.h>
#include <Wire.h>

// stores acceleration vector measured from accelerometer
float output[3];

void setup()
{
  EngduinoAccelerometer.begin();
  EngduinoButton.begin();
}

void loop()
{ 
  if (EngduinoButton.wasPressed())
  {
    // communicate to Processing to fire laser in game
    Serial.println('F');
  }
  
  // read acceleration values from accelerometer
  EngduinoAccelerometer.xyz(output);
  
  // send variation in acceleration along y-axis to Processing
  Serial.print('y');
  Serial.println(output[1]);
  delay(100);
}
