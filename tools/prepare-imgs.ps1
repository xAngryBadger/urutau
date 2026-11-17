# Prepara as imagens do PDF de telas (docs/_pdf-img):
# - converte os prints do emulador (PNG) pra JPEG q92
# - copia os prints do painel (JPG)
# Uso: pwsh tools/prepare-imgs.ps1   (depois: node tools/make-telas-pdf.mjs)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$srcEmu = Join-Path $root 'docs\evidencias-emulador'
$srcAdm = Join-Path $root 'docs\evidencias-admin'
$tmp = Join-Path $root 'docs\_pdf-img'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

Add-Type -AssemblyName System.Drawing
$enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
  Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
  [System.Drawing.Imaging.Encoder]::Quality, 92L)

$n = 0
Get-ChildItem "$srcEmu\wz*.png" | ForEach-Object {
  $bmp = New-Object System.Drawing.Bitmap($_.FullName)
  $bmp.Save("$tmp\$($_.BaseName).jpg", $enc, $ep)
  $bmp.Dispose()
  $n++
}
Copy-Item "$srcAdm\*.jpg" $tmp
Write-Host "preparadas $n imagens do app + painel em $tmp"
