# Load libraries
library(tidyverse)
library(zoo)
library(raster)
library(viridis)

# Load your data
df <- read.csv("example_data.csv")

# Compute cumulative temperature
df$cum_trt2 <- df$trt_2 * df$day

# Map trt1 to µM numeric values
trt1_map <- c("level0" = 0, "level1" = 20, "level2" = 40, "level3" = 80)
df$trt1_um <- trt1_map[df$trt_1]

# Summarize response_values per treatment (mean)
df_summ <- df %>%
  group_by(cum_trt2, trt1_um) %>%
  summarise(response_values = mean(response_values, na.rm = TRUE), .groups = "drop")

# Spread data into matrix
response_values_matrix <- tapply(df_summ$response_values, list(df_summ$cum_trt2, df_summ$trt1_um), mean)

# Check and re-order matrix to have cumulative temperature increasing bottom-up
response_values_matrix <- response_values_matrix[nrow(response_values_matrix):1, ]

# Fill in missing values with last observation carried forward (optional)
response_values_matrix <- na.locf(response_values_matrix, na.rm = FALSE)
response_values_matrix <- na.locf(response_values_matrix, fromLast = TRUE)

# Convert to raster
Lraster <- raster(array(NA, dim = c(50, 50)))
r_response_values <- raster(response_values_matrix)
r_response_values <- resample(r_response_values, Lraster)

# Clip extremes if needed
r_response_values[r_response_values < -2] <- -2
r_response_values[r_response_values > 4] <- 4

# 1) Define non-uniform breakpoints: finer resolution above 0
breakpoints <- c(
  seq(minValue(r_response_values), 0, length.out = 3),      # 5 bins ≤ 0
  seq(0.1, maxValue(r_response_values), length.out = 24)    # 20 bins > 0
)
# 2) Build a brown→blue palette with exactly length(breakpoints)-1 colors
color_palette <- viridis(length(breakpoints) - 1)

# 3) Main raster plot (no legend)
par(mar = c(5, 5, 4, 4), font.axis = 2)
plot(
  r_response_values,
  col        = color_palette,
  breaks     = breakpoints,
  axes      = FALSE,
  box        = FALSE,
  legend     = FALSE
)
plot(
  rasterToPolygons(r_response_values),
  add     = TRUE,
  border  = adjustcolor("black", alpha.f = 0.1),
  lwd     = 1
)

# 4) Custom axes (y now low→high bottom→top)
axis(
  side   = 1,
  at     = seq(0.125, 0.875, length.out = 4),
  labels = c("0", "20", "40", "80"),
  cex.axis = 0.9,
  pos    = -0.01
)
tmp_vals   <- sort(unique(df_summ$cum_trt2))
tmp_ticks  <- seq(0.1, 0.9, length.out = length(tmp_vals))
axis(
  side   = 2,
  at     = tmp_ticks,
  labels = round(tmp_vals),
  cex.axis = 0.9,
  pos    = -0.01
)
axis(
  side   = 1,
  line   = 1.5,
  at     = 0.5,
  labels = 'Treatment_1',
  tick   = FALSE,
  cex.axis = 1.4,
  font   = 2
)
axis(
  side   = 2,
  line   = 1.5,
  at     = 0.5,
  labels = "Cumulative treatment_2",
  tick   = FALSE,
  cex.axis = 1.4,
  font   = 2
)

# 5) Single legend call (uses same breaks + palette)
plot(
  r_response_values,
  legend.only   = TRUE,
  col           = color_palette,
  breaks        = breakpoints,
  legend.width  = 1.5,
  legend.shrink = 0.9,
  axis.args     = list(at = breakpoints, labels = round(breakpoints, 2), cex.axis = 0.8),
  legend.args   = list(
    text = expression(bold("response_values")),
    side = 2,
    font = 2,
    line = 1.5,
    cex  = 1
  )
)
