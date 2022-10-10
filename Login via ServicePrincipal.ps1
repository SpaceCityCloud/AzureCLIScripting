$applicationId = "xyz";   #Operator-ID
$securePassword = "abc" | ConvertTo-SecureString -AsPlainText -Force   #Operator-Key
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $applicationId, $securePassword
Connect-AzureRmAccount -ServicePrincipal -Credential $credential -TenantId "a-b-c"     #TenantID