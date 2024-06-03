// SET MODULE DATE
param module_metadata object = {
  module_last_updated: '2024-06-03'
  owner: 'miztiik@github'
}

param deploymentParams object

param tags object

param laws_id string

param kv_name string
param sa_name string
param ai_search_name string
param ai_svc_name string

// Get reference of SA
resource r_sa_ref 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: sa_name
}

resource r_kv_ref 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: kv_name
}

resource r_ai_svc_ref 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' existing = {
  name: ai_svc_name
}

resource r_ai_search_ref 'Microsoft.Search/searchServices@2024-03-01-preview' existing = {
  name: ai_search_name
}

var __ai_hub_name = replace(
  '${deploymentParams.enterprise_name_suffix}-${deploymentParams.loc_short_code}-council-${deploymentParams.global_uniqueness}',
  '_',
  '-'
)

resource r_ai_hub_insights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${__ai_hub_name}_insights'
  location: deploymentParams.location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    IngestionMode: 'LogAnalytics'
    WorkspaceResourceId: laws_id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource r_ai_hub 'Microsoft.MachineLearningServices/workspaces@2023-10-01' = {
  name: __ai_hub_name
  location: deploymentParams.location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // organization
    friendlyName: 'sage-council'
    description: 'Seek Wisdom'

    // dependent resources
    keyVault: r_kv_ref.id
    storageAccount: r_sa_ref.id
    applicationInsights: r_ai_hub_insights.id
    // containerRegistry: containerRegistryId
  }
  kind: 'hub'
}

var __ai_project_name = 'llm-4-all'
// In ai.azure.com: Azure AI Project
resource r_ai_project 'Microsoft.MachineLearningServices/workspaces@2023-10-01' = {
  name: __ai_project_name
  location: deploymentParams.location
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  kind: 'Project'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: __ai_project_name
    hbiWorkspace: false
    v1LegacyMode: false
    publicNetworkAccess: 'Enabled'
    discoveryUrl: 'https://${deploymentParams.location}.api.azureml.ms/discovery'
    // most properties are not allowed for a project workspace: "Project workspace shouldn't define ..."
    hubResourceId: r_ai_hub.id
  }
}

@description('Connection for Azure OpenAI')
resource r_ai_hub_conn_oai 'Microsoft.MachineLearningServices/workspaces/connections@2023-10-01' = {
  parent: r_ai_hub
  name: '__oai_conn'
  properties: {
    authType: 'ApiKey'
    category: 'AIServices'
    target: r_ai_svc_ref.properties.endpoint
    isSharedToAll: true
    credentials: {
      // key: '${listKeys(r_ai_svc_ref.id, '2021-10-01').key1}'
      key: r_ai_svc_ref.listKeys().key1
    }
    metadata: {
      ApiType: 'Azure'
      ResourceId: r_ai_svc_ref.id
    }
  }
}

@description('Connection for AI Search')
resource r_ai_hub_conn_ai_search 'Microsoft.MachineLearningServices/workspaces/connections@2023-10-01' = {
  parent: r_ai_hub
  name: '__ai_search_conn'
  properties: {
    authType: 'ApiKey'
    category: 'CognitiveSearch'
    target: 'https://${r_ai_search_ref.name}.search.windows.net'

    isSharedToAll: true
    credentials: {
      key: r_ai_search_ref.listAdminKeys().primaryKey
      //clientId: hubmi.properties.clientId
    }
    metadata: {
      ApiType: 'Azure'
      ResourceId: r_ai_search_ref.id
    }
  }
}

// @description('Connection for Storage Account')
// resource r_ai_hub_conn_sa 'Microsoft.MachineLearningServices/workspaces/connections@2023-10-01' = {
//   parent: r_ai_hub
//   name: '__sa_conn'
//   properties: {
//     authType: 'ApiKey'
//     category: 'StorageAccount'
//     target: 'https://${r_ai_search_ref.name}.search.windows.net'

//     isSharedToAll: true
//     credentials: {
//       key: r_ai_search_ref.listAdminKeys().primaryKey
//       //clientId: hubmi.properties.clientId
//     }
//     metadata: {
//       ApiType: 'Azure'
//       ResourceId: r_ai_search_ref.id
//     }
//   }
// }

// OUTPUTS
output module_metadata object = module_metadata

output ai_hub_id string = r_ai_hub.id

// output mlhub_name string = mlHub.name
// output mlproject_name string = mlProject.name

// output openai_endpoint string = openaiEndpoint
