# Ortak ölçme modeli tanımı (M6, M7, M8).
# Model iki yoldan gelir:
#   - kurucu:   list(factors = list(list(name = "F1", items = c("x1", "x2", ...)), ...),
#                    covariances = list(c("x1", "x4"), ...))   # hata kovaryansları
#   - sözdizimi: list(syntax = "F1 =~ x1 + x2 + x3\n ...")      # gelişmiş kullanıcı
# Her iki yolda da çıktı aynıdır: lavaan sözdizimi, faktör → gösterge listesi, hata kovaryansları
# ve modelde kullanılan gözlenen değişkenler. Sözdizimi lavaan'ın kendi ayrıştırıcısıyla denetlenir.

lavaan_name_ok <- function(x) grepl("^[\\p{L}.][\\p{L}\\p{N}._]*$", x, perl = TRUE) & !grepl("^\\.[0-9]", x)

model_check_item_names <- function(items) {
  bad <- items[!lavaan_name_ok(items)]
  if (length(bad)) {
    api_stop("item_name_not_lavaan",
             sprintf("Bu sütun adları lavaan modelinde kullanılamaz: %s. Adlar harfle başlamalı; yalnızca harf, rakam, nokta ve alt çizgi içermelidir. Sütunu dosyada yeniden adlandırıp yükleyin.",
                     paste(bad, collapse = ", ")), 422L)
  }
}

model_from_builder <- function(spec, items) {
  fs <- spec$factors
  if (!is.list(fs) || !length(fs)) api_stop("model_no_factors", "Modelde en az bir faktör olmalıdır.", 422L)
  names_f <- vapply(fs, function(f) if (is.null(f$name)) "" else as.character(f$name)[1], "")
  if (any(!nzchar(names_f))) api_stop("factor_name_missing", "Her faktörün bir adı olmalıdır.", 422L)
  bad <- names_f[!lavaan_name_ok(names_f)]
  if (length(bad)) {
    api_stop("factor_name_invalid", sprintf("Geçersiz faktör adı: %s. Ad harfle başlamalı; boşluk içermemelidir.", paste(bad, collapse = ", ")), 422L)
  }
  if (anyDuplicated(names_f)) api_stop("factor_name_duplicate", sprintf("Aynı adlı faktörler var: %s.", paste(unique(names_f[duplicated(names_f)]), collapse = ", ")), 422L)
  clash <- intersect(names_f, items)
  if (length(clash)) api_stop("factor_name_is_item", sprintf("Faktör adı bir madde adıyla aynı olamaz: %s.", paste(clash, collapse = ", ")), 422L)
  loads <- lapply(fs, function(f) as.character(unlist(f$items)))
  names(loads) <- names_f
  used <- unlist(loads, use.names = FALSE)
  unknown <- setdiff(used, items)
  if (length(unknown)) api_stop("model_unknown_item", sprintf("Temiz veride madde olarak tanımlı olmayan değişken: %s.", paste(unique(unknown), collapse = ", ")), 422L)
  if (anyDuplicated(used)) {
    api_stop("item_in_two_factors", sprintf("Model kurucuda bir madde yalnızca bir faktöre atanabilir: %s. Çapraz yük için sözdizimi düzenleyicisini kullanın.",
                                            paste(unique(used[duplicated(used)]), collapse = ", ")), 422L)
  }
  few <- names(loads)[lengths(loads) < 2L]
  if (length(few)) api_stop("factor_too_few_items", sprintf("Her faktörde en az iki madde olmalıdır: %s.", paste(few, collapse = ", ")), 422L)
  covs <- spec$covariances
  cov_pairs <- list()
  if (length(covs)) {
    for (cv in covs) {
      cv <- as.character(unlist(cv))
      if (length(cv) != 2L || cv[1] == cv[2]) api_stop("covariance_invalid", "Hata kovaryansı iki farklı madde arasında tanımlanmalıdır.", 422L)
      if (!all(cv %in% used)) api_stop("covariance_unknown_item", sprintf("Hata kovaryansındaki madde modelde yok: %s.", paste(setdiff(cv, used), collapse = ", ")), 422L)
      cov_pairs[[length(cov_pairs) + 1L]] <- cv
    }
    key <- vapply(cov_pairs, function(p) paste(sort(p), collapse = "~~"), "")
    cov_pairs <- cov_pairs[!duplicated(key)]
  }
  lines <- c(vapply(names(loads), function(f) sprintf("%s =~ %s", f, paste(loads[[f]], collapse = " + ")), ""),
             vapply(cov_pairs, function(p) sprintf("%s ~~ %s", p[1], p[2]), ""))
  list(syntax = paste(lines, collapse = "\n"), source = "builder")
}

# lavaan sözdizimini ayrıştırır ve yapıyı çıkarır. Yapısal regresyon (~) CFA kapsamında değildir.
model_structure <- function(syntax, items) {
  pt <- tryCatch(
    withCallingHandlers(lavaan::lavParseModelString(syntax, as.data.frame. = TRUE),
                        warning = function(w) api_stop("model_syntax_warning", "Model sözdizimi lavaan tarafından uyarıyla karşılandı.", 422L, conditionMessage(w))),
    error = function(e) if (inherits(e, "api_error")) stop(e) else api_stop("model_syntax_error", "Model sözdizimi geçersiz.", 422L, conditionMessage(e))
  )
  if (!nrow(pt) || !any(pt$op == "=~")) api_stop("model_no_factors", "Modelde en az bir '=~' (faktör) tanımı olmalıdır.", 422L)
  if (any(pt$op == "~")) api_stop("model_has_regression", "DFA modelinde yapısal regresyon (~) kullanılamaz.", 422L)
  latents <- unique(pt$lhs[pt$op == "=~"])
  clash <- intersect(latents, items)
  if (length(clash)) api_stop("factor_name_is_item", sprintf("Faktör adı bir madde adıyla aynı olamaz: %s.", paste(clash, collapse = ", ")), 422L)
  vars <- unique(c(pt$rhs[pt$op == "=~"], pt$lhs[pt$op == "~~"], pt$rhs[pt$op == "~~"]))
  vars <- vars[nzchar(vars)]
  observed <- setdiff(vars, latents)
  unknown <- setdiff(observed, items)
  if (length(unknown)) api_stop("model_unknown_item", sprintf("Temiz veride madde olarak tanımlı olmayan değişken: %s.", paste(unknown, collapse = ", ")), 422L)
  loads <- lapply(stats::setNames(latents, latents), function(f) pt$rhs[pt$op == "=~" & pt$lhs == f])
  first_order <- latents[vapply(loads, function(v) all(v %in% observed), logical(1))]
  covs <- pt[pt$op == "~~" & pt$lhs %in% observed & pt$rhs %in% observed & pt$lhs != pt$rhs, c("lhs", "rhs")]
  list(
    factors = lapply(names(loads), function(f) list(name = f, items = I(loads[[f]]))),
    first_order = I(first_order),
    covariances = lapply(seq_len(nrow(covs)), function(k) I(c(covs$lhs[k], covs$rhs[k]))),
    observed = I(items[items %in% observed])
  )
}

model_warnings <- function(structure) {
  warns <- list()
  few <- vapply(structure$factors, function(f) if (length(f$items) < 3L) f$name else NA_character_, "")
  few <- few[!is.na(few)]
  if (length(few)) {
    warns[[length(warns) + 1L]] <- warning_item("factor_fewer_than_three",
      sprintf("Üçten az göstergeli faktör: %s. Bu faktör tek başına tanımlanamaz; kestirim diğer faktörlerle korelasyonuna dayanır ve kararsız olabilir.", paste(few, collapse = ", ")),
      sprintf("Factor with fewer than three indicators: %s. It is not identified on its own; estimation relies on its correlations with other factors and may be unstable.", paste(few, collapse = ", ")))
  }
  warns
}

# Kurucu ya da sözdizimi girdisinden doğrulanmış model döndürür.
resolve_model <- function(spec, items) {
  if (!is.list(spec) || (is.null(spec$syntax) && is.null(spec$factors))) {
    api_stop("model_missing", "Model tanımı (factors ya da syntax) gönderilmelidir.", 422L)
  }
  model_check_item_names(items)
  if (!is.null(spec$syntax)) {
    if (!is.character(spec$syntax) || length(spec$syntax) != 1L || !nzchar(trimws(spec$syntax))) {
      api_stop("model_syntax_error", "Model sözdizimi boş olamaz.", 422L)
    }
    m <- list(syntax = spec$syntax, source = "syntax")
  } else {
    m <- model_from_builder(spec, items)
  }
  st <- model_structure(m$syntax, items)
  c(m, st, list(warnings = model_warnings(st)))
}

# Model kurucunun önizlemesi: sözdizimi ve yapı (analiz yapmaz).
analysis_model_preview <- function(config, spec) {
  m <- resolve_model(spec, config$items$name)
  m[c("syntax", "source", "factors", "covariances", "observed", "warnings")]
}

# Kayıtta ve betikte kullanılacak yalın model gösterimi.
model_record <- function(m) {
  list(syntax = m$syntax, source = m$source, factors = m$factors, first_order = m$first_order,
       covariances = m$covariances, observed = m$observed)
}

# Varsayılan model: M1'de tanımlanan alt boyutlar.
default_model_from_subscales <- function(config) {
  it <- config$items
  if (all(is.na(it$subscale))) return(NULL)
  subs <- unique(it$subscale[!is.na(it$subscale)])
  list(factors = lapply(subs, function(s) list(name = s, items = I(it$name[!is.na(it$subscale) & it$subscale == s]))))
}
