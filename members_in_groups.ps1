#Admin Center & Site collection URL
$AdminCenterURL = "https://xxxxxx-admin.sharepoint.com/"
$SiteURL = "https://xxxxxx.sharepoint.com/sites/hdkb"
$CSVPath = "C:\Users\tal\Groups.csv"
 
#Connect to SharePoint Online
Connect-SPOService -url $AdminCenterURL -Credential (Get-Credential)
 
#Get All Groups of a site collection
$Groups = Get-SPOSiteGroup -Site $SiteURL
Write-host "Total Number of Groups Found:"$Groups.Count
 
$GroupsData = @()
ForEach($Group in $Groups)
{
    $GroupsData += New-Object PSObject -Property @{
        'Group Name' = $Group.Title
        'Permissions' = $Group.Roles -join ","
        'Users' =  $Group.Users -join ","
    }
}
#Export the data to CSV
$GroupsData | Export-Csv $CSVPath -NoTypeInformation


