# İş sistemi (SPEC §7 M9 9.7; SPEC_REVIEW ARCH-1, MC-5, REP-5).
# Simülasyon parçalar (koşul × tekrar aralığı) hâlinde mirai işçilerinde çalışır. Her parça diske .rds olarak yazılır;
# iş kesilirse eksik parçalar yeniden çalıştırılır. Tekrar tohumları seed + 10000·koşul + tekrar olduğu için kesilip
# devam eden iş, kesintisiz işle birebir aynı sonucu verir. Diske yalnızca sentetik veri sonuçları yazılır (REP-5).

jobs_root <- function() {
  d <- Sys.getenv("JOBS_DIR", file.path(tempdir(), "olceklab-jobs"))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

online_limits <- function() {
  on <- tolower(Sys.getenv("ONLINE_LIMITS", "false")) %in% c("true", "1", "yes")
  list(enabled = on,
       max_total = as.integer(Sys.getenv("ONLINE_MAX_REPLICATIONS_X_CONDITIONS", "2000")),
       max_workers = as.integer(Sys.getenv("ONLINE_MAX_WORKERS", "2")),
       timeout = as.numeric(Sys.getenv("ONLINE_JOB_TIMEOUT_SECONDS", "3600")))
}

sim_spec_defaults <- list(reps = 1000L, seed = 20261030L, chunk_size = 250L)

normalize_sim_spec <- function(body) {
  if (!is.list(body)) api_stop("invalid_simulation", "Simülasyon tanımı bir nesne olmalıdır.", 422L)
  pop <- normalize_population(body$population)
  cd <- if (is.list(body$conditions)) body$conditions else list()
  Ns <- as.integer(unlist(cd$N))
  if (!length(Ns) || anyNA(Ns) || any(Ns < 30L) || anyDuplicated(Ns)) api_stop("invalid_simulation", "N listesi en az 30 olan, birbirinden farklı tam sayılardan oluşmalıdır.", 422L)
  G <- length(pop$groups)
  ratios <- if (G == 1L) list(1) else {
    rr <- cd$ratios
    if (is.null(rr) || !length(rr)) list(rep(1 / G, G)) else lapply(rr, function(r) as.numeric(unlist(r)))
  }
  for (r in ratios) if (length(r) != G || any(is.na(r)) || any(r <= 0)) api_stop("invalid_simulation", sprintf("Her grup oranı %d pozitif değerden oluşmalıdır (ör. 70/30 ya da ,7/,3).", G), 422L)
  ratios <- lapply(ratios, function(r) r / sum(r))  # 70/30 ve ,7/,3 aynı orandır
  scen_names <- vapply(pop$dif, `[[`, "", "name")
  sc <- if (is.null(cd$scenarios)) scen_names else as.character(unlist(cd$scenarios))
  if (!length(sc) || any(!(sc %in% scen_names))) api_stop("invalid_simulation", "Bilinmeyen senaryo adı.", 422L)
  sc_idx <- match(sc, scen_names)
  est <- if (is.null(body$estimators)) "ML" else unique(as.character(unlist(body$estimators)))
  if (!length(est) || any(!(est %in% cfa_estimators))) api_stop("invalid_simulation", "Kestiriciler ML, MLR ya da WLSMV olmalıdır.", 422L)
  if ("WLSMV" %in% est && pop$data_type != "ordinal") api_stop("invalid_simulation", "WLSMV yalnızca sıralı veri üretiminde seçilebilir.", 422L)
  reps <- setting_number(body, "reps", sim_spec_defaults$reps, 1, 10000, integer = TRUE)
  seed <- setting_number(body, "seed", sim_spec_defaults$seed, 1, .Machine$integer.max - 1e8, integer = TRUE)
  chunk <- setting_number(body, "chunk_size", sim_spec_defaults$chunk_size, 1, 10000, integer = TRUE)
  an <- if (is.list(body$analyses)) body$analyses else list()
  pa <- if (is.list(an$pa)) an$pa else list()
  analyses <- list(cfa = setting_flag(an, "cfa", TRUE), invariance = setting_flag(an, "invariance", G >= 2L) && G >= 2L,
                   reliability = setting_flag(an, "reliability", TRUE),
                   pa = list(enabled = setting_flag(pa, "enabled", FALSE), n_iter = setting_number(pa, "n_iter", 100L, 10, 5000, integer = TRUE),
                             quant = setting_number(pa, "quant", 0.95, 0.5, 0.999), per_cell = setting_flag(pa, "per_cell", TRUE)))
  cr <- if (is.list(body$criteria)) body$criteria else list()
  crit <- list(alpha = setting_number(cr, "alpha", 0.05, 0.0001, 0.5), cfi = setting_number(cr, "cfi", -0.01, -1, 0),
               rmsea = setting_number(cr, "rmsea", 0.015, 0, 1), srmr_load = setting_number(cr, "srmr_load", 0.030, 0, 1),
               srmr_int = setting_number(cr, "srmr_int", 0.010, 0, 1))
  rc <- if (is.list(body$recommend)) body$recommend else list()
  cov <- if (is.null(rc$coverage)) c(0.91, 0.98) else as.numeric(unlist(rc$coverage))
  rec <- list(admissible = setting_number(rc, "admissible", 0.95, 0, 1), param_bias = setting_number(rc, "param_bias", 0.10, 0, 1),
              se_bias = setting_number(rc, "se_bias", 0.10, 0, 1), coverage = cov, power = setting_number(rc, "power", 0.80, 0, 1),
              power_step = setting_choice(rc, "power_step", c("auto", "scalar", "metric")), rel_cut = setting_number(rc, "rel_cut", 0.10, 0, 1))
  grid <- expand.grid(scenario = sc_idx, ratio = seq_along(ratios), N = Ns, KEEP.OUT.ATTRS = FALSE)[, c("N", "ratio", "scenario")]
  grid$index <- seq_len(nrow(grid))
  lim <- online_limits()
  if (lim$enabled && reps * nrow(grid) > lim$max_total) {
    api_stop("online_limit", sprintf("Çevrim içi modda tekrar × koşul en fazla %d olabilir (istenen: %d). Bağımsız R paketini indirip kendi bilgisayarınızda çalıştırabilirsiniz.",
                                     lim$max_total, reps * nrow(grid)), 422L)
  }
  list(pop = pop, Ns = Ns, ratios = ratios, scenarios = sc_idx, estimators = est, reps = reps, seed = seed, chunk_size = chunk,
       analyses = analyses, criteria = crit, recommend = rec, grid = grid, body = body)
}

sim_chunks <- function(spec) {
  out <- list()
  for (ci in spec$grid$index) {
    starts <- seq(1L, spec$reps, by = spec$chunk_size)
    for (s in starts) out[[length(out) + 1L]] <- list(cond = ci, from = s, to = min(spec$reps, s + spec$chunk_size - 1L))
  }
  out
}

sim_chunk_file <- function(dir, ch) file.path(dir, sprintf("chunk_%04d_%05d_%05d.rds", ch$cond, ch$from, ch$to))

sim_condition <- function(spec, ci) {
  g <- spec$grid[spec$grid$index == ci, ]
  list(index = ci, N = g$N, ratio = spec$ratios[[g$ratio]], scenario = g$scenario)
}

# Koşul başına paralel analiz referansı (MC-12): tohum seed + 10000·koşul (tekrar 0).
sim_pa_ref_for <- function(spec, cond) {
  pa <- spec$analyses$pa
  if (!isTRUE(pa$enabled) || !isTRUE(pa$per_cell)) return(NULL)
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(sim_seed(spec$seed, cond$index, 0L))
  sim_pa_reference(cond$N, length(spec$pop$items), pa$n_iter, pa$quant)
}

sim_run_chunk <- function(dir, ch) {
  spec <- readRDS(file.path(dir, "spec.rds"))
  old <- options(mc.cores = 1L); on.exit(options(old), add = TRUE)
  cond <- sim_condition(spec, ch$cond)
  t0 <- Sys.time()
  ref <- sim_pa_ref_for(spec, cond)
  reps <- lapply(ch$from:ch$to, function(r) sim_replicate(spec$pop, cond, r, spec$seed, spec$estimators, spec$analyses, spec$criteria, ref))
  f <- sim_chunk_file(dir, ch)
  tmp <- paste0(f, ".tmp")
  saveRDS(reps, tmp)
  file.rename(tmp, f)
  list(file = basename(f), seconds = as.numeric(difftime(Sys.time(), t0, units = "secs")), reps = length(reps))
}

sim_job_create <- function(body) {
  spec <- normalize_sim_spec(body)
  id <- uuid::UUIDgenerate(use.time = FALSE)
  dir <- file.path(jobs_root(), id)
  dir.create(dir, recursive = TRUE)
  saveRDS(spec, file.path(dir, "spec.rds"))
  lim <- online_limits()
  w <- if (lim$enabled) min(lim$max_workers, max(1L, .olceklab$workers)) else max(1L, .olceklab$workers)
  .olceklab$jobs[[id]] <- list(id = id, dir = dir, status = "queued", chunks = sim_chunks(spec), in_flight = character(),
                               started = Sys.time(), seconds = 0, workers = w, error = NULL, total_reps = spec$reps * nrow(spec$grid),
                               timeout = if (lim$enabled) lim$timeout else Inf)
  id
}

sim_job_get <- function(id) {
  j <- .olceklab$jobs[[id]]
  if (is.null(j)) api_stop("job_not_found", "İş bulunamadı. Motor yeniden başlamış olabilir.", 404L)
  j
}

sim_pending <- function(j) Filter(function(ch) !file.exists(sim_chunk_file(j$dir, ch)) && !(basename(sim_chunk_file(j$dir, ch)) %in% j$in_flight), j$chunks)

sim_job_status <- function(id) {
  j <- sim_job_get(id)
  done <- Filter(function(ch) file.exists(sim_chunk_file(j$dir, ch)), j$chunks)
  done_reps <- sum(vapply(done, function(ch) ch$to - ch$from + 1L, 0L))
  elapsed <- as.numeric(difftime(Sys.time(), j$started, units = "secs"))
  if (j$status %in% c("running", "queued") && length(done) == length(j$chunks) && !length(j$in_flight)) {
    .olceklab$jobs[[id]]$status <- "done"; j$status <- "done"
  }
  rate <- if (done_reps > 0 && j$seconds > 0) j$seconds / done_reps else NA_real_
  eta <- if (is.na(rate)) NULL else rate * (j$total_reps - done_reps) / j$workers
  list(job_id = id, status = j$status, chunks_done = length(done), chunks_total = length(j$chunks),
       reps_done = done_reps, reps_total = j$total_reps, progress = done_reps / j$total_reps,
       in_flight = length(j$in_flight), elapsed_seconds = elapsed, eta_seconds = eta, error = j$error,
       text = lapply(c(tr = "tr", en = "en"), function(lang) list(
         progress = sprintf(if (lang == "tr") "%s / %s tekrar (%s)" else "%s / %s replications (%s)",
                            fmt_int(done_reps, lang), fmt_int(j$total_reps, lang), fmt_pct(done_reps / j$total_reps, lang, 0L)),
         elapsed = fmt_duration(elapsed, lang), eta = if (is.null(eta)) FMT_MISSING else fmt_duration(eta, lang))))
}

# Ana süreçte zamanlayıcı: en fazla `workers` parça aynı anda işçide çalışır.
sim_job_schedule <- function(id) {
  j <- .olceklab$jobs[[id]]
  if (is.null(j) || !(j$status %in% c("running", "queued"))) return(invisible(FALSE))
  if (as.numeric(difftime(Sys.time(), j$started, units = "secs")) > j$timeout) {
    .olceklab$jobs[[id]]$status <- "timeout"
    .olceklab$jobs[[id]]$error <- "Çevrim içi modda iş süresi sınırı aşıldı; bağımsız R paketini indirip çalıştırabilirsiniz."
    return(invisible(FALSE))
  }
  .olceklab$jobs[[id]]$status <- "running"
  pend <- sim_pending(j)
  free <- j$workers - length(j$in_flight)
  # Her parça kendi işlevinde başlatılır: döngü içinde tanımlanan geri çağrılar aynı değişkeni paylaşmasın diye.
  for (ch in utils::head(pend, max(0L, free))) sim_job_launch(id, ch)
  invisible(TRUE)
}

sim_job_launch <- function(id, ch) {
  j <- .olceklab$jobs[[id]]
  key <- basename(sim_chunk_file(j$dir, ch))
  .olceklab$jobs[[id]]$in_flight <- c(j$in_flight, key)
  finish <- function(out) {
    jj <- .olceklab$jobs[[id]]
    if (is.null(jj)) return(invisible())
    .olceklab$jobs[[id]]$in_flight <- setdiff(jj$in_flight, key)
    if (!isTRUE(out$ok)) {
      .olceklab$jobs[[id]]$status <- "failed"
      .olceklab$jobs[[id]]$error <- if (is.list(out$body)) out$body$error$detail else as.character(out)
      return(invisible())
    }
    .olceklab$jobs[[id]]$seconds <- jj$seconds + out$value$seconds
    sim_job_schedule(id)
  }
  if (isTRUE(.olceklab$workers > 0L)) {
    m <- mirai::mirai(worker_call("sim_run_chunk", list(dir = dir, ch = ch)), dir = j$dir, ch = ch)
    promises::then(m, onFulfilled = function(out) {
      if (mirai::is_mirai_error(out) || mirai::is_error_value(out)) out <- list(ok = FALSE, body = list(error = list(detail = paste(as.character(out), collapse = " "))))
      finish(out)
    }, onRejected = function(e) finish(list(ok = FALSE, body = list(error = list(detail = conditionMessage(e))))))
  } else {
    dir <- j$dir
    later::later(function() finish(worker_call("sim_run_chunk", list(dir = dir, ch = ch))), 0)
  }
  invisible(key)
}

sim_job_cancel <- function(id) {
  sim_job_get(id)
  if (.olceklab$jobs[[id]]$status %in% c("running", "queued")) .olceklab$jobs[[id]]$status <- "cancelled"
  sim_job_status(id)
}

sim_job_resume <- function(id) {
  j <- sim_job_get(id)
  if (j$status %in% c("cancelled", "failed", "timeout")) {
    .olceklab$jobs[[id]]$status <- "running"; .olceklab$jobs[[id]]$error <- NULL
    if (j$status == "timeout") .olceklab$jobs[[id]]$started <- Sys.time()
    sim_job_schedule(id)
  }
  sim_job_status(id)
}

# Test ve bağımsız kullanım için eşzamanlı çalıştırıcı (en fazla max_chunks parça).
sim_job_run_sync <- function(id, max_chunks = Inf) {
  j <- sim_job_get(id)
  pend <- sim_pending(j)
  n <- 0L
  for (ch in pend) {
    if (n >= max_chunks) break
    out <- sim_run_chunk(j$dir, ch)
    .olceklab$jobs[[id]]$seconds <- .olceklab$jobs[[id]]$seconds + out$seconds
    n <- n + 1L
  }
  .olceklab$jobs[[id]]$status <- if (length(sim_pending(.olceklab$jobs[[id]])) == 0L) "done" else "cancelled"
  sim_job_status(id)
}

sim_job_load <- function(dir) {
  spec <- readRDS(file.path(dir, "spec.rds"))
  files <- vapply(sim_chunks(spec), function(ch) sim_chunk_file(dir, ch), "")
  if (!all(file.exists(files))) api_stop("job_not_done", "Simülasyon henüz tamamlanmadı.", 409L)
  reps <- do.call(c, lapply(files, readRDS))
  list(spec = spec, reps = reps)
}

# İşçide: bütün parçaları okuyup özet kaydını kurar.
sim_results_for <- function(dir, job_id) {
  ld <- sim_job_load(dir)
  sim_results_record(ld$spec, sim_summary(ld$spec, ld$reps), job_id)
}

# Çalıştırmadan önce süre tahmini: en büyük N'li koşulda iki tekrar ölçülür (9.9: "birkaç tekrarla ölçülür").
sim_estimate <- function(body, workers = .olceklab$workers) {
  spec <- normalize_sim_spec(body)
  g <- spec$grid[which.max(spec$grid$N), ]
  cond <- sim_condition(spec, g$index)
  old <- options(mc.cores = 1L); on.exit(options(old), add = TRUE)
  ref <- sim_pa_ref_for(spec, cond)
  t0 <- Sys.time()
  for (r in 1:2) sim_replicate(spec$pop, cond, r, spec$seed, spec$estimators, spec$analyses, spec$criteria, ref)
  per <- as.numeric(difftime(Sys.time(), t0, units = "secs")) / 2
  lim <- online_limits()
  w <- if (lim$enabled) min(lim$max_workers, max(1L, workers)) else max(1L, workers)
  total <- per * spec$reps * nrow(spec$grid) / w
  list(seconds_per_rep_upper = per, conditions = nrow(spec$grid), reps = spec$reps, workers = w,
       estimated_seconds_upper = total,
       text = list(tr = sprintf("En fazla yaklaşık %s (%s koşul × %s tekrar, %s işçi)", fmt_duration(total, "tr"), fmt_int(nrow(spec$grid), "tr"), fmt_int(spec$reps, "tr"), fmt_int(w, "tr")),
                   en = sprintf("At most about %s (%s condition%s × %s replication%s, %s worker%s)", fmt_duration(total, "en"), fmt_int(nrow(spec$grid), "en"), if (nrow(spec$grid) == 1L) "" else "s",
                                fmt_int(spec$reps, "en"), if (spec$reps == 1L) "" else "s", fmt_int(w, "en"), if (w == 1L) "" else "s")),
       note_tr = "Tahmin en büyük N'li koşulda iki tekrarla ölçülmüştür; küçük N'li koşullar daha hızlıdır, bu yüzden üst sınırdır.",
       note_en = "Estimated from two replications of the largest-N condition; smaller conditions are faster, so this is an upper bound.")
}
