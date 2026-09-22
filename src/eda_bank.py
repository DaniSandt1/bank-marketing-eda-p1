# -*- coding: utf-8 -*-
"""
================================================================================
PROYECTO FINAL - ENTREGA P1: EXPLORACION Y PREPROCESAMIENTO
Dataset: Bank Marketing (bank-additional-full.csv)
================================================================================
Este script ejecuta el pipeline completo de la Entrega 1:

    1. Carga y exploracion inicial
    2. Preprocesamiento (Data Wrangling)
    3. Analisis Exploratorio de Datos (univariado y multivariado)

Genera todas las figuras en  figs/  y todas las tablas en  tablas/ ,
que luego consume el informe Quarto (UTEC-Report1.qmd).

Ejecutar desde la raiz del proyecto:  python src/eda_bank.py
================================================================================
"""

import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")                # backend sin ventana: solo escribe archivos
import matplotlib.pyplot as plt
import seaborn as sns

# ------------------------------------------------------------------------------
# CONFIGURACION GLOBAL
# ------------------------------------------------------------------------------
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATOS = os.path.join(BASE, "datos", "bank-additional-full.csv")
FIGS = os.path.join(BASE, "figs")
TABLAS = os.path.join(BASE, "tablas")
os.makedirs(FIGS, exist_ok=True)
os.makedirs(TABLAS, exist_ok=True)

# Paleta categorica validada (orden fijo, nunca ciclado).
# Slot 1 = azul, slot 2 = naranja: las dos clases del target.
C_AZUL, C_NARANJA, C_AQUA = "#2a78d6", "#eb6834", "#1baf7a"
C_TINTA, C_TINTA2 = "#0b0b0b", "#52514e"
PAL_Y = {"no": C_AZUL, "yes": C_NARANJA}      # el color sigue a la entidad

plt.rcParams.update({
    "figure.dpi": 130, "savefig.dpi": 130, "savefig.bbox": "tight",
    "font.size": 9, "axes.titlesize": 10, "axes.titleweight": "bold",
    "axes.labelsize": 9, "axes.edgecolor": "#c9c8c3", "axes.linewidth": 0.8,
    "axes.grid": True, "grid.color": "#e7e6e2", "grid.linewidth": 0.6,
    "axes.axisbelow": True, "axes.spines.top": False, "axes.spines.right": False,
    "text.color": C_TINTA, "axes.labelcolor": C_TINTA2, "xtick.color": C_TINTA2,
    "ytick.color": C_TINTA2, "figure.facecolor": "white", "axes.facecolor": "white",
})


def guardar(fig, nombre):
    """Escribe la figura y cierra el handle para no acumular memoria."""
    fig.savefig(os.path.join(FIGS, nombre))
    plt.close(fig)
    print("   [fig] " + nombre)


def tabla(dfr, nombre, index=True):
    """Exporta una tabla a CSV para que el informe Quarto la lea con kable()."""
    dfr.to_csv(os.path.join(TABLAS, nombre), index=index, encoding="utf-8")
    print("   [tbl] " + nombre)


def seccion(txt):
    print("\n" + "=" * 78)
    print(txt)
    print("=" * 78)


# ==============================================================================
# 1. CARGA Y EXPLORACION INICIAL
# ==============================================================================
seccion("1. CARGA Y EXPLORACION INICIAL")

# El archivo usa ';' como separador y comillas en los campos de texto.
df = pd.read_csv(DATOS, sep=";")
crudo = df.copy()                     # se conserva el crudo para comparar despues

print("Dimensiones: {} filas x {} columnas".format(df.shape[0], df.shape[1]))

# --- Estructura del dataset: tipo, no nulos, cardinalidad ---------------------
estructura = pd.DataFrame({
    "Tipo": df.dtypes.astype(str),
    "No_nulos": df.notna().sum(),
    "Unicos": df.nunique(),
})
print(estructura)
tabla(estructura, "tbl_estructura.csv")

# --- Nulos: pandas no detecta ninguno... --------------------------------------
print("\nValores NaN detectados por pandas: {}".format(df.isna().sum().sum()))

# --- ...pero 'unknown' es un nulo codificado como texto -----------------------
# Hallazgo central del diagnostico: el dataset NO viene limpio, viene con los
# faltantes disfrazados de categoria valida.
cats = df.select_dtypes(include="object").columns.drop("y")
unk = pd.DataFrame(
    {"n_unknown": [(df[c] == "unknown").sum() for c in cats]}, index=cats)
unk["pct_unknown"] = (unk["n_unknown"] / len(df) * 100).round(2)
unk = unk[unk.n_unknown > 0].sort_values("n_unknown", ascending=False)
print("\n'unknown' por columna (nulos encubiertos):")
print(unk)
tabla(unk, "tbl_unknown.csv")

# --- Duplicados ---------------------------------------------------------------
n_dup = int(df.duplicated().sum())
print("\nFilas duplicadas exactas: {}".format(n_dup))

# --- Balance del target -------------------------------------------------------
bal = df["y"].value_counts()
bal_pct = df["y"].value_counts(normalize=True).mul(100).round(2)
print("\nTarget y:")
print(pd.concat([bal, bal_pct], axis=1, keys=["n", "pct"]))
TASA_GLOBAL = (df["y"] == "yes").mean() * 100

# --- FIG: mapa de nulos encubiertos ------------------------------------------
fig, ax = plt.subplots(figsize=(7.2, 3.2))
b = ax.barh(unk.index[::-1], unk["pct_unknown"][::-1], color=C_AZUL, height=0.62)
ax.bar_label(b, fmt="%.2f%%", padding=3, fontsize=8, color=C_TINTA2)
ax.set_xlabel("% de registros con valor 'unknown'")
ax.set_title("Valores faltantes encubiertos como categoria 'unknown'")
ax.set_xlim(0, float(unk["pct_unknown"].max()) * 1.25)
ax.grid(axis="y", visible=False)
guardar(fig, "fig_nulos.png")

# --- FIG: balance del target --------------------------------------------------
fig, ax = plt.subplots(figsize=(4.6, 3.2))
b = ax.bar(["no", "yes"], [bal["no"], bal["yes"]],
           color=[C_AZUL, C_NARANJA], width=0.55)
ax.bar_label(b, labels=["{:,}\n({}%)".format(bal["no"], bal_pct["no"]),
                        "{:,}\n({}%)".format(bal["yes"], bal_pct["yes"])],
             padding=3, fontsize=8.5, color=C_TINTA2)
ax.set_ylabel("N. de clientes")
ax.set_xlabel("Suscribio deposito a plazo (y)")
ax.set_title("Desbalance de la variable objetivo")
ax.set_ylim(0, bal["no"] * 1.22)
ax.grid(axis="x", visible=False)
guardar(fig, "fig_target.png")


# ==============================================================================
# 2. PREPROCESAMIENTO (DATA WRANGLING)
# ==============================================================================
seccion("2. PREPROCESAMIENTO (DATA WRANGLING)")

log = []   # bitacora: cada decision queda registrada y justificada

# --- 2.1 Nombres de columnas --------------------------------------------------
# Los puntos de 'emp.var.rate' rompen la sintaxis de formulas en R. Se normaliza
# a snake_case y se traduce a nombres autoexplicativos en el idioma del informe.
renombres = {
    "age": "edad", "job": "ocupacion", "marital": "estado_civil",
    "education": "educacion", "default": "credito_impago",
    "housing": "prestamo_vivienda", "loan": "prestamo_personal",
    "contact": "tipo_contacto", "month": "mes", "day_of_week": "dia_semana",
    "duration": "duracion", "campaign": "n_contactos_campana",
    "pdays": "dias_ultimo_contacto", "previous": "n_contactos_previos",
    "poutcome": "resultado_campana_previa", "emp.var.rate": "var_empleo",
    "cons.price.idx": "idx_precios", "cons.conf.idx": "idx_confianza",
    "euribor3m": "euribor_3m", "nr.employed": "n_empleados", "y": "suscribio",
}
df = df.rename(columns=renombres)
log.append(("Renombrado de columnas",
            "21 columnas a snake_case en espanol; se eliminan los puntos de "
            "emp.var.rate y similares, que rompen las formulas de R."))

# --- 2.2 Duplicados -----------------------------------------------------------
# 12 filas identicas en las 21 columnas. Siendo registros de llamadas
# individuales, dos llamadas no pueden coincidir en absolutamente todo:
# son errores de carga, no clientes distintos. Se eliminan.
antes = len(df)
df = df.drop_duplicates().reset_index(drop=True)
log.append(("Duplicados",
            "Se eliminan {} filas identicas ({:.3f}% del total): dos llamadas "
            "reales no coinciden en las 21 variables.".format(
                antes - len(df), (antes - len(df)) / antes * 100)))
print("Duplicados eliminados: {}  ->  {} filas".format(antes - len(df), len(df)))

# --- 2.3 'unknown' -> NaN explicito -------------------------------------------
# Primero se hace visible el faltante; la decision de que hacer con el se toma
# columna por columna mas abajo.
for c in ["ocupacion", "estado_civil", "educacion", "credito_impago",
          "prestamo_vivienda", "prestamo_personal"]:
    df[c] = df[c].replace("unknown", np.nan)
log.append(("Nulos encubiertos",
            "'unknown' se convierte a NaN en 6 columnas para hacer medible el "
            "faltante antes de decidir su tratamiento."))

# --- 2.4 pdays: el centinela 999 ---------------------------------------------
# 999 NO significa "hace 999 dias": es el codigo de "nunca contactado antes".
# Dejarlo como numero envenena la media (962.5 dias) y cualquier distancia.
# Se separa en un indicador booleano y el valor real.
df["contactado_antes"] = (df["dias_ultimo_contacto"] != 999).astype(int)
df["dias_ultimo_contacto"] = df["dias_ultimo_contacto"].replace(999, np.nan)
log.append(("Centinela 999",
            "pdays=999 codifica 'nunca contactado'. Se separa en "
            "'contactado_antes' (0/1) y 'dias_ultimo_contacto' (NaN si no aplica); "
            "asi la media deja de estar contaminada."))
print("pdays: {} NaN ({:.2f}%) tras recodificar el 999".format(
    df["dias_ultimo_contacto"].isna().sum(),
    df["dias_ultimo_contacto"].isna().mean() * 100))

# --- 2.5 credito_impago: variable casi degenerada -----------------------------
print("\ncredito_impago original: {}".format(dict(crudo["default"].value_counts())))
# 3 casos 'yes' en 41,188 registros (0.007%). Una categoria con 3 observaciones
# no permite estimar nada, y ademas el 20.87% es 'unknown'. Se binariza en
# "declara no tener impago" vs "no lo declara", que es lo que de verdad separa.
df["impago_desconocido"] = df["credito_impago"].isna().astype(int)
df = df.drop(columns=["credito_impago"])
log.append(("Variable degenerada",
            "credito_impago tiene solo 3 casos 'yes' en 41,188 (0.007%) y 20.87% "
            "'unknown'. Se reemplaza por 'impago_desconocido', que si discrimina "
            "(5.15% vs 12.88% de conversion)."))

# --- 2.6 Imputacion del resto de faltantes ------------------------------------
# Criterio: NO imputar por moda. Aqui el 'unknown' es informativo (quien no
# declara su educacion convierte al 14.50%, por encima del 11.27% global).
# Imputar por moda destruiria esa senal y fabricaria una certeza que el dato
# no tiene. Se mantiene como categoria propia.
for c in ["ocupacion", "estado_civil", "educacion",
          "prestamo_vivienda", "prestamo_personal"]:
    df[c] = df[c].fillna("desconocido")
log.append(("Imputacion",
            "Se descarta la imputacion por moda: el faltante es informativo "
            "(educacion 'unknown' convierte 14.50% vs 11.27% global). Se conserva "
            "como categoria explicita 'desconocido'."))

# --- 2.7 Tipos de datos -------------------------------------------------------
# educacion, mes y dia_semana tienen orden natural -> factor ordenado.
orden_edu = ["illiterate", "basic.4y", "basic.6y", "basic.9y", "high.school",
             "professional.course", "university.degree", "desconocido"]
df["educacion"] = pd.Categorical(df["educacion"], categories=orden_edu, ordered=True)
orden_mes = ["mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
df["mes"] = pd.Categorical(df["mes"], categories=orden_mes, ordered=True)
df["dia_semana"] = pd.Categorical(
    df["dia_semana"], categories=["mon", "tue", "wed", "thu", "fri"], ordered=True)
for c in ["ocupacion", "estado_civil", "tipo_contacto", "resultado_campana_previa",
          "prestamo_vivienda", "prestamo_personal"]:
    df[c] = df[c].astype("category")
df["suscribio_bin"] = (df["suscribio"] == "yes").astype(int)
log.append(("Tipos de dato",
            "educacion, mes y dia_semana pasan a factor ORDENADO; el resto a "
            "factor nominal; se crea 'suscribio_bin' (0/1) para correlaciones."))

# --- 2.8 Enriquecimiento: variables nuevas ------------------------------------
# a) Grupo etario: convierte una continua en segmentos de lectura comercial.
df["grupo_etario"] = pd.cut(df["edad"], bins=[16, 25, 35, 45, 60, 100],
                            labels=["17-25", "26-35", "36-45", "46-60", "60+"])
# b) Intensidad de contacto: mas de 3 llamadas en la campana = cliente saturado.
df["contacto_intensivo"] = (df["n_contactos_campana"] > 3).astype(int)
# c) Duracion en minutos: unidad legible para el negocio.
df["duracion_min"] = (df["duracion"] / 60).round(2)
# d) Exito previo: aisla el 'success' de poutcome, la senal mas fuerte del set.
df["exito_previo"] = (df["resultado_campana_previa"] == "success").astype(int)
# e) Trimestre: agrupa la estacionalidad detectada en 'mes'.
tri = {"mar": "Q1", "apr": "Q2", "may": "Q2", "jun": "Q2", "jul": "Q3",
       "aug": "Q3", "sep": "Q3", "oct": "Q4", "nov": "Q4", "dec": "Q4"}
df["trimestre"] = pd.Categorical(df["mes"].astype(str).map(tri),
                                 categories=["Q1", "Q2", "Q3", "Q4"], ordered=True)
log.append(("Enriquecimiento",
            "5 variables derivadas: grupo_etario, contacto_intensivo, "
            "duracion_min, exito_previo y trimestre."))

print("\n--- BITACORA DE PREPROCESAMIENTO ---")
bit = pd.DataFrame(log, columns=["Paso", "Decision y justificacion"])
for _, r in bit.iterrows():
    print("  * {}: {}".format(r["Paso"], r["Decision y justificacion"]))
tabla(bit, "tbl_bitacora.csv", index=False)
print("\nDataset final: {} filas x {} columnas".format(df.shape[0], df.shape[1]))

df.to_csv(os.path.join(BASE, "datos", "bank_limpio.csv"),
          index=False, encoding="utf-8")
print("Guardado: datos/bank_limpio.csv")

# Conjuntos de columnas para el EDA
NUM = ["edad", "duracion", "n_contactos_campana", "dias_ultimo_contacto",
       "n_contactos_previos", "var_empleo", "idx_precios", "idx_confianza",
       "euribor_3m", "n_empleados"]
CAT = ["ocupacion", "estado_civil", "educacion", "prestamo_vivienda",
       "prestamo_personal", "tipo_contacto", "mes", "dia_semana",
       "resultado_campana_previa", "grupo_etario"]


# ==============================================================================
# 3a. ANALISIS EXPLORATORIO - UNIVARIADO
# ==============================================================================
seccion("3a. EDA UNIVARIADO")

# --- Medidas de tendencia central y dispersion --------------------------------
# Se calculan juntas porque solo tienen lectura combinada: una media sin su
# desviacion no dice nada sobre si es representativa.
filas = []
for c in NUM:
    s = df[c].dropna()
    moda = s.mode()
    filas.append({
        "Variable": c, "n": len(s),
        "Media": s.mean(), "Mediana": s.median(),
        "Moda": moda.iloc[0] if len(moda) else np.nan,
        "Desv_Est": s.std(), "Varianza": s.var(),
        "Min": s.min(), "Q1": s.quantile(.25), "Q3": s.quantile(.75), "Max": s.max(),
        "Rango": s.max() - s.min(), "RIC": s.quantile(.75) - s.quantile(.25),
        "CV_pct": s.std() / s.mean() * 100 if s.mean() != 0 else np.nan,
        "Asimetria": s.skew(), "Curtosis": s.kurt(),
    })
desc = pd.DataFrame(filas).set_index("Variable").round(3)
print(desc.to_string())
tabla(desc, "tbl_descriptivos.csv")

# Deteccion de outliers por el criterio de Tukey (1.5 * RIC)
out = []
for c in NUM:
    s = df[c].dropna()
    q1, q3 = s.quantile(.25), s.quantile(.75)
    ric = q3 - q1
    lo, hi = q1 - 1.5 * ric, q3 + 1.5 * ric
    n_out = int(((s < lo) | (s > hi)).sum())
    out.append({"Variable": c, "Lim_inf": round(lo, 2), "Lim_sup": round(hi, 2),
                "N_outliers": n_out, "Pct_outliers": round(n_out / len(s) * 100, 2)})
outl = pd.DataFrame(out).set_index("Variable")
print("\nOutliers por criterio de Tukey (1.5*RIC):")
print(outl.to_string())
tabla(outl, "tbl_outliers.csv")

# --- FIG: histogramas de todas las numericas ---------------------------------
fig, axes = plt.subplots(2, 5, figsize=(15, 6))
for ax, c in zip(axes.ravel(), NUM):
    s = df[c].dropna()
    ax.hist(s, bins=30, color=C_AZUL, edgecolor="white", linewidth=0.5)
    ax.axvline(s.mean(), color=C_NARANJA, lw=2, label="Media")
    ax.axvline(s.median(), color=C_TINTA, lw=2, ls="--", label="Mediana")
    ax.set_title(c, fontsize=9)
    ax.tick_params(labelsize=7.5)
    ax.grid(axis="x", visible=False)
axes.ravel()[0].legend(fontsize=7, frameon=False)
fig.suptitle("Distribucion de frecuencias de las variables numericas",
             fontsize=12, fontweight="bold", y=1.0)
fig.tight_layout()
guardar(fig, "fig_histogramas.png")

# --- FIG: boxplots de todas las numericas ------------------------------------
fig, axes = plt.subplots(2, 5, figsize=(15, 5.6))
for ax, c in zip(axes.ravel(), NUM):
    bp = ax.boxplot(df[c].dropna(), vert=True, widths=0.45, patch_artist=True,
                    flierprops=dict(marker="o", markersize=2.2,
                                    markerfacecolor=C_NARANJA,
                                    markeredgecolor="none", alpha=0.35),
                    medianprops=dict(color=C_TINTA, lw=1.6),
                    boxprops=dict(facecolor=C_AZUL, alpha=0.75, edgecolor=C_AZUL),
                    whiskerprops=dict(color=C_TINTA2), capprops=dict(color=C_TINTA2))
    ax.set_title(c, fontsize=9)
    ax.set_xticks([])
    ax.tick_params(labelsize=7.5)
    ax.grid(axis="x", visible=False)
fig.suptitle("Dispersion y valores atipicos de las variables numericas",
             fontsize=12, fontweight="bold", y=1.0)
fig.tight_layout()
guardar(fig, "fig_boxplots.png")

# --- FIG: barras de las categoricas ------------------------------------------
fig, axes = plt.subplots(2, 5, figsize=(16, 7))
for ax, c in zip(axes.ravel(), CAT):
    vc = df[c].value_counts().sort_values(ascending=True)
    ax.barh(vc.index.astype(str), vc.values, color=C_AZUL, height=0.7)
    ax.set_title(c, fontsize=9)
    ax.tick_params(labelsize=7)
    ax.grid(axis="y", visible=False)
fig.suptitle("Frecuencia de las categorias en las variables cualitativas",
             fontsize=12, fontweight="bold", y=1.0)
fig.tight_layout()
guardar(fig, "fig_barras_cat.png")

# --- Tabla de frecuencias agrupadas (exigida por la plantilla) ---------------
# Se agrupa la edad en intervalos de 10 anios.
cortes = list(range(15, 105, 10))
grp = pd.cut(df["edad"], bins=cortes, right=False)
frec = grp.value_counts().sort_index().to_frame("Frec_Absoluta")
frec["Marca_Clase"] = [(i.left + i.right) / 2 for i in frec.index]
frec["Frec_Acumulada"] = frec["Frec_Absoluta"].cumsum()
frec["Frec_Relativa_pct"] = (frec["Frec_Absoluta"] / frec["Frec_Absoluta"].sum() * 100).round(2)
frec["Frec_Rel_Acum_pct"] = frec["Frec_Relativa_pct"].cumsum().round(2)
frec.index = frec.index.astype(str)
print("\nTabla de frecuencias agrupadas (edad):")
print(frec.to_string())
tabla(frec, "tbl_frecuencias_edad.csv")


# ==============================================================================
# 3b. ANALISIS EXPLORATORIO - MULTIVARIADO
# ==============================================================================
seccion("3b. EDA MULTIVARIADO")

# --- Correlacion de Pearson (lineal) y Spearman (monotona) -------------------
# Se calculan ambas: Pearson asume relacion lineal; Spearman solo monotonia y
# es robusta a los outliers que el boxplot dejo en evidencia.
corr_p = df[NUM].corr(method="pearson")
corr_s = df[NUM].corr(method="spearman")
cov = df[NUM].cov()
tabla(corr_p.round(3), "tbl_corr_pearson.csv")
tabla(corr_s.round(3), "tbl_corr_spearman.csv")
tabla(cov.round(3), "tbl_covarianza.csv")

print("Matriz de correlacion de Pearson:")
print(corr_p.round(3).to_string())

# Pares con colinealidad problematica
pares = []
for i in range(len(NUM)):
    for j in range(i + 1, len(NUM)):
        r = corr_p.iloc[i, j]
        if abs(r) > 0.5:
            pares.append({"Variable_A": NUM[i], "Variable_B": NUM[j],
                          "Pearson": round(r, 3),
                          "Spearman": round(corr_s.iloc[i, j], 3),
                          "Covarianza": round(cov.iloc[i, j], 3)})
colin = pd.DataFrame(pares).sort_values("Pearson", key=abs, ascending=False)
print("\nPares con |r| > 0.5 (riesgo de colinealidad):")
print(colin.to_string(index=False))
tabla(colin, "tbl_colinealidad.csv", index=False)


def heatmap_corr(mat, titulo, archivo):
    """Heatmap divergente azul-rojo con punto medio gris neutro."""
    fig, ax = plt.subplots(figsize=(8.4, 6.8))
    mask = np.triu(np.ones_like(mat, dtype=bool), k=1)   # solo triangulo inferior
    sns.heatmap(mat, mask=mask, cmap="RdBu_r", center=0, vmin=-1, vmax=1,
                annot=True, fmt=".2f", annot_kws={"size": 7.5},
                linewidths=2, linecolor="white", square=True, ax=ax,
                cbar_kws={"shrink": 0.7, "label": "Coeficiente de correlacion"})
    ax.set_title(titulo, fontsize=11, fontweight="bold", pad=12)
    ax.tick_params(labelsize=8)
    plt.setp(ax.get_xticklabels(), rotation=45, ha="right")
    fig.tight_layout()
    guardar(fig, archivo)


heatmap_corr(corr_p, "Correlacion de Pearson entre variables numericas",
             "fig_corr_pearson.png")
heatmap_corr(corr_s, "Correlacion de Spearman entre variables numericas",
             "fig_corr_spearman.png")

# --- Correlacion de cada numerica con el target ------------------------------
corr_y = df[NUM].corrwith(df["suscribio_bin"]).sort_values(key=abs, ascending=False)
print("\nCorrelacion de cada variable numerica con el target:")
print(corr_y.round(3).to_string())
tabla(corr_y.round(3).to_frame("Correlacion_con_target"), "tbl_corr_target.csv")

fig, ax = plt.subplots(figsize=(7.4, 4.2))
colores = [C_NARANJA if v > 0 else C_AZUL for v in corr_y.values[::-1]]
b = ax.barh(corr_y.index[::-1], corr_y.values[::-1], color=colores, height=0.68)
ax.bar_label(b, fmt="%+.3f", padding=3, fontsize=7.5, color=C_TINTA2)
ax.axvline(0, color=C_TINTA2, lw=0.9)
ax.set_xlabel("Correlacion con la suscripcion (0/1)")
ax.set_title("Fuerza y signo de cada variable numerica frente al target")
ax.set_xlim(-0.5, 0.5)
ax.grid(axis="y", visible=False)
guardar(fig, "fig_corr_target.png")

# --- FIG: boxplots comparativos por clase del target -------------------------
comp = ["duracion", "edad", "n_contactos_campana", "euribor_3m",
        "n_empleados", "idx_confianza"]
fig, axes = plt.subplots(2, 3, figsize=(12, 6.4))
for ax, c in zip(axes.ravel(), comp):
    datos = [df.loc[df.suscribio == k, c].dropna() for k in ["no", "yes"]]
    bp = ax.boxplot(datos, tick_labels=["no", "yes"], widths=0.5, patch_artist=True,
                    flierprops=dict(marker="o", markersize=2,
                                    markerfacecolor=C_TINTA2,
                                    markeredgecolor="none", alpha=0.2),
                    medianprops=dict(color=C_TINTA, lw=1.7),
                    whiskerprops=dict(color=C_TINTA2), capprops=dict(color=C_TINTA2))
    for parche, k in zip(bp["boxes"], ["no", "yes"]):
        parche.set_facecolor(PAL_Y[k])
        parche.set_alpha(0.78)
        parche.set_edgecolor(PAL_Y[k])
    ax.set_title(c, fontsize=9)
    ax.set_xlabel("suscribio")
    ax.tick_params(labelsize=7.5)
    ax.grid(axis="x", visible=False)
fig.suptitle("Comparacion de variables numericas entre quienes suscriben y quienes no",
             fontsize=12, fontweight="bold", y=1.0)
fig.tight_layout()
guardar(fig, "fig_box_comparativos.png")

# --- Tasa de conversion por categoria ----------------------------------------
conv_all = []
for c in CAT:
    g = df.groupby(c, observed=True)["suscribio_bin"].agg(["size", "mean"])
    g["Tasa_pct"] = (g["mean"] * 100).round(2)
    g = g.rename(columns={"size": "N"}).drop(columns="mean")
    g.insert(0, "Variable", c)
    g.index.name = "Categoria"
    conv_all.append(g.reset_index())
conv_tab = pd.concat(conv_all, ignore_index=True)
tabla(conv_tab, "tbl_conversion_categorias.csv", index=False)
print("\nTasa de conversion por categoria (global {:.2f}%):".format(TASA_GLOBAL))
print(conv_tab.to_string(index=False))

# --- FIG: barras agrupadas de conversion en las 4 categoricas mas relevantes --
clave = ["resultado_campana_previa", "tipo_contacto", "ocupacion", "grupo_etario"]
fig, axes = plt.subplots(2, 2, figsize=(12, 7))
for ax, c in zip(axes.ravel(), clave):
    g = df.groupby(c, observed=True)["suscribio_bin"].mean().mul(100).sort_values()
    cols = [C_NARANJA if v > TASA_GLOBAL else C_AZUL for v in g.values]
    b = ax.barh(g.index.astype(str), g.values, color=cols, height=0.68)
    # La linea de la media global va detras; las etiquetas llevan halo blanco
    # para que ninguna quede cortada por ella.
    ax.axvline(TASA_GLOBAL, color=C_TINTA, ls="--", lw=1.2, zorder=1)
    for t in ax.bar_label(b, fmt="%.1f%%", padding=3, fontsize=7.5, color=C_TINTA2):
        t.set_zorder(5)
        t.set_bbox(dict(facecolor="white", edgecolor="none", pad=0.6, alpha=0.9))
    ax.set_title(c, fontsize=9.5)
    ax.set_xlabel("Tasa de suscripcion (%)", fontsize=8)
    ax.set_xlim(0, max(g.values) * 1.22)
    ax.tick_params(labelsize=8)
    ax.grid(axis="y", visible=False)
axes.ravel()[0].annotate(
    "media global {:.2f}%".format(TASA_GLOBAL),
    xy=(TASA_GLOBAL, 2.42), xytext=(TASA_GLOBAL + 6, 2.42),
    fontsize=7.5, color=C_TINTA2, va="center",
    arrowprops=dict(arrowstyle="-", color=C_TINTA2, lw=0.7))
fig.suptitle("Tasa de suscripcion por categoria (naranja = sobre la media global)",
             fontsize=12, fontweight="bold", y=1.0)
fig.tight_layout()
guardar(fig, "fig_conversion_cat.png")

# --- FIG: estacionalidad - volumen frente a efectividad ----------------------
# Dos paneles apilados, NO un doble eje: las unidades no son comparables y
# superponerlas en una sola escala induce a leer una relacion que no existe.
g = df.groupby("mes", observed=True).agg(
    N=("suscribio_bin", "size"), Tasa=("suscribio_bin", "mean"))
g["Tasa"] = g["Tasa"] * 100
tabla(g.round(2), "tbl_estacionalidad.csv")

fig, (a1, a2) = plt.subplots(2, 1, figsize=(9, 6), sharex=True,
                             gridspec_kw={"hspace": 0.18})
b1 = a1.bar(g.index.astype(str), g["N"], color=C_AZUL, width=0.62)
a1.bar_label(b1, fmt="%d", padding=2, fontsize=7.5, color=C_TINTA2)
a1.set_ylabel("Llamadas realizadas")
a1.set_title("Esfuerzo comercial por mes", fontsize=10)
a1.set_ylim(0, g["N"].max() * 1.18)
a1.grid(axis="x", visible=False)

b2 = a2.bar(g.index.astype(str), g["Tasa"], color=C_NARANJA, width=0.62)
# La linea de referencia va por debajo de las etiquetas y estas llevan un halo
# blanco: de lo contrario el valor de julio queda pisado por la linea punteada.
a2.axhline(TASA_GLOBAL, color=C_TINTA, ls="--", lw=1.2, zorder=1)
et = a2.bar_label(b2, fmt="%.1f%%", padding=2, fontsize=7.5, color=C_TINTA2)
for t in et:
    t.set_zorder(5)
    t.set_bbox(dict(facecolor="white", edgecolor="none", pad=0.6, alpha=0.85))
a2.set_ylabel("Tasa de suscripcion (%)")
a2.set_xlabel("Mes del ultimo contacto")
a2.set_title("Efectividad por mes", fontsize=10)
a2.set_ylim(0, g["Tasa"].max() * 1.2)
a2.grid(axis="x", visible=False)
fig.suptitle("El esfuerzo comercial se concentra donde la efectividad es minima",
             fontsize=12, fontweight="bold", y=0.99)
guardar(fig, "fig_estacionalidad.png")

# --- FIG: seis diagramas de dispersion ---------------------------------------
# Con 41,176 puntos el solapamiento oculta la densidad: se toma una muestra
# aleatoria y se baja la opacidad para que el patron sea legible.
rng = np.random.default_rng(1234)
idx = rng.choice(len(df), size=4000, replace=False)
m = df.iloc[idx]

duplas = [("euribor_3m", "n_empleados"), ("euribor_3m", "var_empleo"),
          ("var_empleo", "idx_precios"), ("edad", "duracion"),
          ("n_contactos_campana", "duracion"), ("idx_confianza", "idx_precios")]

# El orden de dibujo se aleatoriza: si se pintara una clase despues de la otra,
# la segunda taparia sistematicamente a la primera en las zonas densas y el
# grafico sugeriria una prevalencia que no existe.
m = m.sample(frac=1.0, random_state=7)
colores_pt = m["suscribio"].map(PAL_Y).values

fig, axes = plt.subplots(2, 3, figsize=(13, 7.4))
for ax, (x, y) in zip(axes.ravel(), duplas):
    ax.scatter(m[x], m[y], s=10, alpha=0.35, c=colores_pt,
               edgecolors="none", linewidths=0)
    r = df[[x, y]].corr().iloc[0, 1]
    ax.set_xlabel(x)
    ax.set_ylabel(y)
    ax.set_title("{} vs {}  (r = {:+.3f})".format(x, y, r), fontsize=9)
    ax.tick_params(labelsize=7.5)

marcas = [plt.Line2D([], [], marker="o", ls="", markersize=7,
                     markerfacecolor=PAL_Y[k], markeredgecolor="none", label=k)
          for k in ["no", "yes"]]
fig.legend(handles=marcas, title="suscribio", loc="lower center", ncol=2,
           frameon=False, fontsize=9, title_fontsize=9,
           bbox_to_anchor=(0.5, -0.005))
fig.suptitle("Relaciones entre pares de variables numericas (muestra n = 4,000)",
             fontsize=12, fontweight="bold")
fig.tight_layout(rect=(0, 0.045, 1, 0.965))
guardar(fig, "fig_scatterplots.png")

# --- FIG: duracion, la variable con fuga de informacion -----------------------
fig, (a1, a2) = plt.subplots(1, 2, figsize=(11, 4.1))
for k in ["no", "yes"]:
    a1.hist(df.loc[df.suscribio == k, "duracion_min"], bins=60, range=(0, 20),
            alpha=0.62, color=PAL_Y[k], label=k, edgecolor="white", linewidth=0.3)
a1.set_xlabel("Duracion de la llamada (minutos)")
a1.set_ylabel("N. de llamadas")
a1.set_title("Distribucion de la duracion segun el resultado", fontsize=9.5)
a1.legend(title="suscribio", frameon=False, fontsize=8)
a1.grid(axis="x", visible=False)

corte = pd.cut(df["duracion_min"], bins=[0, 2, 4, 6, 10, 15, 100],
               labels=["0-2", "2-4", "4-6", "6-10", "10-15", "15+"])
gg = df.groupby(corte, observed=True)["suscribio_bin"].mean().mul(100)
b = a2.bar(gg.index.astype(str), gg.values, color=C_NARANJA, width=0.62)
a2.bar_label(b, fmt="%.1f%%", padding=2, fontsize=8, color=C_TINTA2)
a2.axhline(TASA_GLOBAL, color=C_TINTA, ls="--", lw=1.2)
a2.set_xlabel("Duracion de la llamada (minutos)")
a2.set_ylabel("Tasa de suscripcion (%)")
a2.set_title("La conversion crece de forma monotona con la duracion", fontsize=9.5)
a2.set_ylim(0, max(gg.values) * 1.2)
a2.grid(axis="x", visible=False)
fig.tight_layout()
guardar(fig, "fig_duracion.png")

print("\nDuracion media por clase (minutos):")
print(df.groupby("suscribio", observed=True)["duracion_min"].describe().round(2).to_string())
print("\nTasa de suscripcion por tramo de duracion:")
print(gg.round(2).to_string())


# ==============================================================================
# 4. RESUMEN DE CIFRAS PARA EL INFORME
# ==============================================================================
seccion("4. CIFRAS CLAVE")

clave_vals = {
    "filas_original": len(crudo),
    "columnas_original": crudo.shape[1],
    "filas_final": len(df),
    "columnas_final": df.shape[1],
    "duplicados": n_dup,
    "tasa_global_pct": round(TASA_GLOBAL, 2),
    "pct_unknown_default": float(unk.loc["default", "pct_unknown"]),
    "pct_pdays_999": round(df["contactado_antes"].eq(0).mean() * 100, 2),
    "r_euribor_varempleo": round(corr_p.loc["euribor_3m", "var_empleo"], 3),
    "r_euribor_nempleados": round(corr_p.loc["euribor_3m", "n_empleados"], 3),
    "r_duracion_target": round(corr_y["duracion"], 3),
    "conv_poutcome_success": round(
        df.loc[df.resultado_campana_previa == "success", "suscribio_bin"].mean() * 100, 2),
    "conv_cellular": round(
        df.loc[df.tipo_contacto == "cellular", "suscribio_bin"].mean() * 100, 2),
    "conv_telephone": round(
        df.loc[df.tipo_contacto == "telephone", "suscribio_bin"].mean() * 100, 2),
    "conv_may": round(g.loc["may", "Tasa"], 2) if "may" in g.index else np.nan,
    "conv_mar": round(g.loc["mar", "Tasa"], 2) if "mar" in g.index else np.nan,
    "n_may": int(g.loc["may", "N"]) if "may" in g.index else np.nan,
}
kv = pd.Series(clave_vals).to_frame("Valor")
print(kv.to_string())
tabla(kv, "tbl_cifras_clave.csv")

print("\n" + "=" * 78)
print("PIPELINE COMPLETADO")
print("  Figuras -> figs/     ({} archivos)".format(len(os.listdir(FIGS))))
print("  Tablas  -> tablas/   ({} archivos)".format(len(os.listdir(TABLAS))))
print("=" * 78)
