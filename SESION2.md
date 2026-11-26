# Sesión 2: Modelamiento en `code/fit2.R` y validación con `code/seed_cv.R`

Este documento describe **todo lo que hace `code/fit2.R`**, los criterios que se usaron y por qué, los resultados obtenidos y qué hace `code/seed_cv.R`.

Reemplaza a `SESION_fit2.md`. Ese archivo describe una versión anterior en la que las interacciones se elegían por el estadístico F (con F ≥ 50) y se agregaban algunas a mano. Ese criterio **ya no se usa** (ver sección 10).

Todos los números de este documento salen de correr `main.R` → `fit2.R` → `seed_cv.R` completos, sin errores (unos 2.5 minutos en total).

---

## 0. Resumen

1. El Poisson tiene una **sobredispersión fuerte** (φ̂ ≈ 104.9). Se elige **quasi-Poisson**, con `visibility` eliminada porque no aporta (p = 0.91).
2. Se prueban las **45 interacciones por pares** de a una contra el modelo base. Son candidatas las que tienen **p < 0.05 y bajan al menos un 2 % la devianza**: quedan 10.
3. Una **selección hacia adelante** con el mismo criterio, pero contra el modelo actual, agrega **5 interacciones**: `temp:seasons`, `hour:weekday`, `hour:temp`, `humidity:rain` y `hour:seasons`.
4. El modelo final `m_fwd` tiene **274 parámetros, ninguno NA**. Explica el **90.25 % de la devianza** (el modelo base explica el 80.14 %) y φ̂ baja de 104.9 a 50.9.
5. La **validación cruzada por días completos** muestra que la mejora se mantiene en días no vistos (RMSE de 319 → 216) y que el **sobreajuste es moderado** (brecha del 5 %). El resultado **no depende de la semilla** (desviación estándar de 1 punto entre 5 semillas).
6. **Limitaciones:** los residuos tienen autocorrelación temporal (0.61 en el rezago 1, así que los p-valores son optimistas), y el coeficiente principal de `rain` es sensible a unas pocas observaciones influyentes.

---

## 1. Orden de ejecución y requisitos

```r
source("code/main.R")     # EDA y preparación de bike_data
source("code/fit2.R")     # modelos, selección, diagnóstico y validación cruzada
source("code/seed_cv.R")  # validación cruzada repetida con varias semillas
```

- `fit2.R` usa `bike_data` tal como lo deja `main.R`: con `hour` como factor, `rain`/`snow` como factores Sí/No, `weekday` como factor de 7 niveles, sin las horas con `functioning_day == "No"` y sin `dew_point`.
- `seed_cv.R` usa `bike_data`, `m_qpois` y `m_fwd`, creados en `fit2.R`.
- Paquetes: `dplyr`, `ggplot2`, `tidyverse` (incluye `lubridate`, que se usa para `wday()`), `corrplot`, `MASS` y `car`.
- Datos finales: **n = 8465 horas, 353 días**.

---

## 2. Mapa de `fit2.R`

| Líneas | Sección | Qué hace | Objetos que crea |
|---|---|---|---|
| 1–19 | Poisson | Ajusta el Poisson completo y calcula φ̂ = X²/gl. Muestra las 5 horas con mayor residuo de Pearson. | `m_pois`, `phi_hat` |
| 21–29 | Binomial negativa | Ajusta la binomial negativa con los mismos predictores y calcula el VIF. | `m_nb` |
| 31–54 | Quasi-Poisson | Ajusta el quasi-Poisson completo, `drop1` (se elimina `visibility`), el modelo base sin `visibility`, test F contra el modelo nulo y VIF. | `m_qpois_0`, `m_qpois`, `m_qpois_nulo` |
| 56–95 | Media-varianza | Agrupa en 15 cuantiles de μ̂ y compara la varianza empírica con Poisson, quasi-Poisson y binomial negativa. | `resumen_var`, `theta_hat` |
| 98–121 | Screening | Prueba las 45 interacciones por pares, de a una, contra `m_qpois`. | `screening_int` |
| 123–137 | Candidatas | Filtra por p < 0.05 y ≥ 2 % de devianza. `tabla_F0` es una tabla informativa. | `candidatas`, `tabla_F0` |
| 140–189 | Forward | Selección hacia adelante con el mismo criterio, contra el modelo actual. | `pasos`, `m_fwd` |
| 192–195 | `drop1` | Verifica que cada término de `m_fwd` siga aportando. | — |
| 198–255 | Residuos | Panel 2×2 (residuos contra η̂, residuos contra `temp`, distancia de Cook y ACF) y gráfico A2 con residuos promedio por bins. | `res_dev_std`, `eta_hat`, `cooks_d` |
| 258–283 | Influyentes | Top 10 por distancia de Cook, reajuste sin ellas y cambio de los coeficientes. | `top_influyentes`, `m_fwd_sin_inf` |
| 286–350 | Validación cruzada | Validación cruzada por días completos (10 pliegues, semilla 123): base contra final. | `tabla_cv` |
| 353–388 | Media-varianza final | El mismo gráfico de la sección 56–95, pero con `m_fwd`. | `m_nb_fwd` |
| 391–411 | ANOVA anidado | Nulo ⊂ base ⊂ final, con el % de devianza explicada y φ̂. | `tabla_anidados` |

---

## 3. Elección de la familia (líneas 1–95)

| Modelo | Resultado clave |
|---|---|
| Poisson | φ̂ = X²/gl = **104.9**: la varianza es unas 105 veces la media. El Poisson subestima los errores estándar. |
| Binomial negativa | θ̂ = 4.32 (Var = μ + μ²/4.32). |
| Quasi-Poisson | φ̂ = 104.9, que coincide con el cálculo manual. |

- **`visibility`:** en el `drop1` del quasi-Poisson completo tiene F = 0.01 y p = 0.91, así que se elimina. El resultado es `m_qpois`.
- **Modelo base contra nulo:** F = 892.7, p < 2.2e-16.
- **Multicolinealidad:** todos los GVIF^(1/(2·gl)) están por debajo de 2.4. No hay un problema serio.
- **Elección:** el gráfico media-varianza de las líneas 56–95 se usa para justificar la estructura Var = φ·μ (quasi-Poisson) frente a Var = μ + μ²/θ (binomial negativa).

---

## 4. Screening de interacciones (líneas 98–121)

Para cada par de las 10 variables (`hour`, `temp`, `humidity`, `wind`, `solar_rad`, `rain`, `snow`, `seasons`, `holiday`, `weekday`):

1. Se ajusta `m_qpois + esa interacción`, **sola**.
2. Se corre `anova(m_qpois, mod, test = "F")`.
3. Se guardan los gl extra, `Red_Dev_Pct` (el % de la devianza del modelo base que baja), F y p-valor.

La tabla se ordena por p-valor. Cada interacción se prueba **por separado**, así que el screening **no ve la redundancia** entre interacciones. Para eso está el forward.

**Resultado:** **37 de 45** interacciones tienen p < 0.05. Con n = 8465 casi todo sale significativo, por lo que el p-valor solo no sirve para filtrar.

---

## 5. Criterio de selección: p < 0.05 **y** ≥ 2 % de devianza (líneas 123–137)

```r
alfa_screening <- 0.05
umbral_dev     <- 2   # en %
candidatas <- screening_int$Interaccion[screening_int$p_valor < alfa_screening &
                                          screening_int$Red_Dev_Pct >= umbral_dev]
```

| Condición | Pregunta que responde |
|---|---|
| p < 0.05 (test F) | ¿El efecto es real o podría ser ruido? |
| Baja ≥ 2 % la devianza | ¿El efecto importa en la práctica? |

**Por qué no se usa el estadístico F para ordenar o filtrar.** F = (ΔD/Δgl)/φ̂ es la baja de devianza **por grado de libertad**, pero su distribución depende de los gl. Un F de 50 con 1 gl (p ≈ 1e-12) es mucho menos evidencia que un F de 14 con 138 gl (p ≈ 1e-280). Al ordenar por F se castiga a las interacciones con `hour` (23 gl o más). El p-valor sí tiene en cuenta los gl.

**Por qué no se usa solo "la que más baja la devianza".** Al agregar un término la devianza **siempre** baja, aunque sea ruido. Sin una condición de significancia nunca habría un punto de corte.

**Candidatas (10):**

| Interacción | gl | Baja de devianza | F | p |
|---|---|---|---|---|
| temp:seasons | 3 | 20.97 % | 754.6 | < 1e-300 |
| hour:weekday | 138 | 18.44 % | 14.2 | 1.5e-280 |
| temp:solar_rad | 1 | 8.09 % | 750.1 | 2.8e-158 |
| hour:temp | 23 | 8.80 % | 35.8 | 4.3e-151 |
| solar_rad:seasons | 3 | 7.22 % | 221.2 | 3.7e-138 |
| hour:seasons | 69 | 9.53 % | 13.0 | 1.9e-135 |
| humidity:seasons | 3 | 3.58 % | 105.9 | 2.8e-67 |
| hour:solar_rad | 14 | 2.85 % | 18.1 | 3.5e-45 |
| humidity:rain | 1 | 2.01 % | 178.2 | 3.0e-40 |
| solar_rad:weekday | 6 | 2.22 % | 32.7 | 3.9e-39 |

`humidity:rain` pasa muy justa (2.01 %). La siguiente es `humidity:weekday`, con 1.51 %.

`tabla_F0` (líneas 133–137) recalcula con `add1` el F de cada candidata contra el modelo base. Es informativa y no se usa para decidir. Sus F difieren un poco de los del screening porque `add1` estima φ con la devianza y `anova` con los residuos de Pearson.

---

## 6. Selección hacia adelante (líneas 140–189)

Usa el **mismo criterio** que el screening, pero cada candidata se prueba **contra el modelo actual**, que ya incluye las interacciones agregadas antes:

1. Para cada candidata restante: `anova(m_act, m_act + x, test = "F")`.
2. Son **elegibles** las que tienen p < 0.05 **y** bajan al menos `umbral_dev` % la devianza **del modelo actual**.
3. Entre las elegibles entra la de **menor p-valor**. Se compara `log10(p)`, calculado con `pf(..., log.p = TRUE)`, porque los p-valores más fuertes dan exactamente 0 por underflow y quedarían empatados.
4. Si ninguna es elegible, se detiene e imprime cuánto aportaba cada candidata restante.

**Pasos:**

| Paso | Agregada | gl | Baja de devianza (vs. modelo actual) | F | log10(p) |
|---|---|---|---|---|---|
| 1 | temp:seasons | 3 | 20.97 % | 754.6 | −433.9 |
| 2 | hour:weekday | 138 | 24.11 % | 19.7 | −401.7 |
| 3 | hour:temp | 23 | 12.51 % | 53.4 | −226.9 |
| 4 | humidity:rain | 1 | 4.21 % | 385.9 | −83.3 |
| 5 | hour:seasons | 69 | 2.35 % | 3.0 | −15.1 |

**Se detiene** porque ninguna de las restantes llega al 2 %, aunque todas son significativas:

| Candidata restante | Baja de devianza | log10(p) |
|---|---|---|
| hour:solar_rad | 1.70 % | −24.2 |
| temp:solar_rad | 1.20 % | −24.1 |
| solar_rad:seasons | 0.57 % | −10.1 |
| solar_rad:weekday | 0.54 % | −7.8 |
| humidity:seasons | 0.26 % | −4.3 |

Las interacciones con `solar_rad` aportaban mucho **solas** (en el screening), pero una vez que entran `hour:temp` y `temp:seasons` lo que explicaban ya está cubierto. Es la redundancia que el screening no ve. Como `hour:solar_rad` no entra, **el modelo final no tiene coeficientes NA** (de noche la radiación es siempre 0 y esos coeficientes no serían estimables).

**Modelo final:**
```
count ~ hour + temp + humidity + wind + solar_rad + rain + snow + seasons +
        holiday + weekday + temp:seasons + hour:weekday + hour:temp +
        humidity:rain + hour:seasons
```
274 parámetros, φ̂ = 50.89.

### Interpretación de las interacciones

- **`hour:weekday`:** el perfil horario cambia entre días hábiles y fin de semana. De lunes a viernes hay peaks a las 8:00 (~1300 arriendos) y a las 18:00 (~1700), por los viajes al trabajo o a clases. El sábado y el domingo esos peaks caen (8:00: ~350–500) y el uso se concentra a mediodía y en la tarde.
- **`temp:seasons`:** el efecto de la temperatura depende de la estación.
- **`hour:temp`:** el efecto de la temperatura depende de la hora del día.
- **`humidity:rain`:** el efecto de la lluvia depende de la humedad.
- **`hour:seasons`:** el perfil horario cambia según la estación.

Sin interacciones, el modelo log-lineal obliga a que todos los días tengan la misma forma de curva horaria, y solo deja cambiar el nivel.

---

## 7. ¿Aporta cada término? (líneas 192–195)

`drop1(m_fwd, test = "F")` respeta la jerarquía: solo prueba quitar los términos que no están contenidos en una interacción.

| Término | gl | F | p |
|---|---|---|---|
| temp:seasons | 3 | 1076.8 | < 2.2e-16 |
| humidity:rain | 1 | 370.3 | < 2.2e-16 |
| holiday | 1 | 137.9 | < 2.2e-16 |
| solar_rad | 1 | 135.3 | < 2.2e-16 |
| wind | 1 | 48.3 | 3.9e-12 |
| snow | 1 | 43.3 | 5.0e-11 |
| hour:weekday | 138 | 23.0 | < 2.2e-16 |
| hour:temp | 23 | 17.7 | < 2.2e-16 |
| hour:seasons | 69 | 2.9 | 5.2e-14 |

Todos los términos siguen siendo significativos en el modelo final.

---

## 8. Diagnóstico (líneas 198–283)

### Residuos (panel 2×2 y gráfico A2)
- **A. Residuos contra η̂:** busca curvatura en el enlace log o embudos.
- **A2. Residuos promedio por 30 bins de η̂, con ±2 EE:** si el modelo ajusta bien, los promedios están cerca de 0 y sin forma.
- **B. Residuos contra `temp`:** busca una no linealidad de la temperatura que no se haya capturado.
- **C. Distancia de Cook:** muestra las observaciones influyentes, con la línea de referencia en 4/n.
- **D. ACF de los residuos de Pearson:** autocorrelación de **0.61 en el rezago 1** y de 0.18 en el rezago 24. Las horas consecutivas no son independientes.

### Observaciones influyentes y sensibilidad
Las 10 observaciones con mayor distancia de Cook (máximo 0.019) son horas donde el modelo se equivoca mucho, por ejemplo el 19/04/2018 a las 8:00, con 20 arriendos reales y 1582 predichos. **4 de las 10 son horas con lluvia**, aunque la lluvia aparece solo en 516 de 8465 horas.

Al reajustar sin esas 10:

| Coeficiente | Cambio (escala log) | Cambio relativo |
|---|---|---|
| rainYes | 0.472 | 60.3 % |
| hour13:weekdayMartes | 0.038 | 3.9 % |
| hour8:seasonsSummer | 0.032 | 3.3 % |

φ̂ cambia de 50.89 a 49.31.

**Lectura:** el resto del modelo es estable, pero **el efecto principal de `rain` depende mucho de pocas observaciones**. Además, como `rain` interactúa con `humidity`, el coeficiente `rainYes` (1.99) corresponde al efecto de la lluvia **con humedad = 0**, un valor fuera del rango observado. El efecto de la lluvia debe interpretarse a humedades típicas, combinando `rainYes` con `humidity:rainYes`, y no con `rainYes` solo.

---

## 9. Validación cruzada por bloques de días (líneas 286–350)

### Cómo funciona
1. **Pliegues por día:** `sample(rep(1:10, length.out = 353))` asigna cada día a un pliegue (1 a 10) al azar. `rep` asegura que los pliegues tengan el mismo tamaño (35–36 días cada uno) y `sample` los reparte al azar.
2. **De días a horas:** `folds_dias[as.character(bike_data$date)]` hace que cada hora herede el pliegue de su día, así que las 24 horas de un día quedan siempre juntas.
3. **Para cada pliegue k:**
   - `tr = bike_data[folds != k, ]` (~90 % de los días) y `te = bike_data[folds == k, ]` (~10 %).
   - `update(modelo, data = tr)` reajusta **el mismo modelo** (misma fórmula y familia) solo con `tr`.
   - `predict(..., newdata = te, type = "response")` predice conteos en días que el modelo no vio.
   - Se calculan RMSE = √(promedio de (real − predicho)²) y MAE = promedio de |real − predicho|.
4. Se promedian los 10 pliegues y se comparan con el error de entrenamiento.

### Por qué días completos, al azar
- **No horas sueltas:** las horas de un mismo día comparten clima y patrón. Si se repartieran entre entrenamiento y prueba, el modelo "vería" parte del día que tiene que predecir, y el error saldría artificialmente bajo.
- **No días consecutivos (por ejemplo, un mes por pliegue):** el modelo tendría que extrapolar a una estación casi sin datos, y el error saldría inflado. Con días al azar, cada pliegue tiene días de todas las estaciones y de todos los días de la semana.

### Resultado (semilla 123)

| Modelo | Parámetros | RMSE train | RMSE CV | Brecha | MAE train | MAE CV | Brecha |
|---|---|---|---|---|---|---|---|
| Base | 40 | 312.08 | 318.41 | 2.0 % | 207.25 | 212.42 | 2.5 % |
| Final (m_fwd) | 274 | 206.00 | 215.96 | 4.8 % | 125.05 | 131.55 | 5.2 % |

- **Mejora fuera de la muestra:** −32 % en RMSE y −38 % en MAE. El error de CV del modelo final está muy por debajo incluso del error de **entrenamiento** del modelo base.
- **Sobreajuste:** la brecha sube de 2 % a ~5 %, que es moderado para pasar de 40 a 274 parámetros (~31 observaciones por parámetro).
- **Escala:** el promedio es de 729 arriendos por hora y el máximo de 3556. El RMSE es bastante mayor que el MAE (216 contra 132), lo que indica que hay algunas horas con errores grandes, como las influyentes de la sección 8.

---

## 10. ANOVA anidado y gráfico media-varianza final (líneas 353–411)

| Modelo | Parámetros | gl residuales | Devianza | % de devianza explicada | φ̂ | F vs. anterior |
|---|---|---|---|---|---|---|
| Nulo | 1 | 8464 | 4 556 385 | 0.00 % | 565.88 | — |
| Base aditivo | 40 | 8425 | 904 698 | 80.14 % | 104.89 | 1839.9 (p ≈ 0) |
| Final (m_fwd) | 274 | 8191 | 444 099 | 90.25 % | 50.89 | 38.7 (p ≈ 0) |

Las interacciones bajan la devianza residual a la mitad y reducen φ̂ de 104.9 a 50.9. Parte de lo que parecía sobredispersión era en realidad falta de estructura en el modelo.

El gráfico media-varianza se repite con `m_fwd`, y para comparar se ajusta `m_nb_fwd`, una binomial negativa con la misma fórmula.

---

## 11. `code/seed_cv.R`: validación cruzada con varias semillas

### Para qué
La validación cruzada de `fit2.R` usa una sola semilla (123). La semilla decide **qué días caen en cada pliegue**. Si el resultado dependiera de eso, la conclusión sería frágil. `seed_cv.R` repite la misma validación cruzada con varias semillas y mide cuánto varía.

### Uso
```r
# con bike_data, m_qpois y m_fwd en memoria (después de fit2.R)
source("code/seed_cv.R")

# o con otras opciones:
res <- seed_cv(list(Base = m_qpois, Final = m_fwd),
               semillas = 1:10,  # por defecto c(1, 42, 123, 2024, 777)
               k = 10,           # pliegues
               datos = bike_data)
res$por_semilla   # una fila por semilla y modelo
res$resumen       # media y desviación estándar entre semillas, y brecha con train
```

### Qué hace por dentro
Son tres ciclos anidados:
```
para cada semilla s
  set.seed(s) y se arman los pliegues por día (igual que en fit2.R)
  para cada modelo nm (los mismos pliegues para todos los modelos → comparación justa)
    para cada pliegue j = 1..k
      update(modelos[[nm]], data = tr) → predict sobre te → RMSE y MAE
    promedio de los k pliegues → 1 fila (semilla, modelo)
```
- `modelos` es una **lista con nombre**. Se recorre `names(modelos)` para tener el nombre y usarlo en la tabla, y `modelos[[nm]]` (doble corchete) saca el objeto `glm` en sí. Con un solo corchete sería una lista de un elemento.
- El error de entrenamiento se calcula una vez, porque no depende de la semilla.
- `resumen` cuenta **solo los parámetros estimables** (`sum(!is.na(coef(m)))`).

### Resultado (5 semillas, 10 pliegues)

| Semilla | RMSE CV base | RMSE CV final | MAE CV base | MAE CV final |
|---|---|---|---|---|
| 1 | 316.86 | 215.28 | 211.11 | 131.44 |
| 42 | 320.03 | 217.26 | 213.19 | 132.12 |
| 123 | 318.41 | 215.96 | 212.42 | 131.55 |
| 2024 | 319.87 | 217.28 | 212.34 | 131.96 |
| 777 | 319.76 | 215.48 | 212.78 | 131.25 |

| Modelo | Parámetros | RMSE CV (media ± sd) | Brecha RMSE | MAE CV (media ± sd) | Brecha MAE |
|---|---|---|---|---|---|
| Base | 40 | 318.99 ± 1.35 | 2.2 % | 212.37 ± 0.78 | 2.5 % |
| Final | 274 | 216.25 ± 0.96 | 5.0 % | 131.66 ± 0.36 | 5.3 % |

**Conclusión:** la variación entre semillas (~1 punto) es mínima comparada con la diferencia entre modelos (~103 puntos de RMSE). El modelo final gana con todas las semillas y la brecha con entrenamiento se mantiene en ~5 %. Ni la mejora ni la conclusión sobre el sobreajuste dependen de la partición.

---

## 12. Historia de decisiones

| Versión | Selección de candidatas | Forward | Modelo final | RMSE CV | Brecha |
|---|---|---|---|---|---|
| Anterior (`SESION_fit2.md`) | F ≥ 50, más `hour:temp` y `hour:solar_rad` a mano | Mayor F, p < 0.05 | — | — | — |
| Intermedia | p < 0.05 y ≥ 2 % | Mayor F, p < 0.05 (sin exigir el 2 %) | 9 interacciones, 298 + 9 NA | 210.8 | 6.3 % |
| **Actual** | p < 0.05 y ≥ 2 % | **Menor p, p < 0.05 y ≥ 2 % vs. el modelo actual** | **5 interacciones, 274, sin NA** | **216.3** | **5.0 %** |

**Por qué se cambió:**
1. **El corte F ≥ 50** era arbitrario y castigaba a las interacciones con `hour`. Hubo que agregar dos a mano, lo que es difícil de justificar.
2. **El forward de la versión intermedia** no exigía el 2 %. Entraban `solar_rad:seasons` (1.08 %) y `hour:solar_rad` (1.55 %), que no cumplían el criterio que se declaraba. Además, el orden por F hacía que `hour:weekday`, la que más aporta (25 %), entrara recién en el paso 6.
3. **La versión actual** usa **un solo criterio** en todo el proceso. A cambio de un RMSE ~2.6 % mayor, tiene 4 interacciones menos, ningún coeficiente NA y menos sobreajuste.

---

## 13. Limitaciones para el informe

1. **Autocorrelación temporal:** ACF de 0.61 en el rezago 1. El quasi-Poisson supone independencia, así que **los errores estándar y los p-valores son optimistas**. Esto refuerza que el criterio no dependa solo de p < 0.05 (el umbral del 2 % es el que discrimina) y que la validación cruzada sea por días completos.
2. **Validación cruzada con días al azar:** días vecinos también se parecen (por ejemplo, días seguidos con el mismo clima). El error de CV podría estar un poco subestimado. Una alternativa más estricta sería usar bloques de semanas completas.
3. **Sensibilidad de `rain`:** el coeficiente `rainYes` cambia un 60 % al quitar 10 observaciones (4 de ellas con lluvia). Hay que interpretarlo junto con `humidity:rain` y con cautela.
4. **Tamaño del modelo:** 274 parámetros (138 vienen de `hour:weekday`). Para responder la pregunta de investigación conviene usar **gráficos de predicciones** (perfil horario por tipo de día, efecto de la temperatura por estación, efecto de la lluvia) en vez de interpretar los coeficientes uno por uno. Una versión más compacta sería reemplazar `weekday` por "fin de semana sí/no" en la interacción con `hour` (23 gl en vez de 138).
5. **Umbral del 2 %:** es una decisión del análisis. Con un 1 %, el forward agrega más términos (353 parámetros, RMSE CV ≈ 204, brecha ≈ 8 %). El 2 % favorece la parsimonia.

---

## 14. Validación realizada en esta sesión

- Se corrió `main.R` → `fit2.R` → `seed_cv.R` completo y en orden: **sin errores ni advertencias de R**.
- Todos los números de este documento salen de esa ejecución.
- Dos correcciones menores de comentarios en `fit2.R`:
  - Línea 260: decía "Top 5" pero se toman 10 observaciones.
  - Líneas 270–272: mencionaban coeficientes NA de `hour:solar_rad`, que ya no está en el modelo.
