const express = require("express");
const fs = require("fs");
const path = require("path");

const app = express();
app.use(express.json());

const DATA_FILE = path.join(__dirname, "sensor-data.json");

if (!fs.existsSync(DATA_FILE)) {
  fs.writeFileSync(DATA_FILE, JSON.stringify([]));
}

// ✅ HISTORY (ОКРЕМО)
app.get("/api/history", (req, res) => {
  const data = JSON.parse(fs.readFileSync(DATA_FILE));

  const sensorType = req.query.sensorType;

  if (sensorType) {
    return res.json(
      data.filter(item => item.sensorType === sensorType)
    );
  }

  res.json(data);
});

// ✅ INGEST (ОКРЕМО)
app.post("/api/ingest", (req, res) => {
  console.log("Telemetry received:");
  console.log(JSON.stringify(req.body, null, 2));

  const existing = JSON.parse(fs.readFileSync(DATA_FILE));

  existing.push(req.body);

  fs.writeFileSync(DATA_FILE, JSON.stringify(existing, null, 2));

  res.status(200).json({
    success: true,
    receivedAt: new Date().toISOString()
  });
});

const PORT = 7071;

app.listen(PORT, () => {
  console.log(`Local ingest API running on port ${PORT}`);
});