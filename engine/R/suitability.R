# M3 — Faktör analizine uygunluk (SPEC §7 M3).

suitability_matrix <- function(x, correlation, config) {
  if (identical(correlation, "polychoric")) {
    if (any(is.na(config$items$min))) {
      api_stop("polychoric_needs_categories",
               "Polikorik korelasyon için bütün maddelerde kategori aralığı tanımlanmalıdır.", 422L)
    }
    pc <- collect_conditions(psych::polychoric(x, correct = 0.5))
    list(R = pc$value$rho, warnings = pc$warnings)
  } else {
    list(R = stats::cor(x), warnings = character())
  }
}

analysis_suitability <- function(data, config, settings, dataset_hash) {
  correlation <- setting_choice(settings, "correlation", c("pearson", "polychoric"))
  items <- config$items$name
  x <- data[, items, drop = FALSE]
  if (nrow(x) <= length(items)) {
    api_stop("too_few_rows", "Uygunluk testleri için gözlem sayısı madde sayısından büyük olmalıdır.", 422L)
  }
  cm <- suitability_matrix(x, correlation, config)
  R <- cm$R
  kmo <- collect_conditions(psych::KMO(R))
  bart <- collect_conditions(psych::cortest.bartlett(R, n = nrow(x)))
  mard <- collect_conditions(psych::mardia(x, plot = FALSE))
  k <- kmo$value; b <- bart$value; m <- mard$value

  t1 <- make_table("T1", "KMO ve Bartlett küresellik testi", "KMO and Bartlett's test of sphericity",
    list(tbl_col("kmo", "KMO", "KMO", "num", 3L, TRUE), tbl_col("chisq", "Bartlett χ²", "Bartlett χ²", "num", 2L),
         tbl_col("df", "sd", "df", "int"), tbl_col("p", "p", "p", "p")),
    data.frame(kmo = k$MSA, chisq = b$chisq, df = b$df, p = b$p.value),
    note_tr = sprintf("Kaynak: psych::KMO, psych::cortest.bartlett (n = %d); korelasyon: %s.%s", nrow(x),
                      if (correlation == "pearson") "Pearson" else "polikorik",
                      if (correlation == "polychoric") " Bartlett testi normal kuram varsayımına dayanır." else ""),
    note_en = sprintf("Source: psych::KMO, psych::cortest.bartlett (n = %d); correlation: %s.%s", nrow(x),
                      if (correlation == "pearson") "Pearson" else "polychoric",
                      if (correlation == "polychoric") " Bartlett's test assumes normal theory." else ""))
  t2 <- make_table("T2", "Madde bazında örneklem yeterliliği (MSA)", "Measure of sampling adequacy per item",
    list(tbl_col("item", "Madde", "Item"), tbl_col("msa", "MSA", "MSA", "num", 3L, TRUE)),
    data.frame(item = items, msa = unname(k$MSAi[items])),
    note_tr = "Kaynak: psych::KMO ($MSAi).", note_en = "Source: psych::KMO ($MSAi).")
  t3 <- make_table("T3", "Mardia çok değişkenli normallik testi", "Mardia's multivariate normality test",
    list(tbl_col("stat", "Ölçüt", "Statistic"), tbl_col("value", "Değer", "Value", "num", 2L),
         tbl_col("test", "Test istatistiği", "Test statistic", "num", 2L), tbl_col("p", "p", "p", "p")),
    data.frame(stat = c("b1p (çarpıklık)", "b2p (basıklık)"), value = c(m$b1p, m$b2p),
               test = c(m$skew, m$kurtosis), p = c(m$p.skew, m$p.kurt), stringsAsFactors = FALSE),
    note_tr = "Kaynak: psych::mardia (ham veri). Likert verisinde ve büyük örneklemde test neredeyse her zaman anlamlı çıkar.",
    note_en = "Source: psych::mardia (raw data). With Likert data and large samples the test is almost always significant.")
  t3$rows_fmt$en$stat <- c("b1p (skewness)", "b2p (kurtosis)")

  warns <- list()
  low <- items[unname(k$MSAi[items]) < 0.5]
  if (length(low)) warns[[length(warns) + 1L]] <- warning_item("low_msa",
    sprintf("MSA değeri ,50'nin altında: %s.", paste(low, collapse = ", ")),
    sprintf("MSA below .50: %s.", paste(low, collapse = ", ")))
  for (w in unique(c(cm$warnings, kmo$warnings, bart$warnings, mard$warnings))) {
    warns[[length(warns) + 1L]] <- warning_item("psych_warning", w, w)
  }

  make_record(
    module = "suitability", dataset_hash = dataset_hash,
    settings = list(correlation = correlation, items = I(items)),
    results = list(n = nrow(x), kmo = k$MSA, msa = as.list(k$MSAi[items]),
                   bartlett = list(chisq = b$chisq, df = b$df, p = b$p.value),
                   mardia = list(b1p = m$b1p, b2p = m$b2p, skew = m$skew, p_skew = m$p.skew,
                                 kurtosis = m$kurtosis, p_kurt = m$p.kurt)),
    tables = list(t1, t2, t3), warnings = warns
  )
}
