# M9 yazılım kabulü (SPEC §7 M9 Kabul; SPEC_REVIEW MC-8): sürekli-normal veri ve ML ile kurulmuş kontrol (değişmez)
# senaryosunda Δχ² I. tip hata oranı ,05 civarındadır (1000 tekrarla ,03–,07). Parçalar iki mirai işçisinde paralel
# çalışır; ilk parçanın sıralı çalıştırmayla birebir aynı olduğu da denetlenir (paralellik sonucu değiştirmez).

test_that("kontrol senaryosu, sürekli-normal veri, ML: Δχ² I. tip hata oranı 1000 tekrarda ,03–,07 aralığında", {
  body <- list(population = list(
    factors = list(list(name = "F1", items = c("y1", "y2", "y3")), list(name = "F2", items = c("y4", "y5", "y6"))),
    loadings = list(y1 = .7, y2 = .6, y3 = .65, y4 = .7, y5 = .6, y6 = .7), factor_cor = list(list(a = "F1", b = "F2", r = .4)),
    data_type = "continuous", groups = list(list(name = "A"), list(name = "B"))),
    conditions = list(N = 600L), estimators = "ML", reps = 1000L, chunk_size = 125L, seed = 20261030L,
    analyses = list(cfa = FALSE, reliability = FALSE, invariance = TRUE))
  id <- sim_job_create(body)
  j <- .olceklab$jobs[[id]]
  mirai::daemons(2)
  withr::defer(mirai::daemons(0))
  files <- engine_r_files(engine_dir)
  mirai::everywhere({ for (f in files) source(f, local = FALSE, encoding = "UTF-8") }, files = files)
  res <- mirai::mirai_map(j$chunks, function(ch, dir) sim_run_chunk(dir, ch), .args = list(dir = j$dir))[]
  expect_true(all(vapply(res, function(r) is.list(r) && !is.null(r$file), logical(1))))
  first <- readRDS(sim_chunk_file(j$dir, j$chunks[[1]]))
  d2 <- tempfile("sira-"); dir.create(d2); file.copy(file.path(j$dir, "spec.rds"), d2)
  sim_run_chunk(d2, j$chunks[[1]])
  expect_identical(readRDS(sim_chunk_file(d2, j$chunks[[1]])), first)
  ld <- sim_job_load(j$dir)
  sm <- sim_summary(ld$spec, ld$reps)
  inv <- sm$cells[[1]]$invariance
  for (st in c("metric", "scalar")) {
    r <- inv[inv$step == st, ]
    expect_identical(r$n, 1000L, info = st)
    expect_gte(r$reject_chisq, 0.03); expect_lte(r$reject_chisq, 0.07)
    cat(sprintf("\n  %s: Δχ² I. tip hata = %.3f (MCSE %.4f, geçerli R = %d)", st, r$reject_chisq, r$mcse_chisq, r$n))
  }
  expect_identical(sm$cells[[1]]$invariance_status$ok, 1000)
})
