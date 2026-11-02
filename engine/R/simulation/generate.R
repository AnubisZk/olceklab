# M9 — Veri üretimi (SPEC §7 M9 9.2): gizil yanıt yaklaşımı.
#   η ~ N(α_g, Ψ_g) (MASS::mvrnorm), y* = Λ_g η + ε, ε ~ N(0, Θ), Θ = I − diag(Λ Ψ_ref Λ′) (referans grupta var(y*) = 1).
#   Sıralı veri: y* referans grubun kategori oranlarından Φ⁻¹ ile türetilen eşiklerde kesilir.
#   Yük farkında Θ sabit kalır; eşik/kesişim kayması referans grubun SD(y*) = 1 biriminde verilir.
# RNG tüketim sırası (belgelenmiş ve sabit): gruplar sırayla; her grupta önce η (mvrnorm), sonra ε (rnorm, n × p).
# Çağıran RNGkind("Mersenne-Twister", "Inversion", "Rejection") ve set.seed(tekrar tohumu) ayarlar.

sim_group_sizes <- function(N, ratio) {
  if (length(ratio) == 1L) return(as.integer(N))
  n <- as.integer(round(N * ratio[-length(ratio)]))
  c(n, as.integer(N) - sum(n))
}

sim_generate <- function(pop, N, ratio, scenario) {
  sizes <- sim_group_sizes(N, ratio)
  p <- length(pop$items)
  out <- vector("list", length(pop$groups))
  for (g in seq_along(pop$groups)) {
    G <- pop$groups[[g]]
    Lam <- pop$Lambda
    shift <- stats::setNames(rep(0, p), pop$items)
    if (!isTRUE(scenario$control) && identical(scenario$group, G$name)) {
      for (e in scenario$effects) {
        if (e$type == "loading") { j <- which(Lam[e$item, ] != 0); Lam[e$item, j] <- Lam[e$item, j] + e$size }
        else shift[[e$item]] <- shift[[e$item]] + e$size
      }
    }
    n <- sizes[g]
    eta <- MASS::mvrnorm(n, mu = G$alpha, Sigma = G$psi)
    if (n == 1L) eta <- matrix(eta, nrow = 1L)
    eps <- matrix(stats::rnorm(n * p), n, p) %*% diag(sqrt(pop$theta), p)
    ystar <- eta %*% t(Lam) + eps
    colnames(ystar) <- pop$items
    if (pop$data_type == "ordinal") {
      x <- vapply(pop$items, function(it) findInterval(ystar[, it], pop$tau[[it]] + shift[[it]]) + 1L, integer(n))
      if (n == 1L) x <- matrix(x, nrow = 1L, dimnames = list(NULL, pop$items))
      x <- as.data.frame(x)
    } else {
      x <- as.data.frame(sweep(ystar, 2, shift, `+`))
    }
    x$grp <- G$name
    out[[g]] <- x
  }
  d <- do.call(rbind, out)
  rownames(d) <- NULL
  d
}
