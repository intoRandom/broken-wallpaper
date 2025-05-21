# Variables globales reutilizables
$folderPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'brokenWallpaper'
$overlayFilename = 'brokenScreenBG.png'
$outputFilename = 'crackWallpaper.bmp'
$audioFilename = 'electricShock.wav'

$urlImage = 'https://raw.githubusercontent.com/intoRandom/broken-wallpaper/refs/heads/main/brokenScreenBG.png'
$urlAudio = 'https://github.com/intoRandom/broken-wallpaper/raw/refs/heads/main/electricShock.wav'

$overlayPath = Join-Path $folderPath $overlayFilename
$outputPath = Join-Path $folderPath $outputFilename
$audioPath = Join-Path $folderPath $audioFilename

$taskName = "brokenWallpaper"
$scriptUrl = "https://crash.intorandom.com"


# Función para verificar assets
function CheckAssets {
    if (-not (Test-Path $overlayPath) -or (Get-Item $overlayPath).Length -eq 0) {
        return $false
    }
    if (-not (Test-Path $audioPath) -or (Get-Item $audioPath).Length -eq 0) {
        return $false
    }
    return $true
}

# Función para descargar assets
function DownloadAssets {
    try {
        if (-not (Test-Path $folderPath)) {
            New-Item -ItemType Directory -Path $folderPath | Out-Null
        }

        Invoke-WebRequest -Uri $urlImage -OutFile $overlayPath -ErrorAction Stop
        Invoke-WebRequest -Uri $urlAudio -OutFile $audioPath -ErrorAction Stop

    }
    catch {
        Write-Error "Error durante la descarga: $_"
        exit
    }
}

# Función para generar wallpaper
function GenerateWallpaper {
    try {
        Add-Type -AssemblyName System.Drawing

        $currentWallpaper = Get-ItemPropertyValue 'HKCU:\Control Panel\Desktop' -Name WallPaper
        if (-not (Test-Path $currentWallpaper)) {
            Write-Error "No se pudo obtener el fondo de pantalla actual."
            exit
        }

        $background = [System.Drawing.Image]::FromFile($currentWallpaper)
        $overlay = [System.Drawing.Image]::FromFile($overlayPath)

        $bgWidth = $background.Width
        $bgHeight = $background.Height

        $scale = [Math]::Min($bgWidth / $overlay.Width, $bgHeight / $overlay.Height)
        $newWidth = [int]($overlay.Width * $scale)
        $newHeight = [int]($overlay.Height * $scale)

        $resizedOverlay = New-Object System.Drawing.Bitmap $newWidth, $newHeight
        $gOverlay = [System.Drawing.Graphics]::FromImage($resizedOverlay)
        $gOverlay.DrawImage($overlay, 0, 0, $newWidth, $newHeight)
        $gOverlay.Dispose()
        $overlay.Dispose()

        $result = New-Object System.Drawing.Bitmap $bgWidth, $bgHeight
        $graphics = [System.Drawing.Graphics]::FromImage($result)
        $graphics.DrawImage($background, 0, 0, $bgWidth, $bgHeight)

        $background.Dispose()

        $x = $bgWidth - $newWidth
        $y = 0
        $graphics.DrawImage($resizedOverlay, $x, $y)
        $resizedOverlay.Dispose()
        $graphics.Dispose()

        $result.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Bmp)
        $result.Dispose()

    }
    catch {
        Write-Error "Error al combinar imágenes: $_"
        exit
    }
}

# Función para cambiar wallpaper
function SetWallpaper {
    $code = @"
using System;
using System.Runtime.InteropServices;

public class Wallpaper {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

    Add-Type $code

    $SPI_SETDESKWALLPAPER = 0x0014
    $SPIF_UPDATEINIFILE = 0x01
    $SPIF_SENDCHANGE = 0x02

    [Wallpaper]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $outputPath, $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE) | Out-Null
}

# Función para reproducir sonido
function PlaySound {
    $player = New-Object System.Media.SoundPlayer $audioPath
    $player.Play()
}


# Función para registrar el script en tareas
function RegisterOnceScheduledTask {
    try {
        # Definir la acción (ejecutar Notepad)
        $accion = New-ScheduledTaskAction -Execute "notepad.exe" -WorkingDirectory "$env:USERPROFILE"
        $accion = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"try { `$url='$scriptUrl'; iwr `$url -UseBasicParsing | iex } catch { Write-Error $_ }`"" -WorkingDirectory "$env:USERPROFILE"

        $desencadenador = New-ScheduledTaskTrigger -AtLogOn 
        $desencadenador.UserId = "$env:USERDOMAIN\$env:USERNAME"  
        $desencadenador.Delay = "PT15S"  

        $configuracion = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

        # Registrar la tarea (se ejecutará una sola vez)
        Register-ScheduledTask -TaskName $taskName -Action $accion -Trigger $desencadenador -Settings $configuracion -RunLevel Limited
    }
    catch {
        Write-Error "Error al registrar la tarea: $_"
    }
}



# Ejecución secuencial
if (-not (CheckAssets)) {
    DownloadAssets
    GenerateWallpaper
    RegisterOnceScheduledTask
}
else {
    Start-Sleep -Seconds 6
    PlaySound
    Start-Sleep -Seconds 3
    SetWallpaper
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Remove-Item -Path $folderPath -Recurse -Force
}

exit 