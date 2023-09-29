param virtualMachineName string

param vmSize string

param targetOSDiskName string

param location string = 'East US 2'

param targetOSSnapshotName string

param sourceOSDiskSizeinGB int

param sourceOSDiskSkuName string

param targetDataSnapshotNames array

param targetDataDiskName string

param sourceDataDisksSinzeinGB array

param sourceDataDisksSkuName array

param targetVnetName string

param targetSubnetName string

param targetVNetResourceGroupName string

resource osSnapshot 'Microsoft.Compute/snapshots@2023-04-02' existing = {
  name: targetOSSnapshotName
}

resource dataSnapshots 'Microsoft.Compute/snapshots@2023-04-02' existing = [for dataSnapshotName in targetDataSnapshotNames : {
  name: dataSnapshotName
}]

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' = {
  name: targetSubnetName
}

resource osDisk 'Microsoft.Compute/disks@2023-04-02' = {
  name : targetOSDiskName
  location: location
  sku: {
    name: sourceOSDiskSkuName
  }
  properties: {
    creationData: {
      createOption: 'Copy'
      sourceResourceId: osSnapshot.id
    }
    diskSizeGB: sourceOSDiskSizeinGB
  }
}

resource dataDisks 'Microsoft.Compute/disks@2023-04-02' = [for i in range(0, length(dataSnapshots)) : {
  name : '${targetDataDiskName }-Data-${i}'
  location: location
  sku: {
    name: sourceDataDisksSkuName[i]
  }
  properties: {
    creationData: {
      createOption: 'Copy'
      sourceResourceId: dataSnapshots[i].id
    }
    diskSizeGB: sourceDataDisksSinzeinGB[i]
  }
}]

resource createdVirtualMachine 'Microsoft.Compute/virtualMachines@2023-07-01' = {
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
      dataDisks: [for i in range(0, length(dataDisks)) : {
        createOption: 'Attach'
        lun: i
        managedDisk: {
          id: dataDisks[i].id
        }
      }]
    }
  }
}
