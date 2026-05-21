const { app } = require("@azure/functions");
const { CosmosClient } = require("@azure/cosmos");

const client = new CosmosClient(
  process.env.COSMOS_CONN || process.env.CosmosConnection
);

const container = client
  .database("DeviceTelemetry")
  .container("DeviceTelemetry");

app.eventHub("consumer", {
  connection: "HubConnection",
  eventHubName: "telemetry-hub",
  cardinality: "many",
  handler: async (events, context) => {
    context.log(`Consumer received ${events.length} event(s)`);

    for (const event of events) {
      const body = typeof event === "string" ? JSON.parse(event) : event;

      const item = {
        ...body,
        id: `${body.deviceId || body.DeviceId}-${Date.now()}-${Math.random()
          .toString(36)
          .slice(2)}`,
        DeviceId: body.deviceId || body.DeviceId || "unknown-device",
        timestamp: body.timestamp || new Date().toISOString(),
        receivedAt: new Date().toISOString()
      };

      await container.items.create(item);

      context.log("Telemetry event saved:", item);
    }
  }
});