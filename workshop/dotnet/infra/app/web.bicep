param name string
param location string = resourceGroup().location
param tags object = {}

@description('The name of the identity')
param identityName string

@description('The name of the Application Insights')
param applicationInsightsName string

@description('Port for Web UI')
param webPort string = '80'

@description('The name of the container apps environment')
param containerAppsEnvironmentName string

@description('The name of the container registry')
param containerRegistryName string

@description('The name of the service')
param serviceName string = 'web'

@description('The name of the image')
param imageName string = ''

@description('Specifies if the resource exists')
param exists bool

@description('The name of the Key Vault')
param keyVaultName string

@description('The name of the Key Vault resource group')
param keyVaultResourceGroupName string = resourceGroup().name

@description('The storage blob endpoint')
param storageBlobEndpoint string

@description('The name of the storage container')
param storageContainerName string

@description('The URI for the backend API')
param apiEndpoint string

@description('An array of service binds')
param serviceBinds array

resource webIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

module webKeyVaultAccess '../core/security/keyvault-access.bicep' = {
  name: 'web-keyvault-access'
  scope: resourceGroup(keyVaultResourceGroupName)
  params: {
    principalId: webIdentity.properties.principalId
    keyVaultName: keyVault.name
  }
}

module app '../core/host/container-app-upsert.bicep' = {
  name: '${serviceName}-container-app'
  dependsOn: [ webKeyVaultAccess ]
  params: {
    name: name
    location: location
    tags: union(tags, { 'azd-service-name': serviceName })
    identityName: webIdentity.name
    imageName: imageName
    exists: exists
    serviceBinds: serviceBinds
    containerAppsEnvironmentName: containerAppsEnvironmentName
    containerRegistryName: containerRegistryName
    env: [
      {
        name: 'AZURE_CLIENT_ID'
        value: webIdentity.properties.clientId
      }
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: !empty(applicationInsightsName) ? applicationInsights.properties.ConnectionString : ''
      }
      {
        name: 'AZURE_KEY_VAULT_ENDPOINT'
        value: keyVault.properties.vaultUri
      }
      {
        name: 'AZURE_STORAGE_BLOB_ENDPOINT'
        value: storageBlobEndpoint
      }
      {
        name: 'AZURE_STORAGE_CONTAINER'
        value: storageContainerName
      }
      {
        name: 'API_URL'
        value: apiEndpoint
      }
      {
        name: 'PORT'
        value: webPort
      }
      {
        name: 'REACT_APP_PROXY_URL'
        value: '/api/chat'
      }
    ]
    targetPort: 80
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  name: applicationInsightsName
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
  scope: resourceGroup(keyVaultResourceGroupName)
}

output SERVICE_WEB_IDENTITY_NAME string = identityName
output SERVICE_WEB_IDENTITY_PRINCIPAL_ID string = webIdentity.properties.principalId
output SERVICE_WEB_IMAGE_NAME string = app.outputs.imageName
output SERVICE_WEB_NAME string = app.outputs.name
output SERVICE_WEB_URI string = app.outputs.uri