@description('Prefix for all resources - use your surname in latin')
param studentName string

@description('Azure region - check allowed regions in Azure Policy')
param location string = resourceGroup().location

var prefix = 'lab3-${studentName}'
var storageAccountName = 'lab3${replace(studentName, '-', '')}sa'

// ── Storage Account (required for Functions) ──────────────────────────────
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
}

// ── IoT Hub (F1 = FREE tier, 8000 msg/day) ───────────────────────────────
resource iotHub 'Microsoft.Devices/IotHubs@2023-06-30' = {
  name: '${prefix}-iothub'
  location: location
  sku: {
    name: 'F1'
    capacity: 1
  }
  properties: {
    routing: {
      endpoints: {
        eventHubs: [
          {
            name: 'eventhub-endpoint'
            connectionString: listKeys(eventHubAuthRule.id, eventHubAuthRule.apiVersion).primaryConnectionString
            resourceGroup: resourceGroup().name
          }
        ]
      }
      routes: [
        {
          name: 'to-eventhub'
          source: 'DeviceMessages'
          condition: 'true'
          endpointNames: ['eventhub-endpoint']
          isEnabled: true
        }
      ]
    }
  }
  dependsOn: [eventHub]
}

// ── IoT Hub Devices ───────────────────────────────────────────────────────
// Note: devices are created via az cli after deployment (see README)

// ── Event Hub Namespace ───────────────────────────────────────────────────
resource eventHubNamespace 'Microsoft.EventHub/namespaces@2023-01-01-preview' = {
  name: '${prefix}-ehns'
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 1
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2023-01-01-preview' = {
  parent: eventHubNamespace
  name: 'telemetry-hub'
  properties: {
    partitionCount: 2
    messageRetentionInDays: 1
  }
}

// Auth rule for IoT Hub to send to Event Hub
resource eventHubAuthRule 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2023-01-01-preview' = {
  parent: eventHub
  name: 'iot-send-rule'
  properties: {
    rights: ['Send']
  }
}

// Auth rule for Function to listen from Event Hub
resource eventHubListenRule 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2023-01-01-preview' = {
  parent: eventHub
  name: 'listen-rule'
  properties: {
    rights: ['Listen']
  }
}

// ── CosmosDB (Free tier - 1000 RU/s, 25GB free) ──────────────────────────
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-11-15' = {
  name: '${prefix}-cosmos'
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    enableFreeTier: true
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
  }
}

resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-11-15' = {
  parent: cosmosAccount
  name: 'DeviceTelemetry'
  properties: {
    resource: { id: 'DeviceTelemetry' }
  }
}

resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-11-15' = {
  parent: cosmosDatabase
  name: 'DeviceTelemetry'
  properties: {
    resource: {
      id: 'DeviceTelemetry'
      partitionKey: {
        paths: ['/DeviceId']
        kind: 'Hash'
      }
    }
  }
}

// ── App Service Plan (Consumption = pay per use, ~free) ───────────────────
resource funcPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: '${prefix}-plan'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// ── Consumer Function App (EventHub trigger → CosmosDB) ───────────────────
resource consumerFunc 'Microsoft.Web/sites@2023-01-01' = {
  name: '${prefix}-consumer'
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: funcPlan.id
    siteConfig: {
      linuxFxVersion: 'Node|20'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~20'
        }
        {
          name: 'HubConnection'
          value: listKeys(eventHubListenRule.id, eventHubListenRule.apiVersion).primaryConnectionString
        }
        {
          name: 'CosmosConnection'
          value: cosmosAccount.listConnectionStrings().connectionStrings[0].connectionString
        }
      ]
    }
  }
}

// ── Device Simulator Function App (HTTP trigger → IoT Hub) ────────────────
resource deviceSimFunc 'Microsoft.Web/sites@2023-01-01' = {
  name: '${prefix}-device-sim'
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: funcPlan.id
    siteConfig: {
      linuxFxVersion: 'Node|20'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~20'
        }
        // Connection strings for devices are added after device registration
        // Run: az iot hub device-identity connection-string show --hub-name <hub> --device-id WeatherSensor
        {
          name: 'WEATHER_DEVICE_CONNECTION_STRING'
          value: 'REPLACE_AFTER_DEPLOYMENT'
        }
        {
          name: 'CO2_DEVICE_CONNECTION_STRING'
          value: 'REPLACE_AFTER_DEPLOYMENT'
        }
        {
          name: 'DELAY_MS'
          value: '1000'
        }
        {
          name: 'MAX_REQUESTS'
          value: '100'
        }
      ]
    }
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────
output iotHubName string = iotHub.name
output consumerFuncName string = consumerFunc.name
output deviceSimFuncName string = deviceSimFunc.name
output cosmosAccountName string = cosmosAccount.name

output deployInstructions string = '''
After deployment run these commands:

1. Register IoT devices:
   az iot hub device-identity create --hub-name <iotHubName> --device-id WeatherSensor
   az iot hub device-identity create --hub-name <iotHubName> --device-id Co2Sensor

2. Get device connection strings and update Function App settings:
   az iot hub device-identity connection-string show --hub-name <iotHubName> --device-id WeatherSensor
   az iot hub device-identity connection-string show --hub-name <iotHubName> --device-id Co2Sensor

3. Update WEATHER_DEVICE_CONNECTION_STRING and CO2_DEVICE_CONNECTION_STRING in Function App settings

4. Deploy your functions:
   cd consumer-func-js && npm install
   func azure functionapp publish <consumerFuncName>
   
   cd device-func-js && npm install  
   func azure functionapp publish <deviceSimFuncName>
'''
