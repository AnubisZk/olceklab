# V08 — mirai işçilerinde tohum: tekrar başına set.seed, işçi sayısından bağımsız tekrarlanabilirlik sağlar mı?
suppressPackageStartupMessages(library(mirai))
cat("R:", R.version.string, "| mirai:", as.character(packageVersion("mirai")), "\n\n")
task <- function(seed) { RNGkind("Mersenne-Twister", "Inversion", "Rejection"); set.seed(seed); mean(rnorm(1000)) }
run_with <- function(n, seeded) {
  daemons(n); on.exit(daemons(0))
  m <- mirai_map(1:12, function(i, seeded, task) if (seeded) task(20261030 + i) else mean(rnorm(1000)),
                 seeded = seeded, task = task)
  unlist(m[])
}
a <- run_with(1, TRUE); b <- run_with(2, TRUE)
cat("Tekrar başına tohum: 1 işçi == 2 işçi ?", identical(a, b), "\n")
u1 <- run_with(2, FALSE); u2 <- run_with(2, FALSE)
cat("Tohumsuz (işçi akışı): iki çalıştırma aynı mı ?", identical(u1, u2), "\n")
u3 <- run_with(1, FALSE)
cat("Tohumsuz: 1 işçi == 2 işçi ?", identical(u1, u3), "\n")
