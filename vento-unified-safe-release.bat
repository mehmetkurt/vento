@echo off
setlocal
chcp 65001 >nul
title Vento Unified Safe Release
set "VENTO_UNIFIED_BAT_PATH=%~f0"
set "VENTO_UNIFIED_BAT_DIR=%~dp0"
set "VENTO_UNIFIED_CLI_ARGS=%*"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $lines = [System.IO.File]::ReadAllLines($env:VENTO_UNIFIED_BAT_PATH, [System.Text.Encoding]::UTF8); $idx = [Array]::IndexOf($lines, '# === POWERSHELL_PAYLOAD_START ==='); if ($idx -lt 0) { Write-Error 'Payload marker not found!'; exit 1 };$code = ($lines[($idx + 1)..($lines.Length - 1)] -join [Environment]::NewLine); & ([ScriptBlock]::Create($code))"
set "EXIT_CODE=%ERRORLEVEL%"

echo.
if not "%EXIT_CODE%"=="0" (
    echo ============================================================================
    echo   [KRITIK HATA] Unified Safe Release islemi durduruldu! ^(Kod: %EXIT_CODE%^)
    echo   Sahadaki verileri ve lisans uyumunu korumak icin islem iptal edildi.
    echo ============================================================================
) else (
    echo ============================================================================
    echo   [BASARILI] Istenen islem ve guvenlik denetimleri tamamlandi!
    echo ============================================================================
)
echo.
if "%~1"=="" pause
exit /b %EXIT_CODE%

# === POWERSHELL_PAYLOAD_START ===
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---------------------------------------------------------------------------
# Yardimci Fonksiyonlar & Cikti Formatlama
# ---------------------------------------------------------------------------
function Write-Section([string]$Title) {
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor DarkCyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "============================================================================" -ForegroundColor DarkCyan
}

function Write-SubHeader([string]$Title) {
    Write-Host "`n  ---> $Title" -ForegroundColor Magenta
}

function Write-Pass([string]$Message) { Write-Host "  [OK] $Message" -ForegroundColor Green }
function Write-WarnMsg([string]$Message) { Write-Host "  [UYARI] $Message" -ForegroundColor Yellow }
function Write-FailAndExit([string]$Message) { Write-Host "`n  [HATA] $Message" -ForegroundColor Red; exit 1 }

function Write-Utf8NoBom([string]$FilePath, [string]$Content) {
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($FilePath, $Content,$Utf8NoBom)
}

function Read-TimedKey([string]$PromptPrefix, [int]$Seconds = 6) {
    $SelectedKey =$null
    if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
        for ($sec =$Seconds; $sec -gt 0; $sec--) {
            Write-Host "`r  $PromptPrefix ($sec sn)... " -NoNewline -ForegroundColor Cyan
            for ($tick = 0; $tick -lt 10; $tick++) {
                if ([Console]::KeyAvailable) {
                    $KeyInfo = [Console]::ReadKey($true)
                    $SelectedKey = if ($KeyInfo.Key -eq [ConsoleKey]::Enter) { "ENTER" } else { $KeyInfo.KeyChar.ToString().ToUpperInvariant() }
                    break
                }
                Start-Sleep -Milliseconds 100
            }
            if ($null -ne $SelectedKey) { break }
        }
        Write-Host ""
    }
    return $SelectedKey
}

# ---------------------------------------------------------------------------
# CLI Argumanlarini Ayristir
# ---------------------------------------------------------------------------
$CliTokens = @()
if (-not [string]::IsNullOrWhiteSpace($env:VENTO_UNIFIED_CLI_ARGS)) {
    $CliTokens = $env:VENTO_UNIFIED_CLI_ARGS.Trim() -split '\s+'
}

$VerifyOnly   = $CliTokens -contains '--verify-only'
$SelfTest     = $CliTokens -contains '--self-test'
$NoGit        = -not (($CliTokens -contains '--commit') -or ($CliTokens -contains '--push') -or ($CliTokens -contains '--no-push'))
if ($CliTokens -contains '--no-git') { $NoGit = $true }
$PreviousBuilds = @{}
$NoPush       = -not ($CliTokens -contains "--push")
$SkipCodegen  = $CliTokens -contains "--skip-codegen"
$NoOpenDist   = $CliTokens -contains "--no-open"
if ($SkipCodegen) { throw 'Guvenli release icin --skip-codegen desteklenmiyor.' }
if ($CliTokens -contains '--help') {
    Write-Host 'vento-unified-safe-release.bat --pos|--keygen|--both [--pos-version X.Y.Z+N] [--keygen-version X.Y.Z+N]'
    Write-Host '--verify-only: mevcut APKlari denetler; surum/derleme/Git islemi yapmaz.'
    Write-Host '--self-test: dahili sertifika, paket ve yayin testlerini calistirir.'
    Write-Host '--no-open, --commit, --push, --no-push (yerel commit), --no-git (varsayilan)'
    exit 0
}
$AllowedSwitches = @('--pos','--ventopos','--keygen','--both','--all','--pos-version','--keygen-version','--version','--verify-only','--self-test','--no-open','--no-push','--no-git','--commit','--push')
for ($argumentIndex = 0; $argumentIndex -lt $CliTokens.Count; $argumentIndex++) {
    $argument = $CliTokens[$argumentIndex]
    if ($AllowedSwitches -notcontains $argument) { throw "Bilinmeyen parametre: $argument" }
    if ($argument -in @('--pos-version','--keygen-version','--version')) {
        $argumentIndex++
        if ($argumentIndex -ge $CliTokens.Count -or $CliTokens[$argumentIndex] -notmatch '^\d+\.\d+\.\d+\+[1-9]\d*$') { throw 'Surum X.Y.Z+N biciminde olmali.' }
    }
}

$TargetMode   = $null # "POS", "KEYGEN", "BOTH"
if (($CliTokens -contains "--both") -or ($CliTokens -contains "--all")) {
    $TargetMode = "BOTH"
} elseif (($CliTokens -contains "--pos") -and ($CliTokens -contains "--keygen")) {
    $TargetMode = "BOTH"
} elseif (($CliTokens -contains "--pos") -or ($CliTokens -contains "--ventopos")) {
    $TargetMode = "POS"
} elseif ($CliTokens -contains "--keygen") {
    $TargetMode = "KEYGEN"
}

$ForcedPosVersion    = $null
$ForcedKeygenVersion = $null
for ($i = 0; $i -lt $CliTokens.Count; $i++) {
    if ($CliTokens[$i] -eq "--pos-version" -and ($i + 1) -lt $CliTokens.Count) {
        $ForcedPosVersion = $CliTokens[$i + 1].Trim('"')
    }
    if ($CliTokens[$i] -eq "--keygen-version" -and ($i + 1) -lt $CliTokens.Count) {
        $ForcedKeygenVersion = $CliTokens[$i + 1].Trim('"')
    }
    if ($CliTokens[$i] -eq "--version" -and ($i + 1) -lt $CliTokens.Count) {
        # Tek hedef secildiginde genel --version bayragi destegi
        $v = $CliTokens[$i + 1].Trim('"')
        if ($TargetMode -eq "POS") { $ForcedPosVersion = $v }
        elseif ($TargetMode -eq "KEYGEN") { $ForcedKeygenVersion = $v }
    }
}

# ---------------------------------------------------------------------------
# Depo Tanima ve Otomatik Dizin Kesfi (ventoPOS & ventoPOS_Keygen)
# ---------------------------------------------------------------------------
function Test-IsPosRepo([string]$DirPath) {
    if ([string]::IsNullOrWhiteSpace($DirPath)) { return $false }
    $pub = Join-Path $DirPath "pubspec.yaml"
    $lic = Join-Path $DirPath "lib\core\license\license_constants.dart"
    if ((-not (Test-Path $pub)) -or (-not (Test-Path $lic))) { return $false }
    $pubTxt = [System.IO.File]::ReadAllText($pub, [System.Text.Encoding]::UTF8)
    return ($pubTxt -match '(?m)^name:\s*ventopos\b')
}

function Test-IsKeygenRepo([string]$DirPath) {
    if ([string]::IsNullOrWhiteSpace($DirPath)) { return $false }
    $pub = Join-Path $DirPath "pubspec.yaml"
    $kconst = Join-Path $DirPath "lib\core\constants\keygen_constants.dart"
    if ((-not (Test-Path $pub)) -or (-not (Test-Path $kconst))) { return $false }
    $pubTxt = [System.IO.File]::ReadAllText($pub, [System.Text.Encoding]::UTF8)
    return ($pubTxt -match '(?m)^name:\s*ventopos_keygen\b')
}

$BatDir = $env:VENTO_UNIFIED_BAT_DIR.TrimEnd('\', '/')
$SearchRoots = @($BatDir)
$ParentOfBat = Split-Path -Parent $BatDir
if (-not [string]::IsNullOrWhiteSpace($ParentOfBat)) { $SearchRoots += $ParentOfBat }
$GrandParent = Split-Path -Parent $ParentOfBat
if (-not [string]::IsNullOrWhiteSpace($GrandParent)) { $SearchRoots += $GrandParent }

$PosRoot = $null
$KeygenRoot = $null

foreach ($root in $SearchRoots) {
    if ((-not $PosRoot) -and (Test-IsPosRepo $root)) { $PosRoot = $root }
    if ((-not $KeygenRoot) -and (Test-IsKeygenRepo $root)) { $KeygenRoot = $root }

    $SubDirs = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue
    foreach ($sd in $SubDirs) {
        if ((-not $PosRoot) -and (Test-IsPosRepo $sd.FullName)) { $PosRoot = $sd.FullName }
        if ((-not $KeygenRoot) -and (Test-IsKeygenRepo $sd.FullName)) { $KeygenRoot = $sd.FullName }
    }
}

# Flutter & Dart ikililerini bul
$FlutterCandidates = @(
    "C:\Users\codeislife\.google\flutter\bin\flutter.bat",
    (Join-Path $env:USERPROFILE ".google\flutter\bin\flutter.bat")
)
$FlutterBin = $null
foreach ($cand in $FlutterCandidates) {
    if (Test-Path $cand) { $FlutterBin = $cand; break }
}
if (-not $FlutterBin) {
    $FlutterCmd = Get-Command "flutter" -ErrorAction SilentlyContinue
    if ($FlutterCmd) { $FlutterBin = $FlutterCmd.Source }
    else { Write-FailAndExit "Flutter bulunamadi! C:\Users\codeislife\.google\flutter\bin\flutter.bat veya PATH kontrol edin." }
}

$DartCandidates = @(
    "C:\Users\codeislife\.google\flutter\bin\dart.bat",
    (Join-Path $env:USERPROFILE ".google\flutter\bin\dart.bat")
)
$DartBin = $null
foreach ($cand in $DartCandidates) {
    if (Test-Path $cand) { $DartBin = $cand; break }
}
if (-not $DartBin) {
    $DartCmd = Get-Command "dart" -ErrorAction SilentlyContinue
    if ($DartCmd) { $DartBin = $DartCmd.Source } else { $DartBin = "dart" }
}

# ---------------------------------------------------------------------------
# Baslangic Ozeti ve Hedef Secim Menusu
# ---------------------------------------------------------------------------
Write-Section "VENTOPOS & KEYGEN UNIFIED SAFE RELEASE PIPELINE"
Write-Host ("  ventoPOS Dizini        : " + $(if ($PosRoot) { $PosRoot } else { "[BULUNAMADI]" })) -ForegroundColor $(if ($PosRoot) { "Gray" } else { "Red" })
Write-Host ("  ventoPOS_Keygen Dizini : " + $(if ($KeygenRoot) { $KeygenRoot } else { "[BULUNAMADI]" })) -ForegroundColor $(if ($KeygenRoot) { "Gray" } else { "Red" })
Write-Host "  Flutter Yolu           : $FlutterBin" -ForegroundColor Gray

if (-not $PosRoot -and -not $KeygenRoot) {
    Write-FailAndExit "Ne ventoPOS ne de ventoPOS_Keygen klasoru bulunabildi! .bat dosyasini projelerin ust klasorune koyun."
}

if (-not $TargetMode -and ($VerifyOnly -or $SelfTest)) { $TargetMode = "BOTH" }
if (-not $TargetMode) {
    Write-Host ""
    Write-Host "  Hangi uygulamayi derlemek ve yayinlamak istiyorsunuz?" -ForegroundColor Yellow
    Write-Host "    [1] Sadece VentoPOS        (Musteri Saha Uygulamasi)" -ForegroundColor White
    Write-Host "    [2] Sadece VentoPOS_Keygen (Yonetici Lisans Uretici)" -ForegroundColor White
    Write-Host "    [3] Her Ikisini Birden     (VentoPOS + VentoPOS_Keygen) [Varsayilan - Enter]" -ForegroundColor Green
    Write-Host "    [Q] Iptal / Cikis" -ForegroundColor DarkGray

    $MenuChoice = Read-TimedKey -PromptPrefix "Seciminiz [1/2/3, Enter=3]" -Seconds 8
    switch ($MenuChoice) {
        "1" { $TargetMode = "POS" }
        "2" { $TargetMode = "KEYGEN" }
        "Q" { Write-Host "  Islem kullanici tarafindan iptal edildi." -ForegroundColor Yellow; exit 0 }
        default {
            if ($PosRoot -and $KeygenRoot) { $TargetMode = "BOTH" }
            elseif ($PosRoot) { $TargetMode = "POS" }
            else { $TargetMode = "KEYGEN" }
        }
    }
}

$BuildPos    = ($TargetMode -eq "POS" -or $TargetMode -eq "BOTH")
$BuildKeygen = ($TargetMode -eq "KEYGEN" -or $TargetMode -eq "BOTH")

if ($BuildPos -and (-not $PosRoot)) {
    Write-FailAndExit "VentoPOS secildi ancak ventoPOS proje klasoru bulunamadi!"
}
if ($BuildKeygen -and (-not $KeygenRoot)) {
    Write-FailAndExit "VentoPOS_Keygen secildi ancak ventoPOS_Keygen proje klasoru bulunamadi!"
}

# ---------------------------------------------------------------------------
# Ortak Yardimci: Surum Secici & APK Imza Dogrulayici
# ---------------------------------------------------------------------------
function Select-NextVersionSpec {
    param(
        [string]$AppName,
        [string]$RepoDir,
        [string]$PubspecRaw,
        [string]$ForcedSpec,
        [int]$PreviousBuild = 0
    )
    if ($PubspecRaw -notmatch '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)') {
        Write-FailAndExit "$AppName pubspec.yaml icinde 'version: X.Y.Z+N' formati okunamadi!"
    }
    $CurMajor = [int]$Matches[1]; $CurMinor = [int]$Matches[2]; $CurPatch = [int]$Matches[3]; $CurBuild = [int]$Matches[4]
    $CurFullSpec = "$CurMajor.$CurMinor.$CurPatch+$CurBuild"

    if (-not [string]::IsNullOrWhiteSpace($ForcedSpec)) {
        if ($ForcedSpec -notmatch '^\d+\.\d+\.\d+\+(\d+)$') {
            Write-FailAndExit "$AppName icin gecersiz surum formati: $ForcedSpec (Ornek: 1.1.0+15)"
        }
        if ([int]$Matches[1] -lt $CurBuild) {
            Write-FailAndExit "$AppName yeni build numarasi ($($Matches[1])) mevcuttan ($CurBuild) kucuk olamaz!"
        }
        return $ForcedSpec
    }

    # Reuse a prepared version only while it is newer than the published APK.
    $HeadBuild = -1
    $HeadFullSpec = $null
    if (Get-Command "git" -ErrorAction SilentlyContinue) {
        Push-Location $RepoDir
        $PrevEap = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            $HeadPub = (& git show HEAD:pubspec.yaml 2>$null | Out-String)
            if ($LASTEXITCODE -eq 0 -and $HeadPub -match '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)') {
                $HeadFullSpec = "$($Matches[1]).$($Matches[2]).$($Matches[3])+$($Matches[4])"
                $HeadBuild = [int]$Matches[4]
            }
        } finally {
            $ErrorActionPreference = $PrevEap
            Pop-Location
        }
    }

    if ($HeadBuild -ge 0 -and $CurBuild -gt $HeadBuild -and $CurBuild -gt $PreviousBuild) {
        Write-Host "  [$AppName] Calisma agacinda surum zaten artirilmis ($HeadFullSpec -> $CurFullSpec)." -ForegroundColor Cyan
        return $CurFullSpec
    }

    $NextBuild = [Math]::Max($CurBuild, $PreviousBuild) + 1
    $SuggestedPatch = "$CurMajor.$CurMinor.$($CurPatch + 1)+$NextBuild"
    $SuggestedMinor = "$CurMajor.$($CurMinor + 1).0+$NextBuild"
    $SuggestedMajor = "$($CurMajor + 1).0.0+$NextBuild"

    Write-Host ""
    Write-Host "  [$AppName] Mevcut Surum : $CurFullSpec  -->  Varsayilan Yeni Surum : $SuggestedPatch" -ForegroundColor Yellow
    Write-Host "  [Enter] Patch ($SuggestedPatch) | [M] Minor ($SuggestedMinor) | [J] Major ($SuggestedMajor) | [K] Koru ($CurFullSpec) | [O] Ozel Gir" -ForegroundColor Gray

    $Sel = Read-TimedKey -PromptPrefix "[$AppName] Surum secimi icin tuslayin" -Seconds 6
    switch ($Sel) {
        "M" { return $SuggestedMinor }
        "J" { return $SuggestedMajor }
        "K" { return $CurFullSpec }
        "O" {
            $CustomInput = (Read-Host "  [$AppName] Yeni surumu girin (X.Y.Z+N)").Trim()
            if ($CustomInput -notmatch '^\d+\.\d+\.\d+\+(\d+)$') {
                Write-FailAndExit "$AppName gecersiz surum formati: $CustomInput"
            }
            if ([int]$Matches[1] -lt $CurBuild) {
                Write-FailAndExit "$AppName yeni build numarasi mevcuttan ($CurBuild) kucuk olamaz!"
            }
            return $CustomInput
        }
        default { return $SuggestedPatch }
    }
}

function Verify-BuiltReleaseApk {
    param(
        [string]$ApkPath,
        [string]$ExpectedPackageId,
        [int]$ExpectedVersionCode,
        [string]$ExpectedVersionName = ""
    )
    $repo = if ($ExpectedPackageId -eq 'com.ventopos.ventopos') { $PosRoot } else { $KeygenRoot }
    $CertificatePinPath = Join-Path $repo 'android\release_certificate.sha256'
    if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) { throw 'Release APK bulunamadi.' }
    if (-not (Test-Path -LiteralPath $CertificatePinPath -PathType Leaf)) { throw 'Uretim sertifika ozeti eksik.' }
    $expectedDigest = ([IO.File]::ReadAllText($CertificatePinPath)).Trim().ToLowerInvariant()
    $tools = Get-AndroidBuildTools
    $signer = $tools.Signer; $aapt = $tools.Aapt
$certificateOutput = (& $signer verify --print-certs $ApkPath | Out-String)
if ($LASTEXITCODE -ne 0 -or $certificateOutput -match 'CN=Android Debug') { throw 'Release APK imzasi gecersiz.' }
Assert-ReleaseCertificate $certificateOutput $expectedDigest
$metadata = (& $aapt dump badging $ApkPath | Out-String)
if ($LASTEXITCODE -ne 0 -or $metadata -notmatch ("name='" + [regex]::Escape($ExpectedPackageId) + "'")) { throw 'APK paket kimligi dogrulanamadi.' }
if ($metadata -notmatch "(?m)^sdkVersion:'24'" -or $metadata -notmatch "(?m)^targetSdkVersion:'36'") { throw 'APK SDK hedefleri beklenen surumlerle eslesmiyor.' }
if ($ExpectedVersionCode -gt 0 -and $metadata -notmatch ("versionCode='" + $ExpectedVersionCode + "'")) { throw 'APK build numarasi kaynakla eslesmiyor.' }
if ($ExpectedVersionName -and $metadata -notmatch ("versionName='" + [regex]::Escape($ExpectedVersionName) + "'")) { throw 'APK surum adi kaynakla eslesmiyor.' }
return $expectedDigest
}

function Get-AndroidBuildTools([string]$Root = '') {
    $candidateRoots = @()
    if ($Root) {
        $candidateRoots += $Root
    } else {
        if ($env:ANDROID_SDK_ROOT) { $candidateRoots += (Join-Path $env:ANDROID_SDK_ROOT 'build-tools') }
        if ($env:ANDROID_HOME) { $candidateRoots += (Join-Path $env:ANDROID_HOME 'build-tools') }
        foreach ($repoCand in @($PosRoot, $KeygenRoot)) {
            if ($repoCand) {
                $lp = Join-Path $repoCand 'android\local.properties'
                if (Test-Path -LiteralPath $lp -PathType Leaf) {
                    foreach ($ln in [IO.File]::ReadAllLines($lp)) {
                        if ($ln -match '^\s*sdk\.dir\s*=\s*(.+)$') {
                            $parsedSdk = ($Matches[1].Trim() -replace '\\\\', '\' -replace '\\:', ':')
                            if ($parsedSdk) { $candidateRoots += (Join-Path $parsedSdk 'build-tools') }
                        }
                    }
                }
            }
        }
        if ($env:USERPROFILE) { $candidateRoots += (Join-Path $env:USERPROFILE 'android-sdk\build-tools') }
        if ($env:LOCALAPPDATA) { $candidateRoots += (Join-Path $env:LOCALAPPDATA 'Android\sdk\build-tools') }
    }
    $existingRoots = @($candidateRoots | Select-Object -Unique | Where-Object { Test-Path -LiteralPath $_ -PathType Container -ErrorAction SilentlyContinue })
    if ($existingRoots.Count -eq 0) { throw 'Android SDK build-tools bulunamadi.' }
    $available = @()
    foreach ($btRoot in $existingRoots) {
        $available += @(Get-ChildItem -LiteralPath $btRoot -Directory -ErrorAction SilentlyContinue | Where-Object {
            $ok = $false
            try {
                $ok = (Test-Path -LiteralPath (Join-Path $_.FullName 'apksigner.bat') -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath (Join-Path $_.FullName 'aapt.exe') -ErrorAction SilentlyContinue)
            } catch { $ok = $false }
            $ok
        })
    }
    $available = @($available | Sort-Object { [version]($_.Name -replace '-.*$', '') } -Descending)
    if ($available.Count -eq 0) { throw 'aapt ve apksigner zorunludur; APK denetimi atlanamaz.' }
    return [pscustomobject]@{ Signer = (Join-Path $available[0].FullName 'apksigner.bat'); Aapt = (Join-Path $available[0].FullName 'aapt.exe') }
}
function Assert-ReleaseCertificate([string]$Text, [string]$Expected) {
    if ($Expected -notmatch '^[a-f0-9]{64}$' -or $Text -match 'CN\s*=\s*Android Debug') { throw 'Gecersiz uretim sertifikasi.' }
    $digests = @([regex]::Matches($Text, 'certificate SHA-256 digest:\s*([a-fA-F0-9]{64})') | ForEach-Object { $_.Groups[1].Value.ToLowerInvariant() } | Select-Object -Unique)
    if ($digests.Count -ne 1 -or $digests[0] -cne $Expected) { throw 'Uretim sertifikasi onceki surumle eslesmiyor.' }
}
function Assert-UpgradeBuild([string]$Spec, [int]$Previous) {
    if ($Spec -notmatch '^\d+\.\d+\.\d+\+([1-9]\d*)$' -or [int]$Matches[1] -le $Previous) { throw 'Yeni build numarasi onceki dagitilan APKdan buyuk olmali.' }
}
function Invoke-ReleasePreflight([string]$Name, [string]$Repo, [string]$Package) {
    Write-SubHeader "${Name}: derleme oncesi guvenlik denetimi"
    $gradle = [IO.File]::ReadAllText((Join-Path $Repo 'android\app\build.gradle.kts'))
    if ($gradle -notmatch ('applicationId\s*=\s*"' + [regex]::Escape($Package) + '"') -or $gradle -notmatch 'minSdk\s*=\s*24\b' -or $gradle -notmatch 'targetSdk\s*=\s*36\b' -or $gradle -notmatch 'JavaVersion.VERSION_17') { throw 'Android paket/SDK/Java uyumlulugu bozulmus.' }
    $properties = @{}
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $Repo 'android\key.properties'))) {
        if ($line -match '^\s*([^#!\s=]+)\s*=\s*(.*?)\s*$') { $properties[$Matches[1]] = $Matches[2] }
    }
    foreach ($key in @('storeFile','storePassword','keyAlias','keyPassword')) {
        if (-not $properties.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($properties[$key])) { throw 'Uretim imza yapilandirmasi eksik.' }
    }
    $keystore = $properties['storeFile']
    if (-not [IO.Path]::IsPathRooted($keystore)) { $keystore = Join-Path (Join-Path $Repo 'android\app') $keystore }
    if (-not (Test-Path -LiteralPath $keystore -PathType Leaf)) { throw 'Gradle keystore dosyasi bulunamadi.' }
    $tracked = @(& git -C $Repo ls-files)
    if ($LASTEXITCODE -ne 0) { throw 'Git depo denetimi basarisiz.' }
    if (@($tracked | Where-Object { $_ -match '(^|/)key\.properties$|\.jks$|\.keystore$|^secrets/|^dist/|^debug_symbols/|^build/|\.apk$|\.aab$' }).Count -gt 0) { throw 'Git tarafindan izlenen gizli dosya veya derleme ciktisi var.' }
    $constantFile = if ($Name -eq 'VentoPOS') { 'lib\core\license\license_constants.dart' } else { 'lib\core\constants\keygen_constants.dart' }
    $constants = [IO.File]::ReadAllText((Join-Path $Repo $constantFile))
    $publicKey = [regex]::Match($constants, '(?:publicKeyBase64Url|expectedPublicKeyBase64Url)\s*=\s*''([^'']+)''')
    if (-not $publicKey.Success -or $publicKey.Groups[1].Value -cne 'jf10UMxb1rMu00bH-VIL5oLHo3r0u5p5VVtzuW9j-d0') { throw 'Sahadaki lisanslarin acik anahtari degismis.' }
    if ($constants -notmatch "signatureDomainTag\s*=\s*'VP-LICENSE-V1:'" -or $constants -notmatch 'protocolVersion\s*=\s*1\b') { throw 'Lisans protokolu degismis.' }
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $Repo 'lib') -Recurse -Filter '*.dart') {
        $text = [IO.File]::ReadAllText($file.FullName)
        $relative = $file.FullName.Substring($Repo.Length + 1).Replace('\','/')
        if ($text -match 'VP_KEYGEN_PRIVATE_SEED|compileTimePrivateSeed' -or ($relative -match '^lib/(data|domain)/' -and $text -match '\.runtimeType\.toString\(\)')) { throw 'Obfuscation/gizli anahtar guvenlik denetimi basarisiz.' }
    }
    $canonical = Join-Path $Repo "dist\$Name-release.apk"
    $tools = Get-AndroidBuildTools
    if (Test-Path -LiteralPath $canonical) {
        $null = Verify-BuiltReleaseApk -ApkPath $canonical -ExpectedPackageId $Package -ExpectedVersionCode 0
        $metadata = (& $tools.Aapt dump badging $canonical | Select-String '^package:' | Out-String)
        if ($LASTEXITCODE -ne 0 -or $metadata -notmatch "versionCode='(\d+)'") { throw 'Onceki APK build numarasi okunamadi.' }
        $PreviousBuilds[$Name] = [int]$Matches[1]
    } else {
        if ($VerifyOnly) { throw 'Dogrulanacak onceki APK bulunamadi.' }
        $pubspec = [IO.File]::ReadAllText((Join-Path $Repo 'pubspec.yaml'))
        if ($pubspec -notmatch '(?m)^version:\s*\d+\.\d+\.\d+\+(\d+)') { throw 'Mevcut build numarasi okunamadi.' }
        $PreviousBuilds[$Name] = [int]$Matches[1]
    }
}
function Publish-VerifiedFile([string]$Source, [string]$Destination, [switch]$Immutable) {
    if ($Immutable -and [IO.File]::Exists($Destination)) {
        if ((Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash) { throw 'Ayni surum arsivi farkli icerikle degistirilemez.' }
        return
    }
    $directory = Split-Path -Parent $Destination
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $temporary = Join-Path $directory ('.publish-' + [guid]::NewGuid().ToString('N'))
    try {
        [IO.File]::Copy($Source, $temporary)
        if ([IO.File]::Exists($Destination)) { [IO.File]::Replace($temporary, $Destination, [NullString]::Value) }
        else { [IO.File]::Move($temporary, $Destination) }
    } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}
function New-UpdatePackage([array]$Items, [string]$OutputRoot) {
    $prefix = if ($Items.Count -gt 1) { 'Vento-admin-release-' } elseif ($Items[0].App -eq 'VentoPOS_Keygen') { 'VentoPOS_Keygen-admin-update-' } else { $Items[0].App + '-update-' }
    $id = $prefix + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8)
    $staging = Join-Path $OutputRoot ('.staging-' + $id)
    [IO.Directory]::CreateDirectory($staging) | Out-Null
    $records = @()
    foreach ($item in $Items) {
        $name = Split-Path -Leaf $item.VersionedApk; $copy = Join-Path $staging $name
        [IO.File]::Copy($item.CandidateApk, $copy)
        $hash = (Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash.ToLowerInvariant()
        [IO.File]::WriteAllText("$copy.sha256", "$hash  $name`n", (New-Object Text.UTF8Encoding($false)))
        $sourceCommit = 'fixture'; $dirty = $false
        if ($item.PSObject.Properties['RepoRoot']) {
            $sourceCommit = (& git -C $item.RepoRoot rev-parse HEAD | Out-String).Trim()
            if ($LASTEXITCODE -ne 0) { throw 'Git kaynak surumu okunamadi.' }
            $dirty = -not [string]::IsNullOrWhiteSpace((& git -C $item.RepoRoot status --porcelain | Out-String))
        }
        $parts = $item.VersionSpec.Split('+')
        $records += [ordered]@{ application = $item.App; version = $item.VersionSpec; versionName = $parts[0]; buildNumber = [int]$parts[1]; apk = $name; sha256 = $hash; certificateSha256 = $item.Certificate; sourceCommit = $sourceCommit; sourceHasUncommittedChanges = $dirty }
    }
    $manifest = [ordered]@{ schemaVersion = 1; createdAtUtc = [DateTime]::UtcNow.ToString('o'); licenseProtocol = 'VPK1'; applications = $records }
    [IO.File]::WriteAllText((Join-Path $staging 'release-manifest.json'), ($manifest | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))
    $instructions = "VENTO GUNCELLEME PAKETI`r`n`r`n1. Uygulama icinden yedek alin ve cihaz disina kopyalayin.`r`n2. Mevcut uygulamayi KALDIRMADAN ilgili APKyi kurun.`r`n3. Musteriye yalnizca VentoPOS APKsini verin; Keygen yoneticiye ozeldir.`r`n4. Lisans, musteri/siparis kayitlari ve yaziciyi kontrol edin.`r`n5. Keygen anahtari APKya gomulmez; gerekiyorsa mevcut yonetici anahtarini kurulum ekranindan tanimlayin.`r`n`r`nKeygen iceren ZIP yoneticiye ozeldir; tum paketi musteriye gondermeyin. Musteriye VentoPOS-update ZIP dosyasini iletin.`r`nPaket keystore, ozel anahtar, musteri verisi veya debug sembolu icermez.`r`n"
    [IO.File]::WriteAllText((Join-Path $staging 'INSTALLATION.txt'), $instructions, (New-Object Text.UTF8Encoding($false)))
    $zipStaging = Join-Path $OutputRoot ('.staging-' + $id + '.zip')
    Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $zipStaging -CompressionLevel Optimal
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($zipStaging)
    try {
        if ($archive.Entries.Count -ne ($Items.Count * 2 + 2)) { throw 'Paket dosya sayisi dogrulanamadi.' }
        foreach ($record in $records) {
            $entry = $archive.GetEntry($record.apk)
            if (-not $entry) { throw 'Paket APK dosyasi eksik.' }
            $stream = $entry.Open(); $algorithm = [Security.Cryptography.SHA256]::Create()
            try { $hash = ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
            finally { $stream.Dispose(); $algorithm.Dispose() }
            if ($hash -cne $record.sha256) { throw 'ZIP icindeki APK ozeti dogrulanamadi.' }
        }
    } finally { $archive.Dispose() }
    $final = Join-Path $OutputRoot $id; $zip = Join-Path $OutputRoot "$id.zip"
    [IO.Directory]::Move($staging, $final); [IO.File]::Move($zipStaging, $zip)
    $zipHash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText("$zip.sha256", "$zipHash  $id.zip`n", (New-Object Text.UTF8Encoding($false)))
    $children = @()
    if ($Items.Count -gt 1) {
        foreach ($item in $Items) { $children += New-UpdatePackage @($item) $OutputRoot }
    }
    return [pscustomobject]@{ Directory = $final; Zip = $zip; ApplicationPackages = $children }
}
function Invoke-ReleaseSelfTest {
    $expected = 'a' * 64
    Assert-ReleaseCertificate "V2 Signer: certificate SHA-256 digest: $expected" $expected
    $rejections = 0
    foreach ($text in @('', 'CN=Android Debug', "V2 Signer: certificate SHA-256 digest: $('b' * 64)")) { try { Assert-ReleaseCertificate $text $expected } catch { $rejections++ } }
    Assert-UpgradeBuild '2.8.5+26' 25
    foreach ($version in @('2.8.4+25', '2.8.3+24', 'invalid')) { try { Assert-UpgradeBuild $version 25 } catch { $rejections++ } }
    if ($rejections -ne 6) { throw 'Sertifika/build guvenlik testleri basarisiz.' }
    $testRoot = Join-Path ([IO.Path]::GetTempPath()) ('vento-release-selftest-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($testRoot) | Out-Null
    try {
        # Keep version-selection tests non-interactive and independent of workspace Git state.
        function Read-TimedKey([string]$PromptPrefix, [int]$Seconds = 6) { return 'ENTER' }
        foreach ($fixture in @(
            @{ Name = 'VentoPOS'; Head = '2.8.4+25'; Current = '2.8.5+26'; Previous = 26; Next = '2.8.6+27' },
            @{ Name = 'VentoPOS_Keygen'; Head = '1.1.2+4'; Current = '1.1.3+5'; Previous = 5; Next = '1.1.4+6' }
        )) {
            $repo = Join-Path $testRoot $fixture.Name
            [IO.Directory]::CreateDirectory($repo) | Out-Null
            & git -C $repo init --quiet
            if ($LASTEXITCODE -ne 0) { throw 'Surum testi deposu olusturulamadi.' }
            [IO.File]::WriteAllText((Join-Path $repo 'pubspec.yaml'), "version: $($fixture.Head)`n")
            & git -C $repo -c core.autocrlf=false add -- pubspec.yaml
            if ($LASTEXITCODE -ne 0) { throw 'Surum testi hazirlanamadi.' }
            & git -C $repo -c user.name=ReleaseTest -c user.email=release-test@example.invalid -c commit.gpgsign=false -c core.hooksPath=NUL commit --quiet -m 'test: seed version fixture'
            if ($LASTEXITCODE -ne 0) { throw 'Surum testi HEAD kaydi olusturulamadi.' }
            $current = "version: $($fixture.Current)`n"
            [IO.File]::WriteAllText((Join-Path $repo 'pubspec.yaml'), $current)
            $selected = Select-NextVersionSpec -AppName $fixture.Name -RepoDir $repo -PubspecRaw $current -PreviousBuild $fixture.Previous
            if ($selected -cne $fixture.Next) { throw "Yayinlanmis build tekrar kullanildi: $selected; beklenen: $($fixture.Next)" }
            Assert-UpgradeBuild $selected $fixture.Previous
            $retry = Select-NextVersionSpec -AppName $fixture.Name -RepoDir $repo -PubspecRaw $current -PreviousBuild ($fixture.Previous - 1)
            if ($retry -cne $fixture.Current) { throw 'Yayinlanmamis surum tekrar denemede korunmadi.' }
            $ahead = Select-NextVersionSpec -AppName $fixture.Name -RepoDir $repo -PubspecRaw $current -PreviousBuild 40
            if ($ahead -notmatch '\+41$') { throw 'APK build numarasi kaynak build numarasindan ilerideyken otomatik artirma basarisiz.' }
            $forced = Select-NextVersionSpec -AppName $fixture.Name -RepoDir $repo -PubspecRaw $current -PreviousBuild $fixture.Previous -ForcedSpec $fixture.Current
            $forcedRejected = $false
            try { Assert-UpgradeBuild $forced $fixture.Previous } catch { $forcedRejected = $true }
            if (-not $forcedRejected) { throw 'Elle girilen yayinlanmis build kabul edildi.' }
        }
        $source = Join-Path $testRoot 'candidate.apk'; $published = Join-Path $testRoot 'current.apk'
        [IO.File]::WriteAllText($source, 'fixture-one'); Publish-VerifiedFile $source $published
        [IO.File]::WriteAllText($source, 'fixture-two'); Publish-VerifiedFile $source $published
        if ([IO.File]::ReadAllText($published) -cne 'fixture-two') { throw 'Atomik yayin testi basarisiz.' }
        [IO.File]::WriteAllText($source, 'fixture-three')
        $immutableRejected = $false
        try { Publish-VerifiedFile $source $published -Immutable } catch { $immutableRejected = $true }
        if (-not $immutableRejected -or [IO.File]::ReadAllText($published) -cne 'fixture-two') { throw 'Arsiv degismezligi testi basarisiz.' }
        $item = [pscustomobject]@{ App = 'Test'; VersionSpec = '1.0.1+2'; CandidateApk = $source; VersionedApk = (Join-Path $testRoot 'Test-v1.0.1-build2-release.apk'); Certificate = $expected; GitSummary = 'test fixture' }
        $package = New-UpdatePackage @($item) $testRoot
        if (-not (Test-Path -LiteralPath $package.Zip)) { throw 'Paket testi basarisiz.' }
        $missingRejected = $false
        try { $null = Get-AndroidBuildTools (Join-Path $testRoot 'missing-tools') } catch { $missingRejected = $true }
        if (-not $missingRejected) { throw 'Eksik arac testi basarisiz.' }
        Write-Pass 'Otomatik surum secimi, sertifika, build, atomik yayin, ZIP butunlugu ve eksik arac testleri gecti.'
    } finally {
        $resolved = [IO.Path]::GetFullPath($testRoot)
        if (-not $resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase) -or -not (Split-Path -Leaf $resolved).StartsWith('vento-release-selftest-')) { throw 'Test temizleme siniri gecersiz.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

# ---------------------------------------------------------------------------
# PIPELINE 1: VENTOPOS (Musteri Uygulamasi)
# ---------------------------------------------------------------------------
function Invoke-VentoPosPipeline {
    Write-Section "BOLUM A: VENTOPOS (MUSTERI UYGULAMASI) SAFE RELEASE PIPELINE"
    Push-Location $PosRoot
    try {
        & $FlutterBin pub get | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Bagimliliklar yuklenemedi." }
        # ADIM 1: Guvenlik Kapilari
        Write-SubHeader "[VentoPOS 1/5] Yerinde Guncelleme (In-Place Upgrade) Denetimi"
        $BuildGradlePath = Join-Path $PosRoot "android\app\build.gradle.kts"
        $KeyPropsPath    = Join-Path $PosRoot "android\key.properties"
        if (-not (Test-Path $BuildGradlePath)) { Write-FailAndExit "VentoPOS android\app\build.gradle.kts bulunamadi!" }
        $BuildGradleText = [System.IO.File]::ReadAllText($BuildGradlePath, [System.Text.Encoding]::UTF8)
        if ($BuildGradleText -notmatch 'applicationId\s*=\s*"com\.ventopos\.ventopos"') {
            Write-FailAndExit "VentoPOS applicationId 'com.ventopos.ventopos' degismis!"
        }
        if (-not (Test-Path $KeyPropsPath)) {
            Write-FailAndExit "VentoPOS android\key.properties bulunamadi! Sahadaki verileri korumak icin islem durduruldu."
        }
        $KeyPropsText = [System.IO.File]::ReadAllText($KeyPropsPath, [System.Text.Encoding]::UTF8)
        $StoreFileRel = "../keystore/ventopos-release.jks"
        if ($KeyPropsText -match '(?m)^storeFile\s*=\s*(.+)$') { $StoreFileRel = $Matches[1].Trim() }
        $KsApp     = [System.IO.Path]::GetFullPath((Join-Path (Join-Path $PosRoot "android\app") $StoreFileRel))
        $KsAndroid = [System.IO.Path]::GetFullPath((Join-Path (Join-Path $PosRoot "android") $StoreFileRel))
        $KsDefault = Join-Path $PosRoot "android\keystore\ventopos-release.jks"
        if ((-not (Test-Path $KsApp)) -and (-not (Test-Path $KsAndroid)) -and (-not (Test-Path $KsDefault))) {
            Write-FailAndExit "VentoPOS uretim keystore dosyasi ($StoreFileRel) bulunamadi!"
        }

        $DbConnText = [System.IO.File]::ReadAllText((Join-Path $PosRoot "lib\data\database\connection\database_connection.dart"), [System.Text.Encoding]::UTF8)
        if ($DbConnText -notmatch "kVentoPosEnterpriseDbName\s*=\s*'ventopos_enterprise_db'") {
            Write-FailAndExit "VentoPOS SQLite veritabani adi ('ventopos_enterprise_db') degismis!"
        }

        $LicConstText = [System.IO.File]::ReadAllText((Join-Path $PosRoot "lib\core\license\license_constants.dart"), [System.Text.Encoding]::UTF8)
        if (($LicConstText -notmatch "deviceCodePrefix\s*=\s*'VP'") -or ($LicConstText -notmatch "activationKeyPrefix\s*=\s*'VPK1-'")) {
            Write-FailAndExit "VentoPOS Ed25519 lisans sabitleri (VP / VPK1-) degismis!"
        }

        # Kardes Keygen deposu varsa Public Key eslesmesini bastan denetle
        if ($KeygenRoot) {
            $SiblingKgConst = Join-Path $KeygenRoot "lib\core\constants\keygen_constants.dart"
            if (Test-Path $SiblingKgConst) {
                $KgTxt = [System.IO.File]::ReadAllText($SiblingKgConst, [System.Text.Encoding]::UTF8)
                if (($LicConstText -match "publicKeyBase64Url\s*=\s*'([^']+)'") -and ($KgTxt -match "expectedPublicKeyBase64Url\s*=\s*'([^']+)'")) {
                    $PosPub = ([regex]::Match($LicConstText, "publicKeyBase64Url\s*=\s*'([^']+)'")).Groups[1].Value
                    $KgPub  = ([regex]::Match($KgTxt, "expectedPublicKeyBase64Url\s*=\s*'([^']+)'")).Groups[1].Value
                    if ($PosPub -ne $KgPub) {
                        Write-FailAndExit "KRITIK: VentoPOS publicKey ($PosPub) ile Keygen expectedPublicKey ($KgPub) eslesmiyor!"
                    }
                }
            }
        }

        if (-not $SkipCodegen) {
            & $DartBin run build_runner build --delete-conflicting-outputs | Out-Host
            if ($LASTEXITCODE -ne 0) { Write-FailAndExit "VentoPOS build_runner basarisiz oldu!" }
        }
        Write-Pass "VentoPOS guvenlik kapilari (Keystore, SQLite, Ed25519, Codegen) dogrulandi."

        # ADIM 2: Surum Artirma ve Senkronizasyon
        Write-SubHeader "[VentoPOS 2/5] Surum Artirma ve Senkronizasyon"
        $PubspecPath = Join-Path $PosRoot "pubspec.yaml"
        $AppInfoPath = Join-Path $PosRoot "lib\core\constants\app_info_constants.dart"
        $PubspecRaw  = [System.IO.File]::ReadAllText($PubspecPath, [System.Text.Encoding]::UTF8)
        if ($PubspecRaw -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+\+\d+)') {
            Write-FailAndExit "VentoPOS pubspec.yaml icinde version okunamadi!"
        }
        $CurFullSpec = $Matches[1]
        $TargetSpec  = Select-NextVersionSpec -AppName "VentoPOS" -RepoDir $PosRoot -PubspecRaw $PubspecRaw -ForcedSpec $ForcedPosVersion -PreviousBuild $PreviousBuilds['VentoPOS']

        Assert-UpgradeBuild $TargetSpec $PreviousBuilds['VentoPOS']
        $SpecParts = $TargetSpec -split '\+'
        $VerName   = $SpecParts[0]
        $VerCode   = [int]$SpecParts[1]

        if ($TargetSpec -ne $CurFullSpec) {
            $PubspecUpdated = [regex]::Replace($PubspecRaw, '(?m)^version:\s*[^\r\n]+', "version: $TargetSpec", 1)
            Write-Utf8NoBom -FilePath $PubspecPath -Content $PubspecUpdated
        }
        $AppInfoRaw = [System.IO.File]::ReadAllText($AppInfoPath, [System.Text.Encoding]::UTF8)
        $AppInfoUpdated = [regex]::Replace($AppInfoRaw, "fallbackPubspecVersionSpec\s*=\s*'[^']*'", "fallbackPubspecVersionSpec = '$TargetSpec'", 1)
        if ($AppInfoUpdated -ne $AppInfoRaw) {
            Write-Utf8NoBom -FilePath $AppInfoPath -Content $AppInfoUpdated
        }
        Write-Pass "VentoPOS surumu senkronize edildi: $TargetSpec"

        # ADIM 3: Analiz ve Testler
        Write-SubHeader "[VentoPOS 3/5] flutter analyze & flutter test"
        & $FlutterBin analyze --no-pub | Out-Host
        if ($LASTEXITCODE -ne 0) { Write-FailAndExit "VentoPOS flutter analyze hatasi!" }
        & $FlutterBin test --no-pub | Out-Host
        if ($LASTEXITCODE -ne 0) { Write-FailAndExit "VentoPOS flutter test hatasi!" }
        Write-Pass "VentoPOS statik analiz ve calistirilan testleri basariyla tamamlandi."

        # ADIM 4: Imzali, Obfuscated & Stripped Release APK Derleme
        Write-SubHeader "[VentoPOS 4/5] Imzali Obfuscated Release APK Derleme (--strip aktif)"
        $DistDir    = Join-Path $PosRoot "dist"
        $SymbolsDir = Join-Path $PosRoot "debug_symbols\ventopos\$TargetSpec"
        New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
        New-Item -ItemType Directory -Force -Path $SymbolsDir | Out-Null

        $staleCandidate = Join-Path (Get-Location).Path 'build\app\outputs\flutter-apk\app-release.apk'
        if (Test-Path -LiteralPath $staleCandidate) { Remove-Item -LiteralPath $staleCandidate -Force }
        & $FlutterBin build apk --release --no-pub --obfuscate "--split-debug-info=$SymbolsDir" "--extra-gen-snapshot-options=--strip" | Out-Host
        if ($LASTEXITCODE -ne 0) { Write-FailAndExit "VentoPOS release APK derlemesi basarisiz oldu!" }

        $BuiltApk     = Join-Path $PosRoot "build\app\outputs\flutter-apk\app-release.apk"
        $CanonicalApk = Join-Path $DistDir "VentoPOS-release.apk"
        $VersionedApk = Join-Path $DistDir "VentoPOS-v$VerName-build$VerCode-release.apk"


        $ApkSizeMb   = [math]::Round((Get-Item $BuiltApk).Length / 1MB, 2)
        $CertSummary = Verify-BuiltReleaseApk -ApkPath $BuiltApk -ExpectedPackageId "com.ventopos.ventopos" -ExpectedVersionCode $VerCode -ExpectedVersionName $VerName
        Write-Pass "VentoPOS APK uretildi ve dogrulandi ($ApkSizeMb MB) - $CertSummary"

        $GitHash = (& git rev-parse --short HEAD | Out-String).Trim()
        $GitPushMsg = 'Git islemi istenmedi'

        return [PSCustomObject]@{
            RepoRoot     = $PosRoot
            App          = "VentoPOS"
            VersionSpec  = $TargetSpec
            CandidateApk = $BuiltApk
            CanonicalApk = $CanonicalApk
            VersionedApk = $VersionedApk
            MirroredApk  = $null
            SizeMb       = $ApkSizeMb
            Certificate  = $CertSummary
            GitSummary   = "Commit $GitHash | $GitPushMsg"
            DistDir      = $DistDir
        }
    } finally {
        Pop-Location
    }
}

# ---------------------------------------------------------------------------
# PIPELINE 2: VENTOPOS_KEYGEN (Yonetici Lisans Uretici)
# ---------------------------------------------------------------------------
function Invoke-VentoKeygenPipeline {
    Write-Section "BOLUM B: VENTOPOS_KEYGEN (YONETICI UYGULAMASI) SAFE RELEASE PIPELINE"
    Push-Location $KeygenRoot
    try {
        & $FlutterBin pub get | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "Bagimliliklar yuklenemedi." }
        # ADIM 1: 5 Guvenlik Kapisi
        Write-SubHeader "[Keygen 1/5] Guvenlik, Ed25519 Kripto ve Yerinde Guncelleme Denetimi"
        $BuildGradlePath = Join-Path $KeygenRoot "android\app\build.gradle.kts"
        $KeyPropsPath    = Join-Path $KeygenRoot "android\key.properties"
        if (-not (Test-Path $BuildGradlePath)) { Write-FailAndExit "Keygen Gate 1: android\app\build.gradle.kts bulunamadi!" }
        $BuildGradleText = [System.IO.File]::ReadAllText($BuildGradlePath, [System.Text.Encoding]::UTF8)
        if ($BuildGradleText -notmatch 'applicationId\s*=\s*"com\.ventopos\.ventopos_keygen"') {
            Write-FailAndExit "Keygen Gate 1: applicationId 'com.ventopos.ventopos_keygen' degistirilmis!"
        }
        if ($BuildGradleText -match 'minSdk\s*=\s*(\d+)') {
            if ([int]$Matches[1] -gt 24) { Write-FailAndExit "Keygen Gate 1: minSdk 24'un uzerine cikarilmis!" }
        }
        if (-not (Test-Path $KeyPropsPath)) {
            Write-FailAndExit "Keygen Gate 1: android\key.properties bulunamadi! Debug imzasi cihazdaki lisans gecmisini bozar!"
        }
        $KeyPropsText = [System.IO.File]::ReadAllText($KeyPropsPath, [System.Text.Encoding]::UTF8)
        $StoreFileRel = "../keystore/keygen-release.jks"
        if ($KeyPropsText -match '(?m)^storeFile\s*=\s*(.+)$') { $StoreFileRel = $Matches[1].Trim() }
        $KsApp     = [System.IO.Path]::GetFullPath((Join-Path (Join-Path $KeygenRoot "android\app") $StoreFileRel))
        $KsAndroid = [System.IO.Path]::GetFullPath((Join-Path (Join-Path $KeygenRoot "android") $StoreFileRel))
        $KsDefault = Join-Path $KeygenRoot "android\keystore\keygen-release.jks"
        if ((-not (Test-Path $KsApp)) -and (-not (Test-Path $KsAndroid)) -and (-not (Test-Path $KsDefault))) {
            Write-FailAndExit "Keygen Gate 1: Uretim keystore dosyasi ($StoreFileRel) bulunamadi!"
        }

        $KeygenConstPath = Join-Path $KeygenRoot "lib\core\constants\keygen_constants.dart"
        $SignerPath      = Join-Path $KeygenRoot "lib\core\crypto\ed25519_license_signer.dart"
        $SecretsJsonPath = Join-Path $KeygenRoot "secrets\keygen_signing_key.json"

        $KeygenConstText = [System.IO.File]::ReadAllText($KeygenConstPath, [System.Text.Encoding]::UTF8)
        if ($KeygenConstText -notmatch "expectedPublicKeyBase64Url\s*=\s*'([^']+)'") {
            Write-FailAndExit "Keygen Gate 2: KeygenConstants.expectedPublicKeyBase64Url okunamadi!"
        }
        $KeygenPubKey = $Matches[1]

        if (($KeygenConstText -notmatch "deviceCodePrefix\s*=\s*'VP'") -or
            ($KeygenConstText -notmatch "activationKeyPrefix\s*=\s*'VPK1-'") -or
            ($KeygenConstText -notmatch "signatureDomainTag\s*=\s*'VP-LICENSE-V1:'") -or
            ($KeygenConstText -notmatch "protocolVersion\s*=\s*1\b")) {
            Write-FailAndExit "Keygen Gate 2: Ed25519 protokol sabitleri degistirilmis!"
        }

        if ($PosRoot) {
            $SiblingVentoLic = Join-Path $PosRoot "lib\core\license\license_constants.dart"
            if (Test-Path $SiblingVentoLic) {
                $CustomerLicText = [System.IO.File]::ReadAllText($SiblingVentoLic, [System.Text.Encoding]::UTF8)
                if ($CustomerLicText -match "publicKeyBase64Url\s*=\s*'([^']+)'") {
                    if ($Matches[1] -ne $KeygenPubKey) {
                        Write-FailAndExit "Keygen Gate 2: KRITIK! Keygen expectedPublicKey ($KeygenPubKey) ile VentoPOS publicKey ($($Matches[1])) eslesmiyor!"
                    }
                    Write-Pass "Keygen Gate 2a: Kardes VentoPOS deposu ile Ed25519 Public Key (%100 eslesme) dogrulandi."
                }
            }
        }

        # Signing seeds are provisioned on the administrator device, never embedded in APKs.
        if ($KeygenConstText -match 'VP_KEYGEN_PRIVATE_SEED|compileTimePrivateSeed|defaultValue:') {
            Write-FailAndExit "Signing seeds must not be embedded in the Keygen APK."
        }

        $SignerText = [System.IO.File]::ReadAllText($SignerPath, [System.Text.Encoding]::UTF8)
        if ($SignerText -notmatch "_ed25519\.verify\(") {
            Write-FailAndExit "Keygen Gate 2: Ed25519LicenseSigner icinde zorunlu self-verification kaldirilmis!"
        }

        if (($KeygenConstText -notmatch "storedPrivateSeedPrefKey\s*=\s*'vp_keygen_private_seed_b64_v1'") -or
            ($KeygenConstText -notmatch "issuedHistoryPrefKey\s*=\s*'vp_keygen_issued_history_v1'")) {
            Write-FailAndExit "Keygen Gate 3: SharedPreferences anahtarlari degistirilmis! Gecmis lisans kayitlari kaybolur!"
        }
        $MainKtPath = Join-Path $KeygenRoot "android\app\src\main\kotlin\com\ventopos\ventopos_keygen\MainActivity.kt"
        $MainKtText = [System.IO.File]::ReadAllText($MainKtPath, [System.Text.Encoding]::UTF8)
        if (($KeygenConstText -notmatch "com\.ventopos\.ventopos_keygen/launcher") -or
            ($MainKtText -notmatch "com\.ventopos\.ventopos_keygen/launcher")) {
            Write-FailAndExit "Keygen Gate 3: Native WhatsApp MethodChannel Dart ve Kotlin arasinda senkron degil!"
        }

        $BadRuntimeFiles = @(); $BadNetworkFiles = @()
        $DartFiles = Get-ChildItem -Path (Join-Path $KeygenRoot "lib") -Recurse -Filter "*.dart"
        foreach ($df in $DartFiles) {
            $txt = [System.IO.File]::ReadAllText($df.FullName, [System.Text.Encoding]::UTF8)
            if ($txt -match '\.runtimeType\.toString\(\)') { $BadRuntimeFiles += $df.FullName.Substring($KeygenRoot.Length + 1) }
            if ($txt -match "import\s+'package:(http|dio)/" -or $txt -match '\bHttpClient\b') { $BadNetworkFiles += $df.FullName.Substring($KeygenRoot.Length + 1) }
        }
        if ($BadRuntimeFiles.Count -gt 0) { Write-FailAndExit ("Keygen Gate 4: .runtimeType.toString() bulundu: " + ($BadRuntimeFiles -join ", ")) }
        if ($BadNetworkFiles.Count -gt 0) { Write-FailAndExit ("Keygen Gate 4: Offline Keygen icinde ag istemcisi bulundu: " + ($BadNetworkFiles -join ", ")) }

        if (-not (Test-Path (Join-Path $KeygenRoot "test\keygen_onboarding_and_update_test.dart"))) {
            Write-FailAndExit "Keygen Gate 5: test\keygen_onboarding_and_update_test.dart bulunamadi!"
        }
        Write-Pass "Keygen 5 guvenlik kapisi (Keystore, Ed25519 Seed, SharedPrefs, Offline/Obfuscate, Test) dogrulandi."

        # ADIM 2: Surum Artirma ve Senkronizasyon
        Write-SubHeader "[Keygen 2/5] Surum Artirma ve Senkronizasyon"
        $PubspecPath = Join-Path $KeygenRoot "pubspec.yaml"
        $PubspecRaw  = [System.IO.File]::ReadAllText($PubspecPath, [System.Text.Encoding]::UTF8)
        if ($PubspecRaw -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+\+\d+)') {
            Write-FailAndExit "Keygen pubspec.yaml icinde version okunamadi!"
        }
        $CurFullSpec = $Matches[1]
        $TargetSpec  = Select-NextVersionSpec -AppName "VentoPOS_Keygen" -RepoDir $KeygenRoot -PubspecRaw $PubspecRaw -ForcedSpec $ForcedKeygenVersion -PreviousBuild $PreviousBuilds['VentoPOS_Keygen']

        Assert-UpgradeBuild $TargetSpec $PreviousBuilds['VentoPOS_Keygen']
        $SpecParts        = $TargetSpec -split '\+'
        $FinalVersionName = $SpecParts[0]
        $FinalVersionCode = [int]$SpecParts[1]

        if ($TargetSpec -ne $CurFullSpec) {
            $UpdatedPubspec = [regex]::Replace($PubspecRaw, '(?m)^version:\s*[^\r\n]+', "version: $TargetSpec", 1)
            Write-Utf8NoBom -FilePath $PubspecPath -Content $UpdatedPubspec
        }

        $UpdatedKeygenConst = $KeygenConstText
        $UpdatedKeygenConst = [regex]::Replace($UpdatedKeygenConst, "static\s+const\s+String\s+appVersion\s*=\s*'[^']*';", "static const String appVersion = '$FinalVersionName';", 1)
        $UpdatedKeygenConst = [regex]::Replace($UpdatedKeygenConst, "static\s+const\s+int\s+appBuildNumber\s*=\s*\d+;", "static const int appBuildNumber = $FinalVersionCode;", 1)
        $UpdatedKeygenConst = [regex]::Replace($UpdatedKeygenConst, "static\s+const\s+String\s+appFullVersion\s*=\s*'[^']*';", "static const String appFullVersion = '$TargetSpec';", 1)
        if ($UpdatedKeygenConst -ne $KeygenConstText) {
            Write-Utf8NoBom -FilePath $KeygenConstPath -Content $UpdatedKeygenConst
        }
        Write-Pass "Keygen surumu ve KeygenConstants senkronize edildi: $TargetSpec"

        # ADIM 3: Analiz ve Testler
        Write-SubHeader "[Keygen 3/5] flutter analyze & flutter test"
        & $FlutterBin analyze --no-pub | Out-Host
        if ($LASTEXITCODE -ne 0) { Write-FailAndExit "Keygen flutter analyze hatasi!" }
        & $FlutterBin test --no-pub | Out-Host
        if ($LASTEXITCODE -ne 0) { Write-FailAndExit "Keygen flutter test hatasi!" }
        Write-Pass "Keygen statik analiz ve calistirilan testleri basariyla tamamlandi."

        # ADIM 4: Imzali, Obfuscated & Stripped Release APK Derleme
        Write-SubHeader "[Keygen 4/5] Imzali Obfuscated Release APK Derleme (--strip aktif)"
        $DistDir    = Join-Path $KeygenRoot "dist"
        $SymbolsDir = Join-Path $KeygenRoot "debug_symbols\keygen\$TargetSpec"
        New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
        New-Item -ItemType Directory -Force -Path $SymbolsDir | Out-Null

        $staleCandidate = Join-Path (Get-Location).Path 'build\app\outputs\flutter-apk\app-release.apk'
        if (Test-Path -LiteralPath $staleCandidate) { Remove-Item -LiteralPath $staleCandidate -Force }
        & $FlutterBin build apk --release --no-pub --obfuscate "--split-debug-info=$SymbolsDir" "--extra-gen-snapshot-options=--strip" | Out-Host
        if ($LASTEXITCODE -ne 0) { Write-FailAndExit "VentoPOS_Keygen release APK derlemesi basarisiz oldu!" }

        $BuiltApk     = Join-Path $KeygenRoot "build\app\outputs\flutter-apk\app-release.apk"
        $CanonicalApk = Join-Path $DistDir "VentoPOS_Keygen-release.apk"
        $VersionedApk = Join-Path $DistDir "VentoPOS_Keygen-v$FinalVersionName-build$FinalVersionCode-release.apk"

        # Customer/admin isolation: never mirror Keygen APK into ventoPOS\dist.
        # Keygen artifacts stay under ventoPOS_Keygen\dist and the root admin package dist\.

        $ApkSizeMb   = [math]::Round((Get-Item $BuiltApk).Length / 1MB, 2)
        $CertSummary = Verify-BuiltReleaseApk -ApkPath $BuiltApk -ExpectedPackageId "com.ventopos.ventopos_keygen" -ExpectedVersionCode $FinalVersionCode -ExpectedVersionName $FinalVersionName
        Write-Pass "Keygen APK uretildi ve dogrulandi ($ApkSizeMb MB) - $CertSummary"

        $GitHash = (& git rev-parse --short HEAD | Out-String).Trim()
        $GitPushMsg = 'Git islemi istenmedi'

        return [PSCustomObject]@{
            RepoRoot     = $KeygenRoot
            App          = "VentoPOS_Keygen"
            VersionSpec  = $TargetSpec
            CandidateApk = $BuiltApk
            CanonicalApk = $CanonicalApk
            VersionedApk = $VersionedApk
            MirroredApk  = $null
            SizeMb       = $ApkSizeMb
            Certificate  = $CertSummary
            GitSummary   = "Commit $GitHash | $GitPushMsg"
            DistDir      = $DistDir
        }
    } finally {
        Pop-Location
    }
}

# ---------------------------------------------------------------------------
# Secilen Hedefleri Calistir ve Ortak Sonuc Raporu Uret
# ---------------------------------------------------------------------------
if (($CliTokens -contains '--version') -and $BuildPos -and $BuildKeygen) { throw '--version tek hedef gerektirir; iki hedef icin ayri surum belirtin.' }
if ($SelfTest) { Invoke-ReleaseSelfTest; exit 0 }
if (-not $VerifyOnly) {
    $mutexHasher = [Security.Cryptography.SHA256]::Create()
    try { $mutexSuffix = ([BitConverter]::ToString($mutexHasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($BatDir.ToLowerInvariant())))).Replace('-','') } finally { $mutexHasher.Dispose() }
    $ReleaseMutex = New-Object Threading.Mutex($false, ('Local\VentoUnifiedRelease-' + $mutexSuffix))
    try { $acquired = $ReleaseMutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $acquired = $true }
    if (-not $acquired) { throw 'Bu calisma alaninda baska bir release islemi suruyor.' }
}
if ($BuildPos) { Invoke-ReleasePreflight 'VentoPOS' $PosRoot 'com.ventopos.ventopos' }
if ($BuildKeygen) { Invoke-ReleasePreflight 'VentoPOS_Keygen' $KeygenRoot 'com.ventopos.ventopos_keygen' }
if ($VerifyOnly) { Write-Pass 'Secilen mevcut APKlar ve guvenlik kapilari dogrulandi; dosya degistirilmedi.'; exit 0 }
$Results = @()
if ($BuildPos) { $Results += (Invoke-VentoPosPipeline) }
if ($BuildKeygen) { $Results += (Invoke-VentoKeygenPipeline) }
$Package = New-UpdatePackage $Results (Join-Path $BatDir 'dist')
foreach ($result in $Results) {
    $verified = Join-Path $Package.Directory (Split-Path -Leaf $result.VersionedApk)
    Publish-VerifiedFile $verified $result.VersionedApk -Immutable
    Publish-VerifiedFile $verified $result.CanonicalApk
    if ($result.MirroredApk) { Publish-VerifiedFile $verified $result.MirroredApk }
}
if (-not $NoGit) {
    foreach ($result in $Results) {
        $repo = if ($result.App -eq 'VentoPOS') { $PosRoot } else { $KeygenRoot }
        & git -C $repo add -A | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'Git staging basarisiz.' }
        $staged = @(& git -C $repo diff --cached --name-only)
        if (@($staged | Where-Object { $_ -match '(^|/)key\.properties$|\.jks$|\.keystore$|^secrets/|^dist/|^debug_symbols/|^build/|\.apk$|\.aab$' }).Count -gt 0) { throw 'Commit icinde gizli dosya veya derleme ciktisi var.' }
        if ($staged.Count -gt 0) {
            & git -C $repo commit -m "chore(release): prepare $($result.App) $($result.VersionSpec)" | Out-Host
            if ($LASTEXITCODE -ne 0) { throw 'Git commit basarisiz.' }
        }
        if (-not $NoPush) {
            & git -C $repo push origin HEAD | Out-Host
            if ($LASTEXITCODE -ne 0) { throw 'Git push basarisiz; yerel paket korunuyor.' }
        }
        $result.GitSummary = 'Istenen Git islemi tamamlandi'
    }
}
Write-Pass "Dogrulanmis guncelleme paketi: $($Package.Zip)"
foreach ($applicationPackage in $Package.ApplicationPackages) { Write-Pass "Uygulamaya ozel paket: $($applicationPackage.Zip)" }

Write-Section "UNIFIED SAFE RELEASE SONUC RAPORU"
foreach ($r in $Results) {
    Write-Host "  [$($r.App)]" -ForegroundColor Yellow
    Write-Host "    * Surum & Build        : $($r.VersionSpec)" -ForegroundColor White
    Write-Host "    * Guncel APK           : $($r.CanonicalApk) ($($r.SizeMb) MB)" -ForegroundColor Cyan
    Write-Host "    * Arsive Ozel APK      : $($r.VersionedApk)" -ForegroundColor Cyan
    if ($r.MirroredApk) {
        Write-Host "    * Merkezi Dist Kopyasi : $($r.MirroredApk)" -ForegroundColor Cyan
    }
    Write-Host "    * Imza Dogrulamasi     : $($r.Certificate)" -ForegroundColor Green
    Write-Host "    * Git Durumu           : $($r.GitSummary)" -ForegroundColor White
    Write-Host ""
}

if (-not $NoOpenDist) {
    Start-Process explorer.exe -WindowStyle Hidden -ArgumentList ('"' + $Package.Directory + '"')
}
