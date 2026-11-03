# M10 — Raporlama (SPEC §7 M10; SPEC_REVIEW REP-3).
# Word raporu officer + flextable ile kurulur. Tablolar analiz kayıtlarındaki R-biçimli değerlerden (rows_fmt) gelir;
# Yöntem/Bulgular metinleri önceden yazılmış şablon cümlelerdir ve sayıları yine R'nin biçimlediği değerlerdir.
# Bu modül YAPAY ZEKÂ KULLANMAZ ve hiçbir sayıyı yeniden hesaplamaz. Bir değer kayıtta yoksa ilgili cümle yazılmaz.
# Metinlerde *…* arası italik yazılır (APA 7: istatistik simgeleri).

report_module_titles <- list(
  data_clean = c(tr = "Veri temizleme", en = "Data cleaning"),
  item_analysis = c(tr = "Madde analizi", en = "Item analysis"),
  suitability = c(tr = "Faktör analizine uygunluk", en = "Suitability for factor analysis"),
  factor_number = c(tr = "Faktör sayısı", en = "Number of factors"),
  efa = c(tr = "Açımlayıcı faktör analizi", en = "Exploratory factor analysis"),
  cfa = c(tr = "Doğrulayıcı faktör analizi", en = "Confirmatory factor analysis"),
  cfa_compare = c(tr = "Model karşılaştırma", en = "Model comparison"),
  reliability = c(tr = "Güvenirlik ve geçerlik", en = "Reliability and validity"),
  invariance = c(tr = "Ölçme değişmezliği", en = "Measurement invariance"),
  invariance_scores = c(tr = "Kısmi değişmezlik: skor testleri", en = "Partial invariance: score tests"),
  simulation = c(tr = "Monte Carlo simülasyonu", en = "Monte Carlo simulation"))

report_module_packages <- function(module) {
  switch(module,
    data_clean = c("readxl"), item_analysis = c("psych"), suitability = c("psych"), factor_number = c("psych"),
    efa = c("psych", "GPArotation"), cfa = , cfa_compare = c("lavaan", "semTools"), reliability = c("lavaan", "semTools", "psych"),
    invariance = , invariance_scores = c("lavaan", "semTools"), simulation = c("lavaan", "semTools", "psych", "MASS", "pbivnorm"),
    character())
}

# --- Kayıttan biçimli hücre okuma (yoksa NULL: cümle yazılmaz) -----------------------
rpt_table <- function(rec, id) { for (t in rec$tables) if (identical(t$id, id)) return(t); NULL }
rpt_fmt <- function(rec, id, lang) { t <- rpt_table(rec, id); if (is.null(t)) NULL else as.data.frame(t$rows_fmt[[lang]], stringsAsFactors = FALSE) }
rpt_kv <- function(rec, id, key, lang, col = NULL) {
  d <- rpt_fmt(rec, id, lang)
  if (is.null(d) || !("key" %in% names(d))) return(NULL)
  col <- if (is.null(col)) setdiff(names(d), c("key", "label"))[1] else col
  v <- d[[col]][d$key == key]
  if (!length(v) || is.na(v[1]) || identical(v[1], FMT_MISSING) || !nzchar(v[1])) NULL else v[1]
}
rpt_ok <- function(...) all(vapply(list(...), function(x) !is.null(x) && length(x) == 1L && !is.na(x) && nzchar(x) && !identical(x, FMT_MISSING), logical(1)))
# p metni: "< ,001" ise "*p* < ,001", değilse "*p* = ,224".
rpt_p <- function(p) if (startsWith(p, "<") || startsWith(p, ">")) paste("*p*", p) else paste("*p* =", p)
rpt_list <- function(x, lang) {
  x <- as.character(x)
  if (length(x) <= 1L) return(paste(x, collapse = ""))
  paste(paste(x[-length(x)], collapse = ", "), if (lang == "tr") "ve" else "and", x[length(x)])
}
rpt_tr <- function(lang, tr, en) if (lang == "tr") tr else en

# --- Modül şablonları: list(methods = c(...), results = c(...), limitations = c(...)) --------------
report_text <- function(rec, lang = "tr", table_no = list()) {
  lang <- match.arg(lang, c("tr", "en"))
  ref <- function(id) { k <- table_no[[id]]; if (is.null(k)) "" else rpt_tr(lang, sprintf(" (Tablo %d)", k), sprintf(" (Table %d)", k)) }
  s <- rec$settings; r <- rec$results
  cor_lab <- function(x) switch(as.character(x), pearson = "Pearson", polychoric = rpt_tr(lang, "polikorik", "polychoric"), as.character(x))
  out <- list(methods = character(), results = character(), limitations = character())
  add <- function(part, txt) out[[part]] <<- c(out[[part]], txt)
  switch(rec$module,
    data_clean = {
      lab <- list(invalid_group = c("geçersiz grup değeri", "invalid group value"), missing = c("eksik yanıt", "missing responses"),
                  out_of_range = c("aralık dışı değer", "out-of-range values"), straightline = c("düz yanıt", "straight-lining"),
                  reverse = c("ters maddelerin yeniden kodlanması", "recoding of reverse-keyed items"))
      on <- Filter(function(k) isTRUE(s$rules[[k]]), clean_rule_keys)
      if (length(on)) add("methods", rpt_tr(lang,
        sprintf("Veri temizlemede şu kurallar bu sırayla uygulandı: %s. Bir satır yalnızca ilk eşleştiği kuralda sayıldı.", rpt_list(vapply(on, function(k) lab[[k]][1], ""), lang)),
        sprintf("The following cleaning rules were applied in this order: %s. A row was counted only under the first rule it matched.", rpt_list(vapply(on, function(k) lab[[k]][2], ""), lang))))
      if (!is.null(r$n_raw) && !is.null(r$n_final)) add("results", rpt_tr(lang,
        sprintf("Ham veride %s katılımcı vardı; temizlemeden sonra analizlere %s katılımcı alındı%s.", fmt_int(r$n_raw, lang), fmt_int(r$n_final, lang), ref("T1")),
        sprintf("The raw data contained %s participants; %s were retained for analysis after cleaning%s.", fmt_int(r$n_raw, lang), fmt_int(r$n_final, lang), ref("T1"))))
    },
    item_analysis = {
      add("methods", rpt_tr(lang,
        sprintf("Madde istatistikleri psych::describe, iç tutarlılık Cronbach *α* katsayısıyla (psych::alpha) hesaplandı; düzeltilmiş madde–toplam korelasyonu için eşik %s alındı.", fmt_num(s$r_drop_threshold, 2L, lang, TRUE)),
        sprintf("Item statistics were computed with psych::describe and internal consistency with Cronbach's *α* (psych::alpha); the threshold for the corrected item–total correlation was %s.", fmt_num(s$r_drop_threshold, 2L, lang, TRUE))))
      d <- rpt_fmt(rec, "T2", lang)
      if (!is.null(d) && nrow(d) && rpt_ok(d$alpha[1], d$std_alpha[1])) add("results", rpt_tr(lang,
        sprintf("Bütün maddeler için Cronbach *α* = %s (standartlaştırılmış *α* = %s) bulundu%s.", d$alpha[1], d$std_alpha[1], ref("T2")),
        sprintf("Cronbach's *α* for all items was %s (standardized *α* = %s)%s.", d$alpha[1], d$std_alpha[1], ref("T2"))))
    },
    suitability = {
      add("methods", rpt_tr(lang, "Verinin faktör analizine uygunluğu Kaiser–Meyer–Olkin (KMO) ölçütü ve Bartlett küresellik testiyle (psych::KMO, psych::cortest.bartlett), çok değişkenli normallik Mardia testiyle incelendi.",
                                  "Suitability for factor analysis was examined with the Kaiser–Meyer–Olkin (KMO) measure and Bartlett's test of sphericity (psych::KMO, psych::cortest.bartlett), and multivariate normality with Mardia's test."))
      d <- rpt_fmt(rec, "T1", lang)
      if (!is.null(d) && nrow(d) && rpt_ok(d$kmo[1], d$chisq[1], d$df[1], d$p[1])) add("results", rpt_tr(lang,
        sprintf("KMO = %s; Bartlett *χ*²(%s) = %s, %s%s.", d$kmo[1], d$df[1], d$chisq[1], rpt_p(d$p[1]), ref("T1")),
        sprintf("KMO = %s; Bartlett's *χ*²(%s) = %s, %s%s.", d$kmo[1], d$df[1], d$chisq[1], rpt_p(d$p[1]), ref("T1"))))
    },
    factor_number = {
      refl <- c(simulated_normal = rpt_tr(lang, "simüle normal veri", "simulated normal data"),
                resampled_bootstrap = rpt_tr(lang, "yerine koyarak yeniden örnekleme", "resampling with replacement"),
                permutation = rpt_tr(lang, "sütun içi permütasyon", "within-column permutation"))
      rl <- if (!is.null(s$reference) && s$reference %in% names(refl)) refl[[s$reference]] else as.character(s$reference)
      crit <- if (identical(s$criterion, "mean")) rpt_tr(lang, "ortalama", "mean") else rpt_tr(lang, sprintf("%s yüzdelik", fmt_pct(s$quant, lang, 0L)), sprintf("%s percentile", fmt_pct(s$quant, lang, 0L)))
      add("methods", rpt_tr(lang,
        sprintf("Faktör sayısı paralel analizle (Horn, 1965; psych::fa.parallel ile aynı algoritma) %s yinelemeyle, %s referansıyla ve %s ölçütüyle; ayrıca Velicer (1976) MAP ölçütüyle incelendi. Korelasyon: %s.", fmt_int(s$n_iter, lang), rl, crit, cor_lab(s$correlation)),
        sprintf("The number of factors was examined with parallel analysis (Horn, 1965; the psych::fa.parallel algorithm) using %s iterations, a %s reference and the %s criterion, and with Velicer's (1976) MAP. Correlation: %s.", fmt_int(s$n_iter, lang), rl, crit, cor_lab(s$correlation))))
      dec <- if (lang == "tr") r$decision_tr else r$decision_en
      if (rpt_ok(dec)) add("results", sub("[.]?$", paste0(ref("T2"), "."), dec))
    },
    efa = {
      add("methods", rpt_tr(lang,
        sprintf("Açımlayıcı faktör analizi psych::fa ile %s faktörlü olarak yapıldı (kestirim: %s; döndürme: %s; korelasyon: %s; döndürme için %s rastgele başlangıç). Belirgin yük eşiği %s alındı.",
                fmt_int(s$nfactors, lang), s$fm, s$rotate, cor_lab(s$correlation), fmt_int(s$n_rotations, lang), fmt_num(s$threshold, 2L, lang, TRUE)),
        sprintf("Exploratory factor analysis was conducted with psych::fa extracting %s factors (estimation: %s; rotation: %s; correlation: %s; %s random starts for the rotation). The salient-loading threshold was %s.",
                fmt_int(s$nfactors, lang), s$fm, s$rotate, cor_lab(s$correlation), fmt_int(s$n_rotations, lang), fmt_num(s$threshold, 2L, lang, TRUE))))
      d <- rpt_fmt(rec, "T2", lang)
      if (!is.null(d) && nrow(d) >= 3L) {
        cum <- d[3, ncol(d)]
        if (rpt_ok(cum)) add("results", rpt_tr(lang, sprintf("Faktörlerin birlikte açıkladığı varyans oranı %s oldu%s.", cum, ref("T2")),
                                                     sprintf("The factors jointly explained a proportion of %s of the variance%s.", cum, ref("T2"))))
      }
      rm <- rpt_kv(rec, "T5", "rmsea", lang); tli <- rpt_kv(rec, "T5", "tli", lang)
      if (rpt_ok(rm, tli)) add("results", sprintf("TLI = %s; RMSEA = %s%s.", tli, rm, ref("T5")))
    },
    cfa = {
      est <- s$estimator
      lik <- if (identical(s$likelihood, "wishart")) rpt_tr(lang, "Wishart olabilirliğiyle (N − 1)", "with the Wishart likelihood (N − 1)") else ""
      sc <- if (isTRUE(s$std_lv)) rpt_tr(lang, "gizil değişken varyansları 1'e sabitlenerek", "fixing latent variances to 1") else rpt_tr(lang, "her faktörün ilk yükü 1'e sabitlenerek", "fixing the first loading of each factor to 1")
      add("methods", rpt_tr(lang,
        sprintf("Doğrulayıcı faktör analizi lavaan::cfa ile %s kestiricisiyle%s, %s yapıldı.", est, if (nzchar(lik)) paste0(" ", lik) else "", sc),
        sprintf("Confirmatory factor analysis was conducted with lavaan::cfa using the %s estimator%s, %s.", est, if (nzchar(lik)) paste0(" ", lik) else "", sc)))
      if (isTRUE(s$bootstrap > 0)) add("methods", rpt_tr(lang,
        sprintf("Ayrıca Bollen–Stine bootstrap testi (Bollen ve Stine, 1992) B = %s ile uygulandı.", fmt_int(s$bootstrap, lang)),
        sprintf("A Bollen–Stine bootstrap test (Bollen & Stine, 1992) with B = %s was also applied.", fmt_int(s$bootstrap, lang))))
      col <- if (est == "ML") "value" else "scaled"
      chi <- rpt_kv(rec, "T1", "chisq", lang, col); df <- rpt_kv(rec, "T1", "df", lang, col); p <- rpt_kv(rec, "T1", "pvalue", lang, col)
      cfi <- rpt_kv(rec, "T1", "cfi", lang, col); tli <- rpt_kv(rec, "T1", "tli", lang, col); rm <- rpt_kv(rec, "T1", "rmsea", lang, col)
      ci <- rpt_kv(rec, "T1", "rmsea_ci", lang, col); sr <- rpt_kv(rec, "T1", "srmr", lang, col)
      if (rpt_ok(chi, df, p, cfi, tli, rm, ci, sr)) add("results", rpt_tr(lang,
        sprintf("Modelin uyum değerleri%s: *χ*²(%s) = %s, %s; CFI = %s; TLI = %s; RMSEA = %s, %%90 GA %s; SRMR = %s%s.", if (est == "ML") "" else " (ölçeklenmiş)", df, chi, rpt_p(p), cfi, tli, rm, ci, sr, ref("T1")),
        sprintf("Model fit%s: *χ*²(%s) = %s, %s; CFI = %s; TLI = %s; RMSEA = %s, 90%% CI %s; SRMR = %s%s.", if (est == "ML") "" else " (scaled)", df, chi, rpt_p(p), cfi, tli, rm, ci, sr, ref("T1"))))
      bs <- rpt_kv(rec, "T1", "bollen_stine_p", lang, col)
      if (rpt_ok(bs)) add("results", rpt_tr(lang, sprintf("Bollen–Stine %s.", rpt_p(bs)), sprintf("Bollen–Stine %s.", rpt_p(bs))))
      ld <- r$loadings
      if (is.data.frame(ld) && nrow(ld) && any(!is.na(ld$std))) {
        lo <- fmt_num(min(ld$std, na.rm = TRUE), 3L, lang, TRUE); hi <- fmt_num(max(ld$std, na.rm = TRUE), 3L, lang, TRUE)
        add("results", rpt_tr(lang, sprintf("Standardize faktör yükleri %s ile %s arasında değişti%s.", lo, hi, ref("T2")),
                                    sprintf("Standardized factor loadings ranged from %s to %s%s.", lo, hi, ref("T2"))))
      }
    },
    cfa_compare = {
      add("methods", rpt_tr(lang, sprintf("Rakip modeller aynı veride %s kestiricisiyle kestirildi; iç içe modeller lavaan::lavTestLRT ile karşılaştırıldı (iç içelik semTools::net ile denetlendi).", s$estimator),
                                  sprintf("Competing models were estimated on the same data with the %s estimator; nested models were compared with lavaan::lavTestLRT (nesting checked with semTools::net).", s$estimator)))
      d <- rpt_fmt(rec, "T2", lang)
      if (!is.null(d)) for (i in seq_len(nrow(d))) if (rpt_ok(d$chisq_diff[i], d$df_diff[i], d$p[i])) add("results", rpt_tr(lang,
        sprintf("%s ile %s karşılaştırıldığında Δ*χ*²(%s) = %s, %s; ΔCFI = %s%s.", d$restricted[i], d$reference[i], d$df_diff[i], d$chisq_diff[i], rpt_p(d$p[i]), d$delta_cfi[i], ref("T2")),
        sprintf("Comparing %s with %s: Δ*χ*²(%s) = %s, %s; ΔCFI = %s%s.", d$restricted[i], d$reference[i], d$df_diff[i], d$chisq_diff[i], rpt_p(d$p[i]), d$delta_cfi[i], ref("T2"))))
    },
    reliability = {
      add("methods", rpt_tr(lang,
        sprintf("Güvenirlik Cronbach *α* (psych::alpha; Cronbach, 1951) ve *ω* (semTools::compRelSEM, obs.var = %s; McDonald, 1999) ile; yakınsak geçerlik ortalama açıklanan varyansla (AVE; Fornell ve Larcker, 1981); ayırt edici geçerlik Fornell–Larcker ölçütü ve HTMT oranlarıyla (Henseler vd., 2015; semTools::htmt, htmt2 = %s, absolute = %s) incelendi.",
                if (isTRUE(s$obs_var)) "TRUE" else "FALSE", if (isTRUE(s$htmt$htmt2)) "TRUE" else "FALSE", if (isTRUE(s$htmt$absolute)) "TRUE" else "FALSE"),
        sprintf("Reliability was assessed with Cronbach's *α* (psych::alpha; Cronbach, 1951) and *ω* (semTools::compRelSEM, obs.var = %s; McDonald, 1999); convergent validity with the average variance extracted (AVE; Fornell & Larcker, 1981); discriminant validity with the Fornell–Larcker criterion and HTMT ratios (Henseler et al., 2015; semTools::htmt, htmt2 = %s, absolute = %s).",
                if (isTRUE(s$obs_var)) "TRUE" else "FALSE", if (isTRUE(s$htmt$htmt2)) "TRUE" else "FALSE", if (isTRUE(s$htmt$absolute)) "TRUE" else "FALSE")))
      d <- rpt_fmt(rec, "T1", lang)
      if (!is.null(d)) {
        parts <- vapply(seq_len(nrow(d)), function(i) if (rpt_ok(d$alpha[i], d$omega[i], d$ave[i])) sprintf("%s *α* = %s, *ω* = %s, AVE = %s", d$factor[i], d$alpha[i], d$omega[i], d$ave[i]) else "", "")
        parts <- parts[nzchar(parts)]
        if (length(parts)) add("results", paste0(rpt_tr(lang, "Faktörlere göre: ", "By factor: "), paste(parts, collapse = "; "), ref("T1"), "."))
      }
      h <- r$htmt
      if (is.list(h) && !is.data.frame(h) && length(h)) h <- do.call(rbind, lapply(h, function(x) unlist(x)[names(h)]))
      if (is.matrix(h) || is.data.frame(h)) {
        h <- as.matrix(h); v <- h[lower.tri(h)]
        if (length(v) && any(!is.na(v))) {
          k <- which(h == max(v, na.rm = TRUE) & lower.tri(h), arr.ind = TRUE)[1, ]
          add("results", rpt_tr(lang, sprintf("En büyük HTMT oranı %s (%s – %s) oldu%s.", fmt_num(max(v, na.rm = TRUE), 3L, lang, FALSE), rownames(h)[k[1]], colnames(h)[k[2]], ref("T2")),
                                      sprintf("The largest HTMT ratio was %s (%s – %s)%s.", fmt_num(max(v, na.rm = TRUE), 3L, lang, FALSE), rownames(h)[k[1]], colnames(h)[k[2]], ref("T2"))))
        }
      }
    },
    invariance = {
      cr <- s$criteria
      appr <- if (identical(s$approach, "categorical")) rpt_tr(lang, "kategorik (semTools::measEq.syntax, theta parametrelemesi; Wu ve Estabrook, 2016)", "categorical (semTools::measEq.syntax, theta parameterization; Wu & Estabrook, 2016)") else rpt_tr(lang, "sürekli", "continuous")
      steps <- if (identical(s$approach, "categorical")) rpt_tr(lang, "biçimsel, eşikler, yükler, kesişimler", "configural, thresholds, loadings, intercepts") else rpt_tr(lang, "biçimsel, metrik, skaler", "configural, metric, scalar")
      if (isTRUE(s$include_strict)) steps <- paste0(steps, rpt_tr(lang, ", katı", ", strict"))
      add("methods", rpt_tr(lang,
        sprintf("Ölçme değişmezliği %s grupları arasında %s yaklaşımla ve %s kestiricisiyle ardışık modellerle (%s) sınandı. Kararlar ΔCFI ≥ %s, ΔRMSEA ≤ %s, ΔSRMR ≤ %s (yükler) / %s (diğer adımlar) ve Δ*χ*² *p* ≥ %s ölçütleriyle her biri ayrı raporlanarak verildi (Cheung ve Rensvold, 2002; Chen, 2007).",
                rpt_list(s$groups, lang), appr, s$estimator, steps, fmt_num(cr$cfi, 2L, lang, TRUE), fmt_num(cr$rmsea, 3L, lang, TRUE), fmt_num(cr$srmr_load, 3L, lang, TRUE), fmt_num(cr$srmr_int, 3L, lang, TRUE), fmt_num(cr$alpha, 2L, lang, TRUE)),
        sprintf("Measurement invariance across %s was tested with a %s approach and the %s estimator using a sequence of models (%s). Decisions used ΔCFI ≥ %s, ΔRMSEA ≤ %s, ΔSRMR ≤ %s (loadings) / %s (other steps) and Δ*χ*² *p* ≥ %s, each reported separately (Cheung & Rensvold, 2002; Chen, 2007).",
                rpt_list(s$groups, lang), appr, s$estimator, steps, fmt_num(cr$cfi, 2L, lang, TRUE), fmt_num(cr$rmsea, 3L, lang, TRUE), fmt_num(cr$srmr_load, 3L, lang, TRUE), fmt_num(cr$srmr_int, 3L, lang, TRUE), fmt_num(cr$alpha, 2L, lang, TRUE))))
      if (length(s$partial)) add("methods", rpt_tr(lang, sprintf("Kısmi değişmezlik için serbest bırakılan kısıtlar: %s.", paste(unlist(s$partial), collapse = ", ")),
                                                         sprintf("Constraints released for partial invariance: %s.", paste(unlist(s$partial), collapse = ", "))))
      d <- rpt_fmt(rec, "T2", lang)
      if (!is.null(d)) for (i in seq_len(nrow(d))) if (rpt_ok(d$chisq_diff[i], d$df_diff[i], d$p[i], d$delta_cfi[i], d$delta_rmsea[i])) add("results", rpt_tr(lang,
        sprintf("%s (%s ile): Δ*χ*²(%s) = %s, %s; ΔCFI = %s; ΔRMSEA = %s%s%s.", d$label[i], d$ref[i], d$df_diff[i], d$chisq_diff[i], rpt_p(d$p[i]), d$delta_cfi[i], d$delta_rmsea[i],
                if (rpt_ok(d$delta_srmr[i])) paste0("; ΔSRMR = ", d$delta_srmr[i]) else "", ref("T2")),
        sprintf("%s (vs. %s): Δ*χ*²(%s) = %s, %s; ΔCFI = %s; ΔRMSEA = %s%s%s.", d$label[i], d$ref[i], d$df_diff[i], d$chisq_diff[i], rpt_p(d$p[i]), d$delta_cfi[i], d$delta_rmsea[i],
                if (rpt_ok(d$delta_srmr[i])) paste0("; ΔSRMR = ", d$delta_srmr[i]) else "", ref("T2"))))
      lm <- rpt_fmt(rec, "T3", lang)
      if (!is.null(lm) && nrow(lm)) {
        parts <- vapply(seq_len(nrow(lm)), function(i) if (rpt_ok(lm$kappa[i], lm$p[i], lm$d[i])) sprintf("%s, %s: *κ* = %s, %s, *d* = %s", lm$factor[i], lm$group[i], lm$kappa[i], rpt_p(lm$p[i]), lm$d[i]) else "", "")
        parts <- parts[nzchar(parts)]
        if (length(parts)) add("results", paste0(rpt_tr(lang, "Gizil ortalama farkları (referans grup: ", "Latent mean differences (reference group: "), s$groups[[1]], "): ", paste(parts, collapse = "; "), ref("T3"), "."))
      }
    },
    invariance_scores = {
      add("methods", rpt_tr(lang, "Kısmi değişmezlik için kısıtların tek serbestlik dereceli skor testleri (lavaan::lavTestScore) incelendi; serbest bırakma kararları araştırmacı tarafından tek tek verildi.",
                                  "For partial invariance, univariate score tests of the constraints (lavaan::lavTestScore) were examined; release decisions were made one at a time by the researcher."))
      d <- rpt_fmt(rec, "T1", lang)
      if (!is.null(d) && nrow(d) && rpt_ok(d$x2[1], d$df[1], d$p[1])) add("results", rpt_tr(lang,
        sprintf("En büyük skor testi istatistiği %s kısıtına aitti: *χ*²(%s) = %s, %s%s.", d$parameter[1], d$df[1], d$x2[1], rpt_p(d$p[1]), ref("T1")),
        sprintf("The largest score-test statistic belonged to the %s constraint: *χ*²(%s) = %s, %s%s.", d$parameter[1], d$df[1], d$x2[1], rpt_p(d$p[1]), ref("T1"))))
    },
    simulation = {
      b <- s$body; cd <- b$conditions
      Ns <- vapply(unlist(cd$N), function(n) fmt_int(as.numeric(n), lang), "")
      add("methods", rpt_tr(lang,
        sprintf("Monte Carlo simülasyonu %s tekrarla; N = %s koşullarında; %s kestiricisiyle yapıldı. Veri gizil yanıt yaklaşımıyla üretildi (MASS::mvrnorm); tekrar tohumu = %s + 10000 × koşul + tekrar (Mersenne-Twister, Inversion, Rejection). Örneklem önerisinde Muthén ve Muthén (2002) ölçütleri kullanıldı.",
                fmt_int(s$reps, lang), rpt_list(Ns, lang), rpt_list(unlist(s$estimators), lang), format(s$seed, scientific = FALSE)),
        sprintf("A Monte Carlo simulation with %s replications was run for N = %s with the %s estimator(s). Data were generated with a latent response approach (MASS::mvrnorm); replication seed = %s + 10000 × condition + replication (Mersenne-Twister, Inversion, Rejection). The sample-size recommendation used the criteria of Muthén and Muthén (2002).",
                fmt_int(s$reps, lang), rpt_list(Ns, lang), rpt_list(unlist(s$estimators), lang), format(s$seed, scientific = FALSE))))
      d <- rpt_fmt(rec, "T7", lang)
      if (!is.null(d) && nrow(d)) {
        parts <- sprintf("%s · %s · %s: %s", d$scenario, d$estimator, d$ratio, d$N)
        add("results", paste0(rpt_tr(lang, "Önerilen örneklem büyüklükleri: ", "Recommended sample sizes: "), paste(parts, collapse = "; "), ref("T7"), "."))
      }
      add("limitations", if (lang == "tr") SIM_LABEL_TR else SIM_LABEL_EN)
      add("limitations", rpt_tr(lang,
        "Simülasyon sonuçları yalnızca tanımlanan popülasyon modeli ve koşullar için geçerlidir. Önerilen N ızgara çözünürlüğüyle sınırlıdır. Popülasyon bir örneklem kestiriminden kurulduysa sonuçlar iyimser olabilir (Hoenig ve Heisey, 2001). Sıralı veride ML ile elde edilen gerçek değerler sözde-gerçek değerlerdir (kesin popülasyon momentleri).",
        "Simulation results hold only for the specified population model and conditions. The recommended N is limited by the grid resolution. If the population was built from sample estimates, results may be optimistic (Hoenig & Heisey, 2001). For ordinal data analysed with ML, true values are pseudo-true values (exact population moments)."))
    })
  out
}

# Kaynakça: yöntem kaynakları (metinde anılanlar) + R ve paketlerin kendi citation() kayıtları.
report_method_refs <- list(
  Horn = "Horn, J. L. (1965). A rationale and test for the number of factors in factor analysis. Psychometrika, 30(2), 179–185.",
  Velicer = "Velicer, W. F. (1976). Determining the number of components from the matrix of partial correlations. Psychometrika, 41(3), 321–327.",
  Cronbach = "Cronbach, L. J. (1951). Coefficient alpha and the internal structure of tests. Psychometrika, 16(3), 297–334.",
  McDonald = "McDonald, R. P. (1999). Test theory: A unified treatment. Lawrence Erlbaum.",
  Fornell = "Fornell, C., & Larcker, D. F. (1981). Evaluating structural equation models with unobservable variables and measurement error. Journal of Marketing Research, 18(1), 39–50.",
  Henseler = "Henseler, J., Ringle, C. M., & Sarstedt, M. (2015). A new criterion for assessing discriminant validity in variance-based structural equation modeling. Journal of the Academy of Marketing Science, 43(1), 115–135.",
  Bollen = "Bollen, K. A., & Stine, R. A. (1992). Bootstrapping goodness-of-fit measures in structural equation models. Sociological Methods & Research, 21(2), 205–229.",
  Cheung = "Cheung, G. W., & Rensvold, R. B. (2002). Evaluating goodness-of-fit indexes for testing measurement invariance. Structural Equation Modeling, 9(2), 233–255.",
  Chen = "Chen, F. F. (2007). Sensitivity of goodness of fit indexes to lack of measurement invariance. Structural Equation Modeling, 14(3), 464–504.",
  Wu = "Wu, H., & Estabrook, R. (2016). Identification of confirmatory factor analysis models of different levels of invariance for ordered categorical outcomes. Psychometrika, 81(4), 1014–1045.",
  Muthen = "Muthén, L. K., & Muthén, B. O. (2002). How to use a Monte Carlo study to decide on sample size and determine power. Structural Equation Modeling, 9(4), 599–620.",
  Hoenig = "Hoenig, J. M., & Heisey, D. M. (2001). The abuse of power: The pervasive fallacy of power calculations for data analysis. The American Statistician, 55(1), 19–24.")

report_refs_for <- function(texts) {
  all <- paste(unlist(texts), collapse = " ")
  keys <- c(Horn = "Horn", Velicer = "Velicer", Cronbach = "Cronbach, 1951", McDonald = "McDonald", Fornell = "Fornell", Henseler = "Henseler",
            Bollen = "Bollen", Cheung = "Cheung", Chen = "Chen, 2007", Wu = "Wu", Muthen = "Muthén", Hoenig = "Hoenig")
  hit <- names(keys)[vapply(keys, function(k) grepl(k, all, fixed = TRUE), logical(1))]
  as.character(unname(unlist(report_method_refs[hit])))  # hiç yoksa character(0) (JSON'da [])
}

report_pkg_refs <- function(pkgs) {
  one <- function(p) tryCatch({
    ct <- if (p == "R") utils::citation() else utils::citation(p)
    txt <- format(ct[1], style = "text")
    gsub("\\s+", " ", gsub("[<>]|_|\\*", "", paste(txt, collapse = " ")))
  }, error = function(e) NULL)
  Filter(Negate(is.null), lapply(c("R", pkgs), one))
}

# --- Önizleme (arayüz için): metinler italik parçalarıyla ----------------------------
rpt_segments <- function(txt) {
  parts <- strsplit(txt, "*", fixed = TRUE)[[1]]
  if (!length(parts)) return(list())
  Filter(function(x) nzchar(x$text), lapply(seq_along(parts), function(i) list(text = parts[i], italic = i %% 2L == 0L)))
}

report_items <- function(analysis_ids) {
  ids <- unlist(analysis_ids)
  if (!length(ids)) api_stop("report_empty", "Rapora en az bir analiz ekleyin.", 422L)
  lapply(ids, function(id) analysis_get(as.character(id))$record)
}

report_layout <- function(recs, lang) {
  k <- 0L; items <- list()
  for (rec in recs) {
    nos <- list()
    for (t in rec$tables) { k <- k + 1L; nos[[t$id]] <- k }
    items[[length(items) + 1L]] <- list(record = rec, table_no = nos, text = report_text(rec, lang, nos))
  }
  items
}

report_preview <- function(analysis_ids, lang = "tr") {
  lang <- match.arg(lang, c("tr", "en"))
  lay <- report_layout(report_items(analysis_ids), lang)
  list(lang = lang, items = lapply(lay, function(it) {
    rec <- it$record
    list(analysis_id = rec$analysis_id, module = rec$module, title = report_module_titles[[rec$module]][[lang]],
         methods = lapply(it$text$methods, rpt_segments), results = lapply(it$text$results, rpt_segments),
         limitations = lapply(it$text$limitations, rpt_segments),
         tables = lapply(rec$tables, function(t) list(id = t$id, number = it$table_no[[t$id]], title = if (lang == "tr") t$title_tr else t$title_en)))
  }), references = I(report_refs_for(lapply(lay, `[[`, "text"))),
  note = rpt_tr(lang, "Bütün sayılar R motorunda hesaplanmış ve biçimlenmiştir. Metinler şablondan üretilmiştir; yapay zekâ kullanılmamıştır.",
                      "All numbers were computed and formatted by the R engine. The text was generated from templates; no AI was used."))
}

# --- Word belgesi ---------------------------------------------------------------------
rpt_fpar <- function(txt, size = 12, style = NULL) {
  base <- officer::fp_text(font.family = "Times New Roman", font.size = size)
  segs <- rpt_segments(txt)
  runs <- lapply(segs, function(s) officer::ftext(s$text, if (s$italic) stats::update(base, italic = TRUE) else base))
  do.call(officer::fpar, c(runs, list(fp_p = officer::fp_par(line_spacing = 1.5, padding.bottom = 6))))
}

rpt_flextable <- function(t, lang) {
  d <- as.data.frame(t$rows_fmt[[lang]], stringsAsFactors = FALSE, check.names = FALSE)
  keys <- vapply(t$columns, `[[`, "", "key")
  d <- d[, keys, drop = FALSE]
  labs <- stats::setNames(vapply(t$columns, function(c) if (lang == "tr") c$label_tr else c$label_en, ""), keys)
  ft <- flextable::flextable(d)
  ft <- flextable::set_header_labels(ft, values = as.list(labs))
  ft <- flextable::theme_apa(ft)
  num <- keys[vapply(t$columns, function(c) identical(c$type, "number"), logical(1))]
  ft <- flextable::align(ft, j = keys, align = "left", part = "all")
  if (length(num)) ft <- flextable::align(ft, j = num, align = "right", part = "all")
  size <- if (length(keys) > 9L) 8 else if (length(keys) > 6L) 9 else 10
  ft <- flextable::font(ft, fontname = "Times New Roman", part = "all")
  ft <- flextable::fontsize(ft, size = size, part = "all")
  ft <- flextable::line_spacing(ft, space = 1, part = "all")
  ft <- flextable::padding(ft, padding = 2, part = "all")
  flextable::fit_to_width(flextable::autofit(ft), max_width = 6.5)
}

report_docx <- function(analysis_ids, lang = "tr", title = NULL) {
  lang <- match.arg(lang, c("tr", "en"))
  recs <- report_items(analysis_ids)
  lay <- report_layout(recs, lang)
  v <- engine_versions()
  title <- if (is.null(title) || !nzchar(trimws(title))) rpt_tr(lang, "ÖlçekLab analiz raporu", "ÖlçekLab analysis report") else trimws(as.character(title))
  doc <- officer::read_docx()
  doc <- officer::body_add_fpar(doc, officer::fpar(officer::ftext(title, officer::fp_text(font.family = "Times New Roman", font.size = 14, bold = TRUE)),
                                                   fp_p = officer::fp_par(text.align = "center", padding.bottom = 6)))
  stamp <- format(Sys.time(), "%Y-%m-%d", tz = "UTC")
  doc <- officer::body_add_fpar(doc, rpt_fpar(rpt_tr(lang,
    sprintf("Oluşturulma: %s. ÖlçekLab R motoru (R %s). Bütün sayılar R'de hesaplanmış ve biçimlenmiştir; Yöntem ve Bulgular metinleri şablondan üretilmiştir, yapay zekâ kullanılmamıştır.", stamp, v$R),
    sprintf("Created: %s. ÖlçekLab R engine (R %s). All numbers were computed and formatted in R; the Methods and Results text was generated from templates, no AI was used.", stamp, v$R)), size = 10))
  for (it in lay) {
    rec <- it$record
    doc <- officer::body_add_par(doc, report_module_titles[[rec$module]][[lang]], style = "heading 1")
    if (length(it$text$methods)) {
      doc <- officer::body_add_par(doc, rpt_tr(lang, "Yöntem", "Method"), style = "heading 2")
      for (p in it$text$methods) doc <- officer::body_add_fpar(doc, rpt_fpar(p))
    }
    if (length(it$text$results)) {
      doc <- officer::body_add_par(doc, rpt_tr(lang, "Bulgular", "Results"), style = "heading 2")
      for (p in it$text$results) doc <- officer::body_add_fpar(doc, rpt_fpar(p))
    }
    if (length(it$text$limitations)) {
      doc <- officer::body_add_par(doc, rpt_tr(lang, "Sınırlılıklar", "Limitations"), style = "heading 2")
      for (p in it$text$limitations) doc <- officer::body_add_fpar(doc, rpt_fpar(p))
    }
    pk <- report_module_packages(rec$module)
    ver <- paste(c(sprintf("R %s", rec$engine$R), vapply(pk, function(p) { x <- rec$engine$packages[[p]]; if (is.null(x)) "" else sprintf("%s %s", p, x) }, "")), collapse = ", ")
    ver <- gsub(", ,", ",", gsub(", $", "", ver))
    for (t in rec$tables) {
      no <- it$table_no[[t$id]]
      doc <- officer::body_add_fpar(doc, officer::fpar(officer::ftext(rpt_tr(lang, sprintf("Tablo %d", no), sprintf("Table %d", no)),
                                                                      officer::fp_text(font.family = "Times New Roman", font.size = 12, bold = TRUE)),
                                                       fp_p = officer::fp_par(padding.top = 12)))
      doc <- officer::body_add_fpar(doc, officer::fpar(officer::ftext(if (lang == "tr") t$title_tr else t$title_en,
                                                                      officer::fp_text(font.family = "Times New Roman", font.size = 12, italic = TRUE)),
                                                       fp_p = officer::fp_par(padding.bottom = 4)))
      doc <- flextable::body_add_flextable(doc, rpt_flextable(t, lang), align = "left")
      note <- if (lang == "tr") t$note_tr else t$note_en
      src <- rpt_tr(lang, sprintf("Sürümler: %s. Analiz kimliği: %s.", ver, rec$analysis_id), sprintf("Versions: %s. Analysis ID: %s.", ver, rec$analysis_id))
      nt <- officer::fp_text(font.family = "Times New Roman", font.size = 10)
      doc <- officer::body_add_fpar(doc, officer::fpar(officer::ftext(rpt_tr(lang, "Not.", "Note."), stats::update(nt, italic = TRUE)),
                                                       officer::ftext(paste0(" ", paste(c(note, src), collapse = " ")), nt),
                                                       fp_p = officer::fp_par(padding.top = 2, padding.bottom = 8)))
    }
  }
  # Yazılım, tohumlar ve veri özeti
  doc <- officer::body_add_par(doc, rpt_tr(lang, "Yazılım ve tekrarlanabilirlik", "Software and reproducibility"), style = "heading 1")
  pk_all <- sort(unique(unlist(lapply(recs, function(r) report_module_packages(r$module)))))
  pk_all <- pk_all[pk_all %in% names(v$packages)]
  doc <- officer::body_add_fpar(doc, rpt_fpar(rpt_tr(lang,
    sprintf("Analizler R %s ile yapıldı. Paketler: %s. RNG: %s / %s / %s.", v$R, paste(sprintf("%s %s", pk_all, unlist(v$packages[pk_all])), collapse = ", "), v$rng_kind$kind, v$rng_kind$normal_kind, v$rng_kind$sample_kind),
    sprintf("Analyses were run with R %s. Packages: %s. RNG: %s / %s / %s.", v$R, paste(sprintf("%s %s", pk_all, unlist(v$packages[pk_all])), collapse = ", "), v$rng_kind$kind, v$rng_kind$normal_kind, v$rng_kind$sample_kind)), size = 11))
  for (rec in recs) {
    line <- sprintf("%s — %s%s%s", report_module_titles[[rec$module]][[lang]], rec$analysis_id,
                    if (!is.null(rec$seed)) rpt_tr(lang, sprintf("; tohum %s", format(rec$seed, scientific = FALSE)), sprintf("; seed %s", format(rec$seed, scientific = FALSE))) else "",
                    if (!identical(rec$dataset_hash, "synthetic")) rpt_tr(lang, sprintf("; veri özeti %s", rec$dataset_hash), sprintf("; data digest %s", rec$dataset_hash)) else rpt_tr(lang, "; sentetik veri", "; synthetic data"))
    doc <- officer::body_add_fpar(doc, rpt_fpar(line, size = 10))
  }
  refs <- c(report_refs_for(lapply(lay, `[[`, "text")), unlist(report_pkg_refs(pk_all)))
  if (length(refs)) {
    doc <- officer::body_add_par(doc, rpt_tr(lang, "Kaynakça", "References"), style = "heading 1")
    for (r in sort(refs)) doc <- officer::body_add_fpar(doc, officer::fpar(officer::ftext(r, officer::fp_text(font.family = "Times New Roman", font.size = 11)),
                                                                           fp_p = officer::fp_par(padding.bottom = 4)))
  }
  f <- tempfile(fileext = ".docx")
  on.exit(unlink(f), add = TRUE)
  print(doc, target = f)
  readBin(f, "raw", file.size(f))
}

# --- CSV dışa aktarma: biçimli (ekrandaki metin) ya da ham (17 basamak) ------------------
report_table_csv <- function(rec, table_id, lang = "tr", values = c("formatted", "raw")) {
  values <- match.arg(values); lang <- match.arg(lang, c("tr", "en"))
  t <- rpt_table(rec, table_id)
  if (is.null(t)) api_stop("table_not_found", "Tablo bulunamadı.", 404L)
  keys <- vapply(t$columns, `[[`, "", "key")
  labs <- vapply(t$columns, function(c) if (lang == "tr") c$label_tr else c$label_en, "")
  fm <- as.data.frame(t$rows_fmt[[lang]], stringsAsFactors = FALSE, check.names = FALSE)
  d <- fm[, intersect(keys, names(fm)), drop = FALSE]
  if (values == "raw") {
    # Sayı sütunları ham değerle (17 anlamlı basamak, nokta), metin sütunları seçilen dildeki metinle.
    rw <- as.data.frame(t$rows, stringsAsFactors = FALSE, check.names = FALSE)
    for (k in names(d)) if (k %in% names(rw) && is.numeric(rw[[k]])) d[[k]] <- ifelse(is.na(rw[[k]]), "", sprintf("%.17g", rw[[k]]))
    else if (k %in% names(rw) && !is.numeric(rw[[k]]) && identical(t$columns[[match(k, keys)]]$type, "number")) d[[k]] <- ""
  }
  names(d) <- labs[match(names(d), keys)]
  sep <- if (values == "formatted" && lang == "tr") ";" else ","
  con <- textConnection("csv_out", "w", local = TRUE)
  utils::write.table(d, con, sep = sep, row.names = FALSE, col.names = TRUE, qmethod = "double", fileEncoding = "UTF-8", na = "")
  close(con)
  paste0("﻿", paste(csv_out, collapse = "\r\n"), "\r\n")
}
