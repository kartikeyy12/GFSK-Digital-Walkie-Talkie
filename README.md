# 📻 Digital Walkie Talkie Architecture Utilizing GFSK

*A 2.4 GHz half-duplex wireless communication system bridging analog acoustics and digital RF transmission.*

![Platform](https://img.shields.io/badge/Platform-Arduino-blue)
![RF](https://img.shields.io/badge/RF-NRF24L01-green)
![Simulation](https://img.shields.io/badge/Simulation-MATLAB-orange)

## 📌 Overview
This project details the design and implementation of a digital half-duplex communication system functioning as a wireless walkie-talkie within the 2.4 GHz Industrial, Scientific, and Medical (ISM) band.  It captures analog acoustic signals, digitizes them via an ATmega328P ADC, and transmits the payload using Gaussian Frequency Shift Keying (GFSK) modulation. 

 At the receiving node, the signal is demodulated and synthesized back into an analog waveform utilizing a high-frequency Pulse Width Modulated (PWM) DAC, followed by a passive low-pass filter and an LM386 power amplifier.

 **Detailed Project Report:** [Read PDF](docs/EC256-ProjectReport.pdf) 
 **Presentation Slides:** [View PDF](docs/EC256-Presentation.pptx) 

 > 📖 **Read the full circuit breakdown, signal flow analysis, and hardware build log on [Hackster.io](https://www.hackster.io/kartikey-tiwari/digital-gfsk-walkie-talkie-architecture-5859e6).**

## 🛠️ Hardware Stack
*  **Central Processing Unit:** Arduino UNO (ATmega328P) executing ADC algorithms and PWM-based DAC synthesis.
*  **RF Transceiver:** NRF24L01 managing the physical layer and GFSK modulation/demodulation at 2.4 GHz.
*  **Audio Acquisition:** Electret Microphone with an LM358 Operational Amplifier for active pre-amplification.
*  **Audio Output:** Passive RC low-pass filter, LM386 Audio Power Amplifier, and an 8-Ohm 0.5W Electrodynamic Speaker.

## ⚙️ System Architecture Pipeline

### Transmitter Node
1.   **Signal Acquisition:** The electret microphone captures acoustic energy.
2.   **Pre-Amplification:** An LM358 op-amp in a non-inverting topology boosts the millivolt-level signal to a 0-5V dynamic range suitable for sampling.
3.   **Digitization (ADC):** The Arduino's internal ADC samples the waveform, quantizing it into an 8-bit discrete digital payload.
4.   **GFSK Modulation:** Data is clocked via SPI to the NRF24L01, which applies a Gaussian filter to smooth pulses before frequency modulating the 2.4 GHz carrier.

### Receiver Node
1.   **RF Demodulation:** The receiving NRF24L01 captures the EM waves, demodulates the GFSK carrier, and verifies data integrity via CRC.
2.   **DAC Synthesis:** The receiving Arduino reads the digital values and dynamically adjusts the duty cycle of a high-frequency PWM signal.
3.   **Signal Reconstruction:** A passive RC low-pass filter attenuates the PWM carrier, integrating the square wave back into a continuous audio envelope.
4.   **Power Amplification:** The LM386 IC boosts the signal's current to drive the 8-ohm speaker.

## 📊 Mathematical Verification
 The discrete sampling, quantization, and GFSK modulation/demodulation processes were rigorously modeled and verified using MATLAB, ensuring physical hardware outputs correlated with theoretical expectations. *(See `/matlab` directory for scripts).*
