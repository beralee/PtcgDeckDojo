$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$outputPath = Join-Path $projectRoot "scripts\data\card_tag_overrides.json"
$imageRoot = Join-Path $env:APPDATA "Godot\app_userdata\PTCG Train\cards\images"
$scanSets = @("CSV6C", "CSV7C")

$futureTemplatePath = Join-Path $imageRoot "CSV7C\153.png"
$ancientTemplatePath = Join-Path $imageRoot "CSV7C\109.png"

$futureThreshold = 6500.0
$ancientThreshold = 6000.0
$cropRect = New-Object System.Drawing.Rectangle(185, 8, 108, 62)
$sampleSize = New-Object System.Drawing.Size(54, 31)

function Get-TemplateBitmap([string]$path) {
	if (-not (Test-Path $path)) {
		throw "Template image not found: $path"
	}

	$bmp = [System.Drawing.Bitmap]::new($path)
	try {
		$crop = $bmp.Clone($cropRect, $bmp.PixelFormat)
		try {
			$resized = New-Object System.Drawing.Bitmap $sampleSize.Width, $sampleSize.Height
			$graphics = [System.Drawing.Graphics]::FromImage($resized)
			try {
				$graphics.DrawImage($crop, 0, 0, $sampleSize.Width, $sampleSize.Height)
			}
			finally {
				$graphics.Dispose()
			}
			return $resized
		}
		finally {
			$crop.Dispose()
		}
	}
	finally {
		$bmp.Dispose()
	}
}

function Get-Mse([System.Drawing.Bitmap]$a, [System.Drawing.Bitmap]$b) {
	$sum = 0.0
	for ($x = 0; $x -lt $a.Width; $x++) {
		for ($y = 0; $y -lt $a.Height; $y++) {
			$ca = $a.GetPixel($x, $y)
			$cb = $b.GetPixel($x, $y)
			$dr = $ca.R - $cb.R
			$dg = $ca.G - $cb.G
			$db = $ca.B - $cb.B
			$sum += ($dr * $dr + $dg * $dg + $db * $db)
		}
	}
	return $sum / ($a.Width * $a.Height * 3)
}

function Get-LabelForImage([string]$path, [System.Drawing.Bitmap]$futureTemplate, [System.Drawing.Bitmap]$ancientTemplate) {
	$sample = Get-TemplateBitmap $path
	try {
		$futureScore = Get-Mse $sample $futureTemplate
		$ancientScore = Get-Mse $sample $ancientTemplate

		if ($futureScore -le $futureThreshold) {
			return "Future"
		}
		if ($ancientScore -le $ancientThreshold) {
			return "Ancient"
		}
		return $null
	}
	finally {
		$sample.Dispose()
	}
}

$futureTemplate = Get-TemplateBitmap $futureTemplatePath
$ancientTemplate = Get-TemplateBitmap $ancientTemplatePath

try {
	$result = [ordered]@{}

	foreach ($setCode in $scanSets) {
		$setDir = Join-Path $imageRoot $setCode
		if (-not (Test-Path $setDir)) {
			continue
		}

		Get-ChildItem $setDir -Filter *.png | Sort-Object Name | ForEach-Object {
			$imagePath = $_.FullName
			try {
				$label = Get-LabelForImage $imagePath $futureTemplate $ancientTemplate
				if ($null -ne $label) {
					$uid = "{0}_{1}" -f $setCode, $_.BaseName
					$result[$uid] = @($label)
				}
			}
			catch {
				Write-Warning "Skip unreadable image: $imagePath"
			}
		}
	}

	$json = $result | ConvertTo-Json -Depth 3
	Set-Content -Path $outputPath -Value $json -Encoding UTF8
	Write-Output "Wrote tag overrides to $outputPath"
}
finally {
	$futureTemplate.Dispose()
	$ancientTemplate.Dispose()
}
