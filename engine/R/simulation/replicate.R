# M9 — Tek tekrarın analizi (SPEC §7 M9 9.4; SPEC_REVIEW MC-6, MC-9, MC-12).
# Aynı veri seti seçilen bütün kestiricilerle analiz edilir (ortak rastgele sayılar, MC-6). Hatalı tekrarlar atılmaz;
# hata türü (yakınsamama, uygunsuz çözüm, grupta boş kategori, diğer) ve iletisiyle kaydedilir (MC-9).

sim_seed <- function(seed, cond, rep) as.integer(seed + 10000L * cond + rep)

sim_try_fit <- function(syntax, data, args) {
  w <- character()
  fit <- tryCatch(
    withCallingHandlers(suppressMessages(do.call(lavaan::cfa, c(list(model = syntax, data = data), args))),
                        warning = function(x) { w <<- c(w, conditionMessage(x)); invokeRestart("muffleWarning") }),
    error = function(e) e)
  if (inherits(fit, "error")) return(list(status = "other", message = conditionMessage(fit)))
  if (!isTRUE(lavaan::lavInspect(fit, "converged"))) return(list(status = "nonconverged", message = paste(unique(w), collapse = " | ")))
  pc <- suppressWarnings(lavaan::lavInspect(fit, "post.check"))
  list(status = if (isTRUE(pc)) "ok" else "improper", fit = fit, message = paste(unique(w), collapse = " | "))
}

sim_fm <- function(fit, est) {
  sc <- est != "ML"
  k <- if (sc) c(chisq = "chisq.scaled", df = "df.scaled", pvalue = "pvalue.scaled", cfi = "cfi.scaled", tli = "tli.scaled", rmsea = "rmsea.scaled")
       else c(chisq = "chisq", df = "df", pvalue = "pvalue", cfi = "cfi", tli = "tli", rmsea = "rmsea")
  fm <- suppressWarnings(lavaan::fitMeasures(fit, c(unname(k), "srmr", "srmr_bentler_nomean")))
  out <- stats::setNames(as.numeric(fm[unname(k)]), names(k))
  c(out, srmr = as.numeric(fm[["srmr"]]), srmr_bn = if ("srmr_bentler_nomean" %in% names(fm)) as.numeric(fm[["srmr_bentler_nomean"]]) else NA_real_)
}

sim_empty_category <- function(pop, d) {
  if (pop$data_type != "ordinal") return(FALSE)
  K <- vapply(pop$props, length, integer(1))
  any(vapply(split(d, d$grp), function(g) any(vapply(pop$items, function(it) length(unique(g[[it]])) < K[[it]], logical(1))), logical(1)))
}

sim_cfa_args <- function(pop, est) {
  a <- list(estimator = est, std.lv = TRUE)
  if (est == "WLSMV") a$ordered <- pop$items
  a
}

# Tek grup DFA: çok gruplu tasarımda referans grupta (gerçek değerler o grup için tanımlıdır).
sim_analyse_cfa <- function(pop, d, est, analyses) {
  x <- d[d$grp == pop$gnames[1], pop$items, drop = FALSE]
  if (est == "WLSMV" && sim_empty_category(pop, d[d$grp == pop$gnames[1], , drop = FALSE])) return(list(status = "empty_category"))
  ft <- sim_try_fit(sim_model_syntax(pop), x, sim_cfa_args(pop, est))
  out <- list(status = ft$status, message = ft$message)
  if (is.null(ft$fit)) return(out)
  out$fit <- sim_fm(ft$fit, est)
  ss <- lavaan::standardizedSolution(ft$fit)
  keep <- ss$op == "=~" | (ss$op == "~~" & ss$lhs != ss$rhs & ss$lhs %in% pop$fnames) | ss$op == "|"
  ss <- ss[keep, ]
  out$params <- data.frame(name = ifelse(ss$op == "|", paste0(ss$lhs, "|", ss$rhs), paste0(ss$lhs, ss$op, ss$rhs)),
                           type = ifelse(ss$op == "=~", "loading", ifelse(ss$op == "~~", "factor_cor", "threshold")),
                           est = ss$est.std, se = ss$se, lower = ss$ci.lower, upper = ss$ci.upper, stringsAsFactors = FALSE)
  if (isTRUE(analyses$reliability)) {
    om <- tryCatch(suppressWarnings(semTools::compRelSEM(ft$fit, simplify = TRUE)), error = function(e) NULL)
    omv <- if (is.null(om)) rep(NA_real_, length(pop$fnames)) else { v <- as.numeric(unclass(om)); if (is.null(names(om)) && length(v) == 1L) v else as.numeric(om[pop$fnames]) }
    al <- vapply(pop$fnames, function(f) suppressWarnings(psych::alpha(x[, pop$factors[[f]], drop = FALSE], check.keys = FALSE, warnings = FALSE))$total$raw_alpha, numeric(1))
    out$reliability <- data.frame(factor = pop$fnames, alpha = unname(al), omega = omv, stringsAsFactors = FALSE)
  }
  out
}

sim_inv_steps <- function(est) {
  if (est == "WLSMV") list(configural = character(0), metric = c("thresholds", "loadings"), scalar = c("thresholds", "loadings", "intercepts"))
  else list(configural = character(0), metric = "loadings", scalar = c("loadings", "intercepts"))
}

sim_analyse_invariance <- function(pop, d, est, crit) {
  if (est == "WLSMV" && sim_empty_category(pop, d)) return(list(status = "empty_category"))
  syn0 <- sim_model_syntax(pop)
  steps <- sim_inv_steps(est)
  fits <- list(); rows <- list()
  for (st in names(steps)) {
    eq <- steps[[st]]
    if (est == "WLSMV") {
      syn <- tryCatch(as.character(suppressMessages(semTools::measEq.syntax(configural.model = syn0, data = d, ordered = pop$items, parameterization = "theta",
                        ID.fac = "std.lv", ID.cat = "Wu.Estabrook.2016", group = "grp", group.label = pop$gnames, group.equal = if (length(eq)) eq else ""))),
                      error = function(e) e)
      if (inherits(syn, "error")) return(list(status = "other", message = conditionMessage(syn), step = st))
      args <- list(estimator = "WLSMV", parameterization = "theta", ordered = pop$items, group = "grp", group.label = pop$gnames)
    } else {
      syn <- syn0
      args <- list(estimator = est, std.lv = TRUE, group = "grp", group.label = pop$gnames)
      if (length(eq)) args$group.equal <- eq
    }
    ft <- sim_try_fit(syn, d, args)
    if (ft$status != "ok") return(list(status = ft$status, message = ft$message, step = st))
    fits[[st]] <- ft$fit
    rows[[st]] <- sim_fm(ft$fit, est)
  }
  method <- cfa_lrt_method(est)
  cmp <- lapply(2:length(fits), function(k) {
    lr <- tryCatch(suppressWarnings(if (method == "standard") lavaan::lavTestLRT(fits[[k - 1L]], fits[[k]])
                                    else lavaan::lavTestLRT(fits[[k - 1L]], fits[[k]], method = method)), error = function(e) NULL)
    p <- if (is.null(lr)) NA_real_ else lr[2, "Pr(>Chisq)"]
    dchi <- if (is.null(lr)) NA_real_ else lr[2, "Chisq diff"]
    if (method == "satorra.bentler.2001" && isTRUE(dchi < 0)) {
      lr <- tryCatch(suppressWarnings(lavaan::lavTestLRT(fits[[k - 1L]], fits[[k]], method = "satorra.bentler.2010")), error = function(e) NULL)
      p <- if (is.null(lr)) NA_real_ else lr[2, "Pr(>Chisq)"]; dchi <- if (is.null(lr)) NA_real_ else lr[2, "Chisq diff"]
    }
    a <- rows[[k - 1L]]; b <- rows[[k]]
    st <- names(fits)[k]
    srmr_lim <- if (st == "metric") crit$srmr_load else crit$srmr_int
    data.frame(step = st, chisq_diff = dchi, p = p, delta_cfi = b[["cfi"]] - a[["cfi"]], delta_rmsea = b[["rmsea"]] - a[["rmsea"]],
               delta_srmr = b[["srmr_bn"]] - a[["srmr_bn"]],
               reject_chisq = isTRUE(p < crit$alpha), reject_cfi = isTRUE(b[["cfi"]] - a[["cfi"]] < crit$cfi),
               reject_rmsea = isTRUE(b[["rmsea"]] - a[["rmsea"]] > crit$rmsea), reject_srmr = isTRUE(b[["srmr_bn"]] - a[["srmr_bn"]] > srmr_lim),
               stringsAsFactors = FALSE)
  })
  pe <- lavaan::parameterEstimates(fits$scalar)
  lm <- pe[pe$op == "~1" & pe$lhs %in% pop$fnames & pe$group > 1L, ]
  list(status = "ok", steps = do.call(rbind, cmp),
       latent_means = data.frame(name = paste0(lm$lhs, "~1@", pop$gnames[lm$group]), est = lm$est, se = lm$se,
                                 lower = lm$ci.lower, upper = lm$ci.upper, stringsAsFactors = FALSE))
}

# Paralel analiz (MC-12): koşul başına referans (sim_pa_reference) verilirse yalnızca gözlenen özdeğerler hesaplanır.
sim_pa_reference <- function(N, p, n_iter, quant) {
  ev <- vapply(seq_len(n_iter), function(i) eigen(stats::cor(matrix(stats::rnorm(N * p), N, p)), symmetric = TRUE, only.values = TRUE)$values, numeric(p))
  apply(ev, 1, stats::quantile, quant, names = FALSE)
}

sim_analyse_pa <- function(pop, d, pa, ref) {
  x <- d[, pop$items, drop = FALSE]
  obs <- eigen(stats::cor(x), symmetric = TRUE, only.values = TRUE)$values
  if (is.null(ref)) {
    r <- tryCatch(quiet(psych::fa.parallel(x, fa = "pc", n.iter = pa$n_iter, sim = TRUE, quant = pa$quant, plot = FALSE))$value, error = function(e) NULL)
    if (is.null(r)) return(NA_integer_)
    return(as.integer(r$ncomp))
  }
  k <- count_leading(obs, ref)
  if (is.na(k)) length(obs) else as.integer(k)
}

sim_replicate <- function(pop, cond, rep, seed, estimators, analyses, crit, pa_ref = NULL) {
  s <- sim_seed(seed, cond$index, rep)
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(s)
  d <- sim_generate(pop, cond$N, cond$ratio, pop$dif[[cond$scenario]])
  out <- list(cond = cond$index, rep = rep, seed = s, empty_category = sim_empty_category(pop, d), est = list())
  if (isTRUE(analyses$pa$enabled)) out$pa <- sim_analyse_pa(pop, d, analyses$pa, pa_ref)
  for (est in estimators) {
    r <- list()
    if (isTRUE(analyses$cfa)) r$cfa <- sim_analyse_cfa(pop, d, est, analyses)
    if (isTRUE(analyses$invariance) && length(pop$groups) >= 2L) r$invariance <- sim_analyse_invariance(pop, d, est, crit)
    out$est[[est]] <- r
  }
  out
}
