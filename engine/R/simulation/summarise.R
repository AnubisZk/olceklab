# M9 — Gerçek değerler ve özetleme (SPEC §7 M9 9.5–9.6; SPEC_REVIEW MC-1…MC-4, MC-8, MC-9, MC-11).
#
# Gerçek değer kaynakları (MC-2), referans grupta ve tek grup DFA için:
#   - sürekli veri (her kestirici) ve sıralı veri + WLSMV: üretim parametresi (std.all yükler = λ, faktör korelasyonları,
#     eşikler y* ölçeğinde = τ);
#   - sıralı veri + ML/MLR: sözde-gerçek değer — kesikli puanların kesin popülasyon kovaryans matrisi iki değişkenli normal
#     olasılıklarından hesaplanır ve model bu matrise uydurulur;
#   - α: gözlenen puanların popülasyon kovaryansından (sürekli: ΛΨΛ′ + Θ; sıralı: kesikli momentler);
#   - ω (ML/MLR): popülasyon matrisine uydurulan modelden compRelSEM(obs.var = TRUE); WLSMV'de ord.scale ω'nın
#     popülasyon değeri bu sürümde hesaplanmaz (NA, raporda belirtilir);
#   - gizil ortalama farkı: yalnızca kontrol senaryosunda ve doğru modelde (sürekli veri ya da WLSMV) = α_g (referans SS
#     biriminde); DIF senaryolarında skaler model yanlış tanımlı olduğundan NA.

sim_pop_ordinal_moments <- function(pop) {
  p <- length(pop$items)
  R <- pop$Lambda %*% pop$Psi %*% t(pop$Lambda); diag(R) <- 1
  mu <- vapply(pop$items, function(it) sum(seq_along(pop$props[[it]]) * pop$props[[it]]), numeric(1))
  S <- matrix(0, p, p, dimnames = list(pop$items, pop$items))
  for (i in seq_len(p)) {
    pr <- pop$props[[i]]; k <- seq_along(pr)
    S[i, i] <- sum(k^2 * pr) - mu[i]^2
  }
  cdf <- function(a, b, r) {
    a <- pmin(pmax(a, -38), 38); b <- pmin(pmax(b, -38), 38)
    pbivnorm::pbivnorm(a, b, r)
  }
  for (i in seq_len(p - 1L)) for (j in (i + 1L):p) {
    ti <- c(-Inf, pop$tau[[i]], Inf); tj <- c(-Inf, pop$tau[[j]], Inf)
    Ki <- length(ti) - 1L; Kj <- length(tj) - 1L
    g <- expand.grid(a = seq_len(Ki), b = seq_len(Kj))
    pr <- cdf(ti[g$a + 1L], tj[g$b + 1L], R[i, j]) - cdf(ti[g$a], tj[g$b + 1L], R[i, j]) -
          cdf(ti[g$a + 1L], tj[g$b], R[i, j]) + cdf(ti[g$a], tj[g$b], R[i, j])
    S[i, j] <- S[j, i] <- sum(g$a * g$b * pr) - mu[i] * mu[j]
  }
  S
}

sim_alpha_pop <- function(S, items) { k <- length(items); s <- S[items, items]; k / (k - 1) * (1 - sum(diag(s)) / sum(s)) }

sim_true_values <- function(pop, estimators) {
  lam <- pop$Lambda; Psi <- pop$Psi
  gen <- data.frame(name = character(), type = character(), true = numeric(), stringsAsFactors = FALSE)
  for (f in pop$fnames) for (it in pop$factors[[f]]) gen[nrow(gen) + 1L, ] <- list(paste0(f, "=~", it), "loading", lam[it, f])
  fn <- pop$fnames
  for (j in seq_along(fn)) for (i in seq_len(j - 1L)) gen[nrow(gen) + 1L, ] <- list(paste0(fn[i], "~~", fn[j]), "factor_cor", Psi[fn[i], fn[j]])
  S_obs <- if (pop$data_type == "continuous") {
    S <- lam %*% Psi %*% t(lam); diag(S) <- 1; S
  } else sim_pop_ordinal_moments(pop)
  out <- list()
  for (est in estimators) {
    tv <- gen
    rel <- data.frame(factor = fn, alpha = vapply(fn, function(f) sim_alpha_pop(S_obs, pop$factors[[f]]), numeric(1)), omega = NA_real_, stringsAsFactors = FALSE)
    if (pop$data_type == "ordinal" && est == "WLSMV") {
      for (it in pop$items) for (t in seq_along(pop$tau[[it]])) tv[nrow(tv) + 1L, ] <- list(paste0(it, "|t", t), "threshold", pop$tau[[it]][t])
    }
    if (est != "WLSMV") {
      fit <- suppressWarnings(lavaan::cfa(sim_model_syntax(pop), sample.cov = S_obs, sample.nobs = 1e6L, std.lv = TRUE))
      if (pop$data_type == "ordinal") {
        ss <- lavaan::standardizedSolution(fit)
        key <- ifelse(ss$op == "=~", paste0(ss$lhs, "=~", ss$rhs), paste0(ss$lhs, "~~", ss$rhs))
        tv$true[tv$type %in% c("loading", "factor_cor")] <- ss$est.std[match(tv$name[tv$type %in% c("loading", "factor_cor")], key)]
        tv$source <- "pseudo_true"
      }
      om <- suppressWarnings(semTools::compRelSEM(fit, obs.var = TRUE, simplify = TRUE))
      rel$omega <- if (length(fn) == 1L) as.numeric(unclass(om)) else as.numeric(om[fn])
    }
    if (is.null(tv$source)) tv$source <- "generating"
    lm <- list()
    if (length(pop$groups) >= 2L && (pop$data_type == "continuous" || est == "WLSMV")) {
      for (g in pop$groups[-1]) for (f in fn) lm[[length(lm) + 1L]] <- data.frame(name = paste0(f, "~1@", g$name), type = "latent_mean", true = g$alpha[[f]], source = "generating")
    }
    out[[est]] <- list(params = tv, reliability = rel, latent_means = if (length(lm)) do.call(rbind, lm) else NULL)
  }
  out
}

# --- Özetleme -------------------------------------------------------------------------

sim_rate <- function(x) { x <- x[!is.na(x)]; n <- length(x); p <- if (n) mean(x) else NA_real_; c(rate = p, mcse = if (n) sqrt(p * (1 - p) / n) else NA_real_, n = n) }

sim_param_summary <- function(est_rows, truth, rel_cut) {
  if (is.null(est_rows) || !nrow(est_rows)) return(NULL)
  by <- split(est_rows, est_rows$name)
  rows <- lapply(names(by), function(nm) {
    r <- by[[nm]]; tr <- truth$true[match(nm, truth$name)]; ty <- truth$type[match(nm, truth$name)]
    if (is.na(tr)) return(NULL)
    n <- nrow(r); m <- mean(r$est); sdv <- stats::sd(r$est); bias <- m - tr
    se_m <- mean(r$se, na.rm = TRUE)
    data.frame(name = nm, type = ty, true = tr, source = truth$source[match(nm, truth$name)], n = n, mean = m, bias = bias,
               rel_bias = if (abs(tr) >= rel_cut) bias / tr else NA_real_,
               std_bias = if (isTRUE(sdv > 0)) bias / sdv else NA_real_, emp_sd = sdv, rmse = sqrt(mean((r$est - tr)^2)),
               mean_se = se_m, se_rel_bias = if (isTRUE(sdv > 0)) (se_m - sdv) / sdv else NA_real_,
               coverage = mean(r$lower <= tr & tr <= r$upper, na.rm = TRUE),
               mcse_bias = if (n > 1) sdv / sqrt(n) else NA_real_,
               mcse_coverage = { cv <- mean(r$lower <= tr & tr <= r$upper, na.rm = TRUE); sqrt(cv * (1 - cv) / n) },
               stringsAsFactors = FALSE)
  })
  do.call(rbind, Filter(Negate(is.null), rows))
}

sim_summarise_cell <- function(reps, est, truth, opts) {
  st <- vapply(reps, function(r) { x <- r$est[[est]]$cfa$status; if (is.null(x)) NA_character_ else x }, "")
  inv_st <- vapply(reps, function(r) { x <- r$est[[est]]$invariance$status; if (is.null(x)) NA_character_ else x }, "")
  R <- length(reps)
  counts <- function(s) { s <- s[!is.na(s)]; vapply(c("ok", "nonconverged", "improper", "empty_category", "other"), function(k) sum(s == k), 0) }
  ok <- which(st == "ok")
  conv <- which(st %in% c("ok", "improper"))
  out <- list(R = R, cfa_status = as.list(counts(st)), invariance_status = as.list(counts(inv_st)),
              converged_rate = if (any(!is.na(st))) mean(st %in% c("ok", "improper")) else NA_real_,
              admissible_rate = if (any(!is.na(st))) mean(st == "ok") else NA_real_,
              empty_category_rate = mean(vapply(reps, `[[`, FALSE, "empty_category")))
  if (any(!is.na(st))) {
    fitm <- do.call(rbind, lapply(reps[ok], function(r) r$est[[est]]$cfa$fit))
    if (!is.null(fitm) && nrow(fitm)) {
      out$fit <- lapply(c("chisq", "cfi", "tli", "rmsea", "srmr"), function(k) {
        v <- fitm[, k]; list(index = k, mean = mean(v), sd = stats::sd(v), q025 = unname(stats::quantile(v, 0.025)), q975 = unname(stats::quantile(v, 0.975)))
      })
      out$fit_rates <- list(good = sim_rate(fitm[, "cfi"] >= 0.95 & fitm[, "rmsea"] <= 0.06 & fitm[, "srmr"] <= 0.08)[["rate"]],
                            acceptable = sim_rate(fitm[, "cfi"] >= 0.90 & fitm[, "rmsea"] <= 0.08)[["rate"]])
      prm <- do.call(rbind, lapply(reps[ok], function(r) r$est[[est]]$cfa$params))
      out$params <- sim_param_summary(prm, truth$params, opts$rel_cut)
      prm_conv <- do.call(rbind, lapply(reps[conv], function(r) r$est[[est]]$cfa$params))
      out$params_sensitivity <- sim_param_summary(prm_conv, truth$params, opts$rel_cut)
      rl <- do.call(rbind, lapply(reps[ok], function(r) r$est[[est]]$cfa$reliability))
      if (!is.null(rl) && nrow(rl)) {
        out$reliability <- do.call(rbind, lapply(split(rl, rl$factor), function(x) {
          f <- x$factor[1]; ta <- truth$reliability$alpha[truth$reliability$factor == f]; to <- truth$reliability$omega[truth$reliability$factor == f]
          data.frame(factor = f, alpha_mean = mean(x$alpha), alpha_true = ta, alpha_bias = mean(x$alpha) - ta,
                     omega_mean = mean(x$omega), omega_true = to, omega_bias = mean(x$omega) - to,
                     mcse_alpha = stats::sd(x$alpha) / sqrt(nrow(x)), mcse_omega = stats::sd(x$omega) / sqrt(nrow(x)), stringsAsFactors = FALSE)
        }))
      }
    }
  }
  inv_ok <- which(inv_st == "ok")
  if (length(inv_ok)) {
    stp <- do.call(rbind, lapply(reps[inv_ok], function(r) cbind(rep = r$rep, r$est[[est]]$invariance$steps)))
    steps <- unique(stp$step)
    out$invariance <- do.call(rbind, lapply(steps, function(s) {
      x <- stp[stp$step == s, ]
      prev_ok <- vapply(x$rep, function(rp) { y <- stp[stp$rep == rp & match(stp$step, steps) < match(s, steps), ]; !any(y$reject_chisq) }, logical(1))
      rc <- sim_rate(x$reject_chisq); rcfi <- sim_rate(x$reject_cfi); rr <- sim_rate(x$reject_rmsea); rs <- sim_rate(x$reject_srmr)
      seq_rate <- sim_rate(x$reject_chisq & prev_ok)
      data.frame(step = s, n = nrow(x), reject_chisq = rc[["rate"]], mcse_chisq = rc[["mcse"]], reject_cfi = rcfi[["rate"]], mcse_cfi = rcfi[["mcse"]],
                 reject_rmsea = rr[["rate"]], reject_srmr = rs[["rate"]],
                 reject_cfi_and_rmsea = sim_rate(x$reject_cfi & x$reject_rmsea)[["rate"]], reject_cfi_or_rmsea = sim_rate(x$reject_cfi | x$reject_rmsea)[["rate"]],
                 sequential_chisq = seq_rate[["rate"]], stringsAsFactors = FALSE)
    }))
    lmr <- do.call(rbind, lapply(reps[inv_ok], function(r) r$est[[est]]$invariance$latent_means))
    if (!is.null(truth$latent_means) && !is.null(lmr) && opts$control) out$latent_means <- sim_param_summary(lmr, truth$latent_means, opts$rel_cut)
  }
  if (!is.null(reps[[1]]$pa)) {
    k <- vapply(reps, function(r) as.integer(r$pa), 1L)
    tab <- table(factor(k, levels = sort(unique(c(k[!is.na(k)], length(truth$reliability$factor))))))
    out$pa <- list(distribution = as.list(tab / sum(tab)), correct = sim_rate(k == length(truth$reliability$factor))[["rate"]])
  }
  out
}

# Örneklem büyüklüğü önerisi (MC-11): ölçütlerin hem o N'de hem daha büyük bütün ızgara N'lerinde sağlandığı en küçük N.
# Değişmezlik adımında reddetme oranının anlamı (T4): adımın eklediği kısıt ve senaryodaki DIF türüne göre.
#   ML/MLR: metrik = yükler, skaler = + kesişimler; WLSMV: metrik = eşikler + yükler, skaler = + kesişimler.
#   Sıralı veride eşik kayması ML/MLR analizinde ortalama farkı olarak skaler adımda görünür; kesikli puanların
#   kovaryansı da değiştiği için metrik adım tam bir I. tip hata durumu değildir ("karışık").
sim_step_kind <- function(scenario, step, est, data_type) {
  if (isTRUE(scenario$control)) return("type_i")
  added <- if (est == "WLSMV") list(metric = c("thresholds", "loadings"), scalar = "intercepts") else list(metric = "loadings", scalar = "intercepts")
  order <- names(added)
  hit <- character(); approx <- FALSE
  for (e in scenario$effects) {
    if (e$type == "loading") hit <- c(hit, "loadings")
    else if (e$type == "intercept") hit <- c(hit, "intercepts")
    else if (est == "WLSMV") hit <- c(hit, "thresholds")
    else { hit <- c(hit, "intercepts"); approx <- TRUE }
  }
  if (any(added[[step]] %in% hit)) return("power")
  before <- unlist(added[seq_len(match(step, order) - 1L)])
  if (any(before %in% hit) || approx) return("mixed")
  "type_i"
}

# Önerideki güç ölçütünün adımı: "auto" iken DIF'li parametreyi sınayan ilk adım (sim_step_kind = "power").
sim_power_target <- function(spec, sc, est) {
  d <- spec$pop$dif[[sc]]
  if (isTRUE(d$control) || !isTRUE(spec$analyses$invariance)) return(NULL)
  ps <- spec$recommend$power_step
  if (identical(ps, "auto")) {
    k <- vapply(c("metric", "scalar"), function(st) sim_step_kind(d, st, est, spec$pop$data_type), "")
    ps <- names(k)[k == "power"][1]
    if (is.na(ps)) return(NULL)
  }
  list(step = ps)
}

sim_criteria_met <- function(cell, crit, power_target) {
  ok <- c(admissible = isTRUE(cell$admissible_rate >= crit$admissible))
  if (!is.null(cell$params)) {
    pr <- cell$params
    rb <- pr$rel_bias[!is.na(pr$rel_bias)]
    ok <- c(ok, param_bias = all(abs(rb) <= crit$param_bias), se_bias = all(abs(pr$se_rel_bias) <= crit$se_bias, na.rm = TRUE),
            coverage = all(pr$coverage >= crit$coverage[1] & pr$coverage <= crit$coverage[2], na.rm = TRUE))
  }
  if (!is.null(power_target) && !is.null(cell$invariance)) {
    r <- cell$invariance[cell$invariance$step == power_target$step, ]
    if (nrow(r)) ok <- c(ok, power = isTRUE(r$reject_chisq >= crit$power))
  }
  ok
}

sim_recommend <- function(cells, Ns, crit, power_target) {
  met <- vapply(cells, function(c) all(sim_criteria_met(c, crit, power_target)), logical(1))
  for (i in seq_along(Ns)) if (all(met[i:length(Ns)])) return(Ns[i])
  NA_integer_
}

# Bütün hücrelerin özeti: platform ve bağımsız paket aynı fonksiyonu kullanır.
sim_summary <- function(spec, reps) {
  truth <- sim_true_values(spec$pop, spec$estimators)
  by_cond <- split(reps, vapply(reps, `[[`, 0L, "cond"))
  cells <- list()
  for (ci in spec$grid$index) {
    rr <- by_cond[[as.character(ci)]]
    rr <- rr[order(vapply(rr, `[[`, 0L, "rep"))]
    g <- spec$grid[spec$grid$index == ci, ]
    for (est in spec$estimators) {
      cell <- sim_summarise_cell(rr, est, truth[[est]], list(rel_cut = spec$recommend$rel_cut, control = isTRUE(spec$pop$dif[[g$scenario]]$control)))
      cell$cond <- ci; cell$N <- g$N; cell$ratio <- g$ratio; cell$scenario <- g$scenario; cell$estimator <- est
      cells[[length(cells) + 1L]] <- cell
    }
  }
  recs <- list()
  for (ra in seq_along(spec$ratios)) for (sc in spec$scenarios) for (est in spec$estimators) {
    cs <- Filter(function(c) c$ratio == ra && c$scenario == sc && c$estimator == est, cells)
    cs <- cs[order(vapply(cs, `[[`, 0L, "N"))]
    pt <- sim_power_target(spec, sc, est)
    recs[[length(recs) + 1L]] <- list(ratio = ra, scenario = sc, estimator = est, power_step = if (is.null(pt)) NA_character_ else pt$step,
                                      N = sim_recommend(cs, vapply(cs, `[[`, 0L, "N"), spec$recommend, pt),
                                      criteria = lapply(cs, function(c) as.list(sim_criteria_met(c, spec$recommend, pt))))
  }
  list(truth = truth, cells = cells, recommendations = recs)
}

SIM_LABEL_TR <- "SİMÜLASYON — sentetik veri; ölçeğin geçerliğine kanıt değildir."
SIM_LABEL_EN <- "SIMULATION — synthetic data; not evidence for the validity of the scale."

sim_ratio_label <- function(spec, ra) paste(vapply(spec$ratios[[ra]], function(v) format(round(100 * v)), ""), collapse = "/")

sim_results_record <- function(spec, sm, job_id) {
  scen <- vapply(spec$pop$dif, `[[`, "", "name")
  ctl <- vapply(spec$pop$dif, function(d) isTRUE(d$control), logical(1))
  base_cols <- list(tbl_col("cond", "Koşul", "Condition", "int"), tbl_col("N", "N", "N", "int"), tbl_col("ratio", "Grup oranı", "Group ratio"),
                    tbl_col("scenario", "Senaryo", "Scenario"), tbl_col("estimator", "Kestirici", "Estimator"))
  base_row <- function(c) data.frame(cond = c$cond, N = c$N, ratio = sim_ratio_label(spec, c$ratio), scenario = scen[c$scenario], estimator = c$estimator, stringsAsFactors = FALSE)
  note <- function(tr, en) list(tr = paste(SIM_LABEL_TR, tr), en = paste(SIM_LABEL_EN, en))
  # T1 yakınsama ve hata türleri (MC-9)
  t1 <- do.call(rbind, lapply(sm$cells, function(c) cbind(base_row(c), data.frame(R = c$R, conv = c$converged_rate, adm = c$admissible_rate,
    nonconv = c$cfa_status$nonconverged, improper = c$cfa_status$improper, empty = c$cfa_status$empty_category, other = c$cfa_status$other,
    empty_rate = c$empty_category_rate))))
  n1 <- note("Yakınsama: lavaan yakınsadı; uygun çözüm: ayrıca post.check geçti. Hatalı tekrarlar atılmaz, türüyle sayılır (SPEC_REVIEW MC-9). Birincil özetler uygun çözümlerden, duyarlılık özetleri yakınsayan çözümlerden hesaplanır.",
             "Converged: lavaan converged; admissible: also passed post.check. Failed replications are not discarded but counted by type (SPEC_REVIEW MC-9). Primary summaries use admissible solutions, sensitivity summaries use converged solutions.")
  tables <- list(make_table("T1", "Yakınsama, uygun çözüm ve hata türleri (DFA)", "Convergence, admissibility and error types (CFA)",
    c(base_cols, list(tbl_col("R", "Tekrar", "Replications", "int"), tbl_col("conv", "Yakınsama", "Converged", "pct", 1L), tbl_col("adm", "Uygun çözüm", "Admissible", "pct", 1L),
                      tbl_col("nonconv", "Yakınsamayan", "Non-converged", "int"), tbl_col("improper", "Uygunsuz", "Improper", "int"),
                      tbl_col("empty", "Grupta boş kategori", "Empty category in group", "int"), tbl_col("other", "Diğer", "Other", "int"),
                      tbl_col("empty_rate", "Boş kategori oranı (bütün veri)", "Empty-category rate (all data)", "pct", 1L))),
    t1, note_tr = n1$tr, note_en = n1$en))
  # T2 uyum
  fr <- do.call(rbind, lapply(sm$cells, function(c) if (is.null(c$fit)) NULL else do.call(rbind, lapply(c$fit, function(f) cbind(base_row(c), data.frame(index = toupper(f$index),
    mean = f$mean, sd = f$sd, q025 = f$q025, q975 = f$q975, good = c$fit_rates$good, acceptable = c$fit_rates$acceptable, stringsAsFactors = FALSE))))))
  if (!is.null(fr)) {
    n2 <- note("Robust kestiricilerde ölçeklenmiş indeksler. İyi uyum: CFI ≥ ,95, RMSEA ≤ ,06, SRMR ≤ ,08; kabul edilebilir: CFI ≥ ,90, RMSEA ≤ ,08 (Hu ve Bentler, 1999; ML ve sürekli veri için önerilmiştir, WLSMV'de farklı davranır: Xia ve Yang, 2019).",
               "Scaled indices for robust estimators. Good fit: CFI ≥ .95, RMSEA ≤ .06, SRMR ≤ .08; acceptable: CFI ≥ .90, RMSEA ≤ .08 (Hu & Bentler, 1999; proposed for ML with continuous data and behave differently under WLSMV: Xia & Yang, 2019).")
    tables[[length(tables) + 1L]] <- make_table("T2", "Uyum indekslerinin dağılımı", "Distribution of fit indices",
      c(base_cols, list(tbl_col("index", "İndeks", "Index"), tbl_col("mean", "Ort.", "Mean", "num", 3L), tbl_col("sd", "SS", "SD", "num", 3L),
                        tbl_col("q025", "%2,5", "2.5%", "num", 3L), tbl_col("q975", "%97,5", "97.5%", "num", 3L),
                        tbl_col("good", "İyi uyum oranı", "Good-fit rate", "pct", 1L), tbl_col("acceptable", "Kabul edilebilir oran", "Acceptable rate", "pct", 1L))),
      fr, note_tr = n2$tr, note_en = n2$en)
  }
  # T3 parametreler (MC-1, MC-3, MC-4)
  pr <- do.call(rbind, lapply(sm$cells, function(c) if (is.null(c$params)) NULL else cbind(base_row(c)[rep(1, nrow(c$params)), ], c$params)))
  if (!is.null(pr)) {
    pr$source_tr <- ifelse(pr$source == "pseudo_true", "sözde-gerçek", "üretim")
    n3 <- note(sprintf("Ölçek: yükler ve faktör korelasyonları std.all, eşikler y* ölçeği (referans grup, tek grup DFA). |θ| ≥ %s için göreli yanlılık; daha küçük θ için ham ve standardize yanlılık (yanlılık/SS; |%%40| üzeri sorunlu, Collins vd., 2001). SH göreli yanlılığı: (ort(SH) − SS(θ̂)) / SS(θ̂). Kapsama: %%95 GA. MCSE: Monte Carlo standart hatası. Gerçek değer kaynağı: üretim parametresi ya da kesin popülasyon momentlerinden sözde-gerçek değer (SPEC_REVIEW MC-2).", fmt_num(spec$recommend$rel_cut, 2, "tr", TRUE)),
               sprintf("Scale: loadings and factor correlations std.all, thresholds on the y* scale (reference group, single-group CFA). Relative bias for |θ| ≥ %s; raw and standardized bias (bias/SD; above |40%%| problematic, Collins et al., 2001) for smaller θ. SE relative bias: (mean(SE) − SD(θ̂)) / SD(θ̂). Coverage: 95%% CI. MCSE: Monte Carlo standard error. True-value source: generating parameter or pseudo-true value from exact population moments (SPEC_REVIEW MC-2).", fmt_num(spec$recommend$rel_cut, 2, "en", TRUE)))
    t3 <- make_table("T3", "Parametre kestirimleri: yanlılık, SH yanlılığı ve kapsama", "Parameter estimates: bias, SE bias and coverage",
      c(base_cols, list(tbl_col("name", "Parametre", "Parameter"), tbl_col("source_tr", "Gerçek değer", "True value source"), tbl_col("true", "θ", "θ", "num", 3L),
                        tbl_col("mean", "Ort. θ̂", "Mean θ̂", "num", 3L), tbl_col("bias", "Yanlılık", "Bias", "num", 4L), tbl_col("mcse_bias", "MCSE", "MCSE", "num", 4L),
                        tbl_col("rel_bias", "Göreli yanlılık", "Relative bias", "pct", 1L), tbl_col("std_bias", "Std. yanlılık", "Std. bias", "pct", 1L),
                        tbl_col("rmse", "RMSE", "RMSE", "num", 4L), tbl_col("emp_sd", "Deneysel SS", "Empirical SD", "num", 4L),
                        tbl_col("se_rel_bias", "SH göreli yanlılığı", "SE relative bias", "pct", 1L), tbl_col("coverage", "Kapsama", "Coverage", "pct", 1L))),
      pr, note_tr = n3$tr, note_en = n3$en)
    t3$rows_fmt$en$source_tr <- ifelse(pr$source == "pseudo_true", "pseudo-true", "generating")
    tables[[length(tables) + 1L]] <- t3
  }
  # T4 değişmezlik (MC-8). Ölçü türü adım ve senaryoya göre belirlenir (sim_step_kind).
  kind_lab <- list(type_i = c(tr = "I. tip hata", en = "Type I error"), power = c(tr = "güç", en = "power"),
                   mixed = c(tr = "karışık", en = "mixed"))
  iv <- do.call(rbind, lapply(sm$cells, function(c) if (is.null(c$invariance)) NULL else {
    k <- vapply(c$invariance$step, function(st) sim_step_kind(spec$pop$dif[[c$scenario]], st, c$estimator, spec$pop$data_type), "")
    cbind(base_row(c)[rep(1, nrow(c$invariance)), ], c$invariance, kind = k,
          kind_tr = vapply(k, function(x) kind_lab[[x]][["tr"]], ""), kind_en = vapply(k, function(x) kind_lab[[x]][["en"]], ""), stringsAsFactors = FALSE)
  }))
  if (!is.null(iv)) {
    iv$step_tr <- c(metric = "metrik", scalar = "skaler")[iv$step]
    n4 <- note(sprintf("Reddetme oranı: iki model de popülasyonda doğruysa I. tip hata; adımın eklediği kısıt DIF'li parametreyi kapsıyorsa güç; karışık: karşılaştırılan modeller popülasyonda tam doğru değildir (DIF daha önceki bir adımda ya da sıralı veride eşik DIF'i ML/MLR ile analiz edilmiş). Her adım ayrı: o adımın kararı; ardışık: önceki adımlar Δχ² ile reddedilmediğinde o adımın reddi. Ölçütler: Δχ² p < %s; ΔCFI < %s; ΔRMSEA > %s; ΔSRMR > %s (metrik) / %s (skaler). MCSE = √(p(1 − p)/R).",
                       fmt_num(spec$criteria$alpha, 2, "tr", TRUE), fmt_num(spec$criteria$cfi, 3, "tr", TRUE), fmt_num(spec$criteria$rmsea, 3, "tr", TRUE),
                       fmt_num(spec$criteria$srmr_load, 3, "tr", TRUE), fmt_num(spec$criteria$srmr_int, 3, "tr", TRUE)),
               sprintf("Rejection rate: Type I error when both models hold in the population; power when the step's new constraint covers the DIF parameter; mixed: the compared models do not hold exactly in the population (DIF in an earlier step, or threshold DIF in ordinal data analysed with ML/MLR). Each step separately: that step's decision; sequential: rejection at that step when earlier steps were not rejected by Δχ². Criteria: Δχ² p < %s; ΔCFI < %s; ΔRMSEA > %s; ΔSRMR > %s (metric) / %s (scalar). MCSE = √(p(1 − p)/R).",
                       fmt_num(spec$criteria$alpha, 2, "en", TRUE), fmt_num(spec$criteria$cfi, 3, "en", TRUE), fmt_num(spec$criteria$rmsea, 3, "en", TRUE),
                       fmt_num(spec$criteria$srmr_load, 3, "en", TRUE), fmt_num(spec$criteria$srmr_int, 3, "en", TRUE)))
    t4 <- make_table("T4", "Ölçme değişmezliği: I. tip hata ve güç", "Measurement invariance: Type I error and power",
      c(base_cols, list(tbl_col("step_tr", "Adım", "Step"), tbl_col("kind_tr", "Ölçü", "Measure"), tbl_col("n", "Geçerli R", "Valid R", "int"),
                        tbl_col("reject_chisq", "Δχ²", "Δχ²", "pct", 1L), tbl_col("mcse_chisq", "MCSE", "MCSE", "pct", 1L),
                        tbl_col("reject_cfi", "ΔCFI", "ΔCFI", "pct", 1L), tbl_col("reject_rmsea", "ΔRMSEA", "ΔRMSEA", "pct", 1L), tbl_col("reject_srmr", "ΔSRMR", "ΔSRMR", "pct", 1L),
                        tbl_col("reject_cfi_and_rmsea", "ΔCFI VE ΔRMSEA", "ΔCFI AND ΔRMSEA", "pct", 1L), tbl_col("reject_cfi_or_rmsea", "ΔCFI VEYA ΔRMSEA", "ΔCFI OR ΔRMSEA", "pct", 1L),
                        tbl_col("sequential_chisq", "Ardışık Δχ²", "Sequential Δχ²", "pct", 1L))),
      iv, note_tr = n4$tr, note_en = n4$en)
    t4$rows_fmt$en$step_tr <- iv$step; t4$rows_fmt$en$kind_tr <- iv$kind_en
    tables[[length(tables) + 1L]] <- t4
  }
  # T5 güvenirlik
  rl <- do.call(rbind, lapply(sm$cells, function(c) if (is.null(c$reliability)) NULL else cbind(base_row(c)[rep(1, nrow(c$reliability)), ], c$reliability)))
  if (!is.null(rl)) {
    n5 <- note("α'nın gerçek değeri gözlenen puanların popülasyon kovaryansından; ω'nınki ML/MLR'de popülasyon matrisine uydurulan modelden (obs.var = TRUE). WLSMV'de ω'nın popülasyon değeri bu sürümde hesaplanmaz (—).",
               "The true α comes from the population covariance of observed scores; the true ω (ML/MLR) from the model fitted to the population matrix (obs.var = TRUE). For WLSMV the population ω is not computed in this version (—).")
    tables[[length(tables) + 1L]] <- make_table("T5", "Güvenirlik kestirimleri", "Reliability estimates",
      c(base_cols, list(tbl_col("factor", "Faktör", "Factor"), tbl_col("alpha_true", "α (gerçek)", "α (true)", "num", 3L, TRUE), tbl_col("alpha_mean", "Ort. α̂", "Mean α̂", "num", 3L, TRUE),
                        tbl_col("alpha_bias", "α yanlılığı", "α bias", "num", 4L), tbl_col("omega_true", "ω (gerçek)", "ω (true)", "num", 3L, TRUE),
                        tbl_col("omega_mean", "Ort. ω̂", "Mean ω̂", "num", 3L, TRUE), tbl_col("omega_bias", "ω yanlılığı", "ω bias", "num", 4L))),
      rl, note_tr = n5$tr, note_en = n5$en)
  }
  # T6 paralel analiz
  pa <- do.call(rbind, lapply(sm$cells, function(c) if (is.null(c$pa)) NULL else cbind(base_row(c), data.frame(correct = c$pa$correct,
    dist = paste(sprintf("%s: %s", names(c$pa$distribution), vapply(unlist(c$pa$distribution), function(v) fmt_pct(v, "tr", 1L), "")), collapse = "; "), stringsAsFactors = FALSE))))
  if (!is.null(pa)) {
    n6 <- note(if (isTRUE(spec$analyses$pa$per_cell)) "Paralel analiz (pc, Pearson, simüle normal referans, %95 yüzdelik). Referans özdeğerler koşul başına bir kez, tohum seed + 10000·koşul ile hesaplanır (SPEC_REVIEW MC-12)." else "Paralel analiz her tekrarda psych::fa.parallel ile (pc, simüle normal).",
               if (isTRUE(spec$analyses$pa$per_cell)) "Parallel analysis (pc, Pearson, simulated-normal reference, 95% quantile). Reference eigenvalues are computed once per condition with seed + 10000·condition (SPEC_REVIEW MC-12)." else "Parallel analysis with psych::fa.parallel in every replication (pc, simulated normal).")
    t6 <- make_table("T6", "Paralel analizin önerdiği faktör sayısı", "Number of factors suggested by parallel analysis",
      c(base_cols, list(tbl_col("correct", "Doğru sayı oranı", "Correct-number rate", "pct", 1L), tbl_col("dist", "Dağılım (k: oran)", "Distribution (k: rate)"))),
      pa, note_tr = n6$tr, note_en = n6$en)
    t6$rows_fmt$en$dist <- vapply(sm$cells[!vapply(sm$cells, function(c) is.null(c$pa), logical(1))], function(c)
      paste(sprintf("%s: %s", names(c$pa$distribution), vapply(unlist(c$pa$distribution), function(v) fmt_pct(v, "en", 1L), "")), collapse = "; "), "")
    tables[[length(tables) + 1L]] <- t6
  }
  # T7 örneklem büyüklüğü önerisi (MC-11)
  step_lab <- c(metric = "metrik", scalar = "skaler")
  rc <- do.call(rbind, lapply(sm$recommendations, function(r) data.frame(ratio = sim_ratio_label(spec, r$ratio), scenario = scen[r$scenario], estimator = r$estimator,
                                                                         power_step = if (is.na(r$power_step)) FMT_MISSING else unname(step_lab[r$power_step]),
                                                                         power_step_en = if (is.na(r$power_step)) FMT_MISSING else r$power_step,
                                                                         N = r$N, stringsAsFactors = FALSE)))
  ps_tr <- if (identical(spec$recommend$power_step, "auto")) "DIF'li parametreyi sınayan ilk" else step_lab[[spec$recommend$power_step]]
  ps_en <- if (identical(spec$recommend$power_step, "auto")) "first step that tests the DIF parameter (the" else paste("the", spec$recommend$power_step)
  n7 <- note(sprintf("Önerilen N: seçilen bütün ölçütlerin hem o N'de hem de ızgaradaki daha büyük bütün N'lerde sağlandığı en küçük N (SPEC_REVIEW MC-11). Ölçütler (Muthén ve Muthén, 2002): |parametre yanlılığı| ≤ %%%s, |SH yanlılığı| ≤ %%%s, kapsama %s–%s; uygun çözüm ≥ %s; DIF senaryolarında %s adımında Δχ² gücü ≥ %s. Öneri ızgara çözünürlüğüyle sınırlıdır.",
                     fmt_num(100 * spec$recommend$param_bias, 0, "tr"), fmt_num(100 * spec$recommend$se_bias, 0, "tr"),
                     fmt_num(spec$recommend$coverage[1], 2, "tr", TRUE), fmt_num(spec$recommend$coverage[2], 2, "tr", TRUE),
                     fmt_num(spec$recommend$admissible, 2, "tr", TRUE), ps_tr, fmt_num(spec$recommend$power, 2, "tr", TRUE)),
             sprintf("Recommended N: the smallest N at which all selected criteria hold at that N and at every larger N in the grid (SPEC_REVIEW MC-11). Criteria (Muthén & Muthén, 2002): |parameter bias| ≤ %s%%, |SE bias| ≤ %s%%, coverage %s–%s; admissible ≥ %s; in DIF scenarios Δχ² power ≥ %s at %s step). The recommendation is limited by the grid resolution.",
                     fmt_num(100 * spec$recommend$param_bias, 0, "en"), fmt_num(100 * spec$recommend$se_bias, 0, "en"),
                     fmt_num(spec$recommend$coverage[1], 2, "en", TRUE), fmt_num(spec$recommend$coverage[2], 2, "en", TRUE),
                     fmt_num(spec$recommend$admissible, 2, "en", TRUE), fmt_num(spec$recommend$power, 2, "en", TRUE), ps_en))
  t7 <- make_table("T7", "Örneklem büyüklüğü önerisi", "Sample-size recommendation",
    list(tbl_col("ratio", "Grup oranı", "Group ratio"), tbl_col("scenario", "Senaryo", "Scenario"), tbl_col("estimator", "Kestirici", "Estimator"),
         tbl_col("power_step", "Güç adımı", "Power step"), tbl_col("N", "Önerilen N", "Recommended N", "int")),
    rc, note_tr = n7$tr, note_en = n7$en)
  t7$rows_fmt$en$power_step <- rc$power_step_en
  for (lang in c("tr", "en")) t7$rows_fmt[[lang]]$N[is.na(rc$N)] <- if (lang == "tr") "ızgarada yok" else "not in grid"
  tables[[length(tables) + 1L]] <- t7

  # Şekiller: güç eğrileri (F1) ve göreli yanlılık ısı haritası (F2)
  figs <- list()
  if (!is.null(iv)) {
    series <- list()
    for (est in spec$estimators) for (sc in unique(iv$scenario)) for (st in unique(iv$step)) for (ra in unique(iv$ratio)) {
      x <- iv[iv$estimator == est & iv$scenario == sc & iv$step == st & iv$ratio == ra, ]
      x <- x[order(x$N), ]
      st_tr <- c(metric = "metrik", scalar = "skaler")[[st]]
      series[[length(series) + 1L]] <- list(name = sprintf("%s · %s · %s · %s", sc, est, st, ra), name_tr = sprintf("%s · %s · %s · %s", sc, est, st_tr, ra),
                                            name_en = sprintf("%s · %s · %s · %s", sc, est, st, ra), scenario = sc, estimator = est, step = st, ratio = ra,
                                            N = I(x$N), rate = I(x$reject_chisq), labels_tr = I(fmt_pct(x$reject_chisq, "tr", 1L)), labels_en = I(fmt_pct(x$reject_chisq, "en", 1L)))
    }
    ticks <- seq(0, 1, by = 0.2)
    figs[[length(figs) + 1L]] <- list(id = "F1", type = "power_curve", data = list(series = series, Ns = I(spec$Ns), target = spec$recommend$power, alpha = spec$criteria$alpha,
      y_ticks = I(ticks), y_labels_tr = I(fmt_pct(ticks, "tr", 0L)), y_labels_en = I(fmt_pct(ticks, "en", 0L)),
      target_label_tr = sprintf("güç hedefi %s", fmt_pct(spec$recommend$power, "tr", 0L)), target_label_en = sprintf("power target %s", fmt_pct(spec$recommend$power, "en", 0L))))
  }
  if (!is.null(pr)) {
    e1 <- spec$estimators[1]
    sub <- pr[pr$estimator == e1, ]
    # Gerçek değeri 0 olan parametrede göreli yanlılık tanımsızdır; o hücrede standartlaştırılmış yanlılık gösterilir ve * ile işaretlenir.
    is_std <- is.na(sub$rel_bias) & !is.na(sub$std_bias)
    val <- ifelse(is_std, sub$std_bias, sub$rel_bias)
    conds <- unique(sub$cond); params <- unique(sub$name)
    hm_label <- function(p, ci, lang) {
      k <- which(sub$name == p & sub$cond == ci)
      if (!length(k)) return(fmt_pct(NA, lang, 1L))
      paste0(fmt_pct(val[k[1]], lang, 1L), if (is_std[k[1]]) "*" else "")
    }
    figs[[length(figs) + 1L]] <- list(id = "F2", type = "bias_heatmap", data = list(estimator = e1, params = I(params),
      conditions = I(vapply(conds, function(ci) { g <- spec$grid[spec$grid$index == ci, ]; sprintf("N=%d · %s · %s", g$N, sim_ratio_label(spec, g$ratio), scen[g$scenario]) }, "")),
      values = lapply(params, function(p) I(vapply(conds, function(ci) { v <- val[sub$name == p & sub$cond == ci]; if (length(v)) v else NA_real_ }, 0))),
      labels_tr = lapply(params, function(p) I(vapply(conds, function(ci) hm_label(p, ci, "tr"), ""))),
      labels_en = lapply(params, function(p) I(vapply(conds, function(ci) hm_label(p, ci, "en"), ""))),
      note_tr = paste(c("Hücreler göreli yanlılıktır: (ortalama − gerçek) / gerçek.", if (any(is_std)) "* Gerçek değeri 0 olan parametre: standartlaştırılmış yanlılık, (ortalama − gerçek) / ampirik SS.", SIM_LABEL_TR), collapse = " "),
      note_en = paste(c("Cells show relative bias: (mean − true) / true.", if (any(is_std)) "* Parameter with true value 0: standardized bias, (mean − true) / empirical SD.", SIM_LABEL_EN), collapse = " ")))
  }
  make_record(
    module = "simulation", dataset_hash = "synthetic",
    settings = list(job_id = job_id, body = spec$body, estimators = I(spec$estimators), reps = spec$reps, seed = spec$seed,
                    seed_rule = "seed + 10000 * koşul + tekrar", grid = spec$grid, chunk_size = spec$chunk_size),
    seed = spec$seed, rng = list(kind = "Mersenne-Twister", normal_kind = "Inversion", sample_kind = "Rejection", mc_cores = 1L),
    results = list(label_tr = SIM_LABEL_TR, label_en = SIM_LABEL_EN, cells = sm$cells, recommendations = sm$recommendations,
                   truth = sm$truth),
    tables = tables, figures = figs,
    warnings = list(warning_item("simulation_label", SIM_LABEL_TR, SIM_LABEL_EN))
  )
}
