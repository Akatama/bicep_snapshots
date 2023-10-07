@description('First part of the name of the snapshot resources')
param baseSnapshotName string = 'snapshot'

param location string = 'East US 2'

@description('The Azure ID of the source location/subscription/resource group OS snapshot')
param osSnapshotID string

@description('The Azure IDs of the source location/subscription/resource group Data snapshots')
param dataSnapshotIDs array

var targetSnapshotName = 'target-${baseSnapshotName}'


resource targetSnapshotOSDisk 'Microsoft.Compute/snapshots@2023-01-02' = {
  location: location
  name: '${targetSnapshotName}-OS'
  sku: {
    name: 'Standard_ZRS'
  }
  tags: {
    snapshotTest: 'OS'
    snapshotType: 'target'
  }
  properties: {
    osType: 'Windows'
    creationData: {
      sourceResourceId: osSnapshotID
      createOption: 'CopyStart'
    }
    incremental: true
  } 
}


resource targetSnapshotDataDisks 'Microsoft.Compute/snapshots@2023-01-02' = [for (dataSnapShotID, i) in dataSnapshotIDs : {
  location: location
  name: '${targetSnapshotName}-Data-${i}'
  sku: {
    name: 'Standard_ZRS'
  }
  tags: {
    snapshotTest: 'Data'
    snapshotType: 'target'
  }
  properties: {
    osType: 'Windows'
    creationData: {
      sourceResourceId: dataSnapShotID
      createOption: 'CopyStart'
    }
    incremental: true
  }
}]

output targetOSSnapshotName string = targetSnapshotOSDisk.name

output targetDataSnapshotNames array = [ for i in range (0, length(dataSnapshotIDs)) : targetSnapshotDataDisks[i].name]
