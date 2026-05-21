# Cloud Lab 3 — IoT Sensor Data Processing with Serverless Azure Technologies

## Overview

This project implements an IoT telemetry processing pipeline using Azure serverless services.

The solution simulates multiple IoT sensors, sends telemetry data through REST APIs, processes messages with Azure Functions, and stores telemetry history in Azure Cosmos DB.

---

## Architecture

Telemetry processing flow:

```text
IoT Sensor Emulator
        ↓
HTTP POST /api/ingest
        ↓
Azure Function (ingest)
        ↓
Event Hub Consumer (serverless trigger)
        ↓
Azure Cosmos DB
        ↓
Azure Function /api/history
```

Infrastructure deployment via Bicep:

```text
IoT Hub
Event Hub
Azure Storage Account
Azure Functions
Cosmos DB
```

---

## Features

### IoT Emulator

The emulator simulates 3 sensor types:

- Temperature sensor
- Humidity sensor
- Light sensor

Each sensor includes:

- unique device ID
- sensor type
- telemetry value
- measurement unit
- GPS coordinates
- timestamp

Configurable parameters:

- target URL
- execution duration
- request frequency

Example frequencies:

- temperature → 20 ms
- humidity → 50 ms
- light → 100 ms

---

## Azure Functions

### ingest

HTTP-triggered Azure Function:

```text
POST /api/ingest
```

Responsibilities:

- receive telemetry JSON
- validate request
- enrich telemetry metadata
- store records in Cosmos DB

---

### history

HTTP-triggered Azure Function:

```text
GET /api/history
```

Supports:

- full telemetry history retrieval
- filtering by sensor type

Example:

```text
/api/history?sensorType=temperature
```

---

### consumer

Event Hub-triggered Azure Function.

Responsibilities:

- listen for telemetry events
- automatically trigger on new messages
- process event payloads
- persist data into Cosmos DB

---

## Azure Infrastructure

Provisioned using:

```text
infra/main.bicep
```

Resources:

- Azure IoT Hub
- Azure Event Hub
- Azure Cosmos DB
- Azure Storage Account
- Azure Function Apps

Cosmos DB structure:

```text
Database: DeviceTelemetry
Container: DeviceTelemetry
Partition key: /DeviceId
```

---

## Local Testing

Run Azure Functions:

```bash
cd cloud-iot
func start
```

Run sensor emulator:

```bash
cd emulator
node sensor-emulator.js
```

Manual telemetry test:

```bash
curl -X POST http://localhost:7071/api/ingest \
  -H "Content-Type: application/json" \
  -d "{\"deviceId\":\"temp-001\",\"sensorType\":\"temperature\",\"value\":24.5}"
```

History:

```text
http://localhost:7071/api/history
```

---

## Technologies

- Node.js
- Azure Functions v4
- Azure Cosmos DB
- Azure Event Hub
- Azure IoT Hub
- Azure Bicep
- Axios
- Azure Functions Core Tools

---

## Educational Goal

The purpose of this laboratory work is to demonstrate a scalable IoT telemetry processing architecture using cloud-native serverless Azure services.