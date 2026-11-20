library(dplyr)
library(ggplot2)

bike_data <- read.csv(
  "data/SeoulBikeData.csv",
  fileEncoding = "latin1",
  check.names = FALSE
)

# renombramos para mayor claridad 
names(bike_data) <- c(
  "date", "count", "hour", "temp", "humidity", "wind",
  "visibility", "dew_point", "solar_rad", "rainfall",
  "snowfall", "seasons", "holiday", "functioning_day"
)

table(bike_data$functioning_day)

# vemos si hay algun dia con mas de un estado
dias_mixtos <- bike_data %>%
  group_by(date) %>%
  summarise(
    n_horas = n(),
    estados_distintos = n_distinct(functioning_day)
  )

dias <- dias_mixtos %>%
  filter( estados_distintos > 1)
# El dia 6/10/2018 es la única intermitencia 
dias



# Eliminamos cuando no no está funcionando
bike_data <- bike_data %>% 
  filter(functioning_day == "Yes") %>%
  select(-functioning_day)

# cantidad bicis por hora 
ggplot(bike_data, aes(x = factor(hour), y = count)) +
  geom_boxplot(fill = "steelblue", alpha = 0.6, outlier.alpha = 0.2) +
  labs(
    title = "Distribución y media de bicicletas arrendadas por hora",
    x = "Hora del día",
    y = "Cantidad de bicicletas arrendadas"
  ) +
  theme_minimal()

# cantidad bicis segun estacion
ggplot(bike_data, aes(x = seasons, y = count)) +
  geom_boxplot(fill = "steelblue", alpha = 0.6, outlier.alpha = 0.2) +
  labs(title = "Bicicletas arrendadas por estación", x = "Estación", y = "Cantidad") +
  theme_minimal()

# segun feriado
ggplot(bike_data, aes(x = holiday, y = count)) +
  geom_boxplot(fill = "steelblue", alpha = 0.6, outlier.alpha = 0.2) +
  labs(title = "Bicicletas arrendadas según día feriado", x = "Feriado", y = "Cantidad") +
  theme_minimal()


#variables continuas ( uso de bins )

# segun temperatura
# nota:  cut_number separa los bins por percentiles, en este caso las separamos por deciles
ggplot(bike_data, aes(x = cut_number(temp, 10), y = count)) +
  geom_boxplot(fill = "steelblue", alpha = 0.6, outlier.alpha = 0.2) +
  labs(title = "Bicicletas arrendadas por rango de temperatura", x = "Temperatura (°C)", y = "Cantidad") +
  theme_minimal()

cor(bike_data$temp, bike_data$dew_point)

# segun humedad
ggplot(bike_data, aes(x = cut_number(humidity, 10), y = count)) +
  geom_boxplot(fill = "steelblue", alpha = 0.6, outlier.alpha = 0.2) +
  labs(title = "Bicicletas arrendadas por rango de humedad", x = "Humedad (%)", y = "Cantidad") +
  theme_minimal()

# segun velocidad viento 
ggplot(bike_data, aes(x = cut_number(wind, 10), y = count)) +
  geom_boxplot(fill = "steelblue", alpha = 0.6, outlier.alpha = 0.2) +
  labs(title = "Bicicletas arrendadas por velocidad del viento", x = "Viento (m/s)", y = "Cantidad") +
  theme_minimal()









