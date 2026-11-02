# M12 — Her analiz için bağımsız çalışan R betiği (SPEC §2, §6.2, M12).
# Betik; veri okuma ve temizleme için motorun kendi fonksiyonlarını (birebir kopya) içerir,
# analizi ise psych'i doğrudan, açık argümanlarla çağırarak yapar. Sonuç `sonuc` nesnesindedir.

script_reader_functions <- c("api_stop", "max_upload_bytes", "max_rows", "parse_upload", "parse_delimited_bytes",
                             "parse_excel_bytes", "convert_columns", "validate_frame", "example_csv_hash",
                             "load_example", "clean_dataset")
script_pa_functions <- c("pa_cor", "pa_fa_values", "parallel_manual")

r_literal <- function(x) {
  paste(deparse(x, control = c("keepNA", "keepInteger", "niceNames", "showAttributes"), width.cutoff = 100L), collapse = "\n")
}

embed_functions <- function(names) {
  paste(vapply(names, function(n) {
    paste0(n, " <- ", paste(deparse(get(n, mode = "function"), width.cutoff = 100L), collapse = "\n"))
  }, ""), collapse = "\n\n")
}

script_version_check <- function(pkgs) {
  vers <- vapply(pkgs, function(p) as.character(utils::packageVersion(p)), "")
  paste0(
    "olceklab_surumler <- ", r_literal(vers), "\n",
    "for (p in names(olceklab_surumler)) {\n",
    "  v <- as.character(utils::packageVersion(p))\n",
    "  if (v != olceklab_surumler[[p]]) warning(sprintf(\"%s sürümü farklı: %s (ÖlçekLab: %s). Sonuçlar farklı olabilir.\", p, v, olceklab_surumler[[p]]))\n",
    "}\n",
    sprintf("if (getRversion() != \"%s\") warning(\"R sürümü farklı (ÖlçekLab: %s).\")\n",
            paste(R.version$major, R.version$minor, sep = "."), paste(R.version$major, R.version$minor, sep = "."))
  )
}

script_data_block <- function(ds) {
  if (identical(ds$source$type, "example")) {
    return(paste0(
      sprintf("kaynak <- load_example(%s)\n", r_literal(ds$source$name)),
      "ham <- kaynak$data\n",
      sprintf("stopifnot(identical(kaynak$hash, %s))\n", r_literal(ds$hash))
    ))
  }
  paste0(
    "veri_yolu <- \"VERI_DOSYASI\"  # <-- kendi dosyanızın yolunu yazın (", ds$filename, ")\n",
    "ham_bayt <- readBin(veri_yolu, \"raw\", file.size(veri_yolu))\n",
    sprintf("okunan <- parse_upload(ham_bayt, %s)\n", r_literal(ds$filename)),
    sprintf("if (!identical(okunan$hash, %s)) warning(\"Dosyanın SHA-256 özeti ÖlçekLab'deki veriyle aynı değil.\")\n", r_literal(ds$hash)),
    "ham <- okunan$data\n"
  )
}

script_analysis_block <- function(module, settings, seed) {
  items_line <- sprintf("items <- %s\nx <- temiz[, items, drop = FALSE]\n", r_literal(as.character(settings$items)))
  switch(module,
    item_analysis = paste0(items_line,
      "d <- psych::describe(x, type = 3)\n",
      "a <- psych::alpha(x, check.keys = FALSE, warnings = TRUE)\n",
      "sonuc <- list(\n",
      "  alpha = a$total$raw_alpha, std_alpha = a$total$std.alpha,\n",
      "  r_drop = a$item.stats[items, \"r.drop\"], alpha_drop = a$alpha.drop[items, \"raw_alpha\"],\n",
      "  describe = d[items, c(\"n\", \"mean\", \"sd\", \"skew\", \"kurtosis\")]\n",
      ")\n"),
    suitability = paste0(items_line,
      if (identical(settings$correlation, "polychoric")) "R <- psych::polychoric(x, correct = 0.5)$rho\n" else "R <- stats::cor(x)\n",
      "kmo <- psych::KMO(R)\n",
      "bart <- psych::cortest.bartlett(R, n = nrow(x))\n",
      "mard <- psych::mardia(x, plot = FALSE)\n",
      "sonuc <- list(kmo = kmo$MSA, msa = kmo$MSAi[items], bartlett = bart[c(\"chisq\", \"p.value\", \"df\")],\n",
      "              mardia = mard[c(\"b1p\", \"b2p\", \"skew\", \"p.skew\", \"kurtosis\", \"p.kurt\")])\n"),
    factor_number = paste0(items_line,
      "options(mc.cores = 1)  # psych::fa.parallel çok çekirdekte aynı tohumla farklı sonuç verir (SPEC_REVIEW PA-1)\n",
      "RNGkind(\"Mersenne-Twister\", \"Inversion\", \"Rejection\")\n",
      sprintf("set.seed(%dL)\n", as.integer(seed)),
      if (identical(settings$reference, "permutation")) paste0(
        sprintf("pa <- parallel_manual(x, n_iter = %dL, extraction = %s, correlation = %s, reference = \"permutation\", fm = %s)\n",
                settings$n_iter, r_literal(settings$extraction), r_literal(settings$correlation), r_literal(settings$fm)),
        "values <- pa$values\n")
      else paste0(
        sprintf("pa <- psych::fa.parallel(x, fm = %s, fa = %s, n.iter = %dL, sim = %s, quant = %s, cor = %s, plot = FALSE)\n",
                r_literal(settings$fm), r_literal(settings$extraction), settings$n_iter,
                r_literal(identical(settings$reference, "simulated_normal")), format(settings$quant, digits = 17),
                r_literal(if (identical(settings$correlation, "pearson")) "cor" else "poly")),
        "values <- pa$values\n"),
      sprintf("map <- psych::vss(x, n = %dL, rotate = \"none\", fm = \"minres\", plot = FALSE, cor = %s)$map\n",
              settings$map_max, r_literal(if (identical(settings$correlation, "pearson")) "cor" else "poly")),
      "sonuc <- list(values = values, map = map, map_suggested = which.min(map),\n",
      "              ncomp = if (exists(\"pa\") && !is.null(pa$ncomp)) pa$ncomp else NULL,\n",
      "              nfact = if (exists(\"pa\") && !is.null(pa$nfact)) pa$nfact else NULL)\n"),
    stop("Bu modül için betik tanımlı değil: ", module)
  )
}

build_r_script <- function(module, ds, settings, seed = NULL) {
  titles <- c(item_analysis = "M2 — Madde analizi", suitability = "M3 — Faktör analizine uygunluk",
              factor_number = "M4 — Faktör sayısı (paralel analiz, MAP)")
  pkgs <- unique(c("psych", "digest", if (identical(ds$source$type, "example")) c("lavaan")))
  fns <- c(script_reader_functions, if (module == "factor_number") script_pa_functions)
  paste0(
    "## ÖlçekLab yeniden üretim betiği: ", titles[[module]], "\n",
    "## Oluşturulma: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"), "\n",
    "## Veri özeti: ", ds$hash, "\n",
    "## Bu betik bağımsızdır: R ve aşağıdaki paketler dışında hiçbir şey gerektirmez.\n",
    "## Sonuçlar `sonuc` nesnesindedir.\n\n",
    "stopifnot(isTRUE(l10n_info()[[\"UTF-8\"]]))  # Türkçe sütun adları için UTF-8 yerel ayarı gerekir\n",
    script_version_check(pkgs), "\n",
    "## --- ÖlçekLab motorundan alınan veri okuma ve temizleme fonksiyonları (değiştirmeyin) ---\n",
    embed_functions(fns), "\n\n",
    "## --- 1. Veri ---\n", script_data_block(ds), "\n",
    "## --- 2. Temizleme (ÖlçekLab ayarlarıyla) ---\n",
    "config <- ", r_literal(ds$config), "\n",
    "rules <- ", r_literal(ds$clean_rules %||% list()), "\n",
    "temiz <- clean_dataset(ham, config, rules)$data\n\n",
    "## --- 3. Analiz ---\n", script_analysis_block(module, settings, seed),
    "print(sonuc)\n"
  )
}
