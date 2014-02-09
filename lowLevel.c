//Loosely based on a tutorial, adapted by Alex Seewald
#include <ctype.h>
const int rxPin = 0;
const int txPin = 1;
const int dataBits = 8;

const int bit9600Delay = 84;
const int halfBit9600Delay = 42; //The appropriate delay, in microseconds
//to make for a 9600 baud rate.
const int bit4800Delay = 188;
const int halfBit4800Delay = 94;

char sondeData[9999];
unsigned int sondeDataSize = 0;

void setup() {
   Serial.begin(9600);
   pinMode(rxPin, INPUT);
   pinMode(txPin, OUTPUT);
}

void loop() {
  byte sondeInput = 'i';
  while (digitalRead(rxPin)); //waits for start bit.
    if (digitalRead(rxPin) == LOW) {
      delayMicroseconds(halfBit9600Delay);
      //An iteration for each data bit
      for (int offset = 0; offset < dataBits; offset++) {
         delayMicroseconds(bit9600Delay);
         sondeInput |= digitalRead(rxPin) << offset;
      }
      //waiting for the stop bit
      Serial.println("loop is running");
      delayMicroseconds(bit9600Delay);
      delayMicroseconds(bit9600Delay);
      sondeData[sondeDataSize] = (char) sondeInput;
      ++sondeDataSize;
    }
  }
