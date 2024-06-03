// SET MODULE DATE
param module_metadata object = {
  module_last_updated: '2024-06-02'
  owner: 'miztiik@github'
}

targetScope = 'resourceGroup'

// Parameters
param deploymentParams object
param identity_params object
param key_vault_params object

param sa_params object

param laws_params object

param brand_tags object

param date_now string = utcNow('yyyy-MM-dd')

var create_kv = true
var create_dce = false
var create_dcr = false
var create_vnet = true
var create_vm = false

param tags object = union(brand_tags, { last_deployed: date_now })

@description('Create Identity')
module r_uami 'modules/identity/create_uami.bicep' = {
  name: '${deploymentParams.enterprise_name_suffix}_${deploymentParams.loc_short_code}_${deploymentParams.global_uniqueness}_uami'
  params: {
    deploymentParams: deploymentParams
    identity_params: identity_params
    tags: tags
  }
}

@description('Add Permissions to User Assigned Managed Identity(UAMI)')
module r_add_perms_to_uami 'modules/identity/assign_perms_to_uami.bicep' = {
  name: '${deploymentParams.enterprise_name_suffix}_${deploymentParams.loc_short_code}_${deploymentParams.global_uniqueness}_perms_provider_to_uami'
  params: {
    uami_name_akane: r_uami.outputs.uami_name_akane
  }
  dependsOn: [
    r_uami
  ]
}

@description('Create Alert Action Group')
module r_alert_action_grp 'modules/monitor/create_alert_action_grp.bicep' = {
  name: '${deploymentParams.enterprise_name_suffix}_${deploymentParams.loc_short_code}_${deploymentParams.global_uniqueness}_alert_action_grp'
  params: {
    deploymentParams: deploymentParams
    tags: tags
  }
}

@description('Create Key Vault')
module r_kv 'modules/security/create_key_vault.bicep' = if (create_kv) {
  name: '${deploymentParams.enterprise_name_suffix}_${deploymentParams.loc_short_code}_${deploymentParams.global_uniqueness}_kv'
  params: {
    deploymentParams: deploymentParams
    key_vault_params: key_vault_params
    tags: tags
    uami_name_akane: r_uami.outputs.uami_name_func
  }
}

@description('Create the Log Analytics Workspace')
module r_logAnalyticsWorkspace 'modules/monitor/create_log_analytics_workspace.bicep' = {
  name: '${deploymentParams.enterprise_name_suffix}_${deploymentParams.loc_short_code}_${deploymentParams.global_uniqueness}_la'
  params: {
    deploymentParams: deploymentParams
    laws_params: laws_params
    tags: tags
  }
}

@description('Create Storage Accounts')
module r_sa 'modules/storage/create_storage_account.bicep' = {
  name: '${deploymentParams.enterprise_name_suffix}_${deploymentParams.loc_short_code}_${deploymentParams.global_uniqueness}_sa'
  params: {
    deploymentParams: deploymentParams
    sa_params: sa_params
    tags: tags
    logAnalyticsWorkspaceId: r_logAnalyticsWorkspace.outputs.logAnalyticsPayGWorkspaceId
  }
}

@description('Create Storage Account - Blob container')
module r_blob 'modules/storage/create_blob.bicep' = {
  name: '${deploymentParams.enterprise_name_suffix}_${deploymentParams.loc_short_code}_${deploymentParams.global_uniqueness}_blob'
  params: {
    deploymentParams: deploymentParams
    sa_params: sa_params
    sa_name: r_sa.outputs.sa_name
    misc_sa_name: r_sa.outputs.misc_sa_name
  }
  dependsOn: [
    r_sa
    r_logAnalyticsWorkspace
  ]
}

@description('Create AI Search')
module r_ai_search 'modules/ai_ml/create_ai_search.bicep' = {
  name: '${deploymentParams.enterprise_name_suffix}_${deploymentParams.loc_short_code}_${deploymentParams.global_uniqueness}_ai_search'
  params: {
    deploymentParams: deploymentParams
    uami_name_akane: r_uami.outputs.uami_name_akane
    logAnalyticsPayGWorkspaceId: r_logAnalyticsWorkspace.outputs.logAnalyticsPayGWorkspaceId
    tags: tags
  }
}

@description('Deploy AI Service')
module r_ai_svc 'modules/ai_ml/create_ai_svc.bicep' = {
  name: '${deploymentParams.enterprise_name_suffix}_${deploymentParams.loc_short_code}_${deploymentParams.global_uniqueness}_ai_svc'
  params: {
    deploymentParams: deploymentParams

    logAnalyticsPayGWorkspaceId: r_logAnalyticsWorkspace.outputs.logAnalyticsPayGWorkspaceId
    tags: tags
  }
}

@description('Deploy AI hub')
module r_ai_hub 'modules/ai_ml/create_ai_hub.bicep' = {
  name: '${deploymentParams.enterprise_name_suffix}_${deploymentParams.loc_short_code}_${deploymentParams.global_uniqueness}_ai_hub'
  params: {
    deploymentParams: deploymentParams
    tags: tags

    ai_search_name: r_ai_search.outputs.ai_search_name
    ai_svc_name: r_ai_svc.outputs.ai_svc_name
    sa_name: r_sa.outputs.sa_name
    kv_name: r_kv.outputs.kv_name
    laws_id: r_logAnalyticsWorkspace.outputs.logAnalyticsPayGWorkspaceId
  }
}

//////////////////////////////////////////
// OUTPUTS                              //
//////////////////////////////////////////

output module_metadata object = module_metadata
