#SharePoint Online PowerShell permissions report

<# This script is a PowerShell script used to generate a SharePoint Online permissions report. 
The report provides information about the users and groups that have permissions to access SharePoint Online sites, lists, and items. 
The script requires a SharePoint Online management shell to run and asks for the admin username and password that have the required permissions to the site collection.

The script consists of two functions: Get-Permissions and Generate-SPOSitePermissionRpt. 
The former is used to get permissions applied to a particular object, such as web, list, or list item, and the latter is used to generate the permissions report for a SharePoint Online site.

The Get-Permissions function uses the SharePoint Client Object Model to determine the type of object and get the permissions assigned to it. 
It then loops through the role assignments and retrieves the member and role definition bindings. Finally, it sends the data to the report file.

The Generate-SPOSitePermissionRpt function uses the SharePoint Client Object Model to get the web, site collection administrators, and all lists from the web. 
It then loops through the lists and calls the Get-Permissions function to get the permissions for each list with unique permission. It also sends the data to the report file.

The script requires the admin to change parameters in lines 171 and 172 according to their requirements. 
The report generated is a CSV- TAB Separated File Header that contains URL, Object, Title, Account, PermissionType, and Permissions. #>
  
#Function to Get Permissions Applied on a particular Object, such as: Web, List
Function Get-Permissions([Microsoft.SharePoint.Client.SecurableObject]$Object)
{
    #Determine the type of the object
    Switch($Object.TypedObject.ToString())
    {
        "Microsoft.SharePoint.Client.Web"  { $ObjectType = "Site" ; $ObjectURL = $Object.URL }
        "Microsoft.SharePoint.Client.ListItem"
        {
            $ObjectType = "List Item"
            #Get the URL of the List Item
            $Object.ParentList.Retrieve("DefaultDisplayFormUrl")
            $Ctx.ExecuteQuery()
            $DefaultDisplayFormUrl = $Object.ParentList.DefaultDisplayFormUrl
            $ObjectURL = $("{0}{1}?ID={2}" -f $Ctx.Web.Url.Replace($Ctx.Web.ServerRelativeUrl,''), $DefaultDisplayFormUrl,$Object.ID)
        }
        Default
        {
            $ObjectType = "List/Library"
            #Get the URL of the List or Library
            $Ctx.Load($Object.RootFolder)
            $Ctx.ExecuteQuery()           
            $ObjectURL = $("{0}{1}" -f $Ctx.Web.Url.Replace($Ctx.Web.ServerRelativeUrl,''), $Object.RootFolder.ServerRelativeUrl)
        }
    }
  
    #Get permissions assigned to the object
    $Ctx.Load($Object.RoleAssignments)
    $Ctx.ExecuteQuery()
  
    Foreach($RoleAssignment in $Object.RoleAssignments)
    {
                $Ctx.Load($RoleAssignment.Member)
                $Ctx.executeQuery()
                  
                #Get the Permissions on the given object
                $Permissions=@()
                $Ctx.Load($RoleAssignment.RoleDefinitionBindings)
                $Ctx.ExecuteQuery()
                Foreach ($RoleDefinition in $RoleAssignment.RoleDefinitionBindings)
                {
                    $Permissions += $RoleDefinition.Name +";"
                }
  
                #Check direct permissions
                if($RoleAssignment.Member.PrincipalType -eq "User")
                {
                        #Send the Data to Report file
                        "$($ObjectURL) `t $($ObjectType) `t $($Object.Title)`t $($RoleAssignment.Member.LoginName) `t User `t $($Permissions)" | Out-File $ReportFile -Append
                }
                  
                ElseIf($RoleAssignment.Member.PrincipalType -eq "SharePointGroup")
                {       
                        #Send the Data to Report file
                        "$($ObjectURL) `t $($ObjectType) `t $($Object.Title)`t $($RoleAssignment.Member.LoginName) `t SharePoint Group `t $($Permissions)" | Out-File $ReportFile -Append
                }
                ElseIf($RoleAssignment.Member.PrincipalType -eq "SecurityGroup")
                {
                    #Send the Data to Report file
                    "$($ObjectURL) `t $($ObjectType) `t $($Object.Title)`t $($RoleAssignment.Member.Title)`t $($Permissions) `t Security Group" | Out-File $ReportFile -Append
                }
    }
}
  
#powershell to get sharepoint online **site** permissions
Function Generate-SPOSitePermissionRpt($SiteURL,$ReportFile)
{
    Try {
        #Get Credentials to connect
        $Cred= Get-Credential
        $Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($Cred.Username, $Cred.Password)
   
        #Setup the context
        $Ctx = New-Object Microsoft.SharePoint.Client.ClientContext($SiteURL)
        $Ctx.Credentials = $Credentials
  
        #Get the Web
        $Web = $Ctx.Web
        $Ctx.Load($Web)
        $Ctx.ExecuteQuery()
  
        #Write CSV- TAB Separated File Header
        "URL `t Object `t Title `t Account `t PermissionType `t Permissions" | out-file $ReportFile
  
        Write-host -f Yellow "Getting Site Collection Administrators..."
        #Get Site Collection Administrators
        $SiteUsers= $Ctx.Web.SiteUsers
        $Ctx.Load($SiteUsers)
        $Ctx.ExecuteQuery()
        $SiteAdmins = $SiteUsers | Where { $_.IsSiteAdmin -eq $true}
  
        ForEach($Admin in $SiteAdmins)
        {
            #Send the Data to report file
            "$($Web.URL) `t Site Collection `t $($Web.Title)`t $($Admin.Title) `t Site Collection Administrator `t  Site Collection Administrator" | Out-File $ReportFile -Append
        }
  
        #Function to Get Permissions of all **lists** from the web
        Function Get-SPOListPermission([Microsoft.SharePoint.Client.Web]$Web)
        {
            #Get All Lists from the web
            $Lists = $Web.Lists
            $Ctx.Load($Lists)
            $Ctx.ExecuteQuery()
  
            #Get all lists from the web  
            ForEach($List in $Lists)
            {
                #Exclude System Lists
                If($List.Hidden -eq $False)
                {
                    #Get the Lists with Unique permission
                    $List.Retrieve("HasUniqueRoleAssignments")
                    $Ctx.ExecuteQuery()
  
                    If( $List.HasUniqueRoleAssignments -eq $True)
                    {
                        #Call the function to check permissions
                        Get-Permissions -Object $List
                    }
                }
            }
        }
  
        #Function to Get Webs's Permissions from given URL
        Function Get-SPOWebPermission([Microsoft.SharePoint.Client.Web]$Web)
        {
            #Get all immediate subsites of the site
            $Ctx.Load($web.Webs) 
            $Ctx.executeQuery()
   
            #Call the function to Get Lists of the web
            Write-host -f Yellow "Getting the Permissions of Web "$Web.URL"..."
  
            #Check if the Web has unique permissions
            $Web.Retrieve("HasUniqueRoleAssignments")
            $Ctx.ExecuteQuery()
  
            #Get the Web's Permissions
            If($web.HasUniqueRoleAssignments -eq $true)
            {
                Get-Permissions -Object $Web
            }
  
            #Scan Lists with Unique Permissions
            Write-host -f Yellow "`t Getting the Permissions of Lists and Libraries in "$Web.URL"..."
            Get-SPOListPermission($Web)
   
            #Iterate through each subsite in the current web
            Foreach ($Subweb in $web.Webs)
            {
                 #Call the function recursively                           
                 Get-SPOWebPermission($SubWeb)
            }
        }
  
        #Call the function with RootWeb to get **site collection** permissions
        Get-SPOWebPermission $Web
  
        Write-host -f Green "Site Permission Report Generated Successfully!"
     }
    Catch {
        write-host -f Red "Error Generating Site Permission Report!" $_.Exception.Message
   }
}
  
#Set parameter values
$SiteURL="https://xxxxxxxx.sharepoint.com/sites/site_collection's_name"
$ReportFile="C:\Users\tnaeh\xxxxxxx.csv"
$BatchSize = 1000
  
#Call the function
Generate-SPOSitePermissionRpt -SiteURL $SiteURL -ReportFile $ReportFile
