param virtualMachineName string

param vmSize string

param location string = 'East US 2'

//combine these three into an object
param osSnapshotName string

param osDiskSizeinGB int

param osDiskSkuName string

// combine these three into an object
param dataSnapshotNames array

param dataDisksSizeinGB array

param dataDisksSkuName array

param vnetName string

param subnetName string

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
