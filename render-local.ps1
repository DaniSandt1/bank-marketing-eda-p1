# =============================================================================
# Renderizado local de la Entrega P1 — Bank Marketing
# -----------------------------------------------------------------------------
# Hace en tu maquina lo mismo que el workflow de GitHub Actions:
#
#     1. Ejecuta el pipeline de Python  -> figs/ y tablas/
#     2. Renderiza el informe           -> UTEC-Report1.pdf
#     3. Renderiza la presentacion      -> UTEC-Presentation.html
#
# Uso, desde PowerShell y dentro de la carpeta UTEC-Report:
#
#     .\render-local.ps1
#
# Si Windows bloquea la ejecucion de scripts, permitelo solo en esta sesion:
#
#     Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#
# Opciones:
#     .\render-local.ps1 -SoloInforme        solo el PDF
#     .\render-local.ps1 -SoloPresentacion   solo el HTML
#     .\render-local.ps1 -SinPython          no regenera figuras ni tablas
# =============================================================================

param(
    [switch]$SoloInforme,
    [switch]$SoloPresentacion,
    [switch]$SinPython
)

# NO se pone en "Stop". En PowerShell 5.1 eso convierte cualquier escritura a
# stderr de un .exe en un error terminante, y tanto quarto como pdflatex
# escriben su progreso normal por stderr: el script moriria siempre, aun
# cuando el render hubiera ido bien. El control de errores se hace revisando
# $LASTEXITCODE despues de cada llamada, que es el valor fiable.
$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot

function Paso($txt) {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor DarkGray
    Write-Host "  $txt" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor DarkGray
}

function Fallo($txt) {
    Write-Host ""
    Write-Host "ERROR: $txt" -ForegroundColor Red
    exit 1
}

# -----------------------------------------------------------------------------
# Localizar Quarto
# -----------------------------------------------------------------------------
# RStudio trae su propio Quarto, pero no lo anade al PATH. Se busca primero en
# el PATH y, si no esta, en la instalacion de RStudio.
$quarto = (Get-Command quarto -ErrorAction SilentlyContinue).Source
if (-not $quarto) {
    $candidatos = @(
        "$env:ProgramFiles\RStudio\resources\app\bin\quarto\bin\quarto.exe",
        "$env:ProgramFiles\Quarto\bin\quarto.exe",
        "$env:LOCALAPPDATA\Programs\Quarto\bin\quarto.exe"
    )
    $quarto = $candidatos | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $quarto) {
    Fallo "No se encontro Quarto. Instala RStudio o Quarto, o anade quarto.exe al PATH."
}
Write-Host "Quarto: $quarto" -ForegroundColor DarkGray

# -----------------------------------------------------------------------------
# Comprobacion de LaTeX
# -----------------------------------------------------------------------------
# TinyTeX se instala minimo y le faltan cosas que este informe necesita. Sin
# esta comprobacion, el fallo aparece como un error de LaTeX indescifrable a
# mitad del render.
if (-not $SoloPresentacion) {
    $tinytex = "$env:APPDATA\TinyTeX\bin\windows"
    $tlmgr   = Join-Path $tinytex "tlmgr.bat"
    $kpse    = Join-Path $tinytex "kpsewhich.exe"

    if (Test-Path $kpse) {
        # El PATH se fija explicitamente para esta sesion: si el PATH del
        # sistema esta mal formado (p.ej. con saltos de linea dentro de una
        # entrada), las herramientas de TeX no se encuentran entre si y
        # fmtutil falla con "kpsewhich no se reconoce como un comando".
        $env:PATH = "$tinytex;$env:PATH"

        # spanish.ldf lo necesita `lang: es`. No viene en TinyTeX por defecto
        # y su ausencia aborta con "Package babel Error: Unknown option 'spanish'".
        $faltantes = @()
        foreach ($req in @(
            @{ archivo = "spanish.ldf";  paquete = "babel-spanish" },
            @{ archivo = "ltablex.sty";  paquete = "ltablex"       },
            @{ archivo = "xltabular.sty";paquete = "xltabular"     }
        )) {
            & $kpse $req.archivo *> $null
            if ($LASTEXITCODE -ne 0) { $faltantes += $req.paquete }
        }

        if ($faltantes.Count -gt 0) {
            Paso "Instalando paquetes LaTeX que faltan: $($faltantes -join ', ')"
            & $tlmgr install @faltantes
            # Reconstruye el indice de ficheros. Si esto no corre, un paquete
            # puede estar instalado y aun asi dar "File not found".
            & (Join-Path $tinytex "mktexlsr.exe") 2>&1 | Out-Null
        }
    }
}

# -----------------------------------------------------------------------------
# 1. Pipeline de Python
# -----------------------------------------------------------------------------
if (-not $SinPython) {
    Paso "1/3  Pipeline de Python (genera figs/ y tablas/)"

    $python = (Get-Command python -ErrorAction SilentlyContinue).Source
    if (-not $python) { Fallo "No se encontro python en el PATH." }

    & $python "src/eda_bank.py"
    if ($LASTEXITCODE -ne 0) { Fallo "El pipeline de Python fallo." }

    $nFigs = (Get-ChildItem "figs/*.png").Count
    $nTabs = (Get-ChildItem "tablas/*.csv").Count
    Write-Host ""
    Write-Host "  Figuras generadas: $nFigs   Tablas generadas: $nTabs" -ForegroundColor Green
    if ($nFigs -ne 13 -or $nTabs -ne 14) {
        Fallo "Se esperaban 13 figuras y 14 tablas."
    }
}

# -----------------------------------------------------------------------------
# 2. Informe en PDF
# -----------------------------------------------------------------------------
if (-not $SoloPresentacion) {
    Paso "2/3  Informe -> UTEC-Report1.pdf"
    Write-Host "  La primera vez TinyTeX descarga los paquetes LaTeX que falten;" -ForegroundColor DarkGray
    Write-Host "  puede tardar varios minutos. Las siguientes veces es rapido." -ForegroundColor DarkGray
    Write-Host ""

    & $quarto render "UTEC-Report1.qmd"
    if ($LASTEXITCODE -ne 0) { Fallo "El render del informe fallo (mira el mensaje de LaTeX arriba)." }
}

# -----------------------------------------------------------------------------
# 3. Presentacion en HTML
# -----------------------------------------------------------------------------
if (-not $SoloInforme) {
    Paso "3/3  Presentacion -> UTEC-Presentation.html"
    & $quarto render "UTEC-Presentation.qmd"
    if ($LASTEXITCODE -ne 0) { Fallo "El render de la presentacion fallo." }
}

# -----------------------------------------------------------------------------
# Resumen
# -----------------------------------------------------------------------------
Paso "LISTO"
foreach ($f in @("UTEC-Report1.pdf", "UTEC-Presentation.html")) {
    if (Test-Path $f) {
        $mb = [math]::Round((Get-Item $f).Length / 1MB, 2)
        Write-Host ("  {0,-28} {1,6} MB" -f $f, $mb) -ForegroundColor Green
    }
}
Write-Host ""
Write-Host "  Abrelos con:  ii UTEC-Report1.pdf   /   ii UTEC-Presentation.html" -ForegroundColor DarkGray
Write-Host ""
