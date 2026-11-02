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

script_analysis_block <- function(module, settings, seed, results = NULL) {
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
    efa = paste0(items_line,
      "options(mc.cores = 1)\n",
      "RNGkind(\"Mersenne-Twister\", \"Inversion\", \"Rejection\")\n",
      sprintf("set.seed(%dL)  # psych::fa varsayılan olarak rastgele başlangıçlı döndürme kullanır (SPEC_REVIEW EFA-2)\n", as.integer(seed)),
      sprintf("f <- psych::fa(x, nfactors = %dL, fm = %s, rotate = %s, cor = %s, correct = 0.5, n.rotations = %dL, scores = \"none\", warnings = TRUE)\n",
              as.integer(settings$nfactors), r_literal(settings$fm), r_literal(settings$rotate),
              r_literal(if (identical(settings$correlation, "pearson")) "cor" else "poly"), as.integer(settings$n_rotations)),
      "sonuc <- list(loadings = unclass(f$loadings)[items, , drop = FALSE], communality = f$communality[items],\n",
      "              uniqueness = f$uniquenesses[items], phi = f$Phi, vaccounted = f$Vaccounted,\n",
      "              fit = list(chisq = f$STATISTIC, df = f$dof, p = f$PVAL, tli = f$TLI, rmsea = f$RMSEA, rmsr = f$rms, bic = f$BIC))\n"),
    cfa = paste0(items_line,
      "model <- ", r_literal(settings$model$syntax), "\n",
      "options(mc.cores = 1)\n",
      "RNGkind(\"Mersenne-Twister\", \"Inversion\", \"Rejection\")\n",
      sprintf("set.seed(%dL)\n", as.integer(seed)),
      "fit <- ", lavaan_call_string(settings$lavaan_args), "\n",
      "pe <- lavaan::parameterEstimates(fit, standardized = TRUE, rsquare = TRUE)\n",
      "sonuc <- list(fit = lavaan::fitMeasures(fit), loadings = pe[pe$op == \"=~\", ],\n",
      "              post_check = lavaan::lavInspect(fit, \"post.check\"),\n",
      if (isTRUE(settings$mi_top > 0)) sprintf("              mi = lavaan::modindices(fit, sort. = TRUE, maximum.number = %dL),\n", as.integer(settings$mi_top)) else "",
      "              bollen_stine = lavaan::lavInspect(fit, \"test\")$bollen.stine)\n"),
    cfa_compare = paste0(items_line,
      "modeller <- ", r_literal(stats::setNames(vapply(settings$models, function(m) m$model$syntax, ""), vapply(settings$models, `[[`, "", "name"))), "\n",
      "options(mc.cores = 1)\n",
      "RNGkind(\"Mersenne-Twister\", \"Inversion\", \"Rejection\")\n",
      sprintf("set.seed(%dL)\n", as.integer(seed)),
      "fits <- lapply(modeller, function(model) ", lavaan_call_string(settings$lavaan_args), ")\n",
      "## İç içelik denetimi (Bentler ve Satorra, 2010): satır modeli sütun modelinin içinde iç içedir\n",
      "net_env <- list2env(stats::setNames(fits, paste0(\"fit\", seq_along(fits))))\n",
      "ic_ice <- eval(as.call(c(quote(semTools::net), lapply(paste0(\"fit\", seq_along(fits)), as.name))), net_env)@test\n",
      "testler <- list(\n",
      paste(vapply(results$tests %||% list(), function(t) sprintf(
        "  %s = lavaan::lavTestLRT(fits[[%s]], fits[[%s]]%s)[2, c(\"Chisq diff\", \"Df diff\", \"Pr(>Chisq)\")]",
        r_literal(paste(t$restricted, "-", t$reference)), r_literal(t$reference), r_literal(t$restricted),
        if (t$method == "standard") "" else sprintf(", method = %s", r_literal(t$method))), ""), collapse = ",\n"),
      "\n)\n",
      "sonuc <- list(fit = lapply(fits, lavaan::fitMeasures), ic_ice = ic_ice, testler = testler)\n"),
    reliability = paste0(items_line,
      "model <- ", r_literal(settings$model$syntax), "\n",
      "options(mc.cores = 1)\n",
      "RNGkind(\"Mersenne-Twister\", \"Inversion\", \"Rejection\")\n",
      sprintf("set.seed(%dL)\n", as.integer(seed)),
      "fit <- ", lavaan_call_string(settings$lavaan_args), "\n",
      "faktorler <- ", r_literal(lapply(stats::setNames(Filter(function(f) f$name %in% settings$model$first_order, settings$model$factors),
                                                        vapply(Filter(function(f) f$name %in% settings$model$first_order, settings$model$factors), `[[`, "", "name")),
                                        function(f) as.character(f$items))), "\n",
      "alfa <- sapply(faktorler, function(it) psych::alpha(x[stats::complete.cases(x[, it]), it], check.keys = FALSE, warnings = FALSE)$total$raw_alpha)\n",
      sprintf("omega <- semTools::compRelSEM(fit, obs.var = %s, ord.scale = TRUE, simplify = TRUE)\n", r_literal(isTRUE(settings$obs_var))),
      sprintf("ave <- semTools::AVE(fit, obs.var = %s)\n", r_literal(isTRUE(settings$obs_var))),
      if (length(settings$model$first_order) >= 2L) sprintf(
        "htmt <- semTools::htmt(%s, data = x, missing = \"listwise\", ordered = %s, absolute = %s, htmt2 = %s)\n",
        r_literal(reliability_htmt_syntax(settings$model)),
        if (identical(settings$htmt$correlation, "polychoric")) "items" else "NULL",
        r_literal(isTRUE(settings$htmt$absolute)), r_literal(isTRUE(settings$htmt$htmt2))) else "htmt <- NULL\n",
      "sonuc <- list(alfa = alfa, omega = omega, ave = ave, htmt = htmt)\n"),
    invariance = paste0(
      sprintf("items <- %s\ngrup <- %s\ngruplar <- %s\n", r_literal(as.character(settings$items)), r_literal(settings$group), r_literal(as.character(settings$groups))),
      "x <- temiz[, c(items, grup), drop = FALSE]\nx <- x[!is.na(x[[grup]]), , drop = FALSE]\nx[[grup]] <- as.character(x[[grup]])\nx <- x[x[[grup]] %in% gruplar, , drop = FALSE]\n",
      "options(mc.cores = 1)\n",
      "RNGkind(\"Mersenne-Twister\", \"Inversion\", \"Rejection\")\n",
      sprintf("set.seed(%dL)\n", as.integer(seed)),
      "yapisal_model <- ", r_literal(settings$model$syntax), "\n",
      "fits <- list()\n",
      paste(vapply(settings$steps, function(st) {
        if (identical(settings$approach, "categorical")) paste0(
          sprintf("## %s: semTools::measEq.syntax (theta, Wu ve Estabrook, 2016)\n", st$step),
          sprintf("model <- as.character(semTools::measEq.syntax(configural.model = yapisal_model, data = x, ordered = items, parameterization = \"theta\", ID.fac = \"std.lv\", ID.cat = \"Wu.Estabrook.2016\", group = grup, group.label = gruplar, group.equal = %s, group.partial = %s))\n",
                  r_literal(if (length(st$group_equal)) as.character(st$group_equal) else ""), r_literal(if (length(settings$partial)) as.character(settings$partial) else "")),
          sprintf("fits[[%s]] <- %s\n", r_literal(st$step), lavaan_call_string(st$lavaan_args)))
        else paste0("model <- yapisal_model\n", sprintf("fits[[%s]] <- %s\n", r_literal(st$step), lavaan_call_string(st$lavaan_args)))
      }, ""), collapse = ""),
      "adimlar <- names(fits)\n",
      sprintf("testler <- lapply(seq_along(adimlar)[-1], function(k) lavaan::lavTestLRT(fits[[k - 1]], fits[[k]]%s)[2, c(\"Chisq diff\", \"Df diff\", \"Pr(>Chisq)\")])\n",
              if (identical(settings$lrt_method, "standard")) "" else sprintf(", method = %s", r_literal(settings$lrt_method))),
      "names(testler) <- adimlar[-1]\n",
      if (!is.null(results$latent_model)) paste0(
        "## Gizil ortalamalar: skaler modelle eşdeğer model; d := ile tanımlı (SH ve GA lavaan'dan)\n",
        "model <- ", r_literal(results$latent_model$syntax), "\n",
        "fit_gizil <- ", lavaan_call_string(results$latent_model$lavaan_args), "\n",
        "pe <- lavaan::parameterEstimates(fit_gizil)\n",
        "gizil <- pe[pe$op == \":=\" | (pe$op == \"~1\" & pe$lhs %in% lavaan::lavNames(fit_gizil, \"lv\")), ]\n") else "gizil <- NULL\n",
      "sonuc <- list(fit = lapply(fits, lavaan::fitMeasures), testler = testler, gizil = gizil)\n"),
    invariance_scores = paste0(
      sprintf("items <- %s\ngrup <- %s\ngruplar <- %s\n", r_literal(as.character(settings$items)), r_literal(settings$group), r_literal(as.character(settings$groups))),
      "x <- temiz[, c(items, grup), drop = FALSE]\nx <- x[!is.na(x[[grup]]), , drop = FALSE]\nx[[grup]] <- as.character(x[[grup]])\nx <- x[x[[grup]] %in% gruplar, , drop = FALSE]\n",
      "options(mc.cores = 1)\nRNGkind(\"Mersenne-Twister\", \"Inversion\", \"Rejection\")\n", sprintf("set.seed(%dL)\n", as.integer(seed)),
      "model <- ", r_literal(settings$syntax), "\n",
      "fit <- ", lavaan_call_string(settings$lavaan_args), "\n",
      "skor <- lavaan::lavTestScore(fit, univariate = TRUE, cumulative = FALSE)\n",
      "pt <- lavaan::parTable(fit)\n",
      "sonuc <- list(uni = skor$uni, toplam = skor$test, parametreler = pt[pt$plabel %in% c(skor$uni$lhs, skor$uni$rhs), c(\"plabel\", \"lhs\", \"op\", \"rhs\", \"group\")])\n"),
    stop("Bu modül için betik tanımlı değil: ", module)
  )
}

# lavaan::cfa çağrısını, motorun kullandığı argümanlarla okunur biçimde yazar.
lavaan_call_string <- function(args) {
  parts <- vapply(names(args), function(n) sprintf("%s = %s", n, r_literal(args[[n]])), "")
  paste0("lavaan::cfa(model, data = x, ", paste(parts, collapse = ", "), ")")
}

script_packages <- function(module, ds) {
  base <- switch(module,
    item_analysis = , suitability = , factor_number = "psych",
    efa = c("psych", "GPArotation"),
    cfa = "lavaan",
    cfa_compare = c("lavaan", "semTools"),
    reliability = c("lavaan", "semTools", "psych"),
    invariance = , invariance_scores = c("lavaan", "semTools"))
  unique(c(base, "digest", if (identical(ds$source$type, "example")) c("lavaan", "psych")))
}

build_r_script <- function(module, ds, settings, seed = NULL, results = NULL) {
  titles <- c(item_analysis = "M2 — Madde analizi", suitability = "M3 — Faktör analizine uygunluk",
              factor_number = "M4 — Faktör sayısı (paralel analiz, MAP)", efa = "M5 — Açımlayıcı faktör analizi",
              cfa = "M6 — Doğrulayıcı faktör analizi", cfa_compare = "M6 — Model karşılaştırma",
              reliability = "M7 — Güvenirlik ve geçerlik", invariance = "M8 — Ölçme değişmezliği ve gizil ortalamalar",
              invariance_scores = "M8 — Kısmi değişmezlik: skor testleri")
  pkgs <- script_packages(module, ds)
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
    "## --- 3. Analiz ---\n", script_analysis_block(module, settings, seed, results),
    "print(sonuc)\n"
  )
}
