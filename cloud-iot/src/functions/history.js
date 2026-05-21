const { app } = require("@azure/functions");
const { CosmosClient } = require("@azure/cosmos");

const client = new CosmosClient(process.env.COSMOS_CONN);
const container = client.database("DeviceTelemetry").container("DeviceTelemetry");

app.http("history", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "history",
  handler: async (request, context) => {
    const sensorType = request.query.get("sensorType");

    let query = "SELECT * FROM c";
    const parameters = [];

    if (sensorType) {
      query += " WHERE c.sensorType = @sensorType";
      parameters.push({
        name: "@sensorType",
        value: sensorType
      });
    }

    const { resources } = await container.items
      .query({ query, parameters })
      .fetchAll();

    context.log(`Returned ${resources.length} history records`);

    return {
      status: 200,
      jsonBody: resources
    };
  }
});