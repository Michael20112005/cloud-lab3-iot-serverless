const axios = require("axios");
const config = require("./config.json");

function randomValue(sensorType) {
  switch (sensorType) {
    case "temperature":
      return Number((18 + Math.random() * 12).toFixed(2)); // 18–30 C
    case "humidity":
      return Number((40 + Math.random() * 40).toFixed(2)); // 40–80 %
    case "light":
      return Number((200 + Math.random() * 800).toFixed(2)); // 200–1000 lux
    default:
      return Number((Math.random() * 100).toFixed(2));
  }
}

function createPayload(sensor) {
  return {
    deviceId: sensor.deviceId,
    sensorType: sensor.sensorType,
    value: randomValue(sensor.sensorType),
    unit: sensor.unit,
    location: sensor.location,
    timestamp: new Date().toISOString()
  };
}

function startSensor(sensor) {
  return setInterval(async () => {
    const payload = createPayload(sensor);

    try {
      const response = await axios.post(config.targetUrl, payload);
      console.log(
        `[${response.status}] ${sensor.sensorType}: ${payload.value}${payload.unit}`
      );
    } catch (error) {
      console.error(
        `[ERROR] ${sensor.sensorType}:`,
        error.response?.status || error.message
      );
    }
  }, sensor.intervalMs);
}

console.log("IoT sensor emulator started");
console.log(`Target URL: ${config.targetUrl}`);
console.log(`Duration: ${config.durationSeconds} seconds`);

const intervals = config.sensors.map(startSensor);

setTimeout(() => {
  intervals.forEach(clearInterval);
  console.log("IoT sensor emulator stopped");
  process.exit(0);
}, config.durationSeconds * 1000);