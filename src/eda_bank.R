# ==============================================================================
# PROYECTO FINAL - ENTREGA P1: EXPLORACION Y PREPROCESAMIENTO
# Dataset: Bank Marketing (bank-additional-full.csv)
# ------------------------------------------------------------------------------
# Implementacion en R del mismo pipeline que src/eda_bank.py. Reproduce las
# tres etapas de la entrega:
#
#     1. Carga y exploracion inicial
#     2. Preprocesamiento (Data Wrangling)
#     3. Analisis Exploratorio de Datos (univariado y multivariado)
#
# Escribe sus resultados en  figs_R/  y  tablas_R/  para no pisar los del
# pipeline de Python y permitir comparar ambas salidas.
#
# Ejecutar desde la raiz del proyecto:   Rscript src/eda_bank.R
# ==============================================================================

library(tidyverse)
library(scales)

# ------------------------------------------------------------------------------
# Ordenar barras dentro de cada panel de un facet exige desambiguar las
# etiquetas repetidas entre paneles. Se definen aqui los dos ayudantes en lugar
# de anadir 'tidytext' como dependencia solo por esto.
# ------------------------------------------------------------------------------
reorder_within <- function(x, by, within, sep = "___") {
  stats::reorder(paste(x, within, sep = sep), by)
}
scale_y_reordered <- function(..., sep = "___") {
  ggplot2::scale_y_discrete(
    labels = function(x) gsub(paste0(sep, ".+$"), "", x), ...)
}

# ------------------------------------------------------------------------------
# CONFIGURACION
# ------------------------------------------------------------------------------
RUTA_DATOS <- "datos/bank-additional-full.csv"
DIR_FIGS   <- "figs_R"
DIR_TABLAS <- "tablas_R"
dir.create(DIR_FIGS,   showWarnings = FALSE)
dir.create(DIR_TABLAS, showWarnings = FALSE)

# Paleta categorica validada: el color sigue a la entidad, no al orden.
C_AZUL    <- "#2a78d6"   # clase "no"
C_NARANJA <- "#eb6834"   # clase "yes"
C_TINTA   <- "#0b0b0b"
C_TINTA2  <- "#52514e"
PAL_Y     <- c("no" = C_AZUL, "yes" = C_NARANJA)

tema_informe <- theme_minimal(base_size = 11) +
  theme(
    plot.title      = element_text(face = "bold", size = 12),
    plot.subtitle   = element_text(colour = C_TINTA2, size = 10),
    axis.title      = element_text(colour = C_TINTA2, size = 10),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(colour = "#e7e6e2", linewidth = 0.3),
    strip.text      = element_text(face = "bold", size = 10),
    legend.position = "top"
  )
theme_set(tema_informe)

guardar <- function(p, nombre, w = 9, h = 5.5) {
  ggsave(file.path(DIR_FIGS, nombre), p, width = w, height = h, dpi = 150)
  cat("   [fig]", nombre, "\n")
}

tabla <- function(d, nombre) {
  readr::write_csv(d, file.path(DIR_TABLAS, nombre))
  cat("   [tbl]", nombre, "\n")
}

seccion <- function(txt) {
  cat("\n", strrep("=", 78), "\n", txt, "\n", strrep("=", 78), "\n", sep = "")
}


# ==============================================================================
# 1. CARGA Y EXPLORACION INICIAL
# ==============================================================================
seccion("1. CARGA Y EXPLORACION INICIAL")

# El archivo usa ';' como separador decimal de campos y comillas en los textos.
crudo <- readr::read_delim(RUTA_DATOS, delim = ";",
                           show_col_types = FALSE, trim_ws = TRUE)

cat("Dimensiones:", nrow(crudo), "filas x", ncol(crudo), "columnas\n")

# --- Estructura: tipo, no nulos y cardinalidad --------------------------------
estructura <- tibble(
  Variable = names(crudo),
  Tipo     = map_chr(crudo, ~ class(.x)[1]),
  No_nulos = map_int(crudo, ~ sum(!is.na(.x))),
  Unicos   = map_int(crudo, ~ dplyr::n_distinct(.x))
)
print(estructura, n = Inf)
tabla(estructura, "tbl_estructura.csv")

# --- Nulos: R tampoco detecta ninguno... --------------------------------------
cat("\nValores NA detectados por R:", sum(is.na(crudo)), "\n")

# --- ...porque el faltante viene codificado como el texto "unknown" -----------
# Hallazgo central del diagnostico: el dataset NO viene limpio; los faltantes
# estan disfrazados de categoria valida y atraviesan sin ruido todo el pipeline.
unk <- crudo |>
  select(where(is.character)) |>
  select(-y) |>
  summarise(across(everything(), ~ sum(.x == "unknown"))) |>
  pivot_longer(everything(), names_to = "Variable", values_to = "n_unknown") |>
  mutate(pct_unknown = round(n_unknown / nrow(crudo) * 100, 2)) |>
  filter(n_unknown > 0) |>
  arrange(desc(n_unknown))

cat("\n'unknown' por columna (nulos encubiertos):\n")
print(unk)
tabla(unk, "tbl_unknown.csv")

# --- Duplicados ---------------------------------------------------------------
n_dup <- sum(duplicated(crudo))
cat("\nFilas duplicadas exactas:", n_dup, "\n")

# --- Balance del target -------------------------------------------------------
balance <- crudo |>
  count(y) |>
  mutate(pct = round(n / sum(n) * 100, 2))
cat("\nTarget y:\n"); print(balance)
TASA_GLOBAL <- mean(crudo$y == "yes") * 100

# --- FIG: nulos encubiertos ---------------------------------------------------
p <- ggplot(unk, aes(x = pct_unknown, y = fct_reorder(Variable, pct_unknown))) +
  geom_col(fill = C_AZUL, width = 0.62) +
  geom_text(aes(label = sprintf("%.2f%%", pct_unknown)),
            hjust = -0.15, size = 3, colour = C_TINTA2) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.18))) +
  labs(title = "Valores faltantes encubiertos como categoria 'unknown'",
       x = "% de registros con valor 'unknown'", y = NULL)
guardar(p, "fig_nulos.png", w = 8, h = 3.6)

# --- FIG: balance del target --------------------------------------------------
p <- ggplot(balance, aes(x = y, y = n, fill = y)) +
  geom_col(width = 0.55, show.legend = FALSE) +
  geom_text(aes(label = sprintf("%s\n(%.2f%%)", comma(n), pct)),
            vjust = -0.25, size = 3.2, colour = C_TINTA2) +
  scale_fill_manual(values = PAL_Y) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.22))) +
  labs(title = "Desbalance de la variable objetivo",
       x = "Suscribio deposito a plazo (y)", y = "N. de clientes")
guardar(p, "fig_target.png", w = 5, h = 4)


# ==============================================================================
# 2. PREPROCESAMIENTO (DATA WRANGLING)
# ==============================================================================
seccion("2. PREPROCESAMIENTO (DATA WRANGLING)")

bitacora <- tibble(Paso = character(), Justificacion = character())
anotar <- function(paso, just) {
  bitacora <<- add_row(bitacora, Paso = paso, Justificacion = just)
}

# --- 2.1 Renombrado -----------------------------------------------------------
# Los puntos de 'emp.var.rate' son el operador de acceso a componentes en R y
# rompen la sintaxis de formulas (y ~ emp.var.rate se interpreta mal).
df <- crudo |>
  rename(
    edad = age, ocupacion = job, estado_civil = marital, educacion = education,
    credito_impago = default, prestamo_vivienda = housing,
    prestamo_personal = loan, tipo_contacto = contact, mes = month,
    dia_semana = day_of_week, duracion = duration,
    n_contactos_campana = campaign, dias_ultimo_contacto = pdays,
    n_contactos_previos = previous, resultado_campana_previa = poutcome,
    var_empleo = `emp.var.rate`, idx_precios = `cons.price.idx`,
    idx_confianza = `cons.conf.idx`, euribor_3m = euribor3m,
    n_empleados = `nr.employed`, suscribio = y
  )
anotar("Renombrado de columnas",
       paste("21 columnas a snake_case en espanol; se eliminan los puntos de",
             "emp.var.rate y similares, que rompen las formulas de R."))

# --- 2.2 Duplicados -----------------------------------------------------------
# Dos llamadas reales no coinciden en las 21 variables: son errores de carga.
n_antes <- nrow(df)
df <- distinct(df)
anotar("Duplicados",
       sprintf(paste("Se eliminan %d filas identicas (%.3f%% del total): dos",
                     "llamadas reales no coinciden en las 21 variables."),
               n_antes - nrow(df), (n_antes - nrow(df)) / n_antes * 100))
cat("Duplicados eliminados:", n_antes - nrow(df), " -> ", nrow(df), "filas\n")

# --- 2.3 'unknown' -> NA explicito --------------------------------------------
cols_unk <- c("ocupacion", "estado_civil", "educacion", "credito_impago",
              "prestamo_vivienda", "prestamo_personal")
df <- df |>
  mutate(across(all_of(cols_unk), ~ na_if(.x, "unknown")))
anotar("Nulos encubiertos",
       paste("'unknown' se convierte a NA en 6 columnas para hacer medible el",
             "faltante antes de decidir su tratamiento."))

# --- 2.4 pdays: el centinela 999 ----------------------------------------------
# 999 NO es "hace 999 dias": codifica "nunca contactado antes". Dejarlo como
# numero envenena la media (962.5 dias) y fabrica una correlacion espuria de
# -0.588 con 'previous' que desaparece al recodificar.
df <- df |>
  mutate(
    contactado_antes     = as.integer(dias_ultimo_contacto != 999),
    dias_ultimo_contacto = if_else(dias_ultimo_contacto == 999,
                                   NA_real_, as.numeric(dias_ultimo_contacto))
  )
anotar("Centinela 999",
       paste("pdays=999 codifica 'nunca contactado'. Se separa en",
             "'contactado_antes' (0/1) y 'dias_ultimo_contacto' (NA si no",
             "aplica); asi la media deja de estar contaminada."))
cat(sprintf("pdays: %d NA (%.2f%%) tras recodificar el 999\n",
            sum(is.na(df$dias_ultimo_contacto)),
            mean(is.na(df$dias_ultimo_contacto)) * 100))

# --- 2.5 credito_impago: variable degenerada ----------------------------------
cat("\ncredito_impago original:\n"); print(table(crudo$default, useNA = "ifany"))
# Solo 3 casos 'yes' en 41,188 (0.007%): ninguna particion permite estimar esa
# categoria. Se conserva unicamente lo que la columna informa de forma fiable.
df <- df |>
  mutate(impago_desconocido = as.integer(is.na(credito_impago))) |>
  select(-credito_impago)
anotar("Variable degenerada",
       paste("credito_impago tiene solo 3 casos 'yes' en 41,188 (0.007%) y",
             "20.87% 'unknown'. Se reemplaza por 'impago_desconocido', que si",
             "discrimina (5.15% vs 12.88% de conversion)."))

# --- 2.6 Imputacion -----------------------------------------------------------
# NO se imputa por moda: el faltante es informativo (educacion 'unknown'
# convierte 14.50% frente al 11.27% global). Imputar destruiria esa senal y
# fabricaria una certeza que el dato no tiene.
df <- df |>
  mutate(across(c(ocupacion, estado_civil, educacion,
                  prestamo_vivienda, prestamo_personal),
                ~ replace_na(.x, "desconocido")))
anotar("Imputacion",
       paste("Se descarta la imputacion por moda: el faltante es informativo",
             "(educacion 'unknown' convierte 14.50% vs 11.27% global). Se",
             "conserva como categoria explicita 'desconocido'."))

# --- 2.7 Tipos de dato --------------------------------------------------------
# educacion, mes y dia_semana tienen orden natural -> factor ORDENADO.
orden_edu <- c("illiterate", "basic.4y", "basic.6y", "basic.9y", "high.school",
               "professional.course", "university.degree", "desconocido")
orden_mes <- c("mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec")

df <- df |>
  mutate(
    educacion  = factor(educacion, levels = orden_edu, ordered = TRUE),
    mes        = factor(mes, levels = orden_mes, ordered = TRUE),
    dia_semana = factor(dia_semana,
                        levels = c("mon", "tue", "wed", "thu", "fri"),
                        ordered = TRUE),
    across(c(ocupacion, estado_civil, tipo_contacto,
             resultado_campana_previa, prestamo_vivienda, prestamo_personal),
           as.factor),
    suscribio     = factor(suscribio, levels = c("no", "yes")),
    suscribio_bin = as.integer(suscribio == "yes")
  )
anotar("Tipos de dato",
       paste("educacion, mes y dia_semana pasan a factor ORDENADO; el resto a",
             "factor nominal; se crea 'suscribio_bin' (0/1) para correlaciones."))

# --- 2.8 Enriquecimiento ------------------------------------------------------
df <- df |>
  mutate(
    # El efecto de la edad es en U: los extremos convierten muy por encima del
    # centro, y la variable continua diluye ese patron no lineal.
    grupo_etario = cut(edad, breaks = c(16, 25, 35, 45, 60, 100),
                       labels = c("17-25", "26-35", "36-45", "46-60", "60+")),
    # Mas de 3 llamadas en la misma campana marca al cliente saturado.
    contacto_intensivo = as.integer(n_contactos_campana > 3),
    # Unidad legible para el area comercial.
    duracion_min  = round(duracion / 60, 2),
    # Aisla la senal mas fuerte del conjunto.
    exito_previo  = as.integer(resultado_campana_previa == "success"),
    # Sintetiza la estacionalidad detectada en 'mes'.
    trimestre = factor(case_when(
      mes %in% c("mar")                 ~ "Q1",
      mes %in% c("apr", "may", "jun")   ~ "Q2",
      mes %in% c("jul", "aug", "sep")   ~ "Q3",
      TRUE                              ~ "Q4"
    ), levels = c("Q1", "Q2", "Q3", "Q4"), ordered = TRUE)
  )
anotar("Enriquecimiento",
       paste("5 variables derivadas: grupo_etario, contacto_intensivo,",
             "duracion_min, exito_previo y trimestre."))

cat("\n--- BITACORA DE PREPROCESAMIENTO ---\n")
walk2(bitacora$Paso, bitacora$Justificacion,
      ~ cat("  *", .x, ":", .y, "\n"))
tabla(bitacora, "tbl_bitacora.csv")

cat("\nDataset final:", nrow(df), "filas x", ncol(df), "columnas\n")
readr::write_csv(df, "datos/bank_limpio_R.csv")

# Conjuntos de columnas para el EDA
NUM <- c("edad", "duracion", "n_contactos_campana", "dias_ultimo_contacto",
         "n_contactos_previos", "var_empleo", "idx_precios", "idx_confianza",
         "euribor_3m", "n_empleados")
CAT <- c("ocupacion", "estado_civil", "educacion", "prestamo_vivienda",
         "prestamo_personal", "tipo_contacto", "mes", "dia_semana",
         "resultado_campana_previa", "grupo_etario")


# ==============================================================================
# 3a. EDA UNIVARIADO
# ==============================================================================
seccion("3a. EDA UNIVARIADO")

# La moda no tiene funcion base en R: se define explicitamente.
moda <- function(x) {
  x <- x[!is.na(x)]
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}
asimetria <- function(x) {
  x <- x[!is.na(x)]; n <- length(x)
  (sum((x - mean(x))^3) / n) / (sum((x - mean(x))^2) / n)^1.5
}
curtosis <- function(x) {
  x <- x[!is.na(x)]; n <- length(x)
  (sum((x - mean(x))^4) / n) / (sum((x - mean(x))^2) / n)^2 - 3
}

# --- Tendencia central y dispersion -------------------------------------------
# Se calculan juntas: una media sin su dispersion no informa sobre su propia
# representatividad.
descriptivos <- map_dfr(NUM, function(v) {
  x <- df[[v]]
  tibble(
    Variable = v, n = sum(!is.na(x)),
    Media = mean(x, na.rm = TRUE), Mediana = median(x, na.rm = TRUE),
    Moda = as.numeric(moda(x)),
    Desv_Est = sd(x, na.rm = TRUE), Varianza = var(x, na.rm = TRUE),
    Min = min(x, na.rm = TRUE),
    Q1 = quantile(x, 0.25, na.rm = TRUE), Q3 = quantile(x, 0.75, na.rm = TRUE),
    Max = max(x, na.rm = TRUE),
    Rango = max(x, na.rm = TRUE) - min(x, na.rm = TRUE),
    RIC = IQR(x, na.rm = TRUE),
    CV_pct = sd(x, na.rm = TRUE) / mean(x, na.rm = TRUE) * 100,
    Asimetria = asimetria(x), Curtosis = curtosis(x)
  )
}) |>
  mutate(across(where(is.numeric), ~ round(.x, 3)))
print(descriptivos, n = Inf, width = Inf)
tabla(descriptivos, "tbl_descriptivos.csv")

# --- Outliers por el criterio de Tukey (1.5 * RIC) ----------------------------
outliers <- map_dfr(NUM, function(v) {
  x   <- df[[v]][!is.na(df[[v]])]
  ric <- IQR(x); q  <- quantile(x, c(0.25, 0.75))
  lo  <- q[1] - 1.5 * ric; hi <- q[2] + 1.5 * ric
  n_o <- sum(x < lo | x > hi)
  tibble(Variable = v, Lim_inf = round(lo, 2), Lim_sup = round(hi, 2),
         N_outliers = n_o, Pct_outliers = round(n_o / length(x) * 100, 2))
})
cat("\nOutliers por criterio de Tukey (1.5*RIC):\n"); print(outliers, n = Inf)
tabla(outliers, "tbl_outliers.csv")

# --- FIG: histogramas ---------------------------------------------------------
largo_num <- df |>
  select(all_of(NUM)) |>
  pivot_longer(everything(), names_to = "Variable", values_to = "Valor") |>
  filter(!is.na(Valor))

resumen_lineas <- largo_num |>
  group_by(Variable) |>
  summarise(Media = mean(Valor), Mediana = median(Valor), .groups = "drop")

p <- ggplot(largo_num, aes(x = Valor)) +
  geom_histogram(bins = 30, fill = C_AZUL, colour = "white", linewidth = 0.2) +
  geom_vline(data = resumen_lineas, aes(xintercept = Media),
             colour = C_NARANJA, linewidth = 0.7) +
  geom_vline(data = resumen_lineas, aes(xintercept = Mediana),
             colour = C_TINTA, linetype = "dashed", linewidth = 0.7) +
  facet_wrap(~ Variable, scales = "free", ncol = 5) +
  scale_y_continuous(labels = comma) +
  labs(title = "Distribucion de frecuencias de las variables numericas",
       subtitle = "Linea naranja: media. Linea discontinua: mediana.",
       x = NULL, y = "Frecuencia")
guardar(p, "fig_histogramas.png", w = 15, h = 6.5)

# --- FIG: boxplots ------------------------------------------------------------
p <- ggplot(largo_num, aes(y = Valor)) +
  geom_boxplot(fill = C_AZUL, alpha = 0.75, colour = C_TINTA2,
               outlier.colour = C_NARANJA, outlier.alpha = 0.3,
               outlier.size = 0.6, width = 0.5) +
  facet_wrap(~ Variable, scales = "free_y", ncol = 5) +
  scale_x_continuous(breaks = NULL) +
  labs(title = "Dispersion y valores atipicos de las variables numericas",
       subtitle = "Criterio de Tukey: 1.5 x rango intercuartilico",
       x = NULL, y = NULL)
guardar(p, "fig_boxplots.png", w = 15, h = 6)

# --- FIG: barras de categoricas -----------------------------------------------
largo_cat <- df |>
  select(all_of(CAT)) |>
  mutate(across(everything(), as.character)) |>
  pivot_longer(everything(), names_to = "Variable", values_to = "Categoria") |>
  count(Variable, Categoria)

p <- ggplot(largo_cat, aes(x = n, y = reorder_within(Categoria, n, Variable))) +
  geom_col(fill = C_AZUL, width = 0.7) +
  facet_wrap(~ Variable, scales = "free", ncol = 5) +
  scale_y_reordered() +
  scale_x_continuous(labels = comma) +
  labs(title = "Frecuencia de las categorias en las variables cualitativas",
       x = "N. de registros", y = NULL)
guardar(p, "fig_barras_cat.png", w = 16, h = 7.5)

# --- Tabla de frecuencias agrupadas (edad) ------------------------------------
frec_edad <- df |>
  mutate(Intervalo = cut(edad, breaks = seq(15, 95, by = 10), right = FALSE)) |>
  count(Intervalo, name = "Frec_Absoluta") |>
  mutate(
    Marca_Clase        = seq(20, 90, by = 10)[seq_len(n())],
    Frec_Acumulada     = cumsum(Frec_Absoluta),
    Frec_Relativa_pct  = round(Frec_Absoluta / sum(Frec_Absoluta) * 100, 2),
    Frec_Rel_Acum_pct  = round(cumsum(Frec_Relativa_pct), 2)
  )
cat("\nTabla de frecuencias agrupadas (edad):\n"); print(frec_edad)
tabla(frec_edad, "tbl_frecuencias_edad.csv")


# ==============================================================================
# 3b. EDA MULTIVARIADO
# ==============================================================================
seccion("3b. EDA MULTIVARIADO")

mat_num <- df |> select(all_of(NUM)) |> as.matrix()

# Pearson mide relacion lineal y es sensible a los extremos; Spearman opera
# sobre rangos y los resiste. Se calculan ambos deliberadamente.
corr_p <- cor(mat_num, use = "pairwise.complete.obs", method = "pearson")
corr_s <- cor(mat_num, use = "pairwise.complete.obs", method = "spearman")
covar  <- cov(mat_num, use = "pairwise.complete.obs")

tabla(as_tibble(round(corr_p, 3), rownames = "Variable"), "tbl_corr_pearson.csv")
tabla(as_tibble(round(corr_s, 3), rownames = "Variable"), "tbl_corr_spearman.csv")
tabla(as_tibble(round(covar, 3),  rownames = "Variable"), "tbl_covarianza.csv")

cat("Matriz de correlacion de Pearson:\n"); print(round(corr_p, 3))

# --- Pares con riesgo de colinealidad -----------------------------------------
colinealidad <- as_tibble(corr_p, rownames = "Variable_A") |>
  pivot_longer(-Variable_A, names_to = "Variable_B", values_to = "Pearson") |>
  filter(Variable_A < Variable_B, abs(Pearson) > 0.5) |>
  arrange(desc(abs(Pearson))) |>
  mutate(Pearson = round(Pearson, 3))
cat("\nPares con |r| > 0.5 (riesgo de colinealidad):\n"); print(colinealidad)
tabla(colinealidad, "tbl_colinealidad.csv")

# --- FIG: heatmap de correlaciones --------------------------------------------
# Escala divergente azul-rojo con punto medio gris neutro: el cero debe leerse
# como "nada", nunca como un color del arcoiris.
heatmap_corr <- function(m, titulo, archivo) {
  d <- as_tibble(m, rownames = "Var1") |>
    pivot_longer(-Var1, names_to = "Var2", values_to = "r") |>
    mutate(Var1 = factor(Var1, levels = NUM),
           Var2 = factor(Var2, levels = rev(NUM))) |>
    filter(as.integer(Var1) + as.integer(Var2) <= length(NUM) + 1)

  p <- ggplot(d, aes(Var1, Var2, fill = r)) +
    geom_tile(colour = "white", linewidth = 1.4) +
    geom_text(aes(label = sprintf("%.2f", r)), size = 2.8, colour = C_TINTA) +
    scale_fill_gradient2(low = "#0d366b", mid = "#f0efec", high = "#8c1c1c",
                         midpoint = 0, limits = c(-1, 1),
                         name = "Coef. de\ncorrelacion") +
    coord_fixed() +
    labs(title = titulo, x = NULL, y = NULL) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
          axis.text.y = element_text(size = 8),
          panel.grid = element_blank(), legend.position = "right")
  guardar(p, archivo, w = 9, h = 7.5)
}
heatmap_corr(corr_p, "Correlacion de Pearson entre variables numericas",
             "fig_corr_pearson.png")
heatmap_corr(corr_s, "Correlacion de Spearman entre variables numericas",
             "fig_corr_spearman.png")

# --- Correlacion de cada numerica con el target -------------------------------
corr_target <- map_dfr(NUM, ~ tibble(
  Variable = .x,
  Correlacion = cor(df[[.x]], df$suscribio_bin,
                    use = "pairwise.complete.obs")
)) |>
  arrange(desc(abs(Correlacion))) |>
  mutate(Correlacion = round(Correlacion, 3))
cat("\nCorrelacion de cada variable numerica con el target:\n")
print(corr_target)
tabla(corr_target, "tbl_corr_target.csv")

p <- ggplot(corr_target,
            aes(x = Correlacion, y = fct_reorder(Variable, abs(Correlacion)),
                fill = Correlacion > 0)) +
  geom_col(width = 0.68, show.legend = FALSE) +
  geom_vline(xintercept = 0, colour = C_TINTA2, linewidth = 0.4) +
  geom_text(aes(label = sprintf("%+.3f", Correlacion),
                hjust = if_else(Correlacion > 0, -0.15, 1.15)),
            size = 2.8, colour = C_TINTA2) +
  scale_fill_manual(values = c("TRUE" = C_NARANJA, "FALSE" = C_AZUL)) +
  scale_x_continuous(limits = c(-0.55, 0.55)) +
  labs(title = "Fuerza y signo de cada variable numerica frente al target",
       x = "Correlacion con la suscripcion (0/1)", y = NULL)
guardar(p, "fig_corr_target.png", w = 8.5, h = 5)

# --- FIG: boxplots comparativos por clase -------------------------------------
comparar <- c("duracion", "edad", "n_contactos_campana", "euribor_3m",
              "n_empleados", "idx_confianza")
p <- df |>
  select(suscribio, all_of(comparar)) |>
  pivot_longer(-suscribio, names_to = "Variable", values_to = "Valor") |>
  filter(!is.na(Valor)) |>
  ggplot(aes(x = suscribio, y = Valor, fill = suscribio)) +
  geom_boxplot(alpha = 0.78, colour = C_TINTA2, outlier.alpha = 0.12,
               outlier.size = 0.5, width = 0.5) +
  facet_wrap(~ Variable, scales = "free_y", ncol = 3) +
  scale_fill_manual(values = PAL_Y, name = "Suscribio") +
  labs(title = "Comparacion de variables numericas segun el resultado",
       x = NULL, y = NULL)
guardar(p, "fig_box_comparativos.png", w = 12, h = 7)

# --- Tasa de conversion por categoria -----------------------------------------
conversion <- map_dfr(CAT, function(v) {
  df |>
    group_by(Categoria = as.character(.data[[v]])) |>
    summarise(N = n(), Tasa_pct = round(mean(suscribio_bin) * 100, 2),
              .groups = "drop") |>
    mutate(Variable = v, .before = 1)
})
cat(sprintf("\nTasa de conversion por categoria (global %.2f%%):\n", TASA_GLOBAL))
print(conversion, n = Inf)
tabla(conversion, "tbl_conversion_categorias.csv")

# --- FIG: conversion en las 4 categoricas mas relevantes ----------------------
clave <- c("resultado_campana_previa", "tipo_contacto", "ocupacion", "grupo_etario")
p <- conversion |>
  filter(Variable %in% clave) |>
  ggplot(aes(x = Tasa_pct, y = reorder_within(Categoria, Tasa_pct, Variable),
             fill = Tasa_pct > TASA_GLOBAL)) +
  geom_col(width = 0.68, show.legend = FALSE) +
  geom_vline(xintercept = TASA_GLOBAL, colour = C_TINTA,
             linetype = "dashed", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.1f%%", Tasa_pct)),
            hjust = -0.12, size = 2.7, colour = C_TINTA2) +
  facet_wrap(~ Variable, scales = "free", ncol = 2) +
  scale_y_reordered() +
  scale_fill_manual(values = c("TRUE" = C_NARANJA, "FALSE" = C_AZUL)) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.22))) +
  labs(title = "Tasa de suscripcion por categoria",
       subtitle = sprintf(paste("Naranja: por encima de la media global de",
                                "%.2f%% (linea discontinua)"), TASA_GLOBAL),
       x = "Tasa de suscripcion (%)", y = NULL)
guardar(p, "fig_conversion_cat.png", w = 12, h = 7.5)

# --- FIG: estacionalidad ------------------------------------------------------
# Dos paneles apilados y NO un doble eje: las unidades (llamadas y porcentaje)
# no son comparables y superponerlas induciria a leer una relacion inexistente.
estacional <- df |>
  group_by(mes) |>
  summarise(Llamadas = n(), Tasa = round(mean(suscribio_bin) * 100, 2),
            .groups = "drop")
print(estacional)
tabla(estacional, "tbl_estacionalidad.csv")

p <- estacional |>
  pivot_longer(c(Llamadas, Tasa), names_to = "Metrica", values_to = "Valor") |>
  mutate(Metrica = factor(Metrica, levels = c("Llamadas", "Tasa"),
                          labels = c("Esfuerzo comercial (n. de llamadas)",
                                     "Efectividad (% de suscripcion)"))) |>
  ggplot(aes(x = mes, y = Valor, fill = Metrica)) +
  geom_col(width = 0.62, show.legend = FALSE) +
  facet_wrap(~ Metrica, ncol = 1, scales = "free_y") +
  scale_fill_manual(values = c(C_AZUL, C_NARANJA)) +
  scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.15))) +
  labs(title = "El esfuerzo comercial se concentra donde la efectividad es minima",
       x = "Mes del ultimo contacto", y = NULL)
guardar(p, "fig_estacionalidad.png", w = 9.5, h = 6.5)

# --- FIG: diagramas de dispersion ---------------------------------------------
# Con 41,176 puntos el solapamiento oculta la densidad: se muestrea y se baja la
# opacidad. El orden de dibujo se aleatoriza para que ninguna clase tape
# sistematicamente a la otra.
set.seed(1234)
muestra <- df |> slice_sample(n = 4000) |> slice_sample(prop = 1)

duplas <- tribble(
  ~x,                     ~y,
  "euribor_3m",           "n_empleados",
  "euribor_3m",           "var_empleo",
  "var_empleo",           "idx_precios",
  "edad",                 "duracion",
  "n_contactos_campana",  "duracion",
  "idx_confianza",        "idx_precios"
)

datos_scatter <- pmap_dfr(duplas, function(x, y) {
  tibble(
    Par = sprintf("%s vs %s  (r = %+.3f)", x, y, corr_p[x, y]),
    vx = muestra[[x]], vy = muestra[[y]], suscribio = muestra$suscribio
  )
})

p <- ggplot(datos_scatter, aes(vx, vy, colour = suscribio)) +
  geom_point(size = 0.7, alpha = 0.35) +
  facet_wrap(~ Par, scales = "free", ncol = 3) +
  scale_colour_manual(values = PAL_Y, name = "Suscribio") +
  guides(colour = guide_legend(override.aes = list(size = 3, alpha = 1))) +
  labs(title = "Relaciones entre pares de variables numericas",
       subtitle = "Muestra aleatoria de n = 4,000 registros",
       x = NULL, y = NULL)
guardar(p, "fig_scatterplots.png", w = 13, h = 7.5)

# --- FIG: duracion, la variable con fuga de informacion ------------------------
tramos <- df |>
  mutate(Tramo = cut(duracion_min, breaks = c(0, 2, 4, 6, 10, 15, Inf),
                     labels = c("0-2", "2-4", "4-6", "6-10", "10-15", "15+"))) |>
  group_by(Tramo) |>
  summarise(Tasa = round(mean(suscribio_bin) * 100, 2), .groups = "drop") |>
  filter(!is.na(Tramo))

p <- ggplot(tramos, aes(x = Tramo, y = Tasa)) +
  geom_col(fill = C_NARANJA, width = 0.62) +
  geom_hline(yintercept = TASA_GLOBAL, colour = C_TINTA,
             linetype = "dashed", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.1f%%", Tasa)),
            vjust = -0.4, size = 3, colour = C_TINTA2) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.16))) +
  labs(title = "La conversion crece de forma monotona con la duracion",
       subtitle = paste("La duracion solo se conoce al terminar la llamada:",
                        "es fuga de informacion y no puede usarse para predecir"),
       x = "Duracion de la llamada (minutos)", y = "Tasa de suscripcion (%)")
guardar(p, "fig_duracion.png", w = 8.5, h = 5)

cat("\nDuracion (minutos) por clase:\n")
print(df |> group_by(suscribio) |>
        summarise(n = n(), Media = round(mean(duracion_min), 2),
                  Mediana = round(median(duracion_min), 2), .groups = "drop"))


# ==============================================================================
# 4. CIFRAS CLAVE
# ==============================================================================
seccion("4. CIFRAS CLAVE")

cifras <- tibble(
  Metrica = c("filas_original", "columnas_original", "filas_final",
              "columnas_final", "duplicados", "tasa_global_pct",
              "pct_unknown_default", "pct_pdays_999",
              "r_euribor_varempleo", "r_euribor_nempleados",
              "r_duracion_target", "conv_poutcome_success"),
  Valor = c(
    nrow(crudo), ncol(crudo), nrow(df), ncol(df), n_dup,
    round(TASA_GLOBAL, 2),
    unk$pct_unknown[unk$Variable == "default"],
    round(mean(df$contactado_antes == 0) * 100, 2),
    round(corr_p["euribor_3m", "var_empleo"], 3),
    round(corr_p["euribor_3m", "n_empleados"], 3),
    round(cor(df$duracion, df$suscribio_bin), 3),
    round(mean(df$suscribio_bin[df$resultado_campana_previa == "success"]) * 100, 2)
  )
)
print(cifras, n = Inf)
tabla(cifras, "tbl_cifras_clave.csv")

cat("\n", strrep("=", 78), "\n", sep = "")
cat("PIPELINE COMPLETADO\n")
cat("  Figuras -> ", DIR_FIGS,   "/\n", sep = "")
cat("  Tablas  -> ", DIR_TABLAS, "/\n", sep = "")
cat(strrep("=", 78), "\n")
