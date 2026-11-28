# ==================================================
# Efecto de la temperatura según estación y hora
# ==================================================

# Modelo final previamente ajustado
modelo <- m_fwd

# Datos utilizados en el ajuste
datos <- model.frame(modelo)

# Categorías de las variables
estaciones <- modelo$xlevels$seasons
horas <- modelo$xlevels$hour

# Combinaciones de estación y hora
combinaciones <- expand.grid(
  seasons = estaciones,
  hour = horas
)

# Construcción de observaciones de referencia
datos_0 <- datos[
  rep(1, nrow(combinaciones)), 
  , drop = FALSE
]

datos_0$seasons <- factor(
  combinaciones$seasons,
  levels = estaciones
)

datos_0$hour <- factor(
  combinaciones$hour,
  levels = horas
)

# Temperatura inicial
datos_0$temp <- 15

# Aumento de un grado Celsius
datos_1 <- datos_0
datos_1$temp <- 16

# Predictores lineales
eta_0 <- predict(modelo, newdata = datos_0,
                 type = "link")

eta_1 <- predict(modelo, newdata = datos_1,
                 type = "link")

# Pendiente de la temperatura
combinaciones$Pendiente <- eta_1 - eta_0

# Razón de medias
combinaciones$Razon_medias <- 
  exp(combinaciones$Pendiente)

# Variación porcentual de la demanda
combinaciones$Variacion_pct <- 
  100 * (combinaciones$Razon_medias - 1)

# Visualizar resultados
print(combinaciones)




tabla_efectos <- xtabs(
  Variacion_pct ~ hour + seasons,
  data = combinaciones
)

print(round(tabla_efectos, 2))