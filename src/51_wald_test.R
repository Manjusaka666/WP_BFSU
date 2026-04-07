#!/usr/bin/env Rscript
# 51_wald_test.R — Formal Wald test: H0: beta_meat = beta_grain

suppressPackageStartupMessages({
  library(data.table)
  library(fixest)
})

source(file.path("src", "00_project_utils.R"))
ensure_paths()

cfps <- fread(file.path(project_paths$processed, "cfps_panel.csv"))
cfps <- cfps[!is.na(meat_shock) & !is.na(price_exp) & province > 0]
cfps[, region_wave := paste0(region, "_", wave)]
cfps[, province_factor := as.factor(province)]
cfps[, wave_factor := as.factor(wave)]

# Horse-race: region×wave FE
m1 <- feols(price_exp ~ meat_shock + grain_shock | region_wave,
            data = cfps[!is.na(grain_shock)], vcov = ~province)

b1 <- coef(m1); V1 <- vcov(m1)
d1 <- b1["meat_shock"] - b1["grain_shock"]
se1 <- sqrt(V1["meat_shock","meat_shock"] + V1["grain_shock","grain_shock"] - 2*V1["meat_shock","grain_shock"])
t1 <- d1 / se1
# Use Satterthwaite-like df approximation: G - 1 where G = number of clusters
p1 <- 2 * pt(-abs(t1), df = 30)

cat("=== Region×wave FE ===\n")
cat(sprintf("beta_meat  = %.4f (SE = %.4f)\n", b1["meat_shock"], sqrt(V1["meat_shock","meat_shock"])))
cat(sprintf("beta_grain = %.4f (SE = %.4f)\n", b1["grain_shock"], sqrt(V1["grain_shock","grain_shock"])))
cat(sprintf("Difference = %.4f, SE = %.4f, t = %.4f, p = %.4f\n", d1, se1, t1, p1))

# Horse-race: province + wave FE
m2 <- feols(price_exp ~ meat_shock + grain_shock | province_factor + wave_factor,
            data = cfps[!is.na(grain_shock)], vcov = ~province)

b2 <- coef(m2); V2 <- vcov(m2)
d2 <- b2["meat_shock"] - b2["grain_shock"]
se2 <- sqrt(V2["meat_shock","meat_shock"] + V2["grain_shock","grain_shock"] - 2*V2["meat_shock","grain_shock"])
t2 <- d2 / se2
p2 <- 2 * pt(-abs(t2), df = 30)

cat("\n=== Province + wave FE ===\n")
cat(sprintf("beta_meat  = %.4f (SE = %.4f)\n", b2["meat_shock"], sqrt(V2["meat_shock","meat_shock"])))
cat(sprintf("beta_grain = %.4f (SE = %.4f)\n", b2["grain_shock"], sqrt(V2["grain_shock","grain_shock"])))
cat(sprintf("Difference = %.4f, SE = %.4f, t = %.4f, p = %.4f\n", d2, se2, t2, p2))

# Forecast error horse-race
cfps_fe <- cfps[!is.na(fe_clean) & !is.na(grain_shock)]

m3 <- feols(fe_clean ~ meat_shock + grain_shock | region_wave,
            data = cfps_fe, vcov = ~province)
b3 <- coef(m3); V3 <- vcov(m3)
d3 <- b3["meat_shock"] - b3["grain_shock"]
se3 <- sqrt(V3["meat_shock","meat_shock"] + V3["grain_shock","grain_shock"] - 2*V3["meat_shock","grain_shock"])
t3 <- d3 / se3
p3 <- 2 * pt(-abs(t3), df = 30)

cat("\n=== Forecast error, Region×wave FE ===\n")
cat(sprintf("beta_meat  = %.4f (SE = %.4f)\n", b3["meat_shock"], sqrt(V3["meat_shock","meat_shock"])))
cat(sprintf("beta_grain = %.4f (SE = %.4f)\n", b3["grain_shock"], sqrt(V3["grain_shock","grain_shock"])))
cat(sprintf("Difference = %.4f, SE = %.4f, t = %.4f, p = %.4f\n", d3, se3, t3, p3))

cat("\nDone.\n")
