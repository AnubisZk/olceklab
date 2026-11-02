# M4 — Faktör sayısının belirlenmesi: paralel analiz, MAP, scree (SPEC §7 M4).
# Kurallar: SPEC_REVIEW PA-1…PA-6 (SPEC v1.1).
#  - psych::fa.parallel her zaman mc.cores = 1 ve sabit RNG türüyle çağrılır.
#  - Referans ortalama ve yüzdelik, psych'in döndürdüğü $values matrisinden R'de hesaplanır.
#  - parallel_manual psych'in algoritmasını ve RNG tüketim sırasını birebir izler.

quiet <- function(expr) {
  out <- NULL
  utils::capture.output(out <- collect_conditions(expr), file = nullfile())
  out
}

pa_settings <- function(settings, n_items) {
  s <- list(
    extraction = setting_choice(settings, "extraction", c("pc", "fa", "both")),
    correlation = setting_choice(settings, "correlation", c("pearson", "polychoric")),
    reference = setting_choice(settings, "reference", c("simulated_normal", "resampled_bootstrap", "permutation")),
    n_iter = setting_number(settings, "n_iter", 1000L, 1, 100000, integer = TRUE),
    criterion = setting_choice(settings, "criterion", c("quantile", "mean")),
    quant = setting_number(settings, "quant", 0.95, 0.5, 0.999),
    fm = setting_choice(settings, "fm", c("minres", "ml", "uls", "wls", "gls", "pa")),
    seed = setting_number(settings, "seed", 20261030L, 1, .Machine$integer.max, integer = TRUE),
    map_max = setting_number(settings, "map_max", min(8L, n_items - 1L), 1, n_items - 1L, integer = TRUE)
  )
  if (s$correlation == "polychoric" && s$reference == "simulated_normal") {
    api_stop("invalid_reference_for_polychoric",
             paste("Polikorik korelasyonla simüle normal referans kullanılamaz: psych bu durumda referansı",
                   "Pearson ile hesaplar. 'resampled_bootstrap' ya da 'permutation' seçin."), 422L)
  }
  s
}

pa_cor <- function(correlation) {
  if (correlation == "pearson") function(m) stats::cor(m, use = "pairwise")
  else function(m) suppressWarnings(psych::polychoric(m, correct = 0.5)$rho)
}

# Ortak faktör özdeğerleri: psych'in fa()$values tanımıyla aynı (fa.R: S <- r; diag(S) <- ortak varyans;
# eigen(S)$values). Ortak varyanslar tek faktörlü çözümden gelir (fa.parallel'deki nfactors = 1).
# Çağrı biçimleri fa.parallel.R ile birebir aynıdır (gözlenen: satır 64; yeniden örneklenmiş: satır 100;
# simüle: satır 112), çünkü varsayılan argümanlar RNG tüketimini etkileyebilir.
pa_fa_values <- function(R, fm, call = c("observed", "samp", "sim")) {
  call <- match.arg(call)
  fit <- switch(call,
    observed = psych::fa(R, nfactors = 1, rotate = "none", fm = fm, warnings = FALSE),
    samp = psych::fa(R, fm = fm, nfactors = 1, SMC = FALSE, warnings = FALSE),
    sim = psych::fa(R, fm = fm, nfactors = 1, rotate = "none", SMC = FALSE, warnings = FALSE))
  if (!(fm %in% c("minres", "ml", "uls", "wls", "gls"))) return(fit$values)
  S <- R
  diag(S) <- rowSums(unclass(fit$loadings)^2)
  eigen(S)$values
}

count_leading <- function(observed, reference) {
  which(!(observed > reference))[1] - 1L
}

# Şeffaf yeniden uygulama. Ham veri verildiğinde psych her yinelemede önce yeniden örnekler,
# sonra (sim = TRUE ise) normal veri üretir; RNG bu sırayla tüketilir.
parallel_manual <- function(x, n_iter, extraction = c("pc", "fa", "both"), correlation = c("pearson", "polychoric"),
                            reference = c("simulated_normal", "resampled_bootstrap", "permutation"),
                            fm = "minres", quant = 0.95) {
  extraction <- match.arg(extraction); correlation <- match.arg(correlation); reference <- match.arg(reference)
  x <- as.matrix(x)
  n <- nrow(x); p <- ncol(x)
  corf <- pa_cor(correlation)
  need_fa <- extraction != "pc"
  rx <- corf(x)
  obs_pc <- eigen(rx, only.values = TRUE)$values
  obs_fa <- if (need_fa) pa_fa_values(rx, fm, "observed") else NULL

  blank <- function() matrix(NA_real_, n_iter, p)
  samp <- blank(); samp_fa <- if (need_fa) blank(); sim <- blank(); sim_fa <- if (need_fa) blank()
  replace <- reference != "permutation"
  for (it in seq_len(n_iter)) {
    repeat {
      s <- matrix(apply(x, 2, function(y) if (replace) sample(y, n, replace = TRUE) else sample(y)), ncol = p)
      C <- suppressWarnings(corf(s))
      if (!any(is.na(C))) break
    }
    samp[it, ] <- eigen(C, only.values = TRUE)$values
    if (need_fa) samp_fa[it, ] <- pa_fa_values(C, fm, "samp")
    if (reference == "simulated_normal") {
      SC <- stats::cor(matrix(stats::rnorm(n * p), nrow = n, ncol = p))
      sim[it, ] <- eigen(SC, only.values = TRUE)$values
      if (need_fa) sim_fa[it, ] <- pa_fa_values(SC, fm, "sim")
    }
  }
  values <- cbind(samp, if (need_fa) samp_fa, if (reference == "simulated_normal") sim,
                  if (reference == "simulated_normal" && need_fa) sim_fa)
  ref_pc <- if (reference == "simulated_normal") sim else samp
  ref_fa <- if (!need_fa) NULL else if (reference == "simulated_normal") sim_fa else samp_fa
  list(observed_pc = obs_pc, observed_fa = obs_fa, reference_pc = ref_pc, reference_fa = ref_fa,
       values = unname(values))
}

# psych::fa.parallel'in $values matrisinden blokları ayırır (fa.parallel.R, satır 128–239).
psych_value_blocks <- function(values, p, extraction, sim) {
  blocks <- c("samp", if (extraction != "pc") "samp_fa", if (sim) "sim", if (sim && extraction != "pc") "sim_fa")
  stopifnot(ncol(values) == p * length(blocks))
  out <- lapply(seq_along(blocks), function(b) unname(values[, ((b - 1L) * p + 1L):(b * p), drop = FALSE]))
  stats::setNames(out, blocks)
}

run_parallel <- function(x, s) {
  p <- ncol(x)
  if (s$reference == "permutation") {
    run <- with_seeded_rng(s$seed, quiet(parallel_manual(x, s$n_iter, s$extraction, s$correlation, "permutation", s$fm, s$quant)))
    m <- run$value$value
    return(list(observed_pc = m$observed_pc, observed_fa = m$observed_fa, reference_pc = m$reference_pc,
                reference_fa = m$reference_fa, psych = NULL, rng = run$rng, warnings = run$value$warnings,
                source = "parallel_manual"))
  }
  sim <- s$reference == "simulated_normal"
  run <- with_seeded_rng(s$seed, quiet(psych::fa.parallel(
    x, fm = s$fm, fa = s$extraction, n.iter = s$n_iter, sim = sim, quant = s$quant,
    cor = if (s$correlation == "pearson") "cor" else "poly", plot = FALSE)))
  pa <- run$value$value
  bl <- psych_value_blocks(pa$values, p, s$extraction, sim)
  list(
    observed_pc = pa$pc.values,
    observed_fa = if (s$extraction != "pc") pa$fa.values else NULL,
    reference_pc = if (sim) bl$sim else bl$samp,
    reference_fa = if (s$extraction == "pc") NULL else if (sim) bl$sim_fa else bl$samp_fa,
    psych = list(ncomp = pa$ncomp, nfact = pa$nfact, values = pa$values),
    rng = run$rng, warnings = run$value$warnings, source = "psych::fa.parallel"
  )
}

pa_summarise <- function(observed, reference, quant, criterion) {
  if (is.null(observed)) return(NULL)
  ref_mean <- colMeans(reference)
  ref_q <- apply(reference, 2, stats::quantile, quant)
  used <- if (criterion == "mean") ref_mean else ref_q
  n <- count_leading(observed, used)
  list(observed = observed, reference_mean = unname(ref_mean), reference_quantile = unname(ref_q),
       suggested = n, all_above = is.na(n))
}

# Grafik ipuçları için R'de biçimlenmiş etiketler (ön yüz sayı biçimlemez).
scree_labels <- function(pc, fa, criterion) {
  ref <- function(x) if (is.null(x)) NULL else if (criterion == "mean") x$reference_mean else x$reference_quantile
  lab <- function(lang) list(
    pc_observed = if (!is.null(pc)) I(fmt_num(pc$observed, 3L, lang)), pc_reference = if (!is.null(pc)) I(fmt_num(ref(pc), 3L, lang)),
    fa_observed = if (!is.null(fa)) I(fmt_num(fa$observed, 3L, lang)), fa_reference = if (!is.null(fa)) I(fmt_num(ref(fa), 3L, lang)))
  list(tr = lab("tr"), en = lab("en"))
}

analysis_factor_number <- function(data, config, settings, dataset_hash) {
  items <- config$items$name
  x <- data[, items, drop = FALSE]
  p <- length(items)
  if (p < 3L) api_stop("too_few_items", "Faktör sayısı için en az üç madde gerekir.", 422L)
  if (nrow(x) <= p) api_stop("too_few_rows", "Gözlem sayısı madde sayısından büyük olmalıdır.", 422L)
  s <- pa_settings(settings, p)
  if (s$correlation == "polychoric" && any(is.na(config$items$min))) {
    api_stop("polychoric_needs_categories", "Polikorik korelasyon için bütün maddelerde kategori aralığı tanımlanmalıdır.", 422L)
  }

  pa <- run_parallel(x, s)
  pc <- pa_summarise(pa$observed_pc, pa$reference_pc, s$quant, s$criterion)
  fa <- pa_summarise(pa$observed_fa, pa$reference_fa, s$quant, s$criterion)

  # psych'in kendi kararıyla tutarlılık (yalnızca quantile ölçütünde birebir karşılaştırılabilir)
  psych_check <- NULL
  if (!is.null(pa$psych)) {
    psych_check <- list(ncomp = as.integer(pa$psych$ncomp), nfact = as.integer(pa$psych$nfact))
    if (s$criterion == "quantile") {
      ok_pc <- s$extraction == "fa" || identical(as.integer(pa$psych$ncomp), as.integer(pc$suggested))
      ok_fa <- s$extraction == "pc" || identical(as.integer(pa$psych$nfact), as.integer(fa$suggested))
      if (!ok_pc || !ok_fa) {
        api_stop("internal_mismatch", "Motorun hesapladığı karar psych::fa.parallel ile uyuşmuyor.", 500L,
                 sprintf("psych ncomp=%s nfact=%s; motor pc=%s fa=%s", pa$psych$ncomp, pa$psych$nfact,
                         if (is.null(pc)) NA else pc$suggested, if (is.null(fa)) NA else fa$suggested))
      }
    }
  }

  vss <- quiet(psych::vss(x, n = s$map_max, rotate = "none", fm = "minres", plot = FALSE,
                          cor = if (s$correlation == "pearson") "cor" else "poly"))
  map <- vss$value$map
  map_suggested <- which.min(map)
  kaiser <- sum(pa$observed_pc > 1)

  # Tablolar
  k <- seq_len(p)
  crit_tr <- if (s$criterion == "mean") "ortalama" else sprintf("%%%s yüzdelik", fmt_num(100 * s$quant, 0, "tr"))
  crit_en <- if (s$criterion == "mean") "mean" else sprintf("%s%% quantile", fmt_num(100 * s$quant, 0, "en"))
  rows <- data.frame(k = k)
  cols <- list(tbl_col("k", "Sıra", "No.", "int"))
  if (!is.null(pc)) {
    rows$pc_obs <- pc$observed; rows$pc_mean <- pc$reference_mean; rows$pc_q <- pc$reference_quantile
    cols <- c(cols, list(tbl_col("pc_obs", "TB gözlenen", "PC observed", "num", 3L),
      tbl_col("pc_mean", paste("TB referans ortalama", if (s$criterion == "mean") "(karar)" else ""),
              paste("PC reference mean", if (s$criterion == "mean") "(decision)" else ""), "num", 3L),
      tbl_col("pc_q", paste0("TB referans %", fmt_num(100 * s$quant, 0, "tr"), if (s$criterion == "quantile") " (karar)" else ""),
              paste0("PC reference ", fmt_num(100 * s$quant, 0, "en"), "%", if (s$criterion == "quantile") " (decision)" else ""),
              "num", 3L)))
  }
  if (!is.null(fa)) {
    rows$fa_obs <- fa$observed; rows$fa_mean <- fa$reference_mean; rows$fa_q <- fa$reference_quantile
    cols <- c(cols, list(tbl_col("fa_obs", "OF gözlenen", "FA observed", "num", 3L),
      tbl_col("fa_mean", paste("OF referans ortalama", if (s$criterion == "mean") "(karar)" else ""),
              paste("FA reference mean", if (s$criterion == "mean") "(decision)" else ""), "num", 3L),
      tbl_col("fa_q", paste0("OF referans %", fmt_num(100 * s$quant, 0, "tr"), if (s$criterion == "quantile") " (karar)" else ""),
              paste0("FA reference ", fmt_num(100 * s$quant, 0, "en"), "%", if (s$criterion == "quantile") " (decision)" else ""),
              "num", 3L)))
  }
  ref_label_tr <- switch(s$reference, simulated_normal = "simüle normal veri", resampled_bootstrap = "sütun içi yerine koyarak yeniden örnekleme", permutation = "sütun içi permütasyon")
  ref_label_en <- switch(s$reference, simulated_normal = "simulated normal data", resampled_bootstrap = "column-wise resampling with replacement", permutation = "column-wise permutation")
  src_call <- if (pa$source == "parallel_manual") "factor_number.R::parallel_manual" else "psych::fa.parallel"
  note_args <- sprintf("fa = '%s', n.iter = %d, quant = %s, cor = '%s', fm = '%s', mc.cores = 1, seed = %d",
                       s$extraction, s$n_iter, format(s$quant), if (s$correlation == "pearson") "cor" else "poly", s$fm, s$seed)
  t1 <- make_table("T1", "Paralel analiz: gözlenen ve referans özdeğerler", "Parallel analysis: observed and reference eigenvalues",
    cols, rows,
    note_tr = sprintf("TB: temel bileşen; OF: ortak faktör. Referans: %s; ölçüt: %s. Kaynak: %s (%s); psych %s.",
                      ref_label_tr, crit_tr, src_call, note_args, as.character(utils::packageVersion("psych"))),
    note_en = sprintf("PC: principal component; FA: common factor. Reference: %s; criterion: %s. Source: %s (%s); psych %s.",
                      ref_label_en, crit_en, src_call, note_args, as.character(utils::packageVersion("psych"))))

  sug <- data.frame(method = character(), label_tr = character(), label_en = character(), n = integer(), stringsAsFactors = FALSE)
  if (!is.null(pc)) sug[nrow(sug) + 1L, ] <- list("pa_pc", "Paralel analiz (temel bileşen)", "Parallel analysis (principal components)", pc$suggested)
  if (!is.null(fa)) sug[nrow(sug) + 1L, ] <- list("pa_fa", "Paralel analiz (ortak faktör)", "Parallel analysis (common factors)", fa$suggested)
  sug[nrow(sug) + 1L, ] <- list("map", "Velicer MAP", "Velicer's MAP", map_suggested)
  sug[nrow(sug) + 1L, ] <- list("kaiser", "Özdeğer > 1 (yalnızca bilgi)", "Eigenvalue > 1 (information only)", kaiser)
  t2 <- make_table("T2", "Önerilen faktör sayısı", "Suggested number of factors",
    list(tbl_col("label_tr", "Yöntem", "Method"), tbl_col("n", "Önerilen sayı", "Suggested", "int")), sug,
    note_tr = sprintf("MAP: psych::vss(n = %d)$map; Velicer'in (1976) karesel kısmi korelasyonlu özgün sürümü, 0 faktör öneremez.", s$map_max),
    note_en = sprintf("MAP: psych::vss(n = %d)$map; Velicer's (1976) original squared-partial version, cannot suggest 0 factors.", s$map_max))
  t2$rows_fmt$en$label_tr <- sug$label_en
  t3 <- make_table("T3", "Velicer MAP değerleri", "Velicer's MAP values",
    list(tbl_col("k", "Faktör sayısı", "Factors", "int"), tbl_col("map", "Ortalama kare kısmi korelasyon", "Average squared partial correlation", "num", 4L)),
    data.frame(k = seq_along(map), map = map))

  # Karar destek metni (şablon; yapay zekâ değil)
  num_tr <- function(v) fmt_int(v, "tr"); num_en <- function(v) fmt_int(v, "en")
  pa_part_tr <- paste(c(if (!is.null(pc)) sprintf("%s bileşen", num_tr(pc$suggested)), if (!is.null(fa)) sprintf("%s faktör", num_tr(fa$suggested))), collapse = " ve ")
  pa_part_en <- paste(c(if (!is.null(pc)) sprintf("%s component(s)", num_en(pc$suggested)), if (!is.null(fa)) sprintf("%s factor(s)", num_en(fa$suggested))), collapse = " and ")
  decision_tr <- paste0(sprintf("Paralel analiz %s, Velicer MAP %s faktör önermektedir. ", pa_part_tr, num_tr(map_suggested)),
    "Faktörler arası korelasyonlar yüksek olduğunda paralel analiz faktör sayısını düşük kestirebilir (Crawford vd., 2010; Garrido vd., 2013); ",
    "faktör sayısı kararı kuramsal yapı ve rakip DFA modelleriyle birlikte verilmelidir.")
  decision_en <- paste0(sprintf("Parallel analysis suggests %s and Velicer's MAP suggests %s factor(s). ", pa_part_en, num_en(map_suggested)),
    "When factors are highly correlated, parallel analysis may underestimate the number of factors (Crawford et al., 2010; Garrido et al., 2013); ",
    "the decision should be made together with theory and competing CFA models.")

  warns <- list()
  if (isTRUE(pc$all_above) || isTRUE(fa$all_above)) warns[[length(warns) + 1L]] <- warning_item("all_above_reference",
    "Bütün gözlenen özdeğerler referansın üstünde; önerilen sayı tanımsızdır.",
    "All observed eigenvalues exceed the reference; the suggested number is undefined.")
  for (w in unique(c(pa$warnings, vss$warnings))) warns[[length(warns) + 1L]] <- warning_item("psych_warning", w, w)

  make_record(
    module = "factor_number", dataset_hash = dataset_hash,
    settings = c(s[c("extraction", "correlation", "reference", "n_iter", "criterion", "quant", "fm", "map_max")], list(items = I(items))),
    seed = s$seed, rng = pa$rng,
    results = list(
      n = nrow(x), p = p, source = pa$source,
      pc = pc, fa = fa,
      map = list(values = I(map), suggested = map_suggested),
      kaiser = kaiser,
      psych_check = psych_check,
      decision_tr = decision_tr, decision_en = decision_en
    ),
    tables = list(t1, t2, t3),
    figures = list(list(id = "F1", type = "scree", data = list(
      k = I(k), labels = scree_labels(pc, fa, s$criterion),
      pc_observed = if (!is.null(pc)) pc$observed, pc_reference = if (!is.null(pc)) (if (s$criterion == "mean") pc$reference_mean else pc$reference_quantile),
      fa_observed = if (!is.null(fa)) fa$observed, fa_reference = if (!is.null(fa)) (if (s$criterion == "mean") fa$reference_mean else fa$reference_quantile),
      criterion = s$criterion, quant = s$quant))),
    warnings = warns
  )
}
