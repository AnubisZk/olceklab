# Faz 4: tarayıcıda görünen simülasyon metinleri ↔ belgelenen algoritmanın bağımsız yeniden yazımı.
# Motorun fonksiyonları KULLANILMAZ: veri üretimi METHODS_TR.md M9'daki tanımla (MASS::mvrnorm + rnorm, tohum kuralı
# seed + 10000·koşul + tekrar), analizler doğrudan lavaan/psych ile, biçimleme sprintf ile yapılır.
# Kullanım: Rscript browser_crosscheck.R browser_flow_output.json population_flow.json
suppressPackageStartupMessages({library(lavaan); library(jsonlite)}); options(width = 250)
args <- commandArgs(TRUE)
ui <- fromJSON(args[1], simplifyVector = FALSE)
pop <- fromJSON(args[2], simplifyVector = FALSE)
SEED <- 4242L; REPS <- 100L; Ns <- c(200L, 400L)

num <- function(x, d, bounded = FALSE) {
  s <- sprintf(paste0("%.", d, "f"), abs(x)); if (bounded) s <- sub("^0\\.", ".", s); s <- sub(".", ",", s, fixed = TRUE)
  if (x < 0 && grepl("[1-9]", s)) s <- paste0("−", s); s
}
pct <- function(p, d = 1) { s <- num(100 * p, d); if (startsWith(s, "−")) paste0("−%", substring(s, 2)) else paste0("%", s) }
res <- list(); chk <- function(w, a, b) res[[length(res) + 1L]] <<- data.frame(olcut = w, arayuz = a, bagimsiz_R = b, sonuc = if (identical(a, b)) "AYNI" else "FARKLI")

items <- paste0("y", 1:6)
Lam <- matrix(0, 6, 2, dimnames = list(items, c("F1", "F2"))); Lam[1:3, 1] <- c(.7, .6, .65); Lam[4:6, 2] <- c(.7, .6, .7)
Psi <- matrix(c(1, .4, .4, 1), 2)
theta <- 1 - diag(Lam %*% Psi %*% t(Lam))
model <- "F1 =~ y1 + y2 + y3\nF2 =~ y4 + y5 + y6"
gen <- function(N, dif, seed) {
  RNGkind("Mersenne-Twister", "Inversion", "Rejection"); set.seed(seed)
  n1 <- as.integer(round(N * 0.5)); sizes <- c(n1, N - n1); out <- list()
  for (g in 1:2) {
    mu <- if (g == 2) c(0.3, 0) else c(0, 0)
    eta <- MASS::mvrnorm(sizes[g], mu = mu, Sigma = Psi)
    eps <- matrix(rnorm(sizes[g] * 6), sizes[g], 6) %*% diag(sqrt(theta), 6)
    y <- eta %*% t(Lam) + eps
    if (g == 2 && dif) y[, 1] <- y[, 1] + 0.4
    d <- as.data.frame(y); names(d) <- items; d$grp <- c("A", "B")[g]; out[[g]] <- d
  }
  do.call(rbind, out)
}
ok_fit <- function(f) !inherits(f, "error") && isTRUE(lavInspect(f, "converged")) && isTRUE(suppressWarnings(lavInspect(f, "post.check")))
alpha_raw <- function(x) { out <- NULL; utils::capture.output(out <- suppressMessages(suppressWarnings(psych::alpha(x, warnings = FALSE)))); out$total$raw_alpha }
fitq <- function(...) tryCatch(suppressWarnings(cfa(...)), error = function(e) e)

conds <- expand.grid(dif = c(FALSE, TRUE), N = Ns)  # ızgara sırası: senaryo en hızlı, sonra oran, sonra N
for (ci in seq_len(nrow(conds))) {
  N <- conds$N[ci]; dif <- conds$dif[ci]
  prm <- list(); rej <- list(metric = logical(), scalar = logical()); rel <- list(); adm <- 0L
  for (r in seq_len(REPS)) {
    d <- gen(N, dif, SEED + 10000L * ci + r)
    f <- fitq(model, data = d[d$grp == "A", items], std.lv = TRUE)
    if (ok_fit(f)) {
      adm <- adm + 1L
      ss <- standardizedSolution(f); ss <- ss[ss$op == "=~" | (ss$op == "~~" & ss$lhs != ss$rhs), ]
      prm[[length(prm) + 1L]] <- data.frame(name = paste0(ss$lhs, ss$op, ss$rhs), est = ss$est.std, lo = ss$ci.lower, hi = ss$ci.upper)
      om <- semTools::compRelSEM(f)
      al <- c(F1 = alpha_raw(d[d$grp == "A", 1:3]), F2 = alpha_raw(d[d$grp == "A", 4:6]))
      rel[[length(rel) + 1L]] <- data.frame(factor = c("F1", "F2"), alpha = unname(al), omega = as.numeric(om[c("F1", "F2")]))
    }
    fc <- fitq(model, data = d, group = "grp", group.label = c("A", "B"), std.lv = TRUE)
    fm <- fitq(model, data = d, group = "grp", group.label = c("A", "B"), std.lv = TRUE, group.equal = "loadings")
    fs <- fitq(model, data = d, group = "grp", group.label = c("A", "B"), std.lv = TRUE, group.equal = c("loadings", "intercepts"))
    if (ok_fit(fc) && ok_fit(fm) && ok_fit(fs)) {
      rej$metric <- c(rej$metric, lavTestLRT(fc, fm)[2, "Pr(>Chisq)"] < .05)
      rej$scalar <- c(rej$scalar, lavTestLRT(fm, fs)[2, "Pr(>Chisq)"] < .05)
    }
  }
  tag <- sprintf("koşul %d (N=%d, %s)", ci, N, if (dif) "DIF" else "kontrol")
  t1 <- Filter(function(x) x[[1]] == as.character(ci), ui$T1)[[1]]
  chk(paste(tag, "uygun çözüm oranı"), t1[[8]], pct(adm / REPS))
  P <- do.call(rbind, prm)
  truth <- c(setNames(Lam[Lam != 0], paste0(rep(c("F1", "F2"), each = 3), "=~", items)), "F1~~F2" = 0.4)
  for (nm in c("F1=~y1", "F1=~y3", "F2=~y5", "F1~~F2")) {
    x <- P[P$name == nm, ]; tv <- truth[[nm]]
    row <- Filter(function(z) z[[1]] == as.character(ci) && z[[6]] == nm, ui$T3)[[1]]
    chk(paste(tag, nm, "ortalama"), row[[9]], num(mean(x$est), 3))
    chk(paste(tag, nm, "yanlılık"), row[[10]], num(mean(x$est) - tv, 4))
    chk(paste(tag, nm, "göreli yanlılık"), row[[12]], pct((mean(x$est) - tv) / tv))
    chk(paste(tag, nm, "kapsama"), row[[17]], pct(mean(x$lo <= tv & tv <= x$hi)))
  }
  for (st in c("metric", "scalar")) {
    row <- Filter(function(z) z[[1]] == as.character(ci) && z[[6]] == c(metric = "metrik", scalar = "skaler")[[st]], ui$T4)[[1]]
    chk(paste(tag, st, "ölçü türü"), row[[7]], if (dif && st == "scalar") "güç" else "I. tip hata")  # kesişim DIF'i yalnızca skaler adımda sınanır
    chk(paste(tag, st, "geçerli R"), row[[8]], as.character(length(rej[[st]])))
    chk(paste(tag, st, "Δχ² reddetme"), row[[9]], pct(mean(rej[[st]])))
  }
  R <- do.call(rbind, rel)
  Sigma <- Lam %*% Psi %*% t(Lam) + diag(theta)
  for (fi in 1:2) {
    f <- c("F1", "F2")[fi]; idx <- if (fi == 1) 1:3 else 4:6
    S <- Sigma[idx, idx]; a_true <- 3 / 2 * (1 - sum(diag(S)) / sum(S)); l <- Lam[idx, fi]; o_true <- sum(l)^2 / (sum(l)^2 + sum(theta[idx]))
    row <- Filter(function(z) z[[1]] == as.character(ci) && z[[6]] == f, ui$T5)[[1]]
    chk(paste(tag, f, "α gerçek"), row[[7]], num(a_true, 3, TRUE))
    chk(paste(tag, f, "α ortalama"), row[[8]], num(mean(R$alpha[R$factor == f]), 3, TRUE))
    chk(paste(tag, f, "ω gerçek"), row[[10]], num(o_true, 3, TRUE))
    chk(paste(tag, f, "ω ortalama"), row[[11]], num(mean(R$omega[R$factor == f]), 3, TRUE))
  }
}
chk("iptalden sonra yeni parça başlamadı", ui$after_cancel, ui$after_cancel_later)
chk("tamamlanan tekrar", ui$done_progress, sprintf("%d / %d tekrar (%%100)", REPS * nrow(conds), REPS * nrow(conds)))
chk("paket dosyaları", paste(unlist(ui$package_files), collapse = ","), paste(sort(paste0("olceklab_simulasyon/", c("", "02_simulasyon.R", "03_gercek_degerler.R", "04_calistir.sh", "05_ozet.R", "BENIOKU.md", "params.json"))), collapse = ","))
tab <- do.call(rbind, res); print(tab, row.names = FALSE)
cat(sprintf("\n%d/%d AYNI; grafik sayısı: %s; SİMÜLASYON etiketi sayısı: %s; mobil yatay kaydırma: %s\n",
            sum(tab$sonuc == "AYNI"), nrow(tab), ui$charts, ui$result_notes, ui$mobile_horizontal_scroll))
