@description('First part of the name of the snapshot resources')
param snapshotName string
param location string
param vmToSnapShot object

var snapshotOSName = '${snapshotName}-OS'
var snapshotDataName = '${snapshotName}-Data'


resource sourceSnapshotOSDisk 'Microsoft.Compute/snapshots@2023-01-02' = {
  location: location
  name: snapshotOSName
  sku: {
    name: 'Standard_ZRS'
  }
  tags: {
    snapshotTest: 'OS'
    snapshotType: 'source'
  }
  properties: {
    osType: 'Windows'
    creationData: {
      sourceUri: vmToSnapShot.properties.storageProfile.osDisk.managedDisk.id
      createOption: 'Copy'
    }
    incremental: true
  } 
}

resource sourceSnapshotDataDisks 'Microsoft.Compute/snapshots@2023-01-02' = [for (dataDisk, i) in vmToSnapShot.properties.storageProfile.dataDisks : {
  location: location
  name: '${snapshotDataName}-${i}'
  sku: {
    name: 'Standard_ZRS'
  }
  tags: {
    snapshotTest: 'Data'
    snapshotType: 'source'
  }
  properties: {
    creationData: {
      sourceUri: dataDisk.managedDisk.id
      createOption: 'Copy'
    }
    incremental: true
  } 
}]


output sourceOSSnapshotID string = sourceSnapshotOSDisk.id

output sourceDataSnapshotIDs array = [ for i in range (0, length(vmToSnapShot.properties.storageProfile.dataDisks)) : sourceSnapshotDataDisks[i].id]
