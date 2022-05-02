#copySPsite
#20220429:zG
#
#
<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 # This will copy a set of SharePoint pages; e.g., to build new client project from template
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>

[CMDletBinding()]
#param ([Parameter(Mandatory=$true)][string]$inFile)
param ( [Parameter(Mandatory=$true)][string]$sourceName = 'SAQDTemplate',
        [Parameter(Mandatory=$true)][string]$destName,
        #[switch]$overwrite,
        #$dirsToMonitor = @() ,
        #[switch]$debugging ,
        #[int]$skipto = 0,
        #[string]$errors = $pwd.Path +"\"+ 'error_log.txt',
        #[int]$checkinMins
        [switch]$myVerbose
         )

#NB:  if I remember correctly, the param bit above has to come first


# LEGACY:  Import-Module sharepointpnppowershellonline
Import-Module PnP.PowerShell   # we need this to interact with SharePoint
                               # ref: https://pnp.github.io/powershell/cmdlets/Copy-PnPFolder.html

$sourceURL='https://sylint.sharepoint.com/sites/' + $sourceName
$destURL='https://sylint.sharepoint.com/sites/' + $destName


<# test for existence of source & destination URLs
    if either doesn't exist, warn and abort
 #>
$status=try {  #check for destination
    (Invoke-WebRequest -Uri $destURL -UseBasicParsing -DisableKeepAlive -Method Head).statuscode 
    } 
    catch [Net.WebException] {[int]$_.Exception.Response.StatusCode}
if ($status -ne 200) {
    write 'error:  can''t access destination; aborting'
    exit
    }

$status=try {  #check for source
    (Invoke-WebRequest -Uri $sourceURL -UseBasicParsing -DisableKeepAlive -Method Head).statuscode 
    } 
    catch [Net.WebException] {[int]$_.Exception.Response.StatusCode}
if ($status -ne 200) {
    write 'error:  can''t access source; aborting'
    exit
    }


<# we will build a list of the temporary files created from the template (source); 
   these will then be pushed to the destination site
 #>
$tempFiles=[System.Collections.ArrayList]@()

<# this method of building creds to authenticate to SP didn't work very well (at all)
 #$myuid="lw**n@s**t.com"
 #$mypass=read-host -Prompt "pwd: " -AsSecureString
 #$Credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminUPN, $AdminPassword
 #>

# test to see if we are connected where we need to be
# ToDo:  consider wrapping this in try{} because on new PoSh session there will be no connection, this would avoid the error/warning message
$currConn=Get-PnPConnection
if ($currConn.url -ne $sourceURL) {
    write 're-connecting to source'
    Connect-PnPOnline -Url $sourceURL -useweblogin 3> null
    }
$currConn=Get-PnPConnection
if ($currConn.url -ne $sourceURL) {
    write 'We''re having problems establishing a connection to SharePoint.  Try closing this PoSh session and starting anew.'
    write 'It could be a permissions issue.  It could be that you need to authenticate to SharePoint from your browser before using this script.'
    write 'In any case, we''re aborting.  Sorry.'
    exit
    }

#let's see what pages need to be copied
$pages=Get-PnPListItem -List sitepages

<#ToDo: similar process for copying the various icons
    can use same technique of copying to set of temp files 
    with something like: Get-PnPFile -Url $pages[$i].FieldValues["FileRef"] -path U:\ -Filename [tempname] -AsFile
    and then using Add-PnPFolder & Add-PnPFile to push up
    or perhaps, instead, use Copy-PnPFolder
 #>
#$docs=Get-PnPListItem -List Documents


if ($myVerbose) {  #there's other places where we can be more or less verbose; but don't use $verbose in this code; that's a switch in the PnP.Powershell module
    write 'We''ll be copying these pages: '
    $pages.fieldvalues| foreach-object {write-host ([string]$_.ID),$_.FileLeafRef}
    write ('total: ' + $pages.Count)
    #ToDo:  explain that the IDs may not be fully in sequence/complete; consider labeling the column as SP internal id or replacing with our own index
    }

#write 'debugging:  end reached'
#exit 256

# here's the heart of this script
for ($i=0; $i -lt $pages.Count; $i++) { #for each of the sitepages listed above
    
    write-host -NoNewline 'copying '    
    write-host -nonewline $pages[$i].fieldvalues["FileLeafRef"] ' . . . '
        <# fieldvalues["FileLeafRef"] is the page name as it shows in the SitePages list
           fieldvalues["Title"] is shown in the default list display
           this is one of those places we could be less verbose
         #>

    $pageName = $pages[$i].FieldValues["FileLeafRef"]  #as noted above, this is the page's filename (typically "[blah].aspx"
    $ServerRelativeUrl=(Get-PnPWeb).ServerRelativeUrl
    $file = Get-PnPFile -Url "$ServerRelativeUrl/sitePages/$pageName"  #get the sitepage
    $tempFile = [System.IO.Path]::GetTempFileName()    #here we assign a name for the tempfile
    
    #LEGACY: Export-PnPClientSidePage -Force -Identity $pageName -Out $tempFile
    Export-PnPPage -Force -Identity $pageName -Out $tempFile  #save the sitepage as tempfile
    
    $null=$tempFiles.add($tempFile)   #pop onto our list of temp files
    write-host 'done'   # a little feedback for the UX
    }

#ToDo:  see if the the News webpart is in place

if ($myVerbose) {
    write-host "These are the temporary files which will be copied over to ${destName}:"
    $tempFiles  #list them out for UX
    }

Connect-PnPOnline -Url $destURL -UseWebLogin 3> $null  # now we need to connect to the destination
<#test to see that we've connected successfully
 #>
$currConn=Get-PnPConnection
if ($currConn.url -ne $desturl) {
    write 'We''re having problems establishing a connection to SharePoint.  Try closing this PoSh session and starting anew.'
    write 'It could be a permissions issue.  It could be that you need to authenticate to SharePoint from your browser before using this script.'
    write 'This is unexpected because we were able to connect to the source.'
    write 'In any case, we''re aborting.  Sorry.'
    exit
    }

<#ToDo:  consider testing to see that the number of tempfiles is equal to the # of sitepages 
 #>
for ($i=0; $i -lt $tempFiles.Count; $i++) { #for each of the temp files
    write-host ($i+1) $tempFiles[$i] "=>" $pages[$i].fieldvalues["FileLeafRef"]  #again, some feedback for the UX
    #LEGACY:  Apply-PnPProvisioningTemplate -Path $tempFiles[$i]
    Invoke-PnPSiteTemplate -Path $tempFiles[$i]
    }

write-host "Template copy of $sourceName pages to $destName is complete."
write-host "Next step:  copy items in icons&such to $destName and enjoy your new project."
#ToDo:  see if copying icons&such to the new location might make the graphics auto-magically appear; if so, the above line is unnecessary
write-host 'Also, you will want to point the links in Overall-Status.aspx to the local/project pages instead of the template.'
write-host 'Finally, make sure the spreadsheet section of each Requirements page references the spreadsheet in the client''s project OneDrive, and not the Template.'
