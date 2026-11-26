############## Validacion cruzada por dias con distintas semillas
# Repite la CV por bloques de fit2.R con varias semillas, para mostrar que el resultado
# no depende de como cayeron los dias en los pliegues.
# Requiere en memoria: bike_data y los modelos a comparar (por ejemplo m_qpois y m_fwd de fit2.R).

seed_cv <- function(modelos, semillas = c(1, 42, 123, 2024, 777), k = 10, datos = bike_data) {
  dias <- unique(datos$date)

  # RMSE y MAE en entrenamiento: no dependen de la semilla, se calculan una sola vez
  rmse_train <- sapply(modelos, function(m) sqrt(mean((datos$count - fitted(m))^2)))
  mae_train  <- sapply(modelos, function(m) mean(abs(datos$count - fitted(m))))

  # Una fila por (semilla, modelo) con el RMSE y MAE promedio sobre los k pliegues
  por_semilla <- do.call(rbind, lapply(semillas, function(s) {
    set.seed(s)
    f <- sample(rep(1:k, length.out = length(dias)))
    names(f) <- dias
    folds <- f[as.character(datos$date)]

    do.call(rbind, lapply(names(modelos), function(nm) {
      err <- sapply(1:k, function(j) {
        tr <- datos[folds != j, ]
        te <- datos[folds == j, ]
        p  <- predict(update(modelos[[nm]], data = tr), newdata = te, type = "response")
        c(RMSE = sqrt(mean((te$count - p)^2)), MAE = mean(abs(te$count - p)))
      })
      data.frame(Semilla = s, Modelo = nm,
                 RMSE_CV = mean(err["RMSE", ]), MAE_CV = mean(err["MAE", ]))
    }))
  }))

  # Resumen por modelo: promedio y desviacion estandar entre semillas
  resumen <- do.call(rbind, lapply(names(modelos), function(nm) {
    d <- por_semilla[por_semilla$Modelo == nm, ]
    data.frame(
      Modelo          = nm,
      Parametros      = sum(!is.na(coef(modelos[[nm]]))),   # solo estimables (sin NA)
      RMSE_Train      = round(rmse_train[nm], 2),
      RMSE_CV_media   = round(mean(d$RMSE_CV), 2),
      RMSE_CV_sd      = round(sd(d$RMSE_CV), 2),
      Brecha_RMSE_Pct = round(100 * (mean(d$RMSE_CV) - rmse_train[nm]) / rmse_train[nm], 1),
      MAE_Train       = round(mae_train[nm], 2),
      MAE_CV_media    = round(mean(d$MAE_CV), 2),
      MAE_CV_sd       = round(sd(d$MAE_CV), 2),
      Brecha_MAE_Pct  = round(100 * (mean(d$MAE_CV) - mae_train[nm]) / mae_train[nm], 1)
    )
  }))

  por_semilla$RMSE_CV <- round(por_semilla$RMSE_CV, 2)
  por_semilla$MAE_CV  <- round(por_semilla$MAE_CV, 2)
  list(por_semilla = por_semilla, resumen = resumen)
}

# ---- Uso
res_seed <- seed_cv(list("Base (sin interacciones)" = m_qpois,
                         "Final (m_fwd)"            = m_fwd))
print(res_seed$por_semilla, row.names = FALSE)
print(res_seed$resumen, row.names = FALSE)

# probamos distintas semillas para ver que no depende de la semilla el sobreajuste