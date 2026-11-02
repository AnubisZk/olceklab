# M8 — Ölçme değişmezliği ve gizil ortalamalar (SPEC §7 M8; SPEC_REVIEW I-1…I-5).
#
# Sürekli yaklaşım (ML/MLR): biçimsel → metrik (loadings) → skaler (+ intercepts) → isteğe bağlı katı (+ residuals),
#   lavaan::cfa(group, group.equal, group.partial). §11.3: ML, likelihood = "wishart", std.lv = TRUE.
# Kategorik yaklaşım (WLSMV, theta): semTools::measEq.syntax(ID.fac = "std.lv", ID.cat = "Wu.Estabrook.2016"):
#   biçimsel → eşikler → eşikler + yükler → + kesişimler → + artık varyanslar. Bütün maddeler üç kategoriliyse eşik
#   adımı biçimselle eşdeğerdir ve atlanır; ikili madde içeren ölçeklerde kategorik değişmezlik v1'de kapalıdır.
# Δ = kısıtlı − daha az kısıtlı. Robust kestiricilerde Δ'lar .scaled indekslerle (robust indeksler kısıtlı çok gruplu
#   modellerde tanımsızdır, SPEC_REVIEW W-1/I-2). Fark testi: ML standart, MLR Satorra–Bentler (2001), WLSMV Satorra (2000).

inv_step_defs <- function(approach) {
  if (approach == "continuous") {
    list(configural = character(0), metric = "loadings", scalar = c("loadings", "intercepts"),
         strict = c("loadings", "intercepts", "residuals"))
  } else {
    list(configural = character(0), thresholds = "thresholds", metric = c("thresholds", "loadings"),
         scalar = c("thresholds", "loadings", "intercepts"), strict = c("thresholds", "loadings", "intercepts", "residuals"))
  }
}

inv_step_label <- function(step, approach, lang) {
  cont <- approach == "continuous"
  lab <- switch(step,
    configural = c("Biçimsel", "Configural"),
    thresholds = c("Eşikler", "Thresholds"),
    metric = if (cont) c("Yükler (metrik)", "Loadings (metric)") else c("Eşikler + yükler (metrik)", "Thresholds + loadings (metric)"),
    scalar = if (cont) c("Yükler + kesişimler (skaler)", "Loadings + intercepts (scalar)") else
      c("Eşikler + yükler + kesişimler (skaler)", "Thresholds + loadings + intercepts (scalar)"),
    strict = if (cont) c("+ artık varyanslar (katı)", "+ residual variances (strict)") else
      c("+ artık varyanslar (katı)", "+ residual variances (strict)"))
  lab[if (lang == "tr") 1L else 2L]
}

inv_settings <- function(settings) {
  cr <- if (is.list(settings$criteria)) settings$criteria else list()
  approach <- setting_choice(settings, "approach", c("continuous", "categorical"))
  est <- if (approach == "categorical") "WLSMV" else setting_choice(settings, "estimator", c("ML", "MLR"))
  if (approach == "categorical" && !is.null(settings$estimator) && !identical(settings$estimator, "WLSMV")) {
    api_stop("invalid_setting", "Kategorik değişmezlik WLSMV (theta) ile kestirilir.", 422L)
  }
  s <- list(
    approach = approach, estimator = est,
    likelihood = setting_choice(settings, "likelihood", c("normal", "wishart")),
    std_lv = setting_flag(settings, "std_lv", TRUE),
    include_strict = setting_flag(settings, "include_strict", FALSE),
    reference_group = if (is.null(settings$reference_group)) NULL else as.character(settings$reference_group)[1],
    srmr_type = setting_choice(settings, "srmr_type", c("bentler_nomean", "srmr")),
    rule = setting_choice(settings, "rule", c("none", "and", "or")),
    d_sd = setting_choice(settings, "d_sd", c("pooled", "reference")),
    cfi = setting_number(cr, "cfi", -0.01, -1, 0),
    rmsea = setting_number(cr, "rmsea", 0.015, 0, 1),
    srmr_load = setting_number(cr, "srmr_load", 0.030, 0, 1),
    srmr_int = setting_number(cr, "srmr_int", 0.010, 0, 1),
    alpha = setting_number(cr, "alpha", 0.05, 0.0001, 0.5),
    seed = setting_number(settings, "seed", 20261030L, 1, .Machine$integer.max, integer = TRUE)
  )
  if (s$likelihood == "wishart" && s$estimator != "ML") api_stop("wishart_only_ml", "likelihood = \"wishart\" yalnızca ML kestiricisiyle seçilebilir.", 422L)
  p <- settings$partial
  s$partial <- if (is.null(p) || !length(p)) character(0) else unique(trimws(as.character(unlist(p))))
  s$partial <- s$partial[nzchar(s$partial)]
  bad <- s$partial[!grepl("^[\\p{L}.][\\p{L}\\p{N}._]*(=~[\\p{L}.][\\p{L}\\p{N}._]*|~1|~~[\\p{L}.][\\p{L}\\p{N}._]*|\\|t[0-9]+)$", gsub("\\s+", "", s$partial), perl = TRUE)]
  if (length(bad)) api_stop("invalid_partial", sprintf("Serbest bırakılacak parametre lavaan biçiminde olmalıdır (ör. F=~x1, x1~1, x1|t1): %s", paste(bad, collapse = ", ")), 422L)
  s$partial <- gsub("\\s+", "", s$partial)
  s
}

inv_groups <- function(x, grp, config, ref) {
  g <- as.character(x[[grp]])
  present <- unique(g[!is.na(g)])
  labels <- if (length(config$group_valid_values)) intersect(as.character(config$group_valid_values), present) else present
  labels <- c(labels, setdiff(present, labels))
  if (!is.null(ref)) {
    if (!(ref %in% labels)) api_stop("invalid_reference_group", sprintf("Referans grup veride yok: %s", ref), 422L)
    labels <- c(ref, setdiff(labels, ref))
  }
  if (length(labels) < 2L) api_stop("too_few_groups", "Değişmezlik için temiz veride en az iki grup olmalıdır.", 422L)
  labels
}

inv_fit_args <- function(s, grp, labels, items, eq) {
  if (s$approach == "continuous") {
    a <- list(estimator = s$estimator)
    if (s$estimator == "ML") a$likelihood <- s$likelihood
    a$std.lv <- s$std_lv
    a$group <- grp; a$group.label <- labels
    if (length(eq)) a$group.equal <- eq
    if (length(eq) && length(s$partial)) a$group.partial <- s$partial
  } else {
    a <- list(estimator = "WLSMV", parameterization = "theta", ordered = as.character(items), group = grp, group.label = labels)
  }
  a
}

inv_measeq_syntax <- function(m, x, items, grp, labels, eq, partial) {
  syn <- tryCatch(quiet(semTools::measEq.syntax(configural.model = m$syntax, data = x, ordered = as.character(items),
                                                parameterization = "theta", ID.fac = "std.lv", ID.cat = "Wu.Estabrook.2016",
                                                group = grp, group.label = labels,
                                                group.equal = if (length(eq)) eq else "",
                                                group.partial = if (length(partial)) partial else ""))$value,
                  error = function(e) api_stop("measeq_failed", "semTools::measEq.syntax modeli kuramadı.", 422L, conditionMessage(e)))
  as.character(syn)
}

inv_fit_step <- function(step, eq, m, x, items, grp, labels, s) {
  args <- inv_fit_args(s, grp, labels, items, eq)
  syntax <- if (s$approach == "continuous") m$syntax else inv_measeq_syntax(m, x, items, grp, labels, eq, s$partial)
  ft <- cfa_fit(syntax, x, args)
  ft$syntax <- syntax; ft$args <- args; ft$step <- step; ft$eq <- eq
  ft
}

inv_fit_measures <- function(fit) {
  fm <- cfa_fit_measures(fit)
  fm$srmr_bentler_nomean <- tryCatch(as.numeric(quiet(lavaan::fitMeasures(fit, "srmr_bentler_nomean"))$value), error = function(e) NA_real_)
  fm
}

inv_item_categories <- function(x, items) vapply(items, function(i) length(unique(stats::na.omit(x[[i]]))), integer(1))

# Gizil ortalamalar için koşul: her faktörde yükü ve kesişimi (kategorikte eşikleri) serbest bırakılmamış en az iki madde.
inv_latent_mean_ok <- function(m, partial, approach) {
  freed_load <- sub("^.*=~", "", grep("=~", partial, value = TRUE))
  freed_load_f <- grep("=~", partial, value = TRUE)
  freed_int <- sub("~1$", "", grep("~1$", partial, value = TRUE))
  freed_thr <- if (approach == "categorical") sub("\\|t[0-9]+$", "", grep("\\|t[0-9]+$", partial, value = TRUE)) else character(0)
  fo <- Filter(function(f) f$name %in% m$first_order, m$factors)
  ok <- vapply(fo, function(f) {
    inv <- f$items[!(paste0(f$name, "=~", f$items) %in% freed_load_f) & !(f$items %in% freed_int) & !(f$items %in% freed_thr)]
    length(inv) >= 2L
  }, logical(1))
  stats::setNames(ok, vapply(fo, `[[`, "", "name"))
}

# Gizil ortalama modeli: referans grupta ortalama 0, varyans 1 (std.lv); d lavaan sözdiziminde := ile tanımlanır.
inv_latent_syntax <- function(base_syntax, factors, labels, n, s) {
  G <- length(labels)
  lines <- character()
  defs <- list()
  for (f in factors) {
    if (s$approach == "continuous") {
      ml <- sprintf("olc_m_%s_g%d", f, seq_len(G)); vl <- sprintf("olc_v_%s_g%d", f, seq_len(G))
      lines <- c(lines,
                 sprintf("%s ~ c(%s)*1 + c(%s)*1", f, paste(c("0", rep("NA", G - 1L)), collapse = ", "), paste(ml, collapse = ", ")),
                 sprintf("%s ~~ c(%s)*%s + c(%s)*%s", f, paste(c("1", rep("NA", G - 1L)), collapse = ", "), f, paste(vl, collapse = ", "), f))
    } else {
      sl <- strsplit(base_syntax, "\n", fixed = TRUE)[[1]]
      fe <- gsub(".", "\\.", f, fixed = TRUE)
      mline <- grep(sprintf("^\\s*%s ~ c\\(0", fe), sl, value = TRUE)
      vline <- grep(sprintf("^\\s*%s ~~ c\\(1[^)]*\\)\\*%s \\+", fe, fe), sl, value = TRUE)
      if (length(mline) != 1L || length(vline) != 1L) api_stop("latent_labels_missing", "measEq sözdiziminde gizil ortalama etiketleri bulunamadı.", 500L, f)
      ml <- trimws(strsplit(sub(".*\\+ c\\(([^)]*)\\)\\*1\\s*$", "\\1", mline), ",")[[1]])
      vl <- trimws(strsplit(sub(sprintf(".*\\+ c\\(([^)]*)\\)\\*%s\\s*$", fe), "\\1", vline), ",")[[1]])
    }
    for (k in seq_len(G)[-1]) {
      nm <- sprintf("olc_d_%s_g%d", f, k)
      rhs <- if (s$d_sd == "pooled") {
        sprintf("%s / sqrt(((%d - 1) * 1 + (%d - 1) * %s) / (%d + %d - 2))", ml[k], as.integer(n[1]), as.integer(n[k]), vl[k], as.integer(n[1]), as.integer(n[k]))
      } else sprintf("%s / 1", ml[k])
      lines <- c(lines, sprintf("%s := %s", nm, rhs))
      defs[[length(defs) + 1L]] <- list(factor = f, group = labels[k], k = k, name = nm, mean_label = ml[k])
    }
  }
  list(syntax = paste(c(base_syntax, lines), collapse = "\n"), defs = defs)
}

inv_decisions <- function(cmp, s) {
  load_step <- cmp$step %in% c("metric")
  srmr_lim <- ifelse(load_step, s$srmr_load, s$srmr_int)
  data.frame(cfi_ok = cmp$delta_cfi >= s$cfi, rmsea_ok = cmp$delta_rmsea <= s$rmsea, srmr_ok = cmp$delta_srmr <= srmr_lim,
             chisq_ok = cmp$p >= s$alpha, srmr_lim = srmr_lim)
}

inv_prepare <- function(data, config, settings) {
  s <- inv_settings(settings)
  grp <- config$group
  if (is.null(grp)) api_stop("no_group", "Değişmezlik için Veri sayfasında bir grup değişkeni seçilmelidir.", 422L)
  m <- resolve_model(settings$model, config$items$name)
  items <- m$observed
  x <- data[, c(items, grp), drop = FALSE]
  x <- x[!is.na(x[[grp]]), , drop = FALSE]
  x[[grp]] <- as.character(x[[grp]])
  labels <- inv_groups(x, grp, config, s$reference_group)
  x <- x[x[[grp]] %in% labels, , drop = FALSE]
  ng <- table(factor(x[[grp]], levels = labels))
  small <- names(ng)[ng <= length(items)]
  if (length(small)) api_stop("group_too_small", sprintf("Şu grupların gözlem sayısı madde sayısından büyük olmalıdır: %s.", paste(small, collapse = ", ")), 422L)
  if (s$approach == "categorical") {
    if (any(is.na(config$items$min[match(items, config$items$name)]))) {
      api_stop("wlsmv_needs_categories", "Kategorik değişmezlik için bütün maddelerde kategori aralığı tanımlanmalıdır.", 422L)
    }
    cats <- inv_item_categories(x, items)
    if (any(cats <= 2L)) {
      api_stop("binary_items_not_supported", sprintf("İkili (iki kategorili) madde içeren ölçeklerde kategorik değişmezlik v1'de kapalıdır: %s.", paste(items[cats <= 2L], collapse = ", ")), 422L)
    }
  }
  steps <- inv_step_defs(s$approach)
  notes <- character()
  if (s$approach == "categorical" && all(inv_item_categories(x, items) == 3L)) {
    steps$thresholds <- NULL
    notes <- c(notes, "thresholds_skipped")
  }
  if (!s$include_strict) steps$strict <- NULL
  list(s = s, m = m, items = items, x = x, grp = grp, labels = labels, steps = steps, notes = notes, n = as.integer(ng))
}

analysis_invariance <- function(data, config, settings, dataset_hash) {
  pr <- inv_prepare(data, config, settings)
  s <- pr$s; m <- pr$m
  run <- with_seeded_rng(s$seed, {
    fits <- lapply(names(pr$steps), function(st) inv_fit_step(st, pr$steps[[st]], m, pr$x, pr$items, pr$grp, pr$labels, s))
    names(fits) <- names(pr$steps)
    fits
  })
  fits <- run$value
  fms <- lapply(fits, function(f) inv_fit_measures(f$fit))
  robust <- s$estimator != "ML"
  pick <- function(f, k) f[[if (robust && k %in% c("chisq", "df", "pvalue", "cfi", "tli", "rmsea", "rmsea_ci_lower", "rmsea_ci_upper")) paste0(k, "_scaled") else k]]
  srmr_key <- if (s$srmr_type == "bentler_nomean") "srmr_bentler_nomean" else "srmr"
  method <- cfa_lrt_method(s$estimator)
  warns <- m$warnings
  steps <- names(fits)
  cmps <- list()
  for (k in seq_along(steps)[-1]) {
    a <- fits[[k - 1L]]$fit; b <- fits[[k]]$fit
    lr <- cfa_lrt(a, b, method)
    if (method == "satorra.bentler.2001" && isTRUE(lr$chisq_diff < 0)) {
      lr <- cfa_lrt(a, b, "satorra.bentler.2010")
      warns[[length(warns) + 1L]] <- warning_item("sb2001_negative",
        sprintf("%s adımında Satorra–Bentler (2001) farkı negatif çıktı; Satorra–Bentler (2010) ile yeniden hesaplandı.", inv_step_label(steps[k], s$approach, "tr")),
        sprintf("At step %s the Satorra–Bentler (2001) difference was negative; recomputed with Satorra–Bentler (2010).", inv_step_label(steps[k], s$approach, "en")))
    }
    if (!is.null(lr$error)) warns[[length(warns) + 1L]] <- warning_item("lrt_failed", paste("Fark testi hesaplanamadı:", lr$error), paste("Difference test failed:", lr$error))
    for (w in cfa_lavaan_warnings(lr$warnings)) warns[[length(warns) + 1L]] <- w
    cmps[[length(cmps) + 1L]] <- data.frame(step = steps[k], reference = steps[k - 1L],
      chisq_diff = lr$chisq_diff, df_diff = lr$df_diff, p = lr$p, method = lr$method,
      delta_cfi = pick(fms[[k]], "cfi") - pick(fms[[k - 1L]], "cfi"),
      delta_rmsea = pick(fms[[k]], "rmsea") - pick(fms[[k - 1L]], "rmsea"),
      delta_srmr = fms[[k]][[srmr_key]] - fms[[k - 1L]][[srmr_key]], stringsAsFactors = FALSE)
  }
  cmp <- do.call(rbind, cmps)
  dec <- inv_decisions(cmp, s)
  combined <- switch(s$rule, none = rep(NA, nrow(cmp)), and = dec$cfi_ok & dec$rmsea_ok, or = dec$cfi_ok | dec$rmsea_ok)

  # T1 adım adım uyum
  suf_tr <- if (robust) " (ölç.)" else ""; suf_en <- if (robust) " (sc.)" else ""
  t1_rows <- data.frame(step = steps, label = vapply(steps, inv_step_label, "", s$approach, "tr"),
    chisq = vapply(fms, pick, 0, "chisq"), df = vapply(fms, pick, 0, "df"), p = vapply(fms, pick, 0, "pvalue"),
    cfi = vapply(fms, pick, 0, "cfi"), tli = vapply(fms, pick, 0, "tli"), rmsea = vapply(fms, pick, 0, "rmsea"),
    rmsea_ci = NA_character_, srmr = vapply(fms, `[[`, 0, "srmr"), srmr_bn = vapply(fms, `[[`, 0, "srmr_bentler_nomean"),
    stringsAsFactors = FALSE)
  t1 <- make_table("T1", "Ölçme değişmezliği: adım adım uyum", "Measurement invariance: fit by step",
    list(tbl_col("label", "Adım", "Step"), tbl_col("chisq", paste0("χ²", suf_tr), paste0("χ²", suf_en), "num", 3L),
         tbl_col("df", "sd", "df", "int"), tbl_col("p", "p", "p", "p"),
         tbl_col("cfi", paste0("CFI", suf_tr), paste0("CFI", suf_en), "num", 3L, TRUE), tbl_col("tli", paste0("TLI", suf_tr), paste0("TLI", suf_en), "num", 3L),
         tbl_col("rmsea", paste0("RMSEA", suf_tr), paste0("RMSEA", suf_en), "num", 3L, TRUE), tbl_col("rmsea_ci", "RMSEA %90 GA", "RMSEA 90% CI"),
         tbl_col("srmr", "SRMR (lavaan)", "SRMR (lavaan)", "num", 4L, TRUE), tbl_col("srmr_bn", "SRMR (Bentler, ortalamasız)", "SRMR (Bentler, no mean)", "num", 4L, TRUE)),
    t1_rows,
    note_tr = paste0(sprintf("Kaynak: %s; lavaan %s, semTools %s. Gruplar: %s (referans: %s); n = %s. ",
                             if (s$approach == "continuous") sprintf("lavaan::cfa (estimator = '%s'%s, std.lv = %s, group.equal, group.partial)", s$estimator,
                                                                     if (s$estimator == "ML") sprintf(", likelihood = '%s'", s$likelihood) else "", if (s$std_lv) "TRUE" else "FALSE")
                             else "semTools::measEq.syntax (parameterization = 'theta', ID.fac = 'std.lv', ID.cat = 'Wu.Estabrook.2016'), lavaan::cfa (WLSMV)",
                             as.character(utils::packageVersion("lavaan")), as.character(utils::packageVersion("semTools")),
                             paste(pr$labels, collapse = ", "), pr$labels[1], paste(pr$n, collapse = " / ")),
                     if (length(s$partial)) sprintf("Serbest bırakılan parametreler (group.partial): %s. ", paste(s$partial, collapse = ", ")) else "",
                     "Çok gruplu SRMR için iki değer de gösterilir; raporun varsayılan değeri Bentler (ortalamasız) SRMR'dir.",
                     if ("thresholds_skipped" %in% pr$notes) " Bütün maddeler üç kategorili olduğu için eşik adımı biçimselle eşdeğerdir (sd farkı 0) ve atlandı (Wu ve Estabrook, 2016)." else ""),
    note_en = paste0(sprintf("Source: %s; lavaan %s, semTools %s. Groups: %s (reference: %s); n = %s. ",
                             if (s$approach == "continuous") sprintf("lavaan::cfa (estimator = '%s'%s, std.lv = %s, group.equal, group.partial)", s$estimator,
                                                                     if (s$estimator == "ML") sprintf(", likelihood = '%s'", s$likelihood) else "", if (s$std_lv) "TRUE" else "FALSE")
                             else "semTools::measEq.syntax (parameterization = 'theta', ID.fac = 'std.lv', ID.cat = 'Wu.Estabrook.2016'), lavaan::cfa (WLSMV)",
                             as.character(utils::packageVersion("lavaan")), as.character(utils::packageVersion("semTools")),
                             paste(pr$labels, collapse = ", "), pr$labels[1], paste(pr$n, collapse = " / ")),
                     if (length(s$partial)) sprintf("Freed parameters (group.partial): %s. ", paste(s$partial, collapse = ", ")) else "",
                     "Both multigroup SRMR values are shown; the default report value is Bentler's SRMR without means.",
                     if ("thresholds_skipped" %in% pr$notes) " All items have three categories, so the thresholds step is equivalent to configural (df difference 0) and was skipped (Wu & Estabrook, 2016)." else ""))
  t1$rows_fmt$en$label <- vapply(steps, inv_step_label, "", s$approach, "en")
  for (lang in c("tr", "en")) t1$rows_fmt[[lang]]$rmsea_ci <- vapply(fms, function(f) fmt_ci(pick(f, "rmsea_ci_lower"), pick(f, "rmsea_ci_upper"), 3L, lang, TRUE), "")

  # T2 karşılaştırmalar ve kararlar
  method_label <- c(standard = "χ² farkı (ML)", satorra.2000 = "Satorra (2000)", satorra.bentler.2001 = "Satorra–Bentler (2001)", satorra.bentler.2010 = "Satorra–Bentler (2010)")
  t2_rows <- data.frame(step = cmp$step, label = vapply(cmp$step, inv_step_label, "", s$approach, "tr"),
                        ref = vapply(cmp$reference, inv_step_label, "", s$approach, "tr"),
                        chisq_diff = cmp$chisq_diff, df_diff = cmp$df_diff, p = cmp$p, method = unname(method_label[cmp$method]),
                        delta_cfi = cmp$delta_cfi, delta_rmsea = cmp$delta_rmsea, delta_srmr = cmp$delta_srmr,
                        chisq_ok = dec$chisq_ok, cfi_ok = dec$cfi_ok, rmsea_ok = dec$rmsea_ok, srmr_ok = dec$srmr_ok, combined = combined,
                        stringsAsFactors = FALSE)
  crit_tr <- sprintf("Ölçütler (ayarlanabilir): ΔCFI ≥ %s (Cheung ve Rensvold, 2002); ΔRMSEA ≤ %s (Chen, 2007); ΔSRMR ≤ %s yük adımında, ≤ %s diğer adımlarda (Chen, 2007); Δχ² p ≥ %s.",
                     fmt_num(s$cfi, 3, "tr", TRUE), fmt_num(s$rmsea, 3, "tr", TRUE), fmt_num(s$srmr_load, 3, "tr", TRUE), fmt_num(s$srmr_int, 3, "tr", TRUE), fmt_num(s$alpha, 2, "tr", TRUE))
  crit_en <- sprintf("Criteria (adjustable): ΔCFI ≥ %s (Cheung & Rensvold, 2002); ΔRMSEA ≤ %s (Chen, 2007); ΔSRMR ≤ %s for the loadings step, ≤ %s for other steps (Chen, 2007); Δχ² p ≥ %s.",
                     fmt_num(s$cfi, 3, "en", TRUE), fmt_num(s$rmsea, 3, "en", TRUE), fmt_num(s$srmr_load, 3, "en", TRUE), fmt_num(s$srmr_int, 3, "en", TRUE), fmt_num(s$alpha, 2, "en", TRUE))
  rule_tr <- switch(s$rule, none = "", and = " Birleşik kural: ΔCFI VE ΔRMSEA ölçütü birlikte.", or = " Birleşik kural: ΔCFI VEYA ΔRMSEA ölçütü.")
  rule_en <- switch(s$rule, none = "", and = " Combined rule: ΔCFI AND ΔRMSEA criteria.", or = " Combined rule: ΔCFI OR ΔRMSEA criterion.")
  cols <- list(tbl_col("label", "Kısıtlı adım", "Restricted step"), tbl_col("ref", "Karşılaştırılan", "Compared with"),
               tbl_col("chisq_diff", "Δχ²", "Δχ²", "num", 2L), tbl_col("df_diff", "Δsd", "Δdf", "int"), tbl_col("p", "p", "p", "p"),
               tbl_col("method", "Yöntem", "Method"), tbl_col("delta_cfi", "ΔCFI", "ΔCFI", "num", 3L, TRUE),
               tbl_col("delta_rmsea", "ΔRMSEA", "ΔRMSEA", "num", 3L, TRUE), tbl_col("delta_srmr", "ΔSRMR", "ΔSRMR", "num", 4L, TRUE),
               tbl_col("chisq_ok", "Δχ² ölçütü", "Δχ² criterion"), tbl_col("cfi_ok", "ΔCFI ölçütü", "ΔCFI criterion"),
               tbl_col("rmsea_ok", "ΔRMSEA ölçütü", "ΔRMSEA criterion"), tbl_col("srmr_ok", "ΔSRMR ölçütü", "ΔSRMR criterion"))
  if (s$rule != "none") cols <- c(cols, list(tbl_col("combined", "Birleşik kural", "Combined rule")))
  t2 <- make_table("T2", "Değişmezlik adımlarının karşılaştırması", "Comparison of invariance steps", cols, t2_rows,
    note_tr = paste0("Δ = kısıtlı − daha az kısıtlı model. Fark testi: lavaan::lavTestLRT (method = '", method, "'). ",
                     if (robust) "ΔCFI ve ΔRMSEA ölçeklenmiş indekslerle hesaplanır; dayanıklı indeksler kısıtlı çok gruplu modellerde tanımsızdır. " else "",
                     sprintf("ΔSRMR: %s. ", if (srmr_key == "srmr") "lavaan SRMR" else "Bentler (ortalamasız) SRMR"), crit_tr, rule_tr,
                     if (s$approach == "categorical") " Δ eşikleri sürekli ML simülasyonlarından türetilmiştir; WLSMV için doğrulanmamıştır. Birincil ölçüt Satorra (2000) fark testidir." else ""),
    note_en = paste0("Δ = restricted − less restricted model. Difference test: lavaan::lavTestLRT (method = '", method, "'). ",
                     if (robust) "ΔCFI and ΔRMSEA use the scaled indices; robust indices are undefined in constrained multigroup models. " else "",
                     sprintf("ΔSRMR: %s. ", if (srmr_key == "srmr") "lavaan SRMR" else "Bentler SRMR without means"), crit_en, rule_en,
                     if (s$approach == "categorical") " The Δ cut-offs were derived from continuous ML simulations and are not validated for WLSMV. The primary criterion is the Satorra (2000) difference test." else ""))
  yn <- function(v, lang) ifelse(is.na(v), FMT_MISSING, ifelse(v, if (lang == "tr") "Sağlandı" else "Met", if (lang == "tr") "Sağlanmadı" else "Not met"))
  for (lang in c("tr", "en")) {
    for (k in c("chisq_ok", "cfi_ok", "rmsea_ok", "srmr_ok", "combined")) if (k %in% names(t2$rows_fmt[[lang]])) t2$rows_fmt[[lang]][[k]] <- yn(t2_rows[[k]], lang)
  }
  t2$rows_fmt$en$label <- vapply(cmp$step, inv_step_label, "", s$approach, "en")
  t2$rows_fmt$en$ref <- vapply(cmp$reference, inv_step_label, "", s$approach, "en")
  t2$rows_fmt$en$method <- gsub("χ² farkı", "χ² difference", t2$rows_fmt$en$method)
  tables <- list(t1, t2)

  # Gizil ortalamalar
  lm <- NULL
  lm_ok <- inv_latent_mean_ok(m, s$partial, s$approach)
  if ("scalar" %in% steps) {
    if (!all(lm_ok)) {
      warns[[length(warns) + 1L]] <- warning_item("latent_means_locked",
        sprintf("Gizil ortalamalar hesaplanmadı: şu faktörlerde yükü ve kesişimi değişmez kalan en az iki madde yok: %s (SPEC I-4).", paste(names(lm_ok)[!lm_ok], collapse = ", ")),
        sprintf("Latent means not computed: these factors do not keep at least two items with invariant loading and intercept: %s (SPEC I-4).", paste(names(lm_ok)[!lm_ok], collapse = ", ")))
    } else {
      lm <- inv_latent_means(fits$scalar, fms$scalar, m, pr, s)
      tables[[length(tables) + 1L]] <- lm$table
      warns <- c(warns, lm$warnings)
    }
  }
  if (length(s$partial)) warns[[length(warns) + 1L]] <- warning_item("partial_data_driven",
    "Veri güdümlü serbest bırakmalar bağımsız bir örneklemde doğrulanmalıdır (Byrne vd., 1989).",
    "Data-driven releases must be validated in an independent sample (Byrne et al., 1989).")
  for (f in fits) warns <- c(warns, lapply(cfa_lavaan_warnings(f$warnings), function(w) {
    w$message_tr <- paste0(inv_step_label(f$step, s$approach, "tr"), " — ", w$message_tr)
    w$message_en <- paste0(inv_step_label(f$step, s$approach, "en"), " — ", w$message_en); w }))

  make_record(
    module = "invariance", dataset_hash = dataset_hash,
    settings = list(model = model_record(m), approach = s$approach, estimator = s$estimator,
                    likelihood = if (s$estimator == "ML") s$likelihood else NULL, std_lv = s$std_lv, include_strict = s$include_strict,
                    partial = I(s$partial), groups = I(pr$labels), group = pr$grp, srmr_type = s$srmr_type, rule = s$rule, d_sd = s$d_sd,
                    criteria = list(cfi = s$cfi, rmsea = s$rmsea, srmr_load = s$srmr_load, srmr_int = s$srmr_int, alpha = s$alpha),
                    items = I(pr$items), lrt_method = method,
                    steps = lapply(fits, function(f) list(step = f$step, group_equal = I(f$eq), syntax = f$syntax, lavaan_args = f$args))),
    seed = s$seed, rng = run$rng,
    results = list(groups = I(pr$labels), n = I(pr$n), steps = I(steps), fit = fms,
                   comparisons = cmp, decisions = dec, combined = if (s$rule == "none") NULL else I(combined),
                   latent_means_available = !is.null(lm), latent_means = if (is.null(lm)) NULL else lm$rows,
                   latent_model = if (is.null(lm)) NULL else list(syntax = lm$syntax, lavaan_args = lm$args),
                   notes = I(pr$notes)),
    tables = tables, warnings = warns
  )
}

inv_latent_means <- function(scalar_fit, scalar_fm, m, pr, s) {
  fac <- m$first_order
  base <- scalar_fit$syntax
  ls <- inv_latent_syntax(base, fac, pr$labels, pr$n, s)
  args <- scalar_fit$args
  if (s$approach == "continuous") args$std.lv <- TRUE
  ft <- cfa_fit(ls$syntax, pr$x, args)
  chi_a <- if (s$estimator == "ML") scalar_fm$chisq else scalar_fm$chisq_scaled
  fm_b <- cfa_fit_measures(ft$fit)
  chi_b <- if (s$estimator == "ML") fm_b$chisq else fm_b$chisq_scaled
  if (!isTRUE(abs(chi_a - chi_b) <= 1e-6 * max(1, abs(chi_a)))) {
    api_stop("internal_mismatch", "Gizil ortalama modeli skaler modelle eşdeğer değil.", 500L, sprintf("χ² %.10f ↔ %.10f", chi_a, chi_b))
  }
  pe <- lavaan::parameterEstimates(ft$fit)
  rows <- do.call(rbind, lapply(ls$defs, function(d) {
    mu <- pe[pe$op == "~1" & pe$lhs == d$factor & pe$group == d$k, ]
    dd <- pe[pe$op == ":=" & pe$lhs == d$name, ]
    data.frame(factor = d$factor, group = d$group, kappa = mu$est, se = mu$se, z = mu$z, p = mu$pvalue,
               d = dd$est, d_se = dd$se, d_lower = dd$ci.lower, d_upper = dd$ci.upper, stringsAsFactors = FALSE)
  }))
  tab <- make_table("T3", "Gizil ortalama farkları", "Latent mean differences",
    list(tbl_col("factor", "Faktör", "Factor"), tbl_col("group", "Grup", "Group"), tbl_col("kappa", "Fark (κ)", "Difference (κ)", "num", 3L),
         tbl_col("se", "SH", "SE", "num", 3L), tbl_col("z", "z", "z", "num", 2L), tbl_col("p", "p", "p", "p"),
         tbl_col("d", "d", "d", "num", 3L), tbl_col("d_ci", "d %95 GA", "d 95% CI")),
    transform(rows, d_ci = NA_character_),
    note_tr = sprintf("Referans grup (%s) ortalaması 0, varyansı 1'dir; κ diğer grubun gizil ortalama farkıdır. d = κ / %s; SH ve güven aralığı lavaan'ın := tanımından (delta yöntemi) gelir. Model skaler adımla eşdeğerdir.",
                      pr$labels[1], if (s$d_sd == "pooled") "birleşik gizil SS (Hancock, 2001)" else "referans grup SS'si"),
    note_en = sprintf("The reference group (%s) has mean 0 and variance 1; κ is the other group's latent mean difference. d = κ / %s; SE and confidence interval come from lavaan's := definition (delta method). The model is equivalent to the scalar step.",
                      pr$labels[1], if (s$d_sd == "pooled") "pooled latent SD (Hancock, 2001)" else "reference-group SD"))
  for (lang in c("tr", "en")) tab$rows_fmt[[lang]]$d_ci <- fmt_ci(rows$d_lower, rows$d_upper, 3L, lang, FALSE)
  list(rows = rows, table = tab, syntax = ls$syntax, args = args, warnings = cfa_lavaan_warnings(ft$warnings))
}

# Kısmi değişmezlik sihirbazı: bir adımın kısıtları için skor testleri (SPEC M8; I-3).
analysis_invariance_scores <- function(data, config, settings, dataset_hash) {
  pr <- inv_prepare(data, config, settings)
  s <- pr$s
  step <- setting_choice(settings, "step", setdiff(names(pr$steps), "configural"))
  run <- with_seeded_rng(s$seed, {
    f <- inv_fit_step(step, pr$steps[[step]], pr$m, pr$x, pr$items, pr$grp, pr$labels, s)
    sc <- tryCatch(quiet(lavaan::lavTestScore(f$fit, univariate = TRUE, cumulative = FALSE)), error = function(e) e)
    list(f = f, sc = sc)
  })
  sc <- run$value$sc
  if (inherits(sc, "error")) api_stop("score_test_failed", "lavaan::lavTestScore çalışmadı.", 422L, conditionMessage(sc))
  uni <- sc$value$uni
  if (is.null(uni) || !nrow(uni)) api_stop("no_constraints", "Bu adımda test edilecek eşitlik kısıtı yok.", 422L)
  pt <- lavaan::parTable(run$value$f$fit)
  desc <- function(plabel) {
    r <- pt[pt$plabel == plabel, ][1, ]
    par <- if (r$op == "~1") paste0(r$lhs, "~1") else paste0(r$lhs, r$op, r$rhs)
    list(par = par, group = pr$labels[r$group], op = r$op)
  }
  rows <- do.call(rbind, lapply(seq_len(nrow(uni)), function(i) {
    a <- desc(uni$lhs[i]); b <- desc(uni$rhs[i])
    data.frame(parameter = a$par, groups = paste(a$group, b$group, sep = " – "), kind = a$op,
               x2 = uni$X2[i], df = uni$df[i], p = uni$p.value[i],
               x2_scaled = if ("X2.scaled" %in% names(uni)) uni$X2.scaled[i] else NA_real_,
               p_scaled = if ("p.value.scaled" %in% names(uni)) uni$p.value.scaled[i] else NA_real_,
               free = a$par, stringsAsFactors = FALSE)
  }))
  robust <- s$estimator != "ML"
  ord <- order(-(if (robust && any(!is.na(rows$x2_scaled))) rows$x2_scaled else rows$x2))
  rows <- rows[ord, ]
  rownames(rows) <- NULL
  kind_tr <- c("=~" = "yük", "~1" = "kesişim", "~~" = "artık varyans", "|" = "eşik")
  kind_en <- c("=~" = "loading", "~1" = "intercept", "~~" = "residual variance", "|" = "threshold")
  rows$kind_label <- unname(kind_tr[rows$kind])
  cols <- list(tbl_col("parameter", "Parametre", "Parameter"), tbl_col("kind_label", "Tür", "Type"), tbl_col("groups", "Gruplar", "Groups"),
               tbl_col("x2", "χ² (skor)", "χ² (score)", "num", 3L), tbl_col("df", "sd", "df", "int"), tbl_col("p", "p", "p", "p"))
  if (robust) cols <- c(cols, list(tbl_col("x2_scaled", "χ² (ölçeklenmiş)", "χ² (scaled)", "num", 3L), tbl_col("p_scaled", "p (ölçeklenmiş)", "p (scaled)", "p")))
  tab <- make_table("T1", sprintf("Skor testleri: %s adımının kısıtları", inv_step_label(step, s$approach, "tr")),
    sprintf("Score tests: constraints of the %s step", inv_step_label(step, s$approach, "en")), cols, rows,
    note_tr = paste0("Kaynak: lavaan::lavTestScore (univariate = TRUE); parametre adları parTable'dan okundu. Sıralama ", if (robust) "ölçeklenmiş χ²'ye" else "χ²'ye",
                     " göredir. Serbest bırakma kullanıcının onayıyla yapılır; öneriler kuramsal olarak değerlendirilmelidir. Serbest bırakma bütün gruplarda geçerlidir (group.partial). Veri güdümlü serbest bırakmalar bağımsız örneklemde doğrulanmalıdır."),
    note_en = paste0("Source: lavaan::lavTestScore (univariate = TRUE); parameter names read from parTable. Sorted by ", if (robust) "scaled χ²" else "χ²",
                     ". Releasing requires the user's confirmation; suggestions must be judged theoretically. A release applies to all groups (group.partial). Data-driven releases must be validated in an independent sample."))
  tab$rows_fmt$en$kind_label <- unname(kind_en[rows$kind])
  warns <- list()
  if (length(pr$labels) > 2L) warns[[1]] <- warning_item("partial_all_groups",
    "İkiden çok grupta serbest bırakma bu sürümde bütün gruplarda yapılır; tek grup çiftine özgü serbest bırakma desteklenmez.",
    "With more than two groups a release applies to all groups in this version; releasing for a single pair of groups is not supported.")
  make_record(
    module = "invariance_scores", dataset_hash = dataset_hash,
    settings = list(model = model_record(pr$m), approach = s$approach, estimator = s$estimator,
                    likelihood = if (s$estimator == "ML") s$likelihood else NULL, std_lv = s$std_lv, step = step,
                    partial = I(s$partial), groups = I(pr$labels), group = pr$grp, items = I(pr$items),
                    syntax = run$value$f$syntax, lavaan_args = run$value$f$args),
    seed = s$seed, rng = run$rng,
    results = list(step = step, tests = rows, total = sc$value$test),
    tables = list(tab), warnings = warns
  )
}
