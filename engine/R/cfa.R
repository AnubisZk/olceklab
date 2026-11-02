# M6 — Doğrulayıcı faktör analizi ve model karşılaştırma (SPEC §7 M6).
# İlgili inceleme maddeleri: BS-1…BS-3 (Bollen–Stine), W-1…W-6 (WLSMV, karşılaştırma, χ²/sd, wishart).
# Bütün sayılar lavaan'dan gelir; ön yüz hiçbir χ² farkı ya da indeks hesaplamaz.

cfa_estimators <- c("ML", "MLR", "WLSMV")

cfa_settings <- function(settings) {
  s <- list(
    estimator = setting_choice(settings, "estimator", cfa_estimators),
    likelihood = setting_choice(settings, "likelihood", c("normal", "wishart")),
    std_lv = setting_flag(settings, "std_lv", FALSE),
    bootstrap = setting_number(settings, "bootstrap", 0L, 0, 10000, integer = TRUE),
    seed = setting_number(settings, "seed", 20261030L, 1, .Machine$integer.max, integer = TRUE),
    mi_top = setting_number(settings, "mi_top", 10L, 0, 100, integer = TRUE)
  )
  if (s$likelihood == "wishart" && s$estimator != "ML") {
    api_stop("wishart_only_ml", "likelihood = \"wishart\" yalnızca ML kestiricisiyle seçilebilir (SPEC_REVIEW W-5).", 422L)
  }
  if (s$bootstrap > 0L && s$bootstrap < 100L) {
    api_stop("invalid_setting", "Bollen–Stine için bootstrap sayısı en az 100 olmalıdır (kapatmak için 0).", 422L)
  }
  if (s$bootstrap > 0L && s$estimator != "ML") {
    api_stop("bollen_stine_unavailable",
             "Bollen–Stine bootstrap yalnızca ML kestiricisiyle ve sürekli kabul edilen, eksiksiz veride kullanılabilir. MLR kendi ölçeklenmiş testini, WLSMV ise sıralı veri testini kullanır (SPEC_REVIEW BS-1).", 422L)
  }
  s
}

# lavaan::cfa argümanları. Motor ve dışa aktarılan betik aynı listeyi kullanır.
cfa_call_args <- function(s, observed) {
  a <- list(estimator = s$estimator)
  if (s$estimator == "ML") a$likelihood <- s$likelihood
  a$std.lv <- s$std_lv
  if (s$estimator == "WLSMV") a$ordered <- as.character(observed)
  if (s$bootstrap > 0L) {
    a$test <- "bollen.stine"; a$bootstrap <- s$bootstrap; a$iseed <- s$seed; a$parallel <- "no"
  }
  a
}

cfa_check_data <- function(x, config, observed, s) {
  if (s$estimator == "WLSMV") {
    no_cat <- observed[is.na(config$items$min[match(observed, config$items$name)])]
    if (length(no_cat)) {
      api_stop("wlsmv_needs_categories",
               sprintf("WLSMV sıralı (kategorik) maddeler içindir; şu maddelerde kategori aralığı tanımlı değil: %s.", paste(no_cat, collapse = ", ")), 422L)
    }
  }
  if (s$bootstrap > 0L && anyNA(x)) {
    api_stop("bollen_stine_unavailable", "Bollen–Stine bootstrap eksik değer içeren veride kullanılamaz; temizlemede eksik yanıt kuralını açın.", 422L)
  }
  if (nrow(stats::na.omit(x)) <= length(observed)) {
    api_stop("too_few_rows", "DFA için gözlem sayısı gözlenen değişken sayısından büyük olmalıdır.", 422L)
  }
}

cfa_fit <- function(syntax, x, args) {
  res <- tryCatch(
    collect_conditions(do.call(lavaan::cfa, c(list(model = syntax, data = x), args))),
    error = function(e) api_stop("lavaan_error", "lavaan modeli kestiremedi.", 422L, conditionMessage(e))
  )
  fit <- res$value
  if (!isTRUE(lavaan::lavInspect(fit, "converged"))) {
    api_stop("not_converged", "Model yakınsamadı; sonuçlar raporlanamaz.", 422L, paste(res$warnings, collapse = "\n"))
  }
  df <- suppressWarnings(as.numeric(lavaan::fitMeasures(fit, "df")))
  if (isTRUE(df < 0)) {
    api_stop("model_not_identified", sprintf("Model tanımlanamıyor: serbestlik derecesi negatif (sd = %d). Faktör başına gösterge sayısını artırın ya da parametre ekleyin.", as.integer(df)),
             422L, paste(res$warnings, collapse = "\n"))
  }
  pc <- collect_conditions(lavaan::lavInspect(fit, "post.check"))
  list(fit = fit, warnings = unique(c(res$warnings, pc$warnings)), post_check = isTRUE(pc$value))
}

# lavaan uyum ölçütleri; adlar "." yerine "_" ile.
cfa_fit_names <- c("npar", "ntotal", "chisq", "df", "pvalue", "chisq.scaled", "df.scaled", "pvalue.scaled",
                   "chisq.scaling.factor", "cfi", "tli", "rmsea", "rmsea.ci.lower", "rmsea.ci.upper", "rmsea.pvalue",
                   "cfi.scaled", "tli.scaled", "rmsea.scaled", "rmsea.ci.lower.scaled", "rmsea.ci.upper.scaled",
                   "cfi.robust", "tli.robust", "rmsea.robust", "rmsea.ci.lower.robust", "rmsea.ci.upper.robust",
                   "srmr", "aic", "bic")

cfa_fit_measures <- function(fit) {
  fm <- quiet(lavaan::fitMeasures(fit))$value
  out <- lapply(cfa_fit_names, function(n) if (n %in% names(fm)) unname(as.numeric(fm[[n]])) else NA_real_)
  names(out) <- gsub(".", "_", cfa_fit_names, fixed = TRUE)
  out
}

cfa_scaled_labels <- function(estimator) {
  if (estimator == "WLSMV") {
    list(sc_tr = "Ölçeklenmiş (Mplus uyumlu)", sc_en = "Scaled (Mplus-compatible)",
         rb_tr = "Dayanıklı (Savalei, 2021)", rb_en = "Robust (Savalei, 2021)")
  } else {
    list(sc_tr = "Ölçeklenmiş (Yuan–Bentler)", sc_en = "Scaled (Yuan–Bentler)",
         rb_tr = "Dayanıklı (Brosseau-Liard ve Savalei)", rb_en = "Robust (Brosseau-Liard & Savalei)")
  }
}

cfa_fit_note <- function(s) {
  base_tr <- sprintf("Kaynak: lavaan::cfa (estimator = '%s'%s, std.lv = %s), lavaan::fitMeasures; lavaan %s.",
                     s$estimator, if (s$estimator == "ML") sprintf(", likelihood = '%s'", s$likelihood) else "",
                     if (s$std_lv) "TRUE" else "FALSE", as.character(utils::packageVersion("lavaan")))
  base_en <- sub("^Kaynak:", "Source:", base_tr)
  extra_tr <- c(
    if (s$estimator == "ML" && s$likelihood == "wishart") "Olabilirlik Wishart (N − 1; AMOS/LISREL uyumlu)." else NULL,
    if (s$estimator == "ML") "χ²/sd yalnızca bilgi içindir; eşik verilmez (SPEC_REVIEW W-4)." else NULL,
    if (s$estimator != "ML") "Ölçeklenmiş indeksler ölçeklenmiş χ²'den hesaplanır; dayanıklı indeksler ayrı bir düzeltmedir. İkisi aynı şeyi ölçmez; hangisinin raporlandığı açıkça yazılmalıdır (SPEC_REVIEW W-1)." else NULL,
    if (s$estimator == "WLSMV") "AIC ve BIC WLSMV'de tanımlı değildir." else NULL,
    "Hu ve Bentler (1999) eşikleri ML ve sürekli veri için önerilmiştir; WLSMV'de CFI ve RMSEA farklı davranır (Xia ve Yang, 2019). Bu tabloda iyi/kötü sınıflaması yapılmaz.")
  extra_en <- c(
    if (s$estimator == "ML" && s$likelihood == "wishart") "Wishart likelihood (N − 1; AMOS/LISREL-compatible)." else NULL,
    if (s$estimator == "ML") "χ²/df is for information only; no cut-off is applied (SPEC_REVIEW W-4)." else NULL,
    if (s$estimator != "ML") "Scaled indices are computed from the scaled χ²; robust indices are a separate correction. They do not measure the same thing; state clearly which one is reported (SPEC_REVIEW W-1)." else NULL,
    if (s$estimator == "WLSMV") "AIC and BIC are not defined for WLSMV." else NULL,
    "Hu and Bentler (1999) cut-offs were proposed for ML with continuous data; CFI and RMSEA behave differently under WLSMV (Xia & Yang, 2019). No good/poor classification is made in this table.")
  list(tr = paste(c(base_tr, extra_tr), collapse = " "), en = paste(c(base_en, extra_en), collapse = " "))
}

cfa_fit_table <- function(fm, s, bs = NULL) {
  note <- cfa_fit_note(s)
  ci <- function(lo, hi) list(tr = fmt_ci(lo, hi, 3L, "tr", TRUE), en = fmt_ci(lo, hi, 3L, "en", TRUE))
  if (s$estimator == "ML") {
    rows <- data.frame(
      key = c("chisq", "df", "pvalue", "chisq_df", "cfi", "tli", "rmsea", "rmsea_ci", "srmr", "aic", "bic", "ntotal", "npar"),
      label_tr = c("χ²", "sd", "p", "χ²/sd (bilgi)", "CFI", "TLI", "RMSEA", "RMSEA %90 GA", "SRMR", "AIC", "BIC", "n", "Parametre sayısı"),
      label_en = c("χ²", "df", "p", "χ²/df (information)", "CFI", "TLI", "RMSEA", "RMSEA 90% CI", "SRMR", "AIC", "BIC", "n", "Number of parameters"),
      value = c(fm$chisq, fm$df, fm$pvalue, if (isTRUE(fm$df > 0)) fm$chisq / fm$df else NA_real_, fm$cfi, fm$tli, fm$rmsea, NA,
                fm$srmr, fm$aic, fm$bic, fm$ntotal, fm$npar),
      format = c("num", "int", "p", "num", "num", "num", "num", "text", "num", "num", "num", "int", "int"),
      digits = c(3L, 0L, 3L, 2L, 3L, 3L, 3L, 3L, 3L, 2L, 2L, 0L, 0L),
      bounded = c(FALSE, FALSE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE),
      stringsAsFactors = FALSE)
    tv <- list(rmsea_ci = list(value = ci(fm$rmsea_ci_lower, fm$rmsea_ci_upper)))
    if (!is.null(bs)) {
      rows <- rbind(rows[1:3, ], data.frame(key = "bollen_stine_p", label_tr = sprintf("Bollen–Stine p (B = %d)", bs$boot_length),
                                            label_en = sprintf("Bollen–Stine p (B = %d)", bs$boot_length), value = bs$pvalue,
                                            format = "p", digits = 3L, bounded = TRUE, stringsAsFactors = FALSE), rows[-(1:3), ])
      tv$bollen_stine_p <- list(value = bs$pvalue_fmt)
    }
    return(make_kv_table("T1", "Uyum indeksleri", "Fit indices", rows, text_values = tv,
                         note_tr = note$tr, note_en = note$en))
  }
  lb <- cfa_scaled_labels(s$estimator)
  na <- NA_real_
  rows <- data.frame(
    key = c("chisq", "df", "pvalue", "scaling", "cfi", "tli", "rmsea", "rmsea_ci", "srmr", "aic", "bic", "ntotal", "npar"),
    label_tr = c("χ²", "sd", "p", "Ölçekleme katsayısı", "CFI", "TLI", "RMSEA", "RMSEA %90 GA", "SRMR", "AIC", "BIC", "n", "Parametre sayısı"),
    label_en = c("χ²", "df", "p", "Scaling factor", "CFI", "TLI", "RMSEA", "RMSEA 90% CI", "SRMR", "AIC", "BIC", "n", "Number of parameters"),
    scaled = c(fm$chisq_scaled, fm$df_scaled, fm$pvalue_scaled, fm$chisq_scaling_factor, fm$cfi_scaled, fm$tli_scaled,
               fm$rmsea_scaled, na, fm$srmr, fm$aic, fm$bic, fm$ntotal, fm$npar),
    robust = c(na, na, na, na, fm$cfi_robust, fm$tli_robust, fm$rmsea_robust, na, na, na, na, na, na),
    format = c("num", "int", "p", "num", "num", "num", "num", "text", "num", "num", "num", "int", "int"),
    digits = c(3L, 0L, 3L, 3L, 3L, 3L, 3L, 3L, 3L, 2L, 2L, 0L, 0L),
    bounded = c(FALSE, FALSE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE),
    stringsAsFactors = FALSE)
  if (s$estimator == "WLSMV") rows <- rows[!(rows$key %in% c("aic", "bic")), ]
  tv <- list(rmsea_ci = list(scaled = ci(fm$rmsea_ci_lower_scaled, fm$rmsea_ci_upper_scaled),
                             robust = ci(fm$rmsea_ci_lower_robust, fm$rmsea_ci_upper_robust)))
  make_kv_table("T1", "Uyum indeksleri", "Fit indices", rows,
                value_cols = list(tbl_col("scaled", lb$sc_tr, lb$sc_en, "num"), tbl_col("robust", lb$rb_tr, lb$rb_en, "num")),
                text_values = tv,
                note_tr = paste(note$tr, "Ölçekleme katsayısına, kestiriciden bağımsız ölçütlere (SRMR, n) ve bilgi ölçütlerine ilk sütunda yer verilir."),
                note_en = paste(note$en, "The scaling factor, estimator-independent measures (SRMR, n) and information criteria are shown in the first column."))
}

cfa_parameters <- function(fit) {
  pe <- lavaan::parameterEstimates(fit, standardized = TRUE, rsquare = TRUE)
  pe[, intersect(c("lhs", "op", "rhs", "est", "se", "z", "pvalue", "std.lv", "std.all"), names(pe))]
}

cfa_param_tables <- function(fit, m, s) {
  pe <- cfa_parameters(fit)
  r2 <- pe[pe$op == "r2", c("lhs", "est")]
  ld <- pe[pe$op == "=~", ]
  fixed <- !is.na(ld$se) & ld$se == 0 & is.na(ld$z)
  ld$se[fixed] <- NA_real_
  ld_rows <- data.frame(factor = ld$lhs, item = ld$rhs, est = ld$est, se = ld$se, z = ld$z, p = ld$pvalue,
                        std = ld$std.all, r2 = r2$est[match(ld$rhs, r2$lhs)], stringsAsFactors = FALSE)
  t2 <- make_table("T2", "Faktör yükleri", "Factor loadings",
    list(tbl_col("factor", "Faktör", "Factor"), tbl_col("item", "Madde", "Item"),
         tbl_col("est", "B", "B", "num", 3L), tbl_col("se", "SH", "SE", "num", 3L), tbl_col("z", "z", "z", "num", 2L),
         tbl_col("p", "p", "p", "p"), tbl_col("std", "β", "β", "num", 3L, TRUE), tbl_col("r2", "R²", "R²", "num", 3L, TRUE)),
    ld_rows,
    note_tr = paste0("Kaynak: lavaan::parameterEstimates (standardized = TRUE). β: tam standardize çözüm (std.all). ",
                     if (s$std_lv) "Faktör varyansları 1'e sabitlendi (std.lv = TRUE)." else "Her faktörün işaretleyici maddesinin yükü 1'e sabitlendi; bu maddelerin SH, z ve p değerleri yoktur.",
                     if (s$estimator == "WLSMV") " WLSMV'de yükler gizil yanıt (y*) ölçeğindedir." else ""),
    note_en = paste0("Source: lavaan::parameterEstimates (standardized = TRUE). β: completely standardized solution (std.all). ",
                     if (s$std_lv) "Factor variances fixed to 1 (std.lv = TRUE)." else "The loading of each factor's marker item is fixed to 1; these items have no SE, z or p.",
                     if (s$estimator == "WLSMV") " Under WLSMV loadings are on the latent-response (y*) scale." else ""))
  tables <- list(t2)
  lv <- unique(ld$lhs)
  cors <- pe[pe$op == "~~" & pe$lhs %in% lv & pe$rhs %in% lv & pe$lhs != pe$rhs, ]
  phi <- NULL
  if (length(lv) > 1L) {
    phi <- diag(length(lv)); dimnames(phi) <- list(lv, lv)
    for (k in seq_len(nrow(cors))) phi[cors$lhs[k], cors$rhs[k]] <- phi[cors$rhs[k], cors$lhs[k]] <- cors$std.all[k]
    rows <- data.frame(factor = lv, phi, check.names = FALSE, stringsAsFactors = FALSE)
    rownames(rows) <- NULL
    t3 <- make_table("T3", "Faktörler arası korelasyonlar", "Factor correlations",
      c(list(tbl_col("factor", "Faktör", "Factor")), lapply(lv, function(f) tbl_col(f, f, f, "num", 3L, TRUE))),
      rows, note_tr = "Kaynak: lavaan::parameterEstimates (std.all).", note_en = "Source: lavaan::parameterEstimates (std.all).")
    for (lang in c("tr", "en")) for (j in seq_along(lv)) for (i in seq_len(j - 1L)) t3$rows_fmt[[lang]][i, lv[j]] <- ""
    tables[[length(tables) + 1L]] <- t3
  }
  obs <- m$observed
  ec <- pe[pe$op == "~~" & pe$lhs %in% obs & pe$rhs %in% obs & pe$lhs != pe$rhs, ]
  if (nrow(ec)) {
    tables[[length(tables) + 1L]] <- make_table("T4", "Hata kovaryansları", "Error covariances",
      list(tbl_col("a", "Madde", "Item"), tbl_col("b", "Madde", "Item"), tbl_col("est", "Kovaryans", "Covariance", "num", 3L),
           tbl_col("p", "p", "p", "p"), tbl_col("std", "r", "r", "num", 3L, TRUE)),
      data.frame(a = ec$lhs, b = ec$rhs, est = ec$est, p = ec$pvalue, std = ec$std.all, stringsAsFactors = FALSE),
      note_tr = "Kaynak: lavaan::parameterEstimates. r: standardize hata kovaryansı (std.all).",
      note_en = "Source: lavaan::parameterEstimates. r: standardized error covariance (std.all).")
  }
  resid <- pe[pe$op == "~~" & pe$lhs %in% obs & pe$lhs == pe$rhs, ]
  list(tables = tables, loadings = ld_rows, phi = phi, error_cov = ec, residual_var = resid, lv = lv)
}

cfa_mi <- function(fit, top) {
  if (top == 0L) return(NULL)
  mi <- tryCatch(quiet(lavaan::modindices(fit, sort. = TRUE, maximum.number = top))$value, error = function(e) NULL)
  if (is.null(mi) || !nrow(mi)) return(NULL)
  data.frame(lhs = mi$lhs, op = mi$op, rhs = mi$rhs, mi = mi$mi, epc = mi$epc, sepc_all = mi$sepc.all, stringsAsFactors = FALSE)
}

cfa_mi_table <- function(mi, id = "T5") {
  make_table(id, "Modifikasyon indeksleri (en büyük değerler)", "Modification indices (largest values)",
    list(tbl_col("lhs", "Sol", "Left"), tbl_col("op", "İşlem", "Operator"), tbl_col("rhs", "Sağ", "Right"),
         tbl_col("mi", "MI", "MI", "num", 2L), tbl_col("epc", "BPD", "EPC", "num", 3L), tbl_col("sepc_all", "Std. BPD", "Std. EPC", "num", 3L)),
    mi,
    note_tr = "Kaynak: lavaan::modindices (sort. = TRUE). BPD: beklenen parametre değişimi. Kuramsal gerekçe olmadan parametre serbest bırakmak modeli örnekleme özgü hâle getirir, uyumu yapay olarak artırır ve sonucun başka örneklemlerde tekrarlanmasını zorlaştırır. Serbest bırakılan her parametre kuramsal olarak gerekçelendirilmeli ve raporda belirtilmelidir.",
    note_en = "Source: lavaan::modindices (sort. = TRUE). EPC: expected parameter change. Freeing parameters without theoretical justification capitalizes on chance, inflates fit artificially and makes replication less likely. Every freed parameter must be justified theoretically and reported.")
}

# Bollen–Stine (SPEC_REVIEW BS-1…BS-3). p = boot.larger / boot.length (lavaan); tutucu p = (b + 1) / (B_etkin + 1).
cfa_bollen_stine <- function(fit, B, warnings) {
  bs <- lavaan::lavInspect(fit, "test")$bollen.stine
  if (is.null(bs)) api_stop("bollen_stine_missing", "lavaan Bollen–Stine sonucunu döndürmedi.", 500L)
  parse_count <- function(pattern) {
    hit <- regmatches(warnings, regexpr(paste0("^[0-9]+(?= ", pattern, ")"), warnings, perl = TRUE))
    if (length(hit)) as.integer(hit[1]) else 0L
  }
  b_eff <- as.integer(bs$boot.length)
  larger <- as.integer(bs$boot.larger)
  # b = 0 ise "p < 1/B_etkin": sınır yukarı yuvarlanır ki yazılan değer gerçek sınırdan küçük olmasın.
  bound <- 1 / b_eff
  digits <- max(2L, as.integer(ceiling(-log10(bound) - 1e-9)))
  bound_up <- ceiling(bound * 10^digits - 1e-9) / 10^digits
  p_fmt <- function(lang) {
    if (larger == 0L) paste0("< ", fmt_num(bound_up, digits, lang, TRUE)) else fmt_p(bs$pvalue, lang, 3L)
  }
  out <- list(requested = as.integer(B), boot_length = b_eff, failed = as.integer(B) - b_eff,
              nonadmissible = parse_count("bootstrap runs resulted in nonadmissible solutions"),
              boot_larger = larger, stat = bs$stat, pvalue = bs$pvalue,
              pvalue_conservative = (larger + 1) / (b_eff + 1),
              pvalue_fmt = list(tr = p_fmt("tr"), en = p_fmt("en")))
  rows <- data.frame(
    key = c("requested", "boot_length", "failed", "nonadmissible", "boot_larger", "pvalue", "pvalue_conservative"),
    label_tr = c("İstenen B", "Geçerli tekrar (B_etkin)", "Başarısız ya da yakınsamayan tekrar", "Uygunsuz çözümlü tekrar",
                 "Gözlenen χ²'den büyük bootstrap χ² sayısı (b)", "p (lavaan: b / B_etkin)", "Tutucu p: (b + 1) / (B_etkin + 1)"),
    label_en = c("Requested B", "Valid replications (B_eff)", "Failed or non-converged replications", "Replications with nonadmissible solutions",
                 "Bootstrap χ² larger than observed (b)", "p (lavaan: b / B_eff)", "Conservative p: (b + 1) / (B_eff + 1)"),
    value = c(out$requested, out$boot_length, out$failed, out$nonadmissible, out$boot_larger, out$pvalue, out$pvalue_conservative),
    format = c("int", "int", "int", "int", "int", "p", "p"), digits = c(0L, 0L, 0L, 0L, 0L, 3L, 3L),
    bounded = c(FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, TRUE), stringsAsFactors = FALSE)
  out$table <- make_kv_table("T6", "Bollen–Stine bootstrap", "Bollen–Stine bootstrap", rows,
    text_values = list(pvalue = list(value = out$pvalue_fmt)),
    note_tr = sprintf("Kaynak: lavaan::cfa (test = 'bollen.stine', bootstrap = %d, iseed = tohum, parallel = 'no'), lavInspect(fit, 'test'). Başarısız tekrarlar paydadan düşülür; uygunsuz çözümler içeride kalır. b = 0 ise p, 1/B_etkin'den küçük olarak yazılır. Tutucu p: Davison ve Hinkley (1997).", B),
    note_en = sprintf("Source: lavaan::cfa (test = 'bollen.stine', bootstrap = %d, iseed = seed, parallel = 'no'), lavInspect(fit, 'test'). Failed replications are dropped from the denominator; nonadmissible solutions are kept. If b = 0, p is reported as less than 1/B_eff. Conservative p: Davison & Hinkley (1997).", B))
  out
}

cfa_heywood <- function(pt) {
  neg <- pt$residual_var$lhs[pt$residual_var$est < 0]
  big <- unique(pt$loadings$item[abs(pt$loadings$std) > 1])
  unique(c(neg, big))
}

cfa_path_figure <- function(pt) {
  lab <- function(v, lang) fmt_num(v, 2L, lang, TRUE)
  list(id = "F1", type = "path", data = list(
    factors = lapply(pt$lv, function(f) list(name = f, items = I(pt$loadings$item[pt$loadings$factor == f]))),
    loadings = lapply(seq_len(nrow(pt$loadings)), function(i) list(
      factor = pt$loadings$factor[i], item = pt$loadings$item[i], std = pt$loadings$std[i],
      label_tr = lab(pt$loadings$std[i], "tr"), label_en = lab(pt$loadings$std[i], "en"),
      r2 = pt$loadings$r2[i], r2_label_tr = lab(pt$loadings$r2[i], "tr"), r2_label_en = lab(pt$loadings$r2[i], "en"))),
    correlations = if (is.null(pt$phi)) list() else {
      out <- list(); lv <- pt$lv
      for (j in seq_along(lv)) for (i in seq_len(j - 1L)) {
        v <- pt$phi[lv[i], lv[j]]
        out[[length(out) + 1L]] <- list(a = lv[i], b = lv[j], std = v, label_tr = lab(v, "tr"), label_en = lab(v, "en"))
      }
      out
    },
    covariances = lapply(seq_len(nrow(pt$error_cov)), function(i) list(
      a = pt$error_cov$lhs[i], b = pt$error_cov$rhs[i], std = pt$error_cov$std.all[i],
      label_tr = lab(pt$error_cov$std.all[i], "tr"), label_en = lab(pt$error_cov$std.all[i], "en")))
  ))
}

cfa_lavaan_warnings <- function(msgs) {
  lapply(unique(msgs), function(w) {
    w <- gsub("\\s+", " ", trimws(w))
    warning_item("lavaan_warning", paste("lavaan:", w), paste("lavaan:", w))
  })
}

cfa_prepare <- function(data, config, spec, settings) {
  s <- cfa_settings(settings)
  m <- resolve_model(spec, config$items$name)
  x <- data[, m$observed, drop = FALSE]
  cfa_check_data(x, config, m$observed, s)
  list(s = s, m = m, x = x, args = cfa_call_args(s, m$observed))
}

analysis_cfa <- function(data, config, settings, dataset_hash) {
  pr <- cfa_prepare(data, config, settings$model, settings)
  s <- pr$s; m <- pr$m
  run <- with_seeded_rng(s$seed, cfa_fit(m$syntax, pr$x, pr$args))
  ft <- run$value
  fit <- ft$fit
  fm <- cfa_fit_measures(fit)
  bs <- if (s$bootstrap > 0L) cfa_bollen_stine(fit, s$bootstrap, ft$warnings) else NULL
  pt <- cfa_param_tables(fit, m, s)
  mi <- cfa_mi(fit, s$mi_top)
  tables <- c(list(cfa_fit_table(fm, s, bs)), pt$tables)
  if (!is.null(mi)) tables[[length(tables) + 1L]] <- cfa_mi_table(mi)
  if (!is.null(bs)) tables[[length(tables) + 1L]] <- bs$table

  warns <- m$warnings
  hey <- cfa_heywood(pt)
  if (length(hey)) {
    warns[[length(warns) + 1L]] <- warning_item("heywood",
      sprintf("Uygunsuz çözüm belirtisi (negatif hata varyansı ya da 1'i aşan standardize yük): %s.", paste(hey, collapse = ", ")),
      sprintf("Sign of an improper solution (negative residual variance or standardized loading above 1): %s.", paste(hey, collapse = ", ")))
  }
  if (!ft$post_check) {
    warns[[length(warns) + 1L]] <- warning_item("post_check_failed",
      "lavaan'ın uygunsuz çözüm denetimi (post.check) başarısız oldu; ayrıntılar lavaan uyarılarındadır.",
      "lavaan's admissibility check (post.check) failed; see the lavaan warnings for details.")
  }
  warns <- c(warns, cfa_lavaan_warnings(ft$warnings))

  make_record(
    module = "cfa", dataset_hash = dataset_hash,
    settings = list(model = model_record(m), estimator = s$estimator, likelihood = if (s$estimator == "ML") s$likelihood else NULL,
                    std_lv = s$std_lv, bootstrap = s$bootstrap, mi_top = s$mi_top, items = I(m$observed),
                    lavaan_args = pr$args),
    seed = s$seed, rng = run$rng,
    results = list(
      n = lavaan::lavInspect(fit, "nobs"), converged = TRUE, post_check = ft$post_check,
      fit = fm, loadings = pt$loadings,
      factor_correlations = if (is.null(pt$phi)) NULL else lapply(stats::setNames(pt$lv, pt$lv), function(f) as.list(pt$phi[f, ])),
      error_covariances = if (nrow(pt$error_cov)) pt$error_cov[, c("lhs", "rhs", "est", "pvalue", "std.all")] else NULL,
      modification_indices = mi,
      bollen_stine = if (is.null(bs)) NULL else bs[setdiff(names(bs), "table")]
    ),
    tables = tables, figures = list(cfa_path_figure(pt)), warnings = warns
  )
}

# --- Model karşılaştırma (SPEC_REVIEW W-2, W-3) --------------------------------

cfa_lrt_method <- function(estimator) switch(estimator, ML = "standard", MLR = "satorra.bentler.2001", WLSMV = "satorra.2000")

cfa_lrt <- function(fit_less, fit_more, method) {
  a <- tryCatch(quiet(if (method == "standard") lavaan::lavTestLRT(fit_less, fit_more) else lavaan::lavTestLRT(fit_less, fit_more, method = method)),
                error = function(e) e)
  if (inherits(a, "error")) {
    return(list(chisq_diff = NA_real_, df_diff = NA_real_, p = NA_real_, method = method, warnings = character(), error = conditionMessage(a)))
  }
  t <- a$value
  list(chisq_diff = t[2, "Chisq diff"], df_diff = t[2, "Df diff"], p = t[2, "Pr(>Chisq)"], method = method, warnings = a$warnings)
}

analysis_cfa_compare <- function(data, config, settings, dataset_hash) {
  specs <- settings$models
  if (!is.list(specs) || length(specs) < 2L) api_stop("compare_too_few_models", "Karşılaştırma için en az iki model gerekir.", 422L)
  if (length(specs) > 8L) api_stop("compare_too_many_models", "En fazla sekiz model karşılaştırılabilir.", 422L)
  nm <- vapply(seq_along(specs), function(i) { n <- specs[[i]]$name; if (is.null(n) || !nzchar(n)) sprintf("Model %d", i) else as.character(n)[1] }, "")
  if (anyDuplicated(nm)) api_stop("compare_duplicate_names", "Model adları birbirinden farklı olmalıdır.", 422L)
  if (isTRUE(as.integer(settings$bootstrap %||% 0L) > 0L)) {
    api_stop("invalid_setting", "Karşılaştırma tablosunda Bollen–Stine çalıştırılmaz; tek model analizini kullanın.", 422L)
  }
  settings$bootstrap <- 0L
  prs <- lapply(specs, function(sp) cfa_prepare(data, config, sp$model, settings))
  s <- prs[[1]]$s
  obs_sets <- lapply(prs, function(p) sort(p$m$observed))
  if (!all(vapply(obs_sets, identical, logical(1), obs_sets[[1]]))) {
    api_stop("compare_different_variables",
             "Karşılaştırılan modeller aynı gözlenen değişkenleri kullanmalıdır; aksi hâlde χ², AIC ve BIC aynı veriye dayanmaz (SPEC_REVIEW W-2).", 422L)
  }
  run <- with_seeded_rng(s$seed, lapply(prs, function(p) cfa_fit(p$m$syntax, p$x, p$args)))
  fits <- lapply(run$value, `[[`, "fit")
  names(fits) <- nm
  fms <- lapply(fits, cfa_fit_measures)
  ns <- vapply(fits, function(f) as.numeric(lavaan::lavInspect(f, "nobs")), numeric(1))
  if (length(unique(ns)) > 1L) api_stop("compare_different_n", "Karşılaştırılan modellerin N'si farklı; aynı tabloya alınamaz.", 422L)

  # İç içelik: Bentler ve Satorra (2010); kategorik veride Asparouhov ve Muthén (2019) — semTools::net.
  net_env <- new.env()
  for (k in seq_along(fits)) assign(paste0("fit", k), fits[[k]], envir = net_env)
  net_call <- as.call(c(quote(semTools::net), lapply(paste0("fit", seq_along(fits)), as.name)))
  nest <- tryCatch(quiet(eval(net_call, net_env))$value@test, error = function(e) e)
  warns <- list()
  tests <- list()
  if (inherits(nest, "error")) {
    warns[[length(warns) + 1L]] <- warning_item("net_failed", paste("İç içelik denetimi (semTools::net) çalışmadı; fark testi yapılmadı:", conditionMessage(nest)),
                                                paste("Nesting check (semTools::net) failed; no difference test was run:", conditionMessage(nest)))
  } else {
    # net() matrisi df'ye göre sıralıdır; satır modeli sütun modelinin içinde iç içedir.
    lab <- sub(" \\(df = .*\\)$", "", rownames(nest))
    ord <- match(lab, paste0("fit", seq_along(fits)))
    if (anyNA(ord)) ord <- match(lab, nm)
    if (anyNA(ord)) ord <- seq_along(fits)[order(vapply(fms, `[[`, numeric(1), "df"))]
    method <- cfa_lrt_method(s$estimator)
    for (r in seq_len(nrow(nest))) for (c in seq_len(ncol(nest))) {
      i <- ord[r]; j <- ord[c]
      if (i == j || !isTRUE(nest[r, c])) next
      if (fms[[i]]$df <= fms[[j]]$df) next  # eşdeğer ya da aynı sd: test yok
      lr <- cfa_lrt(fits[[j]], fits[[i]], method)
      if (!is.null(lr$error)) {
        warns[[length(warns) + 1L]] <- warning_item("lrt_failed",
          sprintf("%s – %s: fark testi hesaplanamadı (lavaan): %s", nm[i], nm[j], lr$error),
          sprintf("%s – %s: the difference test could not be computed (lavaan): %s", nm[i], nm[j], lr$error))
        next
      }
      fallback <- FALSE
      if (method == "satorra.bentler.2001" && isTRUE(lr$chisq_diff < 0)) {
        lr <- cfa_lrt(fits[[j]], fits[[i]], "satorra.bentler.2010")
        fallback <- TRUE
        warns[[length(warns) + 1L]] <- warning_item("sb2001_negative",
          sprintf("%s – %s: Satorra–Bentler (2001) farkı negatif çıktı; Satorra–Bentler (2010) ile yeniden hesaplandı.", nm[i], nm[j]),
          sprintf("%s – %s: the Satorra–Bentler (2001) difference was negative; recomputed with Satorra–Bentler (2010).", nm[i], nm[j]))
      }
      for (w in cfa_lavaan_warnings(lr$warnings)) {
        w$message_tr <- sprintf("%s – %s fark testi — %s", nm[i], nm[j], w$message_tr)
        w$message_en <- sprintf("%s – %s difference test — %s", nm[i], nm[j], w$message_en)
        warns[[length(warns) + 1L]] <- w
      }
      sc <- s$estimator != "ML"
      tests[[length(tests) + 1L]] <- list(
        restricted = nm[i], reference = nm[j], chisq_diff = lr$chisq_diff, df_diff = lr$df_diff, p = lr$p,
        method = lr$method, fallback = fallback,
        delta_cfi = (if (sc) fms[[i]]$cfi_scaled else fms[[i]]$cfi) - (if (sc) fms[[j]]$cfi_scaled else fms[[j]]$cfi),
        delta_rmsea = (if (sc) fms[[i]]$rmsea_scaled else fms[[i]]$rmsea) - (if (sc) fms[[j]]$rmsea_scaled else fms[[j]]$rmsea))
    }
    for (r in seq_len(nrow(nest))) for (c in seq_len(ncol(nest))) {
      i <- ord[r]; j <- ord[c]
      if (i < j && isTRUE(nest[r, c]) && isTRUE(nest[c, r])) {
        warns[[length(warns) + 1L]] <- warning_item("equivalent_models", sprintf("%s ve %s eşdeğer modellerdir; aralarında fark testi yapılamaz.", nm[i], nm[j]),
                                                    sprintf("%s and %s are equivalent models; no difference test is possible.", nm[i], nm[j]))
      }
    }
  }

  robust <- s$estimator != "ML"
  pick <- function(f, k) f[[if (robust && k %in% c("chisq", "df", "pvalue", "cfi", "tli", "rmsea", "rmsea_ci_lower", "rmsea_ci_upper")) paste0(k, "_scaled") else k]]
  c1_rows <- data.frame(model = nm, npar = vapply(fms, `[[`, 0, "npar"),
                        chisq = vapply(fms, pick, 0, "chisq"), df = vapply(fms, pick, 0, "df"), p = vapply(fms, pick, 0, "pvalue"),
                        cfi = vapply(fms, pick, 0, "cfi"), tli = vapply(fms, pick, 0, "tli"), rmsea = vapply(fms, pick, 0, "rmsea"),
                        rmsea_ci = NA_character_, srmr = vapply(fms, `[[`, 0, "srmr"), stringsAsFactors = FALSE)
  if (robust) {
    c1_rows$cfi_robust <- vapply(fms, `[[`, 0, "cfi_robust"); c1_rows$tli_robust <- vapply(fms, `[[`, 0, "tli_robust")
    c1_rows$rmsea_robust <- vapply(fms, `[[`, 0, "rmsea_robust")
  }
  if (s$estimator != "WLSMV") { c1_rows$aic <- vapply(fms, `[[`, 0, "aic"); c1_rows$bic <- vapply(fms, `[[`, 0, "bic") }
  suf_tr <- if (robust) " (ölç.)" else ""; suf_en <- if (robust) " (sc.)" else ""
  cols <- list(tbl_col("model", "Model", "Model"), tbl_col("npar", "Parametre", "Parameters", "int"),
               tbl_col("chisq", paste0("χ²", suf_tr), paste0("χ²", suf_en), "num", 3L), tbl_col("df", "sd", "df", "int"), tbl_col("p", "p", "p", "p"),
               tbl_col("cfi", paste0("CFI", suf_tr), paste0("CFI", suf_en), "num", 3L, TRUE), tbl_col("tli", paste0("TLI", suf_tr), paste0("TLI", suf_en), "num", 3L),
               tbl_col("rmsea", paste0("RMSEA", suf_tr), paste0("RMSEA", suf_en), "num", 3L, TRUE),
               tbl_col("rmsea_ci", "RMSEA %90 GA", "RMSEA 90% CI"), tbl_col("srmr", "SRMR", "SRMR", "num", 3L, TRUE))
  if (robust) cols <- c(cols, list(tbl_col("cfi_robust", "CFI (dayanıklı)", "CFI (robust)", "num", 3L, TRUE),
                                   tbl_col("tli_robust", "TLI (dayanıklı)", "TLI (robust)", "num", 3L),
                                   tbl_col("rmsea_robust", "RMSEA (dayanıklı)", "RMSEA (robust)", "num", 3L, TRUE)))
  if (s$estimator != "WLSMV") cols <- c(cols, list(tbl_col("aic", "AIC", "AIC", "num", 2L), tbl_col("bic", "BIC", "BIC", "num", 2L)))
  note <- cfa_fit_note(s)
  c1 <- make_table("T1", "Model karşılaştırma: uyum indeksleri", "Model comparison: fit indices", cols, c1_rows,
    note_tr = paste(note$tr, if (robust) "(ölç.): ölçeklenmiş." else "", if (s$estimator != "WLSMV") "AIC/BIC yalnızca aynı N, kestirici ve olabilirlik ayarıyla kestirilmiş modeller arasında karşılaştırılabilir; iç içe olmayan modeller için yalnızca betimseldir." else "WLSMV'de iç içe olmayan modeller için test sunulmaz; indeksler betimsel olarak yan yana konur."),
    note_en = paste(note$en, if (robust) "(sc.): scaled." else "", if (s$estimator != "WLSMV") "AIC/BIC are comparable only across models with the same N, estimator and likelihood; for non-nested models they are descriptive." else "Under WLSMV no test is offered for non-nested models; indices are shown side by side descriptively."))
  for (lang in c("tr", "en")) c1$rows_fmt[[lang]]$rmsea_ci <- vapply(fms, function(f) fmt_ci(pick(f, "rmsea_ci_lower"), pick(f, "rmsea_ci_upper"), 3L, lang, TRUE), "")
  tables <- list(c1)

  method_label <- c(standard = "χ² farkı (ML)", satorra.2000 = "Satorra (2000)", satorra.bentler.2001 = "Satorra–Bentler (2001)",
                    satorra.bentler.2010 = "Satorra–Bentler (2010)")
  method_label_en <- c(standard = "χ² difference (ML)", satorra.2000 = "Satorra (2000)", satorra.bentler.2001 = "Satorra–Bentler (2001)",
                       satorra.bentler.2010 = "Satorra–Bentler (2010)")
  if (length(tests)) {
    t_rows <- data.frame(restricted = vapply(tests, `[[`, "", "restricted"), reference = vapply(tests, `[[`, "", "reference"),
                         chisq_diff = vapply(tests, `[[`, 0, "chisq_diff"), df_diff = vapply(tests, `[[`, 0, "df_diff"),
                         p = vapply(tests, `[[`, 0, "p"), method = vapply(tests, function(t) method_label[[t$method]], ""),
                         delta_cfi = vapply(tests, `[[`, 0, "delta_cfi"), delta_rmsea = vapply(tests, `[[`, 0, "delta_rmsea"),
                         stringsAsFactors = FALSE)
    c2 <- make_table("T2", "İç içe model fark testleri", "Nested-model difference tests",
      list(tbl_col("restricted", "Kısıtlı model", "Restricted model"), tbl_col("reference", "Daha az kısıtlı model", "Less restricted model"),
           tbl_col("chisq_diff", "Δχ²", "Δχ²", "num", 2L), tbl_col("df_diff", "Δsd", "Δdf", "int"), tbl_col("p", "p", "p", "p"),
           tbl_col("method", "Yöntem", "Method"), tbl_col("delta_cfi", "ΔCFI", "ΔCFI", "num", 3L, TRUE),
           tbl_col("delta_rmsea", "ΔRMSEA", "ΔRMSEA", "num", 3L, TRUE)),
      t_rows,
      note_tr = paste0("Kaynak: lavaan::lavTestLRT (method = '", cfa_lrt_method(s$estimator), "'); iç içelik semTools::net ile denetlendi (Bentler ve Satorra, 2010",
                       if (s$estimator == "WLSMV") "; Asparouhov ve Muthén, 2019" else "", "). Ölçeklenmiş χ² değerleri elle çıkarılmaz. Δ = kısıtlı − daha az kısıtlı",
                       if (robust) "; ΔCFI ve ΔRMSEA ölçeklenmiş indekslerle." else "."),
      note_en = paste0("Source: lavaan::lavTestLRT (method = '", cfa_lrt_method(s$estimator), "'); nesting checked with semTools::net (Bentler & Satorra, 2010",
                       if (s$estimator == "WLSMV") "; Asparouhov & Muthén, 2019" else "", "). Scaled χ² values are never subtracted by hand. Δ = restricted − less restricted",
                       if (robust) "; ΔCFI and ΔRMSEA use the scaled indices." else "."))
    c2$rows_fmt$en$method <- vapply(tests, function(t) method_label_en[[t$method]], "")
    tables[[2]] <- c2
  } else if (!inherits(nest, "error")) {
    warns[[length(warns) + 1L]] <- warning_item("no_nested_pairs", "Modeller arasında iç içe çift bulunamadı; fark testi yapılmadı. Uyum indeksleri betimsel olarak karşılaştırılabilir.",
                                                "No nested pairs were found among the models; no difference test was run. Fit indices can be compared descriptively.")
  }
  for (k in seq_along(prs)) {
    for (w in prs[[k]]$m$warnings) { w$message_tr <- paste0(nm[k], ": ", w$message_tr); w$message_en <- paste0(nm[k], ": ", w$message_en); warns[[length(warns) + 1L]] <- w }
    for (w in cfa_lavaan_warnings(run$value[[k]]$warnings)) { w$message_tr <- paste0(nm[k], " — ", w$message_tr); w$message_en <- paste0(nm[k], " — ", w$message_en); warns[[length(warns) + 1L]] <- w }
  }

  make_record(
    module = "cfa_compare", dataset_hash = dataset_hash,
    settings = list(models = lapply(seq_along(prs), function(k) list(name = nm[k], model = model_record(prs[[k]]$m))),
                    estimator = s$estimator, likelihood = if (s$estimator == "ML") s$likelihood else NULL, std_lv = s$std_lv,
                    items = I(prs[[1]]$m$observed), lavaan_args = prs[[1]]$args, lrt_method = cfa_lrt_method(s$estimator)),
    seed = s$seed, rng = run$rng,
    results = list(n = ns[[1]], models = I(nm), fit = fms,
                   nesting = if (inherits(nest, "error")) NULL else list(models = I(nm[ord]), matrix = unname(nest)),
                   tests = tests),
    tables = tables, warnings = warns
  )
}
