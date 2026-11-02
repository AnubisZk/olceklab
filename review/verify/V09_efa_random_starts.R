# V09 — psych::fa döndürmesinde rastgele başlangıçlar: AFA sonucu tohuma bağlı mı?
suppressPackageStartupMessages({ library(psych); library(GPArotation); library(lavaan) })
cat("R:", R.version.string, "| psych:", as.character(packageVersion("psych")),
    "| GPArotation:", as.character(packageVersion("GPArotation")), "\n")
cat("formals(psych::fa)$n.rotations =", formals(psych::fa)$n.rotations, "\n\n")
x <- HolzingerSwineford1939[, paste0("x", 1:9)]
L <- function(seed, rot) { if (!is.null(seed)) set.seed(seed); unclass(fa(x, 3, rotate = rot, fm = "minres")$loadings) }
for (rot in c("oblimin", "geominQ")) {
  same_seed <- identical(L(1, rot), L(1, rot))
  diff_seed <- max(abs(L(1, rot) - L(2, rot)))
  cat(sprintf("%-8s aynı tohum -> aynı yükler: %s | tohum 1 vs 2 en büyük fark: %.2e\n", rot, same_seed, diff_seed))
}
