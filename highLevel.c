//Written by Alex Seewald.

#include <SoftwareSerial.h> 
#include <Time.h>  

const int rxPin = 10;
const int txPin = 11;
const int debug = 1;
SoftwareSerial mySerial = SoftwareSerial(rxPin, txPin);

void setup() 
{                
  //pinMode(rxPin, INPUT);
  //pinMode(txPin, OUTPUT);
  mySerial.begin(9600); //refers to connection between Sonde and arduino.
  Serial.begin(9600);   //debugging I/O to use with ardunio IDE
  while (!Serial) {
    delay(10);
  }
}

void loop()
{
  if (mySerial.available()) {
    Serial.write(mySerial.read());
  }
  else {
    Serial.write("mySerial is not available");
      if (debug) {
          mySerial.listen();
          if (mySerial.isListening()) {
              Serial.println("It is listening"); 
          }
      }
  }
}
