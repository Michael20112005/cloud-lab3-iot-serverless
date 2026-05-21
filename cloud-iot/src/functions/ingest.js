const { app } = require("@azure/functions");
const { QueueServiceClient } = require("@azure/storage-queue");

const queueServiceClient = QueueServiceClient.fromConnectionString(
  process.env.AzureWebJobsStorage
);

const queueClient = queueServiceClient.getQueueClient("sensor-telemetry");

app.http("ingest", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "ingest",
  handler: async (request, context) => {
    const body = await request.json();

    if (!body) {
      return {
        status: 400,
        jsonBody: { error: "No data" }
      };
    }

    const message = {
      ...body,
      id: `${body.deviceId}-${Date.now()}`,
      DeviceId: body.deviceId,
      timestamp: body.timestamp || new Date().toISOString(),
      receivedAt: new Date().toISOString()
    };

    await queueClient.createIfNotExists();
    await queueClient.sendMessage(Buffer.from(JSON.stringify(message)).toString("base64"));

    context.log("Telemetry queued:", message);

    return {
      status: 200,
      jsonBody: {
        success: true,
        queued: true
      }
    };
  }
});