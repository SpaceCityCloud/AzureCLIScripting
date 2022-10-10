#Login-AzureRmAccount

#Get-AzureRmSubscription 

#Change the subscription Name! After that you're good to go.
#Select-AzureRmSubscription -SubscriptionName $subscription
$nicName ="xyzNIC"
$vmName = "xyzVM"
$vmSize = "Standard_DS2_v2"
$osDiskName = "dskName"
$location = "East US 2"
$rgName = "rgName"

$nic = Get-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $rgName

$osDiskUri = "https://storageAccountName.blob.core.windows.net/vhds/vmVHDtoUse.vhd"

$vmConfig1 = New-AzureRmVMConfig -VMName $vmName -VMSize $vmSize
$vmConfig2 = Set-AzureRmVMOSDisk -VM $vmConfig1 -Name $vmName -VhdUri $osDiskUri -CreateOption Attach -Windows
$vmConfig3 = Add-AzureRmVMNetworkInterface -VM $vmConfig2 -Id $nic.Id
New-AzureRMVM -ResourceGroupName $rgName -Location $location -VM $vmconfig3 