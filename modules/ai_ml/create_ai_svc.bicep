// SET MODULE DATE
param module_metadata object = {
  module_last_updated: '2024-06-02'
  owner: 'miztiik@github'
}

param deploymentParams object
param tags object

param logAnalyticsPayGWorkspaceId string

var __ai_svc_name = replace(
  '${deploymentParams.enterprise_name_suffix}-${deploymentParams.loc_short_code}-ai-svc-${deploymentParams.global_uniqueness}',
  '_',
  '-'
)

resource r_ai_svc 'Microsoft.CognitiveServices/accounts@2022-03-01' = {
  name: __ai_svc_name
  location: deploymentParams.location
  tags: tags
  sku: {
    name: 'S0'
  }
  // kind: 'OpenAI'
  kind: 'AIServices'
  identity: { type: 'SystemAssigned' }
  properties: {
    customSubDomainName: __ai_svc_name
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
    apiProperties: {
      statisticsEnabled: false
    }
  }
}

resource r_ai_deploy_chat_4o 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  name: 'gpt-4o'
  sku: {
    capacity: 10
    name: 'Standard'
  }
  parent: r_ai_svc
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o'
      version: '2024-05-13'
    }
    raiPolicyName: 'Microsoft.Default'
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
}

resource r_ai_deploy_completions 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  name: 'text-embedding-3-small'
  sku: {
    capacity: 10
    name: 'Standard'
  }
  parent: r_ai_svc
  properties: {
    model: {
      format: 'OpenAI'
      name: 'text-embedding-3-small'
      version: '1'
    }
    raiPolicyName: 'Microsoft.Default'
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
}

/*
resource openAIkey 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'azure-openai-key'
  properties: {
    contentType: 'Azure OpenAI Key'
    value: openAIaccount.listKeys().key1
  }
}

*/

// Create Diagnostic Settings
resource r_ai_svc_diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'ai_svc_diag'
  scope: r_ai_svc
  properties: {
    workspaceId: logAnalyticsPayGWorkspaceId
    // logs: [
    //   {
    //     category: 'allLogs'
    //     enabled: true
    //   }
    // ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// OUTPUTS
output module_metadata object = module_metadata

output ai_svc_name string = r_ai_svc.name
output ai_svc_endpoint string = r_ai_svc.properties.endpoint
output ai_svc_id string = r_ai_svc.id
