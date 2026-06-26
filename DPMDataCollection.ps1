#************************************************
#  SCRIPTNAME
#  Author:        Filipe Marques
#  Modified:      Tomé Lopes 
#  Date Created:  22/09/2018
#  Date Modified: 29/01/2022
#  Description:   This script collects & inspects DPM\MAB\MARS configuration
#  2.0
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

#CLEAR
#CLS

$progressPreference = "SilentlyContinue"

function Show_help
{
    cls
        write-host ""
        write-host " Microsoft Customer Support Services (CSS) PowerShell Script Logging Collection" -foregroundcolor green
        write-host " Design for Microsof Data Protection And Microsoft Azure Backup Server Log Colletion" -foregroundcolor green
        write-host ""  
        write-host " Please read" -foregroundcolor cyan     
        write-host " Once you have created the issue or reproduced the scenario, please run this script and will collect the required data."
        write-host " The collected data will be saved to the root of the C:\ of your server with name DPM_DATA.zip."
        write-host " This folder and its contents are not automatically sent to Microsoft."
        write-host " You can upload the DPM_DATA.zip to your secure workspace DPM_Data.zip."
        write-host ""
        write-host " Note" -foregroundcolor cyan     
        write-host " The PowerShell Script is designed to collect information that will help Microsoft Customer Support Services (CSS)"
        write-host " troubleshoot an issue you may be experiencing with Windows."   
        write-host ""  
}  

show_help
write-host ""
write-host -NoNewline "Press any key to continue."
$null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown");
 
        #$Y=Read-Host "Press Y to continue"
        #write-host $line -foregroundcolor white
        #$line = $line + $Y
        #$line >> $logfile
        #if ($Y -NotMatch "Y") 
        #{
        #write-host "Wrong Key.. Exiting.."         
        #Exit 0
        #}



#Create Path for Work
$PathToDelete = "C:\DPM_Data"
$PathToDeleteUploadMeZip = "C:\DPM_DATA.zip"
Remove-Item -Recurse -Force $PathToDelete | Out-Null
Remove-Item -Recurse -Force $PathToDeleteUploadMeZip | Out-Null
New-Item -ItemType Directory -Force -Path "c:\DPM_Data\" | Out-Null
$PathRoot = "C:\DPM_Data"
$OutFilePath = $PathRoot
$OutFileName = "DPM_MABS_Analysis_V11.txt"
Write-Host ""
Write-Host "Please Standby while we are collecting the information." -foregroundcolor cyan
Write-Host "This might take some time.." -ForegroundColor White
Write-Host "There is Tasks 24 to complete" -ForegroundColor White

$GetD = get-date -format "hh:mm:tt dd-MM-yyyy"
" " | Out-File $OutFilePath\$OutFileName #-Append
"-------------------" | Out-File $OutFilePath\$OutFileName -Append
$GetD | Out-File $OutFilePath\$OutFileName -Append
"-------------------" | Out-File $OutFilePath\$OutFileName -Append
"" | Out-File $OutFilePath\$OutFileName -Append

#Get msinfo32
msinfo32 /nfo "C:\DPM_Data\systeminfo.nfo"
"[x] MSInfo32 Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "[x] MSInfo32 Completed" -ForegroundColor White
Write-Host "Tasks 1/24 to complete" -ForegroundColor cyan

#CLEAR
CLS
Write-Host ""
Write-Host "Please Standby while we are collecting the information.." -ForegroundColor cyan
Write-Host "This might take some time.." -ForegroundColor White
Write-Host "Tasks 24 to complete" -ForegroundColor White
Write-Host ""
Write-Host "[x] MSInfo32 Completed" -ForegroundColor White
Write-Host "Tasks 1/24 to complete" -ForegroundColor cyan

#region
### Detect installed Backup Products

$servername = ${Env:ComputerName} 
$OSversion = (Get-CimInstance Win32_OperatingSystem).Caption

$DetectBackupProduct = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{*"
$DetectBackupProduct | % {
                          If ($_.DisplayName -match "Data Protection Manager") {
                                                                                $DPMProdName = $_.DisplayName
                                                                                $DPMDetected = 1
                                                                               }
                          If ($_.DisplayName -match "Microsoft Azure Recovery Services Agent") {
                                                                                                $MARSProdName = $_.DisplayName
                                                                                                $MARSDetected = 1
                                                                                               }
                         }

#endregion

#region 
### Set log path according to detected product and install directory 
if ($DPMDetected -eq 0 -and $MARSDetected -eq 1) {
                                                  $InstallationPath = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Azure Backup\Setup" -Name "InstallPath" -ErrorAction SilentlyContinue
                                                  $InstallPath = $InstallationPath.InstallPath
                                                 }
if ($DPMDetected -eq 1) {
                         $InstallationPath = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup" -Name "InstallPath" -ErrorAction SilentlyContinue
                         $InstallPath = $InstallationPath.InstallPath
                        }
if ($MARSDetected -eq 1) {
                          $MARSInstallPath = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Azure Backup\Setup" -Name "InstallPath" -ErrorAction SilentlyContinue
                          $MARSInstallPath = $MARSInstallPath.InstallPath
                         }
#endregion

#region 
### Log OS and App version
if ($DPMDetected -eq 1) { $DPMProdVersion = Get-ChildItem -Path "$InstallPath\bin\MsdpmDll.dll"
                          $DPMProdVersion = $DPMProdVersion.VersionInfo.ProductVersion
                        }
if ($MARSDetected -eq 1) { $MARSProdVersion = Get-ChildItem -Path "$MARSInstallPath\bin\CBEngine.exe"
                           $MARSProdVersion = $MARSProdVersion.VersionInfo.ProductVersion
                         }

# Get CPU Info
$CPUInfo = Get-WmiObject Win32_Processor | Select-Object -Property Name, NumberOfCores, NumberOfLogicalProcessors

# Get RAM
$PysicalMemory = Get-WmiObject -class "win32_physicalmemory" -namespace "root\CIMV2" 

$DPM_Info_Log = "C:\DPM_Data\DPM_Info.txt"

"" | Out-File $DPM_Info_Log -Append
"OS & Application Versions" | Out-File $DPM_Info_Log -Append
"-------------------------" | Out-File $DPM_Info_Log -Append
"Script Version : $Version" | Out-File $DPM_Info_Log -Append
"Hostname       : $servername" | Out-File $DPM_Info_Log -Append
"OS version     : $OSversion" | Out-File $DPM_Info_Log -Append
"CPU Info       : $CPUInfo" | Out-File $DPM_Info_Log -Append
"Total Memory   : $((($PysicalMemory).Capacity | Measure-Object -Sum).Sum/1GB)GB" | Out-File $DPM_Info_Log -Append
"DPM\MAB version: $DPMProdName - $DPMProdVersion" | Out-File $DPM_Info_Log -Append
"MARS version   : $MARSProdName - $MARSProdVersion" | Out-File $DPM_Info_Log -Append
"" | Out-File $DPM_Info_Log -Append
"DPM Storage Below" | Out-File $DPM_Info_Log -Append
"-------------------------" | Out-File $DPM_Info_Log -Append
$GetDPMStorage = Get-DPMDiskStorage -volumes | Out-File $DPM_Info_Log -Append

"[x] DPM_Info_Log OS & Application Versions Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host ""
Write-Host "[x] DPM_Info_Log OS & Application Versions Completed" -ForegroundColor White
Write-Host "Tasks 24 to complete" -ForegroundColor cyan
#endregion

#CLEAR
CLS
Write-Host "" 
Write-Host "Please Standby while we are collecting the information.." -ForegroundColor cyan
Write-Host "This might take some time.." -ForegroundColor White
Write-Host "Tasks 24 to complete" -ForegroundColor White
Write-Host ""
Write-Host "[x] MSInfo32 Completed" -ForegroundColor White
Write-Host "Tasks 1/24 to complete" -ForegroundColor cyan
Write-Host ""
Write-Host "[x] DPM_Info_Log OS & Application Versions Completed" -ForegroundColor White
Write-Host "Tasks 2/24 to complete" -ForegroundColor cyan

#region
$VSS_Writers_Log = "C:\DPM_Data\VSS_Info.txt"

#Get Writers status
"VSS Writers Status" | Out-File $VSS_Writers_Log -Append
"-------------------------" | Out-File $VSS_Writers_Log -Append
vssadmin list writers | Out-File $VSS_Writers_Log -Append
"" | Out-File $VSS_Writers_Log -Append

#Get Filters Instaled
"Installed Filters" | Out-File $VSS_Writers_Log -Append
"-------------------------" | Out-File $VSS_Writers_Log -Append
fltmc filters | Out-File $VSS_Writers_Log -Append
"" | Out-File $VSS_Writers_Log -Append

#Get Filters attached
"Attached Filters" | Out-File $VSS_Writers_Log -Append
"-------------------------" | Out-File $VSS_Writers_Log -Append
"" | Out-File $VSS_Writers_Log -Append
fltmc instances | Out-File $VSS_Writers_Log -Append

"[x] VSS_Writers_Log Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] VSS Writer Log Completed" -ForegroundColor White
Write-Host "Tasks 3/24 to complete" -ForegroundColor White

#Get Installed Programs
$InstallProg = "C:\DPM_Data\Installed_Programs.txt"
"" | Out-File $InstallProg -Append
"Installed Progragms" | Out-File $InstallProg -Append
"-------------------------" | Out-File $InstallProg -Append
Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Format-Table –AutoSize | Out-File $InstallProg -Append

"[x] InstallProg Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] InstallProg Completed" -ForegroundColor White
Write-Host "Tasks 4/24 to complete" -ForegroundColor cyan

#endregion

#region ### Last BootTime
$LastBootTime = Get-CimInstance -ClassName win32_operatingsystem | select csname, lastbootuptime
"Last Boot Time" | Out-File $DPM_Info_Log -Append
"--------------" | Out-File $DPM_Info_Log -Append
"$LastBootTime.lastbootuptime" | Out-File $DPM_Info_Log -Append
""| Out-File $DPM_Info_Log -Append

"[x] Last Boot Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] Last Boot Completed" -ForegroundColor White
Write-Host "Tasks 5/24 to complete" -ForegroundColor cyan
#endregion

#region ### List Installed Cumulative updates
$WindowsUpdate = new-object -com “Microsoft.Update.Searcher”
$AllUpdates = $WindowsUpdate.GetTotalHistoryCount()
$All = $WindowsUpdate.QueryHistory(0,$AllUpdates)
$CollectionArray = @{}
$Date = Get-Date
$All | % {
          $UpdateName = $_.title
          $UpdateTime = $_.Date 
          If ($UpdateName -notmatch "Defender" -and $UpdateName -notmatch "Removal Tool" -and $UpdateTime -gt $Date) {$CollectionArray.add($_.Date, $_.Title)} 
         }
""| Out-File $DPM_Info_Log -Append
"Installed Cumulative Updates" | Out-File $DPM_Info_Log -Append
"----------------------------" | Out-File $DPM_Info_Log -Append
"  Install Date                Update Title" | Out-File $DPM_Info_Log -Append
#$CollectionArray.GetEnumerator() | Sort-Object -Property Value -Descending
$CollectionArray.GetEnumerator() | Sort-Object -Property Value -Descending | ft -HideTableHeaders | Out-File $DPM_Info_Log -Append

"[x] Installed Cumulative updates Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] Installed Cumulative updates Completed" -ForegroundColor White
Write-Host "Tasks 6/24 to complete" -ForegroundColor cyan
#endregion


#region
### Proxy configuration
$CurrentUser01 = Get-ItemProperty -Path Registry::”HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings\"
"" | Out-File $DPM_Info_Log -Append
"" | Out-File $DPM_Info_Log -Append
"Proxy configuration" | Out-File $DPM_Info_Log -Append
"-------------------" | Out-File $DPM_Info_Log -Append
if ($CurrentUser01.ProxyEnable -eq 1) {
                                       $CurrentUserProxy = $CurrentUser01.ProxyServer
                                       ""| Out-File $DPM_Info_Log -Append
                                       "Current user has proxy configured" | Out-File $DPM_Info_Log -Append
                                       "Proxy IP $CurrentUserProxy" | Out-File $DPM_Info_Log -Append
                                       # Check LocalSys proxy config
                                       $LocalSystem01 = Get-ItemProperty -Path Registry::”HKEY_USERS\S-1-5-18\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
                                       if ($LocalSystem01.ProxyEnable -eq $null -or $LocalSystem01.ProxyEnable -eq 0 ) {
                                                                                                                        ""| Out-File $DPM_Info_Log -Append
                                                                                                                        "Proxy Not configured for Local System Account" | Out-File $DPM_Info_Log -Append
                                                                                                                       }
                                                                                                                       Else
                                                                                                                       {
                                                                                                                        $LocalSystemProxy = $LocalSystem01.ProxyServer
                                                                                                                        ""| Out-File $DPM_Info_Log -Append
                                                                                                                        "Local System Account has proxy configured" | Out-File $DPM_Info_Log -Append
                                                                                                                        "Proxy IP $LocalSystemProxy" | Out-File $DPM_Info_Log -Append
                                                                                                                       }
                                       # Double Check LocalSys proxy config
                                       $LocalSystem02 = Get-ItemProperty -Path Registry::”HKEY_USERS\.DEFAULT\Software\Microsoft\Windows\CurrentVersion\Internet Settings\"   
                                       if ($LocalSystem02.ProxyEnable -eq $null -or $LocalSystem02.ProxyEnable -eq 0 ) {
                                                                                                                        ""| Out-File $DPM_Info_Log -Append
                                                                                                                        "Double Check Proxy Not configured for Local System Account" | Out-File $DPM_Info_Log -Append
                                                                                                                       }
                                                                                                                       Else
                                                                                                                       {
                                                                                                                        $LocalSystemProxy2 = $LocalSystem02.ProxyServer
                                                                                                                        ""| Out-File $DPM_Info_Log -Append
                                                                                                                        "Double Check Local System Account has proxy configured" | Out-File $DPM_Info_Log -Append
                                                                                                                        "Proxy IP $LocalSystemProxy2" | Out-File $DPM_Info_Log -Append
                                                                                                                       }

                                       # Check Windowsproxy config
                                       $Win = "netsh winhttp show proxy"   
                                       if ($Win.ProxyEnable -eq $null -or $Win.ProxyEnable -eq 0 ) {
                                                                                                                        ""| Out-File $DPM_Info_Log -Append
                                                                                                                        "Proxy Not configured for Local System Account" | Out-File $DPM_Info_Log -Append
                                                                                                                       }
                                                                                                                       Else
                                                                                                                       {
                                                                                                                        $LocalSystemProxy3 = $Win.ProxyServer
                                                                                                                        ""| Out-File $DPM_Info_Log -Append
                                                                                                                        "Windows has proxy configured" | Out-File $DPM_Info_Log -Append
                                                                                                                        "Proxy IP $LocalSystemProxy3" | Out-File $DPM_Info_Log -Append
                                                                                                                       }
                                      }
                                      Else
                                      {
                                      ""| Out-File $DPM_Info_Log -Append
                                       "Proxy Not configured for current user" | Out-File $DPM_Info_Log -Append
                                       "" | Out-File $DPM_Info_Log -Append
                                      }

"[x] Proxy Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] Proxy Completed" -ForegroundColor White
Write-Host "Tasks 7/24 to complete" -ForegroundColor cyan

#endregion

#region ### Detect Defender & Exclusions
$CheckDefender = Get-WindowsFeature Windows-Defender
"" | Out-File $DPM_Info_Log -Append
"Defender Configuration" | Out-File $DPM_Info_Log -Append
"----------------------" | Out-File $DPM_Info_Log -Append
If ($CheckDefender.Installed -eq "True") {
                                          $GetDefender = Get-MpPreference -ErrorAction SilentlyContinue
                                          $DefRMStatus = $GetDefender.DisableRealtimeMonitoring
                                          If ($DefRMStatus -eq "True") {
                                                                        #Write-Host "Defender Realtime Monitoring is currently disabled."
                                                                        "Defender Realtime Monitoring is currently disabled." | Out-File $DPM_Info_Log -Append
                                                                       }
                                                                       Else
                                                                       {
                                                                        #Write-Host "Defender Realtime Monitoring is currently enabled."
                                                                        "Defender Realtime Monitoring is currently enabled" | Out-File $DPM_Info_Log -Append
                                                                       }
                                          $DefPathExclusions = $GetDefender.ExclusionPath
                                          $DefProcExclusions = $GetDefender.ExclusionProcess
                                          "" | Out-File $DPM_Info_Log -Append
                                          "Path Exclusions:" | Out-File $DPM_Info_Log -Append
                                          $DefPathExclusions | % {"$_" | Out-File $DPM_Info_Log -Append}
                                          "" | Out-File $DPM_Info_Log -Append
                                          "Process Exclusions:" | Out-File $DPM_Info_Log -Append
                                          $DefProcExclusions | % {"$_" | Out-File $DPM_Info_Log -Append}
                                          }
                                          Else
                                          {
                                           #Write-Host "Defender NOT Installed"
                                           "Defender NOT Installed" | Out-File $DPM_Info_Log -Append
                                          }

"[x] Defender Detection and Exclusions Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] Defender Detection and Exclusions Completed" -ForegroundColor White
Write-Host "Tasks 8/24 to complete" -ForegroundColor cyan

#endregion

#region ### Check DPM\MAB services & Accounts 
if ($DPMDetected -eq 1 ) {

# Netlogon
$GetNetlgon = Get-WmiObject win32_service -Filter "Name Like 'Netlogon'"
$NetlogonStartMode = $GetNetlgon.StartMode
    if ($NetlogonStartMode -notmatch "Auto" ){
                                                Write-Host "Netlogon Service not in Automatic Startup" -ForegroundColor Red
                                                "Netlogon Service not in Automatic Startup" | Out-File $DPM_Info_Log -Append
                                               }
# MSDPM
$GetMSDPM = Get-WmiObject win32_service -Filter "Name Like 'MSDPM'"
$MSDPMStartMode = $GetMSDPM.StartMode
$MSDPMLogAcc = $GetMSDPM.StartName
    if ($MSDPMStartMode -notmatch "Manual" ){
                                             Write-Host "DPM Service not in Manual Startup" -ForegroundColor Red
                                             "DPM Service not in Manual Startup" | Out-File $DPM_Info_Log -Append
                                            }
    if ($MSDPMLogAcc -notmatch "LocalSystem" ){
                                               Write-Host "DPM Service not running with LocalSystem" -ForegroundColor Yellow
                                               "DPM Service not running with LocalSystem" | Out-File $DPM_Info_Log -Append
                                              }
# DPMAM
$DPMAMService = Get-WmiObject win32_service -Filter "Name Like 'DPMAMService'"
$DPMAMState = $DPMAMService.State
$DPMAMStartMode = $DPMAMService.StartMode
$DPMAMLogAcc = $DPMAMService.StartName
    if ($DPMAMState -notmatch "Running" ){
                                              Write-Host "DPMAMService Service not Running" -ForegroundColor Red
                                              "DPMAMService Service not Running" | Out-File $DPM_Info_Log -Append
                                             }
    if ($DPMAMStartMode -notmatch "Auto" ){
                                                Write-Host "DPMAMService Service not in Automatic Startup" -ForegroundColor Red
                                                "DPMAMService Service not in Automatic Startup" | Out-File $DPM_Info_Log -Append
                                               }
    if ($DPMAMLogAcc -notmatch "LocalSystem" ){
                                               Write-Host "DPMAMService Service not running with LocalSystem" -ForegroundColor Yellow
                                               "DPMAMService Service not running with LocalSystem" | Out-File $DPM_Info_Log -Append
                                              }
# DPM Writer
$DpmWriter = Get-WmiObject win32_service -Filter "Name Like 'DpmWriter'"
$DpmWriterState = $DpmWriter.State
$DpmWriterStartMode = $DpmWriter.StartMode
$DpmWriterLogAcc = $DpmWriter.StartName
    if ($DpmWriterState -notmatch "Running" ){
                                              Write-Host "DPM Writer Service not Running" -ForegroundColor Red
                                              "DPM Writer Service not Running" | Out-File $DPM_Info_Log -Append
                                             }
    if ($DpmWriterStartMode -notmatch "Auto" ){
                                               Write-Host "DPM Writer Service not in Automatic Startup" -ForegroundColor Red
                                               "DPM Writer Service not in Automatic Startup" | Out-File $DPM_Info_Log -Append
                                              }
    if ($DpmWriterLogAcc -notmatch "LocalSystem" ){
                                                   Write-Host "DPM Writer Service not running with LocalSystem" -ForegroundColor Yellow
                                                   "DPM Writer Service not running with LocalSystem" | Out-File $DPM_Info_Log -Append
                                                  }
# DPMLA
$DPMLA = Get-WmiObject win32_service -Filter "Name Like 'DPMLA'"
$DPMLAStartMode = $DPMLA.StartMode
$DPMLALogAcc = $DPMLA.StartName
    if ($DPMLAStartMode -notmatch "Manual" ){
                                             Write-Host "DPMLA Service not in Manual Startup" -ForegroundColor Red
                                             "DPMLA Service not in Manual Startup" | Out-File $DPM_Info_Log -Append
                                            }
    if ($DPMLALogAcc -notmatch "LocalSystem" ){
                                               Write-Host "DPMLA Service not running with LocalSystem" -ForegroundColor Yellow
                                               "DPMLA Service not running with LocalSystem" | Out-File $DPM_Info_Log -Append
                                              }
# DPMRA
$DPMRA = Get-WmiObject win32_service -Filter "Name Like 'DPMRA'"
$DPMRAStartMode = $DPMRA.StartMode
$DPMRALogAcc = $DPMRA.StartName
    if ($DPMRAStartMode -notmatch "Manual" ){
                                             #Write-Host "DPMRA Service not in Manual Startup" -ForegroundColor Red
                                             "DPMRA Service not in Manual Startup" | Out-File $DPM_Info_Log -Append
                                            }
    if ($DPMRALogAcc -notmatch "LocalSystem" ){
                                               Write-Host "DPMRA Service not running with LocalSystem" -ForegroundColor Yellow
                                               "DPMRA Service not running with LocalSystem" | Out-File $DPM_Info_Log -Append
                                               }
"[x] DPM Services Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] DPM Services Completed" -ForegroundColor White
Write-Host "Tasks 9/24 to complete" -ForegroundColor cyan
                                              
}

#endregion

#region ### Check DPM\MAB REFS optimizations  
if ($DPMDetected -eq 1 ) {

# Storage Calculation
"" | Out-File $DPM_Info_Log -Append
"Storage Optimizations" | Out-File $DPM_Info_Log -Append
"---------------------" | Out-File $DPM_Info_Log -Append
"" | Out-File $DPM_Info_Log -Append
$StorageCalc = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Configuration\DiskStorage" -Name "DisableReFSStorageComputation" -ErrorAction SilentlyContinue
$StCalcValue = $StorageCalc.DisableReFSStorageComputation
if ($StCalcValue -ne 1) {
                         if ($StCalcValue -eq $Null) {$StCalcValue = "NULL"}
                         #Write-Host "Storage Calculation Enabled" -ForegroundColor Red
                         #Write-Host "DisableReFSStorageComputation value set to: $StCalcValue" -ForegroundColor Red
                         "" | Out-File $DPM_Info_Log -Append
                         "Storage Calculation Enabled" | Out-File $DPM_Info_Log -Append
                         "DisableReFSStorageComputation value set to: $StCalcValue" | Out-File $DPM_Info_Log -Append
                             #  Manage-DPMDSStorageSizeUpdate.ps1 -ManageStorageInfo StopSizeAutoUpdate   # run command to disable size calculation
                        }
                        Else 
                        {
                         #Write-Host "Storage Calculation is disabled" -ForegroundColor yellow
                         "" | Out-File $DPM_Info_Log -Append
                         "Storage Calculation disabled" | Out-File $DPM_Info_Log -Append
                        }
"" | Out-File $DPM_Info_Log -Append

# DuplicateExtentBatchSizeinMB  
$DuplicateExtentBatchSizeinMB  = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\Software\Microsoft\Microsoft Data Protection Manager\Configuration\DiskStorage" -Name "DuplicateExtentBatchSizeinMB" -ErrorAction SilentlyContinue
$DupExtBatch = $DuplicateExtentBatchSizeinMB.DuplicateExtentBatchSizeinMB
if (99 -lt $DupExtBatch`
-or $DupExtBatch -eq $NULL) {
                             if ($DupExtBatch -eq $Null) {$DupExtBatch = "NULL"}
                             #Write-Host "DuplicateExtentBatchSize Value not set or higher than recommended value of 100" -ForegroundColor Red
                             #Write-Host "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running"
                             "" | Out-File $DPM_Info_Log -Append
                             "DuplicateExtentBatchSize Value not set or higher than recommended value of 100" | Out-File $DPM_Info_Log -Append
                             "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running" | Out-File $DPM_Info_Log -Append
                            }
#Write-Host "DuplicateExtentBatchSize value set to: $DupExtBatch" -ForegroundColor Yellow
"DuplicateExtentBatchSize value set to: $DupExtBatch" | Out-File $DPM_Info_Log -Append
"" | Out-File $DPM_Info_Log -Append

### RefsEnableLargeWorkingSetTrim
$RefsEnableLargeWorkingSetTrim = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "RefsEnableLargeWorkingSetTrim" -ErrorAction SilentlyContinue
$RefsEnalLargeWkSet = $RefsEnableLargeWorkingSetTrim.RefsEnableLargeWorkingSetTrim
if ($RefsEnalLargeWkSet -ne 1 `
-or $RefsEnalLargeWkSet -eq $NULL) {
                                    if ($RefsEnalLargeWkSet -eq $Null) {$RefsEnalLargeWkSet = "NULL"}
                                    #Write-Host "RefsEnableLargeWorkingSetTrim Value not set" -ForegroundColor Red
                                    #Write-Host "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running"
                                    "RefsEnableLargeWorkingSetTrim Value not set" | Out-File $DPM_Info_Log -Append
                                    "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running" | Out-File $DPM_Info_Log -Append
                                   }
                                   Else
                                   {
                                    #Write-Host "RefsEnableLargeWorkingSetTrim is configured" -ForegroundColor Green
                                    "RefsEnableLargeWorkingSetTrim is configured" | Out-File $DPM_Info_Log -Append
                                   }
"" | Out-File $DPM_Info_Log -Append

### RefsDisableCachedPins
$RefsDisableCachedPins = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "RefsDisableCachedPins" -ErrorAction SilentlyContinue
$RefsDCaPin = $RefsDisableCachedPins.RefsDisableCachedPins
if ($RefsDCaPin -ne 1 `
-or $RefsDCaPin -eq $NULL) {
                            if ($RefsDCaPin -eq $Null) {$RefsDCaPin = "NULL"}
                            #Write-Host "RefsDisableCachedPins Value not set" -ForegroundColor Red
                            #Write-Host "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running"
                            "RefsDisableCachedPins Value not set" | Out-File $DPM_Info_Log -Append
                            "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running" | Out-File $DPM_Info_Log -Append
                           }
                           Else
                           {
                            #Write-Host "RefsDisableCachedPins is configured" -ForegroundColor Green
                            "RefsDisableCachedPins is configured" | Out-File $DPM_Info_Log -Append
                           }

"" | Out-File $DPM_Info_Log -Append

### RefsEnableInlineTrim
$RefsEnableInlineTrim = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "RefsEnableInlineTrim" -ErrorAction SilentlyContinue
$RefsEnalineTrim = $RefsEnableInlineTrim.RefsEnableInlineTrim
if ($RefsEnalineTrim -ne 1 `
-or $RefsEnalineTrim -eq $NULL) {
                                 if ($RefsEnalineTrim -eq $Null) {$RefsEnalineTrim = "NULL"}
                                 #Write-Host "RefsEnableInlineTrim Value not set" -ForegroundColor Red
                                 #Write-Host "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running"
                                 "RefsEnableInlineTrim Value not set" | Out-File $DPM_Info_Log -Append
                                 "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running" | Out-File $DPM_Info_Log -Append
                                }
                                Else
                                {
                                 #Write-Host "RefsEnableInlineTrim is configured" -ForegroundColor Green
                                 "RefsEnableInlineTrim is configured" | Out-File $DPM_Info_Log -Append
                                }
"" | Out-File $DPM_Info_Log -Append

### RefsProcessedDeleteQueueEntryCountThreshold 
$RefsProcDelQueEntCouThresh  = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "RefsProcessedDeleteQueueEntryCountThreshold" -ErrorAction SilentlyContinue
$RefsPrDelQCouT = $RefsProcDelQueEntCouThresh.RefsProcessedDeleteQueueEntryCountThreshold
if (2049 -lt $RefsPrDelQCouT`
-or $RefsPrDelQCouT -eq $NULL) {
                                if ($RefsPrDelQCouT -eq $Null) {$RefsPrDelQCouT = "NULL"}
                                #Write-Host "RefsProcessedDeleteQueueEntryCountThreshold Value not set or higher than recommended value of 2048, 1024 or 512" -ForegroundColor Red
                                #Write-Host "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running"
                                "RefsProcessedDeleteQueueEntryCountThreshold Value not set or higher than recommended value of 2048, 1024 or 512" | Out-File $DPM_Info_Log -Append
                                "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running" | Out-File $DPM_Info_Log -Append
                                }
                                Else
                                {
                                 #Write-Host "RefsProcessedDeleteQueueEntryCountThreshold configurable values are: 2048, 1024 and 512" -ForegroundColor Green
                                 #Write-Host "RefsProcessedDeleteQueueEntryCountThreshold value set to: $RefsPrDelQCouT" -ForegroundColor Yellow
                                 "RefsProcessedDeleteQueueEntryCountThreshold configurable values are: 2048, 1024 and 512" | Out-File $DPM_Info_Log -Append
                                 "RefsProcessedDeleteQueueEntryCountThreshold value set to: $RefsPrDelQCouT" | Out-File $DPM_Info_Log -Append
                                }
"" | Out-File $DPM_Info_Log -Append

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
                                 "RefsNumberOfChunksToTrim Value not set" | Out-File $DPM_Info_Log -Append
                                 "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running" | Out-File $DPM_Info_Log -Append
                                }
                                Else
                                {
                                 #Write-Host "RefsNumberOfChunksToTrim configurable values are: 4, 8, 16, 32..." -ForegroundColor Green
                                 #Write-Host "RefsNumberOfChunksToTrim value set to: $RefsEnaChunkTrim" -ForegroundColor Green
                                 "RefsNumberOfChunksToTrim configurable values are: 4, 8, 16, 32..." | Out-File $DPM_Info_Log -Append
                                 "RefsNumberOfChunksToTrim value set to: $RefsEnaChunkTrim" | Out-File $DPM_Info_Log -Append
                                }
"" | Out-File $DPM_Info_Log -Append

# Disk TimeOutValue  
$TimeOutValue   = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Disk" -Name "TimeOutValue" -ErrorAction SilentlyContinue
$TiValue = $TimeOutValue.TimeOutValue
if ($TiValue -lt 120) {
                                    if ($TiValue -eq $Null) {$TiValue = "NULL"}
                                    #Write-Host "Disk TimeOut Value not set or less than recommended value of 120" -ForegroundColor Red
                                    #Write-Host "Disk TimeOut Value set to: $TiValue" -ForegroundColor Red
                                    #Write-Host "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running"
                                    "Disk TimeOut Value not set or less than recommended value of 120" | Out-File $DPM_Info_Log -Append
                                    "Disk TimeOut Value set to: $TiValue" | Out-File $DPM_Info_Log -Append
                                    "https://support.microsoft.com/en-us/help/4090104/update-resolves-heavy-memory-use-in-refs-on-a-computer-that-is-running" | Out-File $DPM_Info_Log -Append
                                   }
                                   Else
                                   {
                                    #Write-Host "Disk TimeOut set to: $TiValue" -ForegroundColor yellow
                                    "Disk TimeOut set to: $TiValue" | Out-File $DPM_Info_Log -Append
                                   }
"" | Out-File $DPM_Info_Log -Append

# ParallelMountDismountLimit  
$ParallelMountDismountLimit   = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Configuration" -Name "ParallelMountDismountLimit" -ErrorAction SilentlyContinue
$ParallelMount = $ParallelMountDismountLimit.ParallelMountDismountLimit
if ($ParallelMount -eq $NULL) {
                                    if ($ParallelMount -eq $Null) {$ParallelMount = "NULL"}
                                    "ParallelMountDismountLimit Value not set" | Out-File $DPM_Info_Log -Append
                                    "ParallelMountDismountLimit set to: $ParallelMount" | Out-File $DPM_Info_Log -Append
                                   }
                                   Else
                                   {
                                    #Write-Host "Disk TimeOut set to: $TiValue" -ForegroundColor yellow
                                    "ParallelMountDismountLimit set to: $ParallelMount" | Out-File $DPM_Info_Log -Append
                                   }
"" | Out-File $DPM_Info_Log -Append

# WMICheckCheckClientOb
$WMICheckClientOb   = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Wbem\CIMOM" -Name "High Threshold On Client Objects (B)" -ErrorAction SilentlyContinue
$WMICheckClient = $WMICheckClientOb."High Threshold On Client Objects (B)"
if ($WMICheckClient -eq $NULL) {
                                    if ($WMICheckClient -eq $Null) {$WMICheckClient = "NULL"}
                                    "High Threshold On Client Objects (B) Value not set" | Out-File $DPM_Info_Log -Append
                                    "High Threshold On Client Objects (B) set to: $WMICheckClient" | Out-File $DPM_Info_Log -Append
                                   }
                                   Else
                                   {
                                    #Write-Host "Disk TimeOut set to: $TiValue" -ForegroundColor yellow
                                    "High Threshold On Client Objects (B) set to: $WMICheckClient" | Out-File $DPM_Info_Log -Append
                                   }
"" | Out-File $DPM_Info_Log -Append

# WMICheckOnEvents
$WMICheckOnEvents   = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Wbem\CIMOM" -Name "High Threshold On Events (B)" -ErrorAction SilentlyContinue
$WMICheckOnEv = $WMICheckOnEvents."High Threshold On Events (B)"
if ($WMICheckOnEv -eq $NULL) {
                                    if ($WMICheckOnEv -eq $Null) {$WMICheckOnEv = "NULL"}
                                    "High Threshold On Events (B) Value not set" | Out-File $DPM_Info_Log -Append
                                    "High Threshold On Events (B) set to: $WMICheckOnEv" | Out-File $DPM_Info_Log -Append
                                   }
                                   Else
                                   {
                                    #Write-Host "Disk TimeOut set to: $TiValue" -ForegroundColor yellow
                                    "High Threshold On Events (B) set to: $WMICheckOnEv" | Out-File $DPM_Info_Log -Append
                                   }
"" | Out-File $DPM_Info_Log -Append

}

"[x] ReFs Optimizations Check Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] ReFs Optimizations Check Completed" -ForegroundColor White
Write-Host "Tasks 10/24 to complete" -ForegroundColor cyan

#endregion

#region ### Check REFS PIT TIMES
$PerfLog = "C:\DPM_Data\PIT_Mount_UnMount_Info.txt"
$logtocheck = $InstallPath+"Temp"
$MSDPMlogs = Get-ChildItem -Path $logtocheck | ? {$_.Name.StartsWith("MSDPM") -and $_.Name.EndsWith(".errlog")} | Where-Object {$_.LastWriteTime -gt (Get-Date).AddHours(-24)} | Sort-Object -Property LastWriteTime
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

$RefsPitTimesResult = $PITstartEndDiffArray | Sort-Object -Property TotalTime -Descending
"" | Out-File $PerfLog -Append
"REFS PIT (CLONE) TIMES for last 24hrs (sorted descending)" | Out-File $PerfLog -Append
"---------------------------" | Out-File $PerfLog -Append
$RefsPitTimesResult | Out-File $PerfLog -Append

"[x] PIT Time Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] PIT Time Completed" -ForegroundColor White
Write-Host "Tasks 11/24 to complete" -ForegroundColor cyan
#endregion

#region ### Check Mount/Unmount Times
$StartMount = "==>MountStorage\("
$EndMount = "MountStorage:"
$StartUnMount = "==>UnmountStorage\("
$EndUnMount = "UnmountStorage:"

$StartMountArray = @()
$StartUnMountArray = @()
$EndMountArray = @()
$EndUnMountArray = @()
$LinesWithStartMount = @()
$LinesWithStartUnMount = @()
$LinesWithEndMount = @()
$LinesWithEndUnMount = @()

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
"Mount\Unmount TIMES for last 24hrs (sorted by TotalTime Descending)" | Out-File $PerfLog -Append
"--------------------------------" | Out-File $PerfLog -Append
$MountTimesResult | Out-File $PerfLog -Append

"[x] Mount and UnMount Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] Mount and UnMount Completed" -ForegroundColor White
Write-Host "Tasks 12/24 to complete" -ForegroundColor cyan
#endregion

#region ### Check REFS PIT UniqueSize
$logtocheck = $InstallPath+"Temp"
$MSDPMlogs = Get-ChildItem -Path $logtocheck | ? {$_.Name.StartsWith("MSDPM") -and $_.Name.EndsWith(".errlog")} | Where-Object {$_.LastWriteTime -gt (Get-Date).AddHours(-24)} | Sort-Object -Property LastWriteTime
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

"[x] ReFs PIT Unique Size Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] ReFs PIT Unique Size Completed" -ForegroundColor White
Write-Host "Tasks 13/24 to complete" -ForegroundColor cyan
#endregion

#region ### Check DPM\MAB DPMDB      
if ($DPMDetected -eq 1 ) {

# DataBase Connection 
$DatabaseName = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft Data Protection Manager\DB" -Name "DatabaseName" -ErrorAction SilentlyContinue
$DatabaseServer = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft Data Protection Manager\DB" -Name "SqlServer" -ErrorAction SilentlyContinue
$DatabaseInstance = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft Data Protection Manager\DB" -Name "InstanceName" -ErrorAction SilentlyContinue

$DPMDB = $DatabaseName.DatabaseName
$DPMdbServer = $DatabaseServer.SqlServer
$DPMdbInstance = $DatabaseInstance.InstanceName
If ($DPMdbInstance -eq "MSSQLSERVER") {
                                       $SRVInstance = "$DPMdbServer"
                                      }
                                      Else
                                      {
                                       $SRVInstance = "$DPMdbServer\$DPMdbInstance"
                                      }

"SQL Server Name" | Out-File $DPM_Info_Log -Append
$SRVInstance | Out-File $DPM_Info_Log -Append
"" | Out-File $DPM_Info_Log -Append
"DPM DB Name" | Out-File $DPM_Info_Log -Append
$DPMDB | Out-File $DPM_Info_Log -Append
"" | Out-File $DPM_Info_Log -Append
"DPM DB Instance Name" | Out-File $DPM_Info_Log -Append
$DPMdbInstance | Out-File $DPM_Info_Log -Append

# DPM Update History
$DPMUpdateHistory = "SELECT [Name],[BuildNumber],[FileName] FROM [$DPMDB].[dbo].[tbl_AM_AgentPatch] where OSType = 2 order by Name desc"
$DPMHistory = Invoke-Sqlcmd -ServerInstance $SRVInstance -Query $DPMUpdateHistory
"" | Out-File $DPM_Info_Log -Append
"DPM Update History" | Out-File $DPM_Info_Log -Append
"------------------" | Out-File $DPM_Info_Log -Append
$DPMHistory | Out-File $DPM_Info_Log -Append

#DPM DB Backup - This might fail if DPM DB it's on a SQL Remote Server. Line1
write-host ""
write-host "Please read!" -ForegroundColor Red
write-host "DPM Database Backup Step. This might fail if DPM DB it's on a SQL Remote Server."

$Y=Read-Host "Press Y to continue if you really necessary to have database backup or any other key to move forward if no database backup is required"

        write-host $line -foregroundcolor white
        $line = $line + $Y
        $line >> $logfile
        if ($Y -Match "Y"){
        #{$Continue}
        #{
        #write-host "Moving forward with no database backup."         
        #}

$DPMDBBCKPath = "C:\DPM_Data\DPMDB"
New-Item -ItemType Directory -Force -Path $DPMDBBCKPath | Out-Null
Backup-SqlDatabase -ServerInstance $SRVInstance -Database $DPMDB -BackupFile "C:\DPM_Data\DPMDB\DPMDB.bak"
$DPMDBBCKPathZip = "C:\DPM_Data\DPMDB"
$DPMDBBCKPathZipDest ="C:\DPM_Data\DPMDB.zip"
Compress-Archive -Path $DPMDBBCKPathZip -DestinationPath $DPMDBBCKPathZipDest | Out-Null
Remove-Item -Recurse -Force $DPMDBBCKPath
}

ELSE {
#$Continue
write-host "Continue.. Moving forward with no database backup."         
}

#DPMDB DBRecovery State
$DPMdbRecovery = "SELECT [PropertyName],[PropertyValue] FROM [$DPMDB].[dbo].[tbl_DLS_GlobalSetting]"
$DPMrecovery = Invoke-Sqlcmd -ServerInstance $SRVInstance -Query $DPMdbRecovery

if ($DPMrecovery[6].PropertyValue -eq 1) {
                                          "" | Out-File $DPM_Info_Log -Append
                                          "DPM Database Recovery" | Out-File $DPM_Info_Log -Append
                                          "---------------------" | Out-File $DPM_Info_Log -Append
                                          #Write-Host "DPM Database in Recovery Mode" -ForegroundColor red
                                          "DPM Database in Recovery Mode" | Out-File $DPM_Info_Log -Append
                                         }

# tbl_STM_Volume and disk status 
$STMVolQuery = "SELECT [AccessPath],[Label],[Status],[Tag],[FileSystem],[DedupMode] FROM [$DPMDB].[dbo].[tbl_STM_Volume]"
$DPMdisksSQL = Invoke-Sqlcmd -ServerInstance $SRVInstance -Query $STMVolQuery
$DPMdisksSQL | % {
                  If ($_.Status -eq 1 -and $_.Tag -eq 511) {
                                                            $DiskAccess = $_.AccessPath
                                                            $DiskStatus = $_.Label
                                                            "" | Out-File $DPM_Info_Log -Append
                                                            "DPM Storage Issues" | Out-File $DPM_Info_Log -Append
                                                            "------------------" | Out-File $DPM_Info_Log -Append
                                                            #Write-Host "DPM has a failed or missing volume: $DiskAccess $DiskStatus" -ForegroundColor yellow
                                                            "DPM has a failed or missing volume: $DiskAccess $DiskStatus" | Out-File $DPM_Info_Log -Append
                                                           }
                 }

# DPM Garbage recent history
$DPMGC ="select [TaskID], [JobID], [LastStateName], [StartedDateTime], [StoppedDateTime] from [$DPMDB].[dbo].[tbl_TE_TaskTrail] where VerbID = '282faac6-e3cb-4015-8c6d-4276fcca11d4' order by startedDateTime"
$DPMGChistory = Invoke-Sqlcmd -ServerInstance $SRVInstance -Query $DPMGC
"" | Out-File $DPM_Info_Log -Append
"DPM GC History (Last 5 entries)" | Out-File $DPM_Info_Log -Append
"-------------------------------" | Out-File $DPM_Info_Log -Append
$DPMGChistory | Select-Object -Last 5 | Out-File $DPM_Info_Log -Append
}

"[x] DPM DB Check Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] DPM DB Check Completed" -ForegroundColor White
Write-Host "Tasks 14/24 to complete" -ForegroundColor cyan

#Gather tape library info
$DPMLibraryLog = "C:\DPM_Data\DPM_Library_Info.txt"
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
				$TDobj | Out-File $DPMLibraryLog -append
			}
	} else {
		"WARNING: NO TAPE LIBRARIES FOUND" | Out-File $DPMLibraryLog -append
	}

"[x] Library Info Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] Library Info Completed" -ForegroundColor White
Write-Host "Tasks 15/24 to complete" -ForegroundColor cyan

# Get Protection Groups
$ProtectionGroupsLog = "C:\DPM_Data\Protection_Groups_Info.txt"
"Protection Groups" | Out-File $ProtectionGroupsLog -append
"-------------------------------" | Out-File $ProtectionGroupsLog -append
"" | Out-File $ProtectionGroupsLog -append
$PGList = @(Get-ProtectionGroup (&hostname) | Sort-Object name)
        foreach ($pg in $PGList)
        {
            if ($DPMMajorVersion -eq '3') # DPM 2010
            {
               "Protection Group............: " + $pg.friendlyname | Out-File $ProtectionGroupsLog -append
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
                ("       type: {0,-20} - Datasource Name: {1}" -f $ds.ObjectType, $ds.DisplayPath ) | Out-File $ProtectionGroupsLog -append
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
                                            $DSTypeList = @(Invoke-Sqlcmd -ServerInstance $DPM -Database $DPMDB -Query $query)
                                            foreach ($DSType in $DSTypeList)
                                            {                                        
                                                "            " + $DSType.ComponentName | Out-File $ProtectionGroupsLog -append
                                            }
                                        }
                    'SharePoint Farm'   {   $query = "select ComponentName 
                                                      from tbl_IM_ProtectedObject 
                                                      where ProtectedInPlan = 1 and
	                                                  ReferentialDataSourceId like '"+ $ds.DatasourceId + "' order by convert(varchar(max),LogicalPath)"
                                            $DSTypeList = @(Invoke-Sqlcmd -ServerInstance $DPM -Database $DPMDB -Query $query)
                                            foreach ($DSType in $DSTypeList)
                                            {                                        
                                                 "         " + $DSType.ComponentName | Out-File $ProtectionGroupsLog -append
                                           }
                                        }
                    'Volume'            {   $query = "select LogicalPath
                                                      from tbl_IM_ProtectedObject 
                                                      where ProtectedInPlan = 1 and
	                                                  DataSourceId like '"+ $ds.DatasourceId + "' order by convert(varchar(max),LogicalPath)"
                                            $DSTypeList = @(Invoke-Sqlcmd -ServerInstance $DPM -Database $DPMDB -Query $query)
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

"[x] Protection Groups Info Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] Protection Groups Info Completed" -ForegroundColor White
Write-Host "Tasks 16/24 to complete" -ForegroundColor cyan

# Ran this query to see the PG's and Data Sources

$GETDataSources = "select ag.NetbiosName, ds.DataSourceName, ds.DataSourceId, lr.PhysicalReplicaId, pg.FriendlyName, lr.validity from [$DPMDB].[dbo].[tbl_IM_DataSource] as ds
join [$DPMDB].[dbo].[tbl_PRM_LogicalReplica] as lr 
on ds.DataSourceId=lr.DataSourceId
join [$DPMDB].[dbo].[tbl_AM_Server] as ag
on ds.ServerId=ag.ServerId
join [$DPMDB].[dbo].[tbl_IM_ProtectedGroup] as pg 
on ds.ProtectedGroupId=pg.ProtectedGroupId and pg.DiskIntentId is not null order by FriendlyName asc"
$GETDataSourcesCMD = Invoke-Sqlcmd -ServerInstance $SRVInstance -Query $GETDataSources
"" | Out-File $DPM_Info_Log -Append
"" | Out-File $DPM_Info_Log -Append
"Data Sources" | Out-File $DPM_Info_Log -Append
"-------------------------------" | Out-File $DPM_Info_Log -Append
$GETDataSourcesCMD | Select-Object | ft | Out-File $DPM_Info_Log -Append

"[x] Query to Get PG's and Data Sources ID's Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] Query to Get PG's and Data Sources ID's Completed" -ForegroundColor White
Write-Host "Tasks 17/24 to complete" -ForegroundColor cyan

# Get Job History
$JobHistoryLog = "C:\DPM_Data\DPM_Job_History.txt"

"Job History" | Out-File $JobHistoryLog -Append
"-------------------------------" | Out-File $JobHistoryLog -Append
"" | Out-File $JobHistoryLog -Append
$LastJobInHours = 240
$D = Get-date
$DPMservername = ${Env:ComputerName}
$a= Get-DPMJob -DPMServerName $DPMservername -From $D.addhours(-$LastJobInHours) -To $D | Where-Object -FilterScript {$_.JobType -ne "FastInventory"}
"StartTime            EndTime           Duration JobType               TaskID                           DataSource             ErrorCode" | Out-File $JobHistoryLog -Append
"-------------       ---------          -------- --------            ----------                         ----------             ---------" | Out-File $JobHistoryLog -Append
$a | % {
        if ($_.TaskList.DatasourcePath -ge 2)
            {
            $subdata = $_.TaskList
            $subdata | % {
                        $subdatavalues = $_
                        $duration = $subdatavalues.EndTime - $subdatavalues.StartTime
                        #$Jobs += 
                        -join ($subdatavalues.StartTime.ToString("s"),'  ',$subdatavalues.EndTime.ToString("s"),'  ',$duration.Minutes,'  ',$subdatavalues.Type,'  ',$subdatavalues.TaskID,'  ',$subdatavalues.DatasourcePath,'  ',$subdatavalues.ErrorCode) | Out-File $JobHistoryLog -Append
                        } 
            } 
  }

"[x] Job History Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] Job History Completed" -ForegroundColor White
Write-Host "Tasks 18/24 to complete" -ForegroundColor cyan
#endregion

#region 
### Event Viewer Colletion
$vmms_storage = "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-Hyper-V-VMMS-Storage.evtx"
$vmms_operational = "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-Hyper-V-VMMS-Operational.evtx"
$VHDPM = "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-VHDMP-Operational.evtx"
$WMI = "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-WMI-Activity%4Operational.evtx"
$CloudBackup = "C:\Windows\System32\Winevt\Logs\CloudBackup.evtx"
$Application = "C:\Windows\System32\Winevt\Logs\Application.evtx"
$DPMAlerts = "C:\Windows\System32\Winevt\Logs\DPM Alerts.evtx"
$System = "C:\Windows\System32\Winevt\Logs\System.evtx"
$Security = "C:\Windows\System32\Winevt\Logs\Security.evtx"
$DPMBackupEvents = "C:\Windows\System32\Winevt\Logs\DPM Backup Events.evtx"
$WindowsBackup = "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-Backup.evtx"
$CAPI2 = "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-CAPI2%4Operational.evtx"
$DedupScrubbing = "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-Deduplication%4Scrubbing.evtx"
$DedupOp = "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-Deduplication%4Operational.evtx"
$NTFS = "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-Ntfs%4Operational.evtx"
$ReFSEvent = "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-ReFS%4Operational.evtx"
$SMBClientCon = "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-SmbClient%4Connectivity.evtx"
$SMBClientOp = "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-SMBClient%4Operational.evtx"
$SMBServerOp = "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-SMBServer%4Operational.evtx"
$SMBServerCon = "C:\Windows\System32\Winevt\Logs\Microsoft-Windows-SMBServer%4Connectivity.evtx"

#Copy Events to folder Events
$EventViewerLogs = "C:\DPM_Data\Events"
$EventViewerLogsZip = "C:\DPM_Data\Events.zip"
New-Item -ItemType Directory -Force -Path $EventViewerLogs | Out-Null

copy $vmms_storage "C:\DPM_Data\Events"
copy $vmms_operational "C:\DPM_Data\Events"
copy $VHDPM "C:\DPM_Data\Events"
copy $WMI "C:\DPM_Data\Events" 
copy $CloudBackup "C:\DPM_Data\Events"
copy $Application "C:\DPM_Data\Events"
copy $DPMAlerts "C:\DPM_Data\Events"
copy $System "C:\DPM_Data\Events"
copy $Security "C:\DPM_Data\Events"
copy $DPMBackupEvents "C:\DPM_Data\Events"
copy $WindowsBackup "C:\DPM_Data\Events"
copy $CAPI2 "C:\DPM_Data\Events"
copy $DedupScrubbing "C:\DPM_Data\Events"
copy $DedupOp "C:\DPM_Data\Events"
copy $NTFS "C:\DPM_Data\Events"
copy $ReFSEvent "C:\DPM_Data\Events"
copy $SMBClientCon "C:\DPM_Data\Events"
copy $SMBClientOp "C:\DPM_Data\Events"
copy $SMBServerOp "C:\DPM_Data\Events"
copy $SMBServerCon "C:\DPM_Data\Events"

Compress-Archive -Path $EventViewerLogs -DestinationPath $EventViewerLogsZip | Out-Null
Remove-Item -Recurse -Force $EventViewerLogs

"[x] Event Viewer Colletion Ended" | Out-File $OutFilePath\$OutFileName -Append

Write-Host "" -ForegroundColor White
Write-Host "[x] Event Viewer Collection Completed" -ForegroundColor White
Write-Host "Tasks 19/24 to complete" -ForegroundColor cyan
#endregion

#region
#GET DPM Installation Path
$GetDPMInst = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup" -Name "InstallPath"
$GetDPMInst.InstallPath | Out-Null

"[x] Get DPM Installation Path Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] Get DPM Installation Path Completed" -ForegroundColor White
Write-Host "Tasks 20/24 to complete" -ForegroundColor cyan

#Copy DPM Temp Folder
$DPMErrorLogs = "C:\DPM_Data\DPM_Error_Logs"
New-Item -ItemType Directory -Force -Path $DPMErrorLogs | Out-Null
$DPMtempZip = $GetDPMInst.InstallPath + "Temp\*"
copy $DPMtempZip $DPMErrorLogs
$OutputBase= "C:\DPM_Data\DPM_Error_Logs.zip"
Compress-Archive -Path $DPMErrorLogs -DestinationPath $OutputBase | Out-Null
Remove-Item -Recurse -Force $DPMErrorLogs

"[x] Copy and Compress with DPM Temp Deletion Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] Copy and Compress with DPM Temp Deletion Completed" -ForegroundColor White
Write-Host "Tasks 21/24 to complete" -ForegroundColor cyan
#endregion

#region
#Get MARS Installation Path

$GetMARSInst = Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Azure Backup\Setup" -Name "InstallPath"
$GetMARSInst.InstallPath | Out-Null
#endregion

#Copy CBENGINE Temp Folder

$CBENGINEErrorLogs = "C:\DPM_Data\CBENGINE_Error_Logs"
New-Item -ItemType Directory -Force -Path $CBENGINEErrorLogs | Out-Null
$CBENGINEtempZip = $GetMARSInst.InstallPath  + "Temp\*"
copy $CBENGINEtempZip $CBENGINEErrorLogs
$OutputBaseMARS = "C:\DPM_Data\CBENGINE_Error_Logs.zip"
Compress-Archive -Path $CBENGINEErrorLogs -DestinationPath $OutputBaseMARS | Out-Null
Remove-Item -Recurse -Force $CBENGINEErrorLogs

"[x] Copy and Compress with MARS Temp Deletion Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] Copy and Compress with MARS Temp Deletion Completed" -ForegroundColor White
Write-Host "Tasks 22/24 to complete" -ForegroundColor cyan
#endregion

#CustomerInfo
Write-Host ""
Write-Host " We are almost ready.." -ForegroundColor Green

#region
#Get Registry Info
$DPMRegistryLog = "C:\DPM_Data\DPM_Registry_Info.txt"
"DPM Installation Path"| Out-File $DPMRegistryLog -Append
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\Setup" -Name "InstallPath” | Out-File $DPMRegistryLog -Append
"------------------------------"| Out-File $DPMRegistryLog -Append
""| Out-File $DPMRegistryLog -Append
"DPM Database Setup"| Out-File $DPMRegistryLog -Append
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft Data Protection Manager\DB" -Name "ConnectionString”,”DatabaseName”,”GlobalDbConnectionString”,”GlobalInstanceName”,”GlobalSqlServer”,”InstanceName”,”LinkedServerName”,”ReportingInstanceName”,”ReportingServer”,”SqlServer” | Out-File $DPMRegistryLog -Append
"------------------------------"| Out-File $DPMRegistryLog -Append
""| Out-File $DPMRegistryLog -Append
"MARS Installation Path"| Out-File $DPMRegistryLog -Append
$GetMARSInst.InstallPath | Out-File $DPMRegistryLog -Append
""| Out-File $DPMRegistryLog -Append
"------------------------------"| Out-File $DPMRegistryLog -Append
""| Out-File $DPMRegistryLog -Append
"MARS Setup Data"| Out-File $DPMRegistryLog -Append
Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows Azure Backup\Config" -Name "MachineID", "ResourceId", "ScratchLocation” | Out-File $DPMRegistryLog -Append

"[x] Get Registry Info Completed" | Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] Get Registry Completed" -ForegroundColor White
Write-Host "Tasks 23/24 to complete" -ForegroundColor cyan
#endregion

#region
#Get online job history
$OnlineJobHistoryLog = "C:\DPM_Data\DPM_OnlineJob_History.txt"
$count=0
		while ($count -ne 10)
		{
$Jobhistorylist  = @(Get-DPMJob (&hostname) -type CloudBackup -From (get-date).AddDays(-15) | Sort-Object starttime)
			if (!$Jobhistorylist) { Sleep 2; $count++} else { break }
		}

		''                                                                                                                                                                                                                                                     | Out-File $OutputBase -Append -Width 500
		'JobType       Start (UTC Time)         End (UTC Time)           State       Data Transfer (MB)   Production Server                      Name                                   DPM/CBENGINE TaskID                    DetailedErrorCode   ErrorCode'  | Out-File $OutputBase -Append -Width 500
		'-----------   ----------------------   ----------------------   ---------   ------------------   ------------------------------------   ------------------------------------   ------------------------------------   -----------------   ----------' | Out-File $OutputBase -Append -Width 500
		foreach ($jobhistory in $Jobhistorylist)
		{
			$jobTYpe     = $Jobhistory.jobtype
			$jobstatus   = $jobhistory.status
		    $JobStartTm  = $jobhistory.StartTime
			$JobEndTm    = $jobhistory.endTime
			$JobFiles    = $jobhistory.JobStatus.DatasourceStatus.fileprogress.total
			$jobTransfer = $jobhistory.DataSize
			$JobName     = $jobhistory.DataSources
			$JobServer   = $jobhistory.Tasks.ProductionServerName
			[xml]$Error  = $Jobhistory.tasks.errorinfoxml
			$JobDEC      = $error.ErrorInfo.DetailedCode
			[int]$JobErr = $error.ErrorInfo.ErrorCode
			#$JobErrParm  = $jobhistory.JobStatus.errorinfo.ErrorParamList.name + ' ' + $jobhistory.JobStatus.errorinfo.ErrorParamList.value
			$JobID       = $jobhistory.Tasks.taskid.Guid
			if ($jobTransfer -ne 0) { $JobTransferMB = $jobTransfer/1024/1024 } else {  $JobTransferMB = 0 } 
		    ('{0,-11}   {1,-22}   {2,-22}   {3,-9}   {4,18:N2}   {5,-36}   {6,-36}   {7}   {8,17:x}   {9,10:x}' -f $jobtype, $JobStartTm, $JobEndTm, $Jobstatus, $JobTransferMB, $JobServer, $JobName, $JobID, $JobDEC, $JobErr) | Out-File $OnlineJobHistoryLog -Append -Width 500
		}
"[x] Online Job History Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] Online Job History Completed" -ForegroundColor White
Write-Host "Tasks 24/24 to complete" -ForegroundColor cyan
#endregion

$GetD = get-date -format "hh:mm:tt dd-MM-yyyy"
" " | Out-File $OutFilePath\$OutFileName #-Append
"-------------------" | Out-File $OutFilePath\$OutFileName -Append
$GetD | Out-File $OutFilePath\$OutFileName -Append
"-------------------" | Out-File $OutFilePath\$OutFileName -Append
"" | Out-File $OutFilePath\$OutFileName -Append

#CLEAR
Write-Host ""
Write-Host "Finishing..Compressing collected logging and Cleaning.." -ForegroundColor Green

#region
#Compressing DPM_DATA
$DataToCustomerZip = "C:\DPM_DATA.zip"
$DataToCustomer = "C:\DPM_DATA"
Compress-Archive -Path $DataToCustomer -DestinationPath $DataToCustomerZip | Out-Null
$ToRemove = "C:\DPM_Data"
Remove-Item -Recurse -Force $ToRemove


#"[x] Compress of the Logging Collected and Cleaning Completed"| Out-File $OutFilePath\$OutFileName -Append
Write-Host "" -ForegroundColor White
Write-Host "[x] Compress of the Logging Collected and Cleaning Completed" -ForegroundColor White
write-host ""
write-host " ALL Tasks Completed!"-ForegroundColor White

#endregion

write-host ""
Write-host "Congratulations!" -ForegroundColor Green 
write-host ""
write-host "Logs were collected with Success. Please upload the folder DPM_DATA.zip located on the root of the C:\ of your server to your workspace" -ForegroundColor White