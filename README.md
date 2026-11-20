# Tarea 2 — Modelos Lineales Generalizados (GLM)

## Demanda de Bicicletas Compartidas en Seúl

### Descripción del Conjunto de Datos
Para el desarrollo de este trabajo se utilizará la base de datos **Seoul Bike Sharing Demand**, disponible en 
* [UCI Machine Learning Repository — Seoul Bike Sharing Demand](https://archive.ics.uci.edu/dataset/560/seoul+bike+sharing+demand)

El conjunto de datos cuenta con **8.760 observaciones horarias** ( 365 días completos) que registran la demanda del sistema público de arriendo de bicicletas en Seúl, junto con las variables meteorológicas y temporales:
* **Variable respuesta:** Cantidad de bicicletas arrendadas por hora (`Rented Bike Count`).
* **Covariables meteorológicas:** Temperatura (°C), humedad relativa (%), velocidad del viento (m/s), visibilidad (10 m), temperatura de punto de rocío (°C), radiación solar (MJ/m²), precipitaciones (mm) y caída de nieve (cm).
* **Covariables temporales y operativas:** Fecha, hora del día (`0`–`23`), estación del año (`Winter`, `Spring`, `Summer`, `Autumn`), indicador de día festivo (`Holiday` / `No Holiday`) y estado operativo del servicio (`Functioning Day`).

---

### 2. Pregunta de Investigación
> *¿Cómo influyen las condiciones meteorológicas y temporales en la cantidad esperada de bicicletas arrendadas por hora?*

---

### 3. Estrategia de Modelamiento
1. **Depuración de datos:** bla bla
2. **Modelo base:** bla bla 
3. **Evaluación de sobredispersión:** bla bla

---
### 4. Estructura del Repositorio
* `data/` — Base de datos original (`SeoulBikeData.csv`).
* `code/` — Scripts de R con el análisis exploratorio, limpieza de variables y ajuste de modelos GLM.