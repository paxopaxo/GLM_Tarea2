# Se traduce a efectos interpretables con 3 herramientas:
#   1. Importancia de cada variable (devianza que se pierde al quitarla con sus interacciones).
#   2. Razones de tasas exp(beta) con IC 95% para variables SIN interaccion.
#   3. Efectos promedio por prediccion para variables CON interaccion (temp, rain, hour).
#
m <- m_fwd
d <- bike_data

# Carpeta donde se guardan todos los graficos
dir.create("plots", showWarnings = FALSE)


############## 1. Importancia de cada variable
# Para cada variable: se reajusta el modelo final SIN esa variable y SIN las interacciones
# en que aparece, y se mide cuanta devianza se pierde, como % de la devianza del modelo nulo.
# Mientras mas devianza se pierde, mas importante es la variable para explicar los arriendos.

vars_imp <- c(hour = "Temporal", seasons = "Temporal", weekday = "Temporal", holiday = "Temporal",
              temp = "Meteorologica", rain = "Meteorologica", humidity = "Meteorologica",
              solar_rad = "Meteorologica", wind = "Meteorologica", snow = "Meteorologica")

terminos <- attr(terms(m), "term.labels")
dev_nulo <- deviance(m_qpois_nulo)

importancia <- do.call(rbind, lapply(names(vars_imp), function(v) {
  # se quitan los terminos que contienen a v (efecto principal e interacciones)
  quedan <- terminos[!sapply(strsplit(terminos, ":"), function(z) v %in% z)]
  m_sin  <- update(m, reformulate(quedan, response = "count"))
  data.frame(Variable = v,
             Tipo     = vars_imp[[v]],
             Dev_Perdida_Pct = round(100 * (deviance(m_sin) - deviance(m)) / dev_nulo, 2))
}))
importancia <- importancia[order(-importancia$Dev_Perdida_Pct), ]
print(importancia, row.names = FALSE)

# Grafico de importancia
importancia$Variable <- factor(importancia$Variable, levels = rev(importancia$Variable))
print(
  ggplot(importancia, aes(x = Dev_Perdida_Pct, y = Variable, fill = Tipo)) +
    geom_col(width = 0.65) +
    geom_text(aes(label = sprintf("%.2f%%", Dev_Perdida_Pct)), hjust = -0.15, size = 3.5) +
    scale_fill_manual(values = c(Temporal = "steelblue", Meteorologica = "darkorange")) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.15))) +
    labs(title = "Importancia de cada variable en el modelo final",
         subtitle = "Devianza que se pierde al quitar la variable y sus interacciones (% de la devianza del modelo nulo)",
         x = "Devianza perdida (%)", y = NULL, fill = NULL) +
    theme_minimal()
)
ggsave("plots/03_efectos_importancia_variables.png", width = 9, height = 5, dpi = 300)

############## 3. Efectos promedio por prediccion (variables con interaccion)
# Idea: se predice con el modelo cambiando UNA sola variable y dejando todo lo demas igual
# a lo observado, y se compara el promedio de las predicciones:
#   efecto = mean(prediccion con el cambio) / mean(prediccion original)
# Asi el efecto ya incluye todas las interacciones de esa variable.

# Razon de medias predichas entre dos escenarios, por grupo
razon_pred <- function(datos_cambio, datos_base, grupo) {
  round(tapply(predict(m, newdata = datos_cambio, type = "response"), grupo, mean) /
          tapply(predict(m, newdata = datos_base, type = "response"), grupo, mean), 3)
}

# ---- 3a. Temperatura: +5 °C, segun estacion y segun franja horaria
d_temp5 <- d
d_temp5$temp <- d$temp + 5

cat("\nEfecto de +5 °C segun estacion (razon de arriendos esperados):\n")
print(razon_pred(d_temp5, d, d$seasons))

franja <- cut(as.numeric(as.character(d$hour)), breaks = c(-1, 5, 9, 16, 20, 23),
              labels = c("0-5", "6-9", "10-16", "17-20", "21-23"))
cat("\nEfecto de +5 °C segun franja horaria:\n")
print(razon_pred(d_temp5, d, franja))

# Curva de arriendos esperados segun temperatura, una por estacion.
# Para cada estacion: se toman sus horas, se fija la temperatura en cada valor de la grilla
# y se promedia la prediccion. La grilla se limita al rango observado en cada estacion
# (entre los percentiles 2.5 y 97.5) para no extrapolar.
curva_temp <- do.call(rbind, lapply(levels(factor(d$seasons)), function(s) {
  d_s    <- d[d$seasons == s, ]
  grilla <- seq(quantile(d_s$temp, 0.025), quantile(d_s$temp, 0.975), length.out = 40)
  data.frame(Estacion = s, temp = grilla,
             Arriendos = sapply(grilla, function(t) {
               d_s$temp <- t
               mean(predict(m, newdata = d_s, type = "response"))
             }))
}))
print(
  ggplot(curva_temp, aes(x = temp, y = Arriendos, color = Estacion)) +
    geom_line(linewidth = 1.2) +
    labs(title = "Arriendos esperados segun temperatura, por estacion",
         subtitle = "Promedio de las predicciones de m_fwd, cambiando solo la temperatura (rango observado de cada estacion)",
         x = "Temperatura (°C)", y = "Arriendos esperados por hora", color = "Estacion") +
    theme_minimal()
)
ggsave("plots/03_efectos_temperatura_por_estacion.png", width = 9, height = 5, dpi = 300)

# ---- 3b. Lluvia
# El efecto se evalua SOLO en las horas en que efectivamente llovio: se compara la
# prediccion con lluvia (lo observado) contra la misma hora si no hubiera llovido.
# No se evalua sobre todas las horas porque rain interactua con humidity y casi no hay
# lluvia con humedad baja (solo 8 de 516 horas con humedad <= 57%): ahi el modelo
# extrapola y da efectos absurdos (lluvia aumentando los arriendos).
llueve <- d$rain == "Yes"
d_lluvia     <- d[llueve, ]
d_sin_lluvia <- d_lluvia
d_sin_lluvia$rain <- factor("No", levels = levels(d$rain))

efecto_lluvia <- mean(predict(m, newdata = d_lluvia, type = "response")) /
  mean(predict(m, newdata = d_sin_lluvia, type = "response"))
cat("\nHumedad en horas con lluvia:\n")
print(summary(d$humidity[llueve]))
cat("Horas con lluvia y humedad <= 57%:", sum(llueve & d$humidity <= 57), "de", sum(llueve), "\n")
cat("Efecto de la lluvia (en horas que llovio): razon =", round(efecto_lluvia, 3),
    "->", round(100 * (efecto_lluvia - 1), 1), "% de arriendos\n")
cat("Observado: media con lluvia =", round(mean(d$count[llueve])),
    "| media sin lluvia =", round(mean(d$count[!llueve])), "\n")




# ---- 3c. Perfil horario: dia habil vs. fin de semana
tipo_dia <- factor(ifelse(d$weekday %in% c("Sábado", "Domingo"), "Fin de semana", "Dia habil"))
perfil <- data.frame(
  hora      = rep(0:23, 2),
  Tipo      = rep(levels(tipo_dia), each = 24),
  Predicho  = c(tapply(fitted(m)[tipo_dia == levels(tipo_dia)[1]], d$hour[tipo_dia == levels(tipo_dia)[1]], mean),
                tapply(fitted(m)[tipo_dia == levels(tipo_dia)[2]], d$hour[tipo_dia == levels(tipo_dia)[2]], mean)),
  Observado = c(tapply(d$count[tipo_dia == levels(tipo_dia)[1]], d$hour[tipo_dia == levels(tipo_dia)[1]], mean),
                tapply(d$count[tipo_dia == levels(tipo_dia)[2]], d$hour[tipo_dia == levels(tipo_dia)[2]], mean))
)
cat("\nArriendos predichos promedio por hora (horas seleccionadas):\n")
print(round(xtabs(Predicho ~ hora + Tipo, data = perfil)[c("4", "8", "13", "15", "18", "21"), ]))

print(
  ggplot(perfil, aes(x = hora, color = Tipo)) +
    geom_line(aes(y = Predicho), linewidth = 1.2) +
    geom_point(aes(y = Observado), size = 1.8, alpha = 0.6) +
    scale_x_continuous(breaks = seq(0, 23, 2)) +
    scale_color_manual(values = c("Dia habil" = "steelblue", "Fin de semana" = "darkorange")) +
    labs(title = "Perfil horario de arriendos: dia habil vs. fin de semana",
         subtitle = "Linea: promedio predicho por m_fwd | Puntos: promedio observado (coinciden: con enlace log y hour:weekday,\nel GLM reproduce exactamente el promedio de cada hora x dia)",
         x = "Hora del dia", y = "Arriendos por hora", color = NULL) +
    theme_minimal()
)
ggsave("plots/03_efectos_perfil_horario.png", width = 10, height = 5.5, dpi = 300)

# ---- 3d. Estacion: arriendos predichos promedio
cat("\nArriendos predichos promedio por estacion:\n")
print(round(tapply(fitted(m), d$seasons, mean)))
