# Registro de la sesión: selección de interacciones, diagnóstico y validación en `code/fit2.R`

Todo el código nuevo está en `code/fit2.R`, desde la línea 98. El script necesita que `main.R` se haya ejecutado antes, porque usa `bike_data`.

## 0. Resumen en una página

1. El screening de 45 interacciones por pares se ordena por **F_stat** y no por p-valor. Con ~8.400 observaciones casi todo sale significativo, y el F ya divide por los grados de libertad.
2. Se preseleccionan las candidatas con **F ≥ 50** (8 interacciones) y se agregan a mano `hour:temp` y `hour:solar_rad`, que el corte dejaba fuera por tener muchos gl.
3. Una **selección hacia adelante** (entra la candidata con mayor F si su p < 0.05) agrega 8 términos y deja el modelo final `m_fwd`, con 96 coeficientes (87 estimables, ver nota en la sección 5).
4. `drop1` y un test F anidado confirman que **todos los términos aportan**, incluidos los de `hour`.
5. La **validación cruzada por bloques de días** muestra que **no hay evidencia de sobreajuste relevante**: la brecha entre el error de entrenamiento y el de CV es de ~2.4-3.3% en RMSE, y se mantiene con 10 semillas distintas (sección 7).
6. Frente a los modelos de `fit.R`, `m_fwd` tiene el menor error de CV, con menos parámetros que `m_3int`.
7. Para la pregunta secundaria (efecto de la temperatura), el modelo tiene 4 interacciones con `temp`, así que **no existe un único efecto**: depende de la estación, la hora, la radiación solar y el feriado (sección 9).
8. **Diagnósticos (sección 10):** no hay un patrón fuerte en los residuos. Hay una curvatura moderada de la temperatura dentro de verano, y las observaciones más influyentes son horas de lluvia, cuyo efecto es sensible a pocas observaciones.
9. **Autocorrelación (sección 11):** los residuos tienen una autocorrelación de 0.64 en el rezago 1. El supuesto de independencia no se cumple del todo, y se plantea como limitación.

## 1. Qué hace cada parte de `fit2.R`

| Líneas | Sección | Qué hace |
|---|---|---|
| 1-96 | Modelos base | Poisson, binomial negativa y quasi-Poisson. Elige quasi-Poisson por sobredispersión y deja `m_qpois` (sin `visibility`) como modelo base. Es la misma sección de `fit.R`. |
| 98-121 | Screening | Ajusta `m_qpois` más cada una de las 45 interacciones por pares, calcula el test F contra la base y ordena la tabla por `F_stat`. |
| 123-141 | Candidatas | Se queda con las de `F_stat ≥ umbral_F` (50) y agrega a mano `hour:temp` y `hour:solar_rad`. Imprime la tabla `tabla_F0` con el F de cada candidata contra la base. |
| 143-174 | Selección hacia adelante | Parte de `m_qpois` y agrega de a una la candidata con mayor F, recalculado contra el modelo actual. Se detiene cuando la mejor tiene p ≥ 0.05. Guarda `m_fwd` y la tabla `pasos`. |
| 176-180 | `drop1` | Test F al quitar cada término de `m_fwd`: verifica que todos sigan aportando. |
| 182-216 | Diagnóstico de residuos | Panel 2×2 con A (residuos contra η̂), B (residuos contra `temp`), C (distancia de Cook) y D (ACF). |
| 218-240 | Gráfico A2 | Figura aparte: residuos promedio por bins de η̂ (30 bins de igual tamaño, con ±2 EE). |
| 242-268 | Influyentes | Top 10 por distancia de Cook y reajuste sin ellas para medir la sensibilidad de los coeficientes. |
| 270-end | Validación cruzada por bloques | Compara base y `m_fwd` con `k_pliegues` pliegues de días completos y semilla `semilla_cv`. Calcula RMSE y MAE en train y CV, y las brechas. |

Detalle de la selección hacia adelante:
- `add1(m_act, scope = restantes, test = "F")` prueba cada candidata restante contra el modelo actual.
- La de mayor F entra solo si `p < 0.05`. Si no lo cumple, se detiene todo el proceso. No se usa ningún criterio de información.
- El F se recalcula en cada vuelta, por lo que depende de qué otros términos ya están en el modelo.

## 2. Por qué mirar los grados de libertad

Cada interacción cuesta una cantidad distinta de parámetros: `temp:humidity` agrega 1, `hour:holiday` 23 y `hour:seasons` 69. La reducción de devianza (`Red_Dev_Pct`) siempre favorece a las que tienen más parámetros. El F divide por los gl extra y por φ̂, y permite comparar.

## 3. Screening ordenado por F_stat (contra el modelo base)

| Interacción | gl | F |
|---|---|---|
| `temp:seasons` | 3 | 754.6 |
| `temp:solar_rad` | 1 | 750.1 |
| `solar_rad:seasons` | 3 | 221.2 |
| `humidity:rain` | 1 | 178.2 |
| `humidity:seasons` | 3 | 105.9 |
| `solar_rad:rain` | 1 | 90.3 |
| `temp:rain` | 1 | 61.4 |
| `temp:holiday` | 1 | 53.5 |
| `temp:humidity` | 1 | 38.3 |
| `hour:temp` | 23 | 35.8 |
| `hour:solar_rad` | 14 | 18.1 |
| `hour:weekday` | 138 | 14.2 |
| `hour:seasons` | 69 | 13.0 |
| `hour:holiday` | 23 | 6.2 |

- No hay un salto claro en los valores, así que `umbral_F = 50` es una decisión del análisis.
- Todas las interacciones con `hour` tienen p < 0.05, pero cuestan muchos gl.
- `hour:solar_rad` figura con 14 gl y no 23, porque la radiación es 0 de noche y varios coeficientes no son estimables (en `m_fwd` hay 9 coeficientes NA).

## 4. Candidatas

`umbral_F = 50` deja 8 interacciones. Se agregan a mano `hour:temp` y `hour:solar_rad`. La lista se arma con `unique(...)` para que se pueda ejecutar varias veces sin duplicar términos (antes, `c(candidatas, ...)` acumulaba repeticiones).

Total: **10 candidatas**.

## 5. Selección hacia adelante

| Paso | Agregada | gl | F | p |
|---|---|---|---|---|
| 0 | base | | | |
| 1 | `temp:seasons` | 3 | 744.8 | 0 |
| 2 | `humidity:rain` | 1 | 253.9 | 2.4e-56 |
| 3 | `temp:solar_rad` | 1 | 252.5 | 4.7e-56 |
| 4 | `temp:holiday` | 1 | 72.0 | 2.5e-17 |
| 5 | `solar_rad:rain` | 1 | 39.4 | 3.7e-10 |
| 6 | `hour:temp` | 23 | 30.8 | 6.0e-129 |
| 7 | `solar_rad:seasons` | 3 | 18.7 | 4.3e-12 |
| 8 | `hour:solar_rad` | 14 | 6.0 | 5.7e-12 |

El modelo final es `m_fwd`: φ̂ ≈ 68.8 y 96 coeficientes, de los cuales 9 no son estimables (`NA`, en `hour:solar_rad`, porque la radiación es 0 de noche). Los coeficientes efectivamente estimados son 87 (`m_fwd$rank`). Las columnas "Parámetros" de las tablas siguientes usan `length(coef())` y cuentan esos `NA`.

**Por qué no entraron `humidity:seasons` ni `temp:rain`** (no fueron "eliminadas", la selección solo agrega y se detuvo antes). Probadas contra el modelo final:

| Término | gl | F | p |
|---|---|---|---|
| `humidity:seasons` | 3 | 1.27 | 0.28 |
| `temp:rain` | 1 | 3.29 | 0.070 |

Ninguno cumple p < 0.05. Con `hour:temp` ya en el modelo, la temperatura queda mayormente explicada y esos términos aportan poco. En la corrida con solo 8 candidatas sí habían entrado (con F = 23.7 y 5.2). El F de un término depende de qué otros están presentes.

Además, `solar_rad:seasons` tenía F = 221 en el screening y 3.7 en la primera corrida, y ahora entra con F = 18.7. El screening marginal sobreestima interacciones redundantes.

## 6. ¿Aporta cada término? (`drop1(m_fwd, test = "F")`)

| Término | gl | F | p |
|---|---|---|---|
| `temp:seasons` | 3 | 701.3 | < 2e-16 |
| `humidity:rain` | 1 | 170.0 | < 2e-16 |
| `temp:solar_rad` | 1 | 101.2 | < 2e-16 |
| `temp:holiday` | 1 | 83.5 | < 2e-16 |
| `solar_rad:rain` | 1 | 43.6 | 4.3e-11 |
| `hour:temp` | 23 | 20.1 | < 2e-16 |
| `solar_rad:seasons` | 3 | 20.0 | 6.6e-13 |
| `hour:solar_rad` | 14 | 6.0 | 5.7e-12 |

Todos los términos aportan. `drop1` no prueba los efectos principales contenidos en una interacción, para respetar la jerarquía.

**Test F anidado** de `m_fwd` contra `m_fwd` sin `hour:temp` ni `hour:solar_rad`: F = 23.4, 37 gl, p < 2e-16. Las interacciones con `hour` aportan de forma significativa.

## 7. Validación cruzada por bloques de días

La validación cruzada reajusta el mismo modelo con (k−1)/k de los **días** y predice el resto, que el modelo no vio. Se repite k veces. No se necesita una muestra de prueba aparte: los mismos datos hacen turnos como entrenamiento y como prueba. Los pliegues son **días completos**, porque las 24 horas de un día se parecen y un reparto aleatorio de filas subestimaría el error.

**Parámetros editables** (líneas 278-279 de `fit2.R`, al inicio de la sección):

```r
semilla_cv <- 123   # semilla del reparto de días en pliegues
k_pliegues <- 10    # número de pliegues
```

Cambiando esos dos valores se obtiene otro reparto o más pliegues, sin tocar el resto del código.

Definiciones:
- **MAE:** promedio del error absoluto, en número de bicicletas.
- **RMSE:** raíz del error cuadrático medio; castiga más los errores grandes.
- **Train:** error en los mismos datos con que se ajustó el modelo (optimista).
- **CV:** error en días que el modelo no vio.
- **Brecha:** CV − train. Si hubiera sobreajuste, sería grande.

**Con `semilla_cv = 123`:**

| Modelo | Parámetros | RMSE train | RMSE CV | Brecha RMSE | % | MAE train | MAE CV | Brecha MAE | % |
|---|---|---|---|---|---|---|---|---|---|
| Base | 40 | 312.08 | 318.41 | 6.33 | 2.0% | 207.25 | 212.42 | 5.17 | 2.5% |
| Final (`m_fwd`) | 96 | 243.96 | 249.74 | 5.78 | 2.4% | 157.96 | 162.47 | 4.51 | 2.9% |

**Con 10 semillas distintas** (123, 1, 2, 3, 4, 5, 42, 100, 2024, 777; 10 pliegues cada una):

| Semilla | Base: RMSE CV | Final: RMSE CV | Final: brecha RMSE | Final: MAE CV | Final: brecha MAE |
|---|---|---|---|---|---|
| 123 | 318.41 | 249.74 | 2.4% | 162.47 | 2.9% |
| 1 | 316.86 | 250.08 | 2.5% | 162.58 | 2.9% |
| 2 | 317.99 | 251.72 | 3.2% | 163.18 | 3.3% |
| 3 | 318.43 | 250.45 | 2.7% | 161.98 | 2.5% |
| 4 | 320.80 | 250.67 | 2.8% | 162.64 | 3.0% |
| 5 | 320.67 | 250.51 | 2.7% | 162.37 | 2.8% |
| 42 | 320.03 | 252.13 | 3.3% | 163.32 | 3.4% |
| 100 | 318.63 | 251.42 | 3.1% | 163.52 | 3.5% |
| 2024 | 319.87 | 250.67 | 2.7% | 162.83 | 3.1% |
| 777 | 319.76 | 251.38 | 3.0% | 163.06 | 3.2% |

Resumen:

| | RMSE CV | Brecha RMSE | MAE CV | Brecha MAE |
|---|---|---|---|---|
| **Base** | media 319.1, sd 1.3, rango [316.9, 320.8] | media 2.3% [1.5, 2.8] | media 212.4 [211.1, 213.4] | media 2.5% |
| **Final (`m_fwd`)** | media **250.9**, sd 0.8, rango [249.7, 252.1] | media **2.8%** [2.4, 3.3] | media **162.8** [162.0, 163.5] | media **3.1%** |

**Lectura:**
- El resultado casi no depende del reparto: el RMSE del modelo final solo varía entre 249.7 y 252.1.
- La diferencia con la base (~68 puntos de RMSE, ~21%) es unas 80 veces mayor que la variación entre semillas.
- La brecha del modelo final es de 2.4% a 3.3% en RMSE, similar a la de la base (2.3% en promedio). La complejidad extra no abre una brecha grande.
- Conclusión prudente: **no hay evidencia de sobreajuste relevante**.

**Limitaciones de esta conclusión:**
- La selección de interacciones (screening y selección hacia adelante) se hizo con todos los datos y el CV no la repite en cada pliegue (CV anidado). El error de validación podría ser algo optimista.
- Los días de prueba pueden quedar junto a días de entrenamiento, y los días vecinos se parecen.
- Solo se mide el error promedio, no si el modelo falla en zonas específicas (por ejemplo, las horas con lluvia, sección 10).

## 8. Comparación con los modelos de `fit.R`

Misma semilla (123) y mismos pliegues por días.

| Modelo | Parámetros | RMSE train | RMSE CV | MAE train | MAE CV |
|---|---|---|---|---|---|
| Base | 40 | 312.08 | 318.41 | 207.25 | 212.42 |
| `fit.R`: `m_int_temp_seas` | 43 | 264.74 | 268.79 | 174.45 | 178.17 |
| `fit.R`: `m_3int` | 135 | 249.23 | 254.27 | 162.02 | 166.68 |
| `fit2`: `m_fwd` sin términos `hour` | 50 | 257.08 | 262.24 | 167.25 | 171.73 |
| **`fit2`: `m_fwd`** | **96** | **243.96** | **249.74** | **157.96** | **162.47** |

- `m_fwd` tiene el menor error, con menos parámetros que `m_3int` (96 frente a 135). La mejora es de ~1.8% en RMSE y ~2.5% en MAE. Es pequeña, y comparable con la variación entre semillas (sd de 0.8 en el RMSE del modelo final), así que no es una diferencia sólida por sí sola.
- Lo claro es que los modelos con interacciones de `hour` son mejores que los que no las tienen.
- Los rótulos "37 param" y "129 param" de `fit.R` están desactualizados: el conteo real es 43 y 135 (los 6 niveles de `weekday` agregados después).

## 9. Pregunta secundaria: efecto de la temperatura

> *¿Qué efecto tiene la temperatura sobre la cantidad de bicicletas arrendadas por hora, manteniendo constantes las demás variables explicativas?*

**Consecuencia del modelo:** `temp` participa en 4 interacciones (`temp:seasons`, `temp:solar_rad`, `temp:holiday`, `hour:temp`). Por eso **no hay un único coeficiente de temperatura**: el efecto de +1 °C depende de la estación, la hora, la radiación solar y si es feriado. La respuesta es una tabla de efectos condicionales, no un número.

Razón de tasas (IRR) por +1 °C, con IC 95% de Wald. Se calcula como el cambio en el predictor lineal al subir `temp` en 1 °C, promediado sobre las observaciones de cada grupo y con la matriz de covarianza del modelo. Excluye los días feriados salvo en la última fila.

| Grupo | n | IRR (+1 °C) | IC 95% | Cambio |
|---|---|---|---|---|
| Primavera | 2088 | 1.051 | [1.049, 1.053] | +5.1% |
| Invierno | 1968 | 1.050 | [1.044, 1.055] | +5.0% |
| Otoño | 1841 | 1.028 | [1.026, 1.030] | +2.8% |
| **Verano** | 2160 | **0.965** | [0.963, 0.968] | **−3.5%** |
| Madrugada (0-5 h) | 2010 | 1.027 | [1.024, 1.030] | +2.7% |
| Mañana (6-11 h) | 2015 | 1.010 | [1.008, 1.013] | +1.0% |
| Tarde (12-17 h) | 2016 | 1.013 | [1.011, 1.016] | +1.3% |
| Noche (18-23 h) | 2016 | 1.037 | [1.034, 1.039] | +3.7% |
| Días no feriados | 8057 | 1.022 | [1.020, 1.024] | +2.2% |
| Días feriados | 408 | 1.052 | [1.048, 1.057] | +5.2% |
| **Global (todos los datos)** | 8465 | **1.023** | [1.022, 1.025] | **+2.3%** |

Lectura:
- En promedio, +1 °C se asocia a ~2.3% más arriendos por hora, con el resto de variables fijas.
- **En verano el efecto se invierte** (−3.5% por °C): con calor alto, más temperatura reduce los arriendos. En el resto del año, sube.
- El efecto es mayor de noche y madrugada que a media mañana o por la tarde.
- Estas filas son efectos condicionales: no se pueden sumar ni promediar a ojo.

Reservas:
- Los IC de Wald no consideran la **autocorrelación** de los datos horarios (sección 11) ni la **incertidumbre de la selección** de términos. Son más estrechos de lo que corresponde.
- **Curvatura en verano** (sección 10): los residuos sugieren que en verano el efecto no es lineal en la escala logarítmica. El modelo lo aproxima con una recta.
- Esto es una asociación observacional, no un efecto causal.
- Estos cálculos están en un script temporal; **no están en `fit2.R`**.

## 10. Diagnóstico de residuos e influyentes (sobre `m_fwd`)

### 10.1 Cómo se calculan y qué miran los gráficos

- **Residuo de devianza estandarizado:** uno por cada hora. Se calcula la contribución de esa observación a la devianza, `d = 2·[y·ln(y/μ̂) − (y − μ̂)]`, se le pone el signo de `y − μ̂` y se estandariza dividiendo por `√(φ̂·(1 − h))` (`rstandard(m_fwd, type = "deviance")`). Corrige que la varianza crezca con la media y compensa el leverage `h`.
- **A (residuos contra η̂):** busca error sistemático según el nivel de la predicción (línea naranja) y forma de embudo (supuesto de varianza). Las bandas rojas en ±3 marcan observaciones muy mal explicadas: con residuos aproximadamente normales, ~0.3% debería quedar fuera.
- **B (residuos contra temperatura):** cada punto es una hora, con su temperatura y su residuo del modelo completo (que ya usó todas las covariables). Pregunta si lo que el modelo no explica todavía depende de la temperatura.
- **C (distancia de Cook):** combina el tamaño del residuo y el leverage de cada observación.
- **D (ACF):** ver sección 11.
- En el código, el panel 2×2 es A, B, C, D. El A2 sale como figura aparte.

### 10.2 Residuos contra η̂ (A y A2)

En A hay pocos puntos con η̂ bajo, y es difícil ver una tendencia. El **A2** agrupa los datos en 30 bins de ~282 observaciones y grafica el promedio de residuos de cada bin con ±2 EE.

| Zona | Promedio de residuos | Lectura |
|---|---|---|
| Bin más a la izquierda (η̂ de 1.9 a 4.05) | **+0.23** (EE = 0.035) | El único que se separa claramente de 0 |
| Resto de la zona baja y media | ~0 | Sin tendencia |
| η̂ de 5 a 6.5 | −0.05 a −0.23 | Ligera inclinación negativa |
| Derecha | cerca de 0, con una caída final (−0.14) | Dentro del ruido |

- Hay una ligera subida a la izquierda (el modelo subestima algo en horas de baja demanda), pero es pequeña: 0.23 desviaciones estándar, frente a residuos individuales que van de −6 a +6.
- No hay forma de embudo ni curva grande.
- Las barras de error son optimistas por la autocorrelación.

### 10.3 Residuos contra temperatura (B)

- La correlación entre el residuo y la temperatura es **−0.004**. No es casualidad: la ecuación de estimación fuerza que la suma de `(y − μ̂)·temp` sea 0 (comprobado: −0.0004). Por construcción no queda una tendencia **lineal**, así que el gráfico B solo puede detectar **curvatura**.
- Residuo promedio en 20 tramos de temperatura (~420 observaciones cada uno): casi todos entre −0.2 y +0.14. 9 de los 20 caen fuera de ±2 EE, con desviaciones pequeñas. El tramo más caluroso (30.9 a 39.4 °C) tiene el promedio más negativo: **−0.33** (el modelo sobreestima en calor extremo).
- Separado por estación, en 4 tramos de temperatura dentro de cada una:

| Estación | Tramo 1 | Tramo 2 | Tramo 3 | Tramo 4 |
|---|---|---|---|---|
| Otoño | −0.20 | +0.01 | −0.05 | −0.05 |
| Primavera | −0.18 | −0.09 | −0.01 | −0.07 |
| **Verano** | **−0.33** (16-23 °C) | +0.09 (23-27 °C) | **+0.25** (27-30 °C) | **−0.25** (30-39 °C) |
| Invierno | −0.03 | +0.03 | 0.00 | −0.05 |

- Otoño, primavera e invierno quedan cerca de 0. **Verano muestra una forma de U invertida** (con valores de ±0.25 a 0.33): el efecto de la temperatura parece subir hasta ~28 °C y bajar después, y el modelo lo aproxima con una recta.
- La magnitud es moderada, pero es una limitación a mencionar. El gráfico global B no la muestra porque las estaciones se compensan.

### 10.4 Distancia de Cook y observaciones influyentes

Las 10 observaciones con mayor distancia de Cook (`order(cooks_d, decreasing = TRUE)[1:10]`; `order()` devuelve las posiciones que ordenan el vector, no recibe el modelo porque `cooks_d` ya se calculó con `cooks.distance(m_fwd)`):

| Fecha | Hora | Observado | Predicho | Lluvia (mm) | Humedad | Radiación | Leverage |
|---|---|---|---|---|---|---|---|
| 28/07/2018 | 14 | 314 | 933 | 0.2 | 65 | 1.75 | 0.234 |
| 22/04/2018 | 15 | 234 | 1021 | 0.2 | 44 | 0.47 | 0.142 |
| 15/08/2018 | 18 | 925 | 1910 | 0.1 | 63 | 0.89 | 0.156 |
| 30/08/2018 | 19 | 1707 | 569 | 0.5 | 74 | 0.00 | 0.026 |
| 30/06/2018 | 13 | 1144 | 275 | 3.5 | 87 | 0.71 | 0.018 |
| 03/07/2018 | 19 | 2598 | 1815 | 0.1 | 62 | 0.65 | 0.114 |
| 09/08/2018 | 18 | 1850 | 493 | 0.5 | 86 | 0.28 | 0.010 |
| 09/06/2018 | 20 | 246 | 859 | 0.4 | 62 | 0.00 | 0.070 |
| 23/08/2018 | 20 | 257 | 850 | 0.1 | 62 | 0.00 | 0.072 |
| 13/06/2018 | 15 | 2288 | 1137 | 0 (sin lluvia) | 50 | 0.47 | 0.027 |

**Por qué aparecen estas observaciones:**
1. **9 de 10 son horas con lluvia, y la mayoría son lloviznas (0.1 a 0.5 mm).** El modelo solo sabe "llovió: sí/no" (`rain = rainfall > 0` en `main.R`) y trata igual una llovizna que un aguacero. Residuo promedio en horas lluviosas de verano según la intensidad:

| Lluvia | n | Residuo promedio |
|---|---|---|
| ≤ 0.5 mm | 81 | **+0.44** (el modelo subestima) |
| 0.5 a 2 mm | 55 | −0.27 |
| 2 a 5 mm | 30 | −0.42 |
| > 5 mm | 31 | **−0.86** (el modelo sobreestima) |

2. **Leverage alto en combinaciones raras.** El leverage medio es 0.0103 (= p/n). Cuatro de estas filas tienen entre 0.11 y 0.23 (10 a 20 veces el promedio). Las horas con lluvia son solo **516 de 8.465 (6.1%)**, y las interacciones `humidity:rain` y `solar_rad:rain` las subdividen todavía más.

Esto es en parte un **desequilibrio de los datos** (lluvia es una categoría rara) y en parte una **simplificación de la variable** (sí/no en vez de milímetros).

**Sensibilidad:** al reajustar el modelo sin esas 10 observaciones:

| Coeficiente | Diferencia (log) | Cambio relativo |
|---|---|---|
| `rainYes` | 0.4725 | +60% |
| `hour13:solar_rad` | 0.1313 | +14% |
| `hour19:solar_rad` | 0.1303 | +14% |
| `hour18:solar_rad` | 0.1301 | +14% |
| `hour6:solar_rad` | 0.1289 | +14% |

- φ̂ pasa de 68.81 a 67.54.
- **El coeficiente de `rain` es muy inestable:** cambia un 60% al quitar el 0.1% de los datos. `rainYes` es el efecto de la lluvia con humedad y radiación en 0, así que no se lee directamente, pero la inestabilidad es clara.
- Corrección en el código: `max(dif_coef)` devolvía `NA` por los 9 coeficientes no estimables. Se usa `max(dif_coef, na.rm = TRUE)`, y los textos ahora usan `length(top_influyentes)`. Además se imprime la tabla de los 5 coeficientes que más cambian.

**Qué hacer con ellas:**
- **No eliminarlas.** Son datos reales y plausibles.
- **Dejarlas y reportar la sensibilidad**, como limitación: el efecto de la lluvia se estima con pocos datos y es sensible a unas pocas horas.
- Opción que probablemente más ayude: usar la lluvia en milímetros o por categorías de intensidad (llovizna, moderada, fuerte). Cambiaría `main.R` y el modelo final, y habría que coordinarlo.
- Otra comprobación posible: ver si `humidity:rain` y `solar_rad:rain` siguen siendo significativas al quitar las 10 observaciones.

## 11. Autocorrelación temporal de los residuos

**Qué mide el ACF (gráfico D):** la correlación entre el residuo de una hora y el de las horas vecinas. `acf()` no sabe que son horas: supone que el orden del vector es el orden del tiempo. `bike_data` está ordenado cronológicamente (comprobado con fecha y hora). Por tener eliminados los días sin servicio, no todos los pares consecutivos están separados por 1 hora: de las filas consecutivas, 8.452 están a 1 hora y 12 tienen saltos de 8, 25 o 49 horas, lo que es despreciable. El rezago 24 compara cada hora con la misma hora del día siguiente.

| Modelo | lag 1 | lag 2 | lag 3 | lag 6 | lag 12 | lag 24 | lag 48 |
|---|---|---|---|---|---|---|---|
| Base | 0.74 | 0.58 | 0.47 | 0.18 | 0.23 | 0.40 | 0.25 |
| `m_fwd` | 0.64 | 0.43 | 0.29 | −0.02 | 0.22 | 0.19 | −0.02 |

(Banda de ruido aproximada bajo independencia: ±0.02.)

- Mejoró respecto de la base, pero el rezago 1 sigue en 0.64.
- Los valores positivos en los rezagos 12 y 24 (~0.2) sugieren que hay **días enteros** que el modelo predice sistemáticamente alto o bajo: algo a nivel de día que no está en las covariables.

**Consecuencias:**
- Las **estimaciones puntuales** y las **predicciones** siguen siendo razonables si la forma de la media es adecuada. El CV por días las respalda.
- Los **errores estándar, los IC y los p-valores son demasiado optimistas**, y los tests F de la selección también (tienden a aceptar más términos de los debidos).

**Alternativas evaluadas (fuera de alcance del curso, que asume independencia):**

| Opción | Resultado |
|---|---|
| Errores estándar robustos por día (`sandwich`) | No se calculó (paquete no instalado). Corrige errores estándar e IC sin cambiar los coeficientes |
| Modelo con el conteo de la hora anterior | El ACF en el rezago 1 baja a 0.20 y φ̂ de 68.8 a 22.9, pero el coeficiente del rezago es 0.81 y el coeficiente principal de `temp` pasa de 0.055 a 0.004. El rezago absorbe el efecto del clima y cambia el significado del modelo. No sirve para la pregunta sobre la temperatura |
| GEE AR(1), modelos mixtos | Requieren paquetes no disponibles y se salen del alcance |

**Decisión:** se declara como **limitación**: se muestra el ACF, se dice que el supuesto de independencia no se cumple del todo y se explican las consecuencias (inferencia optimista, predicción razonable).

Párrafo base para el informe:

> Los residuos del modelo final presentan autocorrelación temporal (ACF de 0.64 en el rezago 1), lo que viola el supuesto de independencia del GLM. Esto es esperable en datos horarios consecutivos. La consecuencia es que los errores estándar, intervalos y p-valores resultan más optimistas de lo que corresponde, por lo que las conclusiones inferenciales deben interpretarse con cautela. Las estimaciones puntuales y la capacidad predictiva, evaluada con validación cruzada por bloques de días, no se ven comprometidas de la misma forma. Modelar explícitamente esta dependencia (por ejemplo, con modelos mixtos o términos autorregresivos) queda fuera del alcance de este trabajo.

## 12. Qué preguntas se pueden responder con `m_fwd`

| Pregunta | Con qué parte del modelo | Estado |
|---|---|---|
| **Principal:** ¿cómo influyen las condiciones meteorológicas y temporales en el número esperado de arriendos por hora? | Todo el modelo, como razones de tasas (IRR) | Falta la tabla de IRR |
| **Secundaria:** ¿qué efecto tiene la temperatura, manteniendo lo demás constante? | `temp` y sus 4 interacciones | Hecho (sección 9) |
| ¿El efecto de la temperatura cambia según estación, hora o feriado? | `temp:seasons`, `hour:temp`, `temp:holiday` | Hecho (sección 9) |
| ¿El efecto de la lluvia depende de la humedad o la radiación? | `humidity:rain`, `solar_rad:rain` | Falta calcular el efecto condicional |
| ¿Cómo cambia la demanda a lo largo del día y con la temperatura? | `hour`, `hour:temp` | Se puede mostrar |
| ¿Hay diferencias entre días de la semana? | `weekday` (F = 58.8, 6 gl) | Falta ver qué días difieren |
| ¿Efecto del viento y la nieve? | Un solo IRR cada uno (no están en interacciones) | Falta calcular el IRR |
| ¿Cuánto mejoran las interacciones? | CV por días | Hecho (RMSE 319 → 251) |
| ¿Cuántas bicicletas esperar por hora en un escenario climático dado, y con qué error? | `predict()` más el CV | Error: RMSE ~251, MAE ~163 |

**Interpretación:** `temp`, `humidity`, `rain`, `solar_rad`, `seasons`, `holiday` y `hour` están en interacciones, así que no tienen un solo IRR; sus coeficientes principales valen para el nivel de referencia de los otros. Solo `wind`, `snow` y `weekday` se interpretan directamente.

**Lo que no se puede responder:**
- Causalidad (datos observacionales).
- Inferencia exacta (p-valores e IC optimistas por la autocorrelación y la selección con los mismos datos).
- Efecto de la intensidad de lluvia o nieve (en `main.R` se discretizaron a sí/no).
- Predicción de la hora siguiente conociendo la anterior (no hay rezagos).
- Días sin servicio (se eliminaron), `visibility` y punto de rocío (se quitaron).
- Extrapolar fuera de lo observado (temperatura entre −17.8 y 39.4 °C, una ciudad y un periodo acotado).

## 13. Pendiente

- Tabla de IRR con IC 95% para el resto de las variables (`wind`, `snow`, `weekday`) y el efecto condicional de la lluvia.
- Agregar a `fit2.R` el cálculo de los efectos condicionales de la temperatura (sección 9), si se usará en el informe.
- Gráfico media-varianza con el modelo final y tabla comparativa con anova entre modelos anidados (existen en `fit.R`, faltan en `fit2.R`).
- Evaluar la lluvia por categorías de intensidad (cambiaría `main.R` y el modelo final).
- Comprobar si `humidity:rain` y `solar_rad:rain` siguen siendo significativas al quitar las 10 observaciones influyentes.
- Repetir la selección de interacciones dentro de cada pliegue (CV anidado) para medir el sesgo por seleccionar con todos los datos.
- Los p-valores del modelo final no son válidos tal cual, porque los términos se eligieron con los mismos datos y los residuos están autocorrelacionados.
- El bucle de selección no imprime por qué se detiene. Se puede agregar un mensaje con el p-valor de la mejor candidata rechazada.
- Detalle menor en `cv_bloques()`: la línea `c(RMSE = ..., MAE = ...)` está repetida. La primera se descarta y no afecta los resultados.
- El script es más lento ahora, por los modelos con ~100 parámetros y el `add1` con las interacciones de `hour`. Para ver solo la tabla de F, basta ejecutar hasta `tabla_F0` (línea 140).
