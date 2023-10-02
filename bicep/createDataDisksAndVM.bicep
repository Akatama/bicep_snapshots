param virtualMachineName string

param vmSize string

param location string = 'East US 2'

param osDiskName string

//combine these three into an object
param osSnapshotName string

param osDiskSizeinGB int

param osDiskSkuName string

// combine these three into an object
param dataSnapshotNames array

param dataDiskName string

param dataDisksSizeinGB array

param dataDisksSkuName array

param targetVnetName string

param targetSubnetName string

param targetVNetResourceGroupName string

resource osSnapshot 'Microsoft.Compute/snapshots@2023-01-02' existing = {
  name: osSnapshotName
}

resource dataSnapshots 'Microsoft.Compute/snapshots@2023-01-02' existing = [for dataSnapshotName in dataSnapshotNames : {
  name: dataSnapshotName
}]

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-02-01' existing = {
  name: targetSubnetName
  scope: resourceGroup(targetVNetResourceGroupName)
}

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
  name : '${dataDiskName}${i}'
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

resource createdVirtualMachine 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  dependsOn: [dataDisks]
  name: virtualMachineName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    networkProfile: {
      networkInterfaceConfigurations: [
        {
          name: 'PrivateIP'
          properties: {
            ipConfigurations: [
              {
                name: 'subnet'
                properties: {
                  subnet: {
                    id: subnet.id
                  }
                }
              }
            ]
          }
        }
      ]
    }
    storageProfile: {
      osDisk: osDisk
      dataDisks: [for i in range(0, length(dataSnapshotNames)) : {
        createOption: 'Attach'
        lun: i
        managedDisk: {
          id: dataDisks[i].id
        }
      }]
    }
  }
}
