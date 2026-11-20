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

m_nb <- glm.nb(count ~ hour + temp + humidity + wind + visibility +
                 solar_rad + rain + snow + seasons + holiday,
               data = bike_data)

summary(m_nb)

# multicolinealidad
vif(m_nb)
