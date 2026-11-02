# V05 — Monte Carlo: yanlılık hesabında ölçek, "gerçek değer" tanımı, göreli yanlılık ve tohum şeması
suppressPackageStartupMessages({ library(lavaan); library(MASS); library(pbivnorm) })
cat("R:", R.version.string, "| lavaan:", as.character(packageVersion("lavaan")), "\n\n")

# Popülasyon: 2 faktör, 6+6 madde, standardize yük .70, faktör korelasyonu .40, 5 kategori
p <- 12; lam <- rep(.70, p); fac <- rep(1:2, each = 6); phi <- .40
Lambda <- matrix(0, p, 2); Lambda[cbind(1:p, fac)] <- lam
Psi <- matrix(c(1, phi, phi, 1), 2)
Theta <- diag(1 - diag(Lambda %*% Psi %*% t(Lambda)))
SigmaStar <- Lambda %*% Psi %*% t(Lambda) + Theta          # var(y*) = 1
tau <- qnorm(cumsum(c(.10, .20, .40, .20))[1:4])            # kategori oranları .10/.20/.40/.20/.10
gen <- function(n) {
  ys <- mvrnorm(n, rep(0, p), SigmaStar)
  y <- matrix(findInterval(ys, tau) + 1L, n, p); colnames(y) <- paste0("y", 1:p); as.data.frame(y)
}
model <- paste0("F1 =~ ", paste0("y", 1:6, collapse = " + "), "\nF2 =~ ", paste0("y", 7:12, collapse = " + "))

cat("== (a) WLSMV'de parametre ölçeği: üretim değeri λ = .70 (standardize) ==\n")
set.seed(1); d <- gen(2000)
f_theta <- cfa(model, d, ordered = names(d), estimator = "WLSMV", std.lv = TRUE, parameterization = "theta")
f_delta <- cfa(model, d, ordered = names(d), estimator = "WLSMV", std.lv = TRUE, parameterization = "delta")
l_theta <- mean(parameterEstimates(f_theta)$est[parameterEstimates(f_theta)$op == "=~"])
l_std   <- mean(standardizedSolution(f_theta)$est.std[standardizedSolution(f_theta)$op == "=~"])
l_delta <- mean(parameterEstimates(f_delta)$est[parameterEstimates(f_delta)$op == "=~"])
cat(sprintf("theta ham λ ort. = %.3f (kuramsal: .70/sqrt(.51) = %.3f) | std.all = %.3f | delta ham = %.3f\n",
            l_theta, .70 / sqrt(.51), l_std, l_delta))
cat(sprintf("theta ham değeri .70 ile karşılaştırılırsa 'göreli yanlılık' = %+.1f%% (yanlış ölçek)\n", 100 * (l_theta - .70) / .70))

cat("\n== (b) Sıralı veriye ML: tahmin edilen nicelik (estimand) üretim değeri değildir ==\n")
# Kesikli gözlenen puanların KESİN popülasyon kovaryansı (iki değişkenli normal olasılıklarından)
cuts <- c(-Inf, tau, Inf); C <- length(cuts) - 1L
marg <- diff(pnorm(cuts)); mu_y <- sum(seq_len(C) * marg); var_y <- sum(seq_len(C)^2 * marg) - mu_y^2
cov_pair <- function(rho) {
  P <- matrix(0, C, C)
  F2 <- function(a, b) { if (is.infinite(a) && a < 0) return(0); if (is.infinite(b) && b < 0) return(0)
    if (is.infinite(a) && is.infinite(b)) return(1); if (is.infinite(a)) return(pnorm(b)); if (is.infinite(b)) return(pnorm(a))
    pbivnorm(a, b, rho) }
  for (i in 1:C) for (j in 1:C)
    P[i, j] <- F2(cuts[i + 1], cuts[j + 1]) - F2(cuts[i], cuts[j + 1]) - F2(cuts[i + 1], cuts[j]) + F2(cuts[i], cuts[j])
  sum(outer(1:C, 1:C) * P) - mu_y^2
}
Sy <- matrix(var_y, p, p)
for (i in 1:(p - 1)) for (j in (i + 1):p) Sy[i, j] <- Sy[j, i] <- cov_pair(SigmaStar[i, j])
dimnames(Sy) <- list(paste0("y", 1:p), paste0("y", 1:p))
t0 <- proc.time()[3]
f_pop <- cfa(model, sample.cov = Sy, sample.nobs = 1e6, std.lv = TRUE)
t_pop <- proc.time()[3] - t0
pt_std <- standardizedSolution(f_pop)
lam_pop <- pt_std$est.std[pt_std$op == "=~"]; phi_pop <- pt_std$est.std[pt_std$op == "~~" & pt_std$lhs == "F1" & pt_std$rhs == "F2"]
cat(sprintf("Kesin popülasyon (sözde-gerçek) değer, ML std.all: λ = %.4f, φ = %.4f  [%.2f sn]\n", mean(lam_pop), phi_pop, t_pop))
set.seed(2); t0 <- proc.time()[3]; dbig <- gen(200000)
f_big <- cfa(model, dbig, std.lv = TRUE)
t_big <- proc.time()[3] - t0
sb <- standardizedSolution(f_big)
cat(sprintf("N = 200.000 örneklem, ML std.all:              λ = %.4f, φ = %.4f  [%.2f sn]\n",
            mean(sb$est.std[sb$op == "=~"]), sb$est.std[sb$op == "~~" & sb$lhs == "F1" & sb$rhs == "F2"], t_big))
cat(sprintf("Fark (yük başına en büyük |fark|): %.5f\n", max(abs(sb$est.std[sb$op == "=~"] - lam_pop))))
cat(sprintf("Üretim değerleri: λ = .70, φ = .40 -> ML-sıralı sözde-gerçek değerden sapma: Δλ = %.4f, Δφ = %.4f\n",
            mean(lam_pop) - .70, phi_pop - .40))

cat("\n== (c) N = 200.000'de WLSMV süresi (gerçek değer için önerilen yöntemin maliyeti) ==\n")
t0 <- proc.time()[3]
f_bigw <- cfa(model, dbig, ordered = names(dbig), estimator = "WLSMV", std.lv = TRUE, se = "none", test = "none")
cat(sprintf("WLSMV, N = 200.000, se/test kapalı: %.1f sn | λ ort. (std.all) = %.4f\n",
            proc.time()[3] - t0, mean(standardizedSolution(f_bigw)$est.std[standardizedSolution(f_bigw)$op == "=~"])))

cat("\n== (d) Gerçek değeri sıfıra yakın parametrede göreli yanlılık ==\n")
set.seed(3); R <- 200; n <- 300; est <- numeric(R)
Psi0 <- matrix(c(1, .02, .02, 1), 2); Sig0 <- Lambda %*% Psi0 %*% t(Lambda) + Theta
for (r in 1:R) { y <- as.data.frame(mvrnorm(n, rep(0, p), Sig0)); names(y) <- paste0("y", 1:p)
  pe <- parameterEstimates(cfa(model, y, std.lv = TRUE)); est[r] <- pe$est[pe$op == "~~" & pe$lhs == "F1" & pe$rhs == "F2"] }
bias <- mean(est) - .02
cat(sprintf("φ = .02: ortalama tahmin = %.4f | ham yanlılık = %+.4f | göreli yanlılık = %+.1f%% | standardize yanlılık (bias/SD) = %+.1f%% | MCSE(ort.) = %.4f\n",
            mean(est), bias, 100 * bias / .02, 100 * bias / sd(est), sd(est) / sqrt(R)))

cat("\n== (e) Tohum şeması: seed + 10000*koşul + tekrar ==\n")
s0 <- 20261030
seeds <- function(ncond, R) as.vector(outer(1:R, 1:ncond, function(r, k) s0 + 10000 * k + r))
for (R in c(1000, 9999, 10000, 12000)) { s <- seeds(16, R); cat(sprintf("R = %5d, 16 koşul: çakışan tohum sayısı = %d\n", R, sum(duplicated(s)))) }
g1 <- expand.grid(N = c(300, 600, 1000, 1500), oran = c("50/50", "70/30"), stringsAsFactors = FALSE)
g2 <- expand.grid(oran = c("50/50", "70/30"), N = c(300, 600, 1000, 1500), stringsAsFactors = FALSE)
k1 <- which(g1$N == 600 & g1$oran == "70/30"); k2 <- which(g2$N == 600 & g2$oran == "70/30")
cat(sprintf("Aynı hücre (N=600, 70/30) için koşul indeksi: ızgara sırası 1 -> %d, ızgara sırası 2 -> %d (tohum farklı)\n", k1, k2))

cat("\n== (f) Kontrol senaryosunda I. tip hata için Monte Carlo aralığı (R = 1000, α = .05) ==\n")
R <- 1000; mcse <- sqrt(.05 * .95 / R)
cat(sprintf("MCSE = %.4f | %%95 binom aralığı = [%.3f, %.3f] | şartname aralığı .03–.07 ≈ ±%.1f MCSE | Bradley (1978) liberal: .025–.075\n",
            mcse, qbinom(.025, R, .05) / R, qbinom(.975, R, .05) / R, .02 / mcse))
