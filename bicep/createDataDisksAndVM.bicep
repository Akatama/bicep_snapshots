@description('Name of the virtual machine that we will create')
param virtualMachineName string

@description('Size of the created virtual machine (usually the same as the one we took a snapshot of)')
param vmSize string

param location string = 'East US 2'

//combine these three into an object
@description('Name of the target location/subscription/resource group OS snapshot')
param osSnapshotName string

@description('Size in GB of the original OS Disk')
param osDiskSizeinGB int

@description('SKU of the original OS disk')
param osDiskSkuName string

// combine these three into an object
@description('Names of the target local/subscription/resource group Data snasphots')
param dataSnapshotNames array

@description('Size in GB of the original data disks')
param dataDisksSizeinGB array

@description('SKU of the original Data disks')
param dataDisksSkuName array

@description('name of the Vnet we will attach our VM to')
param vnetName string

@description('Subnet we will attach our VM to')
param subnetName string

@description('the resource group where the Vnet is located')
param vnetRG string

resource osSnapshot 'Microsoft.Compute/snapshots@2023-01-02' existing = {
  name: osSnapshotName
}

resource dataSnapshots 'Microsoft.Compute/snapshots@2023-01-02' existing = [for dataSnapshotName in dataSnapshotNames : {
  name: dataSnapshotName
}]

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetRG)
}

var selectedSubnetId = first(filter(virtualNetwork.properties.subnets, x => x.name == subnetName)).id

var osDiskName = '${virtualMachineName}-OS'

resource osDisk 'Microsoft.Compute/disks@2023-04-02' = {
  name : osDiskName
  location: location
  sku: {
    name: osDiskSkuName 
  }
  properties: {
    creationData: {
      createOption: 'Copy'
      sourceResourceId: osSnapshot.id
    }
    diskSizeGB: osDiskSizeinGB
  }
}

resource dataDisks 'Microsoft.Compute/disks@2023-04-02' = [for i in range(0, length(dataSnapshotNames)) : {
  name : '${virtualMachineName}-Data-${i}'
  location: location
  sku: {
    name: dataDisksSkuName[i]
  }
  properties: {
    creationData: {
      createOption: 'Copy'
      sourceResourceId: dataSnapshots[i].id
    }
    diskSizeGB: dataDisksSizeinGB[i]
  }
}]

resource nic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name : '${virtualMachineName}-NIC'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: selectedSubnetId
          }
        }
      }
    ]
  }
}

resource createdVirtualMachine 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  dependsOn: [dataDisks]
  name: virtualMachineName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    storageProfile: {
      osDisk: {
        osType: 'Windows'
        diskSizeGB: osDiskSizeinGB
        managedDisk: {
          id: osDisk.id
        }
        createOption: 'Attach'
        name: osDiskName
        
      }
      dataDisks: [for i in range(0, length(dataSnapshotNames)) : {
        createOption: 'Attach'
        diskSizeGB: dataDisksSizeinGB[i]
        name: dataDisks[i].name
        lun: i
        managedDisk: {
          id: dataDisks[i].id
        }
      }]
    }

  }
}
