# Cloud Lab 3 — IoT Serverless Pipeline

This project implements an IoT data processing pipeline using cloud serverless technologies.

## Goal

The goal of this lab is to emulate IoT sensor data processing in the cloud using serverless services.

The system receives data from simulated IoT sensors, sends messages to a cloud messaging service, processes them with serverless functions, stores them in a database, and provides an HTTP endpoint for reading sensor history.

## Architecture

IoT Sensor Emulator  
→ IoT Hub / Event Hub  
→ Azure Function Consumer  
→ Cosmos DB  
→ HTTP History API

## Components

### 1. IoT Sensor Emulator

The emulator simulates three different sensors:

- temperature sensor
- humidity sensor
- light sensor

Each sensor sends:

- device id
- sensor type
- measured value
- unit
- location
- timestamp

Each sensor has its own configurable sending interval.

### 2. Messaging Layer

Sensor data is sent to a cloud messaging service.

In this project, the infrastructure is prepared for:

- Azure IoT Hub
- Event Hub-compatible endpoint

This layer works as a buffer between devices and processing functions.

### 3. Serverless Processing

Azure Functions are used to process incoming sensor messages.

The function is triggered when new telemetry data appears in the event stream.

Processing logic:

1. receive message
2. parse JSON payload
3. detect sensor type
4. validate data
5. store reading in Cosmos DB

### 4. Database

Cosmos DB is used to store sensor telemetry history.

Example record:

```json
{
  "deviceId": "temp-001",
  "sensorType": "temperature",
  "value": 24.7,
  "unit": "C",
  "location": {
    "lat": 49.8397,
    "lng": 24.0297
  },
  "timestamp": "2026-05-18T12:00:00.000Z"
}
