# M9 — Monte Carlo simülasyonu: popülasyon, veri üretimi, gerçek değerler, iş sistemi (kes-devam), çevrim içi sınırlar,
# bağımsız paket. Beklenen değerler kuramsal momentlerden ya da paketlerin kendi fonksiyonlarından üretilir.

pop_body <- function(type = "ordinal", groups = TRUE, dif = TRUE) {
  b <- list(factors = list(list(name = "F1", items = c("y1", "y2", "y3")), list(name = "F2", items = c("y4", "y5", "y6"))),
            loadings = list(y1 = .7, y2 = .6, y3 = .65, y4 = .7, y5 = .6, y6 = .7),
            factor_cor = list(list(a = "F1", b = "F2", r = .4)), data_type = type)
  if (type == "ordinal") b$category_props <- c(.1, .2, .4, .2, .1)
  if (groups) b$groups <- list(list(name = "A"), list(name = "B", latent_means = list(F1 = 0.3)))
  if (groups && dif) b$dif <- list(list(name = "DIF", group = "B", effects = list(list(item = "y1", type = if (type == "ordinal") "threshold" else "intercept", size = 0.5))))
  b
}

test_that("popülasyon doğrulanır: eşikler kategori oranlarından Φ⁻¹ ile; Θ = 1 − diag(ΛΨΛ′)", {
  pop <- normalize_population(pop_body())
  expect_identical(pop$tau$y1, stats::qnorm(cumsum(c(.1, .2, .4, .2, .1))[-5]))
  expect_equal(unname(pop$theta[["y1"]]), 1 - .7^2, tolerance = 1e-15)
  expect_identical(vapply(pop$dif, `[[`, "", "name"), c("Değişmez (kontrol)", "DIF"))
  code <- function(b) tryCatch({ normalize_population(b); "ok" }, error = function(e) e$code)
  b <- pop_body(); b$loadings$y1 <- 1.2; expect_identical(code(b), "invalid_population")
  b <- pop_body(); b$category_props <- c(.5, .5); expect_identical(code(b), "invalid_population")  # ikili madde
  b <- pop_body(); b$factor_cor[[1]]$r <- 1; expect_identical(code(b), "invalid_population")
  b <- pop_body("continuous"); b$dif[[1]]$effects[[1]]$type <- "threshold"; expect_identical(code(b), "invalid_population")
})

test_that("veri üretimi: aynı tohum aynı veri; büyük örneklemde kuramsal momentler ve kategori oranları", {
  pop <- normalize_population(pop_body("continuous", groups = FALSE))
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(1); a <- sim_generate(pop, 300, 1, pop$dif[[1]])
  set.seed(1); b <- sim_generate(pop, 300, 1, pop$dif[[1]])
  expect_identical(a, b)
  set.seed(2); big <- sim_generate(pop, 200000, 1, pop$dif[[1]])
  S <- pop$Lambda %*% pop$Psi %*% t(pop$Lambda); diag(S) <- 1
  expect_lt(max(abs(stats::cov(big[, pop$items]) - S)), 0.01)  # MC hatası ≈ 1/√N ≈ ,002
  po <- normalize_population(pop_body("ordinal", groups = FALSE))
  set.seed(3); bo <- sim_generate(po, 200000, 1, po$dif[[1]])
  expect_lt(max(abs(as.numeric(table(factor(bo$y1, 1:5))) / 2e5 - c(.1, .2, .4, .2, .1))), 0.005)
})

test_that("grup oranları ve DIF: odak grupta eşik kayması ortalamayı düşürür; gizil ortalama farkı uygulanır", {
  pop <- normalize_population(pop_body())
  expect_identical(sim_group_sizes(301, c(.7, .3)), c(211L, 90L))
  RNGkind("Mersenne-Twister", "Inversion", "Rejection"); set.seed(5)
  d0 <- sim_generate(pop, 100000, c(.5, .5), pop$dif[[1]]); set.seed(5)
  d1 <- sim_generate(pop, 100000, c(.5, .5), pop$dif[[2]])
  expect_identical(d0[d0$grp == "A", ], d1[d1$grp == "A", ])  # referans grup aynı
  expect_lt(mean(d1$y1[d1$grp == "B"]), mean(d0$y1[d0$grp == "B"]))
  expect_identical(d0$y2, d1$y2)  # DIF yalnızca y1'de
  expect_gt(mean(d0$y2[d0$grp == "B"]), mean(d0$y2[d0$grp == "A"]))  # F1 ortalaması +,3
})

test_that("kesikli puanların popülasyon kovaryansı mvtnorm ile ve büyük örneklemle tutarlı (sözde-gerçek değerin temeli)", {
  pop <- normalize_population(pop_body("ordinal", groups = FALSE))
  S <- sim_pop_ordinal_moments(pop)
  tau <- c(-Inf, pop$tau$y1, Inf); r <- .7 * .6
  P <- outer(1:5, 1:5, Vectorize(function(a, b) mvtnorm::pmvnorm(lower = c(tau[a], tau[b]), upper = c(tau[a + 1], tau[b + 1]), corr = matrix(c(1, r, r, 1), 2))[1]))
  m <- sum(1:5 * c(.1, .2, .4, .2, .1))
  expect_equal(S["y1", "y2"], sum(outer(1:5, 1:5) * P) - m^2, tolerance = 1e-6)
  RNGkind("Mersenne-Twister", "Inversion", "Rejection"); set.seed(7)
  big <- sim_generate(pop, 300000, 1, pop$dif[[1]])
  expect_lt(max(abs(stats::cov(big[, pop$items]) - S)), 0.01)
})

test_that("gerçek değerler: sürekli veride üretim parametresi; sıralı + ML'de sözde-gerçek; WLSMV'de eşikler", {
  pc <- normalize_population(pop_body("continuous", groups = FALSE))
  tc <- sim_true_values(pc, "ML")$ML
  expect_identical(tc$params$true[tc$params$name == "F1=~y1"], 0.7)
  expect_identical(unique(tc$params$source), "generating")
  fit <- lavaan::cfa(sim_model_syntax(pc), sample.cov = {S <- pc$Lambda %*% pc$Psi %*% t(pc$Lambda); diag(S) <- 1; S}, sample.nobs = 1e6, std.lv = TRUE)
  ss <- lavaan::standardizedSolution(fit)
  expect_equal(ss$est.std[ss$op == "=~" & ss$rhs == "y1"], 0.7, tolerance = 1e-5)  # doğru modelde sözde-gerçek = üretim
  po <- normalize_population(pop_body("ordinal", groups = FALSE))
  to <- sim_true_values(po, c("ML", "WLSMV"))
  expect_identical(unique(to$ML$params$source), "pseudo_true")
  expect_lt(to$ML$params$true[to$ML$params$name == "F1=~y1"], 0.7)  # kesikleştirme yükleri azaltır
  expect_identical(to$WLSMV$params$true[to$WLSMV$params$name == "y1|t1"], po$tau$y1[1])
  expect_true(all(is.na(to$WLSMV$reliability$omega)))
})

# Hızlı olsun diye iş testleri ML ile; WLSMV yolu ayrı ve küçük bir testte sınanır.
sim_spec <- function(reps = 4, chunk = 2, estimators = "ML", ...) {
  c(list(population = pop_body(), conditions = list(N = c(200, 400)), estimators = estimators, reps = reps, chunk_size = chunk, seed = 123), list(...))
}

test_that("aynı tohum ve sürümle iki çalıştırma birebir aynı sonucu verir", {
  a <- sim_job_create(sim_spec()); sim_job_run_sync(a)
  b <- sim_job_create(sim_spec()); sim_job_run_sync(b)
  la <- sim_job_load(.olceklab$jobs[[a]]$dir); lb <- sim_job_load(.olceklab$jobs[[b]]$dir)
  expect_identical(la$reps, lb$reps)
  expect_identical(sim_summary(la$spec, la$reps)$cells, sim_summary(lb$spec, lb$reps)$cells)
  expect_identical(la$reps[[1]]$seed, 123L + 10000L * 1L + 1L)
})

test_that("kesilip yeniden başlatılan iş, kesintisiz işle birebir aynı sonucu verir", {
  full <- sim_job_create(sim_spec()); sim_job_run_sync(full)
  cut <- sim_job_create(sim_spec())
  st <- sim_job_run_sync(cut, max_chunks = 3)
  expect_identical(st$status, "cancelled")
  expect_identical(st$chunks_done, 3L)
  # Motor yeniden başlamış gibi: bellekteki kayıt silinir, yalnızca diskteki parçalar kalır
  dir <- .olceklab$jobs[[cut]]$dir
  .olceklab$jobs[[cut]]$status <- "cancelled"
  st2 <- sim_job_run_sync(cut)
  expect_identical(st2$status, "done")
  lf <- sim_job_load(.olceklab$jobs[[full]]$dir); lc <- sim_job_load(dir)
  expect_identical(lc$reps, lf$reps)
  expect_identical(sim_summary(lc$spec, lc$reps), sim_summary(lf$spec, lf$reps))
})

test_that("ortak rastgele sayılar: aynı tekrar bütün kestiricilerde aynı veriyle analiz edilir (MC-6)", {
  sp <- normalize_sim_spec(sim_spec())
  cond <- sim_condition(sp, 1L)
  r1 <- sim_replicate(sp$pop, cond, 1L, sp$seed, "ML", sp$analyses, sp$criteria)
  r2 <- sim_replicate(sp$pop, cond, 1L, sp$seed, c("ML", "WLSMV"), sp$analyses, sp$criteria)
  expect_identical(r1$est$ML, r2$est$ML)
  # WLSMV yolu: Wu–Estabrook değişmezlik zinciri ve eşikler
  expect_identical(r2$est$WLSMV$invariance$status, "ok")
  expect_identical(r2$est$WLSMV$invariance$steps$step, c("metric", "scalar"))
  expect_true(any(r2$est$WLSMV$cfa$params$type == "threshold"))
})

test_that("hata türleri ayrı sayılır; özet tabloları SİMÜLASYON etiketini taşır", {
  id <- sim_job_create(sim_spec(analyses = list(pa = list(enabled = TRUE, n_iter = 30))))
  sim_job_run_sync(id)
  rec <- sim_results_for(.olceklab$jobs[[id]]$dir, id)
  expect_identical(rec$module, "simulation")
  for (t in rec$tables) expect_match(t$note_tr, "SİMÜLASYON — sentetik veri", fixed = TRUE)
  t1 <- rec$tables[[1]]
  expect_identical(names(rec$results$cells[[1]]$cfa_status), c("ok", "nonconverged", "improper", "empty_category", "other"))
  expect_identical(t1$rows$R, rep(4L, 4))
  expect_identical(vapply(rec$figures, `[[`, "", "type"), c("power_curve", "bias_heatmap"))
  expect_false(is.null(rec$results$cells[[1]]$pa))
})

test_that("örneklem önerisi: ölçütlerin o N'de ve daha büyük bütün N'lerde sağlandığı en küçük N (MC-11)", {
  mk <- function(adm) list(admissible_rate = adm, params = NULL, invariance = NULL)
  crit <- list(admissible = .95, param_bias = .1, se_bias = .1, coverage = c(.91, .98), power = .8)
  expect_identical(sim_recommend(list(mk(.9), mk(.96), mk(.97)), c(100L, 200L, 300L), crit, NULL), 200L)
  expect_identical(sim_recommend(list(mk(.96), mk(.9), mk(.97)), c(100L, 200L, 300L), crit, NULL), 300L)
  expect_identical(sim_recommend(list(mk(.9), mk(.9)), c(100L, 200L), crit, NULL), NA_integer_)
})

test_that("çevrim içi mod sınırları: tekrar × koşul sınırı aşılırsa paket önerisiyle reddedilir", {
  withr::local_envvar(ONLINE_LIMITS = "true", ONLINE_MAX_REPLICATIONS_X_CONDITIONS = "100")
  e <- tryCatch(normalize_sim_spec(sim_spec(reps = 60)), error = function(e) e)
  expect_identical(e$code, "online_limit")
  expect_match(conditionMessage(e), "Bağımsız R paketini", fixed = TRUE)
  expect_silent(normalize_sim_spec(sim_spec(reps = 25)))
  expect_identical(online_limits()$max_workers, 2L)
})

test_that("grup oranları R'de normalleştirilir: 70/30 ile ,7/,3 aynı tanımdır; sıfır ya da eksik oran reddedilir", {
  with_ratios <- function(r) { b <- sim_spec(); b$conditions$ratios <- r; b }
  a <- normalize_sim_spec(with_ratios(list(c(70, 30))))
  b <- normalize_sim_spec(with_ratios(list(c(.7, .3))))
  expect_equal(a$ratios, b$ratios, tolerance = 1e-15)
  expect_identical(sim_ratio_label(a, 1L), "70/30")
  e <- tryCatch(normalize_sim_spec(with_ratios(list(c(1, 0)))), error = function(e) e)
  expect_identical(e$code, "invalid_simulation")
  e2 <- tryCatch(normalize_sim_spec(with_ratios(list(1))), error = function(e) e)
  expect_identical(e2$code, "invalid_simulation")
})

test_that("T4 ölçü türü: adımın eklediği kısıt DIF'li parametreyi kapsıyorsa güç; önceki adımda DIF ya da ML ile eşik DIF'i karışık", {
  ctl <- list(control = TRUE)
  ic <- list(control = FALSE, effects = list(list(item = "y1", type = "intercept", size = .4)))
  ld <- list(control = FALSE, effects = list(list(item = "y1", type = "loading", size = .2)))
  th <- list(control = FALSE, effects = list(list(item = "y1", type = "threshold", size = .5)))
  k <- function(sc, est, dt) vapply(c("metric", "scalar"), function(st) sim_step_kind(sc, st, est, dt), "")
  expect_identical(k(ctl, "ML", "continuous"), c(metric = "type_i", scalar = "type_i"))
  expect_identical(k(ic, "ML", "continuous"), c(metric = "type_i", scalar = "power"))
  expect_identical(k(ld, "MLR", "continuous"), c(metric = "power", scalar = "mixed"))
  expect_identical(k(th, "ML", "ordinal"), c(metric = "mixed", scalar = "power"))
  expect_identical(k(th, "WLSMV", "ordinal"), c(metric = "power", scalar = "mixed"))
  sp <- normalize_sim_spec(sim_spec(estimators = c("ML", "WLSMV")))
  expect_identical(sp$recommend$power_step, "auto")
  expect_null(sim_power_target(sp, 1L, "ML"))                       # kontrol senaryosu
  expect_identical(sim_power_target(sp, 2L, "ML")$step, "scalar")   # sıralı veri, eşik DIF'i, ML
  expect_identical(sim_power_target(sp, 2L, "WLSMV")$step, "metric")
  sp2 <- normalize_sim_spec(c(sim_spec(), list(recommend = list(power_step = "metric"))))
  expect_identical(sim_power_target(sp2, 2L, "ML")$step, "metric")  # açık seçim otomatiği ezer
})

test_that("tek gruplu simülasyonun sonuç kaydı kurulur (değişmezlik tablosu yok; kısmi ad eşleşmesi hatası olmaz)", {
  body <- list(population = list(factors = list(list(name = "F1", items = c("y1", "y2", "y3"))), loadings = list(y1 = .7, y2 = .6, y3 = .65),
                                 data_type = "continuous"), conditions = list(N = c(100, 200)), estimators = "ML", reps = 2, chunk_size = 2, seed = 9)
  id <- sim_job_create(body); sim_job_run_sync(id)
  rec <- sim_results_for(.olceklab$jobs[[id]]$dir, id)
  ids <- vapply(rec$tables, `[[`, "", "id")
  expect_false("T4" %in% ids)
  expect_true(all(c("T1", "T3", "T5", "T7") %in% ids))
  expect_null(rec$results$cells[[1]][["invariance"]])
})

test_that("DFA'dan popülasyon notları JSON'da her zaman dizidir (tek notta da)", {
  b10 <- example_ds("bfi", items = c(paste0("A", 1:5), paste0("C", 1:5)))
  mod <- list(factors = list(list(name = "A", items = paste0("A", 1:5)), list(name = "C", items = paste0("C", 1:5))))
  rw <- analysis_cfa(b10$clean$data, b10$config, list(model = mod, estimator = "WLSMV"), b10$hash)
  j <- jsonlite::parse_json(as.character(to_json(population_from_cfa(rw, b10$clean$data, b10$config))), simplifyVector = FALSE)
  expect_length(j$notes_tr, 1L)
  expect_true(is.list(j$notes_tr) && is.list(j$notes_en))
})
