# DE10-Nano Vision – FPGA-Based Image Processing System

## Project Overview

This project implements an FPGA-based image processing system using Verilog HDL on the Intel DE10-Nano Cyclone V SoC FPGA development board.

The design demonstrates real-time pixel processing using the Sobel edge detection algorithm. It includes a simulated camera input, image line buffering, edge detection, defect indication, and HDMI transmitter configuration through the I2C interface.

## Project Objectives

- Develop an FPGA-based image processing architecture.
- Implement the Sobel edge detection algorithm using Verilog HDL.
- Design line buffers for image processing.
- Generate video timing signals for image display.
- Configure the ADV7513 HDMI transmitter using I2C.
- Develop a testbench for RTL simulation and verification.

## Hardware Requirements

- Intel DE10-Nano Development Board
- Intel Cyclone V SoC FPGA (5CSEBA6U23I7)
- HDMI-compatible display
- HDMI cable

## Software Requirements

- Intel Quartus Prime 25.1 Lite Edition
- Questa or ModelSim for RTL simulation
- Verilog HDL

## Project Architecture

The project contains the following major modules:

1. **Top-Level Module:** Integrates the image processing and HDMI interface components.
2. **Camera Emulator:** Generates simulated 640 × 480 pixel video data.
3. **Line Buffer:** Stores previous image lines for pixel processing.
4. **Sobel Filter:** Performs gradient calculation and edge detection.
5. **I2C ADV7513 Configuration:** Configures the HDMI transmitter.
6. **Testbench:** Provides simulation stimulus and monitors output signals.

## Sobel Edge Detection

The Sobel operator detects image edges using horizontal and vertical gradient calculations.

The gradient magnitude is calculated using:

G = |Gx| + |Gy|

A threshold is applied to identify edge pixels.

- White pixel (255): Detected edge.
- Black pixel (0): Background.

## Project Directory Structure

```text
DE10-Nano-Vision-FPGA/
│
├── RTL/
│   ├── de10_nano_vision_top.v
│   ├── camera_emulator.v
│   ├── sobel_filter.v
│   ├── line_buffer.v
│   └── i2c_adv7513_config.v
│
├── Testbench/
│   └── tb_de10_nano_vision_top.v
│
├── Quartus_Project/
│   ├── de10_nano_vision.qpf
│   ├── de10_nano_vision_top.qsf
│   └── output_files/
│
└── Documentation/
```

## FPGA Implementation

The project targets the Intel Cyclone V SoC FPGA available on the DE10-Nano development board.

The Quartus project includes device configuration, pin assignments, RTL source files, and compilation settings.

## Simulation and Verification

The Verilog testbench is intended to verify the top-level design by generating clock, reset, and video pixel stimulus.

Questa/ModelSim can be used for RTL simulation and waveform analysis.

## Compilation Results

The Quartus compilation output includes the following reports:

- Fitter Summary
- Mapping Summary
- Static Timing Analysis Summary
- FPGA programming file (.sof)

## Future Improvements

- Integrate a physical camera sensor.
- Implement real-time PCB defect detection.
- Improve image processing performance.
- Add additional image filtering algorithms.
- Optimize FPGA resource utilization.

## Author

**Gaurav Sain**
GitHub: [gaurav-sainn](https://github.com/gaurav-sainn)

## Platform

Intel DE10-Nano | Cyclone V SoC FPGA

Intel Quartus Prime 25.1 | Verilog HDL
