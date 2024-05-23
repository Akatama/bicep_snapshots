# bicep_snapshots
Bicep code to create a snapshot of all VM disks, then re-create the VM in another resource group, region and subscription
The imagined use case for this would be for disaster recovery, especially if you have VMs that don't meet the requirements for Azure Site Recovery

I don't recommend doing this with Bicep. It was a fun project, but it is much easier with just PowerShell.
There are two main reasons for this:
    1. You cannot create the snapshots in the source region/subscription, then immediately copy them in the same bicep file.
    2. Bicep will not wait for the snapshots to be hydrated before re-creating the disks, so you need to do the waiting in PowerShell or Bash anyway.
Because of this, you cannot truly do this only in Bicep, you must use both Bicep and PowerShell or Bash. 

There are three PowerShell files in this solution.

takeBaseSnapshots.ps1
    This is if you already don't have any snapshots easily avilable. In general, you should aim to keep frequent snapshots of all your disks. If it's for a disaster recovery test, and you have about a day before it, running this script will help you. This is especially good if you have really large disks, as an 8 TB disk snapshot will take around 24 hours to fully hydrate if you don't have any other snapshots.

takeSnapshot.ps1
    This is to take consistent snapshots. The script itself imagines it running once a day, so it names the snapshots and deployments with the date.

takeSnapshotThenCreateVM.ps1
    This takes one last snapshot, then uses it to restore the VM in another resource group, region and subscription.
