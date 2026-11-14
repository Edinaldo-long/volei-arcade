<#
.SYNOPSIS
    Script automatizado de release para o jogo Volei Arcade.
#>

[CmdletBinding()]
param(
    [string]$CustomVersion = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Localiza o diretorio do projeto e o pubspec.yaml
$targetDir = $PSScriptRoot
$pubspecPath = Join-Path $targetDir "pubspec.yaml"

if (-not (Test-Path $pubspecPath)) {
    $parentPubspec = Join-Path (Split-Path -Parent $targetDir) "pubspec.yaml"
    if (Test-Path $parentPubspec) {
        $targetDir = Split-Path -Parent $targetDir
        $pubspecPath = $parentPubspec
    } else {
        $childPubspec = Join-Path $targetDir "volei\pubspec.yaml"
        if (Test-Path $childPubspec) {
            $targetDir = Join-Path $targetDir "volei"
            $pubspecPath = $childPubspec
        } else {
            Write-Error "Arquivo pubspec.yaml nao foi encontrado."
            exit 1
        }
    }
}

Set-Location $targetDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "        ESTEIRA AUTOMATIZADA DE RELEASE - VOLEI           " -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Diretorio do projeto: $targetDir" -ForegroundColor Gray

# Le o conteudo de pubspec.yaml
$pubspecContent = [System.IO.File]::ReadAllText($pubspecPath, [System.Text.Encoding]::UTF8)

if ($pubspecContent -match 'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)') {
    $major = [int]$Matches[1]
    $minor = [int]$Matches[2]
    $patch = [int]$Matches[3]
    $build = [int]$Matches[4]
    $currentVersion = "$major.$minor.$patch+$build"

    if ([string]::IsNullOrWhiteSpace($CustomVersion)) {
        $nextPatch = $patch + 1
        $nextBuild = $build + 1
        $newVersion = "$major.$minor.$nextPatch+$nextBuild"
        $newTag = "v$major.$minor.$nextPatch"
    } else {
        $newVersion = $CustomVersion
        $cleanVer = $CustomVersion -replace '\+.*$', ''
        $newTag = "v$cleanVer"
    }

    Write-Host "Versao atual:   $currentVersion" -ForegroundColor Yellow
    Write-Host "Nova versao:    $newVersion" -ForegroundColor Green
    Write-Host "Tag de release: $newTag" -ForegroundColor Cyan
} else {
    Write-Error "Nao foi possivel encontrar a linha de versao no formato X.Y.Z+N em $pubspecPath"
    exit 1
}

if ($DryRun) {
    Write-Host "[DRY-RUN] Nenhuma alteracao persistida em disco ou git." -ForegroundColor Magenta
    exit 0
}

# 1. Atualiza pubspec.yaml
$updatedContent = $pubspecContent -replace 'version:\s*\d+\.\d+\.\d+\+\d+', "version: $newVersion"
[System.IO.File]::WriteAllText($pubspecPath, $updatedContent, [System.Text.Encoding]::UTF8)
Write-Host "[OK] pubspec.yaml atualizado com sucesso!" -ForegroundColor Green

# 2. Executa comandos do Git
Write-Host "Sincronizando com o Git..." -ForegroundColor Gray
git add .

$commitMessage = "release: $newTag"
git commit -m $commitMessage
Write-Host "[OK] Commit criado: '$commitMessage'" -ForegroundColor Green

git tag -a $newTag -m "Release $newTag"
Write-Host "[OK] Tag criada: $newTag" -ForegroundColor Green

# Determina branch atual (padrao: main)
$currentBranch = (git branch --show-current).Trim()
if ([string]::IsNullOrWhiteSpace($currentBranch)) {
    $currentBranch = "main"
}

Write-Host "Enviando commits e tags para o repositorio remoto (origin $currentBranch)..." -ForegroundColor Yellow
git push origin $currentBranch --tags
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[ATENCAO] O Git local nao conseguiu autenticar automaticamente no GitHub." -ForegroundColor Red
    Write-Host "O commit e a tag $newTag ja estao salvos localmente!" -ForegroundColor Yellow
    Write-Host "Para enviar agora ao GitHub, execute no seu terminal interativo:" -ForegroundColor Cyan
    Write-Host "    cd volei; git push origin $currentBranch --tags" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "       RELEASE DISPARADA COM SUCESSO!                     " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "A tag $newTag foi enviada para o GitHub." -ForegroundColor Cyan
Write-Host "O GitHub Actions iniciou a compilacao do APK de release." -ForegroundColor Cyan
Write-Host "Acompanhe em tempo real em: https://github.com/Edinaldo-long/volei-arcade/actions" -ForegroundColor Yellow
Write-Host ""
