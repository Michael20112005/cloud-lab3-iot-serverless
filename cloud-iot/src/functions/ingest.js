const { app } = require("@azure/functions");
const { CosmosClient } = require("@azure/cosmos");

const client = new CosmosClient(process.env.COSMOS_CONN);
const container = client.database("DeviceTelemetry").container("DeviceTelemetry");

app.http("ingest", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "ingest",
  handler: async (request, context) => {
    const body = await request.json();

    if (!body) {
      return { status: 400, jsonBody: { error: "No data" } };
    }

    const item = {
      ...body,
      id: `${body.deviceId}-${Date.now()}`,
      DeviceId: body.deviceId,
      timestamp: body.timestamp || new Date().toISOString(),
      receivedAt: new Date().toISOString()
    };

    try {
  await container.items.create(item);
} catch (error) {
  context.log("Cosmos error:", error.message);

  return {
    status: 500,
    jsonBody: {
      error: error.message,
      code: error.code
    }
  };
}

    context.log("Telemetry saved:", item);

    return {
      status: 200,
      jsonBody: {
        success: true,
        id: item.id
      }
    };
  }
});