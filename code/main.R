library(dplyr)
library(ggplot2)
library(tidyverse)
library(corrplot)
select <- dplyr::select

# Carpeta donde se guardan todos los graficos
dir.create("plots", showWarnings = FALSE)

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
# notar que rainfall y snowfall son 0 hasta el tercer cuantil 
summary(bike_data)

# Ver cuantas horas tienen lluvia y nieve al mismo tiempo
sum(bike_data$rainfall > 0 & bike_data$snowfall > 0)

bike_data %>%
  mutate(weather_state = case_when(
    snowfall > 0 ~ "Nieve (> 0 cm)",
    rainfall > 0 ~ "LLuvia (> 0 mm)",
    TRUE         ~ "Seco (0)"
  )) %>%
  group_by(weather_state) %>%
  summarise(n = n()) %>%
  mutate(pct = n / sum(n) * 100) %>%
  ggplot(aes(x = weather_state, y = pct, fill = weather_state)) +
  geom_col(width = 0.55, show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.1f%% (%d hrs)", pct, n)), vjust = -0.4) +
  ylim(0, 105) +
  labs(
    title = "Distribution of Precipitation States in Seoul Bike Data",
    x = NULL,
    y = "Percentage of Hours (%)"
  ) +
  theme_minimal(base_size = 12)
ggsave("plots/01_eda_estados_precipitacion.png", width = 7, height = 5, dpi = 300)

bike_data <- bike_data %>%
  mutate(
    rain = factor(ifelse(rainfall > 0, "Yes", "No")),
    snow = factor(ifelse(snowfall > 0, "Yes", "No"))
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

#variables numericas
num_vars <- bike_data %>%
  select(count, temp, humidity, dew_point, wind, visibility, solar_rad, rainfall, snowfall)

#matriz de correlacion pearson
cor_mat <- cor(num_vars, method = "pearson")
corrplot(cor_mat, method = "color", type = "lower", addCoef.col = "black", number.cex = 0.75, tl.col = "black")
dev.copy(png, "plots/01_eda_matriz_correlacion.png", width = 8, height = 8, units = "in", res = 300); dev.off()


# Eliminamos cuando no no está funcionando
bike_data <- bike_data %>% 
  mutate( hour = factor(hour) ) %>% 
  filter(functioning_day == "Yes") %>%
  select(-functioning_day, -dew_point)

# Día de la semana como factor (uso de wday() para ser independiente del locale del sistema)
# wday con week_start=1 -> 1=Lunes, 7=Domingo
bike_data <- bike_data %>%
  mutate(
    date_dt = as.Date(date, format = "%d/%m/%Y"),
    weekday = factor(
      wday(date_dt, week_start = 1),
      levels = 1:7,
      labels = c("Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo")
    )
  )

# cantidad bicis por hora 
ggplot(bike_data, aes(x = factor(hour), y = count)) +
  geom_boxplot(fill = "steelblue", alpha = 0.6, outlier.alpha = 0.2) +
  labs(
    title = "Distribución y media de bicicletas arrendadas por hora",
    x = "Hora del día",
    y = "Cantidad de bicicletas arrendadas"
  ) +
  theme_minimal()
ggsave("plots/01_eda_boxplot_hora.png", width = 10, height = 5, dpi = 300)

# cantidad bicis segun estacion
ggplot(bike_data, aes(x = seasons, y = count)) +
  geom_boxplot(fill = "steelblue", alpha = 0.6, outlier.alpha = 0.2) +
  labs(title = "Bicicletas arrendadas por estación", x = "Estación", y = "Cantidad") +
  theme_minimal()
ggsave("plots/01_eda_boxplot_estacion.png", width = 7, height = 5, dpi = 300)

# segun feriado
ggplot(bike_data, aes(x = holiday, y = count)) +
  geom_boxplot(fill = "steelblue", alpha = 0.6, outlier.alpha = 0.2) +
  labs(title = "Bicicletas arrendadas según día feriado", x = "Feriado", y = "Cantidad") +
  theme_minimal()
ggsave("plots/01_eda_boxplot_feriado.png", width = 6, height = 5, dpi = 300)

# segun dia de la semana
ggplot(bike_data, aes(x = weekday, y = count)) +
  geom_boxplot(fill = "steelblue", alpha = 0.6, outlier.alpha = 0.2) +
  labs(title = "Bicicletas arrendadas por día de la semana", x = "Día de la semana", y = "Cantidad") +
  theme_minimal()
ggsave("plots/01_eda_boxplot_dia_semana.png", width = 8, height = 5, dpi = 300)


#variables continuas ( uso de bins )

# segun temperatura
# nota:  cut_number separa los bins por percentiles, en este caso las separamos por deciles
ggplot(bike_data, aes(x = cut_number(temp, 10), y = count)) +
  geom_boxplot(fill = "steelblue", alpha = 0.6, outlier.alpha = 0.2) +
  labs(title = "Bicicletas arrendadas por rango de temperatura", x = "Temperatura (°C)", y = "Cantidad") +
  theme_minimal()
ggsave("plots/01_eda_boxplot_temperatura.png", width = 10, height = 5, dpi = 300)

# segun humedad
ggplot(bike_data, aes(x = cut_number(humidity, 10), y = count)) +
  geom_boxplot(fill = "steelblue", alpha = 0.6, outlier.alpha = 0.2) +
  labs(title = "Bicicletas arrendadas por rango de humedad", x = "Humedad (%)", y = "Cantidad") +
  theme_minimal()
ggsave("plots/01_eda_boxplot_humedad.png", width = 10, height = 5, dpi = 300)

# segun velocidad viento 
ggplot(bike_data, aes(x = cut_number(wind, 10), y = count)) +
  geom_boxplot(fill = "steelblue", alpha = 0.6, outlier.alpha = 0.2) +
  labs(title = "Bicicletas arrendadas por velocidad del viento", x = "Viento (m/s)", y = "Cantidad") +
  theme_minimal()
ggsave("plots/01_eda_boxplot_viento.png", width = 10, height = 5, dpi = 300)









