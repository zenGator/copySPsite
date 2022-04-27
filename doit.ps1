Import-Module sharepointpnppowershellonline
$sourceURL="https://[redacted].sharepoint.com/sites/[source]"
$destURL="https://[redacted].sharepoint.com/sites/[dest]"
$tempFiles=[System.Collections.ArrayList]@()
#$myuid="z***g@[redacted].com"
#$mypass=read-host -Prompt "pwd: " -AsSecureString
#$Credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminUPN, $AdminPassword
Connect-PnPOnline -Url $sourceURL -useweblogin
#Get-PnPListItem -List sitepages
$pages=Get-PnPListItem -List sitepages
#$pages=Get-PnPListItem -List siteassets
#put this next one back
#$pageName = $pages[0].FieldValues["FileLeafRef"]

#Connect-PnPOnline -Url https://contoso.sharepoint.com -Credentials (Get-Credential)
Connect-PnPOnline -Url $sourceURL -UseWebLogin  #-Credentials (Get-Credential)

for ($i=2; $i -lt 5; $i++) { 
    write-host $i $pages[$i].fieldvalues["FileLeafRef"]
    $pageName = $pages[$i].FieldValues["FileLeafRef"]
    $ServerRelativeUrl=(Get-PnPWeb).ServerRelativeUrl
    $file = Get-PnPFile -Url "$ServerRelativeUrl/sitePages/$pageName"
    $tempFile = [System.IO.Path]::GetTempFileName()
    Export-PnPClientSidePage -Force -Identity $pageName -Out $tempFile
    $null=$tempFiles.add($tempFile)
    
    #Connect-PnPOnline -Url $destURL -UseWebLogin
    #Apply-PnPProvisioningTemplate -Path $tempFile
    }
#then set the new Home.aspx as the site homepage
#various graphics are not in place
#also, the News webpart is not in place
$tempFiles

Connect-PnPOnline -Url $destURL -UseWebLogin
for ($i=0; $i -lt $tempFiles.Count; $i++) { 
    write-host $i $tempFiles[$i] "=>" $pages[$i+1].fieldvalues["FileLeafRef"]
    Apply-PnPProvisioningTemplate -Path $tempFiles[$i]
    }
