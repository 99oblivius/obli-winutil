#Requires -RunAsAdministrator

<#
.NOTES
    Author         : Chris Titus @christitustech
    Forker         : 99oblivius
    Runspace Author: @DeveloperDurp
    GitHub         : https://github.com/ChrisTitusTech
    Version        : 1.0.0
#>

Start-Transcript $ENV:TEMP\Winutil.log -Append

#Load DLLs
Add-Type -AssemblyName System.Windows.Forms

# variable to sync between runspaces
$sync = [Hashtable]::Synchronized(@{})
$sync.PSScriptRoot = $PSScriptRoot
$sync.version = "1.0.0"
$sync.configs = @{}
$sync.ProcessRunning = $false
Function Get-WinUtilCheckBoxes {

    <#

        .DESCRIPTION
        Function is meant to find all checkboxes that are checked on the specefic tab and input them into a script.

        Outputed data will be the names of the checkboxes that were checked

        .EXAMPLE

        Get-WinUtilCheckBoxes "WPFInstall"

    #>

    Param(
        $Group,
        [boolean]$unCheck = $true
    )


    $Output = New-Object System.Collections.Generic.List[System.Object]

    if($Group -eq "WPFInstall"){
        $filter = Get-WinUtilVariables -Type Checkbox | Where-Object {$psitem -like "WPFInstall*"}
        $CheckBoxes = $sync.GetEnumerator() | Where-Object {$psitem.Key -in $filter}
        Foreach ($CheckBox in $CheckBoxes){
            if($CheckBox.value.ischecked -eq $true){
                $sync.configs.applications.$($CheckBox.Name).winget -split ";" | ForEach-Object {
                    $Output.Add($psitem)
                }
                if ($uncheck -eq $true){
                    $CheckBox.value.ischecked = $false
                }
                
            }
        }
    }
    
    if($Group -eq "WPFTweaks"){
        $filter = Get-WinUtilVariables -Type Checkbox | Where-Object {$psitem -like "WPF*Tweaks*"}
        $CheckBoxes = $sync.GetEnumerator() | Where-Object {$psitem.Key -in $filter}
        Foreach ($CheckBox in $CheckBoxes){
            if($CheckBox.value.ischecked -eq $true){
                $Output.Add($Checkbox.Name)
                
                if ($uncheck -eq $true){
                    $CheckBox.value.ischecked = $false
                }
            }
        }
    }

    if($Group -eq "WPFFeature"){
        $filter = Get-WinUtilVariables -Type Checkbox | Where-Object {$psitem -like "WPF*Feature*"}
        $CheckBoxes = $sync.GetEnumerator() | Where-Object {$psitem.Key -in $filter}
        Foreach ($CheckBox in $CheckBoxes){
            if($CheckBox.value.ischecked -eq $true){
                $Output.Add($Checkbox.Name)
                
                if ($uncheck -eq $true){
                    $CheckBox.value.ischecked = $false
                }
            }
        }
    }

    Write-Output $($Output | Select-Object -Unique)
}
Function Get-WinUtilDarkMode {
    <#
    
        .DESCRIPTION
        Meant to pull the registry keys responsible for Dark Mode and returns true or false
    
    #>
    $app = (Get-ItemProperty -path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize').AppsUseLightTheme
    $system = (Get-ItemProperty -path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize').SystemUsesLightTheme
    if($app -eq 0 -and $system -eq 0){
        return $true
    } 
    else{
        return $false
    }
}
function Get-WinUtilInstallerProcess {
    <#
    
        .DESCRIPTION
        Meant to check for running processes and will return a boolean response
    
    #>

    param($Process)

    if ($Null -eq $Process){
        return $false
    }
    if (Get-Process -Id $Process.Id -ErrorAction SilentlyContinue){
        return $true
    }
    return $false
}
function Get-WinUtilRegistry {
    <#
    
        .DESCRIPTION
        This function will make all modifications to the registry

        .EXAMPLE

        Set-WinUtilRegistry -Name "PublishUserActivities" -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Type "DWord" -Value "0"
    
    #>    
    param (
        $Name,
        $Path,
        $Type,
        $Value
    )

    Try{      
        $syscheckvalue = Get-ItemPropertyValue -Path $Path -Value $Value # Return Value

    }
    Catch [System.Security.SecurityException] {
        Write-Warning "Unable to set $Path\$Name to $Value due to a Security Exception"
    }
    Catch [System.Management.Automation.ItemNotFoundException] {
        Write-Warning $psitem.Exception.ErrorRecord
    }
    Catch{
        Write-Warning "Unable to set $Name due to unhandled exception"
        Write-Warning $psitem.Exception.StackTrace
    }
}
function Get-WinUtilVariables {

    <#
    
        .DESCRIPTION
        palceholder
    
    #>
    param (
        [Parameter()]
        [ValidateSet("CheckBox", "Button")]
        [string]$Type
    )

    $keys = $sync.keys | Where-Object {$psitem -like "WPF*"} 

    if($type){
        $output = $keys | ForEach-Object {
            Try{
                if ($sync["$psitem"].GetType() -like "*$type*"){
                    Write-Output $psitem
                }
            }
            Catch{<#I am here so errors don't get outputted for a couple variables that don't have the .GetType() attribute#>}
        }
        return $output        
    }
    return $keys
}
Function Install-WinUtilProgramWinget {

    <#
    
        .DESCRIPTION
        This will install programs via Winget using a new powershell.exe instance to prevent the GUI from locking up.

        Note the triple quotes are required any time you need a " in a normal script block.
    
    #>

    param(
        $ProgramsToInstall,
        $manage = "Installing"
    )

    $x = 0
    $count = $($ProgramsToInstall -split ",").Count

    Write-Progress -Activity "$manage Applications" -Status "Starting" -PercentComplete 0

    Foreach ($Program in $($ProgramsToInstall -split ",")){
    
        Write-Progress -Activity "$manage Applications" -Status "$manage $Program $($x + 1) of $count" -PercentComplete $($x/$count*100)
        if($manage -eq "Installing"){
            Start-Process -FilePath winget -ArgumentList "install -e --accept-source-agreements --accept-package-agreements --silent $Program" -NoNewWindow -Wait
        }
        if($manage -eq "Uninstalling"){
            Start-Process -FilePath winget -ArgumentList "remove -e --purge --force --silent $Program" -NoNewWindow -Wait
        }
        
        $X++
    }

    Write-Progress -Activity "$manage Applications" -Status "Finished" -Completed

}
function Install-WinUtilWinget {
    
    <#
    
        .DESCRIPTION
        Function is meant to ensure winget is installed 
    
    #>
    Try{
        Write-Host "Checking if Winget is Installed..."
        if (Test-WinUtilPackageManager -winget) {
            #Checks if winget executable exists and if the Windows Version is 1809 or higher
            Write-Host "Winget Already Installed"
            return
        }

        #Gets the computer's information
        if ($null -eq $sync.ComputerInfo){
            $ComputerInfo = Get-ComputerInfo -ErrorAction Stop
        }
        Else {
            $ComputerInfo = $sync.ComputerInfo
        }

        if (($ComputerInfo.WindowsVersion) -lt "1809") {
            #Checks if Windows Version is too old for winget
            Write-Host "Winget is not supported on this version of Windows (Pre-1809)"
            return
        }

        #Gets the Windows Edition
        $OSName = if ($ComputerInfo.OSName) {
            $ComputerInfo.OSName
        }else {
            $ComputerInfo.WindowsProductName
        }

        if (((($OSName.IndexOf("LTSC")) -ne -1) -or ($OSName.IndexOf("Server") -ne -1)) -and (($ComputerInfo.WindowsVersion) -ge "1809")) {

            Write-Host "Running Alternative Installer for LTSC/Server Editions"

            # Switching to winget-install from PSGallery from asheroto
            # Source: https://github.com/asheroto/winget-installer

            #adding the code from the asheroto repo
            Set-ExecutionPolicy RemoteSigned -force
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
            Install-Script -Name winget-install -force
            winget-instal
            
            
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-command irm https://raw.githubusercontent.com/ChrisTitusTech/winutil/$BranchToUse/winget.ps1 | iex | Out-Host" -WindowStyle Normal -ErrorAction Stop

            if(!(Test-WinUtilPackageManager -winget)){
                break
            }
        }

        else {
            #Installing Winget from the Microsoft Store
            Write-Host "Winget not found, installing it now."
            Start-Process "ms-appinstaller:?source=https://aka.ms/getwinget"
            $nid = (Get-Process AppInstaller).Id
            Wait-Process -Id $nid

            if(!(Test-WinUtilPackageManager -winget)){
                break
            }
        }
        Write-Host "Winget Installed"
    }
    Catch{
        throw [WingetFailedInstall]::new('Failed to install')
    }
}
Function Invoke-WinUtilCurrentSystem {

    <#

        .DESCRIPTION
        Function is meant to read existing system registry and check according configuration.

        Example: Is telemetry enabled? check the box.

        .EXAMPLE

        Get-WinUtilCheckBoxes "WPFInstall"

    #>

    param(
        $CheckBox
    )

    if ($checkbox -eq "winget"){

        $originalEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
        $Sync.InstalledPrograms = winget list -s winget | Select-Object -skip 3 | ConvertFrom-String -PropertyNames "Name", "Id", "Version", "Available" -Delimiter '\s{2,}'
        [Console]::OutputEncoding = $originalEncoding

        $filter = Get-WinUtilVariables -Type Checkbox | Where-Object {$psitem -like "WPFInstall*"}
        $sync.GetEnumerator() | Where-Object {$psitem.Key -in $filter} | ForEach-Object {
            if($sync.configs.applications.$($psitem.Key).winget -in $sync.InstalledPrograms.Id){
                Write-Output $psitem.name
            }
        }
    }

    if($CheckBox -eq "tweaks"){

        if(!(Test-Path 'HKU:\')){New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS}
        $ScheduledTasks = Get-ScheduledTask

        $sync.configs.tweaks | Get-Member -MemberType NoteProperty | ForEach-Object {

            $Config = $psitem.Name
            #WPFEssTweaksTele
            $registryKeys = $sync.configs.tweaks.$Config.registry
            $scheduledtaskKeys = $sync.configs.tweaks.$Config.scheduledtask
            $serviceKeys = $sync.configs.tweaks.$Config.service
        
            if($registryKeys -or $scheduledtaskKeys -or $serviceKeys){
                $Values = @()


                Foreach ($tweaks in $registryKeys){
                    Foreach($tweak in $tweaks){
            
                        if(test-path $tweak.Path){
                            $actualValue = Get-ItemProperty -Name $tweak.Name -Path $tweak.Path -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $($tweak.Name)
                            $expectedValue = $tweak.Value
                            if ($expectedValue -notlike $actualValue){
                                $values += $False                                
                            }
                        }
                    }
                }

                Foreach ($tweaks in $scheduledtaskKeys){
                    Foreach($tweak in $tweaks){
                        $task = $ScheduledTasks | Where-Object {$($psitem.TaskPath + $psitem.TaskName) -like "\$($tweak.name)"}
            
                        if($task){
                            $actualValue = $task.State
                            $expectedValue = $tweak.State
                            if ($expectedValue -ne $actualValue){
                                $values += $False
                            }
                        }
                    }
                }

                Foreach ($tweaks in $serviceKeys){
                    Foreach($tweak in $tweaks){
                        $Service = Get-Service -Name $tweak.Name
            
                        if($Service){
                            $actualValue = $Service.StartType
                            $expectedValue = $tweak.StartupType
                            if ($expectedValue -ne $actualValue){
                                $values += $False
                            }
                        }
                    }
                }

                if($values -notcontains $false){
                    Write-Output $Config
                }
            }
        }
    }
}

function Invoke-WinUtilFeatureInstall {
    <#
    
        .DESCRIPTION
        This function converts all the values from the tweaks.json and routes them to the appropriate function
    
    #>

    param(
        $CheckBox
    )

    $CheckBox | ForEach-Object {
        if($sync.configs.feature.$psitem.feature){
            Foreach( $feature in $sync.configs.feature.$psitem.feature ){
                Try{ 
                    Write-Host "Installing $feature"
                    Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart
                }
                Catch{
                    if ($psitem.Exception.Message -like "*requires elevation*"){
                        Write-Warning "Unable to Install $feature due to permissions. Are you running as admin?"
                    }

                    else{
                        Write-Warning "Unable to Install $feature due to unhandled exception"
                        Write-Warning $psitem.Exception.StackTrace 
                    }
                }
            } 
        }
        if($sync.configs.feature.$psitem.InvokeScript){
            Foreach( $script in $sync.configs.feature.$psitem.InvokeScript ){
                Try{
                    $Scriptblock = [scriptblock]::Create($script)

                    Write-Host "Running Script for $psitem"
                    Invoke-Command $scriptblock -ErrorAction stop
                }
                Catch{
                    if ($psitem.Exception.Message -like "*requires elevation*"){
                        Write-Warning "Unable to Install $feature due to permissions. Are you running as admin?"
                    }

                    else{
                        Write-Warning "Unable to Install $feature due to unhandled exception"
                        Write-Warning $psitem.Exception.StackTrace 
                    }
                }
            } 
        }
    }
}
function Invoke-WinUtilScript {
    <#
    
        .DESCRIPTION
        This function will run a seperate powershell script. Meant for things that can't be handled with the other functions

        .EXAMPLE

        $Scriptblock = [scriptblock]::Create({"Write-output 'Hello World'"})
        Invoke-WinUtilScript -ScriptBlock $scriptblock -Name "Hello World"
    
    #>
    param (
        $Name,
        [scriptblock]$scriptblock
    )

    Try {
        Write-Host "Running Script for $name"
        Invoke-Command $scriptblock -ErrorAction Stop
    }
    Catch [System.Management.Automation.CommandNotFoundException] {
        Write-Warning "The specified command was not found."
        Write-Warning $PSItem.Exception.message
    }
    Catch [System.Management.Automation.RuntimeException] {
        Write-Warning "A runtime exception occurred."
        Write-Warning $PSItem.Exception.message
    }
    Catch [System.Security.SecurityException] {
        Write-Warning "A security exception occurred."
        Write-Warning $PSItem.Exception.message
    }
    Catch [System.UnauthorizedAccessException] {
        Write-Warning "Access denied. You do not have permission to perform this operation."
        Write-Warning $PSItem.Exception.message
    }
    Catch {
        # Generic catch block to handle any other type of exception
        Write-Warning "Unable to run script for $name due to unhandled exception"
        Write-Warning $psitem.Exception.StackTrace 
    }
    
}
function Invoke-WinUtilTweaks {
    <#
    
        .DESCRIPTION
        This function converts all the values from the tweaks.json and routes them to the appropriate function
    
    #>

    param(
        $CheckBox,
        $undo = $false
    )
    if($undo){
        $Values = @{
            Registry = "OriginalValue"
            ScheduledTask = "OriginalState"
            Service = "OriginalType"
        }
    }    
    Else{
        $Values = @{
            Registry = "Value"
            ScheduledTask = "State"
            Service = "StartupType"
        }
    }

    if($sync.configs.tweaks.$CheckBox.registry){
        $sync.configs.tweaks.$CheckBox.registry | ForEach-Object {
            Set-WinUtilRegistry -Name $psitem.Name -Path $psitem.Path -Type $psitem.Type -Value $psitem.$($values.registry)
        }
    }
    if($sync.configs.tweaks.$CheckBox.ScheduledTask){
        $sync.configs.tweaks.$CheckBox.ScheduledTask | ForEach-Object {
            Set-WinUtilScheduledTask -Name $psitem.Name -State $psitem.$($values.ScheduledTask)
        }
    }
    if($sync.configs.tweaks.$CheckBox.service){
        $sync.configs.tweaks.$CheckBox.service | ForEach-Object {
            Set-WinUtilService -Name $psitem.Name -StartupType $psitem.$($values.Service)
        }
    }

    if(!$undo){
        if($sync.configs.tweaks.$CheckBox.appx){
            $sync.configs.tweaks.$CheckBox.appx | ForEach-Object {
                Remove-WinUtilAPPX -Name $psitem
            }
        }
        if($sync.configs.tweaks.$CheckBox.InvokeScript){
            $sync.configs.tweaks.$CheckBox.InvokeScript | ForEach-Object {
                $Scriptblock = [scriptblock]::Create($psitem)
                Invoke-WinUtilScript -ScriptBlock $scriptblock -Name $CheckBox
            }
        }
    }
}
function Remove-WinUtilAPPX {
    <#
    
        .DESCRIPTION
        This function will remove any of the provided APPX names

        .EXAMPLE

        Remove-WinUtilAPPX -Name "Microsoft.Microsoft3DViewer"
    
    #>
    param (
        $Name
    )

    Try{
        Write-Host "Removing $Name"
        Get-AppxPackage "*$Name*" | Remove-AppxPackage -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like "*$Name*" | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }
    Catch [System.Exception] {
        if($psitem.Exception.Message -like "*The requested operation requires elevation*"){
            Write-Warning "Unable to uninstall $name due to a Security Exception"
        }
        Else{
            Write-Warning "Unable to uninstall $name due to unhandled exception"
            Write-Warning $psitem.Exception.StackTrace 
        }
    }
    Catch{
        Write-Warning "Unable to uninstall $name due to unhandled exception"
        Write-Warning $psitem.Exception.StackTrace 
    }
}
function Set-WinUtilDNS {
    <#
    
        .DESCRIPTION
        This function will set the DNS of all interfaces that are in the "Up" state. It will lookup the values from the DNS.Json file

        .EXAMPLE

        Set-WinUtilDNS -DNSProvider "google"
    
    #>
    param($DNSProvider)
    if($DNSProvider -eq "Default"){return}
    Try{
        $Adapters = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
        Write-Host "Ensuring DNS is set to $DNSProvider on the following interfaces"
        Write-Host $($Adapters | Out-String)

        Foreach ($Adapter in $Adapters){
            if($DNSProvider -eq "DHCP"){
                Set-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -ResetServerAddresses
            }
            Else{
                Set-DnsClientServerAddress -InterfaceIndex $Adapter.ifIndex -ServerAddresses ("$($sync.configs.dns.$DNSProvider.Primary)", "$($sync.configs.dns.$DNSProvider.Secondary)")
            }
        }
    }
    Catch{
        Write-Warning "Unable to set DNS Provider due to an unhandled exception"
        Write-Warning $psitem.Exception.StackTrace 
    }
}
function Set-WinUtilRegistry {
    <#
    
        .DESCRIPTION
        This function will make all modifications to the registry

        .EXAMPLE

        Set-WinUtilRegistry -Name "PublishUserActivities" -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Type "DWord" -Value "0"
    
    #>    
    param (
        $Name,
        $Path,
        $Type,
        $Value
    )

    Try{      
        if(!(Test-Path 'HKU:\')){New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS}

        If (!(Test-Path $Path)) {
            Write-Host "$Path was not found, Creating..."
            New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
        }

        Write-Host "Set $Path\$Name to $Value"
        Set-ItemProperty -Path $Path -Name $Name -Type $Type -Value $Value -Force -ErrorAction Stop | Out-Null
    }
    Catch [System.Security.SecurityException] {
        Write-Warning "Unable to set $Path\$Name to $Value due to a Security Exception"
    }
    Catch [System.Management.Automation.ItemNotFoundException] {
        Write-Warning $psitem.Exception.ErrorRecord
    }
    Catch{
        Write-Warning "Unable to set $Name due to unhandled exception"
        Write-Warning $psitem.Exception.StackTrace
    }
}
function Set-WinUtilScheduledTask {
    <#
    
        .DESCRIPTION
        This function will enable/disable the provided Scheduled Task

        .EXAMPLE

        Set-WinUtilScheduledTask -Name "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" -State "Disabled"
    
    #>
    param (
        $Name,
        $State
    )

    Try{
        if($State -eq "Disabled"){
            Write-Host "Disabling Scheduled Task $Name"
            Disable-ScheduledTask -TaskName $Name -ErrorAction Stop
        }
        if($State -eq "Enabled"){
            Write-Host "Enabling Scheduled Task $Name"
            Enable-ScheduledTask -TaskName $Name -ErrorAction Stop
        }
    }
    Catch [System.Exception]{
        if($psitem.Exception.Message -like "*The system cannot find the file specified*"){
            Write-Warning "Scheduled Task $name was not Found"
        }
        Else{
            Write-Warning "Unable to set $Name due to unhandled exception"
            Write-Warning $psitem.Exception.Message
        }
    }
    Catch{
        Write-Warning "Unable to run script for $name due to unhandled exception"
        Write-Warning $psitem.Exception.StackTrace 
    }
}
Function Set-WinUtilService {
    <#
    
        .DESCRIPTION
        This function will change the startup type of services and start/stop them as needed

        .EXAMPLE

        Set-WinUtilService -Name "HomeGroupListener" -StartupType "Manual"
    
    #>   
    param (
        $Name,
        $StartupType
    )
    Try{
        Write-Host "Setting Services $Name to $StartupType"
        Set-Service -Name $Name -StartupType $StartupType -ErrorAction Stop

        if($StartupType -eq "Disabled"){
            Write-Host "Stopping $Name"
            Stop-Service -Name $Name -Force -ErrorAction Stop
        }
        if($StartupType -eq "Enabled"){
            Write-Host "Starting $Name"
            Start-Service -Name $Name -Force -ErrorAction Stop
        }
    }
    Catch [System.Exception]{
        if($psitem.Exception.Message -like "*Cannot find any service with service name*" -or 
           $psitem.Exception.Message -like "*was not found on computer*"){
            Write-Warning "Service $name was not Found"
        }
        Else{
            Write-Warning "Unable to set $Name due to unhandled exception"
            Write-Warning $psitem.Exception.Message
        }
    }
    Catch{
        Write-Warning "Unable to set $Name due to unhandled exception"
        Write-Warning $psitem.Exception.StackTrace
    }
}
function Test-WinUtilPackageManager {
    <#
    
        .DESCRIPTION
        Checks for Winget or Choco depending on the paramater
    
    #>

    Param(
        [System.Management.Automation.SwitchParameter]$winget,
        [System.Management.Automation.SwitchParameter]$choco
    )

    if($winget){
        if (Test-Path ~\AppData\Local\Microsoft\WindowsApps\winget.exe) {
            return $true
        }
    }

    if($choco){
        if ((Get-Command -Name choco -ErrorAction Ignore) -and ($chocoVersion = (Get-Item "$env:ChocolateyInstall\choco.exe" -ErrorAction Ignore).VersionInfo.ProductVersion)){
            return $true
        }
    }

    return $false
}
Function Update-WinUtilProgramWinget {

    <#
    
        .DESCRIPTION
        This will update programs via Winget using a new powershell.exe instance to prevent the GUI from locking up.
    
    #>

    [ScriptBlock]$wingetinstall = {

        $host.ui.RawUI.WindowTitle = """Winget Install"""

        Start-Transcript $ENV:TEMP\winget-update.log -Append
        winget upgrade --all

        Pause
    }

    $global:WinGetInstall = Start-Process -Verb runas powershell -ArgumentList "-command invoke-command -scriptblock {$wingetinstall} -argumentlist '$($ProgramsToInstall -join ",")'" -PassThru

}
function Invoke-WPFButton {

    <#
    
        .DESCRIPTION
        Meant to make creating buttons easier. There is a section below in the gui that will assign this function to every button.
        This way you can dictate what each button does from this function. 
    
        Input will be the name of the button that is clicked. 
    #>
    
    Param ([string]$Button) 

    #Use this to get the name of the button
    #[System.Windows.MessageBox]::Show("$Button","Chris Titus Tech's Windows Utility","OK","Info")

    Switch -Wildcard ($Button){

        "WPFTab?BT" {Invoke-WPFTab $Button}
        "WPFinstall" {Invoke-WPFInstall}
        "WPFuninstall" {Invoke-WPFUnInstall}
        "WPFInstallUpgrade" {Invoke-WPFInstallUpgrade}
        "WPFdesktop" {Invoke-WPFPresets "Desktop"}
        "WPFlaptop" {Invoke-WPFPresets "laptop"}
        "WPFminimal" {Invoke-WPFPresets "minimal"}
        "WPFexport" {Invoke-WPFImpex -type "export" -CheckBox "WPFTweaks"}
        "WPFimport" {Invoke-WPFImpex -type "import" -CheckBox "WPFTweaks"}
        "WPFexportWinget" {Invoke-WPFImpex -type "export" -CheckBox "WPFInstall"}
        "WPFimportWinget" {Invoke-WPFImpex -type "import" -CheckBox "WPFInstall"}
        "WPFclear" {Invoke-WPFPresets -preset $null -imported $true}
        "WPFclearWinget" {Invoke-WPFPresets -preset $null -imported $true -CheckBox "WPFInstall"}
        "WPFtweaksbutton" {Invoke-WPFtweaksbutton}
        "WPFAddUltPerf" {Invoke-WPFUltimatePerformance -State "Enabled"}
        "WPFRemoveUltPerf" {Invoke-WPFUltimatePerformance -State "Disabled"}
        "WPFToggleDarkMode" {Invoke-WPFDarkMode -DarkMoveEnabled $(Get-WinUtilDarkMode)}
        "WPFundoall" {Invoke-WPFundoall}
        "WPFFeatureInstall" {Invoke-WPFFeatureInstall}
        "WPFPanelDISM" {Invoke-WPFPanelDISM}
        "WPFPanelAutologin" {Invoke-WPFPanelAutologin}
        "WPFPanelcontrol" {Invoke-WPFControlPanel -Panel $button}
        "WPFPanelnetwork" {Invoke-WPFControlPanel -Panel $button}
        "WPFPanelpower" {Invoke-WPFControlPanel -Panel $button}
        "WPFPanelsound" {Invoke-WPFControlPanel -Panel $button}
        "WPFPanelsystem" {Invoke-WPFControlPanel -Panel $button}
        "WPFPaneluser" {Invoke-WPFControlPanel -Panel $button}
        "WPFUpdatesdefault" {Invoke-WPFUpdatesdefault}
        "WPFFixesUpdate" {Invoke-WPFFixesUpdate}
        "WPFUpdatesdisable" {Invoke-WPFUpdatesdisable}
        "WPFUpdatessecurity" {Invoke-WPFUpdatessecurity}
        "WPFWinUtilShortcut" {Invoke-WPFShortcut -ShortcutToAdd "WinUtil"}
        "WPFGetInstalled" {Invoke-WPFGetInstalled -CheckBox "winget"}
        "WPFGetInstalledTweaks" {Invoke-WPFGetInstalled -CheckBox "tweaks"}
    }
}
function Invoke-WPFControlPanel {
        <#
    
        .DESCRIPTION
        Simple Switch for lagacy windows
    
    #>
    param($Panel)

    switch ($Panel){
        "WPFPanelcontrol" {cmd /c control}
        "WPFPanelnetwork" {cmd /c ncpa.cpl}
        "WPFPanelpower"   {cmd /c powercfg.cpl}
        "WPFPanelsound"   {cmd /c mmsys.cpl}
        "WPFPanelsystem"  {cmd /c sysdm.cpl}
        "WPFPaneluser"    {cmd /c "control userpasswords2"}
    }
}
Function Invoke-WPFDarkMode {
        <#
    
        .DESCRIPTION
        Sets Dark Mode on or off
    
    #>
    Param($DarkMoveEnabled)
    Try{
        if ($DarkMoveEnabled -eq $false){
            Write-Host "Enabling Dark Mode"
            $DarkMoveValue = 0
        }
        else {
            Write-Host "Disabling Dark Mode"
            $DarkMoveValue = 1
        }
    
        $Theme = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        Set-ItemProperty -Path $Theme -Name AppsUseLightTheme -Value $DarkMoveValue
        Set-ItemProperty -Path $Theme -Name SystemUsesLightTheme -Value $DarkMoveValue
    }
    Catch [System.Security.SecurityException] {
        Write-Warning "Unable to set $Path\$Name to $Value due to a Security Exception"
    }
    Catch [System.Management.Automation.ItemNotFoundException] {
        Write-Warning $psitem.Exception.ErrorRecord
    }
    Catch{
        Write-Warning "Unable to set $Name due to unhandled exception"
        Write-Warning $psitem.Exception.StackTrace
    }
}
function Invoke-WPFFeatureInstall {
        <#
    
        .DESCRIPTION
        GUI Function to install Windows Features
    
    #>

    if($sync.ProcessRunning){
        $msg = "Install process is currently running."
        [System.Windows.MessageBox]::Show($msg, "Winutil", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $Features = Get-WinUtilCheckBoxes -Group "WPFFeature"

    Invoke-WPFRunspace -ArgumentList $Features -ScriptBlock {
        param($Features)

        $sync.ProcessRunning = $true

        Invoke-WinUtilFeatureInstall $Features

        $sync.ProcessRunning = $false
        Write-Host "==================================="
        Write-Host "---   Features are Installed    ---"
        Write-Host "---  A Reboot may be required   ---"
        Write-Host "==================================="
    
        $ButtonType = [System.Windows.MessageBoxButton]::OK
        $MessageboxTitle = "All features are now installed "
        $Messageboxbody = ("Done")
        $MessageIcon = [System.Windows.MessageBoxImage]::Information
    
        [System.Windows.MessageBox]::Show($Messageboxbody, $MessageboxTitle, $ButtonType, $MessageIcon)
    }
}
function Invoke-WPFFixesUpdate {

    <#
    
        .DESCRIPTION
        PlaceHolder
    
    #>

    ### Reset Windows Update Script - reregister dlls, services, and remove registry entires.
    Write-Host "1. Stopping Windows Update Services..."
    Stop-Service -Name BITS
    Stop-Service -Name wuauserv
    Stop-Service -Name appidsvc
    Stop-Service -Name cryptsvc

    Write-Host "2. Remove QMGR Data file..."
    Remove-Item "$env:allusersprofile\Application Data\Microsoft\Network\Downloader\qmgr*.dat" -ErrorAction SilentlyContinue

    Write-Host "3. Renaming the Software Distribution and CatRoot Folder..."
    Rename-Item $env:systemroot\SoftwareDistribution SoftwareDistribution.bak -ErrorAction SilentlyContinue
    Rename-Item $env:systemroot\System32\Catroot2 catroot2.bak -ErrorAction SilentlyContinue

    Write-Host "4. Removing old Windows Update log..."
    Remove-Item $env:systemroot\WindowsUpdate.log -ErrorAction SilentlyContinue

    Write-Host "5. Resetting the Windows Update Services to defualt settings..."
    "sc.exe sdset bits D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)"
    "sc.exe sdset wuauserv D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)"
    Set-Location $env:systemroot\system32

    Write-Host "6. Registering some DLLs..."
    regsvr32.exe /s atl.dll
    regsvr32.exe /s urlmon.dll
    regsvr32.exe /s mshtml.dll
    regsvr32.exe /s shdocvw.dll
    regsvr32.exe /s browseui.dll
    regsvr32.exe /s jscript.dll
    regsvr32.exe /s vbscript.dll
    regsvr32.exe /s scrrun.dll
    regsvr32.exe /s msxml.dll
    regsvr32.exe /s msxml3.dll
    regsvr32.exe /s msxml6.dll
    regsvr32.exe /s actxprxy.dll
    regsvr32.exe /s softpub.dll
    regsvr32.exe /s wintrust.dll
    regsvr32.exe /s dssenh.dll
    regsvr32.exe /s rsaenh.dll
    regsvr32.exe /s gpkcsp.dll
    regsvr32.exe /s sccbase.dll
    regsvr32.exe /s slbcsp.dll
    regsvr32.exe /s cryptdlg.dll
    regsvr32.exe /s oleaut32.dll
    regsvr32.exe /s ole32.dll
    regsvr32.exe /s shell32.dll
    regsvr32.exe /s initpki.dll
    regsvr32.exe /s wuapi.dll
    regsvr32.exe /s wuaueng.dll
    regsvr32.exe /s wuaueng1.dll
    regsvr32.exe /s wucltui.dll
    regsvr32.exe /s wups.dll
    regsvr32.exe /s wups2.dll
    regsvr32.exe /s wuweb.dll
    regsvr32.exe /s qmgr.dll
    regsvr32.exe /s qmgrprxy.dll
    regsvr32.exe /s wucltux.dll
    regsvr32.exe /s muweb.dll
    regsvr32.exe /s wuwebv.dll

    Write-Host "7) Removing WSUS client settings..."
    REG DELETE "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v AccountDomainSid /f
    REG DELETE "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v PingID /f
    REG DELETE "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v SusClientId /f

    Write-Host "8) Resetting the WinSock..."
    netsh winsock reset
    netsh winhttp reset proxy
    netsh int ip reset

    Write-Host "9) Delete all BITS jobs..."
    Get-BitsTransfer | Remove-BitsTransfer

    Write-Host "10) Attempting to install the Windows Update Agent..."
    If ([System.Environment]::Is64BitOperatingSystem) {
        wusa Windows8-RT-KB2937636-x64 /quiet
    }
    else {
        wusa Windows8-RT-KB2937636-x86 /quiet
    }

    Write-Host "11) Starting Windows Update Services..."
    Start-Service -Name BITS
    Start-Service -Name wuauserv
    Start-Service -Name appidsvc
    Start-Service -Name cryptsvc

    Write-Host "12) Forcing discovery..."
    wuauclt /resetauthorization /detectnow

    Write-Host "Process complete. Please reboot your computer."

    $ButtonType = [System.Windows.MessageBoxButton]::OK
    $MessageboxTitle = "Reset Windows Update "
    $Messageboxbody = ("Stock settings loaded.`n Please reboot your computer")
    $MessageIcon = [System.Windows.MessageBoxImage]::Information

    [System.Windows.MessageBox]::Show($Messageboxbody, $MessageboxTitle, $ButtonType, $MessageIcon)
    Write-Host "================================="
    Write-Host "-- Reset ALL Updates to Factory -"
    Write-Host "================================="
}
Function Invoke-WPFFormVariables {
    <#
    
        .DESCRIPTION
        PlaceHolder
    
    #>
    #If ($global:ReadmeDisplay -ne $true) { Write-Host "If you need to reference this display again, run Get-FormVariables" -ForegroundColor Yellow; $global:ReadmeDisplay = $true }

    Write-Host ""
    Write-Host "  ██╗    ██╗██╗███╗   ██╗    ██╗   ██╗████████╗██╗██╗       " -BackgroundColor Black -ForegroundColor Magenta
    Write-Host "  ██║    ██║██║████╗  ██║    ██║   ██║╚══██╔══╝██║██║       " -BackgroundColor Black -ForegroundColor Magenta
    Write-Host "  ██║ █╗ ██║██║██╔██╗ ██║    ██║   ██║   ██║   ██║██║       " -BackgroundColor Black -ForegroundColor Magenta
    Write-Host "  ██║███╗██║██║██║╚██╗██║    ██║   ██║   ██║   ██║██║       " -BackgroundColor Black -ForegroundColor Magenta
    Write-Host "  ╚███╔███╔╝██║██║ ╚████║    ╚██████╔╝   ██║   ██║███████╗  " -BackgroundColor Black -ForegroundColor Magenta
    Write-Host "   ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝     ╚═════╝    ╚═╝   ╚═╝╚══════╝  " -BackgroundColor Black -ForegroundColor Magenta
    Write-Host ""
    
    Write-Host "====Chris Titus Tech====="
    Write-Host "=====Windows Toolbox====="
    Write-Host "=====Forked by 99oblivius====="


    #====DEBUG GUI Elements====

    #Write-Host "Found the following interactable elements from our form" -ForegroundColor Cyan
    #get-variable WPF*
}
function Invoke-WPFGetInstalled {
    <#

    .DESCRIPTION
    placeholder

    #>
    param($checkbox)

    if($sync.ProcessRunning){
        $msg = "Install process is currently running."
        [System.Windows.MessageBox]::Show($msg, "Winutil", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    if(!(Test-WinUtilPackageManager -winget) -and $checkbox -eq "winget"){
        Write-Host "==========================================="
        Write-Host "--       Winget is not installed        ---"
        Write-Host "==========================================="
        return
    }

    Invoke-WPFRunspace -ArgumentList $checkbox -ScriptBlock {
        param($checkbox)

        $sync.ProcessRunning = $true

        if($checkbox -eq "winget"){
            Write-Host "Getting Installed Programs..."
        }
        if($checkbox -eq "tweaks"){
            Write-Host "Getting Installed Tweaks..."
        }
        
        $Checkboxes = Invoke-WinUtilCurrentSystem -CheckBox $checkbox
        
        $sync.form.Dispatcher.invoke({
            foreach($checkbox in $Checkboxes){
                $sync.$checkbox.ischecked = $True
            }
        })

        Write-Host "Done..."
        $sync.ProcessRunning = $false
    }
}
function Invoke-WPFImpex {
    <#
    
        .DESCRIPTION
        This function handles importing and exporting of the checkboxes checked for the tweaks section

        .EXAMPLE

        Invoke-WPFImpex -type "export"
    
    #>
    param(
        $type,
        $checkbox
    )

    if ($type -eq "export"){
        $FileBrowser = New-Object System.Windows.Forms.SaveFileDialog
    }
    if ($type -eq "import"){
        $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog 
    }

    $FileBrowser.InitialDirectory = [Environment]::GetFolderPath('Desktop')
    $FileBrowser.Filter = "JSON Files (*.json)|*.json"
    $FileBrowser.ShowDialog() | Out-Null

    if($FileBrowser.FileName -eq ""){
        return
    }
    
    if ($type -eq "export"){
        $jsonFile = Get-WinUtilCheckBoxes $checkbox -unCheck $false
        $jsonFile | ConvertTo-Json | Out-File $FileBrowser.FileName -Force
    }
    if ($type -eq "import"){
        $jsonFile = Get-Content $FileBrowser.FileName | ConvertFrom-Json
        Invoke-WPFPresets -preset $jsonFile -imported $true -CheckBox $checkbox
    }
}
function Invoke-WPFInstall {
    <#
    
        .DESCRIPTION
        PlaceHolder
    
    #>

    if($sync.ProcessRunning){
        $msg = "Install process is currently running."
        [System.Windows.MessageBox]::Show($msg, "Winutil", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $WingetInstall = Get-WinUtilCheckBoxes -Group "WPFInstall"

    if ($wingetinstall.Count -eq 0) {
        $WarningMsg = "Please select the program(s) to install"
        [System.Windows.MessageBox]::Show($WarningMsg, $AppTitle, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    Invoke-WPFRunspace -ArgumentList $WingetInstall -scriptblock {
        param($WingetInstall)
        try{
            $sync.ProcessRunning = $true

            # Ensure winget is installed
            Install-WinUtilWinget

            # Install all winget programs in new window
            Install-WinUtilProgramWinget -ProgramsToInstall $WingetInstall

            $ButtonType = [System.Windows.MessageBoxButton]::OK
            $MessageboxTitle = "Installs are Finished "
            $Messageboxbody = ("Done")
            $MessageIcon = [System.Windows.MessageBoxImage]::Information
        
            [System.Windows.MessageBox]::Show($Messageboxbody, $MessageboxTitle, $ButtonType, $MessageIcon)

            Write-Host "==========================================="
            Write-Host "--      Installs have finished          ---"
            Write-Host "==========================================="
        }
        Catch {
            Write-Host "==========================================="
            Write-Host "--      Winget failed to install        ---"
            Write-Host "==========================================="
        }
        $sync.ProcessRunning = $False
    }
}
function Invoke-WPFInstallUpgrade {
    <#
    
        .DESCRIPTION
        PlaceHolder
    
    #>
    if(!(Test-WinUtilPackageManager -winget)){
        Write-Host "==========================================="
        Write-Host "--       Winget is not installed        ---"
        Write-Host "==========================================="
        return
    }

    if(Get-WinUtilInstallerProcess -Process $global:WinGetInstall){
        $msg = "Install process is currently running. Please check for a powershell window labled 'Winget Install'"
        [System.Windows.MessageBox]::Show($msg, "Winutil", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    Update-WinUtilProgramWinget

    Write-Host "==========================================="
    Write-Host "--           Updates started            ---"
    Write-Host "-- You can close this window if desired ---"
    Write-Host "==========================================="
}
function Invoke-WPFPanelAutologin {
    <#
    
        .DESCRIPTION
        PlaceHolder
    
    #>
    curl.exe -ss "https://live.sysinternals.com/Autologon.exe" -o $env:temp\autologin.exe # Official Microsoft recommendation https://learn.microsoft.com/en-us/sysinternals/downloads/autologon
    cmd /c $env:temp\autologin.exe
}
function Invoke-WPFPanelDISM {
    <#
    
        .DESCRIPTION
        PlaceHolder
    
    #>
    Start-Process PowerShell -ArgumentList "Write-Host '(1/4) Chkdsk' -ForegroundColor Green; Chkdsk /scan;
    Write-Host '`n(2/4) SFC - 1st scan' -ForegroundColor Green; sfc /scannow;
    Write-Host '`n(3/4) DISM' -ForegroundColor Green; DISM /Online /Cleanup-Image /Restorehealth;
    Write-Host '`n(4/4) SFC - 2nd scan' -ForegroundColor Green; sfc /scannow;
    Read-Host '`nPress Enter to Continue'" -verb runas
}
function Invoke-WPFPresets {
    <#

        .DESCRIPTION
        Meant to make settings presets easier in the tweaks tab. Will pull the data from config/preset.json

    #>

    param(
        $preset,
        [bool]$imported = $false,
        $checkbox = "WPFTweaks"
    )

    if($imported -eq $true){
        $CheckBoxesToCheck = $preset
    }
    Else{
        $CheckBoxesToCheck = $sync.configs.preset.$preset
    }

    if($checkbox -eq "WPFTweaks"){
        $filter = Get-WinUtilVariables -Type Checkbox | Where-Object {$psitem -like "*tweaks*"}
        $sync.GetEnumerator() | Where-Object {$psitem.Key -in $filter} | ForEach-Object {
            if ($CheckBoxesToCheck -contains $PSItem.name){
                $sync.$($PSItem.name).ischecked = $true
            }
            else{$sync.$($PSItem.name).ischecked = $false}
        }
    }
    if($checkbox -eq "WPFInstall"){

        $filter = Get-WinUtilVariables -Type Checkbox | Where-Object {$psitem -like "WPFInstall*"}
        $sync.GetEnumerator() | Where-Object {$psitem.Key -in $filter} | ForEach-Object {
            if($($sync.configs.applications.$($psitem.name).winget) -in $CheckBoxesToCheck){
                $sync.$($PSItem.name).ischecked = $true
            }
            else{$sync.$($PSItem.name).ischecked = $false}
        }
    }
}
function Invoke-WPFRunspace {

    <#
    
        .DESCRIPTION
        Simple function to make it easier to invoke a runspace from inside the script. 

        .EXAMPLE

        $params = @{
            ScriptBlock = $sync.ScriptsInstallPrograms
            ArgumentList = "Installadvancedip,Installbitwarden"
            Verbose = $true
        }

        Invoke-WPFRunspace @params
    
    #>

    [CmdletBinding()]
    Param (
        $ScriptBlock,
        $ArgumentList
    ) 

    #Crate a PowerShell instance.
    $script:powershell = [powershell]::Create()

    #Add Scriptblock and Arguments to runspace
    $script:powershell.AddScript($ScriptBlock)
    $script:powershell.AddArgument($ArgumentList)
    $script:powershell.RunspacePool = $sync.runspace
    
    #Run our RunspacePool.
    $script:handle = $script:powershell.BeginInvoke()

    #Cleanup our RunspacePool threads when they are complete ie. GC.
    if ($script:handle.IsCompleted)
    {
        $script:powershell.EndInvoke($script:handle)
        $script:powershell.Dispose()
        $sync.runspace.Dispose()
        $sync.runspace.Close()
        [System.GC]::Collect()
    }
}
function Invoke-WPFShortcut {
    <#

        .DESCRIPTION
        Creates a shortcut

    #>
    param($ShortcutToAdd)

    Switch ($ShortcutToAdd) {
        "WinUtil" {
            $SourceExe = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" 
            $IRM = 'irm https://christitus.com/win | iex'
            $Powershell = '-ExecutionPolicy Bypass -Command "Start-Process powershell.exe -verb runas -ArgumentList'
            $ArgumentsToSourceExe = "$powershell '$IRM'"
            $DestinationName = "WinUtil.lnk"
        }
    }

    $FileBrowser = New-Object System.Windows.Forms.SaveFileDialog
    $FileBrowser.InitialDirectory = [Environment]::GetFolderPath('Desktop')
    $FileBrowser.Filter = "Shortcut Files (*.lnk)|*.lnk"
    $FileBrowser.FileName = $DestinationName
    $FileBrowser.ShowDialog() | Out-Null

    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($FileBrowser.FileName)
    $Shortcut.TargetPath = $SourceExe
    $Shortcut.Arguments = $ArgumentsToSourceExe
    $Shortcut.Save()
    
    Write-Host "Shortcut for $ShortcutToAdd has been saved to $($FileBrowser.FileName)"
}
function Invoke-WPFTab {

    <#
    
        .DESCRIPTION
        Sole purpose of this fuction reduce duplicated code for switching between tabs. 
    
    #>

    Param ($ClickedTab)
    $Tabs = Get-WinUtilVariables | Where-Object {$psitem -like "WPFTab?BT"}
    $TabNav = Get-WinUtilVariables | Where-Object {$psitem -like "WPFTabNav"}
    $x = [int]($ClickedTab -replace "WPFTab","" -replace "BT","") - 1

    0..($Tabs.Count -1 ) | ForEach-Object {
        
        if ($x -eq $psitem){
            $sync.$TabNav.Items[$psitem].IsSelected = $true
        }
        else{
            $sync.$TabNav.Items[$psitem].IsSelected = $false
        }
    }
}
function Invoke-WPFtweaksbutton {
  <#
  
      .DESCRIPTION
      PlaceHolder
  
  #>

  if($sync.ProcessRunning){
    $msg = "Install process is currently running."
    [System.Windows.MessageBox]::Show($msg, "Winutil", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    return
  }

  $Tweaks = Get-WinUtilCheckBoxes -Group "WPFTweaks"

  Set-WinUtilDNS -DNSProvider $sync["WPFchangedns"].text

  if ($tweaks.count -eq 0 -and  $sync["WPFchangedns"].text -eq "Default"){
    $msg = "Please check the tweaks you wish to perform."
    [System.Windows.MessageBox]::Show($msg, "Winutil", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
    return
  }

  Invoke-WPFRunspace -ArgumentList $Tweaks -ScriptBlock {
    param($Tweaks)

    $sync.ProcessRunning = $true

    Foreach ($tweak in $tweaks){
        Invoke-WinUtilTweaks $tweak
    }

    $sync.ProcessRunning = $false
    Write-Host "================================="
    Write-Host "--     Tweaks are Finished    ---"
    Write-Host "================================="

    $ButtonType = [System.Windows.MessageBoxButton]::OK
    $MessageboxTitle = "Tweaks are Finished "
    $Messageboxbody = ("Done")
    $MessageIcon = [System.Windows.MessageBoxImage]::Information

    [System.Windows.MessageBox]::Show($Messageboxbody, $MessageboxTitle, $ButtonType, $MessageIcon)
  }
}
Function Invoke-WPFUltimatePerformance {
    <#
    
        .DESCRIPTION
        PlaceHolder
    
    #>
    param($State)
    Try{

        if($state -eq "Enabled"){
            # Define the name and GUID of the power scheme you want to add
            $powerSchemeName = "Ultimate Performance"
            $powerSchemeGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"

            # Get all power schemes
            $schemes = powercfg /list | Out-String -Stream

            # Find the scheme you want to add
            $ultimateScheme = $schemes | Where-Object { $_ -match $powerSchemeName }

            # If the scheme does not exist, add it
            if ($null -eq $ultimateScheme) {
                Write-Host "Power scheme '$powerSchemeName' not found. Adding..."

                # Add the power scheme
                powercfg /duplicatescheme $powerSchemeGuid

                Write-Host "Power scheme added successfully."
            }
            else {
                Write-Host "Power scheme '$powerSchemeName' already exists."
            }           
        }
        elseif($state -eq "Disabled"){
                # Define the name of the power scheme you want to remove
                $powerSchemeName = "Ultimate Performance"

                # Get all power schemes
                $schemes = powercfg /list | Out-String -Stream

                # Find the scheme you want to remove
                $ultimateScheme = $schemes | Where-Object { $_ -match $powerSchemeName }

                # If the scheme exists, remove it
                if ($null -ne $ultimateScheme) {
                    # Extract the GUID of the power scheme
                    $guid = ($ultimateScheme -split '\s+')[3]

                    if($null -ne $guid){
                        Write-Host "Found power scheme '$powerSchemeName' with GUID $guid. Removing..."
                        
                        # Remove the power scheme
                        powercfg /delete $guid
                        
                        Write-Host "Power scheme removed successfully."
                    }
                    else {
                        Write-Host "Could not find GUID for power scheme '$powerSchemeName'."
                    }
                }
                else {
                    Write-Host "Power scheme '$powerSchemeName' not found."
                }

            }
        
    }
    Catch{
        Write-Warning $psitem.Exception.Message
    }
}
function Invoke-WPFundoall {
    <#
    
        .DESCRIPTION
        PlaceHolder
    
    #>

    if($sync.ProcessRunning){
        $msg = "Install process is currently running."
        [System.Windows.MessageBox]::Show($msg, "Winutil", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $Tweaks = Get-WinUtilCheckBoxes -Group "WPFTweaks"

    if ($tweaks.count -eq 0){
        $msg = "Please check the tweaks you wish to undo."
        [System.Windows.MessageBox]::Show($msg, "Winutil", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }      
    
    Invoke-WPFRunspace -ArgumentList $Tweaks -ScriptBlock {
        param($Tweaks)

        $sync.ProcessRunning = $true

        Foreach ($tweak in $tweaks){
            Invoke-WinUtilTweaks $tweak -undo $true
        }

        $sync.ProcessRunning = $false
        Write-Host "=================================="
        Write-Host "---  Undo Tweaks are Finished  ---"
        Write-Host "=================================="

        $ButtonType = [System.Windows.MessageBoxButton]::OK
        $MessageboxTitle = "Tweaks are Finished "
        $Messageboxbody = ("Done")
        $MessageIcon = [System.Windows.MessageBoxImage]::Information

        [System.Windows.MessageBox]::Show($Messageboxbody, $MessageboxTitle, $ButtonType, $MessageIcon)
    }

<#

    Write-Host "Creating Restore Point in case something bad happens"
    Enable-ComputerRestore -Drive "$env:SystemDrive"
    Checkpoint-Computer -Description "RestorePoint1" -RestorePointType "MODIFY_SETTINGS"

    Write-Host "Enabling Telemetry..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 1
    Write-Host "Enabling Wi-Fi Sense"
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" -Name "Value" -Type DWord -Value 1
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots" -Name "Value" -Type DWord -Value 1
    Write-Host "Enabling Application suggestions..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "ContentDeliveryAllowed" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "OemPreInstalledAppsEnabled" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "PreInstalledAppsEnabled" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "PreInstalledAppsEverEnabled" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338387Enabled" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338388Enabled" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-353698Enabled" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SystemPaneSuggestionsEnabled" -Type DWord -Value 1
    If (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent") {
        Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Recurse -ErrorAction SilentlyContinue
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Type DWord -Value 0
    Write-Host "Enabling Activity History..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Type DWord -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Type DWord -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Type DWord -Value 1
    Write-Host "Enable Location Tracking..."
    If (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location") {
        Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Recurse -ErrorAction SilentlyContinue
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Type String -Value "Allow"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Type DWord -Value 1
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" -Name "Status" -Type DWord -Value 1
    Write-Host "Enabling automatic Maps updates..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\Maps" -Name "AutoUpdateEnabled" -Type DWord -Value 1
    Write-Host "Enabling Feedback..."
    If (Test-Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules") {
        Remove-Item -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Recurse -ErrorAction SilentlyContinue
    }
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" -Name "NumberOfSIUFInPeriod" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DoNotShowFeedbackNotifications" -Type DWord -Value 0
    Write-Host "Enabling Tailored Experiences..."
    If (Test-Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent") {
        Remove-Item -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Recurse -ErrorAction SilentlyContinue
    }
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableTailoredExperiencesWithDiagnosticData" -Type DWord -Value 0
    Write-Host "Disabling Advertising ID..."
    If (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo") {
        Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Recurse -ErrorAction SilentlyContinue
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Type DWord -Value 0
    Write-Host "Allow Error reporting..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Type DWord -Value 0
    Write-Host "Allowing Diagnostics Tracking Service..."
    Stop-Service "DiagTrack" -WarningAction SilentlyContinue
    Set-Service "DiagTrack" -StartupType Manual
    Write-Host "Allowing WAP Push Service..."
    Stop-Service "dmwappushservice" -WarningAction SilentlyContinue
    Set-Service "dmwappushservice" -StartupType Manual
    Write-Host "Allowing Home Groups services..."
    Stop-Service "HomeGroupListener" -WarningAction SilentlyContinue
    Set-Service "HomeGroupListener" -StartupType Manual
    Stop-Service "HomeGroupProvider" -WarningAction SilentlyContinue
    Set-Service "HomeGroupProvider" -StartupType Manual
    Write-Host "Enabling Storage Sense..."
    New-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" | Out-Null
    Write-Host "Allowing Superfetch service..."
    Stop-Service "SysMain" -WarningAction SilentlyContinue
    Set-Service "SysMain" -StartupType Manual
    Write-Host "Setting BIOS time to Local Time instead of UTC..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" -Name "RealTimeIsUniversal" -Type DWord -Value 0
    Write-Host "Enabling Hibernation..."
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Session Manager\Power" -Name "HibernteEnabled" -Type Dword -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" -Name "ShowHibernateOption" -Type Dword -Value 1
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -Name "NoLockScreen" -ErrorAction SilentlyContinue

    Write-Host "Hiding file operations details..."
    If (Test-Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager") {
        Remove-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager" -Recurse -ErrorAction SilentlyContinue
    }
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager" -Name "EnthusiastMode" -Type DWord -Value 0
    Write-Host "Showing Task View button..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Name "PeopleBand" -Type DWord -Value 1

    Write-Host "Changing default Explorer view to Quick Access..."
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Type DWord -Value 0

    Write-Host "Unrestricting AutoLogger directory"
    $autoLoggerDir = "$env:PROGRAMDATA\Microsoft\Diagnosis\ETLLogs\AutoLogger"
    icacls $autoLoggerDir /grant:r SYSTEM:`(OI`)`(CI`)F | Out-Null

    Write-Host "Enabling and starting Diagnostics Tracking Service"
    Set-Service "DiagTrack" -StartupType Automatic
    Start-Service "DiagTrack"

    Write-Host "Hiding known file extensions"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Type DWord -Value 1

    Write-Host "Reset Local Group Policies to Stock Defaults"
    # cmd /c secedit /configure /cfg %windir%\inf\defltbase.inf /db defltbase.sdb /verbose
    cmd /c RD /S /Q "%WinDir%\System32\GroupPolicyUsers"
    cmd /c RD /S /Q "%WinDir%\System32\GroupPolicy"
    cmd /c gpupdate /force
    # Considered using Invoke-GPUpdate but requires module most people won't have installed

    Write-Host "Adjusting visual effects for appearance..."
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Type String -Value 1
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Type String -Value 400
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Type Binary -Value ([byte[]](158, 30, 7, 128, 18, 0, 0, 0))
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Type String -Value 1
    Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name "KeyboardDelay" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewAlphaSelect" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewShadow" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Type DWord -Value 1
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Type DWord -Value 3
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\DWM" -Name "EnableAeroPeek" -Type DWord -Value 1
    Remove-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "HungAppTimeout" -ErrorAction SilentlyContinue
    Write-Host "Restoring Clipboard History..."
    Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Clipboard" -Name "EnableClipboardHistory" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "AllowClipboardHistory" -ErrorAction SilentlyContinue
    Write-Host "Enabling Notifications and Action Center"
    Remove-Item -Path HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer -Force
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled"
    Write-Host "Restoring Default Right Click Menu Layout"
    Remove-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -Confirm:$false -Force

    Write-Host "Reset News and Interests"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" -Name "EnableFeeds" -Type DWord -Value 1
    # Remove "News and Interest" from taskbar
    Set-ItemProperty -Path  "HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds" -Name "ShellFeedsTaskbarViewMode" -Type DWord -Value 0
    Write-Host "Done - Reverted to Stock Settings"

    Write-Host "Essential Undo Completed"

    $ButtonType = [System.Windows.MessageBoxButton]::OK
    $MessageboxTitle = "Undo All"
    $Messageboxbody = ("Done")
    $MessageIcon = [System.Windows.MessageBoxImage]::Information

    [System.Windows.MessageBox]::Show($Messageboxbody, $MessageboxTitle, $ButtonType, $MessageIcon)

    Write-Host "================================="
    Write-Host "---   Undo All is Finished    ---"
    Write-Host "================================="
    #>
}
function Invoke-WPFUnInstall {
    <#
    
        .DESCRIPTION
        PlaceHolder
    
    #>

    if($sync.ProcessRunning){
        $msg = "Install process is currently running."
        [System.Windows.MessageBox]::Show($msg, "Winutil", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $WingetInstall = Get-WinUtilCheckBoxes -Group "WPFInstall"

    if ($wingetinstall.Count -eq 0) {
        $WarningMsg = "Please select the program(s) to install"
        [System.Windows.MessageBox]::Show($WarningMsg, $AppTitle, [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $ButtonType = [System.Windows.MessageBoxButton]::YesNo
    $MessageboxTitle = "Are you sure?"
    $Messageboxbody = ("This will uninstall the following applications `n $WingetInstall")
    $MessageIcon = [System.Windows.MessageBoxImage]::Information

    $confirm = [System.Windows.MessageBox]::Show($Messageboxbody, $MessageboxTitle, $ButtonType, $MessageIcon)

    if($confirm -eq "No"){return}

    Invoke-WPFRunspace -ArgumentList $WingetInstall -scriptblock {
        param($WingetInstall)
        try{
            $sync.ProcessRunning = $true

            # Install all winget programs in new window
            Install-WinUtilProgramWinget -ProgramsToInstall $WingetInstall -Manage "Uninstalling"

            $ButtonType = [System.Windows.MessageBoxButton]::OK
            $MessageboxTitle = "Uninstalls are Finished "
            $Messageboxbody = ("Done")
            $MessageIcon = [System.Windows.MessageBoxImage]::Information
        
            [System.Windows.MessageBox]::Show($Messageboxbody, $MessageboxTitle, $ButtonType, $MessageIcon)

            Write-Host "==========================================="
            Write-Host "--      Uninstalls have finished          ---"
            Write-Host "==========================================="
        }
        Catch {
            Write-Host "==========================================="
            Write-Host "--      Winget failed to install        ---"
            Write-Host "==========================================="
        }
        $sync.ProcessRunning = $False
    }
}
function Invoke-WPFUpdatesdefault {
    <#
    
        .DESCRIPTION
        PlaceHolder
    
    #>
    If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Type DWord -Value 3
    If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Type DWord -Value 1

    $services = @(
        "BITS"
        "wuauserv"
    )

    foreach ($service in $services) {
        # -ErrorAction SilentlyContinue is so it doesn't write an error to stdout if a service doesn't exist

        Write-Host "Setting $service StartupType to Automatic"
        Get-Service -Name $service -ErrorAction SilentlyContinue | Set-Service -StartupType Automatic
    }
    Write-Host "Enabling driver offering through Windows Update..."
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Name "PreventDeviceMetadataFromNetwork" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontPromptForWindowsUpdate" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontSearchWindowsUpdate" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DriverUpdateWizardWuSearchEnabled" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -ErrorAction SilentlyContinue
    Write-Host "Enabling Windows Update automatic restart..."
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUPowerManagement" -ErrorAction SilentlyContinue
    Write-Host "Enabled driver offering through Windows Update"
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "BranchReadinessLevel" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferFeatureUpdatesPeriodInDays" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferQualityUpdatesPeriodInDays " -ErrorAction SilentlyContinue
    Write-Host "================================="
    Write-Host "---  Updates Set to Default   ---"
    Write-Host "================================="
}
function Invoke-WPFUpdatesdisable {
    <#
    
        .DESCRIPTION
        PlaceHolder
    
    #>
    If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Type DWord -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Type DWord -Value 1
    If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Type DWord -Value 0

    $services = @(
        "BITS"
        "wuauserv"
    )

    foreach ($service in $services) {
        # -ErrorAction SilentlyContinue is so it doesn't write an error to stdout if a service doesn't exist

        Write-Host "Setting $service StartupType to Disabled"
        Get-Service -Name $service -ErrorAction SilentlyContinue | Set-Service -StartupType Disabled
    }
    Write-Host "================================="
    Write-Host "---  Updates ARE DISABLED     ---"
    Write-Host "================================="
}
function Invoke-WPFUpdatessecurity {
    <#
    
        .DESCRIPTION
        PlaceHolder
    
    #>
    Write-Host "Disabling driver offering through Windows Update..."
        If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata")) {
            New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Force | Out-Null
        }
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Name "PreventDeviceMetadataFromNetwork" -Type DWord -Value 1
        If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching")) {
            New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Force | Out-Null
        }
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontPromptForWindowsUpdate" -Type DWord -Value 1
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontSearchWindowsUpdate" -Type DWord -Value 1
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DriverUpdateWizardWuSearchEnabled" -Type DWord -Value 0
        If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate")) {
            New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" | Out-Null
        }
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -Type DWord -Value 1
        Write-Host "Disabling Windows Update automatic restart..."
        If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU")) {
            New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force | Out-Null
        }
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -Type DWord -Value 1
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUPowerManagement" -Type DWord -Value 0
        Write-Host "Disabled driver offering through Windows Update"
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "BranchReadinessLevel" -Type DWord -Value 20
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferFeatureUpdatesPeriodInDays" -Type DWord -Value 365
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "DeferQualityUpdatesPeriodInDays " -Type DWord -Value 4

        $ButtonType = [System.Windows.MessageBoxButton]::OK
        $MessageboxTitle = "Set Security Updates"
        $Messageboxbody = ("Recommended Update settings loaded")
        $MessageIcon = [System.Windows.MessageBoxImage]::Information

        [System.Windows.MessageBox]::Show($Messageboxbody, $MessageboxTitle, $ButtonType, $MessageIcon)
        Write-Host "================================="
        Write-Host "-- Updates Set to Recommended ---"
        Write-Host "================================="
}
$inputXML = '<Window x:Class="WinUtility.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:WinUtility"
        mc:Ignorable="d"
        Background="#642b87"
        WindowStartupLocation="CenterScreen"
        Title="Chris Titus Tech''s Windows Utility" Height="800" Width="1200">
    <Window.Resources>
        <Style x:Key="ToggleSwitchStyle" TargetType="CheckBox">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <StackPanel>
                            <Grid>
                                <Border Width="45" 
                                        Height="20"
                                        Background="#7364d1" 
                                        CornerRadius="10" 
                                        Margin="5,0"
                                />
                                <Border Name="WPFToggleSwitchButton"
                                        Width="25" 
                                        Height="25"
                                        Background="Black" 
                                        CornerRadius="12.5" 
                                        HorizontalAlignment="Left"
                                />
                                <ContentPresenter Name="WPFToggleSwitchContent"
                                                  Margin="10,0,0,0"
                                                  Content="{TemplateBinding Content}"
                                                  VerticalAlignment="Center"
                                />
                            </Grid>
                        </StackPanel>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="false">
                                <Trigger.ExitActions>
                                    <RemoveStoryboard BeginStoryboardName="WPFToggleSwitchLeft" />
                                    <BeginStoryboard x:Name="WPFToggleSwitchRight">
                                        <Storyboard>
                                            <ThicknessAnimation Storyboard.TargetProperty="Margin"
                                                    Storyboard.TargetName="WPFToggleSwitchButton"
                                                    Duration="0:0:0:0"
                                                    From="0,0,0,0"
                                                    To="28,0,0,0">
                                            </ThicknessAnimation>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.ExitActions>
                                <Setter TargetName="WPFToggleSwitchButton"
                                        Property="Background"
                                        Value="#fff9f4f4"
                                />
                            </Trigger>
                            <Trigger Property="IsChecked" Value="true">
                                <Trigger.ExitActions>
                                    <RemoveStoryboard BeginStoryboardName="WPFToggleSwitchRight" />
                                    <BeginStoryboard x:Name="WPFToggleSwitchLeft">
                                        <Storyboard>
                                            <ThicknessAnimation Storyboard.TargetProperty="Margin"
                                                    Storyboard.TargetName="WPFToggleSwitchButton"
                                                    Duration="0:0:0:0"
                                                    From="28,0,0,0"
                                                    To="0,0,0,0">
                                            </ThicknessAnimation>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.ExitActions>
                                <Setter TargetName="WPFToggleSwitchButton"
                                        Property="Background"
                                        Value="#ff060600"
                                />
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Border Name="WPFdummy" Grid.Column="0" Grid.Row="0">
        <Viewbox Stretch="Uniform" VerticalAlignment="Top">
            <Grid Background="#777777" ShowGridLines="False" Name="WPFMainGrid">
                <Grid.RowDefinitions>
                    <RowDefinition Height=".1*"/>
                    <RowDefinition Height=".9*"/>
                </Grid.RowDefinitions>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <DockPanel Background="#777777" SnapsToDevicePixels="True" Grid.Row="0" Width="1100">
                    <Image Height="50" Width="100" Name="WPFIcon" SnapsToDevicePixels="True" Source="https://christitus.com/images/logo-full.png" Margin="0,10,0,10"/>
                    <Button Content="Install" HorizontalAlignment="Left" Height="40" Width="100" Background="#501f4a" BorderThickness="0,0,0,0" FontWeight="Bold" Foreground="#ffffff" Name="WPFTab1BT"/>
                    <Button Content="Tweaks" HorizontalAlignment="Left" Height="40" Width="100" Background="#333333" BorderThickness="0,0,0,0" FontWeight="Bold" Foreground="#ffffff" Name="WPFTab2BT"/>
                    <Button Content="Config" HorizontalAlignment="Left" Height="40" Width="100" Background="#b48be0" BorderThickness="0,0,0,0" FontWeight="Bold" Foreground="#ffffff" Name="WPFTab3BT"/>
                    <Button Content="Updates" HorizontalAlignment="Left" Height="40" Width="100" Background="#555555" BorderThickness="0,0,0,0" FontWeight="Bold" Foreground="#ffffff" Name="WPFTab4BT"/>
                </DockPanel>
                <TabControl Grid.Row="1" Padding="-1" Name="WPFTabNav" Background="#501f4a">
                    <TabItem Header="Install" Visibility="Collapsed" Name="WPFTab1">
                        <Grid Background="#501f4a">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Grid.RowDefinitions>
                                <RowDefinition Height=".10*"/>
                                <RowDefinition Height=".90*"/>
                            </Grid.RowDefinitions>

                            <StackPanel Background="#777777" Orientation="Horizontal" Grid.Row="0" HorizontalAlignment="Center" Grid.Column="0" Grid.ColumnSpan="3" Margin="10">
                            <Button Name="WPFGetInstalled" Content=" Select All Installed " Margin="7"/>
                            <Label Content="Winget:" FontSize="17" VerticalAlignment="Center"/>
                            <Button Name="WPFinstall" Content=" Install Selection " Margin="7"/>
                            <Button Name="WPFInstallUpgrade" Content=" Upgrade All " Margin="7"/>
                            <Button Name="WPFuninstall" Content=" Uninstall Selection " Margin="7"/>
                            <Button Name="WPFclearWinget" Content=" Clear Selection " Margin="7"/>
                            </StackPanel>
                            <StackPanel Background="#777777" Orientation="Horizontal" Grid.Row="0" HorizontalAlignment="Center" Grid.Column="3" Grid.ColumnSpan="2" Margin="10">
                                <Label Content="Configuration File:" FontSize="17" VerticalAlignment="Center"/>
                                <Button Name="WPFimportWinget" Content=" Import " Margin="7"/>
                                <Button Name="WPFexportWinget" Content=" Export " Margin="7"/>
                            </StackPanel>
                            <StackPanel Background="#777777" SnapsToDevicePixels="True" Grid.Row="1" Grid.Column="0" Margin="10">
                                <Label Content="Drivers" FontSize="16" Margin="15,0"/>
                                <Label Content="asus.com/support/" FontSize="12"/>
                                <Label Content="msi.com/support/mb" FontSize="12"/>
                                <Label Content="gigabyte.com/Support/Motherboard" FontSize="12"/>
                                <Label Content="amd.com/en/support" FontSize="12"/>
                                <CheckBox Name="WPFInstallgeforceexperience" Content="GeForce Experience" Margin="5,0"/>

                                <Label Content="Browsers" FontSize="16" Margin="15,0"/>
                                <CheckBox Name="WPFInstallbrave" Content="Brave" Margin="5,0"/>
                                <CheckBox Name="WPFInstallchrome" Content="Chrome" Margin="5,0"/>
                                <CheckBox Name="WPFInstallchromium" Content="Chromium" Margin="5,0"/>
                                <CheckBox Name="WPFInstalledge" Content="Edge" Margin="5,0"/>
                                <CheckBox Name="WPFInstallfirefox" Content="Firefox" Margin="5,0"/>
                                <CheckBox Name="WPFInstalllibrewolf" Content="LibreWolf" Margin="5,0"/>
                                <CheckBox Name="WPFInstalltor" Content="Tor Browser" Margin="5,0"/>
                                <CheckBox Name="WPFInstallvivaldi" Content="Vivaldi" Margin="5,0"/>
                                <CheckBox Name="WPFInstallwaterfox" Content="Waterfox" Margin="5,0"/>
                                <CheckBox Name="WPFInstalloperagx" Content="OperaGX" Margin="5,0"/>

                                <Label Content="Communications" FontSize="16" Margin="15,0"/>
                                <CheckBox Name="WPFInstalldiscord" Content="Discord" Margin="5,0"/>
                                <CheckBox Name="WPFInstalldiscordptb" Content="Discord PTB" Margin="5,0"/>
                                <CheckBox Name="WPFInstalldiscordcanary" Content="Discord Canary" Margin="5,0"/>
                                <CheckBox Name="WPFInstallhexchat" Content="Hexchat" Margin="5,0"/>
                                <CheckBox Name="WPFInstalljami" Content="Jami" Margin="5,0"/>
                                <CheckBox Name="WPFInstallmatrix" Content="Matrix" Margin="5,0"/>
                                <CheckBox Name="WPFInstallsignal" Content="Signal" Margin="5,0"/>
                                <CheckBox Name="WPFInstallskype" Content="Skype" Margin="5,0"/>
                                <CheckBox Name="WPFInstallslack" Content="Slack" Margin="5,0"/>
                                <CheckBox Name="WPFInstallteams" Content="Teams" Margin="5,0"/>
                                <CheckBox Name="WPFInstalltelegram" Content="Telegram" Margin="5,0"/>
                                <CheckBox Name="WPFInstallviber" Content="Viber" Margin="5,0"/>
                                <CheckBox Name="WPFInstallzoom" Content="Zoom" Margin="5,0"/>
                                <CheckBox Name="WPFInstallts3" Content="TeamSpeak 3" Margin="5,0"/>
                                <CheckBox Name="WPFInstallwebex" Content="Webex" Margin="5,0"/>
                            </StackPanel>
                            <StackPanel Background="#777777" SnapsToDevicePixels="True" Grid.Row="1" Grid.Column="1" Margin="10">
                                <Label Content="Development" FontSize="16" Margin="15,0"/>
                                <CheckBox Name="WPFInstallgit" Content="Git" Margin="5,0"/>
                                <CheckBox Name="WPFInstallgithubdesktop" Content="GitHub Desktop" Margin="5,0"/>
                                <CheckBox Name="WPFInstalljava8" Content="OpenJDK Java 8" Margin="5,0"/>
                                <CheckBox Name="WPFInstalljava16" Content="OpenJDK Java 16" Margin="5,0"/>
                                <CheckBox Name="WPFInstalljava18" Content="Oracle Java 18" Margin="5,0"/>
                                <CheckBox Name="WPFInstalljetbrains" Content="Jetbrains Toolbox" Margin="5,0"/>
                                <CheckBox Name="WPFInstallminiconda" Content="Miniconda" Margin="5,0"/>
                                <CheckBox Name="WPFInstallnodejs" Content="NodeJS" Margin="5,0"/>
                                <CheckBox Name="WPFInstallnodejslts" Content="NodeJS LTS" Margin="5,0"/>
                                <CheckBox Name="WPFInstallnvm" Content="Node Version Manager" Margin="5,0"/>
                                <CheckBox Name="WPFInstallpython3" Content="Python3" Margin="5,0"/>
                                <CheckBox Name="WPFInstallpostman" Content="Postman" Margin="5,0"/>
                                <CheckBox Name="WPFInstallrustlang" Content="Rust" Margin="5,0"/>
                                <CheckBox Name="WPFInstallgolang" Content="GoLang" Margin="5,0"/>
                                <CheckBox Name="WPFInstallsublime" Content="Sublime" Margin="5,0"/>
                                <CheckBox Name="WPFInstallunity" Content="Unity Hub" Margin="5,0"/>
                                <CheckBox Name="WPFInstallvisualstudio" Content="Visual Studio 2022" Margin="5,0"/>
                                <CheckBox Name="WPFInstallneovim" Content="Neovim" Margin="5,0"/>
                                <CheckBox Name="WPFInstallvscode" Content="VS Code" Margin="5,0"/>
                                <CheckBox Name="WPFInstallvscodium" Content="VS Codium" Margin="5,0"/>
                                
                                <Label Content="Microsoft Tools" FontSize="16" Margin="15,0"/>
                                <CheckBox Name="WPFInstalldotnet3" Content=".NET Desktop Runtime 3.1" Margin="5,0"/>
                                <CheckBox Name="WPFInstalldotnet5" Content=".NET Desktop Runtime 5" Margin="5,0"/>
                                <CheckBox Name="WPFInstalldotnet6" Content=".NET Desktop Runtime 6" Margin="5,0"/>
                                <CheckBox Name="WPFInstallnuget" Content="Nuget" Margin="5,0"/>
                                <CheckBox Name="WPFInstallonedrive" Content="OneDrive" Margin="5,0"/>
                                <CheckBox Name="WPFInstallpowershell" Content="PowerShell 7" Margin="5,0"/>
                                <CheckBox Name="WPFInstallpowertoys" Content="Powertoys" Margin="5,0"/>
                                <CheckBox Name="WPFInstallprocessmonitor" Content="SysInternals Process Monitor" Margin="5,0"/>
                                <CheckBox Name="WPFInstallvc2015_64" Content="Visual C++ 2015-2022 64-bit" Margin="5,0"/>
                                <CheckBox Name="WPFInstallvc2015_32" Content="Visual C++ 2015-2022 32-bit" Margin="5,0"/>
                                <CheckBox Name="WPFInstallterminal" Content="Windows Terminal" Margin="5,0"/>
                                
                                </StackPanel>
                                <StackPanel Background="#777777" SnapsToDevicePixels="True" Grid.Row="1" Grid.Column="2" Margin="10">
                                
                                <Label Content="Games" FontSize="16" Margin="15,0"/>
                                <CheckBox Name="WPFInstallbluestacks" Content="Bluestacks" Margin="5,0"/>
                                <CheckBox Name="WPFInstallepicgames" Content="Epic Games Launcher" Margin="5,0"/>
                                <CheckBox Name="WPFInstallgog" Content="GOG Galaxy" Margin="5,0"/>
                                <CheckBox Name="WPFInstallminecraft" Content="Minecraft Launcher" Margin="5,0"/>
                                <CheckBox Name="WPFInstallorigin" Content="Origin" Margin="5,0"/>
                                <CheckBox Name="WPFInstallprismlauncher" Content="Prism Launcher" Margin="5,0"/>
                                <CheckBox Name="WPFInstallsidequest" Content="SideQuest" Margin="5,0"/>
                                <CheckBox Name="WPFInstallsteam" Content="Steam" Margin="5,0"/>
                                <CheckBox Name="WPFInstallubisoft" Content="Ubisoft Connect" Margin="5,0"/>
                                <CheckBox Name="WPFInstallgeforcenow" Content="GeForce NOW" Margin="5,0"/>
                                <CheckBox Name="WPFInstallicue" Content="Corsair iCUE" Margin="5,0"/>
                                <CheckBox Name="WPFInstallsteelseriesgg" Content="Steelseries GG" Margin="5,0"/>

                                <Label Content="Document" FontSize="16" Margin="5,0"/>
                                <CheckBox Name="WPFInstalladobe" Content="Adobe Reader DC" Margin="5,0"/>
                                <CheckBox Name="WPFInstallfoxpdf" Content="Foxit PDF" Margin="5,0"/>
                                <CheckBox Name="WPFInstalljoplin" Content="Joplin (FOSS Notes)" Margin="5,0"/>
                                <CheckBox Name="WPFInstalllibreoffice" Content="LibreOffice" Margin="5,0"/>
                                <CheckBox Name="WPFInstallnotepadplus" Content="Notepad++" Margin="5,0"/>
                                <CheckBox Name="WPFInstallobsidian" Content="Obsidian" Margin="5,0"/>
                                <CheckBox Name="WPFInstallonlyoffice" Content="ONLYOffice Desktop" Margin="5,0"/>
                                <CheckBox Name="WPFInstallopenoffice" Content="Apache OpenOffice" Margin="5,0"/>
                                <CheckBox Name="WPFInstallsumatra" Content="Sumatra PDF" Margin="5,0"/>
                                <CheckBox Name="WPFInstallwinmerge" Content="WinMerge" Margin="5,0"/>


                            </StackPanel>
                            <StackPanel Background="#777777" SnapsToDevicePixels="True" Grid.Row="1" Grid.Column="3" Margin="10">
                                <Label Content="Multimedia Tools" FontSize="16" Margin="15,0"/>
                                <CheckBox Name="WPFInstallaudacity" Content="Audacity" Margin="5,0"/>
                                <CheckBox Name="WPFInstallblender" Content="Blender (3D Graphics)" Margin="5,0"/>
                                <CheckBox Name="WPFInstallcider" Content="Cider (FOSS Music Player)" Margin="5,0"/>
                                <CheckBox Name="WPFInstalleartrumpet" Content="Eartrumpet (Audio)" Margin="5,0"/>
                                <CheckBox Name="WPFInstallflameshot" Content="Flameshot (Screenshots)" Margin="5,0"/>
                                <CheckBox Name="WPFInstallfoobar" Content="Foobar2000 (Music Player)" Margin="5,0"/>
                                <CheckBox Name="WPFInstallgimp" Content="GIMP (Image Editor)" Margin="5,0"/>
                                <CheckBox Name="WPFInstallgreenshot" Content="Greenshot (Screenshots)" Margin="5,0"/>
                                <CheckBox Name="WPFInstallhandbrake" Content="HandBrake" Margin="5,0"/>
                                <CheckBox Name="WPFInstallimageglass" Content="ImageGlass (Image Viewer)" Margin="5,0"/>
                                <CheckBox Name="WPFInstallinkscape" Content="Inkscape" Margin="5,0"/>
                                <CheckBox Name="WPFInstallitunes" Content="iTunes" Margin="5,0"/>
                                <CheckBox Name="WPFInstallkdenlive" Content="Kdenlive (Video Editor)" Margin="5,0"/>
                                <CheckBox Name="WPFInstallkodi" Content="Kodi Media Center" Margin="5,0"/>
                                <CheckBox Name="WPFInstallklite" Content="K-Lite Codec Standard" Margin="5,0"/>
                                <CheckBox Name="WPFInstallkrita" Content="Krita (Image Editor)" Margin="5,0"/>
                                <CheckBox Name="WPFInstallmpc" Content="Media Player Classic (Video Player)" Margin="5,0"/>
                                <CheckBox Name="WPFInstallnditools" Content="NDI Tools" Margin="5,0"/>
                                <CheckBox Name="WPFInstallndiruntime" Content="NDI Runtime" Margin="5,0"/>
                                <CheckBox Name="WPFInstallobs" Content="OBS Studio" Margin="5,0"/>
                                <CheckBox Name="WPFInstallnglide" Content="nGlide (3dfx compatibility)" Margin="5,0"/>
                                <CheckBox Name="WPFInstallsharex" Content="ShareX (Screenshots)" Margin="5,0"/>
                                <CheckBox Name="WPFInstallstrawberry" Content="Strawberry (Music Player)" Margin="5,0"/>
                                <CheckBox Name="WPFInstallvlc" Content="VLC (Video Player)" Margin="5,0"/>
                                <CheckBox Name="WPFInstallvoicemeeter" Content="Voicemeeter (Audio)" Margin="5,0"/>
                            </StackPanel>
                            <StackPanel Background="#777777" SnapsToDevicePixels="True" Grid.Row="1" Grid.Column="4" Margin="10">
                                <Label Content="Utilities" FontSize="16" Margin="15,0"/>
                                <CheckBox Name="WPFInstallsevenzip" Content="7-Zip" Margin="5,0"/>
                                <CheckBox Name="WPFInstallalacritty" Content="Alacritty Terminal" Margin="5,0"/>
                                <CheckBox Name="WPFInstallanydesk" Content="AnyDesk" Margin="5,0"/>
                                <CheckBox Name="WPFInstallautohotkey" Content="AutoHotkey" Margin="5,0"/>
                                <CheckBox Name="WPFInstallbitwarden" Content="Bitwarden" Margin="5,0"/>
                                <CheckBox Name="WPFInstallcpuz" Content="CPU-Z" Margin="5,0"/>
                                <CheckBox Name="WPFInstalldeluge" Content="Deluge" Margin="5,0"/>
                                <CheckBox Name="WPFInstalletcher" Content="Etcher USB Creator" Margin="5,0"/>
                                <CheckBox Name="WPFInstallesearch" Content="Everything Search" Margin="5,0"/>
                                <CheckBox Name="WPFInstallflux" Content="f.lux Redshift" Margin="5,0"/>
                                <CheckBox Name="WPFInstallgpuz" Content="GPU-Z" Margin="5,0"/>
                                <CheckBox Name="WPFInstallglaryutilities" Content="Glary Utilities" Margin="5,0"/>
                                <CheckBox Name="WPFInstallhwinfo" Content="HWInfo" Margin="5,0"/>
                                <CheckBox Name="WPFInstallidm" Content="Internet Download Manager" Margin="5,0"/>
                                <CheckBox Name="WPFInstalljdownloader" Content="J Download Manager" Margin="5,0"/>
                                <CheckBox Name="WPFInstallkeepass" Content="KeePassXC" Margin="5,0"/>
                                <CheckBox Name="WPFInstallmalwarebytes" Content="MalwareBytes" Margin="5,0"/>
                                <CheckBox Name="WPFInstallmonitorian" Content="Monitorian" Margin="5,0"/>
                                <CheckBox Name="WPFInstallnvclean" Content="NVCleanstall" Margin="5,0"/>
                                <CheckBox Name="WPFInstallopenshell" Content="Open Shell (Start Menu)" Margin="5,0"/>
                                <CheckBox Name="WPFInstallprocesslasso" Content="Process Lasso" Margin="5,0"/>
                                <CheckBox Name="WPFInstallqbittorrent" Content="qBittorrent" Margin="5,0"/>
                                <CheckBox Name="WPFInstallrevo" Content="RevoUninstaller" Margin="5,0"/>
                                <CheckBox Name="WPFInstallrufus" Content="Rufus Imager" Margin="5,0"/>
                                <CheckBox Name="WPFInstallsandboxie" Content="Sandboxie Plus" Margin="5,0"/>
                                <CheckBox Name="WPFInstallshell" Content="Shell (Expanded Context Menu)" Margin="5,0"/>
                                <CheckBox Name="WPFInstallsshfs" Content="SSHFS-Win" Margin="5,0"/>
                                <CheckBox Name="WPFInstallteamviewer" Content="TeamViewer" Margin="5,0"/>
                                <CheckBox Name="WPFInstallttaskbar" Content="Translucent Taskbar" Margin="5,0"/>
                                <CheckBox Name="WPFInstalltreesize" Content="TreeSize Free" Margin="5,0"/>
                                <CheckBox Name="WPFInstalltwinkletray" Content="Twinkle Tray" Margin="5,0"/>
                                <CheckBox Name="WPFInstallwindirstat" Content="WinDirStat" Margin="5,0"/>
                                <CheckBox Name="WPFInstallwiztree" Content="WizTree" Margin="5,0"/>
                                <CheckBox Name="WPFInstallwinrar" Content="WinRAR" Margin="5,0"/>
                                <CheckBox Name="WPFInstallscp" Content="WinSCP" Margin="5,0"/>
                                <CheckBox Name="WPFInstallwireshark" Content="WireShark" Margin="5,0"/>
                                
                            </StackPanel>
                        </Grid>
                    </TabItem>
                    <TabItem Header="Tweaks" Visibility="Collapsed" Name="WPFTab2">
                        <Grid Background="#333333">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Grid.RowDefinitions>
                                <RowDefinition Height=".10*"/>
                                <RowDefinition Height=".70*"/>
                                <RowDefinition Height=".10*"/>
                            </Grid.RowDefinitions>
                            <StackPanel Background="#777777" Orientation="Horizontal" Grid.Row="0" HorizontalAlignment="Center" Grid.Column="0" Margin="10">
                                <Label Content="Recommended Selections:" FontSize="17" VerticalAlignment="Center"/>
                                <Button Name="WPFdesktop" Content=" Desktop " Margin="7"/>
                                <Button Name="WPFlaptop" Content=" Laptop " Margin="7"/>
                                <Button Name="WPFminimal" Content=" Minimal " Margin="7"/>
                                <Button Name="WPFclear" Content=" Clear " Margin="7"/>
                                <Button Name="WPFGetInstalledTweaks" Content=" Get Installed " Margin="7"/>
                            </StackPanel>
                            <StackPanel Background="#777777" Orientation="Horizontal" Grid.Row="0" HorizontalAlignment="Center" Grid.Column="1" Margin="10">
                                <Label Content="Configuration File:" FontSize="17" VerticalAlignment="Center"/>
                                <Button Name="WPFimport" Content=" Import " Margin="7"/>
                                <Button Name="WPFexport" Content=" Export " Margin="7"/>
                            </StackPanel>
                            <StackPanel Background="#777777" Orientation="Horizontal" Grid.Row="2" HorizontalAlignment="Center" Grid.ColumnSpan="2" Margin="10">
                                <TextBlock Padding="10">
                                    Note: Hover over items to get a better description. Please be careful as many of these tweaks will heavily modify your system.
                                    <LineBreak/>Recommended selections are for normal users and if you are unsure do NOT check anything else!
                                </TextBlock>
                            </StackPanel>
                            <StackPanel Background="#777777" SnapsToDevicePixels="True" Grid.Row="1" Grid.Column="0" Margin="10,5">
                                <Label FontSize="16" Content="Essential Tweaks"/>
                                <CheckBox Name="WPFEssTweaksRP" Content="Create Restore Point" Margin="5,0" ToolTip="Creates a Windows Restore point before modifying system. Can use Windows System Restore to rollback to before tweaks were applied"/>
                                <CheckBox Name="WPFEssTweaksOO" Content="Run OO Shutup" Margin="5,0" ToolTip="Runs OO Shutup from https://www.oo-software.com/en/shutup10"/>
                                <CheckBox Name="WPFEssTweaksTele" Content="Disable Telemetry" Margin="5,0" ToolTip="Disables Microsoft Telemetry. Note: This will lock many Edge Browser settings. Microsoft spys heavily on you when using the Edge browser."/>
                                <CheckBox Name="WPFEssTweaksWifi" Content="Disable Wifi-Sense" Margin="5,0" ToolTip="Wifi Sense is a spying service that phones home all nearby scaned wifi networks and your current geo location."/>
                                <CheckBox Name="WPFEssTweaksAH" Content="Disable Activity History" Margin="5,0" ToolTip="This erases recent docs, clipboard, and run history."/>
                                <CheckBox Name="WPFEssTweaksDeleteTempFiles" Content="Delete Temporary Files" Margin="5,0" ToolTip="Erases TEMP Folders"/>
                                <CheckBox Name="WPFEssTweaksDiskCleanup" Content="Run Disk Cleanup" Margin="5,0" ToolTip="Runs Disk Cleanup on Drive C: and removes old Windows Updates."/>
                                <CheckBox Name="WPFEssTweaksLoc" Content="Disable Location Tracking" Margin="5,0" ToolTip="Disables Location Tracking...DUH!"/>
                                <CheckBox Name="WPFEssTweaksHome" Content="Disable Homegroup" Margin="5,0" ToolTip="Disables HomeGroup - Windows 11 doesn''t have this, it was awful."/>
                                <CheckBox Name="WPFEssTweaksStorage" Content="Disable Storage Sense" Margin="5,0" ToolTip="Storage Sense is supposed to delete temp files automatically, but often runs at wierd times and mostly doesn''t do much. Although when it was introduced in Win 10 (1809 Version) it deleted people''s documents... So there is that."/>
                                <CheckBox Name="WPFEssTweaksHiber" Content="Disable Hibernation" Margin="5,0" ToolTip="Hibernation is really meant for laptops as it saves whats in memory before turning the pc off. It really should never be used, but some people are lazy and rely on it. Don''t be like Bob. Bob likes hibernation."/>
                                <CheckBox Name="WPFEssTweaksDVR" Content="Disable GameDVR" Margin="5,0" ToolTip="GameDVR is a Windows App that is a dependancy for some Store Games. I''ve never met someone that likes it, but it''s there for the XBOX crowd."/>
                                <CheckBox Name="WPFEssTweaksServices" Content="Set Services to Manual" Margin="5,0" ToolTip="Turns a bunch of system services to manual that don''t need to be running all the time. This is pretty harmless as if the service is needed, it will simply start on demand."/>
                                <Label Content="Dark Theme" />
                                <StackPanel Orientation="Horizontal">
                                    <Label Content="Off" />
                                    <CheckBox Name="WPFToggleDarkMode" Style="{StaticResource ToggleSwitchStyle}" Margin="2.5,0"/>
                                    <Label Content="On" />
                                </StackPanel>
							<Label Content="Performance Plans" />
                                <Button Name="WPFAddUltPerf" Background="AliceBlue" Content="Add Ultimate Performance Profile" HorizontalAlignment = "Left" Margin="5,0" Padding="20,5" Width="300"/>
                                <Button Name="WPFRemoveUltPerf" Background="AliceBlue" Content="Remove Ultimate Performance Profile" HorizontalAlignment = "Left" Margin="5,0,0,5" Padding="20,5" Width="300"/>
							<Label Content="Shortcuts" />
                                <Button Name="WPFWinUtilShortcut" Background="AliceBlue" Content="Create WinUtil Shortcut" HorizontalAlignment = "Left" Margin="5,0" Padding="20,5" Width="300"/>

                            </StackPanel>
                            <StackPanel Background="#777777" SnapsToDevicePixels="True" Grid.Row="1" Grid.Column="1" Margin="10,5">
                                <Label FontSize="16" Content="Misc. Tweaks"/>
                                <CheckBox Name="WPFMiscTweaksPower" Content="Disable Power Throttling" Margin="5,0" ToolTip="This is mainly for Laptops, It disables Power Throttling and will use more battery."/>
                                <CheckBox Name="WPFMiscTweaksLapPower" Content="Enable Power Throttling" Margin="5,0" ToolTip="ONLY FOR LAPTOPS! Do not use on a desktop."/>
                                <CheckBox Name="WPFMiscTweaksNum" Content="Enable NumLock on Startup" Margin="5,0" ToolTip="This creates a time vortex and send you back to the past... or it simply turns numlock on at startup"/>
                                <CheckBox Name="WPFMiscTweaksLapNum" Content="Disable Numlock on Startup" Margin="5,0" ToolTip="Disables Numlock... Very useful when you are on a laptop WITHOUT 9-key and this fixes that issue when the numlock is enabled!"/>
                                <CheckBox Name="WPFMiscTweaksExt" Content="Show File Extensions" Margin="5,0"/>
                                <CheckBox Name="WPFMiscTweaksDisplay" Content="Set Display for Performance" Margin="5,0" ToolTip="Sets the system preferences to performance. You can do this manually with sysdm.cpl as well."/>
                                <CheckBox Name="WPFMiscTweaksUTC" Content="Set Time to UTC (Dual Boot)" Margin="5,0" ToolTip="Essential for computers that are dual booting. Fixes the time sync with Linux Systems."/>
                                <CheckBox Name="WPFMiscTweaksDisableUAC" Content="Disable UAC" Margin="5,0" ToolTip="Disables User Account Control. Only recommended for Expert Users."/>
                                <CheckBox Name="WPFMiscTweaksDisableNotifications" Content="Disable Notification Tray/Calendar" Margin="5,0" ToolTip="Disables all Notifications INCLUDING Calendar"/>
                                <CheckBox Name="WPFMiscTweaksDisableTPMCheck" Content="Disable TPM on Update" Margin="5,0" ToolTip="Add the Windows 11 Bypass for those that want to upgrade their Windows 10."/>
                                <CheckBox Name="WPFEssTweaksDeBloat" Content="Remove ALL MS Store Apps" Margin="5,0" ToolTip="USE WITH CAUTION!!!!! This will remove ALL Microsoft store apps other than the essentials to make winget work. Games installed by MS Store ARE INCLUDED!"/>
                                <CheckBox Name="WPFEssTweaksRemoveCortana" Content="Remove Cortana" Margin="5,0" ToolTip="Removes Cortana, but often breaks search... if you are a heavy windows search users, this is NOT recommended."/>
                                <CheckBox Name="WPFEssTweaksRemoveEdge" Content="Remove Microsoft Edge" Margin="5,0" ToolTip="Removes MS Edge when it gets reinstalled by updates."/>
                                <CheckBox Name="WPFMiscTweaksRightClickMenu" Content="Set Classic Right-Click Menu " Margin="5,0" ToolTip="Great Windows 11 tweak to bring back good context menus when right clicking things in explorer."/>
                                <CheckBox Name="WPFMiscTweaksDisableMouseAcceleration" Content="Disable Mouse Acceleration" Margin="5,0" ToolTip="Disables Mouse Acceleration."/>
                                <CheckBox Name="WPFMiscTweaksEnableMouseAcceleration" Content="Enable Mouse Acceleration" Margin="5,0" ToolTip="Enables Mouse Acceleration."/>
                                <Label Content="DNS" />
							    <ComboBox Name="WPFchangedns"  Height = "20" Width = "160" HorizontalAlignment = "Left" Margin="5,5"> 
								    <ComboBoxItem IsSelected="True" Content = "Default"/> 
                                    <ComboBoxItem Content = "DHCP"/> 
								    <ComboBoxItem Content = "Google"/> 
								    <ComboBoxItem Content = "Cloudflare"/> 
                                    <ComboBoxItem Content = "Cloudflare_Malware"/> 
                                    <ComboBoxItem Content = "Cloudflare_Malware_Adult"/> 
								    <ComboBoxItem Content = "Level3"/> 
								    <ComboBoxItem Content = "Open_DNS"/> 
                                    <ComboBoxItem Content = "Quad9"/>
							    </ComboBox> 
                                <Button Name="WPFtweaksbutton" Background="AliceBlue" Content="Run Tweaks  " HorizontalAlignment = "Left" Margin="5,0" Padding="20,5" Width="160"/>
                                <Button Name="WPFundoall" Background="AliceBlue" Content="Undo Selected Tweaks" HorizontalAlignment = "Left" Margin="5,0" Padding="20,5" Width="160"/>
                            </StackPanel>
                        </Grid>
                    </TabItem>
                    <TabItem Header="Config" Visibility="Collapsed" Name="WPFTab3">
                        <Grid Background="#b48be0">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <StackPanel Background="#777777" SnapsToDevicePixels="True" Grid.Column="0" Margin="10,5">
                                <Label Content="Features" FontSize="16"/>
                                <CheckBox Name="WPFFeaturesdotnet" Content="All .Net Framework (2,3,4)" Margin="5,0"/>
                                <CheckBox Name="WPFFeatureshyperv" Content="HyperV Virtualization" Margin="5,0"/>
                                <CheckBox Name="WPFFeatureslegacymedia" Content="Legacy Media (WMP, DirectPlay)" Margin="5,0"/>
                                <CheckBox Name="WPFFeaturenfs" Content="NFS - Network File System" Margin="5,0"/>
                                <CheckBox Name="WPFFeaturewsl" Content="Windows Subsystem for Linux" Margin="5,0"/>
                                <Button Name="WPFFeatureInstall" FontSize="14" Background="AliceBlue" Content="Install Features" HorizontalAlignment = "Left" Margin="5" Padding="20,5" Width="150"/>
                                <Label Content="Fixes" FontSize="16"/>
                                <Button Name="WPFPanelAutologin" FontSize="14" Background="AliceBlue" Content="Set Up Autologin" HorizontalAlignment = "Left" Margin="5,2" Padding="20,5" Width="300"/>
                                <Button Name="WPFFixesUpdate" FontSize="14" Background="AliceBlue" Content="Reset Windows Update" HorizontalAlignment = "Left" Margin="5,2" Padding="20,5" Width="300"/>
                                <Button Name="WPFPanelDISM" FontSize="14" Background="AliceBlue" Content="System Corruption Scan" HorizontalAlignment = "Left" Margin="5,2" Padding="20,5" Width="300"/>
                            </StackPanel>
                            <StackPanel Background="#777777" SnapsToDevicePixels="True" Grid.Column="1" Margin="10,5">
                                <Label Content="Legacy Windows Panels" FontSize="16"/>
                                <Button Name="WPFPanelcontrol" FontSize="14" Background="AliceBlue" Content="Control Panel" HorizontalAlignment = "Left" Margin="5" Padding="20,5" Width="200"/>
                                <Button Name="WPFPanelnetwork" FontSize="14" Background="AliceBlue" Content="Network Connections" HorizontalAlignment = "Left" Margin="5" Padding="20,5" Width="200"/>
                                <Button Name="WPFPanelpower" FontSize="14" Background="AliceBlue" Content="Power Panel" HorizontalAlignment = "Left" Margin="5" Padding="20,5" Width="200"/>
                                <Button Name="WPFPanelsound" FontSize="14" Background="AliceBlue" Content="Sound Settings" HorizontalAlignment = "Left" Margin="5" Padding="20,5" Width="200"/>
                                <Button Name="WPFPanelsystem" FontSize="14" Background="AliceBlue" Content="System Properties" HorizontalAlignment = "Left" Margin="5" Padding="20,5" Width="200"/>
                                <Button Name="WPFPaneluser" FontSize="14" Background="AliceBlue" Content="User Accounts" HorizontalAlignment = "Left" Margin="5" Padding="20,5" Width="200"/>
                            </StackPanel>
                        </Grid>
                    </TabItem>
                    <TabItem Header="Updates" Visibility="Collapsed" Name="WPFTab4">
                        <Grid Background="#555555">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <StackPanel Background="#777777" SnapsToDevicePixels="True" Grid.Column="0" Margin="10,5">
                                <Button Name="WPFUpdatesdefault" FontSize="16" Background="AliceBlue" Content="Default (Out of Box) Settings" Margin="20,0,20,10" Padding="10"/>
                                <TextBlock Margin="20,0,20,0" Padding="10" TextWrapping="WrapWithOverflow" MaxWidth="300">This is the default settings that come with Windows. <LineBreak/><LineBreak/> No modifications are made and will remove any custom windows update settings.<LineBreak/><LineBreak/>Note: If you still encounter update errors, reset all updates in the config tab. That will restore ALL Microsoft Update Services from their servers and reinstall them to default settings.</TextBlock>
                            </StackPanel>
                            <StackPanel Background="#777777" SnapsToDevicePixels="True" Grid.Column="1" Margin="10,5">
                                <Button Name="WPFUpdatessecurity" FontSize="16" Background="AliceBlue" Content="Security (Recommended) Settings" Margin="20,0,20,10" Padding="10"/>
                                <TextBlock Margin="20,0,20,0" Padding="10" TextWrapping="WrapWithOverflow" MaxWidth="300">This is my recommended setting I use on all computers.<LineBreak/><LineBreak/> It will delay feature updates by 2 years and will install security updates 4 days after release.<LineBreak/><LineBreak/>Feature Updates: Adds features and often bugs to systems when they are released. You want to delay these as long as possible.<LineBreak/><LineBreak/>Security Updates: Typically these are pressing security flaws that need to be patched quickly. You only want to delay these a couple of days just to see if they are safe and don''t break other systems. You don''t want to go without these for ANY extended periods of time.</TextBlock>
                            </StackPanel>
                            <StackPanel Background="#777777" SnapsToDevicePixels="True" Grid.Column="2" Margin="10,5">
                                <Button Name="WPFUpdatesdisable" FontSize="16" Background="AliceBlue" Content="Disable ALL Updates (NOT RECOMMENDED!)" Margin="20,0,20,10" Padding="10,10,10,10"/>
                                <TextBlock Margin="20,0,20,0" Padding="10" TextWrapping="WrapWithOverflow" MaxWidth="300">This completely disables ALL Windows Updates and is NOT RECOMMENDED.<LineBreak/><LineBreak/> However, it can be suitable if you use your system for a select purpose and do not actively browse the internet. <LineBreak/><LineBreak/>Note: Your system will be easier to hack and infect without security updates.</TextBlock>
                                <TextBlock Text=" " Margin="20,0,20,0" Padding="10" TextWrapping="WrapWithOverflow" MaxWidth="300"/>

                            </StackPanel>

                        </Grid>
                    </TabItem>
                </TabControl>
            </Grid>
        </Viewbox>
    </Border>
</Window>'
$sync.configs.applications = '{
  "WPFInstallgeforceexperience": {
    "winget": "Nvidia.GeForceExperience"
  },
  "WPFInstalladobe": {
    "winget": "Adobe.Acrobat.Reader.64-bit",
    "choco": "adobereader"
  },
  "WPFInstalladvancedip": {
    "winget": "Famatech.AdvancedIPScanner",
    "choco": "advanced-ip-scanner"
  },
  "WPFInstallanydesk": {
    "winget": "AnyDeskSoftwareGmbH.AnyDesk",
    "choco": "anydesk"
  },
  "WPFInstallaudacity": {
    "winget": "Audacity.Audacity",
    "choco": "audacity"
  },
  "WPFInstallautohotkey": {
    "winget": "Lexikos.AutoHotkey",
    "choco": "autohotkey"
  },
  "WPFInstallbitwarden": {
    "winget": "Bitwarden.Bitwarden",
    "choco": "bitwarden"
  },
  "WPFInstallblender": {
    "winget": "BlenderFoundation.Blender",
    "choco": "blender"
  },
  "WPFInstallbrave": {
    "winget": "Brave.Brave",
    "choco": "brave"
  },
  "WPFInstallchrome": {
    "winget": "Google.Chrome",
    "choco": "googlechrome"
  },
  "WPFInstallchromium": {
    "winget": "eloston.ungoogled-chromium",
    "choco": "chromium"
  },
  "WPFInstallcpuz": {
    "winget": "CPUID.CPU-Z",
    "choco": "cpu-z"
  },
  "WPFInstalldeluge": {
    "winget": "DelugeTeam.Deluge",
    "choco": "deluge"
  },
  "WPFInstalldiscord": {
    "winget": "Discord.Discord",
    "choco": "discord"
  },
  "WPFInstalldiscordptb": {
    "winget": "Discord.Discord.PTB"
  },
  "WPFInstalldiscordcanary": {
    "winget": "Discord.Discord.Canary"
  },
  "WPFInstalleartrumpet": {
    "winget": "File-New-Project.EarTrumpet",
    "choco": "eartrumpet"
  },
  "WPFInstallepicgames": {
    "winget": "EpicGames.EpicGamesLauncher",
    "choco": "epicgameslauncher"
  },
  "WPFInstallesearch": {
    "winget": "voidtools.Everything",
    "choco": "everything"
  },
  "WPFInstalletcher": {
    "winget": "Balena.Etcher",
    "choco": "etcher"
  },
  "WPFInstallfirefox": {
    "winget": "Mozilla.Firefox",
    "choco": "firefox"
  },
  "WPFInstallflameshot": {
    "winget": "Flameshot.Flameshot",
    "choco": "na"
  },
  "WPFInstallfoobar": {
    "winget": "PeterPawlowski.foobar2000",
    "choco": "foobar2000"
  },
  "WPFInstallgeforcenow": {
    "winget": "Nvidia.GeForceNow",
    "choco": "nvidia-geforce-now"
  },
  "WPFInstallgimp": {
    "winget": "GIMP.GIMP",
    "choco": "gimp"
  },
  "WPFInstallgithubdesktop": {
    "winget": "Git.Git;GitHub.GitHubDesktop",
    "choco": "git;github-desktop"
  },
  "WPFInstallgog": {
    "winget": "GOG.Galaxy",
    "choco": "goggalaxy"
  },
  "WPFInstallgpuz": {
    "winget": "TechPowerUp.GPU-Z",
    "choco": "gpu-z"
  },
  "WPFInstallgreenshot": {
    "winget": "Greenshot.Greenshot",
    "choco": "greenshot"
  },
  "WPFInstallhandbrake": {
    "winget": "HandBrake.HandBrake",
    "choco": "handbrake"
  },
  "WPFInstallhexchat": {
    "winget": "HexChat.HexChat",
    "choco": "hexchat"
  },
  "WPFInstallhwinfo": {
    "winget": "REALiX.HWiNFO",
    "choco": "hwinfo"
  },
  "WPFInstallimageglass": {
    "winget": "DuongDieuPhap.ImageGlass",
    "choco": "imageglass"
  },
  "WPFInstallinkscape": {
    "winget": "Inkscape.Inkscape",
    "choco": "inkscape"
  },
  "WPFInstalljava16": {
    "winget": "AdoptOpenJDK.OpenJDK.16",
    "choco": "temurin16jre"
  },
  "WPFInstalljava18": {
    "winget": "EclipseAdoptium.Temurin.18.JRE",
    "choco": "temurin18jre"
  },
  "WPFInstalljava8": {
    "winget": "EclipseAdoptium.Temurin.8.JRE",
    "choco": "temurin8jre"
  },
  "WPFInstalljava19": {
    "winget": "EclipseAdoptium.Temurin.19.JRE",
    "choco": "temurin19jre"
  },
  "WPFInstalljava17": {
    "winget": "EclipseAdoptium.Temurin.17.JRE",
    "choco": "temurin17jre"
  },
  "WPFInstalljava11": {
    "winget": "EclipseAdoptium.Temurin.11.JRE",
    "choco": "javaruntime"
  },
  "WPFInstalljetbrains": {
    "winget": "JetBrains.Toolbox",
    "choco": "jetbrainstoolbox"
  },
  "WPFInstallkeepass": {
    "winget": "KeePassXCTeam.KeePassXC",
    "choco": "keepassxc"
  },
  "WPFInstalllibrewolf": {
    "winget": "LibreWolf.LibreWolf",
    "choco": "librewolf"
  },
  "WPFInstallmalwarebytes": {
    "winget": "Malwarebytes.Malwarebytes",
    "choco": "malwarebytes"
  },
  "WPFInstallmonitorian": {
    "winget": "emoacht.Monitorian"
  },
  "WPFInstallmatrix": {
    "winget": "Element.Element",
    "choco": "element-desktop"
  },
  "WPFInstallmpc": {
    "winget": "clsid2.mpc-hc",
    "choco": "mpc-hc"
  },
  "WPFInstallmremoteng": {
    "winget": "mRemoteNG.mRemoteNG",
    "choco": "mremoteng"
  },
  "WPFInstallminiconda": {
    "winget": "Anaconda.Miniconda3"
  },
  "WPFInstallnodejs": {
    "winget": "OpenJS.NodeJS",
    "choco": "nodejs"
  },
  "WPFInstallnodejslts": {
    "winget": "OpenJS.NodeJS.LTS",
    "choco": "nodejs-lts"
  },
  "WPFInstallnotepadplus": {
    "winget": "Notepad++.Notepad++",
    "choco": "notepadplusplus"
  },
  "WPFInstallnvclean": {
    "winget": "TechPowerUp.NVCleanstall",
    "choco": "na"
  },
  "WPFInstallnditools": {
    "winget": "NewTek.NDI5Tools"
  },
  "WPFInstallndiruntime": {
    "winget": "NewTek.NDI5Runtime"
  },
  "WPFInstallobs": {
    "winget": "OBSProject.OBSStudio",
    "choco": "obs-studio"
  },
  "WPFInstallobsidian": {
    "winget": "Obsidian.Obsidian",
    "choco": "obsidian"
  },
  "WPFInstallpowertoys": {
    "winget": "Microsoft.PowerToys",
    "choco": "powertoys"
  },
  "WPFInstallputty": {
    "winget": "PuTTY.PuTTY",
    "choco": "putty"
  },
  "WPFInstallpython3": {
    "winget": "Python.Python.3.11",
    "choco": "python"
  },
  "WPFInstallrevo": {
    "winget": "RevoUninstaller.RevoUninstaller",
    "choco": "revo-uninstaller"
  },
  "WPFInstallrufus": {
    "winget": "Rufus.Rufus",
    "choco": "rufus"
  },
  "WPFInstallsevenzip": {
    "winget": "7zip.7zip",
    "choco": "7zip"
  },
  "WPFInstallsharex": {
    "winget": "ShareX.ShareX",
    "choco": "sharex"
  },
  "WPFInstallsignal": {
    "winget": "OpenWhisperSystems.Signal",
    "choco": "signal"
  },
  "WPFInstallskype": {
    "winget": "Microsoft.Skype",
    "choco": "skype"
  },
  "WPFInstallslack": {
    "winget": "SlackTechnologies.Slack",
    "choco": "slack"
  },
  "WPFInstallprismlauncher": {
    "winget": "PrismLauncher.PrismLauncher"
  },
  "WPFInstallsidequest": {
    "winget": "SideQuestVR.SideQuest"
  },
  "WPFInstallsteam": {
    "winget": "Valve.Steam",
    "choco": "steam-client"
  },
  "WPFInstallsublime": {
    "winget": "SublimeHQ.SublimeText.4",
    "choco": "sublimetext4"
  },
  "WPFInstallsumatra": {
    "winget": "SumatraPDF.SumatraPDF",
    "choco": "sumatrapdf"
  },
  "WPFInstallteams": {
    "winget": "Microsoft.Teams",
    "choco": "microsoft-teams"
  },
  "WPFInstallteamviewer": {
    "winget": "TeamViewer.TeamViewer",
    "choco": "teamviewer9"
  },
  "WPFInstallterminal": {
    "winget": "Microsoft.WindowsTerminal",
    "choco": "microsoft-windows-terminal"
  },
  "WPFInstalltreesize": {
    "winget": "JAMSoftware.TreeSize.Free",
    "choco": "treesizefree"
  },
  "WPFInstallttaskbar": {
    "winget": "TranslucentTB.TranslucentTB",
    "choco": "translucenttb"
  },
  "WPFInstallvisualstudio": {
    "winget": "Microsoft.VisualStudio.2022.Community",
    "choco": "visualstudio2022community"
  },
  "WPFInstallvivaldi": {
    "winget": "VivaldiTechnologies.Vivaldi",
    "choco": "vivaldi"
  },
  "WPFInstallvlc": {
    "winget": "VideoLAN.VLC",
    "choco": "vlc"
  },
  "WPFInstallvoicemeeter": {
    "winget": "VB-Audio.Voicemeeter",
    "choco": "voicemeeter"
  },
  "WPFInstallvscode": {
    "winget": "Git.Git;Microsoft.VisualStudioCode",
    "choco": "vscode"
  },
  "WPFInstallvscodium": {
    "winget": "Git.Git;VSCodium.VSCodium",
    "choco": "vscodium"
  },
  "WPFInstallwindirstat": {
    "winget": "WinDirStat.WinDirStat",
    "choco": "windirstat"
  },
  "WPFInstallscp": {
    "winget": "WinSCP.WinSCP",
    "choco": "winscp"
  },
  "WPFInstallwireshark": {
    "winget": "WiresharkFoundation.Wireshark",
    "choco": "wireshark"
  },
  "WPFInstallzoom": {
    "winget": "Zoom.Zoom",
    "choco": "zoom"
  },
  "WPFInstallts3": {
    "winget": "TeamSpeakSystems.TeamSpeakClient"
  },
  "WPFInstallwebex": {
    "winget": "Cisco.WebexTeams"
  },
  "WPFInstalllibreoffice": {
    "winget": "TheDocumentFoundation.LibreOffice",
    "choco": "libreoffice-fresh"
  },
  "WPFInstallshell": {
    "winget": "Nilesoft.Shell",
    "choco": "na"
  },
  "WPFInstallsshfs": {
    "winget": "SSHFS-Win.SSHFS-Win"
  },
  "WPFInstallklite": {
    "winget": "CodecGuide.K-LiteCodecPack.Standard",
    "choco": "k-litecodecpack-standard"
  },
  "WPFInstallsandboxie": {
    "winget": "Sandboxie.Plus",
    "choco": "sandboxie"
  },
  "WPFInstallprocesslasso": {
    "winget": "BitSum.ProcessLasso",
    "choco": "plasso"
  },
  "WPFInstallwinmerge": {
    "winget": "WinMerge.WinMerge",
    "choco": "winmerge"
  },
  "WPFInstalldotnet3": {
    "winget": "Microsoft.DotNet.DesktopRuntime.3_1",
    "choco": "dotnetcore3-desktop-runtime"
  },
  "WPFInstalldotnet5": {
    "winget": "Microsoft.DotNet.DesktopRuntime.5",
    "choco": "dotnet-5.0-runtime"
  },
  "WPFInstalldotnet6": {
    "winget": "Microsoft.DotNet.DesktopRuntime.6",
    "choco": "dotnet-6.0-runtime"
  },
  "WPFInstallvc2015_64": {
    "winget": "Microsoft.VC++2015-2022Redist-x64",
    "choco": "na"
  },
  "WPFInstallvc2015_32": {
    "winget": "Microsoft.VC++2015-2022Redist-x86",
    "choco": "na"
  },
  "WPFInstallfoxpdf": {
    "winget": "Foxit.PhantomPDF",
    "choco": "na"
  },
  "WPFInstallonlyoffice": {
    "winget": "ONLYOFFICE.DesktopEditors",
    "choco": "onlyoffice"
  },
  "WPFInstallflux": {
    "winget": "flux.flux",
    "choco": "flux"
  },
  "WPFInstallicue": {
    "winget": "Corsair.iCUE.4"
  },
  "WPFInstallsteelseriesgg": {
    "winget": "SteelSeries.GG"
  },
  "WPFInstallitunes": {
    "winget": "Apple.iTunes",
    "choco": "itunes"
  },
  "WPFInstallcider": {
    "winget": "CiderCollective.Cider",
    "choco": "cider"
  },
  "WPFInstalljoplin": {
    "winget": "Joplin.Joplin",
    "choco": "joplin"
  },
  "WPFInstallopenoffice": {
    "winget": "Apache.OpenOffice",
    "choco": "openoffice"
  },
  "WPFInstallrustdesk": {
    "winget": "RustDesk.RustDesk",
    "choco": "rustdesk.portable"
  },
  "WPFInstalljami": {
    "winget": "SFLinux.Jami",
    "choco": "jami"
  },
  "WPFInstalljdownloader": {
    "winget": "AppWork.JDownloader",
    "choco": "jdownloader"
  },
  "WPFInstallsimplewall": {
    "Winget": "Henry++.simplewall",
    "choco": "simplewall"
  },
  "WPFInstallrustlang": {
    "Winget": "Rustlang.Rust.MSVC",
    "choco": "rust"
  },
  "WPFInstallgolang": {
    "Winget": "GoLang.Go.1.19",
    "choco": "golang"
  },
  "WPFInstallalacritty": {
    "Winget": "Alacritty.Alacritty",
    "choco": "alacritty"
  },
  "WPFInstallkdenlive": {
    "Winget": "KDE.Kdenlive",
    "choco": "kdenlive"
  },
  "WPFInstallglaryutilities": {
    "Winget": "Glarysoft.GlaryUtilities",
    "choco": "glaryutilities-free"
  },
  "WPFInstalltwinkletray": {
    "Winget": "xanderfrangos.twinkletray",
    "choco": "na"
  },
  "WPFInstallidm": {
    "Winget": "Tonec.InternetDownloadManager",
    "choco": "internet-download-manager"
  },
  "WPFInstallviber": {
    "Winget": "Viber.Viber",
    "choco": "viber"
  },
  "WPFInstallgit": {
    "Winget": "Git.Git",
    "choco": "git"
  },
  "WPFInstallwiztree": {
    "Winget": "AntibodySoftware.WizTree",
    "choco": "wiztree\\"
  },
  "WPFInstalltor": {
    "Winget": "TorProject.TorBrowser",
    "choco": "tor-browser"
  },
  "WPFInstallkrita": {
    "winget": "KDE.Krita",
    "choco": "krita"
  },
  "WPFInstallnglide": {
    "winget": "ZeusSoftware.nGlide",
    "choco": "na"
  },
  "WPFInstallkodi": {
    "winget": "XBMCFoundation.Kodi",
    "choco": "kodi"
  },
  "WPFInstalltelegram": {
    "winget": "Telegram.TelegramDesktop",
    "choco": "telegram"
  },
  "WPFInstallunity": {
    "winget": "UnityTechnologies.UnityHub",
    "choco": "unityhub"
  },
  "WPFInstallqbittorrent": {
    "winget": "qBittorrent.qBittorrent",
    "choco": "qbittorrent"
  },
  "WPFInstallminecraft": {
    "winget": "Mojang.MinecraftLauncher"
  },
  "WPFInstallorigin": {
    "winget": "ElectronicArts.EADesktop",
    "choco": "origin"
  },
  "WPFInstallopenshell": {
    "winget": "Open-Shell.Open-Shell-Menu",
    "choco": "open-shell"
  },
  "WPFInstallbluestacks": {
    "winget": "BlueStack.BlueStacks",
    "choco": "na"
  },
  "WPFInstallstrawberry": {
    "winget": "StrawberryMusicPlayer.Strawberry",
    "choco": "strawberrymusicplayer"
  },
  "WPFInstallsqlstudio": {
    "winget": "Microsoft.SQLServerManagementStudio",
    "choco": "sql-server-management-studio"
  },
  "WPFInstallwaterfox": {
    "winget": "Waterfox.Waterfox",
    "choco": "waterfox"
  },
  "WPFInstalloperagx": {
    "winget": "Opera.OperaGX"
  },
  "WPFInstallpowershell": {
    "winget": "Microsoft.PowerShell",
    "choco": "powershell-core"
  },
  "WPFInstallprocessmonitor": {
    "winget": "Microsoft.Sysinternals.ProcessMonitor",
    "choco": "procexp"
  },
  "WPFInstallonedrive": {
    "winget": "Microsoft.OneDrive",
    "choco": "onedrive"
  },
  "WPFInstalledge": {
    "winget": "Microsoft.Edge",
    "choco": "microsoft-edge"
  },
  "WPFInstallubisoft": {
    "winget": "Ubisoft.Connect",
    "choco": "ubisoft-connect"
  },
  "WPFInstallnuget": {
    "winget": "Microsoft.NuGet",
    "choco": "nuget.commandline"
  },
  "WPFInstallwinrar": {
    "winget": "RARLab.WinRar",
    "choco": "winrar"
  },
  "WPFInstallneovim": {
    "winget": "Neovim.Neovim",
    "choco": "neovim"
  },
  "WPFInstallnvm": {
    "winget": "CoreyButler.NVMforWindows",
    "choco": "nvm"
  },
  "WPFInstallpostman": {
    "winget": "Postman.Postman",
    "choco": "postman"
  }
}' | convertfrom-json
$sync.configs.dns = '{
    "Google":{
        "Primary": "8.8.8.8",
        "Secondary": "8.8.4.4"
    },
    "Cloudflare":{
        "Primary": "1.1.1.1",
        "Secondary": "1.0.0.1"
    },
    "Cloudflare_Malware":{
        "Primary": "1.1.1.2",
        "Secondary": "1.0.0.2"
    },
    "Cloudflare_Malware_Adult":{
        "Primary": "1.1.1.3",
        "Secondary": "1.0.0.3"
    },
    "Level3":{
        "Primary": "4.2.2.2",
        "Secondary": "4.2.2.1"
    },
    "Open_DNS":{
        "Primary": "208.67.222.222",
        "Secondary": "208.67.220.220"
    },
    "Quad9":{
        "Primary": "9.9.9.9",
        "Secondary": "149.112.112.112"
    }
}' | convertfrom-json
$sync.configs.feature = '{
  "WPFFeaturesdotnet": {
    "feature": [
      "NetFx4-AdvSrvs",
      "NetFx3"
    ],
    "InvokeScript": [

    ]
  },
  "WPFFeatureshyperv": {
    "feature": [
      "HypervisorPlatform",
      "Microsoft-Hyper-V-All",
      "Microsoft-Hyper-V",
      "Microsoft-Hyper-V-Tools-All",
      "Microsoft-Hyper-V-Management-PowerShell",
      "Microsoft-Hyper-V-Hypervisor",
      "Microsoft-Hyper-V-Services",
      "Microsoft-Hyper-V-Management-Clients"
    ],
    "InvokeScript": [
      "Start-Process -FilePath cmd.exe -ArgumentList ''/c bcdedit /set hypervisorschedulertype classic'' -Wait"
    ]
  },
  "WPFFeatureslegacymedia": {
    "feature": [
      "WindowsMediaPlayer",
      "MediaPlayback",
      "DirectPlay",
      "LegacyComponents"
    ],
    "InvokeScript": [

    ]
  },
  "WPFFeaturewsl": {
    "feature": [
      "VirtualMachinePlatform",
      "Microsoft-Windows-Subsystem-Linux"
    ],
    "InvokeScript": [
      
    ]
  },
  "WPFFeaturenfs": {
    "feature": [
      "ServicesForNFS-ClientOnly",
      "ClientForNFS-Infrastructure",
      "NFS-Administration"
    ],
    "InvokeScript": [
      "nfsadmin client stop
      Set-ItemProperty -Path ''HKLM:\\SOFTWARE\\Microsoft\\ClientForNFS\\CurrentVersion\\Default'' -Name ''AnonymousUID'' -Type DWord -Value 0
      Set-ItemProperty -Path ''HKLM:\\SOFTWARE\\Microsoft\\ClientForNFS\\CurrentVersion\\Default'' -Name ''AnonymousGID'' -Type DWord -Value 0
      nfsadmin client start
      nfsadmin client localhost config fileaccess=755 SecFlavors=+sys -krb5 -krb5i
      "
    ]
  }
}' | convertfrom-json
$sync.configs.preset = '{
  "desktop": [
    "WPFEssTweaksAH",
    "WPFEssTweaksDVR",
    "WPFEssTweaksHiber",
    "WPFEssTweaksHome",
    "WPFEssTweaksLoc",
    "WPFEssTweaksOO",
    "WPFEssTweaksRP",
    "WPFEssTweaksServices",
    "WPFEssTweaksStorage",
    "WPFEssTweaksTele",
    "WPFEssTweaksWifi",
    "WPFMiscTweaksPower",
    "WPFMiscTweaksNum"
  ],
  "laptop": [
    "WPFEssTweaksAH",
    "WPFEssTweaksDVR",
    "WPFEssTweaksHome",
    "WPFEssTweaksLoc",
    "WPFEssTweaksOO",
    "WPFEssTweaksRP",
    "WPFEssTweaksServices",
    "WPFEssTweaksStorage",
    "WPFEssTweaksTele",
    "WPFEssTweaksWifi",
    "WPFMiscTweaksLapPower",
    "WPFMiscTweaksLapNum"
  ],
  "minimal": [
    "WPFEssTweaksHome",
    "WPFEssTweaksOO",
    "WPFEssTweaksRP",
    "WPFEssTweaksServices",
    "WPFEssTweaksTele"
  ]
}' | convertfrom-json
$sync.configs.tweaks = '{
  "WPFEssTweaksAH": {
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System",
        "Name": "EnableActivityFeed",
        "Type": "DWord",
        "Value": "0",
        "OriginalValue": "1"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System",
        "Name": "PublishUserActivities",
        "Type": "DWord",
        "Value": "0",
        "OriginalValue": "1"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System",
        "Name": "UploadUserActivities",
        "Type": "DWord",
        "Value": "0",
        "OriginalValue": "1"
      }
    ]
  },
  "WPFEssTweaksHiber": {
    "registry": [
      {
        "Path": "HKLM:\\System\\CurrentControlSet\\Control\\Session Manager\\Power",
        "Name": "HibernateEnabled",
        "Type": "Dword",
        "Value": "0",
        "OriginalValue": "1"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\FlyoutMenuSettings",
        "Name": "ShowHibernateOption",
        "Type": "Dword",
        "Value": "0",
        "OriginalValue": "1"
      }
    ]
  },
  "WPFEssTweaksHome": {
    "service": [
      {
        "Name": "HomeGroupListener",
        "StartupType": "Manual",
        "OriginalType": "Automatic"
      },
      {
        "Name": "HomeGroupProvider",
        "StartupType": "Manual",
        "OriginalType": "Automatic"
      }
    ]
  },
  "WPFEssTweaksLoc": {
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\CapabilityAccessManager\\ConsentStore\\location",
        "Name": "Value",
        "Type": "String",
        "Value": "Deny",
        "OriginalValue": "Allow"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Sensor\\Overrides\\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}",
        "Name": "SensorPermissionState",
        "Type": "Dword",
        "Value": "0",
        "OriginalValue": "1"
      },
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\lfsvc\\Service\\Configuration",
        "Name": "Status",
        "Type": "Dword",
        "Value": "0",
        "OriginalValue": "1"
      },
      {
        "Path": "HKLM:\\SYSTEM\\Maps",
        "Name": "AutoUpdateEnabled",
        "Type": "Dword",
        "Value": "0",
        "OriginalValue": "1"
      }
    ]
  },
  "WPFEssTweaksServices": {
    "service": [
      {
        "Name": "AJRouter",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "ALG",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "AppIDSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "AppMgmt",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "AppReadiness",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "AppVClient",
        "OriginalType": "Disabled"
      },
      {
        "Name": "AppXSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "Appinfo",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "AssignedAccessManagerSvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "AudioEndpointBuilder",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "AudioSrv",
        "StartupType": "Automatic"
      },
      {
        "Name": "Audiosrv",
        "OriginalType": "Automatic"
      },
      {
        "Name": "AxInstSV",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "BDESVC",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "BFE",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "BITS",
        "StartupType": "AutomaticDelayedStart",
        "OriginalType": "Automatic"
      },
      {
        "Name": "BTAGService",
        "OriginalType": "Manual"
      },
      {
        "Name": "BcastDVRUserService_dc2a4",
        "OriginalType": "Manual"
      },
      {
        "Name": "BluetoothUserService_dc2a4",
        "OriginalType": "Manual"
      },
      {
        "Name": "BrokerInfrastructure",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "Browser",
        "StartupType": "Manual"
      },
      {
        "Name": "BthAvctpSvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "BthHFSrv",
        "StartupType": "Manual"
      },
      {
        "Name": "CDPSvc",
        "StartupType": "Manual",
        "OriginalType": "Automatic"
      },
      {
        "Name": "CDPUserSvc_dc2a4",
        "OriginalType": "Automatic"
      },
      {
        "Name": "COMSysApp",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "CaptureService_dc2a4",
        "OriginalType": "Manual"
      },
      {
        "Name": "CertPropSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "ClipSVC",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "ConsentUxUserSvc_dc2a4",
        "OriginalType": "Manual"
      },
      {
        "Name": "CoreMessagingRegistrar",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "CredentialEnrollmentManagerUserSvc_dc2a4",
        "OriginalType": "Manual"
      },
      {
        "Name": "CryptSvc",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "CscService",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "DPS",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "DcomLaunch",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "DcpSvc",
        "StartupType": "Manual"
      },
      {
        "Name": "DevQueryBroker",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "DeviceAssociationBrokerSvc_dc2a4",
        "OriginalType": "Manual"
      },
      {
        "Name": "DeviceAssociationService",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "DeviceInstall",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "DevicePickerUserSvc_dc2a4",
        "OriginalType": "Manual"
      },
      {
        "Name": "DevicesFlowUserSvc_dc2a4",
        "OriginalType": "Manual"
      },
      {
        "Name": "Dhcp",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "DiagTrack",
        "StartupType": "Disabled",
        "OriginalType": "Automatic"
      },
      {
        "Name": "DialogBlockingService",
        "OriginalType": "Disabled"
      },
      {
        "Name": "DispBrokerDesktopSvc",
        "OriginalType": "Automatic"
      },
      {
        "Name": "DisplayEnhancementService",
        "OriginalType": "Manual"
      },
      {
        "Name": "DmEnrollmentSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "Dnscache",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "DoSvc",
        "StartupType": "AutomaticDelayedStart",
        "OriginalType": "Automatic"
      },
      {
        "Name": "DsSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "DsmSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "DusmSvc",
        "OriginalType": "Automatic"
      },
      {
        "Name": "EFS",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "EapHost",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "EntAppSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "EventLog",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "EventSystem",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "FDResPub",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "Fax",
        "StartupType": "Manual"
      },
      {
        "Name": "FontCache",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "FrameServer",
        "OriginalType": "Manual"
      },
      {
        "Name": "FrameServerMonitor",
        "OriginalType": "Manual"
      },
      {
        "Name": "GraphicsPerfSvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "HomeGroupListener",
        "StartupType": "Manual"
      },
      {
        "Name": "HomeGroupProvider",
        "StartupType": "Manual"
      },
      {
        "Name": "HvHost",
        "OriginalType": "Manual"
      },
      {
        "Name": "IEEtwCollectorService",
        "StartupType": "Manual"
      },
      {
        "Name": "IKEEXT",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "InstallService",
        "OriginalType": "Manual"
      },
      {
        "Name": "InventorySvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "IpxlatCfgSvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "KeyIso",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "KtmRm",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "LSM",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "LanmanServer",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "LanmanWorkstation",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "LicenseManager",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "LxpSvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "MSDTC",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "MSiSCSI",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "MapsBroker",
        "StartupType": "AutomaticDelayedStart",
        "OriginalType": "Automatic"
      },
      {
        "Name": "McpManagementService",
        "OriginalType": "Manual"
      },
      {
        "Name": "MessagingService_dc2a4",
        "OriginalType": "Manual"
      },
      {
        "Name": "MicrosoftEdgeElevationService",
        "OriginalType": "Manual"
      },
      {
        "Name": "MixedRealityOpenXRSvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "MpsSvc",
        "StartupType": "Automatic"
      },
      {
        "Name": "MsKeyboardFilter",
        "OriginalType": "Disabled"
      },
      {
        "Name": "NPSMSvc_dc2a4",
        "OriginalType": "Manual"
      },
      {
        "Name": "NaturalAuthentication",
        "OriginalType": "Manual"
      },
      {
        "Name": "NcaSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "NcbService",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "NcdAutoSetup",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "NetSetupSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "NetTcpPortSharing",
        "StartupType": "Disabled",
        "OriginalType": "Disabled"
      },
      {
        "Name": "Netlogon",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "Netman",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "NgcCtnrSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "NgcSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "NlaSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "OneSyncSvc_dc2a4",
        "OriginalType": "Automatic"
      },
      {
        "Name": "P9RdrService_dc2a4",
        "OriginalType": "Manual"
      },
      {
        "Name": "PNRPAutoReg",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "PNRPsvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "PcaSvc",
        "StartupType": "Manual",
        "OriginalType": "Automatic"
      },
      {
        "Name": "PeerDistSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "PenService_dc2a4",
        "OriginalType": "Manual"
      },
      {
        "Name": "PerfHost",
        "OriginalType": "Manual"
      },
      {
        "Name": "PhoneSvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "PimIndexMaintenanceSvc_dc2a4",
        "OriginalType": "Manual"
      },
      {
        "Name": "PlugPlay",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "PolicyAgent",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "Power",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "PrintNotify",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "PrintWorkflowUserSvc_dc2a4",
        "OriginalType": "Manual"
      },
      {
        "Name": "ProfSvc",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "PushToInstall",
        "OriginalType": "Manual"
      },
      {
        "Name": "QWAVE",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "RasAuto",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "RasMan",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "RemoteAccess",
        "StartupType": "Disabled",
        "OriginalType": "Disabled"
      },
      {
        "Name": "RemoteRegistry",
        "StartupType": "Disabled",
        "OriginalType": "Disabled"
      },
      {
        "Name": "RetailDemo",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "RmSvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "RpcEptMapper",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "RpcLocator",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "RpcSs",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "SCPolicySvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "SCardSvr",
        "StartupType": "Disabled",
        "OriginalType": "Manual"
      },
      {
        "Name": "SDRSVC",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "SEMgrSvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "SENS",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "SNMPTRAP",
        "StartupType": "Manual"
      },
      {
        "Name": "SNMPTrap",
        "OriginalType": "Manual"
      },
      {
        "Name": "SSDPSRV",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "SamSs",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "ScDeviceEnum",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "Schedule",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "SecurityHealthService",
        "OriginalType": "Manual"
      },
      {
        "Name": "Sense",
        "OriginalType": "Manual"
      },
      {
        "Name": "SensorDataService",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "SensorService",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "SensrSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "SessionEnv",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "SgrmBroker",
        "OriginalType": "Automatic"
      },
      {
        "Name": "SharedAccess",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "SharedRealitySvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "ShellHWDetection",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "SmsRouter",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "Spooler",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "SstpSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "StateRepository",
        "StartupType": "Manual",
        "OriginalType": "Automatic"
      },
      {
        "Name": "StiSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "StorSvc",
        "StartupType": "Manual",
        "OriginalType": "Automatic"
      },
      {
        "Name": "SysMain",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "SystemEventsBroker",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "TabletInputService",
        "StartupType": "Manual"
      },
      {
        "Name": "TapiSrv",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "TermService",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "TextInputManagementService",
        "OriginalType": "Automatic"
      },
      {
        "Name": "Themes",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "TieringEngineService",
        "OriginalType": "Manual"
      },
      {
        "Name": "TimeBroker",
        "StartupType": "Manual"
      },
      {
        "Name": "TimeBrokerSvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "TokenBroker",
        "OriginalType": "Manual"
      },
      {
        "Name": "TrkWks",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "TroubleshootingSvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "TrustedInstaller",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "UI0Detect",
        "StartupType": "Manual"
      },
      {
        "Name": "UdkUserSvc_dc2a4",
        "OriginalType": "Manual"
      },
      {
        "Name": "UevAgentService",
        "OriginalType": "Disabled"
      },
      {
        "Name": "UmRdpService",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "UnistoreSvc_dc2a4",
        "OriginalType": "Manual"
      },
      {
        "Name": "UserDataSvc_dc2a4",
        "OriginalType": "Manual"
      },
      {
        "Name": "UserManager",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "UsoSvc",
        "StartupType": "Manual",
        "OriginalType": "Automatic"
      },
      {
        "Name": "VGAuthService",
        "OriginalType": "Automatic"
      },
      {
        "Name": "VMTools",
        "OriginalType": "Automatic"
      },
      {
        "Name": "VSS",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "VacSvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "VaultSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "W32Time",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "WEPHOSTSVC",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "WFDSConMgrSvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "WMPNetworkSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "WManSvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "WPDBusEnum",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "WSService",
        "StartupType": "Manual"
      },
      {
        "Name": "WSearch",
        "StartupType": "AutomaticDelayedStart",
        "OriginalType": "Automatic"
      },
      {
        "Name": "WaaSMedicSvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "WalletService",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "WarpJITSvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "WbioSrvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "Wcmsvc",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "WcsPlugInService",
        "StartupType": "Manual"
      },
      {
        "Name": "WdNisSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "WdiServiceHost",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "WdiSystemHost",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "WebClient",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "Wecsvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "WerSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "WiaRpc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "WinDefend",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "WinHttpAutoProxySvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "WinRM",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "Winmgmt",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "WlanSvc",
        "OriginalType": "Automatic"
      },
      {
        "Name": "WpcMonSvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "WpnService",
        "StartupType": "Manual",
        "OriginalType": "Automatic"
      },
      {
        "Name": "WpnUserService_dc2a4",
        "OriginalType": "Automatic"
      },
      {
        "Name": "WwanSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "XblAuthManager",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "XblGameSave",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "XboxGipSvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "XboxNetApiSvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "autotimesvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "bthserv",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "camsvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "cbdhsvc_dc2a4",
        "OriginalType": "Automatic"
      },
      {
        "Name": "cloudidsvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "dcsvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "defragsvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "diagnosticshub.standardcollector.service",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "diagsvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "dmwappushservice",
        "StartupType": "Disabled",
        "OriginalType": "Manual"
      },
      {
        "Name": "dot3svc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "edgeupdate",
        "OriginalType": "Automatic"
      },
      {
        "Name": "edgeupdatem",
        "OriginalType": "Manual"
      },
      {
        "Name": "embeddedmode",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "fdPHost",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "fhsvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "gpsvc",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "hidserv",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "icssvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "iphlpsvc",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "lfsvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "lltdsvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "lmhosts",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "mpssvc",
        "OriginalType": "Automatic"
      },
      {
        "Name": "msiserver",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "netprofm",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "nsi",
        "StartupType": "Automatic",
        "OriginalType": "Automatic"
      },
      {
        "Name": "p2pimsvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "p2psvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "perceptionsimulation",
        "OriginalType": "Manual"
      },
      {
        "Name": "pla",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "seclogon",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "shpamsvc",
        "OriginalType": "Disabled"
      },
      {
        "Name": "smphost",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "spectrum",
        "OriginalType": "Manual"
      },
      {
        "Name": "sppsvc",
        "StartupType": "AutomaticDelayedStart",
        "OriginalType": "Automatic"
      },
      {
        "Name": "ssh-agent",
        "OriginalType": "Disabled"
      },
      {
        "Name": "svsvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "swprv",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "tiledatamodelsvc",
        "StartupType": "Automatic"
      },
      {
        "Name": "tzautoupdate",
        "OriginalType": "Disabled"
      },
      {
        "Name": "uhssvc",
        "OriginalType": "Disabled"
      },
      {
        "Name": "upnphost",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "vds",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "vm3dservice",
        "OriginalType": "Automatic"
      },
      {
        "Name": "vmicguestinterface",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "vmicheartbeat",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "vmickvpexchange",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "vmicrdv",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "vmicshutdown",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "vmictimesync",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "vmicvmsession",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "vmicvss",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "vmvss",
        "OriginalType": "Manual"
      },
      {
        "Name": "wbengine",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "wcncsvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "webthreatdefsvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "webthreatdefusersvc_dc2a4",
        "OriginalType": "Automatic"
      },
      {
        "Name": "wercplsupport",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "wisvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "wlidsvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "wlpasvc",
        "OriginalType": "Manual"
      },
      {
        "Name": "wmiApSrv",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "workfolderssvc",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "wscsvc",
        "StartupType": "AutomaticDelayedStart",
        "OriginalType": "Automatic"
      },
      {
        "Name": "wuauserv",
        "StartupType": "Manual",
        "OriginalType": "Manual"
      },
      {
        "Name": "wudfsvc",
        "StartupType": "Manual"
      }
    ]
  },
  "WPFEssTweaksTele": {
    "ScheduledTask": [
      {
        "Name": "Microsoft\\Windows\\Application Experience\\Microsoft Compatibility Appraiser",
        "State": "Disabled",
        "OriginalState": "Enabled"
      },
      {
        "Name": "Microsoft\\Windows\\Application Experience\\ProgramDataUpdater",
        "State": "Disabled",
        "OriginalState": "Enabled"
      },
      {
        "Name": "Microsoft\\Windows\\Autochk\\Proxy",
        "State": "Disabled",
        "OriginalState": "Enabled"
      },
      {
        "Name": "Microsoft\\Windows\\Customer Experience Improvement Program\\Consolidator",
        "State": "Disabled",
        "OriginalState": "Enabled"
      },
      {
        "Name": "Microsoft\\Windows\\Customer Experience Improvement Program\\UsbCeip",
        "State": "Disabled",
        "OriginalState": "Enabled"
      },
      {
        "Name": "Microsoft\\Windows\\DiskDiagnostic\\Microsoft-Windows-DiskDiagnosticDataCollector",
        "State": "Disabled",
        "OriginalState": "Enabled"
      },
      {
        "Name": "Microsoft\\Windows\\Feedback\\Siuf\\DmClient",
        "State": "Disabled",
        "OriginalState": "Enabled"
      },
      {
        "Name": "Microsoft\\Windows\\Feedback\\Siuf\\DmClientOnScenarioDownload",
        "State": "Disabled",
        "OriginalState": "Enabled"
      },
      {
        "Name": "Microsoft\\Windows\\Windows Error Reporting\\QueueReporting",
        "State": "Disabled",
        "OriginalState": "Enabled"
      }
    ],
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\DataCollection",
        "type": "Dword",
        "value": 0,
        "name": "AllowTelemetry",
        "OriginalValue": "1"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection",
        "OriginalValue": "1",
        "name": "AllowTelemetry",
        "value": 0,
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager",
        "OriginalValue": "1",
        "name": "ContentDeliveryAllowed",
        "value": 0,
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager",
        "OriginalValue": "1",
        "name": "OemPreInstalledAppsEnabled",
        "value": 0,
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager",
        "OriginalValue": "1",
        "name": "PreInstalledAppsEnabled",
        "value": 0,
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager",
        "OriginalValue": "1",
        "name": "PreInstalledAppsEverEnabled",
        "value": 0,
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager",
        "OriginalValue": "1",
        "name": "SilentInstalledAppsEnabled",
        "value": 0,
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager",
        "OriginalValue": "1",
        "name": "SubscribedContent-338387Enabled",
        "value": 0,
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager",
        "OriginalValue": "1",
        "name": "SubscribedContent-338388Enabled",
        "value": 0,
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager",
        "OriginalValue": "1",
        "name": "SubscribedContent-338389Enabled",
        "value": 0,
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager",
        "OriginalValue": "1",
        "name": "SubscribedContent-353698Enabled",
        "value": 0,
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager",
        "OriginalValue": "1",
        "name": "SystemPaneSuggestionsEnabled",
        "value": 0,
        "type": "Dword"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\CloudContent",
        "OriginalValue": "0",
        "name": "DisableWindowsConsumerFeatures",
        "value": 1,
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\SOFTWARE\\Microsoft\\Siuf\\Rules",
        "OriginalValue": "0",
        "name": "NumberOfSIUFInPeriod",
        "value": 0,
        "type": "Dword"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection",
        "OriginalValue": "0",
        "name": "DoNotShowFeedbackNotifications",
        "value": 1,
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\SOFTWARE\\Policies\\Microsoft\\Windows\\CloudContent",
        "OriginalValue": "0",
        "name": "DisableTailoredExperiencesWithDiagnosticData",
        "value": 1,
        "type": "Dword"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\AdvertisingInfo",
        "OriginalValue": "0",
        "name": "DisabledByGroupPolicy",
        "value": 1,
        "type": "Dword"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\Windows Error Reporting",
        "OriginalValue": "0",
        "name": "Disabled",
        "value": 1,
        "type": "Dword"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\DeliveryOptimization\\Config",
        "OriginalValue": "1",
        "name": "DODownloadMode",
        "value": 1,
        "type": "Dword"
      },
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Remote Assistance",
        "OriginalValue": "1",
        "name": "fAllowToGetHelp",
        "value": 0,
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\OperationStatusManager",
        "OriginalValue": "0",
        "name": "EnthusiastMode",
        "value": 1,
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "OriginalValue": "1",
        "name": "ShowTaskViewButton",
        "value": 0,
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced\\People",
        "OriginalValue": "1",
        "name": "PeopleBand",
        "value": 0,
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "OriginalValue": "1",
        "name": "LaunchTo",
        "value": 1,
        "type": "Dword"
      },
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\FileSystem",
        "OriginalValue": "0",
        "name": "LongPathsEnabled",
        "value": 1,
        "type": "Dword"
      },
      {
        "_Comment" : "Driver searching is a function that should be left in",
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\DriverSearching",
        "OriginalValue": "1",
        "name": "SearchOrderConfig",
        "value": "1",
        "type": "Dword"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile",
        "OriginalValue": "1",
        "name": "SystemResponsiveness",
        "value": "0",
        "type": "Dword"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile",
        "OriginalValue": "1",
        "name": "NetworkThrottlingIndex",
        "value": "4294967295",
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\Control Panel\\Desktop",
        "OriginalValue": "1",
        "name": "MenuShowDelay",
        "value": "1",
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\Control Panel\\Desktop",
        "OriginalValue": "1",
        "name": "AutoEndTasks",
        "value": "1",
        "type": "Dword"
      },
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management",
        "OriginalValue": "0",
        "name": "ClearPageFileAtShutdown",
        "value": "0",
        "type": "Dword"
      },
      {
        "Path": "HKLM:\\SYSTEM\\ControlSet001\\Services\\Ndu",
        "OriginalValue": "1",
        "name": "Start",
        "value": "4",
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\Control Panel\\Mouse",
        "OriginalValue": "400",
        "name": "MouseHoverTime",
        "value": "400",
        "type": "String"
      },
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\LanmanServer\\Parameters",
        "OriginalValue": "20",
        "name": "IRPStackSize",
        "value": "30",
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Windows Feeds",
        "OriginalValue": "1",
        "name": "EnableFeeds",
        "value": "0",
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Feeds",
        "OriginalValue": "1",
        "name": "ShellFeedsTaskbarViewMode",
        "value": "2",
        "type": "Dword"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer",
        "OriginalValue": "1",
        "name": "HideSCAMeetNow",
        "value": "1",
        "type": "Dword"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Games",
        "OriginalValue": "1",
        "name": "GPU Priority",
        "value": "8",
        "type": "Dword"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Games",
        "OriginalValue": "1",
        "name": "Priority",
        "value": "6",
        "type": "Dword"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Multimedia\\SystemProfile\\Tasks\\Games",
        "OriginalValue": "High",
        "name": "Scheduling Category",
        "value": "High",
        "type": "String"
      }
    ],
    "service": [
      {
        "Name": "DiagTrack",
        "StartupType": "Disabled",
        "OriginalType": "Automatic"
      },
      {
        "Name": "dmwappushservice",
        "StartupType": "Disabled",
        "OriginalType": "Manual"
      },
      {
        "Name": "SysMain",
        "StartupType": "Disabled",
        "OriginalType": "Manual"
      }
    ],
    "InvokeScript": [
      "bcdedit /set `{current`} bootmenupolicy Legacy | Out-Null
        If ((get-ItemProperty -Path \"HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\" -Name CurrentBuild).CurrentBuild -lt 22557) {
            $taskmgr = Start-Process -WindowStyle Hidden -FilePath taskmgr.exe -PassThru
            Do {
                Start-Sleep -Milliseconds 100
                $preferences = Get-ItemProperty -Path \"HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\TaskManager\" -Name \"Preferences\" -ErrorAction SilentlyContinue
            } Until ($preferences)
            Stop-Process $taskmgr
            $preferences.Preferences[28] = 0
            Set-ItemProperty -Path \"HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\TaskManager\" -Name \"Preferences\" -Type Binary -Value $preferences.Preferences
        }
        Remove-Item -Path \"HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\MyComputer\\NameSpace\\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}\" -Recurse -ErrorAction SilentlyContinue  

        # Group svchost.exe processes
        $ram = (Get-CimInstance -ClassName Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1kb
        Set-ItemProperty -Path \"HKLM:\\SYSTEM\\CurrentControlSet\\Control\" -Name \"SvcHostSplitThresholdInKB\" -Type DWord -Value $ram -Force

        $autoLoggerDir = \"$env:PROGRAMDATA\\Microsoft\\Diagnosis\\ETLLogs\\AutoLogger\"
        If (Test-Path \"$autoLoggerDir\\AutoLogger-Diagtrack-Listener.etl\") {
            Remove-Item \"$autoLoggerDir\\AutoLogger-Diagtrack-Listener.etl\"
        }
        icacls $autoLoggerDir /deny SYSTEM:`(OI`)`(CI`)F | Out-Null

        $ram = (Get-CimInstance -ClassName \"Win32_PhysicalMemory\" | Measure-Object -Property Capacity -Sum).Sum / 1kb
        Set-ItemProperty -Path \"HKLM:\\SYSTEM\\CurrentControlSet\\Control\" -Name \"SvcHostSplitThresholdInKB\" -Type DWord -Value $ram -Force
        "
    ]
  },
  "WPFEssTweaksWifi": {
    "registry": [
      {
        "Path": "HKLM:\\Software\\Microsoft\\PolicyManager\\default\\WiFi\\AllowWiFiHotSpotReporting",
        "Name": "Value",
        "Type": "DWord",
        "Value": "0",
        "OriginalValue": "1"
      },
      {
        "Path": "HKLM:\\Software\\Microsoft\\PolicyManager\\default\\WiFi\\AllowAutoConnectToWiFiSenseHotspots",
        "Name": "Value",
        "Type": "DWord",
        "Value": "0",
        "OriginalValue": "1"
      }
    ]
  },
  "WPFMiscTweaksLapPower": {
    "registry": [
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Power\\PowerThrottling",
        "Name": "PowerThrottlingOff",
        "Type": "DWord",
        "Value": "00000000",
        "OriginalValue": "00000001"
      },
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Power",
        "Name": "HiberbootEnabled",
        "Type": "DWord",
        "Value": "0000001",
        "OriginalValue": "0000000"
      }
    ]
  },
  "WPFMiscTweaksPower": {
    "registry": [
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Power\\PowerThrottling",
        "Name": "PowerThrottlingOff",
        "Type": "DWord",
        "Value": "00000001",
        "OriginalValue": "00000000"
      },
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Power",
        "Name": "HiberbootEnabled",
        "Type": "DWord",
        "Value": "0000000",
        "OriginalValue": "00000001"
      }
    ]
  },
  "WPFMiscTweaksExt": {
    "registry": [
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "Name": "HideFileExt",
        "Type": "DWord",
        "Value": "0",
        "OriginalValue": "1"
      }
    ]
  },
  "WPFMiscTweaksUTC": {
    "registry": [
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\TimeZoneInformation",
        "Name": "RealTimeIsUniversal",
        "Type": "DWord",
        "Value": "1",
        "OriginalValue": "0"
      }
    ]
  },
  "WPFMiscTweaksDisplay": {
    "registry": [
      {
        "path": "HKCU:\\Control Panel\\Desktop",
        "OriginalValue": "1",
        "name": "DragFullWindows",
        "value": "0",
        "type": "String"
      },
      {
        "path": "HKCU:\\Control Panel\\Desktop",
        "OriginalValue": "1",
        "name": "MenuShowDelay",
        "value": "200",
        "type": "String"
      },
      {
        "path": "HKCU:\\Control Panel\\Desktop\\WindowMetrics",
        "OriginalValue": "1",
        "name": "MinAnimate",
        "value": "0",
        "type": "String"
      },
      {
        "path": "HKCU:\\Control Panel\\Keyboard",
        "OriginalValue": "1",
        "name": "KeyboardDelay",
        "value": "0",
        "type": "DWord"
      },
      {
        "path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "OriginalValue": "1",
        "name": "ListviewAlphaSelect",
        "value": "0",
        "type": "DWord"
      },
      {
        "path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "OriginalValue": "1",
        "name": "ListviewShadow",
        "value": "0",
        "type": "DWord"
      },
      {
        "path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "OriginalValue": "1",
        "name": "TaskbarAnimations",
        "value": "0",
        "type": "DWord"
      },
      {
        "path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\VisualEffects",
        "OriginalValue": "1",
        "name": "VisualFXSetting",
        "value": "3",
        "type": "DWord"
      },
      {
        "path": "HKCU:\\Software\\Microsoft\\Windows\\DWM",
        "OriginalValue": "1",
        "name": "EnableAeroPeek",
        "value": "0",
        "type": "DWord"
      }
    ],
    "InvokeScript": [
      "Set-ItemProperty -Path \"HKCU:\\Control Panel\\Desktop\" -Name \"UserPreferencesMask\" -Type Binary -Value ([byte[]](144,18,3,128,16,0,0,0))"
    ]
  },
  "WPFEssTweaksDeBloat": {
    "appx": [
      "Microsoft.Microsoft3DViewer",
      "Microsoft.AppConnector",
      "Microsoft.BingFinance",
      "Microsoft.BingNews",
      "Microsoft.BingSports",
      "Microsoft.BingTranslator",
      "Microsoft.BingWeather",
      "Microsoft.BingFoodAndDrink",
      "Microsoft.BingHealthAndFitness",
      "Microsoft.BingTravel",
      "Microsoft.MinecraftUWP",
      "Microsoft.GamingServices",
      "Microsoft.GetHelp",
      "Microsoft.Getstarted",
      "Microsoft.Messaging",
      "Microsoft.Microsoft3DViewer",
      "Microsoft.MicrosoftSolitaireCollection",
      "Microsoft.NetworkSpeedTest",
      "Microsoft.News",
      "Microsoft.Office.Lens",
      "Microsoft.Office.Sway",
      "Microsoft.Office.OneNote",
      "Microsoft.OneConnect",
      "Microsoft.People",
      "Microsoft.Print3D",
      "Microsoft.SkypeApp",
      "Microsoft.Wallet",
      "Microsoft.Whiteboard",
      "Microsoft.WindowsAlarms",
      "microsoft.windowscommunicationsapps",
      "Microsoft.WindowsFeedbackHub",
      "Microsoft.WindowsMaps",
      "Microsoft.WindowsPhone",
      "Microsoft.WindowsSoundRecorder",
      "Microsoft.XboxApp",
      "Microsoft.ConnectivityStore",
      "Microsoft.CommsPhone",
      "Microsoft.ScreenSketch",
      "Microsoft.Xbox.TCUI",
      "Microsoft.XboxGameOverlay",
      "Microsoft.XboxGameCallableUI",
      "Microsoft.XboxSpeechToTextOverlay",
      "Microsoft.MixedReality.Portal",
      "Microsoft.XboxIdentityProvider",
      "Microsoft.ZuneMusic",
      "Microsoft.ZuneVideo",
      "Microsoft.Getstarted",
      "Microsoft.MicrosoftOfficeHub",
      "*EclipseManager*",
      "*ActiproSoftwareLLC*",
      "*AdobeSystemsIncorporated.AdobePhotoshopExpress*",
      "*Duolingo-LearnLanguagesforFree*",
      "*PandoraMediaInc*",
      "*CandyCrush*",
      "*BubbleWitch3Saga*",
      "*Wunderlist*",
      "*Flipboard*",
      "*Twitter*",
      "*Facebook*",
      "*Royal Revolt*",
      "*Sway*",
      "*Speed Test*",
      "*Dolby*",
      "*Viber*",
      "*ACGMediaPlayer*",
      "*Netflix*",
      "*OneCalendar*",
      "*LinkedInforWindows*",
      "*HiddenCityMysteryofShadows*",
      "*Hulu*",
      "*HiddenCity*",
      "*AdobePhotoshopExpress*",
      "*HotspotShieldFreeVPN*",
      "*Microsoft.Advertising.Xaml*"
    ],
    "InvokeScript": [
      "
        $TeamsPath = [System.IO.Path]::Combine($env:LOCALAPPDATA, ''Microsoft'', ''Teams'')
        $TeamsUpdateExePath = [System.IO.Path]::Combine($TeamsPath, ''Update.exe'')
    
        Write-Host \"Stopping Teams process...\"
        Stop-Process -Name \"*teams*\" -Force -ErrorAction SilentlyContinue
    
        Write-Host \"Uninstalling Teams from AppData\\Microsoft\\Teams\"
        if ([System.IO.File]::Exists($TeamsUpdateExePath)) {
            # Uninstall app
            $proc = Start-Process $TeamsUpdateExePath \"-uninstall -s\" -PassThru
            $proc.WaitForExit()
        }
    
        Write-Host \"Removing Teams AppxPackage...\"
        Get-AppxPackage \"*Teams*\" | Remove-AppxPackage -ErrorAction SilentlyContinue
        Get-AppxPackage \"*Teams*\" -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    
        Write-Host \"Deleting Teams directory\"
        if ([System.IO.Directory]::Exists($TeamsPath)) {
            Remove-Item $TeamsPath -Force -Recurse -ErrorAction SilentlyContinue
        }
    
        Write-Host \"Deleting Teams uninstall registry key\"
        # Uninstall from Uninstall registry key UninstallString
        $us = (Get-ChildItem -Path HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall, HKLM:\\SOFTWARE\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall | Get-ItemProperty | Where-Object { $_.DisplayName -like ''*Teams*''}).UninstallString
        if ($us.Length -gt 0) {
            $us = ($us.Replace(''/I'', ''/uninstall '') + '' /quiet'').Replace(''  '', '' '')
            $FilePath = ($us.Substring(0, $us.IndexOf(''.exe'') + 4).Trim())
            $ProcessArgs = ($us.Substring($us.IndexOf(''.exe'') + 5).Trim().replace(''  '', '' ''))
            $proc = Start-Process -FilePath $FilePath -Args $ProcessArgs -PassThru
            $proc.WaitForExit()
        }
      "
    ]
  },
  "WPFEssTweaksOO": {
    "InvokeScript": [
      "curl.exe -s \"https://raw.githubusercontent.com/ChrisTitusTech/winutil/main/ooshutup10_winutil_settings.cfg\" -o $ENV:temp\\ooshutup10.cfg
       curl.exe -s \"https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe\" -o $ENV:temp\\OOSU10.exe
       Start-Process $ENV:temp\\OOSU10.exe -ArgumentList \"$ENV:temp\\ooshutup10.cfg /quiet\"
       "
    ]
  },
  "WPFEssTweaksRP": {
    "InvokeScript": [
      "Enable-ComputerRestore -Drive \"$env:SystemDrive\"
       Checkpoint-Computer -Description \"RestorePoint1\" -RestorePointType \"MODIFY_SETTINGS\""
    ]
  },
  "WPFEssTweaksStorage": {
    "InvokeScript": [
      "Remove-Item -Path \"HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\StorageSense\\Parameters\\StoragePolicy\" -Recurse -ErrorAction SilentlyContinue"
    ]
  },
  "WPFMiscTweaksLapNum": {
    "Registry": [
      {
        "path": "HKU:\\.DEFAULT\\Control Panel\\Keyboard",
        "OriginalValue": "1",
        "name": "InitialKeyboardIndicators",
        "value": "0",
        "type": "DWord"
      }
    ]
  },
  "WPFMiscTweaksNum": {
    "Registry": [
      {
        "path": "HKU:\\.DEFAULT\\Control Panel\\Keyboard",
        "OriginalValue": "1",
        "name": "InitialKeyboardIndicators",
        "value": "80000002",
        "type": "DWord"
      }
    ]
  },
  "WPFEssTweaksRemoveEdge": {
    "InvokeScript": [
        "      
        # Stop Edge Task
        Stop-Process -Name \"msedge\" -Force -ErrorAction SilentlyContinue

        # Uninstall - Edge
        $edgePath = \"C:\\Program Files (x86)\\Microsoft\\Edge\\Application\"
        if (Test-Path $edgePath) {
            $edgeVersions = Get-ChildItem $edgePath -Directory
            foreach ($version in $edgeVersions) {
                $installerPath = Join-Path $version.FullName \"Installer\"
                if (Test-Path $installerPath) {
                    Set-Location -Path $installerPath | Out-Null
                    if (Test-Path \"setup.exe\") {
                        Write-Host \"Removing Microsoft Edge\"
                        Start-Process -Wait -FilePath \"setup.exe\" -ArgumentList \"--uninstall --system-level --force-uninstall\"
                    }
                }
            }
        }

        # Uninstall - EdgeWebView
        $edgeWebViewPath = \"C:\\Program Files (x86)\\Microsoft\\EdgeWebView\\Application\"
        if (Test-Path $edgeWebViewPath) {
            $edgeWebViewVersions = Get-ChildItem $edgeWebViewPath -Directory
            foreach ($version in $edgeWebViewVersions) {
                $installerPath = Join-Path $version.FullName \"Installer\"
                if (Test-Path $installerPath) {
                    Set-Location -Path $installerPath | Out-Null
                    if (Test-Path \"setup.exe\") {
                        Write-Host \"Removing EdgeWebView\"
                        Start-Process -Wait -FilePath \"setup.exe\" -ArgumentList \"--uninstall --msedgewebview --system-level --force-uninstall\"
                    }
                }
            }
        }

        # Delete Edge desktop icon, from all users
        $users = Get-ChildItem -Path \"C:\\Users\" -Directory
        foreach ($user in $users) {
            $desktopPath = Join-Path -Path $user.FullName -ChildPath \"Desktop\"
            Remove-Item -Path \"$desktopPath\\edge.lnk\" -Force -ErrorAction SilentlyContinue
            Remove-Item -Path \"$desktopPath\\Microsoft Edge.lnk\" -Force -ErrorAction SilentlyContinue
        }

        # Delete additional files
        if (Test-Path \"C:\\Windows\\System32\\MicrosoftEdgeCP.exe\") {
            $edgeFiles = Get-ChildItem -Path \"C:\\Windows\\System32\" -Filter \"MicrosoftEdge*\" -File
            foreach ($file in $edgeFiles) {
                $filePath = Join-Path -Path $file.Directory.FullName -ChildPath $file.Name
                takeown.exe /F \"$filePath\" > $null
                icacls.exe \"$filePath\" /inheritance:e /grant \"$env:UserName:(OI)(CI)F\" /T /C > $null
                Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue
            }
        }
        "
    ]
  },
  "WPFMiscTweaksDisableNotifications": {
    "registry": [
      {
        "Path": "HKCU:\\Software\\Policies\\Microsoft\\Windows\\Explorer",
        "Name": "DisableNotificationCenter",
        "Type": "DWord",
        "Value": "1",
        "OriginalValue": "0"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\PushNotifications",
        "Name": "ToastEnabled",
        "Type": "DWord",
        "Value": "0",
        "OriginalValue": "1"
      }
    ]
  },
  "WPFMiscTweaksRightClickMenu": {
    "InvokeScript": [
      "New-Item -Path \"HKCU:\\Software\\Classes\\CLSID\\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\" -Name \"InprocServer32\" -force -value \"\" "
    ]
  },
  "WPFEssTweaksDiskCleanup": {
    "InvokeScript": [
      "cleanmgr.exe /d C: /VERYLOWDISK"
    ]
  },
  "WPFMiscTweaksDisableTPMCheck": {
    "registry": [
      {
        "Path": "HKLM:\\SYSTEM\\Setup\\MoSetup",
        "Name": "AllowUpgradesWithUnsupportedTPM",
        "Type": "DWord",
        "Value": "1",
        "OriginalValue": "0"
      }
    ]
  },
  "WPFMiscTweaksDisableUAC": {
    "registry": [
      {
        "path": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System",
        "OriginalValue": "5",
        "name": "ConsentPromptBehaviorAdmin",
        "value": "0",
        "type": "DWord"
      }
    ]
  },
  "WPFMiscTweaksDisableMouseAcceleration": {
    "registry": [
      {
        "path": "HKCU:\\Control Panel\\Mouse",
        "OriginalValue": "1",
        "name": "MouseSpeed",
        "value": "0",
        "type": "String"
      },
      {
        "path": "HKCU:\\Control Panel\\Mouse",
        "OriginalValue": "6",
        "name": "MouseThreshold1",
        "value": "0",
        "type": "String"
      },
      {
        "path": "HKCU:\\Control Panel\\Mouse",
        "OriginalValue": "10",
        "name": "MouseThreshold2",
        "value": "0",
        "type": "String"
      }
    ]
  },
  "WPFMiscTweaksEnableMouseAcceleration": {
    "registry": [
      {
        "path": "HKCU:\\Control Panel\\Mouse",
        "OriginalValue": "1",
        "name": "MouseSpeed",
        "value": "1",
        "type": "String"
      },
      {
        "path": "HKCU:\\Control Panel\\Mouse",
        "OriginalValue": "6",
        "name": "MouseThreshold1",
        "value": "6",
        "type": "String"
      },
      {
        "path": "HKCU:\\Control Panel\\Mouse",
        "OriginalValue": "10",
        "name": "MouseThreshold2",
        "value": "10",
        "type": "String"
      }
    ]
  },
  "WPFEssTweaksDeleteTempFiles": {
    "InvokeScript": [
      "Get-ChildItem -Path \"C:\\Windows\\Temp\" *.* -Recurse | Remove-Item -Force -Recurse
    Get-ChildItem -Path $env:TEMP *.* -Recurse | Remove-Item -Force -Recurse"
    ]
  },
  "WPFEssTweaksRemoveCortana": {
    "InvokeScript": [
      "Get-AppxPackage -allusers Microsoft.549981C3F5F10 | Remove-AppxPackage"
    ]
  },
  "WPFEssTweaksDVR": {
    "registry": [
      {
        "Path": "HKCU:\\System\\GameConfigStore",
        "Name": "GameDVR_FSEBehavior",
        "Value": "2",
        "OriginalValue": "1",
        "Type": "DWord"
      },
      {
        "Path": "HKCU:\\System\\GameConfigStore",
        "Name": "GameDVR_Enabled",
        "Value": "0",
        "OriginalValue": "1",
        "Type": "DWord"
      },
      {
        "Path": "HKCU:\\System\\GameConfigStore",
        "Name": "GameDVR_DXGIHonorFSEWindowsCompatible",
        "Value": "1",
        "OriginalValue": "0",
        "Type": "DWord"
      },
      {
        "Path": "HKCU:\\System\\GameConfigStore",
        "Name": "GameDVR_HonorUserFSEBehaviorMode",
        "Value": "1",
        "OriginalValue": "0",
        "Type": "DWord"
      },
      {
        "Path": "HKCU:\\System\\GameConfigStore",
        "Name": "GameDVR_EFSEFeatureFlags",
        "Value": "0",
        "OriginalValue": "1",
        "Type": "DWord"
      }
    ]
  },
  "WPFDisableGameBar": {
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\GameDVR",
        "Name": "AllowGameDVR",
        "Value": "0",
        "OriginalValue": "1",
        "Type": "DWord"
      }
    ]
  },
  "WPFBingSearch": {
    "registry": [
      {
        "OriginalValue": "1",
        "Name": "BingSearchEnabled",
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Search",
        "Type": "DWORD",
        "Value": "0"
      }
    ]
  }
}' | convertfrom-json
#Configure max thread count for RunspacePool.
$maxthreads = [int]$env:NUMBER_OF_PROCESSORS

#Create a new session state for parsing variables ie hashtable into our runspace.
$hashVars = New-object System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'sync',$sync,$Null
$InitialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

#Add the variable to the RunspacePool sessionstate
$InitialSessionState.Variables.Add($hashVars)

#Add functions
$functions = Get-ChildItem function:\ | Where-Object {$_.name -like "*winutil*" -or $_.name -like "*WPF*"}
foreach ($function in $functions){
    $functionDefinition = Get-Content function:\$($function.name)
    $functionEntry = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $($function.name), $functionDefinition
    
    # And add it to the iss object
    $initialSessionState.Commands.Add($functionEntry)
}

#Create our runspace pool. We are entering three parameters here min thread count, max thread count and host machine of where these runspaces should be made.
$sync.runspace = [runspacefactory]::CreateRunspacePool(1,$maxthreads,$InitialSessionState, $Host)

#Open a RunspacePool instance.
$sync.runspace.Open()

#region exception classes

    class WingetFailedInstall : Exception {
        [string] $additionalData

        WingetFailedInstall($Message) : base($Message) {}
    }
    
    class ChocoFailedInstall : Exception {
        [string] $additionalData

        ChocoFailedInstall($Message) : base($Message) {}
    }

    class GenericException : Exception {
        [string] $additionalData

        GenericException($Message) : base($Message) {}
    }
    
#endregion exception classes

$inputXML = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML
#Read XAML

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
try { $sync["Form"] = [Windows.Markup.XamlReader]::Load( $reader ) }
catch [System.Management.Automation.MethodInvocationException] {
    Write-Warning "We ran into a problem with the XAML code.  Check the syntax for this control..."
    Write-Host $error[0].Exception.Message -ForegroundColor Red
    If ($error[0].Exception.Message -like "*button*") {
        write-warning "Ensure your &lt;button in the `$inputXML does NOT have a Click=ButtonClick property.  PS can't handle this`n`n`n`n"
    }
}
catch {
    # If it broke some other way <img draggable="false" role="img" class="emoji" alt="??" src="https://s0.wp.com/wp-content/mu-plugins/wpcom-smileys/twemoji/2/svg/1f600.svg">
    Write-Host "Unable to load Windows.Markup.XamlReader. Double-check syntax and ensure .net is installed."
}

#===========================================================================
# Store Form Objects In PowerShell
#===========================================================================

$xaml.SelectNodes("//*[@Name]") | ForEach-Object {$sync["$("$($psitem.Name)")"] = $sync["Form"].FindName($psitem.Name)}

$sync.keys | ForEach-Object {
    if($sync.$psitem){
        if($($sync["$psitem"].GetType() | Select-Object -ExpandProperty Name) -eq "Button"){
            $sync["$psitem"].Add_Click({
                [System.Object]$Sender = $args[0]
                Invoke-WPFButton $Sender.name
            })
        }
    }
}

$sync["WPFToggleDarkMode"].Add_Click({    
  Invoke-WPFDarkMode -DarkMoveEnabled $(Get-WinUtilDarkMode)
})

$sync["WPFToggleDarkMode"].IsChecked = Get-WinUtilDarkMode

#===========================================================================
# Setup background config
#===========================================================================

#Load information in the background
Invoke-WPFRunspace -ScriptBlock { 
    $sync.ConfigLoaded = $False

    $sync.ComputerInfo = Get-ComputerInfo

    $sync.ConfigLoaded = $True
} | Out-Null

#===========================================================================
# Shows the form
#===========================================================================

Invoke-WPFFormVariables

$sync["Form"].title = $sync["Form"].title + " " + $sync.version
$sync["Form"].Add_Closing({
    $sync.runspace.Dispose()
    $sync.runspace.Close()
    [System.GC]::Collect()
})

$sync["Form"].ShowDialog() | out-null
Stop-Transcript
