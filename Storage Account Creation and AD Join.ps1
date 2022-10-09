#Make SURE you have no blank lines in your CSV file. The script will glitch out if you have a superfluous blank line.


#CSV Format should be "storageAccountName","storageAccountResourceGroup","vNetName","vNetResourceGroup","storageAccountRegion","Subscription","privateEndpointSubnet","tag1","tag2","tag3","tag4","tag5","tag6","Application","fileShare"

 

#You will have to already have the AzFilesHybrid module installed for this to work as well.

 

#.\CopyToPSPath.ps1

#Import-Module -Name AzFilesHybrid

 

#Yes, you have to log into both the az cli and the Az powershell module. There is code in here that uses both.

#The user account running this ISE session must be one with Domain Admin rights to your internal AD if your normal user account does not have rights.

#If your normal user account doesn't have the rights to do this (such as if you have independant Admin accounts) you can work around this running the below:
#   Start-Process powershell.exe -Credential “Domain\SuperUser” -ArgumentList “Start-Process powershell_ise.exe -Verb runAs” 



az login

connect-azaccount

 

Add-Content .\storage-sakeys.csv "StorageAccountSub,StorageAccountRG,StorageAccountName,fileShare,storageAccountKey"

 

import-csv .\storageAccountsToCreate.csv | foreach-object {

    $StorageAccountName = $_.storageAccountName

    $StorageAccountRG = $_.storageAccountResourceGroup

    $StorageAccountVNET = $_.vNetName

    $StorageAccountVNETRG = $_.vNetResourceGroup

    $StorageAccountRegion = $_.storageAccountRegion

    $StorageAccountSub = $_.Subscription

    $fileShare = $_.fileShare

    $EncryptionType = "AES256"

    $PrivateEndPointSubnetName = $_.privateEndpointSubnet

    $PrivateEndPointType = "file"   #this can be either file or blob.

    $tag1 = $_.tag1

    $tag2 = $_.tag2

    $tag3 = $_.tag3

    $tag4 = $_.tag4

    $tag5 = $_.tag5

    $tag6 = $_.tag6

    $tag7 = $_.tag7

    $OuDistinguishedName = "OU=AzureStorageAccounts,OU=Storage,DC=xyz,DC=com"

 

    #variables for ACL/rights assignment

    $identity1 = 'xyz\xyz_server_admin'

    $identity2 = 'Creator Owner'

    $rights1 = 'FullControl' #Other options: [enum]::GetValues('System.Security.AccessControl.FileSystemRights')

    $rights2 = 'Read'

    $inheritance = 'ContainerInherit, ObjectInherit' #Other options: [enum]::GetValues('System.Security.AccessControl.Inheritance')

    $propagation = 'None' #Other options: [enum]::GetValues('System.Security.AccessControl.PropagationFlags')

    $type = 'Allow' #Other options: [enum]::GetValues('System.Securit y.AccessControl.AccessControlType')

    $ACE1 = New-Object System.Security.AccessControl.FileSystemAccessRule($identity1,$rights1,$inheritance,$propagation,$type)

    $ACE2 = New-Object System.Security.AccessControl.FileSystemAccessRule($identity2,$rights2,$inheritance,$propagation,$type)


 
    #Setting subscription context in both CLI and PowerShell

    az account set -s $storageaccountsub

    set-azcontext -subscriptionid $storageaccountsub

 

    $OutputText = ""

    Write-Host "Checking VNET . . ."

    $vnet = az network vnet show `

        --name $StorageAccountVNET `

        --resource-group $StorageAccountVNETRG `

        --subscription $StorageAccountSub | ConvertFrom-Json

    $OutputText += $vnet

 

    Write-Host "Update Subnet . . ."

    $subnetUpdate = az network vnet subnet update `

    --name $PrivateEndPointSubnetName `

    --resource-group $StorageAccountVNETRG `

    --subscription $StorageAccountSub `

    --vnet-name $StorageAccountVNET `

    --disable-private-endpoint-network-policies true

    $OutputText += "$subnetUpdate `r`n"

 

    Write-Host "Create Resource Group . . ."

    $rg = az group create `

        --location $StorageAccountRegion `

        --subscription $StorageAccountSub `

        --name $StorageAccountRG `

        --tags tag_1=$tag1 tag_2=$tag2 tag_3=$tag3 tag_4=$tag4 tag_5=$tag5 tag_6=$tag6 tag_7=$tag7

    $OutputText += "$rg  `r`n"

 

    Write-Host "Gathering Subnet Detail Infomation . . ."

    $SAsubnet = az network vnet subnet show `

        --name $PrivateEndPointSubnetName `

        --subscription $StorageAccountSub `

        --resource-group $StorageAccountVNETRG `

        --vnet-name $StorageAccountVNET `

        | ConvertFrom-Json

    $OutputText += "$SAsubnet  `r`n"

 

    Write-Host "Create Storage Account . . ."

    $storageAccount = az storage account create `

        --name "$StorageAccountName" `

        --resource-group "$StorageAccountRG" `

        --allow-blob-public-access false `

        --subscription "$StorageAccountSub" `

        --kind StorageV2 `

        --sku Standard_LRS `

        --enable-large-file-share `

        --publish-internet-endpoints false `

        --default-action deny `

        --min-tls-version TLS1_2 `

        --publish-microsoft-endpoints true `

        | ConvertFrom-Json

    $OutputText += "$storageAccount  `r`n"

 

    Write-Host "Create EndPoint . . ."

    $endPoint = az network private-endpoint create `

        --connection-name "$StorageAccountName-conn" `

        --name "$StorageAccountName--file-ep" `

        --private-connection-resource-id $storageAccount.id `

        --resource-group $StorageAccountRG `

        --subnet $SAsubnet.id `

        --group-id $PrivateEndPointType `

        --location $StorageAccountRegion `

        --subscription $StorageAccountSub `

        | ConvertFrom-Json

    $OutputText += "$endPoint  `r`n"

 

    Write-Host "Add Admin Roles to the new Storage Account . . ."

    $xyzAdmin1 = az ad group show --g XYZ_Server_Admin1_Storage

    $xyzadmin1nj = $xyzadmin1 | ConvertFrom-Json

 

    $roleassign1 = az role assignment create `

        --assignee $xyzAdmin1nj.objectID `

        --role "Storage File Data SMB Share Elevated Contributor" `

        --scope $storageAccount.id `

        | ConvertFrom-Json

    $OutputText += $roleassign1

    [console]::ResetColor()

 

    #The following code is why we have to run the ISE session as an account with AD Domain Admin rights.
 

    Write-Host "Add Storage Account to the AD Group . . ."

    Join-AzStorageAccountForAuth `

        -ResourceGroupName $StorageAccountRG `

        -StorageAccountName $StorageAccountName `

        -OrganizationalUnitDistinguishedName $OuDistinguishedName `

        -EncryptionType $EncryptionType `

        -OverwriteExistingADObject

 

    Update-AzStorageAccountAuthForAES256 -ResourceGroupName $StorageAccountRG -StorageAccountName $StorageAccountName

 

    $SAKeys = Get-AzStorageAccountKey -ResourceGroupName $storageAccountRG -AccountName $storageAccountName

    $storageAccountKey = $SAkeys[0].value


    #The below line is needed to resolve an issue with Kerberos authentication.

    Write-Host "Pausing for 15 minutes prior to file share creation. Some AD sync issue."

    start-sleep -Seconds 900

  

    Write-Host "Create File Share . . ."

    $newFileShare = az storage share create --account-name $storageAccountName --account-key $storageAccountKey --name $fileShare

 

    #Creating RSV for the File Share.
 
    Write-Host "Create Recovery Vault . . ."

    az backup vault create `

        --location $storageAccountRegion `

        --name $storageAccountName-rsv `

        --resource-group $storageAccountRG | ConvertFrom-Json

   

    #Creating Backup Policy for the vault. Change your path to policy.json file as needed, but you must have a policy.json file for this to complete. 
    #Simplest way to get a policy.json file is to create a backup policy on an existing vault and use "az backup policy show", then save the results 
    #as a policy.json file. You can delete any id references in the file.

    Write-Host "Create Backup Policy . . ."

    az backup policy create `

        --backup-management-type AzureStorage `

        --name $storageAccountName-bup `

        --policy .\policy.json `

        --resource-group $storageAccountRG `

        --vault-name $storageAccountName-rsv `

        --workload-type AzureFileShare | ConvertFrom-Json

 
    #Enabling the backup policy for the file share

    Write-Host "Enable Backup for File Share . . ."

    az backup protection enable-for-azurefileshare `

        --azure-file-share $fileShare `

        --policy-name $StorageAccountName-bup `

        --resource-group $storageAccountRG `

        --storage-account $storageAccountName `

        --vault-name $storageAccountName-rsv | ConvertFrom-Json

    $OutputText += "$newFileShare  `r`n"

 
    #Adding ACL permissions to the File Share.

    Write-Host "Add ACL permissions to File Share . . ."

    cmd.exe /C "cmdkey /add:`"$storageAccountName.file.core.windows.net`" /user:`"localhost\$storageAccountName`" /pass:`"$storageAccountKey`""

    New-PSDrive -Name X -PSProvider FileSystem -Root \\$storageAccountName.file.core.windows.net\$fileShare -Persist

    $aclList = get-acl -path X:

    $aclList.AddAccessRule($ACE)

    $aclList.AddAccessRule($ACE2)

    set-acl -path X: -aclobject $aclList

    (get-acl -path X:).access | format-table -autosize

    get-psdrive X | remove-psdrive

 

    $storageAccount_info='{0},{1},{2},{3},{4}' -f $StorageAccountSub,$StorageAccountRG,$StorageAccountName,$fileShare,$storageAccountKey

    write-Output $storageAccount_info | out-file -append -filepath .\storage-sakeys.csv
    
    #We collected the storage account keys so that we could ingest them into our migration program at a later date. No, that's not secure.
    #Yes, that's how we had to do it to make the chosen program for the migrations actually work. I didn't pick the migration tool. I just made it work.

 

    Read-Host -Prompt "Press Enter to continue to the next account, or end the script if there are no more accounts to be created."

}