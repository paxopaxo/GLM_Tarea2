# Tarea 2 — Modelos Lineales Generalizados (GLM)

## Demanda de Bicicletas Compartidas en Seúl

### Descripción del Conjunto de Datos
Para el desarrollo de este trabajo se utilizará la base de datos **Seoul Bike Sharing Demand**, disponible en 
* [UCI Machine Learning Repository — Seoul Bike Sharing Demand](https://archive.ics.uci.edu/dataset/560/seoul+bike+sharing+demand)

El conjunto de datos cuenta con **8.760 observaciones horarias** ( 365 días completos) que registran la demanda del sistema público de arriendo de bicicletas en Seúl, junto con las variables meteorológicas y temporales:
* **Variable respuesta:** Cantidad de bicicletas arrendadas por hora (`Rented Bike Count`).
* **Covariables meteorológicas:** Temperatura (°C), humedad relativa (%), velocidad del viento (m/s), visibilidad (10 m), temperatura de punto de rocío (°C), radiación solar (MJ/m²), precipitaciones (mm) y caída de nieve (cm).
* **Covariables temporales y operativas:** Fecha, hora del día (`0`–`23`), estación del año (`Winter`, `Spring`, `Summer`, `Autumn`), indicador de día festivo (`Holiday` / `No Holiday`) y estado operativo del servicio (`Functioning Day`).

En `main.R` se eliminan las horas en que el servicio no estaba operativo (`Functioning Day = No`), por lo que el análisis se hace sobre **8.465 observaciones (353 días)**.

---

### 2. Pregunta de Investigación
> *¿Cómo influyen las condiciones meteorológicas y temporales en la cantidad esperada de bicicletas arrendadas por hora?*

---
### 3. Estructura del Repositorio
* `data/` — Base de datos original (`SeoulBikeData.csv`).
* `code/` — Scripts de R:
  * `main.R` — **Análisis exploratorio de datos (EDA) y preparación de la base.**
    * Carga el CSV y renombra las variables.
    * Explora la distribución de lluvia y nieve, revisa los días no operativos y calcula la matriz de correlaciones.
    * Hace boxplots de arriendos por hora, estación, feriado, día de la semana y deciles de temperatura, humedad y viento.
    * Deja `bike_data` listo para modelar: `hour` como factor, `rain`/`snow` como Sí/No, `weekday` (lunes a domingo), sin las horas no operativas y sin `dew_point`.
  * `fit2.R` — **Modelamiento.**
    * Elección de la familia (Poisson → quasi-Poisson por sobredispersión).
    * Screening de las 45 interacciones por pares y selección hacia adelante (criterio: p < 0.05 y reducción de devianza ≥ 2 %).
    * Diagnóstico de residuos, observaciones influyentes, validación cruzada por bloques de días y ANOVA de modelos anidados.
    * Deja en memoria el modelo base `m_qpois` y el modelo final `m_fwd`.
  * `seed_cv.R` — Función `seed_cv()`: repite la validación cruzada por días con varias semillas para verificar que el resultado no depende de cómo se reparten los días en los pliegues.
* `doc/` — Documentos anexos.

---
### 4. Orden de Ejecución
Los scripts dependen de los objetos que crea el anterior, por lo que deben ejecutarse **en este orden**, desde la raíz del proyecto (la ruta `data/SeoulBikeData.csv` es relativa):

```r
source("code/main.R")     # 1. EDA y preparación de bike_data
source("code/fit2.R")     # 2. Modelos, selección de interacciones y validación (requiere bike_data)
source("code/seed_cv.R")  # 3. Validación cruzada con varias semillas (requiere bike_data, m_qpois y m_fwd)
```

* **Paquetes necesarios:** `tidyverse` (incluye `dplyr`, `ggplot2` y `lubridate`), `corrplot`, `MASS` y `car`.
* **Tiempo aproximado:** ~2.5 minutos en total. La mayor parte se va en las validaciones cruzadas, que reajustan los modelos muchas veces.
