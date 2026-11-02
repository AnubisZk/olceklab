# V04 — psych::fa.parallel: tekrarlanabilirlik, referans türü, ölçüt ve korelasyon türü
suppressPackageStartupMessages({ library(psych); library(lavaan) })
cat("R:", R.version.string, "| psych:", as.character(packageVersion("psych")),
    "| getOption('mc.cores') =", deparse(getOption("mc.cores")), "| parallel::detectCores() =", parallel::detectCores(), "\n\n")
x <- HolzingerSwineford1939[, paste0("x", 1:9)]
run <- function(...) suppressWarnings(fa.parallel(x, fa = "pc", n.iter = 100, plot = FALSE, ...))

cat("== (a) Aynı tohum, varsayılan ayarlar (mclapply, varsayılan RNG) ==\n")
set.seed(20261030); a <- run(); set.seed(20261030); b <- run()
cat("values birebir aynı mı:", identical(a$values, b$values),
    "| en büyük mutlak fark:", signif(max(abs(a$values - b$values)), 3), "\n")

cat("\n== (b) options(mc.cores = 1) ile ==\n")
old <- options(mc.cores = 1)
set.seed(20261030); a1 <- run(); set.seed(20261030); b1 <- run()
cat("values birebir aynı mı:", identical(a1$values, b1$values), "\n")
options(old)

cat("\n== (c) RNGkind('L\\'Ecuyer-CMRG') + mc.cores = 2 ==\n")
RNGkind("L'Ecuyer-CMRG"); old <- options(mc.cores = 2)
set.seed(20261030); a2 <- run(); set.seed(20261030); b2 <- run()
cat("values birebir aynı mı:", identical(a2$values, b2$values), "\n")
options(mc.cores = 1); set.seed(20261030); c1 <- run()
cat("mc.cores=2 ile mc.cores=1 aynı mı (L'Ecuyer):", identical(a2$values, c1$values), "\n")
options(old); RNGkind("Mersenne-Twister", "Inversion", "Rejection")

cat("\n== (d) Döndürülen 'pc.sim' ortalama mı, karar ölçütü (quant=.95) mı? ==\n")
options(mc.cores = 1); set.seed(1)
p <- suppressWarnings(fa.parallel(x, fa = "pc", n.iter = 200, plot = FALSE, sim = TRUE))
k <- ncol(x)
simcols <- grep("^CSim", colnames(p$values))
if (length(simcols) == 0) simcols <- (k + 1):(2 * k)
cat("pc.sim == colMeans(sim)?        ", isTRUE(all.equal(unname(p$pc.sim), unname(colMeans(p$values[, simcols])))), "\n")
q95 <- apply(p$values[, simcols], 2, quantile, .95)
cat("gözlenen özdeğerler :", round(p$pc.values, 3), "\n")
cat("referans ortalama   :", round(p$pc.sim, 3), "\n")
cat("referans %95 yüzdelik:", round(q95, 3), "\n")
cat("psych ncomp:", p$ncomp, "| ortalama ölçütüyle sayım:", which(!(p$pc.values > p$pc.sim))[1] - 1,
    "| %95 ölçütüyle sayım:", which(!(p$pc.values > q95))[1] - 1, "\n")
cat("fa.parallel varsayılanları: n.iter =", formals(fa.parallel)$n.iter, ", quant =", formals(fa.parallel)$quant,
    ", sim =", formals(fa.parallel)$sim, ", fa =", formals(fa.parallel)$fa, "\n")

cat("\n== (e) 'resampled' referans: permütasyon mu, yerine koyarak örnekleme mi? (kaynak satırı) ==\n")
src <- paste(deparse(body(fa.parallel), width.cutoff = 500L), collapse = "\n")
show_src <- function(pattern) cat(regmatches(src, regexpr(pattern, src)), "\n")
show_src("sample\\(y, [^)]*\\)")

cat("\n== (f) cor = 'poly' iken simüle referans hangi korelasyonu kullanır? (kaynak satırı) ==\n")
show_src("sim.cor <- cor\\(simdata\\)")

cat("\n== (g) FA özdeğerleri: indirgenmiş matris mi, 1 faktörlü fa() çözümünün $values'u mu? ==\n")
show_src("fa.valuesx <- fa\\(rx[^)]*\\)\\$values")
