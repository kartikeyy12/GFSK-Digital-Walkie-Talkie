#include "arduino_secrets.h"

#include <SPI.h>
#include <RF24.h>

RF24 radio(7, 8); 
const int ADC_CS = 6;
const byte address[6] = "AUDIO";
volatile byte bufferA[32];
volatile byte bufferB[32];
volatile byte* writeBuffer = bufferA; 
volatile byte* sendBuffer = nullptr;  

volatile byte bufferIndex = 0;
volatile bool packetReady = false;

void setup() {
  Serial.begin(115200);
  pinMode(ADC_CS, OUTPUT);
  digitalWrite(ADC_CS, HIGH);
  if (!radio.begin()) {
    Serial.println("Radio hardware not responding!");
    while (1); 
  }
  radio.openWritingPipe(address);
  radio.setPALevel(RF24_PA_HIGH); 
  radio.setDataRate(RF24_2MBPS); 
  radio.stopListening();         
  cli(); 
  TCCR1A = 0;
  TCCR1B = 0;
  TCNT1  = 0;
  OCR1A = 249; 
  TCCR1B |= (1 << WGM12);
  TCCR1B |= (1 << CS11);  
  TIMSK1 |= (1 << OCIE1A); 
  sei(); 
}

void loop() {
  if (packetReady && sendBuffer != nullptr) {
    noInterrupts(); 
    radio.write((void*)sendBuffer, 32); 
    interrupts();   
    
    packetReady = false; 
  }
}


ISR(TIMER1_COMPA_vect) {
  writeBuffer[bufferIndex] = readFromExternalADC();
  bufferIndex++;
  if (bufferIndex >= 32) {
    sendBuffer = writeBuffer; 
    if (writeBuffer == bufferA) {
      writeBuffer = bufferB;
    } else {
      writeBuffer = bufferA;
    }
    bufferIndex = 0;
    packetReady = true;
  }
}


byte readFromExternalADC() {
  SPI.beginTransaction(SPISettings(1600000, MSBFIRST, SPI_MODE0));

  digitalWrite(ADC_CS, LOW); 
  byte highByte = SPI.transfer(0x00); 
  byte lowByte = SPI.transfer(0x00);  
  digitalWrite(ADC_CS, HIGH); 
  SPI.endTransaction();
  int adcValue = ((highByte & 0x1F) << 7) | (lowByte >> 1);
  return (byte)(adcValue >> 4);
}