const { app } = require("@azure/functions");
const { CosmosClient } = require("@azure/cosmos");

const client = new CosmosClient(process.env.COSMOS_CONN);
const container = client
  .database("DeviceTelemetry")
  .container("DeviceTelemetry");

function parseQueueMessage(queueItem) {
  if (typeof queueItem === "object") {
    return queueItem;
  }

  try {
    return JSON.parse(queueItem);
  } catch {
    const decoded = Buffer.from(queueItem, "base64").toString("utf8");
    return JSON.parse(decoded);
  }
}

app.storageQueue("queueConsumer", {
  queueName: "sensor-telemetry",
  connection: "AzureWebJobsStorage",
  handler: async (queueItem, context) => {
    const item = parseQueueMessage(queueItem);

    await container.items.create(item);

    context.log("Telemetry saved from queue:", item);
  }
});