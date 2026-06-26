#************************************************
#  SCRIPTNAME
#  Author:        Filipe Marques
#  Modified:      Tomé Lopes 
#  Date Created:  22/09/2018
#  Date Modified: 02/05/2025 [wsouza]
#  Description:   This script collects & inspects DPM\MAB\MARS configuration
$Scriptversion = "V17"
#  
#  V17  [wsouza] - When machine has DPM Agentonly, Agent logs are not being collected
#  V16  [wsouza] - Script now looks for a local drive with the most available space instead of default it to the C drive. #
#  V15  [wsouza] - Formatter and validated output text files
#
#  V14  [wsouza]
# - Added DPM UI/CLI capture
# - Formated some generated files
# - Formatter DPM job history
# - Zipped file name now will be <servername>.tar instead of DPM_DATA.zip
#
#  V13  [Mjacquet]
# - fixed Event log collection errors
# - Moved DB collection question and collecting to the very beginning of the script
# - Better visual and logging
# - Better User experience
#
# V12 has some other mods not included in this script
#
# V11
# -Modified logs location to be created on C:\DPM_Data.
#  Once it collects all the data it will zip the folder with name DPM_Data.zip and delete C:\DPM_Data.
#  This zip folder will be on root of the C:\
# -Improved Proxy Colletion.
# -Improved Event Viewer Collection.
# -Added VSS Writers Status.
# -Added Filteres installed and attached.
# -Added Installed Programs.
# -Added msinfo32.
# -Added Temp DPM Folder.
# -Added Temp of CBENGINE
# -Added Registry Information for MARS and DPM
# -Added Tape Info
# -Added Extra Layer for only Online Job History
# -Added DPM DB BAK
#
# 1.0.8 
# -Added DPM Storage output.
# -Verify if there is a missing volume AND IF DPM DB is on recovery model. IF not will not write on the log file.
# -Will collect extra logging related with mount failures. 
# -Microsoft-Windows-Hyper-V-VMM-Storage.evtx
# -Microsoft-Windows-Hyper-V-VMM-Operational.evtx
# -WMI.evtx
# -VHDMP.evtx
#
# 1.0.7 = Added Job History
# 1.0.6 = Added CPU and RAM of Server
# 1.0.5 = Add PG's and Data Sources
# 1.0.4 = Added WMI Registry Queries
# 1.0.3 = Fixed registry queries and added check for ParallelMountDismountLimit
# 1.0.2 = Added REFS PIT UniqueSize -> The time taken for size calculation at StorageManager Level (Time between GetPITUniqueSize call and return)
# 1.0.1 = Original
#
#Requires -RunAsAdministrator
#************************************************

#variables
$driveletter               = (Get-Volume | ? { $_.filesystemtype -in ('ReFS','NTFS') -and $_.DriveType -eq 'Fixed' -and $_.HealthStatus -eq 'Healthy' } | Sort-Object SizeRemaining -Descending)[0].DriveLetter
$progressPreference        = "SilentlyContinue"
$global:localservernamezip = (&hostname) + '.tar'
$global:totalTasks         = 9
$global:currentTask        = 1
$DPMErrorLogs              = ("{0}:\DPM_Data\DPM_Error_Logs" -f $driveletter)
$GetDPMInst                = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup" -Name "InstallPath" -ErrorAction SilentlyContinue
$DPMtempZip                = $GetDPMInst.InstallPath + "Temp\*"
$DPMRegistryLog            = ("{0}:\DPM_Data\DPM_Registry_Info.txt" -f $driveletter)
#Create Path for Work
$PathToDelete              = ("{0}:\DPM_Data" -f $driveletter)
$PathToDeleteUploadMeZip   = ("{0}:\{1}.zip" -f $driveletter, (&hostname))
$PathRoot                  = $PathToDelete
$OutFilePath               = $PathToDelete
$OutFileName               = "DPM_MABS_Analysis_$Scriptversion-log.txt"
$EventViewerLogs           = ("{0}:\DPM_Data\Events" -f $driveletter)

function Show_help
{
    cls
    write-host 
    write-host " Microsoft Customer Support Services (CSS) PowerShell Script Logging Collection" -foregroundcolor green    
    Write-Host " Script Version $Scriptversion" -foregroundcolor green
    write-host   
    write-host " Please read" -foregroundcolor cyan     
    write-host " Once you have created the issue or reproduced the scenario, please run "
    write-host " this script and will collect the required data."     
    write-host " The collected data will be saved as " -NoNewline
    write-host ("{0}:\{1}" -f $driveletter, $localservernamezip) -ForegroundColor Yellow
    write-host " This file is not automatically sent to Microsoft."    
    write-host 
    write-host " Note" -foregroundcolor cyan     
    write-host " The PowerShell Script is designed to collect information that will"
    write-host " help Microsoft Customer Support Services (CSS) troubleshoot an issue"
    write-host " you may be experiencing with:"
    write-host
    write-host "    ■ System Center Data Protection Manager (DPM)"
    write-host "    ■ Microsoft Azure Backup Sever (MABS)"
    write-host "    ■ Microsoft Azure Recovery Services (MARS) agent"   
    write-host   
}  

function getdate
{
    write-host ("{0,22}" -f (Get-date)) -NoNewline -ForegroundColor Yellow
}

function taskprogress
{
    Write-Host (" "*26) "Task $currentTask/$totalTasks completed" -ForegroundColor green
    write-host
    $global:currentTask++
}

function getd
{
    $GetD = get-date -format "hh:mm:tt dd-MM-yyyy"
    ""                    | Out-File $OutFilePath\$OutFileName -Append
    "-------------------" | Out-File $OutFilePath\$OutFileName -Append
    $GetD                 | Out-File $OutFilePath\$OutFileName -Append
    "-------------------" | Out-File $OutFilePath\$OutFileName -Append
    ""                    | Out-File $OutFilePath\$OutFileName -Append
}


show_help
write-host 
 
$null = Read-Host "Press any key to continue or CTRL+C to exit now"


if (test-path $PathRoot)                {Remove-Item -Recurse -Force $PathRoot                | Out-Null}
if (test-path $PathToDeleteUploadMeZip) {Remove-Item -Recurse -Force $PathToDeleteUploadMeZip | Out-Null}
New-Item -ItemType Directory -Force -Path $PathRoot | Out-Null

getd

#region
### Detect installed Backup Products
$servername          = ${Env:ComputerName} 
$OSversion           = (Get-CimInstance Win32_OperatingSystem).Caption
$DetectBackupProduct = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{*"

$DetectBackupProduct | % {
                            If ($_.DisplayName -match "Data Protection Manager") 
                            {
                                $DPMProdName = $_.DisplayName
                                $DPMDetected = $true
                                $totalTasks += 14
                            }
                            If ($_.DisplayName -match "Microsoft Azure Recovery Services Agent") 
                            {
                                $MARSProdName = $_.DisplayName
                                $MARSDetected = $true
                                $totalTasks += 1
                            }
                            If ($_.DisplayName -match "DPM Protection Agent") 
                            {
                                $DPMProdName      = $_.DisplayName
                                $DPMAgentDetected = $true
                                $totalTasks      += 4
                            }
                         }
#endregion


if ($DPMDetected) 
{
    # DataBase Connection 
    $DPMDbKey     = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft Data Protection Manager\DB"
    $DPMDB        = $DPMDbKey.DatabaseName
    $DPMdbServer  = $DPMDbKey.SqlServer
    switch ($DPMDbKey.InstanceName)
    {
        "MSSQLSERVER" { $DPMdbInstance = $DPMdbServer }
        Default       { $DPMdbInstance = $DPMdbServer + "\" + $DPMDbKey.InstanceName }
    }    

    #Ask to backup DPM DB.
    write-host ""
    write-host "Please read!" -ForegroundColor Red
    write-host "DPM Database Backup. This step might fail if DPM DB is hosted on a remote SQL Remote Server."
    write-host "Press " -nonewline
    write-host "Y" -nonewline -foregroundcolor yellow
    $DBBACKUP  = Read-Host " to continue if it is necessary to have database backup or any other key to move forward`nif no database backup is required"

    #DPM DB Backup
    if ($DBBACKUP -imatch "Y")
    {
        getdate
        Write-Host " [x] Backup DPM Database Started" -ForegroundColor White
        $DPMDBBCKPath        = ("{0}:\DPM_Data\DPMDB" -f $driveletter)
        $DPMDBBCKPathZipDest = ("{0}:\DPM_Data\DPMDB.zip" -f $driveletter)
        $BackupFile          = "$DPMDBBCKPath\DPMDB.bak"
        New-Item -ItemType Directory -Force -Path $DPMDBBCKPath | Out-Null
        Backup-SqlDatabase -ServerInstance $DPMdbInstance -Database $DPMDB -BackupFile ($BackupFile)

        Push-Location $PathRoot
        tar -cf dpmdb.tar dpmdb\dpmdb.bak
        Pop-Location


#       Compress-Archive -Path ("$DPMDBBCKPath\DPMDB.bak") -DestinationPath $DPMDBBCKPathZipDest | Out-Null
        Remove-Item -Recurse -Force $DPMDBBCKPath    
        "[x] Backup DPM Database Completed in DPMDB.zip" | Out-File $OutFilePath\$OutFileName -Append
        getdate
        Write-Host " [x] Backup DPM Database Completed" -ForegroundColor White
        Write-Host "Task complete"                      -ForegroundColor green
    }
    ELSE 
    {
        write-host "Continuing without collecting DPM database." 
        write-host      
        "[x] Backup DPM Database Skipped by user" | Out-File $OutFilePath\$OutFileName -Append
        Write-Host "[x] Backup DPM Database Skipped by the user" -ForegroundColor White
    }
}

Write-Host 
Write-Host "Please Standby while we are collecting logs."                                          -foregroundcolor cyan
Write-Host "This might take some time. Data collection will perform a total of $totalTasks tasks." -ForegroundColor White
write-host 

#Get msinfo32
getdate
Get-Process msinfo32 -ErrorAction SilentlyContinue | Stop-Process -ErrorAction SilentlyContinue
Write-Host " [x] MSInfo32 Started. Please wait..." -ForegroundColor White
msinfo32 /nfo ("{0}:\DPM_Data\systeminfo.nfo" -f $driveletter)
while (get-process -name msinfo32 -ErrorAction SilentlyContinue) { sleep 5}
"[x] MSInfo32 Completed in systeminfo.nfo"| Out-File $OutFilePath\$OutFileName -Append
getdate
Write-Host " [x] MSInfo32 Completed" -ForegroundColor White
taskprogress

#region 
### Set log path according to detected product and install directory 
if ($DPMDetected) 
{
    $InstallationPath = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup" -Name "InstallPath" -ErrorAction SilentlyContinue
    $InstallPath = $InstallationPath.InstallPath
}
if ($DPMAgentDetected) 
{
    $InstallationPath = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup" -Name "InstallPath" -ErrorAction SilentlyContinue
    $InstallPath = $InstallationPath.InstallPath
}
if ($MARSDetected) 
{
    $MARSInstallPath = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Azure Backup\Setup" -Name "InstallPath" -ErrorAction SilentlyContinue
    $MARSInstallPath = $MARSInstallPath.InstallPath
}
#endregion

#region 
### Log OS and App version
getdate
Write-Host " [x] DPM_Info_Log OS and Application Versions started" -ForegroundColor White
if ($DPMDetected)      { $DPMProdVersion  = (Get-ChildItem -Path "$InstallPath\bin\MsdpmDll.dll").VersionInfo.ProductVersion }
if ($MARSDetected)     { $MARSProdVersion = (Get-ChildItem -Path "$MARSInstallPath\bin\CBEngine.exe").VersionInfo.ProductVersion }
if ($DPMAgentDetected) { $DPMProdVersion  = (Get-ChildItem -Path "$InstallPath\bin\msdpmPS.dll").VersionInfo.ProductVersion }

# Get CPU Info
$CPUInfo = Get-WmiObject Win32_Processor | Select-Object -Property Name, NumberOfCores, NumberOfLogicalProcessors

# Get RAM
$PhysicalMemory = Get-WmiObject -class "win32_physicalmemory" -namespace "root\CIMV2" 

$DPM_Info_Log = ("{0}:\DPM_Data\DPM_Info.txt" -f $driveletter)

""                                                  | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
"OS & Application Versions"                         | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
"-------------------------"                         | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
"Script Version : $Scriptversion"                   | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
"Hostname.......: $servername"                      | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
"OS version.....: $OSversion"                       | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
"CPU Info.......: $CPUInfo"                         | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
"Total Memory...: $((($PhysicalMemory).Capacity     | Measure-Object -Sum).Sum/1GB) GB" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
"DPM\MAB version: $DPMProdName - $DPMProdVersion"   | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
"MARS version...: $MARSProdName - $MARSProdVersion" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
""                                                  | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
if ($DPMDetected)
{
    "DPM Storage"                                   | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    "-----------"                                   | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    $GetDPMStorage = Get-DPMDiskStorage -volumes    | ft Name,Version,  AccessPath , Tag, TotalSpace, UnoptimizedUsedSpace, OptimizedUsedSpace, Status | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
}
"[x] DPM_Info_Log OS and Application Versions Completed in DPM_Info.txt"| Out-File $OutFilePath\$OutFileName -Append 
getdate
Write-Host " [x] DPM_Info_Log OS and Application Versions Completed" -ForegroundColor White
taskprogress
#endregion


#region
getdate
Write-Host " [x] VSS Writer Log Started" -ForegroundColor White
$VSS_Writers_Log = ("{0}:\DPM_Data\VSS_Info.txt" -f $driveletter)

#Get Writers status
"VSS Writers Status"  | Out-File $VSS_Writers_Log -Append
"------------------"  | Out-File $VSS_Writers_Log -Append
vssadmin list writers | Out-File $VSS_Writers_Log -Append
""                    | Out-File $VSS_Writers_Log -Append

#Get Filters Instaled
"Installed Filters"   | Out-File $VSS_Writers_Log -Append
"-----------------"   | Out-File $VSS_Writers_Log -Append
fltmc filters         | Out-File $VSS_Writers_Log -Append
""                    | Out-File $VSS_Writers_Log -Append

#Get Filters attached
"Attached Filters"    | Out-File $VSS_Writers_Log -Append
"----------------"    | Out-File $VSS_Writers_Log -Append
""                    | Out-File $VSS_Writers_Log -Append
fltmc instances       | Out-File $VSS_Writers_Log -Append

"[x] VSS_Writers_Log Completed in VSS_Info.txt"| Out-File $OutFilePath\$OutFileName -Append
getdate
Write-Host " [x] VSS Writer Log Completed"           -ForegroundColor White
taskprogress

#Get Installed Programs
getdate
Write-Host " [x] InstallProg Started" -ForegroundColor White
$InstallProg = ("{0}:\DPM_Data\Installed_Programs.txt" -f $driveletter)
""                          | Out-File $InstallProg -Append
"Installed Programs"        | Out-File $InstallProg -Append
"------------------"        | Out-File $InstallProg -Append
Get-WmiObject Win32_Product | ft name, version,  vendor, InstallDate -AutoSize | Out-File $InstallProg -Append
"[x] InstallProg Completed in Installed_Programs.txt"| Out-File $OutFilePath\$OutFileName -Append
getdate
Write-Host " [x] InstallProg Completed"              -ForegroundColor White
taskprogress
#endregion

#region ### Last BootTime
getdate
Write-Host " [x] Last Boot Started" -ForegroundColor White
$LastBootTime = Get-CimInstance -ClassName win32_operatingsystem | select csname, lastbootuptime
"Last Boot Time"               | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
"--------------"               | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
"$LastBootTime.lastbootuptime" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
""                             | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000

"[x] Last Boot Completed in DPM_Info.txt"| Out-File $OutFilePath\$OutFileName -Append
getdate
Write-Host " [x] Last Boot Completed"                -ForegroundColor White
taskprogress
#endregion

#region ### List Installed Cumulative updates
getdate
Write-Host " [x] Installed Cumulative updates Started" -ForegroundColor White
$WindowsUpdate   = new-object -com “Microsoft.Update.Searcher"
$AllUpdates      = $WindowsUpdate.GetTotalHistoryCount()
$All             = $WindowsUpdate.QueryHistory(0,$AllUpdates)
$CollectionArray = @{}
$Date            = Get-Date
$All | % {
          $UpdateName = $_.title
          $UpdateTime = $_.Date 
          If ($UpdateName -notmatch "Defender" -and $UpdateName -notmatch "Removal Tool" -and $UpdateTime -gt $Date) {$CollectionArray.add($_.Date, $_.Title)} 
         }
""                             | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
"Installed Cumulative Updates" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
"----------------------------" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
"  Install Date                Update Title" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000

$CollectionArray.GetEnumerator() | Sort-Object -Property Value -Descending | ft -HideTableHeaders | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000

"[x] Installed Cumulative updates Completed in DPM_Info.txt"| Out-File $OutFilePath\$OutFileName -Append
getdate
Write-Host " [x] Installed Cumulative updates Completed" -ForegroundColor White
taskprogress
#endregion


#region
### Proxy configuration
getdate
Write-Host " [x] Proxy Startd" -ForegroundColor White
$CurrentUser01 = Get-ItemProperty -Path Registry::"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings\"
"" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
"" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
"Proxy configuration" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
"-------------------" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
if ($CurrentUser01.ProxyEnable -eq 1) 
{
    $CurrentUserProxy = $CurrentUser01.ProxyServer
    ""                                  | Out-File $DPM_Info_Log -Append
    "Current user has proxy configured" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    "Proxy IP $CurrentUserProxy"        | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    # Check LocalSys proxy config
    $LocalSystem01 = Get-ItemProperty -Path Registry::"HKEY_USERS\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    if ($LocalSystem01.ProxyEnable -eq $null -or $LocalSystem01.ProxyEnable -eq 0 ) 
    {
        ""                                              | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
        "Proxy Not configured for Local System Account" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    }
    Else
    {
        $LocalSystemProxy = $LocalSystem01.ProxyServer
        ""                                          | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
        "Local System Account has proxy configured" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
        "Proxy IP $LocalSystemProxy"                | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    }
    # Double Check LocalSys proxy config
    $LocalSystem02 = Get-ItemProperty -Path Registry::"HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Internet Settings\"   
    if ($LocalSystem02.ProxyEnable -eq $null -or $LocalSystem02.ProxyEnable -eq 0 ) 
    {
        ""                                                           | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
        "Double Check Proxy Not configured for Local System Account" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    }
    Else
    {
        $LocalSystemProxy2 = $LocalSystem02.ProxyServer
        ""                                                       | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
        "Double Check Local System Account has proxy configured" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
        "Proxy IP $LocalSystemProxy2"                            | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    }

    # Check Windowsproxy config
    $Win = "netsh winhttp show proxy"   
    if ($Win.ProxyEnable -eq $null -or $Win.ProxyEnable -eq 0 ) 
    {
        ""                                              | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
        "Proxy Not configured for Local System Account" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    }
    Else
    {
        $LocalSystemProxy3 = $Win.ProxyServer
        ""                             | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
        "Windows has proxy configured" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
        "Proxy IP $LocalSystemProxy3"  | Out-File $DPM_Info_Log  -Append -Encoding ascii -Width 1000
    }
}
Else
{
    ""                                      | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    "Proxy Not configured for current user" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    ""                                      | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
}

"[x] Proxy Completed in DPM_Info.txt"| Out-File $OutFilePath\$OutFileName -Append
getdate
Write-Host " [x] Proxy Completed"                    -ForegroundColor White
taskprogress

#endregion

#region ### Detect Defender & Exclusions
getdate
Write-Host " [x] Defender Detection and Exclusions Started" -ForegroundColor White
$CheckDefender = Get-WindowsFeature Windows-Defender
""                       | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
"Defender Configuration" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
"----------------------" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
If ($CheckDefender.Installed -eq "True") 
{
    $GetDefender = Get-MpPreference -ErrorAction SilentlyContinue
    $DefRMStatus = $GetDefender.DisableRealtimeMonitoring
    If ($DefRMStatus -eq "True") 
    {
        #Write-Host "Defender Realtime Monitoring is currently disabled."
        "Defender Realtime Monitoring is currently disabled." | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    }
    Else
    {
        #Write-Host "Defender Realtime Monitoring is currently enabled."
        "Defender Realtime Monitoring is currently enabled" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    }
    $DefPathExclusions = $GetDefender.ExclusionPath
    $DefProcExclusions = $GetDefender.ExclusionProcess
    ""                           | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    "Path Exclusions:"           | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    $DefPathExclusions | % {"$_" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000}
    ""                           | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    "Process Exclusions:"        | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    $DefProcExclusions | % {"$_" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000}
}
Else
{
    #Write-Host "Defender NOT Installed"
    "Defender NOT Installed"     | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
}

"[x] Defender Detection and Exclusions Completed in DPM_Info.txt"| Out-File $OutFilePath\$OutFileName -Append
getdate
Write-Host " [x] Defender Detection and Exclusions Completed" -ForegroundColor White
taskprogress

#endregion

#region ### Check DPM\MAB services & Accounts 
if ($DPMDetected -or $DPMAgentDetected) 
{
    getdate
    Write-Host " [x] DPM Services Started" -ForegroundColor White
    Get-WmiObject -Query "select * from Win32_Service where name like '%DPM%'" | ft Name, ProcessId, StartMode, State, Status, StartName, ExitCode | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000

    "[x] DPM Services Completed in DPM_Info.txt"| Out-File $OutFilePath\$OutFileName -Append 
    getdate
    Write-Host " [x] DPM Services Completed"             -ForegroundColor White
    taskprogress                                              
}

#endregion


if ($DPMDetected) 
{
    #region ### Check DPM\MAB REFS optimizations  
    getdate
    Write-Host " [x] ReFs Optimizations Check Started" -ForegroundColor White
    # Storage Calculation
    "" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    "Storage Optimizations" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    "---------------------" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    "" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    $StorageCalc = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Configuration\DiskStorage" -Name "DisableReFSStorageComputation" -ErrorAction SilentlyContinue
    $StCalcValue = $StorageCalc.DisableReFSStorageComputation
    if ($StCalcValue -ne 1) {
                             if ($StCalcValue -eq $Null) {$StCalcValue = "NULL"}
                             #Write-Host "Storage Calculation Enabled" -ForegroundColor Red
                             #Write-Host "DisableReFSStorageComputation value set to: $StCalcValue" -ForegroundColor Red
                             "" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                             "Storage Calculation Enabled" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                             "DisableReFSStorageComputation value set to: $StCalcValue" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                 #  Manage-DPMDSStorageSizeUpdate.ps1 -ManageStorageInfo StopSizeAutoUpdate   # run command to disable size calculation
                            }
                            Else 
                            {
                             #Write-Host "Storage Calculation is disabled" -ForegroundColor yellow
                             "" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                             "Storage Calculation disabled" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                            }
    "" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000

    # DuplicateExtentBatchSizeinMB  
    $DuplicateExtentBatchSizeinMB  = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Microsoft Data Protection Manager\Configuration\DiskStorage" -Name "DuplicateExtentBatchSizeinMB" -ErrorAction SilentlyContinue
    $DupExtBatch = $DuplicateExtentBatchSizeinMB.DuplicateExtentBatchSizeinMB
    if (99 -lt $DupExtBatch`
    -or $DupExtBatch -eq $NULL) {
                                 if ($DupExtBatch -eq $Null) {$DupExtBatch = "NULL"}
                                 #Write-Host "DuplicateExtentBatchSize Value not set or higher than recommended value of 100" -ForegroundColor Red
                                 #Write-Host "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running"
                                 "" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                 "DuplicateExtentBatchSize Value not set or higher than recommended value of 100" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                 "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                }
    #Write-Host "DuplicateExtentBatchSize value set to: $DupExtBatch" -ForegroundColor Yellow
    "DuplicateExtentBatchSize value set to: $DupExtBatch" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    "" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000

    ### RefsEnableLargeWorkingSetTrim
    $RefsEnableLargeWorkingSetTrim = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "RefsEnableLargeWorkingSetTrim" -ErrorAction SilentlyContinue
    $RefsEnalLargeWkSet = $RefsEnableLargeWorkingSetTrim.RefsEnableLargeWorkingSetTrim
    if ($RefsEnalLargeWkSet -ne 1 `
    -or $RefsEnalLargeWkSet -eq $NULL) {
                                        if ($RefsEnalLargeWkSet -eq $Null) {$RefsEnalLargeWkSet = "NULL"}
                                        #Write-Host "RefsEnableLargeWorkingSetTrim Value not set" -ForegroundColor Red
                                        #Write-Host "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running"
                                        "RefsEnableLargeWorkingSetTrim Value not set" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                        "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                       }
                                       Else
                                       {
                                        #Write-Host "RefsEnableLargeWorkingSetTrim is configured" -ForegroundColor Green
                                        "RefsEnableLargeWorkingSetTrim is configured" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                   }
    "" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000

    ### RefsDisableCachedPins
    $RefsDisableCachedPins = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "RefsDisableCachedPins" -ErrorAction SilentlyContinue
    $RefsDCaPin = $RefsDisableCachedPins.RefsDisableCachedPins
    if ($RefsDCaPin -ne 1 `
    -or $RefsDCaPin -eq $NULL) {
                                if ($RefsDCaPin -eq $Null) {$RefsDCaPin = "NULL"}
                                #Write-Host "RefsDisableCachedPins Value not set" -ForegroundColor Red
                                #Write-Host "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running"
                                "RefsDisableCachedPins Value not set" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                               }
                               Else
                               {
                                #Write-Host "RefsDisableCachedPins is configured" -ForegroundColor Green
                                "RefsDisableCachedPins is configured" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                               }

    "" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000

    ### RefsEnableInlineTrim
    $RefsEnableInlineTrim = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "RefsEnableInlineTrim" -ErrorAction SilentlyContinue
    $RefsEnalineTrim = $RefsEnableInlineTrim.RefsEnableInlineTrim
    if ($RefsEnalineTrim -ne 1 `
    -or $RefsEnalineTrim -eq $NULL) {
                                     if ($RefsEnalineTrim -eq $Null) {$RefsEnalineTrim = "NULL"}
                                     #Write-Host "RefsEnableInlineTrim Value not set" -ForegroundColor Red
                                     #Write-Host "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running"
                                     "RefsEnableInlineTrim Value not set" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                     "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                    }
                                    Else
                                    {
                                     #Write-Host "RefsEnableInlineTrim is configured" -ForegroundColor Green
                                     "RefsEnableInlineTrim is configured" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                    }
    "" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000

    ### RefsProcessedDeleteQueueEntryCountThreshold 
    $RefsProcDelQueEntCouThresh  = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "RefsProcessedDeleteQueueEntryCountThreshold" -ErrorAction SilentlyContinue
    $RefsPrDelQCouT = $RefsProcDelQueEntCouThresh.RefsProcessedDeleteQueueEntryCountThreshold
    if (2049 -lt $RefsPrDelQCouT`
    -or $RefsPrDelQCouT -eq $NULL) {
                                    if ($RefsPrDelQCouT -eq $Null) {$RefsPrDelQCouT = "NULL"}
                                    #Write-Host "RefsProcessedDeleteQueueEntryCountThreshold Value not set or higher than recommended value of 2048, 1024 or 512" -ForegroundColor Red
                                    #Write-Host "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running"
                                    "RefsProcessedDeleteQueueEntryCountThreshold Value not set or higher than recommended value of 2048, 1024 or 512" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                    "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                    }
                                    Else
                                    {
                                     #Write-Host "RefsProcessedDeleteQueueEntryCountThreshold configurable values are: 2048, 1024 and 512" -ForegroundColor Green
                                     #Write-Host "RefsProcessedDeleteQueueEntryCountThreshold value set to: $RefsPrDelQCouT" -ForegroundColor Yellow
                                     "RefsProcessedDeleteQueueEntryCountThreshold configurable values are: 2048, 1024 and 512" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                     "RefsProcessedDeleteQueueEntryCountThreshold value set to: $RefsPrDelQCouT" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                    }
    "" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000

    ### RefsNumberOfChunksToTrim
    $RefsNumChunTrimArray = (4,8,16,32,64)
    $RefsNumberOfChunksToTrim = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "RefsNumberOfChunksToTrim" -ErrorAction SilentlyContinue
    $RefsEnaChunkTrim = $RefsNumberOfChunksToTrim.RefsNumberOfChunksToTrim
    $ValueFound = $RefsNumChunTrimArray.Contains($RefsEnaChunkTrim)
    if ($ValueFound -ne "True" `
    -or $RefsEnaChunkTrim -eq $NULL) {
                                     if ($RefsEnaChunkTrim -eq $Null) {$RefsEnaChunkTrim = "NULL"}
                                     #Write-Host "RefsNumberOfChunksToTrim Value not set" -ForegroundColor Red
                                     #Write-Host "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running"
                                     "RefsNumberOfChunksToTrim Value not set" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                     "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                    }
                                    Else
                                    {
                                     #Write-Host "RefsNumberOfChunksToTrim configurable values are: 4, 8, 16, 32..." -ForegroundColor Green
                                     #Write-Host "RefsNumberOfChunksToTrim value set to: $RefsEnaChunkTrim" -ForegroundColor Green
                                     "RefsNumberOfChunksToTrim configurable values are: 4, 8, 16, 32..." | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                     "RefsNumberOfChunksToTrim value set to: $RefsEnaChunkTrim" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                    }
    "" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000

    # Disk TimeOutValue  
    $TimeOutValue   = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Disk" -Name "TimeOutValue" -ErrorAction SilentlyContinue
    $TiValue = $TimeOutValue.TimeOutValue
    if ($TiValue -lt 120) {
                                        if ($TiValue -eq $Null) {$TiValue = "NULL"}
                                        #Write-Host "Disk TimeOut Value not set or less than recommended value of 120" -ForegroundColor Red
                                        #Write-Host "Disk TimeOut Value set to: $TiValue" -ForegroundColor Red
                                        #Write-Host "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running"
                                        "Disk TimeOut Value not set or less than recommended value of 120" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                        "Disk TimeOut Value set to: $TiValue" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                        "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                       }
                                       Else
                                       {
                                        #Write-Host "Disk TimeOut set to: $TiValue" -ForegroundColor yellow
                                        "Disk TimeOut set to: $TiValue" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                       }
    "" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000

    # ParallelMountDismountLimit  
    $ParallelMountDismountLimit   = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Configuration" -Name "ParallelMountDismountLimit" -ErrorAction SilentlyContinue
    $ParallelMount = $ParallelMountDismountLimit.ParallelMountDismountLimit
    if ($ParallelMount -eq $NULL) {
                                        if ($ParallelMount -eq $Null) {$ParallelMount = "NULL"}
                                        "ParallelMountDismountLimit Value not set" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                        "ParallelMountDismountLimit set to: $ParallelMount" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                       }
                                       Else
                                       {
                                        #Write-Host "Disk TimeOut set to: $TiValue" -ForegroundColor yellow
                                        "ParallelMountDismountLimit set to: $ParallelMount" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                       }
    "" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000

    # WMICheckCheckClientOb
    $WMICheckClientOb   = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Wbem\CIMOM" -Name "High Threshold On Client Objects (B)" -ErrorAction SilentlyContinue
    $WMICheckClient = $WMICheckClientOb."High Threshold On Client Objects (B)"
    if ($WMICheckClient -eq $NULL) {
                                        if ($WMICheckClient -eq $Null) {$WMICheckClient = "NULL"}
                                        "High Threshold On Client Objects (B) Value not set" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                        "High Threshold On Client Objects (B) set to: $WMICheckClient" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                       }
                                       Else
                                       {
                                        #Write-Host "Disk TimeOut set to: $TiValue" -ForegroundColor yellow
                                        "High Threshold On Client Objects (B) set to: $WMICheckClient" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                    }
    "" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000

    # WMICheckOnEvents
    $WMICheckOnEvents   = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Wbem\CIMOM" -Name "High Threshold On Events (B)" -ErrorAction SilentlyContinue
    $WMICheckOnEv = $WMICheckOnEvents."High Threshold On Events (B)"
    if ($WMICheckOnEv -eq $NULL) {
                                        if ($WMICheckOnEv -eq $Null) {$WMICheckOnEv = "NULL"}
                                        "High Threshold On Events (B) Value not set" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                        "High Threshold On Events (B) set to: $WMICheckOnEv" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                       }
                                       Else
                                       {
                                        #Write-Host "Disk TimeOut set to: $TiValue" -ForegroundColor yellow
                                        "High Threshold On Events (B) set to: $WMICheckOnEv" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
                                       }
    "" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    "[x] ReFs Optimizations Check Completed in DPM_Info.txt"| Out-File $OutFilePath\$OutFileName -Append
    getdate
    Write-Host " [x] ReFs Optimizations Check Completed" -ForegroundColor White
    taskprogress

	#region ### Check REFS PIT TIMES
    getdate
	Write-Host " [x] PIT Time Started" -ForegroundColor White
	$PerfLog = ("{0}:\DPM_Data\PIT_Mount_UnMount_Info.txt" -f $driveletter)
	$logtocheck = $InstallPath+"Temp"
	$MSDPMlogs = Get-ChildItem -Path $logtocheck | ? {$_.Name.StartsWith("MSDPM") -and $_.Name.EndsWith(".errlog")} | Where-Object {$_.LastWriteTime -gt (Get-Date).AddHours(-24)} | Sort-Object -Property LastWriteTime
    if ($MSDPMlogs) 
    {
	    $MSDPMlogsData = @()
	    $MSDPMlogs.FullName | %  {$MSDPMlogsData += Get-Content $_}
	    $StartPIT = "==>CreatePIT\("
	    $EndPIT = "<--CreatePIT"
	    $StartPitsArray = @()
	    $EndPitsArray = @()
	    $LinesWithStartPIT = @()
	    $LinesWithEndPIT = @()
	    $MSDPMlogsData | % {
		    				if ($_ -match $StartPIT) {$LinesWithStartPIT += $_}
			    			if ($_ -match $EndPIT) {$LinesWithEndPIT += $_}
				    	   }
    
    	$LinesWithStartPIT | % {
	    						    $Taskid = ([string]$_).Split("`t")[7] 
		    					    $Day = ([string]$_).Split("`t")[2]
			    				    $Time = ([string]$_).Split("`t")[3]
				    			    $DayTime = "$Day "+ "$Time"
					    		    $DayTime = [datetime]::ParseExact($DayTime,'MM/dd HH:mm:ss.fff',$null)
						    	    $StartPitsArray += New-object PSObject -Property([ordered]@{Taskid = $Taskid; DayTime = $DayTime})
						     }
	    $LinesWithEndPIT | % {
		    					$Taskid = ([string]$_).Split("`t")[7] 
			    				$Day = ([string]$_).Split("`t")[2]
				    			$Time = ([string]$_).Split("`t")[3]
					    		$DayTime = "$Day "+ "$Time"
						    	$DayTime = [datetime]::ParseExact($DayTime,'MM/dd HH:mm:ss.fff',$null)
							    $EndPitsArray += New-object PSObject -Property([ordered]@{Taskid = $Taskid; DayTime = $DayTime})
    						  }

	    $PITstartEndArray = @()
	    $StartPitsArray | % {
		    				    if ($_.TaskId.length -gt 30) 
                                {
                                    $aa = $_.TaskId
					    			$bb = $_.DayTime 
						    		$EndPitsArray | % {
                                                            If ($_.TaskId.length -gt 30 -and $aa -match $_.TaskId) 
                                                            {
                                                                $PITstartEndArray += New-object PSObject -Property([ordered]@{TaskID = $aa; Start = $bb; End = $_.DayTime})
										    				}
										  	    	  }
    				            }
	    					}

    	$PITstartEndDiffArray = @()
	    $PITstartEndArray | % {
		    			    	   $PITTotalTime = New-TimeSpan -Start $_.Start -End $_.End
			    			       $TTimeFormat = "{0:g}" -f $PITTotalTime
				    		       $PITstartEndDiffArray += New-object PSObject -Property([ordered]@{TaskID = $_.TaskId; Start = $_.Start; End = $_.End; TotalTime = $TTimeFormat})
					    	  }

    	$RefsPitTimesResult = $PITstartEndDiffArray | Sort-Object -Property TotalTime -Descending
    	""                                                                         | Out-File $PerfLog -Append
    	"REFS PIT (CLONE) TIMES for last 24hrs (sorted by TotalTime - descending)" | Out-File $PerfLog -Append
    	"---------------------------"                                              | Out-File $PerfLog -Append
    	$RefsPitTimesResult                                                        | Out-File $PerfLog -Append    
    }
    "[x] PIT Time Completed in PIT_Mount_UnMount_Info.txt"                     | Out-File $OutFilePath\$OutFileName -Append
    getdate
	Write-Host " [x] PIT Time Completed"                -ForegroundColor White
    taskprogress
	#endregion

	#region ### Check Mount/Unmount Times
    getdate
	Write-Host " [x] Mount and UnMount Started" -ForegroundColor White
	$StartMount            = "==>MountStorage\("
	$EndMount              = "MountStorage:"
	$StartUnMount          = "==>UnmountStorage\("
	$EndUnMount            = "UnmountStorage:"
	$StartMountArray       = @()
	$StartUnMountArray     = @()
	$EndMountArray         = @()
	$EndUnMountArray       = @()
	$LinesWithStartMount   = @()
	$LinesWithStartUnMount = @()
	$LinesWithEndMount     = @()
	$LinesWithEndUnMount   = @()

	$MSDPMlogsData | % {
						if ($_ -cmatch $StartMount) {$LinesWithStartMount += $_}
						if ($_ -cmatch $EndMount) {$LinesWithEndMount += $_}
						if ($_ -cmatch $StartUnMount) {$LinesWithStartUnMount += $_}
						if ($_ -cmatch $EndUnMount) {$LinesWithEndUnMount += $_}
					   }

	$LinesWithStartMount | % {
							$Taskid = ([string]$_).Split("`t")[7] 
							$Day = ([string]$_).Split("`t")[2]
							$Time = ([string]$_).Split("`t")[3]
							$DayTime = "$Day "+ "$Time"
							$DayTime = [datetime]::ParseExact($DayTime,'MM/dd HH:mm:ss.fff',$null)
							$StartMountArray += New-object PSObject -Property([ordered]@{Taskid = $Taskid; DayTime = $DayTime})
						   }
	$LinesWithStartUnMount | % {
								$Taskid = ([string]$_).Split("`t")[7] 
								$Day = ([string]$_).Split("`t")[2]
								$Time = ([string]$_).Split("`t")[3]
								$DayTime = "$Day "+ "$Time"
								$DayTime = [datetime]::ParseExact($DayTime,'MM/dd HH:mm:ss.fff',$null)
								$StartUnMountArray += New-object PSObject -Property([ordered]@{Taskid = $Taskid; DayTime = $DayTime})
							   }


	$LinesWithEndMount | % {
							$Taskidcrude = ([string]$_).Split("`t")[9] 
							$Taskid = $Taskidcrude.Split()[4]
							$Day = ([string]$_).Split("`t")[2]
							$Time = ([string]$_).Split("`t")[3]
							$DayTime = "$Day "+ "$Time"
							$DayTime = [datetime]::ParseExact($DayTime,'MM/dd HH:mm:ss.fff',$null)
							$EndMountArray += New-object PSObject -Property([ordered]@{Taskid = $Taskid; DayTime = $DayTime})
						   }
	$LinesWithEndUnMount | % {
							  $Taskidcrude = ([string]$_).Split("`t")[9] 
							  $Taskid = $Taskidcrude.Split()[4]
							  $Day = ([string]$_).Split("`t")[2]
							  $Time = ([string]$_).Split("`t")[3]
							  $DayTime = "$Day "+ "$Time"
							  $DayTime = [datetime]::ParseExact($DayTime,'MM/dd HH:mm:ss.fff',$null)
							  $EndUnMountArray += New-object PSObject -Property([ordered]@{Taskid = $Taskid; DayTime = $DayTime})
							 }

	$MountstartEndArray = @()
	$StartMountArray | % {
						 if ($_.TaskId.length -gt 30) {
													   $aa = $_.TaskId
													   $bb = $_.DayTime 
													   $EndMountArray | % {
																		  If ($_.TaskId.length -gt 30 -and $aa -match $_.TaskId) {
																																  $MountstartEndArray += New-object PSObject -Property([ordered]@{TaskID = $aa; Start = $bb; End = $_.DayTime})
																																 }
																		 }
													  }
						}
	$UnMountstartEndArray = @()
	$StartUnMountArray | % {
							if ($_.TaskId.length -gt 30) {
														  $aa = $_.TaskId
														  $bb = $_.DayTime 
														  $EndUnMountArray | % {
																				If ($_.TaskId.length -gt 30 -and $aa -match $_.TaskId) {
																																		$UnMountstartEndArray += New-object PSObject -Property([ordered]@{TaskID = $aa; Start = $bb; End = $_.DayTime})
																																	   }
																			   }
														}
						  }

	$MountstartEndDiffArray = @()
	$MountstartEndArray | % {
							 $MountTotalTime = New-TimeSpan -Start $_.Start -End $_.End
							 $MountTimeFormat = "{0:g}" -f $MountTotalTime
							 $MountstartEndDiffArray += New-object PSObject -Property([ordered]@{TaskType = "Mount";TaskID = $_.TaskId; Start = $_.Start; End = $_.End; TotalTime = $MountTimeFormat})
							}

	$UnMountstartEndArray | % {
							   $UnMountTotalTime = New-TimeSpan -Start $_.Start -End $_.End
							   $UnMountTimeFormat = "{0:g}" -f $UnMountTotalTime
							   $MountstartEndDiffArray += New-object PSObject -Property([ordered]@{TaskType = "UnMount";TaskID = $_.TaskId; Start = $_.Start; End = $_.End; TotalTime = $UnMountTimeFormat})
							  }

	$MountTimesResult = $MountstartEndDiffArray | Sort-Object -Property TotalTime -Descending | ft 
	"" | Out-File $PerfLog -Append
	"Mount\Unmount TIMES for last 24hrs (sorted by TotalTime - Descending)" | Out-File $PerfLog -Append
	"--------------------------------" | Out-File $PerfLog -Append
	$MountTimesResult | Out-File $PerfLog -Append

	"[x] Mount and UnMount Completed in PIT_Mount_UnMount_Info.txt"| Out-File $OutFilePath\$OutFileName -Append
	getdate
    Write-Host " [x] Mount and UnMount Completed"        -ForegroundColor White
    taskprogress
	#endregion

	#region ### Check REFS PIT UniqueSize
    getdate
	Write-Host " [x] ReFs PIT Unique Size Started" -ForegroundColor White
	$logtocheck = $InstallPath+"Temp"
	$MSDPMlogs = Get-ChildItem -Path $logtocheck | ? {$_.Name.StartsWith("MSDPM") -and $_.Name.EndsWith(".errlog")} | Where-Object {$_.LastWriteTime -gt (Get-Date).AddHours(-24)} | Sort-Object -Property LastWriteTime
    if ($MSDPMlogs)
    {
	    $MSDPMlogsData = @()
	    $MSDPMlogs.FullName | %  {$MSDPMlogsData += Get-Content $_}
	    $StartPIT = "==>GetPITUniqueSize"
	    $EndPIT = "<--GetPITUniqueSize"
	    $StartPitsArray = @()
	    $EndPitsArray = @()
	    $LinesWithStartPIT = @()
	    $LinesWithEndPIT = @()
	    $MSDPMlogsData | % {
		    				if ($_ -match $StartPIT) {$LinesWithStartPIT += $_}
			    			if ($_ -match $EndPIT) {$LinesWithEndPIT += $_}
				    	   }

	    $LinesWithStartPIT | % {
		    					$Taskid = ([string]$_).Split("`t")[7] 
			    				$Day = ([string]$_).Split("`t")[2]
				    			$Time = ([string]$_).Split("`t")[3]
					    		$DayTime = "$Day "+ "$Time"
						    	$DayTime = [datetime]::ParseExact($DayTime,'MM/dd HH:mm:ss.fff',$null)
							    $StartPitsArray += New-object PSObject -Property([ordered]@{Taskid = $Taskid; DayTime = $DayTime})
						    }
	    $LinesWithEndPIT | % {
		    					$Taskid = ([string]$_).Split("`t")[7] 
			    				$Day = ([string]$_).Split("`t")[2]
				    			$Time = ([string]$_).Split("`t")[3]
					    		$DayTime = "$Day "+ "$Time"
						    	$DayTime = [datetime]::ParseExact($DayTime,'MM/dd HH:mm:ss.fff',$null)
							    $EndPitsArray += New-object PSObject -Property([ordered]@{Taskid = $Taskid; DayTime = $DayTime})
    						   }

	    $PITstartEndArray = @()
	    $StartPitsArray | % {
		    				 if ($_.TaskId.length -gt 30) {
			    										   $aa = $_.TaskId
				    									   $bb = $_.DayTime 
					    								   $EndPitsArray | % {
						    												  If ($_.TaskId.length -gt 30 -and $aa -match $_.TaskId) {
							    																									  $PITstartEndArray += New-object PSObject -Property([ordered]@{TaskID = $aa; Start = $bb; End = $_.DayTime})
								    																								 }
									    									 }
										    			  }
    						}

    	$PITstartEndDiffArray = @()
	    $PITstartEndArray | % {
		    				   $PITTotalTime = New-TimeSpan -Start $_.Start -End $_.End
			    			   $TTimeFormat = "{0:g}" -f $PITTotalTime
				    		   $PITstartEndDiffArray += New-object PSObject -Property([ordered]@{TaskID = $_.TaskId; Start = $_.Start; End = $_.End; TotalTime = $TTimeFormat})
					    	  }

    	$RefsPitTimesResult = $PITstartEndDiffArray | Sort-Object -Property Totaltime -Descending
    	"" | Out-File $PerfLog -Append
    	"REFS PIT UNIQUESIZE TIMES for last 24hrs (sorted descending)" | Out-File $PerfLog -Append
    	"---------------------------" | Out-File $PerfLog -Append
    	$RefsPitTimesResult | Out-File $PerfLog -Append
    }
	"[x] ReFs PIT Unique Size Completed in PIT_Mount_UnMount_Info.txt"| Out-File $OutFilePath\$OutFileName -Append
    getdate	
    Write-Host " [x] ReFs PIT Unique Size Completed"     -ForegroundColor White
    taskprogress
	#endregion

	#region ### Check DPM\MAB DPMDB 
#	if ($DPMDetected) {

	"SQL Server Name......: $DPMdbServer"   | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
	"DPM DB Name..........: $DPMDB"         | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
    "DPM DB Instance Name.: $DPMdbInstance" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000

	# DPM Update History
	$DPMUpdateHistory = "SELECT [Name],[BuildNumber],[FileName] FROM [$DPMDB].[dbo].[tbl_AM_AgentPatch] where OSType = 2 order by Name desc"
	$DPMHistory = Invoke-Sqlcmd -ServerInstance $DPMdbInstance -Query $DPMUpdateHistory
	"" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
	"DPM Update History" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
	"------------------" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
	$DPMHistory | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000



	#DPMDB DBRecovery State
	$DPMdbRecovery = "SELECT [PropertyName],[PropertyValue] FROM [$DPMDB].[dbo].[tbl_DLS_GlobalSetting]"
	$DPMrecovery = Invoke-Sqlcmd -ServerInstance $DPMdbInstance -Query $DPMdbRecovery

	if ($DPMrecovery[6].PropertyValue -eq 1) {
											  "" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
											  "DPM Database Recovery" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
											  "---------------------" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
											  #Write-Host "DPM Database in Recovery Mode" -ForegroundColor red
											  "DPM Database in Recovery Mode" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
											 }

	# tbl_STM_Volume and disk status 
	$STMVolQuery = "SELECT [AccessPath],[Label],[Status],[Tag],[FileSystem],[DedupMode] FROM [$DPMDB].[dbo].[tbl_STM_Volume]"
	$DPMdisksSQL = Invoke-Sqlcmd -ServerInstance $DPMdbInstance -Query $STMVolQuery
	$DPMdisksSQL | % {
					  If ($_.Status -eq 1 -and $_.Tag -eq 511) {
																$DiskAccess = $_.AccessPath
																$DiskStatus = $_.Label
																"" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
																"DPM Storage Issues" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
																"------------------" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
																#Write-Host "DPM has a failed or missing volume: $DiskAccess $DiskStatus" -ForegroundColor yellow
																"DPM has a failed or missing volume: $DiskAccess $DiskStatus" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
															   }
					 }

	# DPM Garbage recent history
	$DPMGC ="select [TaskID], [JobID], [LastStateName], [StartedDateTime], [StoppedDateTime] from [$DPMDB].[dbo].[tbl_TE_TaskTrail] where VerbID = '282faac6-e3cb-4015-8c6d-4276fcca11d4' order by startedDateTime"
	$DPMGChistory = Invoke-Sqlcmd -ServerInstance $DPMdbInstance -Query $DPMGC
	"" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
	"DPM GC History (Last 5 entries)" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
	"-------------------------------" | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
	$DPMGChistory | Select-Object -Last 5 | ft -AutoSize |  Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
#	}
    
	"[x] DPM DB Check Completed DPM_Info.txt"| Out-File $OutFilePath\$OutFileName -Append 
    getdate
	Write-Host " [x] DPM DB Check Completed" -ForegroundColor White
	taskprogress

	#Gather tape library info
    getdate
	Write-Host " [x] Library Info Completed" -ForegroundColor White
	$DPMLibraryLog = ("{0}:\DPM_Data\DPM_Library_Info.txt" -f $driveletter)
	$dpmLibrary = Get-DPMLibrary -DPMServerName $ServerName

	"**************************************************" | Out-File $DPMLibraryLog -append
	"*          TAPE LIBRARY INFORMATION              *" | Out-File $DPMLibraryLog -append
	"**************************************************" | Out-File $DPMLibraryLog -append
	# We have to check to be sure a tape library is present...
	if ($dpmLibrary)
	{   
		$dpmLibrary | Format-List |  Out-File $DPMLibraryLog -append
		"**************************************************" | Out-File $DPMLibraryLog -append
		"*          TAPE DRIVE INFORMATION                *" | Out-File $DPMLibraryLog -append
		"**************************************************" | Out-File $DPMLibraryLog -append
		$TDobj = New-Object PSObject
			foreach ($TapeLib in $dpmLibrary)
			{
				$TDobj | Add-Member NoteProperty -Force -name "Name" -value $TapeLib.UserFriendlyName
				$TDobj | Add-Member NoteProperty -Force -name "Product ID" -value $TapeLib.ProductId
				$TDobj | Add-Member NoteProperty -Force -name "Serial #" -value $TapeLib.SerialNumber
				$TDobj | Add-Member NoteProperty -Force -name "Tape Drive Enabled?" -value $TapeLib.IsEnabled
				$TDobj | Add-Member NoteProperty -Force -name "Tape Drive offline?" -value $TapeLib.IsOffline
				$TDobj | Out-File $DPMLibraryLog -append -Width 1000
			}
	} else {
		"WARNING: NO TAPE LIBRARIES FOUND" | Out-File $DPMLibraryLog -append
	}

	"[x] Library Info Completed in DPM_Library_Info.txt"| Out-File $OutFilePath\$OutFileName -Append
    getdate
	Write-Host " [x] Library Info Completed" -ForegroundColor White
	taskprogress

	# Get Protection Groups
    getdate
	Write-Host " [x] Protection Groups Info Started" -ForegroundColor White
	$ProtectionGroupsLog = ("{0}:\DPM_Data\Protection_Groups_Info.txt" -f $driveletter)
	"Protection Groups" | Out-File $ProtectionGroupsLog -append
	"-----------------" | Out-File $ProtectionGroupsLog -append
	""                  | Out-File $ProtectionGroupsLog -append
	$PGList = @(Get-ProtectionGroup (&hostname) | Sort-Object name)
			foreach ($pg in $PGList)
			{
				if ($DPMMajorVersion -eq '3') # DPM 2010
				{
				  "Protection Group............: " + $pg.friendlyname     | Out-File $ProtectionGroupsLog -append
				}
				else
				{
				  "Protection Group............: " + $pg.name             | Out-File $ProtectionGroupsLog -append
				  "Protection Method...........: " + $pg.ProtectionMethod | Out-File $ProtectionGroupsLog -append
				  if ($pg.IsDiskShortTerm)
				  {
						"Short-Term Disk Backup time.: " + (Get-DPMPolicySchedule -ProtectionGroup $PG -ShortTerm).ScheduleDescription | Out-File $ProtectionGroupsLog -append
						"Short-Term Disk Retention...: " + (Get-DPMPolicyObjective -ProtectionGroup $pg -ShortTerm).retentionrange.range + " " + (Get-DPMPolicyObjective -ProtectionGroup $pg -ShortTerm).retentionrange.unit | Out-File $ProtectionGroupsLog -append
				  }
				  if ($pg.IsTapeShortTerm)
				  {
						"Short-Term Tape Backup time.: " + (Get-DPMPolicySchedule -ProtectionGroup $PG -ShortTerm).ScheduleDescription | Out-File $ProtectionGroupsLog -append
						"Short-Term Tape Retention...: " + $pg.ArchiveIntent.RetentionPolicy.OnsiteFather.ToString() | Out-File $ProtectionGroupsLog -append
				}
				  if ($pg.IsTapeLongTerm)
				  {
						"Long-Term Backup time Goal 1: " + @((Get-DPMPolicySchedule -ProtectionGroup $pg -LongTerm Tape) | sort-object jobtype -Descending)[0].ScheduleDescription | Out-File $ProtectionGroupsLog -append
						"Long_term Retention Goal 1..: " + $pg.ArchiveIntent.RetentionPolicy.OffsiteFather.ToString() | Out-File $ProtectionGroupsLog -append
						if ($pg.ArchiveIntent.RetentionPolicy.OffsiteGrandfather.Enabled)
						{
							"Long-Term Backup time Goal 2: " + @((Get-DPMPolicySchedule -ProtectionGroup $pg -LongTerm Tape) | sort-object jobtype -Descending)[1].ScheduleDescription | Out-File $ProtectionGroupsLog -append
							"Long_term Retention Goal 2..: " + $pg.ArchiveIntent.RetentionPolicy.OffsiteGrandfather.ToString() | Out-File $ProtectionGroupsLog -append
							if ($pg.ArchiveIntent.RetentionPolicy.OffsiteGreatGrandfather.Enabled)
							{
								"Long-Term Backup time Goal 3: " + @((Get-DPMPolicySchedule -ProtectionGroup $pg -LongTerm Tape) | sort-object jobtype -Descending)[2].ScheduleDescription | Out-File $ProtectionGroupsLog -append
								"Long_term Retention Goal 3..: " + $pg.ArchiveIntent.RetentionPolicy.OffsiteGreatGrandfather.ToString() | Out-File $ProtectionGroupsLog -append
							}
						}
				  }
				  if ($pg.IsCloudLongTerm)
				{
						"Online Backup time..........: " + (Get-DPMPolicySchedule -ProtectionGroup $pg -LongTerm online).scheduledescription | Out-File $ProtectionGroupsLog -append
						if ((Get-DPMPolicyObjective $PG -LongTerm Online).RetentionRangeDaily.range)
						{
							"Daily Retention Range.......: " + (Get-DPMPolicyObjective $PG -LongTerm Online).RetentionRangeDaily.range + " "  + (Get-DPMPolicyObjective $PG -LongTerm Online).RetentionRangeDaily.unit | Out-File $ProtectionGroupsLog -append
						}
						if ((Get-DPMPolicyObjective $PG -LongTerm Online).RetentionRangeWeekly.range)
						{
							"Weekly Retention Range......: " + (Get-DPMPolicyObjective $PG -LongTerm Online).RetentionRangeWeekly.range + " "  + (Get-DPMPolicyObjective $PG -LongTerm Online).RetentionRangeWeekly.unit | Out-File $ProtectionGroupsLog -append
						}
						if ((Get-DPMPolicyObjective $PG -LongTerm Online).RetentionRangeMonthly.range)
						{
							"Monthly Retention Range.....: " + (Get-DPMPolicyObjective $PG -LongTerm Online).RetentionRangeMonthly.range + " "  + (Get-DPMPolicyObjective $PG -LongTerm Online).RetentionRangeMonthly.unit | Out-File $ProtectionGroupsLog -append
						}
						if ((Get-DPMPolicyObjective $PG -LongTerm Online).RetentionRangeYearly.range)
						{
							"Yearly Retention Range......: " + (Get-DPMPolicyObjective $PG -LongTerm Online).RetentionRangeYearly.range + " "  + (Get-DPMPolicyObjective $PG -LongTerm Online).RetentionRangeYearly.unit | Out-File $ProtectionGroupsLog -append
						}
				  }

				  "Performance Optimization....: " + $pg.PerformanceSettings | Out-File $ProtectionGroupsLog -append
				}
				$DSList = @(Get-Datasource $pg | Sort-Object ProductionServerName, name)
				$ComputerName = $DSList[0].ProductionServerName
				"   Computer: " + $ComputerName | Out-File $ProtectionGroupsLog -append
				foreach ($DS in $DSList)
				{
					if ($ds.ProductionServerName -ne $ComputerName)
					{
						$ComputerName = $DS.ProductionServerName
						"   Computer: " + $ComputerName | Out-File $ProtectionGroupsLog -append
					}
					("       type: {0,-20} - Datasource Name: {1}" -f $ds.ObjectType, $ds.DisplayPath ) | Out-File $ProtectionGroupsLog -append
					#("       type: {0,-20} - Datasource Name: {1}" -f $ds.ObjectType, $ds.DisplayPath ) | Out-File $ProtectionGroupsLog -append
					if ($DPMMajorVersion -eq '3') # DPM 2010
					{
					   $ObjectType = $ds.type.name
					}
					else
					{
					   $ObjectType = $ds.ObjectType
					}

					switch ($ObjectType)
					{
						'System Protection' {   $query = "select ComponentName 
														  from tbl_IM_ProtectedObject 
														  where ProtectedInPlan = 1 and 
														  (ComponentName like 'Bare Metal Recovery' or ComponentName like 'System State') and 
														  DataSourceId like '"+ $ds.DatasourceId + "'"
												$DSTypeList = @(Invoke-Sqlcmd -ServerInstance $DPMdbInstance -Database $DPMDB -Query $query)
												foreach ($DSType in $DSTypeList)
												{                                        
													"            " + $DSType.ComponentName | Out-File $ProtectionGroupsLog -append
												}
											}
						'SharePoint Farm'   {   $query = "select ComponentName 
														  from tbl_IM_ProtectedObject 
														  where ProtectedInPlan = 1 and
														  ReferentialDataSourceId like '"+ $ds.DatasourceId + "' order by convert(varchar(max),LogicalPath)"
												$DSTypeList = @(Invoke-Sqlcmd -ServerInstance $DPMdbInstance -Database $DPMDB -Query $query)
												foreach ($DSType in $DSTypeList)
												{                                        
													 "         " + $DSType.ComponentName | Out-File $ProtectionGroupsLog -append
											   }
											}
						'Volume'            {   $query = "select LogicalPath
														  from tbl_IM_ProtectedObject 
														  where ProtectedInPlan = 1 and
														  DataSourceId like '"+ $ds.DatasourceId + "' order by convert(varchar(max),LogicalPath)"
												$DSTypeList = @(Invoke-Sqlcmd -ServerInstance $DPMdbInstance -Database $DPMDB -Query $query)
												Foreach ($DSType in $DSTypeList)
												{
													[xml]$xml = $DSType.LogicalPath
													$type = ($xml.ArrayOfInquiryPathEntryType.InquiryPathEntryType)[-1]
													if ($type.type -eq 'NonRootTargetShare')
													{
														"             Share  - " +  $Type.value | Out-File $ProtectionGroupsLog -append
													}
													else
													{
														"             " + $type.type + " - " + $Type.value | Out-File $ProtectionGroupsLog -append
													}
												}
											}
					}
				}
				"" | Out-File $ProtectionGroupsLog -append
			}

	"[x] Protection Groups Info Completed in Protection_Groups_Info.txt"| Out-File $OutFilePath\$OutFileName -Append
    getdate
	Write-Host " [x] Protection Groups Info Completed" -ForegroundColor White
	taskprogress

	# Ran this query to see the PG's and Data Sources
    getdate
	Write-Host " [x] Query to Get PG's and Data Sources ID's Started" -ForegroundColor White
	$GETDataSources    = "select ag.NetbiosName, ds.DataSourceName, ds.DataSourceId, lr.PhysicalReplicaId, pg.FriendlyName, lr.validity from [$DPMDB].[dbo].[tbl_IM_DataSource] as ds
                          join [$DPMDB].[dbo].[tbl_PRM_LogicalReplica] as lr 
                          on ds.DataSourceId=lr.DataSourceId
                          join [$DPMDB].[dbo].[tbl_AM_Server] as ag
                          on ds.ServerId=ag.ServerId
                          join [$DPMDB].[dbo].[tbl_IM_ProtectedGroup] as pg 
	                      on ds.ProtectedGroupId=pg.ProtectedGroupId and pg.DiskIntentId is not null order by FriendlyName asc"
	$GETDataSourcesCMD = Invoke-Sqlcmd -ServerInstance $DPMdbInstance -Query $GETDataSources
	""                 | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
	"Data Sources"     | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
	"------------"     | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000
	$GETDataSourcesCMD | Select-Object | ft | Out-File $DPM_Info_Log -Append -Encoding ascii -Width 1000

	"[x] Query to Get PG's and Data Sources ID's Completed in DPM_Info.txt"| Out-File $OutFilePath\$OutFileName -Append 
    getdate
	Write-Host " [x] Query to Get PG's and Data Sources ID's Completed" -ForegroundColor White
	taskprogress


	#Getting DPM job history for the last 40 days
	"[x] Job History Started in DPM_Job_History.txt"| Out-File $OutFilePath\$OutFileName -Append
    getdate
	Write-Host " [x] Job History Started" -ForegroundColor White
	$JobHistoryLog = ("{0}:\DPM_Data\DPM_Job_History.txt" -f $driveletter)
	$joblist       = Get-DPMJob -From ((get-date).AddDays(-40))
	$jobs          = @()
	foreach ($job in $joblist)
	{
	   $Tasklist = @($job.TaskList)
	   foreach ($task in $Tasklist)
	   {
			$jobsobject = New-Object PSObject
			Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name CreatedTimeUTC   -Value ([datetime]($task.CreatedTime).ToUniversalTime())
			Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name CreatedTime      -Value ([datetime]($task.CreatedTime))                
			switch ($task.Status)
			{
				'Initialized' {
									Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name starttime   -Value "Not Started"
									Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name endtime     -Value "Not Completed"
									Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name Duration    -Value ("-"*10)
						  }
				'InProgress'  { 
									$ts = ((get-date) - $task.Starttime)
									Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name starttime   -Value ([datetime]($task.Starttime))
									Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name endtime     -Value ("-"*22)
									Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name Duration    -Value ("{0}d {1:D2}h {2:D2}m" -f $ts.Days, $ts.Hours, $ts.Minutes)
						  }
				default       {
									$ts = ($task.endtime - $task.Starttime)
									Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name starttime   -Value ([datetime]($task.Starttime))
									Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name endtime     -Value ([datetime]($task.endtime))
									Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name Duration    -Value ("{0}d {1:D2}h {2:D2}m" -f $ts.Days, $ts.Hours, $ts.Minutes)
						  }
			}
			Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name Datasource           -Value ($task.DatasourcePath)
			Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name ProductionServerName -Value ($task.ProductionServerName)
			switch ($job.JobCategory)
			{
				'Validation'    { Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name jobcategory   -Value "Consistency Check" }
				'ShadowCopy'    { Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name jobcategory   -Value "Recovery Point" }
				'Replication'   { Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name jobcategory   -Value "Recovery Point" }
				Default         { Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name jobcategory   -Value ($job.jobcategory) }
			}        
			Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name WriterId             -Value ($task.TaskInfo.WriterId.Guid)
			Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name Type                 -Value ($task.type)
			Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name status               -Value ($task.status)        
			Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name DatasourceId         -Value ($task.TaskInfo.DatasourceId.Guid) 
			Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name JobId                -Value ($job.JobId)
			Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name TaskId               -Value ($task.TaskId)
			Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name protectiongroupname  -Value ($job.protectiongroupname)
			Add-Member -InputObject $jobsobject -MemberType NoteProperty -Name ErrorInfo            -Value ($task.ErrorInfo)
			$jobs += $jobsobject        
		}
	}
	$jobs  | Sort-Object CreatedTimeUTC -Descending |  ft starttime, endtime, Datasource, ProductionServerName, Jobcategory, Status, JobId, taskid, protectiongroupname, errorinfo  -AutoSize| Out-File $JobHistoryLog -Append -Encoding ascii -Width 1000



	"[x] Job History Completed in DPM_Job_History.txt"| Out-File $OutFilePath\$OutFileName -Append
    getdate
	Write-Host " [x] Job History Completed" -ForegroundColor White
	taskprogress

    #region
    #GET DPM Installation Path
    getdate
    Write-Host " [x] Get DPM Installation Path Started" -ForegroundColor White
    $GetDPMInst.InstallPath | Out-Null

    "[x] Get DPM Installation Path Completed"| Out-File $OutFilePath\$OutFileName -Append
    getdate
    Write-Host " [x] Get DPM Installation Path Completed" -ForegroundColor White
    taskprogress

    #Copy DPM Temp Folder
    getdate
    Write-Host " [x] Copy and Compress DPM Temp folder and DPM UI Started" -ForegroundColor White
    New-Item -ItemType Directory -Force -Path $DPMErrorLogs | Out-Null
    copy $DPMtempZip $DPMErrorLogs

    # Collecting UI errorlogs
    $userlist = dir C:\Users
    $usernumber = 1
    foreach ($user in $userlist)
    {
        $userpath = "C:\Users\" + $user.Name + "\AppData\Roaming\Microsoft"
        if (dir ($userpath + '\dpmui*.errlog') -recurse -ErrorAction SilentlyContinue)
        {
            md ("{0}:\DPM_Data\user{1}" -f $driveletter, $usernumber) | Out-Null
            copy (dir ($userpath + '\dpm*') -Recurse ) ("{0}:\DPM_Data\user{1}" -f $driveletter, $usernumber)
            $usernumber++       
        }               
    }   
	#endregion



    #Collecting DPM logs under windows\temp folder
    if (dir C:\windows\Temp\msdpm*)
    {
        mkdir ("{0}:\DPM_Data\DPM_Windows_temp" -f $driveletter)
        copy c:\windows\temp\msdpm* ("{0}:\DPM_Data\DPM_Windows_temp" -f $driveletter)
    }
    
    $OutputBase= ("{0}:\DPM_Data\DPM_Error_Logs.zip" -f $driveletter)
    Compress-Archive -Path $DPMErrorLogs -DestinationPath $OutputBase | Out-Null
    Remove-Item -Recurse -Force $DPMErrorLogs

    "[x] Copy and Compress DPM Temp folder Completed in DPM_Error_Logs.zip"| Out-File $OutFilePath\$OutFileName -Append
    getdate
    Write-Host " [x] Copy and Compress with DPM Temp Deletion Completed" -ForegroundColor White
    taskprogress
    #endregion
}
#endregion





    # Collecting UI errorlogs
    $userlist = dir C:\Users
    $usernumber = 1
    foreach ($user in $userlist)
    {
        $userpath = "C:\Users\" + $user.Name + "\AppData\Roaming\Microsoft"
        if (dir ($userpath + '\dpmui*.errlog') -recurse -ErrorAction SilentlyContinue)
        {
            md ("{0}:\DPM_Data\user{1}" -f $driveletter, $usernumber) | Out-Null
            copy (dir ($userpath + '\dpm*') -Recurse ) ("{0}:\DPM_Data\user{1}" -f $driveletter, $usernumber)
            $usernumber++       
        }               
    }   
	#endregion



#Collecting DPM Agent logs 
if ($DPMAgentDetected)
{
    getdate
    Write-Host " [x] Copy and Compress DPM Agent folder" -ForegroundColor White
    
    if (dir C:\windows\Temp\msdpm*)
    {
        mkdir ("{0}:\DPM_Data\DPM_Windows_temp" -f $driveletter)
        copy c:\windows\temp\msdpm* ("{0}:\DPM_Data\DPM_Windows_temp" -f $driveletter)
    }
    
    $OutputBase= ("{0}:\DPM_Data\DPM_Error_Logs.zip" -f $driveletter)
    Compress-Archive -Path ($InstallPath +"temp" ) -DestinationPath $OutputBase | Out-Null
    #Remove-Item -Recurse -Force ("{0}:\DPM_Data\DPM_Windows_temp" -f $driveletter)    
    "[x] Copy and Compress DPM Agent folder Completed"| Out-File $OutFilePath\$OutFileName -Append    
    getdate
    write-host " [x] Copy and Compress DPM Agent folder Completed" -ForegroundColor White
    taskprogress
}



#region 
### Event Viewer Colletion
getdate
Write-Host " [x] Event Viewer Collection Started" -ForegroundColor White
#Copy Events to folder Events
New-Item -ItemType Directory -Force -Path $EventViewerLogs | Out-Null
Copy-Item "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-Hyper-V-VMMS-Storage.evtx"       $EventViewerLogs -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-Hyper-V-VMMS-Operational.evtx"   $EventViewerLogs -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-VHDMP-Operational.evtx"          $EventViewerLogs -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-WMI-Activity-Operational.evtx"   $EventViewerLogs -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\System32\Winevt\Logs\CloudBackup.evtx"                                  $EventViewerLogs -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\System32\Winevt\Logs\Application.evtx"                                  $EventViewerLogs -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\System32\Winevt\Logs\DPM Alerts.evtx"                                   $EventViewerLogs -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\System32\Winevt\Logs\System.evtx"                                       $EventViewerLogs -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\System32\Winevt\Logs\Security.evtx"                                     $EventViewerLogs -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\System32\Winevt\Logs\DPM Backup Events.evtx"                            $EventViewerLogs -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-Backup.evtx"                     $EventViewerLogs -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-CAPI2-Operational.evtx"          $EventViewerLogs -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-Deduplication%4Scrubbing.evtx"   $EventViewerLogs -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-Deduplication%4Operational.evtx" $EventViewerLogs -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-Ntfs%4Operational.evtx"          $EventViewerLogs -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-ReFS%4Operational.evtx"          $EventViewerLogs -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-SmbClient-Connectivity.evtx"     $EventViewerLogs -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-SMBClient-Operational.evtx"      $EventViewerLogs -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-SMBServer-Operational.evtx"      $EventViewerLogs -ErrorAction SilentlyContinue
Copy-Item "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-SMBServer-Connectivity.evtx"     $EventViewerLogs -ErrorAction SilentlyContinue

Push-Location $PathRoot
cd $PathRoot
tar -cf events.tar events
Pop-Location

#Compress-Archive -Path $EventViewerLogs -DestinationPath $EventViewerLogsZip | Out-Null
Remove-Item -Recurse -Force $EventViewerLogs

"[x] Event Viewer Colletion completed" | Out-File $OutFilePath\$OutFileName -Append
getdate
Write-Host " [x] Event Viewer Collection Completed" -ForegroundColor White
taskprogress
#endregion


if ($MARSDetected)
{

    #region
    #Get MARS Installation Path
    getdate
    Write-Host " [x] Copy and Compress MARS Temp folder Started" -ForegroundColor White
    $GetMARSInst = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Azure Backup\Setup" -Name "InstallPath"
    $GetMARSInst.InstallPath | Out-Null
    #endregion

    #Copy CBENGINE Temp Folder
    $CBENGINEErrorLogs = ("{0}:\DPM_Data\CBENGINE_Error_Logs" -f $driveletter)
    $CBENGINEtempZip   = $GetMARSInst.InstallPath  + "Temp\*"
    $OutputBaseMARS    = ("{0}:\DPM_Data\CBENGINE_Error_Logs.zip" -f $driveletter)
    New-Item -ItemType Directory -Force -Path $CBENGINEErrorLogs               | Out-Null    
    copy $CBENGINEtempZip $CBENGINEErrorLogs    
    Compress-Archive -Path $CBENGINEErrorLogs -DestinationPath $OutputBaseMARS | Out-Null
    Remove-Item -Recurse -Force $CBENGINEErrorLogs
    "[x] Copy and Compress MARS Temp folder Completed in CBENGINE_Error_Logs.zip"| Out-File $OutFilePath\$OutFileName -Append
    getdate
    Write-Host " [x] Copy and Compress with MARS Temp Deletion Completed" -ForegroundColor White
    taskprogress 
    #endregion

}

#region
#Get Registry Info
getdate
Write-Host " [x] Get Registry Started" -ForegroundColor White
if ($DPMDetected)
{    
    reg.exe export "HKLM\SOFTWARE\Microsoft\Microsoft Data Protection Manager" ($PathRoot + "\DPM_Registry.txt") | Out-Null
 
}
if ($MARSDetected)
{
    reg.exe export "HKLM\SOFTWARE\Microsoft\Windows Azure Backup"  ($PathRoot + "\MARS_Registry.txt") | Out-Null
}
"[X] Get Registry Info Completed in DPM_Registry_Info.txt" | Out-File $OutFilePath\$OutFileName -Append
getdate
Write-Host " [x] Get Registry Completed" -ForegroundColor White
taskprogress
#endregion

#region
#Get online job history
getdate
Write-Host " [x] Online Job History Started" -ForegroundColor White
$OnlineJobHistoryLog = ("{0}:\DPM_Data\OnlineJob_History.txt" -f $driveletter)
# Collecting job history if we found MARS but not DPM/MABS
if (!$DPMDetected -and $MARSDetected)
{
    $jobs = Get-OBJob -Previous 100 | Sort-Object DisplayTime -Descending
    $jobs  | ft    @{label='StartTime';expression={$_.jobstatus.StartTime}},
                   @{label='EndTime';expression={$_.jobstatus.endtime}},
                   @{label='JobType';expression={$_.jobtype}},
                   @{label='JobState';expression={$_.jobstatus.JobState}},
                   @{label='Name';expression={$_.JobStatus.DatasourceStatus.datasource.datasourcename}},
                   @{label='Data Transferred MB';expression={("{0,10:N2}" -f ($_.JobStatus.DatasourceStatus.byteprogress.Progress/1024/1024))}},
                   @{label='DataSourceID';expression={("{0}" -f ($_.JobStatus.DatasourceStatus.datasource.DataSourceId))}},
                   @{label='JobID';expression={("{0}" -f ($_.JobId))}} -autosize | Out-File $OnlineJobHistoryLog -Encoding ascii -Append -Width 1000 
}
if ($DPMDetected -and $MARSDetected)
{
    "This is a MABS/DPM server, please check online jobs under DPM_Jobs_History.txt file" | Out-File $OnlineJobHistoryLog -Append -Width 1000
}
if (!$DPMDetected -and !$MARSDetected)
{
    "No MABS/DPM/MARS found."                                                             | Out-File $OnlineJobHistoryLog -Append -Width 1000
}

"[x] Online Job History Completed in DPM_OnlineJob_History.txt"| Out-File $OutFilePath\$OutFileName -Append
getdate
Write-Host " [x] Online Job History Completed" -ForegroundColor White
taskprogress
#endregion

getd

#CLEAR
Write-Host 
Write-Host "Finishing up by compressing collected data." -ForegroundColor Cyan

#region
#Compressing DPM_DATA
write-host
getdate
Write-Host " [x] Compress of the Logging Collected and Cleaning Started" -ForegroundColor White
"[x] Compress of the Logging Collected and Cleaning Completed"| Out-File $OutFilePath\$OutFileName -Append

Push-Location $PathRoot
cd ($driveletter + ":\")
tar -cf $global:localservernamezip $PathRoot.Split("\")[-1]
Pop-Location


#Compress-Archive -Path $PathRoot -DestinationPath $PathToDeleteUploadMeZip | Out-Null
Remove-Item -Recurse -Force $PathRoot
getdate
Write-Host " [x] Compress of the Logging Collected and Cleaning Completed" -ForegroundColor White
write-host 
write-host " ALL Tasks Completed!"-ForegroundColor green

#endregion

"`n" 
write-host "Logs were collected with Success. Please upload file " -NoNewline 
write-host ("{0}:\{1}" -f $driveletter, $localservernamezip)                       -ForegroundColor Yellow -NoNewline
write-host " to Microsoft workspace created for your case."        -ForegroundColor White