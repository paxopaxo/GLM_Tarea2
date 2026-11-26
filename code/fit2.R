library(MASS)
library(car)

m_pois <- glm(count ~ hour + temp + humidity + wind + visibility +
                solar_rad + seasons + holiday + rain + snow + weekday,
              family = poisson(link = "log"), data = bike_data)
summary(m_pois)

# X² / df -- si >>1 tiene sobredispersion
phi_hat <- sum(residuals(m_pois, type = "pearson")^2) / df.residual(m_pois)
phi_hat


bike_data %>%
  mutate(mu_hat = fitted(m_pois),
         pearson_sq = residuals(m_pois, type = "pearson")^2) %>%
  arrange(desc(pearson_sq)) %>%
  select(date, hour, count, rain, snow, mu_hat, pearson_sq) %>%
  head(5)

# binomial negativo
m_nb <- glm.nb(count ~ hour + temp + humidity + wind + visibility +
                 solar_rad + rain + snow + seasons + holiday + weekday,
               data = bike_data)

summary(m_nb)

# multicolinealidad
vif(m_nb)

# quasi-poisson
m_qpois_0 <- glm(count ~ hour + temp + humidity + wind + visibility +
                   solar_rad + rain + snow + seasons + holiday + weekday,
                 family = quasipoisson(link = "log"),
                 data = bike_data)

# phi_hat estimado por el modelo quasi-poisson (encaja con el calculado manualmente antes)
cat("phi_hat (m_qpois_0):", summary(m_qpois_0)$dispersion, "\n")

# visibility no aporta significativamente
drop1(m_qpois_0, test = "F")

# quasi-poisson sin visibility (drop1 arriba lo confirma)
m_qpois <- glm(count ~ hour + temp + humidity + wind +
                 solar_rad + rain + snow + seasons + holiday + weekday,
               family = quasipoisson(link = "log"),
               data = bike_data)
drop1(m_qpois, test = "F")

m_qpois_nulo <- glm(count ~ 1, family = quasipoisson(link = "log"), data = bike_data)
anova(m_qpois_nulo, m_qpois, test = "F")

# Multicolinealidad
vif(m_qpois)

### evidencia suficiente para elegir quasi-poisson
#############################################
# Agrupar en 15 cuantiles según la media predicha
df_var <- data.frame(
  mu_hat = fitted(m_qpois),
  res_sq = (bike_data$count - fitted(m_qpois))^2
)
df_var$grupo <- cut(
  df_var$mu_hat,
  breaks = quantile(df_var$mu_hat, probs = seq(0, 1, length.out = 16)),
  include.lowest = TRUE
)
resumen_var <- aggregate(cbind(mu_hat, res_sq) ~ grupo, data = df_var, FUN = mean)
# Parámetros estimados
phi_hat   <- summary(m_qpois_0)$dispersion
theta_hat <- m_nb$theta
# Gráfico comparativo con las 3 estructuras de varianza
plot(resumen_var$mu_hat, resumen_var$res_sq, pch = 19,
     ylim = c(0, max(resumen_var$res_sq) * 1.05),
     xlab = "Media predicha (mu_hat)",
     ylab = "Varianza empírica promedio",
     main = "Estructura Media-Varianza: Poisson vs Cuasi-Poisson vs Binomial Negativa")
# 1. Poisson estándar (phi = 1 -> Var = mu)
lines(resumen_var$mu_hat, resumen_var$mu_hat,
      col = "darkgreen", lwd = 2, lty = 3)
# 2. Cuasi-Poisson (Var = phi * mu)
lines(resumen_var$mu_hat, phi_hat * resumen_var$mu_hat,
      col = "blue", lwd = 2, lty = 1)
# 3. Binomial Negativa (Var = mu + mu^2 / theta)
lines(resumen_var$mu_hat, resumen_var$mu_hat + (resumen_var$mu_hat^2) / theta_hat,
      col = "red", lwd = 2, lty = 2)
legend("topleft",
       legend = c(
         "Poisson estándar (Var = mu, phi = 1)",
         paste0("Cuasi-Poisson (Var = ", round(phi_hat, 1), " * mu)"),
         paste0("Binomial Negativa (Var = mu + mu^2 / ", round(theta_hat, 2), ")")
       ),
       col = c("darkgreen", "blue", "red"),
       lwd = 2, lty = c(3, 1, 2), bty = "n")
#############################


############## Screening de todas las interacciones posibles (por pares)

# Variables predictoras del modelo base
vars_pred <- c("hour", "temp", "humidity", "wind", "solar_rad",
               "rain", "snow", "seasons", "holiday", "weekday")
# Genera todos los pares posibles
int_terms <- apply(combn(vars_pred, 2), 2, paste, collapse = ":")

# Para cada interacción: ajusta modelo, corre test F vs. base, extrae métricas
screening_int <- do.call(rbind, lapply(int_terms, function(x) {
  mod <- update(m_qpois, as.formula(paste(". ~ . +", x)))
  tst <- anova(m_qpois, mod, test = "F")
  data.frame(
    Interaccion = x,
    Df_Extra    = tst$Df[2],
    Red_Dev_Pct = round(100 * tst$Deviance[2] / deviance(m_qpois), 2),
    F_stat      = round(tst$F[2], 2),
    p_valor     = signif(tst$`Pr(>F)`[2], 3),
    Significativa = tst$`Pr(>F)`[2] < 0.05
  )
}))
# Ordenado por p-valor
screening_int <- screening_int[order(+screening_int$p_valor), ]
print(screening_int, row.names = FALSE)

############## Preseleccion de candidatas: significancia + relevancia practica
# Una interaccion es candidata si cumple ambas condiciones (cada una probada sola vs. m_qpois):
#  1. p-valor del test F < 0.05: el efecto es real (estadisticamente significativo del anova).
#  2. Reduce la devianza del modelo base en al menos un 2%: el efecto importa en la practica.
alfa_screening <- 0.05
umbral_dev     <- 2   # en %
candidatas <- screening_int$Interaccion[screening_int$p_valor < alfa_screening &
                                          screening_int$Red_Dev_Pct >= umbral_dev]
candidatas

# Tabla de F de las candidatas contra el modelo base (un solo add1, rapido)
tabla_F0 <- add1(m_qpois, scope = as.formula(paste("~ . +", paste(candidatas, collapse = " + "))),
                 test = "F")
tabla_F0 <- tabla_F0[rownames(tabla_F0) != "<none>", ]
tabla_F0[order(-tabla_F0$`F value`), c("Df", "Deviance", "F value", "Pr(>F)")]


############## Seleccion hacia adelante entre las candidatas
# Criterio: en cada paso se agrega la candidata con mayor F (vs. el modelo actual),
# siempre que su p-valor sea < alfa. Si la mejor candidata no lo cumple, se detiene.

alfa <- 0.05
m_act <- m_qpois
restantes <- candidatas
pasos <- data.frame(Paso = 0, Agregada = "(base)", Df_Extra = NA, F_stat = NA,
                    p_valor = NA)

repeat {
  if (length(restantes) == 0) break
  a <- add1(m_act, scope = as.formula(paste("~ . +", paste(restantes, collapse = " + "))),
            test = "F")
  a <- a[rownames(a) != "<none>", ]
  mejor <- rownames(a)[which.max(a$`F value`)]
  m_new <- update(m_act, as.formula(paste(". ~ . +", mejor)))
  p_mejor <- a[mejor, "Pr(>F)"]
  if (p_mejor >= alfa) break
  m_act <- m_new
  restantes <- setdiff(restantes, mejor)
  pasos <- rbind(pasos, data.frame(Paso = nrow(pasos), Agregada = mejor,
                                   Df_Extra = a[mejor, "Df"],
                                   F_stat = round(a[mejor, "F value"], 2),
                                   p_valor = signif(p_mejor, 3)))
}
print(pasos, row.names = FALSE)

m_fwd <- m_act
formula(m_fwd)
cat("phi_hat (m_fwd):", summary(m_fwd)$dispersion, "| parametros:", length(coef(m_fwd)), "\n")


############## Aporta cada termino? (test F al quitar cada uno de m_fwd)
# Para las interacciones, drop1 respeta la jerarquia: solo prueba quitar terminos
# que no estan contenidos en otro de orden superior.
drop1(m_fwd, test = "F")


############## Diagnostico de residuos y puntos influyentes (m_fwd)

res_dev_std <- rstandard(m_fwd, type = "deviance")
eta_hat     <- predict(m_fwd, type = "link")
cooks_d     <- cooks.distance(m_fwd)

par(mfrow = c(2, 2))

# A. Residuos de devianza estandarizados vs. predictor lineal
#    Verifica linealidad en el enlace y ausencia de embudos sistematicos
plot(eta_hat, res_dev_std, pch = 16, cex = 0.4, col = rgb(0, 0, 0.6, 0.25),
     xlab = expression("Predictor lineal (" * hat(eta) * ")"),
     ylab = "Residuos de devianza estandarizados",
     main = "A. Residuos vs. Predictor Lineal")
abline(h = c(-3, 0, 3), col = c("red", "black", "red"), lty = c(2, 1, 2))
lines(lowess(eta_hat, res_dev_std), col = "darkorange", lwd = 2)

# B. Residuos vs. temperatura (curvatura no lineal residual)
plot(bike_data$temp, res_dev_std, pch = 16, cex = 0.4, col = rgb(0, 0.5, 0, 0.25),
     xlab = "Temperatura (°C)",
     ylab = "Residuos de devianza estandarizados",
     main = "B. Residuos vs. Temperatura")
abline(h = 0, lty = 1)
lines(lowess(bike_data$temp, res_dev_std), col = "red", lwd = 2)

# C. Distancia de Cook (observaciones influyentes)
plot(cooks_d, type = "h", col = "steelblue",
     xlab = "Índice de observación", ylab = "Distancia de Cook",
     main = "C. Distancia de Cook (Influencia)")
abline(h = 4 / nrow(bike_data), col = "red", lty = 2)

# D. Autocorrelacion temporal de los residuos (datos horarios consecutivos)
acf(residuals(m_fwd, type = "pearson"), main = "D. Autocorrelación Temporal (ACF)")

par(mfrow = c(1, 1))

# A2. Mismo grafico, agrupado en bins con igual numero de observaciones.
#     En A hay pocos puntos con eta bajo y es dificil ver una tendencia. Aqui cada punto
#     es el promedio de ~n/30 observaciones, con barras de +-2 errores estandar:
#     si el modelo ajusta bien, los promedios deben estar cerca de 0 y sin forma.
n_bins <- 30
bins <- cut(eta_hat, breaks = unique(quantile(eta_hat, probs = seq(0, 1, length.out = n_bins + 1))),
            include.lowest = TRUE)
bin_df <- data.frame(
  eta = tapply(eta_hat, bins, mean),
  res = tapply(res_dev_std, bins, mean),
  se  = tapply(res_dev_std, bins, function(x) sd(x) / sqrt(length(x)))
)

plot(bin_df$eta, bin_df$res, pch = 16, col = "darkblue",
     ylim = range(bin_df$res - 2 * bin_df$se, bin_df$res + 2 * bin_df$se),
     xlab = expression("Predictor lineal (" * hat(eta) * "), promedio por bin"),
     ylab = "Residuo estandarizado promedio",
     main = "A2. Residuos Promedio por Bin del Predictor Lineal")
arrows(bin_df$eta, bin_df$res - 2 * bin_df$se, bin_df$eta, bin_df$res + 2 * bin_df$se,
       angle = 90, code = 3, length = 0.03, col = "darkblue")
abline(h = 0, col = "red", lty = 2)
lines(bin_df$eta, bin_df$res, col = "darkorange", lwd = 2)


############## Observaciones influyentes y sensibilidad

# Top 5 observaciones con mayor distancia de Cook
top_influyentes <- order(cooks_d, decreasing = TRUE)[1:10]
cbind(bike_data[top_influyentes, c("date", "hour", "count", "temp", "rain", "snow", "seasons")],
      mu_hat  = round(fitted(m_fwd)[top_influyentes], 1),
      res_std = round(res_dev_std[top_influyentes], 2),
      cook    = round(cooks_d[top_influyentes], 5))

# Reajustar sin las observaciones influyentes y comparar coeficientes
m_fwd_sin_inf <- update(m_fwd, subset = -top_influyentes)

# Diferencia absoluta (escala log) de cada coeficiente entre el modelo con todos los datos
# y el modelo sin las observaciones influyentes. Los coeficientes no estimables (NA, por
# ejemplo en hour:solar_rad) se ignoran con na.rm = TRUE.

dif_coef <- abs(coef(m_fwd) - coef(m_fwd_sin_inf))
cat("Máxima diferencia absoluta en coeficientes al quitar top", length(top_influyentes),
    "influyentes:", round(max(dif_coef, na.rm = TRUE), 4),
    "(", names(which.max(dif_coef)), ")\n")

# Los 5 coeficientes que mas cambian (exp(dif) - 1 = cambio relativo en la razon de tasas)
mas_cambian <- sort(dif_coef, decreasing = TRUE)[1:5]
print(round(data.frame(Dif_abs = mas_cambian, Cambio_rel_pct = 100 * (exp(mas_cambian) - 1)), 4))
cat("Phi_hat original:", round(summary(m_fwd)$dispersion, 2),
    "| Phi_hat sin top", length(top_influyentes), ":", round(summary(m_fwd_sin_inf)$dispersion, 2), "\n")


############## Validacion cruzada por bloques (dias completos): descartar sobreajuste
# Se compara el modelo final (m_fwd) contra el modelo base sin interacciones.
# En cada vuelta k: se ajusta con los bloques != k (tr) y se predice el bloque k (te),
# que el modelo no vio. Cada fila se predice exactamente una vez.
# Bloques = dias completos: las 24 horas de un dia se parecen entre si, asi que
# repartirlas al azar entre train y test haria el error artificialmente bajo.

# ---- Parametros editables de la validacion cruzada 
semilla_cv <- 123   # semilla
k_pliegues <- 10    # bloques de dias

modelos_cv <- list(
  "Base (sin interacciones)" = m_qpois,
  "Final (m_fwd)"            = m_fwd
)

# Pliegues por bloques: cada dia completo se asigna a uno de k_pliegues pliegues
set.seed(semilla_cv)
dias_unicos <- unique(bike_data$date)
folds_dias  <- sample(rep(1:k_pliegues, length.out = length(dias_unicos)))
names(folds_dias) <- dias_unicos
folds_por_dia <- folds_dias[as.character(bike_data$date)]

# Reajusta cada modelo en k_pliegues vueltas; devuelve RMSE y MAE promedio sobre los pliegues de test
cv_bloques <- function(modelos, folds) {
  res <- sapply(modelos, function(mod) {
    err <- sapply(1:k_pliegues, function(k) {
      tr <- bike_data[folds != k, ]
      te <- bike_data[folds == k, ]
      p  <- predict(update(mod, data = tr), newdata = te, type = "response")
      c(RMSE = sqrt(mean((te$count - p)^2)), MAE = mean(abs(te$count - p)))
    })
    rowMeans(err)
  })
  t(res)
}
cv_dias <- cv_bloques(modelos_cv, folds_por_dia)

# Error en entrenamiento (mismos datos con que se ajusta cada modelo)
rmse_train <- sapply(modelos_cv, function(m) sqrt(mean((bike_data$count - fitted(m))^2)))
mae_train  <- sapply(modelos_cv, function(m) mean(abs(bike_data$count - fitted(m))))

tabla_cv <- data.frame(
  Modelo       = names(modelos_cv),
  Parametros   = sapply(modelos_cv, function(m) length(coef(m))),
  RMSE_Train   = round(rmse_train, 2),
  RMSE_CV      = round(cv_dias[, "RMSE"], 2),
  Brecha_RMSE  = round(cv_dias[, "RMSE"] - rmse_train, 2),
  Brecha_RMSE_Pct = round(100 * (cv_dias[, "RMSE"] - rmse_train) / rmse_train, 1),
  MAE_Train    = round(mae_train, 2),
  MAE_CV       = round(cv_dias[, "MAE"], 2),
  Brecha_MAE   = round(cv_dias[, "MAE"] - mae_train, 2),
  Brecha_MAE_Pct  = round(100 * (cv_dias[, "MAE"] - mae_train) / mae_train, 1)
)
print(tabla_cv, row.names = FALSE)

# Interpretacion (sobreajuste):
# - Train: error en los mismos datos con que se ajusto el modelo (optimista).
# - CV: error en dias que el modelo NO vio al ajustarse (honesto).
# - Brecha = CV - Train. Si el modelo "memorizara" los datos de entrenamiento, el error
#   de train seria bajo y el de CV mucho mas alto (brecha grande).
# - Se concluye que no hay sobreajuste si la brecha del modelo final es pequena en
#   terminos relativos y comparable a la del modelo base (que tiene muchos menos parametros).
# - Ademas, el RMSE/MAE de CV del modelo final debe ser menor que el de la base: la
#   mejora se mantiene en dias no vistos, no solo en entrenamiento.


############## 1. Gráfico media-varianza sobre el modelo final (m_fwd)
df_var_fwd <- data.frame(
  mu_hat = fitted(m_fwd),
  res_sq = (bike_data$count - fitted(m_fwd))^2
)
df_var_fwd$grupo <- cut(
  df_var_fwd$mu_hat,
  breaks = quantile(df_var_fwd$mu_hat, probs = seq(0, 1, length.out = 16)),
  include.lowest = TRUE
)
resumen_var_fwd <- aggregate(cbind(mu_hat, res_sq) ~ grupo, data = df_var_fwd, FUN = mean)

phi_fwd <- summary(m_fwd)$dispersion
# Ajustamos NB con la misma fórmula de m_fwd solo para comparar la curva cuadrática
m_nb_fwd <- glm.nb(formula(m_fwd), data = bike_data)
theta_fwd <- m_nb_fwd$theta

plot(resumen_var_fwd$mu_hat, resumen_var_fwd$res_sq, pch = 19,
     ylim = c(0, max(resumen_var_fwd$res_sq) * 1.05),
     xlab = "Media predicha (mu_hat)",
     ylab = "Varianza empírica promedio",
     main = "Estructura Media-Varianza en el Modelo Final (m_fwd)")
lines(resumen_var_fwd$mu_hat, resumen_var_fwd$mu_hat,
      col = "darkgreen", lwd = 2, lty = 3)
lines(resumen_var_fwd$mu_hat, phi_fwd * resumen_var_fwd$mu_hat,
      col = "blue", lwd = 2, lty = 1)
lines(resumen_var_fwd$mu_hat, resumen_var_fwd$mu_hat + (resumen_var_fwd$mu_hat^2) / theta_fwd,
      col = "red", lwd = 2, lty = 2)
legend("topleft",
       legend = c(
         "Poisson estándar (Var = mu, phi = 1)",
         paste0("Cuasi-Poisson final (Var = ", round(phi_fwd, 1), " * mu)"),
         paste0("Binomial Negativa (Var = mu + mu^2 / ", round(theta_fwd, 2), ")")
       ),
       col = c("darkgreen", "blue", "red"),
       lwd = 2, lty = c(3, 1, 2), bty = "n")


############## 2. Tabla comparativa ANOVA de modelos anidados
anova_anidados <- anova(m_qpois_nulo, m_qpois, m_fwd, test = "F")
print(anova_anidados)

# Resumen limpio con % de devianza explicada y phi_hat para el informe
modelos_resumen <- list(
  "1. Nulo (solo intercepto)" = m_qpois_nulo,
  "2. Base aditivo (sin visibility)" = m_qpois,
  "3. Final con interacciones (m_fwd)" = m_fwd
)

tabla_anidados <- data.frame(
  Modelo      = names(modelos_resumen),
  Parametros  = sapply(modelos_resumen, function(m) length(coef(m))),
  GL_Res      = sapply(modelos_resumen, df.residual),
  Dev_Res     = round(sapply(modelos_resumen, deviance), 0),
  Dev_Exp_Pct = round(100 * (1 - sapply(modelos_resumen, deviance) / deviance(m_qpois_nulo)), 2),
  Phi_hat     = round(sapply(modelos_resumen, function(m) summary(m)$dispersion), 2),
  F_vs_prev   = c(NA, round(anova_anidados$F[2], 2), round(anova_anidados$F[3], 2)),
  p_valor     = c(NA, signif(anova_anidados$`Pr(>F)`[2], 3), signif(anova_anidados$`Pr(>F)`[3], 3))
)
print(tabla_anidados, row.names = FALSE)