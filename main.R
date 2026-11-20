bike_data <- read.csv(
  "data/SeoulBikeData.csv",
  fileEncoding = "latin1",
  check.names = FALSE
)

# renombramos los nombres para mayor claridad 
names(bike_data) <- c(
  "date", "count", "hour", "temp", "humidity", "wind",
  "visibility", "dew_point", "solar_rad", "rainfall",
  "snowfall", "seasons", "holiday", "functioning_day"
)

