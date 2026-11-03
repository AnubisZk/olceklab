# M9 iş sistemi HTTP üzerinden (iki mirai işçisi): başlat → iptal → sürdür → sonuçlar → bağımsız paket.
# Sonuçlar aynı tanımın yerelde eşzamanlı çalıştırılmasıyla birebir karşılaştırılır.

eng <- start_engine(workers = 2L)
api <- eng$api

sim_body <- list(population = list(
  factors = list(list(name = "F1", items = c("y1", "y2", "y3")), list(name = "F2", items = c("y4", "y5", "y6"))),
  loadings = list(y1 = .7, y2 = .6, y3 = .65, y4 = .7, y5 = .6, y6 = .7), factor_cor = list(list(a = "F1", b = "F2", r = .4)),
  data_type = "ordinal", category_props = c(.1, .2, .4, .2, .1),
  groups = list(list(name = "A"), list(name = "B", latent_means = list(F1 = .3))),
  dif = list(list(name = "DIF", group = "B", effects = list(list(item = "y1", type = "threshold", size = .5))))),
  conditions = list(N = c(200, 300)), estimators = list("ML"), reps = 6, chunk_size = 1, seed = 99)

wait_status <- function(id, until, timeout = 240) {
  t0 <- Sys.time()
  repeat {
    st <- body_json(api(sprintf("/jobs/%s", id)))
    if (st$status %in% until && !(st$status == "cancelled" && FALSE)) return(st)
    if (difftime(Sys.time(), t0, units = "secs") > timeout) stop("iş zaman aşımına uğradı: ", st$status)
    Sys.sleep(0.3)
  }
}

test_that("süre tahmini işçide ölçülür", {
  e <- body_json(api("/simulations/estimate", "POST", json = sim_body))
  expect_gt(e$seconds_per_rep_upper, 0)
  expect_identical(e$conditions, 4L)
  expect_identical(e$workers, 2L)  # ölçüm işçide yapılır ama işçi sayısı ana süreçten gelir
  expect_match(e$text$tr, "2 işçi", fixed = TRUE)
  expect_match(e$note_tr, "üst sınırdır", fixed = TRUE)
})

test_that("iş başlatılır, iptal edilir, sürdürülür; sonuçlar yerel eşzamanlı çalıştırmayla aynı", {
  st <- body_json(api("/simulations", "POST", json = sim_body))
  id <- st$job_id
  expect_true(st$status %in% c("running", "queued"))
  Sys.sleep(1.5)
  c1 <- body_json(api(sprintf("/jobs/%s/cancel", id), "POST"))
  expect_identical(c1$status, "cancelled")
  Sys.sleep(4)  # işçideki parçalar biter; yeni parça başlatılmaz
  mid <- body_json(api(sprintf("/jobs/%s", id)))
  expect_identical(mid$status, "cancelled")
  expect_lt(mid$chunks_done, mid$chunks_total)
  r409 <- api(sprintf("/simulations/%s/results", id))
  expect_identical(httr2::resp_status(r409), 409L)
  body_json(api(sprintf("/jobs/%s/resume", id), "POST"))
  done <- wait_status(id, c("done", "failed"))
  expect_identical(done$status, "done")
  expect_identical(done$reps_done, 24L)
  rec <- body_json(api(sprintf("/simulations/%s/results", id)))
  expect_identical(rec$module, "simulation")
  lid <- sim_job_create(sim_body); sim_job_run_sync(lid)
  ld <- sim_job_load(.olceklab$jobs[[lid]]$dir)
  sm <- sim_summary(ld$spec, ld$reps)
  for (k in seq_along(sm$cells)) {
    expect_identical(vapply(rec$results$cells[[k]]$invariance, `[[`, 0, "reject_chisq"), sm$cells[[k]]$invariance$reject_chisq, info = k)
    expect_identical(vapply(rec$results$cells[[k]]$params, `[[`, 0, "bias"), sm$cells[[k]]$params$bias, info = k)
  }
  expect_match(rec$tables[[1]]$note_tr, "SİMÜLASYON", fixed = TRUE)
  z <- api(sprintf("/simulations/%s/package", id))
  expect_identical(httr2::resp_status(z), 200L)
  expect_identical(httr2::resp_header(z, "Content-Type"), "application/zip")
  expect_identical(utils::head(httr2::resp_body_raw(z), 2), as.raw(c(0x50, 0x4b)))
})

test_that("geçersiz tanım 422; bilinmeyen iş 404", {
  bad <- sim_body; bad$population$loadings$y1 <- 2
  r <- api("/simulations", "POST", json = bad)
  expect_identical(httr2::resp_status(r), 422L)
  expect_identical(body_json(r)$error$code, "invalid_population")
  expect_identical(httr2::resp_status(api("/jobs/yok")), 404L)
})

test_that("ikili yanıtlı uç noktalarda hata yine JSON gövdesiyle döner", {
  r <- api("/simulations/yok/package")
  expect_identical(httr2::resp_status(r), 404L)
  expect_identical(body_json(r)$error$code, "job_not_found")
})
