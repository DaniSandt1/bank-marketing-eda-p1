# Entrega P1 — Bank Marketing

**Curso:** Introducción a Ciencia de Datos e Inteligencia Artificial
**Entrega:** P1 — Exploración y Preprocesamiento
**Dataset:** *Bank Marketing* (UCI ML Repository)

---

## 1. Qué contiene este proyecto

Análisis exploratorio y preprocesamiento de las campañas de marketing telefónico
de un banco portugués (2008–2010), con el objetivo de entender qué determina que
un cliente contrate un depósito a plazo fijo.

El dataset utilizado es **`bank-additional-full.csv`**: 41,188 registros y 21
variables. Se eligió esta versión sobre `bank-full.csv` porque incorpora cinco
indicadores macroeconómicos —ausentes en la versión de 2012— que resultan
determinantes: el período analizado coincide con la crisis financiera global.

---

## 2. Estructura del proyecto

```
UTEC-Report/
├── UTEC-Report1.qmd          # Informe principal (Quarto → PDF)
├── UTEC-Presentation.qmd     # Presentación (Quarto → reveal.js HTML)
├── preamble.tex              # Preámbulo LaTeX propio del informe
├── references.bib            # Bibliografía (BibTeX)
│
├── src/
│   ├── eda_bank.py           # Pipeline completo en Python  ← fuente de verdad
│   └── eda_bank.R            # Pipeline equivalente en R
│
├── datos/
│   ├── bank-additional-full.csv   # Dataset original
│   └── bank_limpio.csv            # Salida del preprocesamiento
│
├── figs/                     # 13 figuras generadas por el pipeline
├── tablas/                   # 14 tablas en CSV generadas por el pipeline
│
├── _extensions/              # Plantilla numbats/report (sin modificar)
└── UCTEC-Report.qmd          # Plantilla original del curso (referencia)
```

### Por qué el informe no calcula, sino que lee

Las cifras citadas en el texto del informe **no se escriben a mano**: se leen
desde `tablas/tbl_cifras_clave.csv` mediante la función `v()` definida en el
bloque `setup`. El informe y el análisis no pueden desincronizarse: si el
pipeline se vuelve a ejecutar con otro criterio, el texto se actualiza solo.

---

## 3. Cómo reproducir el análisis

### Requisitos

> **Nada de esto hace falta para ver los documentos.** Están publicados en
> <https://danisandt1.github.io/bank-marketing-eda-p1/> y se regeneran solos en
> cada `push`. Lo de abajo es únicamente para trabajar en local.

| Herramienta | Uso | Necesaria para |
|:---|:---|:---|
| Python ≥ 3.10 | Pipeline principal | Generar figuras y tablas |
| R ≥ 4.2 + RStudio | Pipeline alternativo e informe | Renderizar `.qmd` |
| Quarto | Motor de documentos | Informe y presentación |
| LaTeX (MiKTeX / TinyTeX) | Salida PDF | Solo el informe |

### Dependencias

```bash
# Python
pip install pandas numpy matplotlib seaborn scipy

# R
install.packages(c("tidyverse", "scales", "knitr", "kableExtra"))
```

### Ejecución

```bash
# 1. Generar figuras y tablas (obligatorio antes de renderizar)
python src/eda_bank.py

# 2. Renderizar el informe en PDF
quarto render UTEC-Report1.qmd

# 3. Renderizar la presentación en HTML
quarto render UTEC-Presentation.qmd
```

El pipeline en R es equivalente y escribe en `figs_R/` y `tablas_R/` para
permitir comparar ambas salidas sin sobrescribir nada:

```bash
Rscript src/eda_bank.R
```

> **Importante:** el informe lee de `figs/` y `tablas/`, es decir, de la salida
> de **Python**. Ejecutar solo el script de R no es suficiente para renderizar.

---

## 4. Decisiones de preprocesamiento

Cada decisión quedó registrada en una bitácora durante la ejecución
(`tablas/tbl_bitacora.csv`), que el informe reproduce íntegra.

| Decisión | Justificación |
|:---|:---|
| **No imputar por moda** | El faltante es informativo: quien no declara su educación convierte al 14.50% frente al 11.27% global. Imputar destruiría esa señal y fabricaría certeza inexistente. Se conserva como categoría `desconocido`. |
| **Recodificar `pdays = 999`** | No significa "hace 999 días" sino "nunca contactado" (96.32% de los casos). Se separa en `contactado_antes` (0/1) y el valor real. |
| **Descartar `default`** | Solo 3 casos `yes` entre 41,188 (0.007%). Se sustituye por `impago_desconocido`, que sí discrimina. |
| **Eliminar 12 duplicados** | Dos llamadas reales no coinciden en las 21 variables: son errores de carga. |
| **Conservar los outliers** | Una llamada de 82 minutos no es un error de medición: es exactamente el tipo de conversación que termina en contratación. |
| **5 variables derivadas** | `grupo_etario`, `contacto_intensivo`, `duracion_min`, `exito_previo`, `trimestre`. |

---

## 5. Hallazgos principales

**El dataset no estaba limpio pese a declararse como tal.** `is.na()` devuelve
cero en las 21 columnas, pero existen faltantes en seis variables codificados
como el texto `"unknown"`, un centinela que distorsionaba una media en tres
órdenes de magnitud, y una correlación de -0.588 que era puro artefacto de ese
centinela.

**Desbalance del 11.27%.** Un modelo que prediga "no" siempre acertaría el
88.73% de las veces. La exactitud queda descartada como métrica de evaluación.

**Colinealidad severa entre las macroeconómicas.** `euribor_3m` y `var_empleo`
correlacionan a **r = 0.972**: una explica el 94.5% de la varianza de la otra.
Debe conservarse una sola representante del bloque.

**`duracion` es fuga de información.** Es la variable más correlacionada con el
objetivo (r = +0.405) y no puede usarse: solo se conoce al terminar la llamada,
y la causalidad va al revés —el cliente interesado prolonga la conversación—.
Se excluirá del conjunto de predictores en la Entrega 2.

**El esfuerzo comercial está mal asignado.** Mayo concentra 13,767 llamadas —un
tercio de la campaña— con la peor tasa del año (6.44%), mientras marzo convierte
al 50.55% con 546 llamadas.

**La edad tiene efecto en U.** Los mayores de 60 convierten al 45.5% y los de
17–25 al 21.0%, frente a solo 8.5% en el tramo de 36–45. La correlación lineal
es de +0.030: Pearson no puede ver este patrón.

---

## 6. Estado de verificación

Todo el proyecto se verifica automáticamente en cada `push` mediante GitHub
Actions ([`.github/workflows/render.yml`](.github/workflows/render.yml)), sobre
un Ubuntu limpio y sin depender de lo que haya instalado en la máquina de nadie.

| Componente | Estado |
|:---|:---|
| `src/eda_bank.py` | **Ejecutado.** El workflow falla si no genera exactamente 13 figuras y 14 tablas. Todas fueron además inspeccionadas visualmente. |
| `src/eda_bank.R` | **Ejecutado.** Corre de principio a fin en Ubuntu con R release. |
| `UTEC-Report1.qmd` | **Renderizado a PDF.** 28 páginas, con índice, listado de 13 figuras y 11 tablas, y las 5 citas resueltas por biblatex. |
| `UTEC-Presentation.qmd` | **Renderizado a HTML.** 25 secciones reveal.js, con todos los valores dinámicos de R interpolados. |
| Cifras del informe | **Verificadas.** Provienen de las tablas que genera el pipeline en la misma ejecución que renderiza el documento. |

### Resultados publicados

Cada ejecución correcta publica el informe y la presentación en:

**<https://danisandt1.github.io/bank-marketing-eda-p1/>**

Los artefactos (PDF, HTML, `.tex` intermedio, figuras y tablas) quedan además
descargables desde la pestaña *Actions* del repositorio.

### Problemas encontrados y corregidos durante la verificación

Vale la pena dejarlos registrados, porque son errores que no se manifiestan
hasta que se compila de verdad:

1. **Signo menos Unicode.** El texto usaba U+2212 en lugar del guion ASCII.
   pdfLaTeX con `inputenc` solo conoce Latin-1 y abortaba la compilación. Se
   sustituyeron los 17 casos y se añadieron declaraciones
   `\DeclareUnicodeCharacter` en `preamble.tex` como red de seguridad.
2. **`No counter 'none' defined`.** La única tabla markdown sin caption se
   convertía en `longtable` y, con `lot: true`, Quarto intentaba añadirla a la
   lista de tablas sin contador. Se le dio caption e identificador.
3. **Tabla de covarianzas desbordada.** `scale_down` de kableExtra **no
   funciona sobre `longtable`** y se descarta en silencio; se confirmó
   inspeccionando el `.tex` generado, donde no aparecía ningún `\resizebox`. Lo
   que forzaba el ancho eran los encabezados, así que se abrevian con
   `abbreviate()` de R base, que garantiza unicidad —truncarlos a mano
   colapsaba `n_contactos_campana` y `n_contactos_previos` en la misma cadena.

---

## 7. Para la Entrega 2

1. Excluir `duracion` del conjunto de predictores.
2. Evaluar con precisión, exhaustividad, F1 y AUC — nunca con exactitud.
3. Partición entrenamiento/prueba **estratificada** por la variable objetivo.
4. Considerar remuestreo o ponderación de clases.
5. Preferir modelos basados en árboles, o incorporar `grupo_etario` como factor,
   dado el efecto no lineal de la edad.
6. Conservar una sola variable macroeconómica, o aplicar reducción de
   dimensionalidad sobre el bloque.

---

## 8. Fuente

Moro, S., Cortez, P. y Rita, P. (2014). *A Data-Driven Approach to Predict the
Success of Bank Telemarketing*. Decision Support Systems, 62, 22–31.

Dataset: <https://archive.ics.uci.edu/dataset/222/bank+marketing>
