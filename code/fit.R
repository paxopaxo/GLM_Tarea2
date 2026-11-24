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

# encaja con el phi_hat que estimamos antes
summary(m_qpois_0)

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

summary(m_qpois)

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


#ajuste de midelos con interacciones
m_int_hour_hol  <- update(m_qpois, . ~ . + hour:holiday)
m_int_hour_seas <- update(m_qpois, . ~ . + hour:seasons)
m_int_temp_seas <- update(m_qpois, . ~ . + temp:seasons)
m_int_temp_hum  <- update(m_qpois, . ~ . + temp:humidity)

# Pruebas F de devianza 
tvr_1 <- anova(m_qpois, m_int_hour_hol,  test = "F")
tvr_2 <- anova(m_qpois, m_int_hour_seas, test = "F")
tvr_3 <- anova(m_qpois, m_int_temp_seas, test = "F")
tvr_4 <- anova(m_qpois, m_int_temp_hum,  test = "F")

# Mostrar salidas individuales del test F
tvr_1
tvr_2
tvr_3
tvr_4


############## Comparacion de modelos con interacciones

comparacion_int <- data.frame(
  Modelo = c("Base (sin interacciones)",
             "+ hour:holiday",
             "+ hour:seasons",
             "+ temp:seasons",
             "+ temp:humidity"),
  Gl_Extra = c(0,
               tvr_1$Df[2],
               tvr_2$Df[2],
               tvr_3$Df[2],
               tvr_4$Df[2]),
  Devianza_Resid = c(deviance(m_qpois),
                     deviance(m_int_hour_hol),
                     deviance(m_int_hour_seas),
                     deviance(m_int_temp_seas),
                     deviance(m_int_temp_hum)),
  Reduccion_Dev_Pct = round(100 * (deviance(m_qpois) - c(deviance(m_qpois),
                                                         deviance(m_int_hour_hol),
                                                         deviance(m_int_hour_seas),
                                                         deviance(m_int_temp_seas),
                                                         deviance(m_int_temp_hum))) / deviance(m_qpois), 2),
  Phi_hat = round(c(summary(m_qpois)$dispersion,
                    summary(m_int_hour_hol)$dispersion,
                    summary(m_int_hour_seas)$dispersion,
                    summary(m_int_temp_seas)$dispersion,
                    summary(m_int_temp_hum)$dispersion), 2),
  Estadistico_F = round(c(NA, tvr_1$F[2], tvr_2$F[2], tvr_3$F[2], tvr_4$F[2]), 2),
  Valor_p = c(NA, tvr_1$`Pr(>F)`[2], tvr_2$`Pr(>F)`[2], tvr_3$`Pr(>F)`[2], tvr_4$`Pr(>F)`[2])
)

print(comparacion_int)


# 1. Modelos combinados (desde el más completo hacia abajo)
m_full <- update(m_qpois, . ~ . + temp:seasons + hour:seasons + hour:holiday + temp:humidity)
m_3int <- update(m_qpois, . ~ . + temp:seasons + hour:seasons + hour:holiday) # Sin temp:humidity
m_2int <- update(m_qpois, . ~ . + temp:seasons + hour:holiday)                # Las 2 más parsimoniosas

modelos <- list(
  "0. Base (sin int)"     = m_qpois,
  "1. + temp:seasons"     = m_int_temp_seas,
  "2. + temp:seas + h:hol"= m_2int,
  "3. 3 int (sin t:hum)"  = m_3int,
  "4. Full (4 int)"       = m_full
)

# 2. Tabla resumen comparativa (Devianza, % reducción, phi_hat y F vs Base)
resumen <- do.call(rbind, lapply(names(modelos), function(nom) {
  mod <- modelos[[nom]]
  tst <- if (nom == "0. Base (sin int)") list(Df = c(0,0), F = c(NA,NA), `Pr(>F)` = c(NA,NA)) else anova(m_qpois, mod, test = "F")
  data.frame(
    Modelo      = nom,
    Df_Extra    = tst$Df[2],
    Dev_Resid   = round(deviance(mod), 0),
    Red_Dev_Pct = round(100 * (deviance(m_qpois) - deviance(mod)) / deviance(m_qpois), 2),
    Phi_hat     = round(summary(mod)$dispersion, 2),
    F_vs_Base   = round(tst$F[2], 2),
    p_vs_Base   = signif(tst$`Pr(>F)`[2], 3)
  )
}))
print(resumen, row.names = FALSE)

# 3. Pruebas F anidadas paso a paso (¿vale la pena agregar más complejidad?)
anova(m_int_temp_seas, m_2int, m_3int, m_full, test = "F")

drop1(m_3int, test = "F")
drop1(m_int_temp_seas, test = "F")



# Gráfico Media-Varianza actualizado con el modelo Quasi-Poisson refinado (m_3int)
df_var <- data.frame(
  mu_hat = fitted(m_3int),
  res_sq = (bike_data$count - fitted(m_3int))^2
)
df_var$grupo <- cut(df_var$mu_hat,
                    breaks = quantile(df_var$mu_hat, probs = seq(0, 1, length.out = 16)),
                    include.lowest = TRUE)
resumen_var <- aggregate(cbind(mu_hat, res_sq) ~ grupo, data = df_var, FUN = mean)

phi_final <- summary(m_3int)$dispersion
theta_nb  <- m_nb$theta

# 2. Tabla de Razones de Tasas (IRR = exp(beta)) e IC 95% de wald para el modelo (m_int_temp_seas)

irr_parsimonioso <- exp(cbind(IRR = coef(m_int_temp_seas), confint.default(m_int_temp_seas)))
round(irr_parsimonioso, 4)


# Grafico media-varianza (m_3int vs m_int_temp_seas vs m_nb)

df_var <- data.frame(
  mu_hat = fitted(m_3int),
  res_sq = (bike_data$count - fitted(m_3int))^2
)
df_var$grupo <- cut(df_var$mu_hat,
                    breaks = quantile(df_var$mu_hat, probs = seq(0, 1, length.out = 16)),
                    include.lowest = TRUE)
resumen_var <- aggregate(cbind(mu_hat, res_sq) ~ grupo, data = df_var, FUN = mean)

phi_3int <- summary(m_3int)$dispersion
phi_1int <- summary(m_int_temp_seas)$dispersion
theta_nb <- m_nb$theta

plot(resumen_var$mu_hat, resumen_var$res_sq, pch = 19, col = "black",
     ylim = c(0, max(resumen_var$res_sq) * 1.15),
     xlab = expression("Media predicha (" * hat(mu) * ")"),
     ylab = expression("Varianza empírica " * (y - hat(mu))^2),
     main = "Estructura Media-Varianza: Modelos Quasi-Poisson vs. Binomial Negativa")

lines(resumen_var$mu_hat, phi_3int * resumen_var$mu_hat, col = "blue", lwd = 2, lty = 1)
lines(resumen_var$mu_hat, phi_1int * resumen_var$mu_hat, col = "darkgreen", lwd = 2, lty = 3)
lines(resumen_var$mu_hat, resumen_var$mu_hat + (resumen_var$mu_hat^2)/theta_nb, col = "red", lwd = 2, lty = 2)

legend("topleft",
       legend = c("Varianza empírica (15 cuantiles)",
                  paste0("Quasi-Poisson 3 int (phi = ", round(phi_3int, 2), ")"),
                  paste0("Quasi-Poisson temp:seasons (phi = ", round(phi_1int, 2), ")"),
                  paste0("Binomial Negativa (theta = ", round(theta_nb, 2), ")")),
       col = c("black", "blue", "darkgreen", "red"),
       pch = c(19, NA, NA, NA), lty = c(NA, 1, 3, 2), lwd = 2, bty = "n")


# Grafico Comparación directa de ajuste (Observado vs. Predicho)
#            Modelo menos parametros (m_int_temp_seas) vs. Modelo Completo (m_3int)

par(mfrow = c(1, 2))

plot(fitted(m_int_temp_seas), bike_data$count, pch = 16, cex = 0.4, col = rgb(0, 0.4, 0, 0.25),
     xlab = "Predicho (m_int_temp_seas)", ylab = "Conteo Observado",
     main = "Parsimonioso (+ temp:seasons)")
abline(0, 1, col = "black", lwd = 2, lty = 2)

plot(fitted(m_3int), bike_data$count, pch = 16, cex = 0.4, col = rgb(0, 0, 0.7, 0.25),
     xlab = "Predicho (m_3int)", ylab = "Conteo Observado",
     main = "Predictivo (3 interacciones)")
abline(0, 1, col = "black", lwd = 2, lty = 2)

par(mfrow = c(1, 1))




###########Diagnostico de residuos y puntos influyentes m_3_int

res_dev_std <- rstandard(m_3int, type = "deviance")
eta_hat     <- predict(m_3int, type = "link")
cooks_d     <- cooks.distance(m_3int)
leverage    <- hatvalues(m_3int)

par(mfrow = c(2, 2))

#  Residuos de devianza estandarizados vs. Predictor lineal 

#    Verifica linealidad en el enlace y ausencia de embudos sistemáticos
plot(eta_hat, res_dev_std, pch = 16, cex = 0.4, col = rgb(0, 0, 0.6, 0.25),
     xlab = expression("Predictor lineal (" * hat(eta) * ")"),
     ylab = "Residuos de devianza estandarizados",
     main = "A. Residuos vs. Predictor Lineal")
abline(h = c(-3, 0, 3), col = c("red", "black", "red"), lty = c(2, 1, 2))
lines(lowess(eta_hat, res_dev_std), col = "darkorange", lwd = 2)

# B. Residuos vs. Temperatura (chequeo de curvatura no lineal residual)
plot(bike_data$temp, res_dev_std, pch = 16, cex = 0.4, col = rgb(0, 0.5, 0, 0.25),
     xlab = "Temperatura (°C)",
     ylab = "Residuos de devianza estandarizados",
     main = "B. Residuos vs. Temperatura")
abline(h = 0, lty = 1)
lines(lowess(bike_data$temp, res_dev_std), col = "red", lwd = 2)

# C. Distancia de Cook (identificación de observaciones influyentes)
plot(cooks_d, type = "h", col = "steelblue",
     xlab = "Índice de observación", ylab = "Distancia de Cook",
     main = "C. Distancia de Cook (Influencia)")
umbral_cook <- 4 / nrow(bike_data)
abline(h = umbral_cook, col = "red", lty = 2)

# D. Autocorrelación temporal de los residuos (ACF)
#    Crítico en datos horarios consecutivos
acf(residuals(m_3int, type = "pearson"), main = "D. Autocorrelación Temporal (ACF)")

par(mfrow = c(1, 1))


# Observaciones influyentes y sensubulidad

# Top 5 observaciones con mayor Distancia de Cook
top_influyentes <- order(cooks_d, decreasing = TRUE)[1:5]
cbind(bike_data[top_influyentes, c("date", "hour", "count", "temp", "rain", "snow", "seasons")],
      mu_hat = round(fitted(m_3int)[top_influyentes], 1),
      res_std = round(res_dev_std[top_influyentes], 2),
      cook = round(cooks_d[top_influyentes], 5))

# Prueba de sensibilidad: reajustar sin las 5 observaciones más influyentes
m_3int_sin_inf <- update(m_3int, subset = -top_influyentes)

# Comparar cambio porcentual máximo en los coeficientes clave
dif_coef <- abs(coef(m_3int) - coef(m_3int_sin_inf))
cat("Máxima diferencia absoluta en coeficientes al quitar top 5 influyentes:", round(max(dif_coef), 4), "\n")
cat("Phi_hat original:", round(summary(m_3int)$dispersion, 2),
    "| Phi_hat sin top 5:", round(summary(m_3int_sin_inf)$dispersion, 2), "\n")

#Observamos que no cambia significativamente



##############  Análizamos sí  sobreajuste comparando ambos modelos finales
#################E gemini no cachaba como analizar esto hay que mirarlo XDDDD

# 1. Validación cruzada aleatoria de 10 pliegues (10-fold CV)
set.seed(123)
folds <- sample(rep(1:10, length.out = nrow(bike_data)))
err <- sapply(1:10, function(k) {
  tr <- bike_data[folds != k, ]
  te <- bike_data[folds == k, ]
  p1 <- predict(update(m_int_temp_seas, data = tr), newdata = te, type = "response")
  p3 <- predict(update(m_3int, data = tr), newdata = te, type = "response")
  c(RMSE_1int = sqrt(mean((te$count - p1)^2)), MAE_1int = mean(abs(te$count - p1)),
    RMSE_3int = sqrt(mean((te$count - p3)^2)), MAE_3int = mean(abs(te$count - p3)))
})

res_cv <- round(rowMeans(err), 2)
print(res_cv)

# 2. Brecha Train vs. Test y Criterio de Información Cuasi-AIC (QAIC)
phi_global <- summary(m_3int)$dispersion

calc_qaic <- function(mod_qpois, phi_g) {
  mod_p <- update(mod_qpois, family = poisson(link = "log"))
  k     <- length(coef(mod_qpois)) + 1
  -2 * as.numeric(logLik(mod_p)) / phi_g + 2 * k
}

rmse_train <- c(
  sqrt(mean((bike_data$count - fitted(m_int_temp_seas))^2)),
  sqrt(mean((bike_data$count - fitted(m_3int))^2))
)
rmse_cv <- unname(res_cv[c("RMSE_1int", "RMSE_3int")])

tabla_validacion <- data.frame(
  Modelo     = c("m_int_temp_seas (37 param)", "m_3int (129 param)"),
  RMSE_Train = round(rmse_train, 2),
  RMSE_CV    = rmse_cv,
  Brecha_CV  = round(rmse_cv - rmse_train, 2),
  QAIC       = round(c(calc_qaic(m_int_temp_seas, phi_global),
                       calc_qaic(m_3int, phi_global)), 1)
)
print(tabla_validacion, row.names = FALSE)

# 3. Validación cruzada por bloques temporales (días completos)
set.seed(123)
dias_unicos <- unique(bike_data$date)
folds_dias  <- sample(rep(1:10, length.out = length(dias_unicos)))
names(folds_dias) <- dias_unicos
bike_data$fold_dia <- folds_dias[as.character(bike_data$date)]

err_dias <- sapply(1:10, function(k) {
  tr <- bike_data[bike_data$fold_dia != k, ]
  te <- bike_data[bike_data$fold_dia == k, ]
  p1 <- predict(update(m_int_temp_seas, data = tr), newdata = te, type = "response")
  p3 <- predict(update(m_3int, data = tr), newdata = te, type = "response")
  c(RMSE_dia_1int = sqrt(mean((te$count - p1)^2)),
    RMSE_dia_3int = sqrt(mean((te$count - p3)^2)))
})
round(rowMeans(err_dias), 2)

#No praece haber sobre ajuste del modelo con el triple de parametros