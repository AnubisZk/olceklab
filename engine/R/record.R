# Analiz kaydı (SPEC §6.2). Her modül çıktısı bu yapıda döner.

warning_item <- function(code, message_tr, message_en) {
  list(code = code, message_tr = message_tr, message_en = message_en)
}

current_rng_info <- function() {
  k <- RNGkind()
  list(kind = k[1], normal_kind = k[2], sample_kind = k[3],
       mc_cores = getOption("mc.cores", NA_integer_))
}

make_record <- function(module, dataset_hash, settings, results,
                        tables = list(), figures = list(), warnings = list(),
                        seed = NULL, rng = NULL, r_script = NULL) {
  v <- engine_versions()
  list(
    analysis_id = uuid::UUIDgenerate(use.time = FALSE),
    module = module,
    dataset_hash = dataset_hash,
    settings = settings,
    seed = seed,
    rng = rng,
    engine = list(R = v$R, packages = v$packages, blas = v$blas),
    results = results,
    tables = tables,
    figures = figures,
    warnings = warnings,
    r_script = r_script,
    created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
}

# Rastgelelik denetimi (SPEC §0 kural 9; SPEC_REVIEW PA-1).
# Kod, sabit RNG türü, verilen tohum ve mc.cores = 1 ile çalışır; çağıranın
# RNG durumu ve seçenekleri sonra geri yüklenir.
with_seeded_rng <- function(seed, code) {
  if (!is.numeric(seed) || length(seed) != 1L || is.na(seed) || seed != round(seed)) {
    api_stop("invalid_seed", "Tohum değeri bir tam sayı olmalıdır.", 422L)
  }
  old_kind <- RNGkind()
  had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
  old_opt <- options(mc.cores = 1L)
  on.exit({
    options(old_opt)
    RNGkind(old_kind[1], old_kind[2], old_kind[3])
    if (had_seed) assign(".Random.seed", old_seed, envir = globalenv())
  }, add = TRUE)
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(as.integer(seed))
  rng <- current_rng_info()
  value <- force(code)
  list(value = value, rng = rng)
}

# psych'in uyarılarını ve iletilerini toplar; sonuçla birlikte döndürür.
collect_conditions <- function(expr) {
  msgs <- character()
  value <- withCallingHandlers(
    suppressMessages(expr),
    warning = function(w) {
      msgs <<- c(msgs, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, warnings = unique(msgs))
}
