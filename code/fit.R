library(MASS)
library(car)

m_pois <- glm(count ~ hour + temp + humidity + wind + visibility +
                solar_rad + seasons + holiday+ rain + snow,
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
                 solar_rad + rain + snow + seasons + holiday,
               data = bike_data)

summary(m_nb)

# multicolinealidad
vif(m_nb)

# quasi-poisson
m_qpois_0 <- glm(count ~ hour + temp + humidity + wind + visibility +
                 solar_rad + rain + snow + seasons + holiday,
               family = quasipoisson(link = "log"),
               data = bike_data)

# encaja con el phi_hat que estimamos antes
summary(m_qpois_0)

# visibility no aporta significativamente
drop1(m_qpois, test = "F")

# quasi-poisson sin visibility
m_qpois <- glm(count ~ hour + temp + humidity + wind +
                 solar_rad + rain + snow + seasons + holiday,
               family = quasipoisson(link = "log"),
               data = bike_data)
drop1(m_qpois, test = "F")

m_qpois_nulo <- glm(count ~ 1, family = quasipoisson(link = "log"), data = bike_data)

anova(m_qpois_nulo, m_qpois, test = "F")

# Multicolinealidad
vif(m_qpois)





### esto hay que validarlo. 

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
phi_hat   <- summary(m_qpois)$dispersion
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


