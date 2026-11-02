test_that("sürüm bilgisi gerçek R oturumundan gelir", {
  v <- engine_versions()
  expect_identical(v$R, paste(R.version$major, R.version$minor, sep = "."))
  expect_identical(v$packages$lavaan, as.character(utils::packageVersion("lavaan")))
  expect_named(v$rng_kind, c("kind", "normal_kind", "sample_kind"))
})

test_that("bütün çekirdek paketler kurulu", {
  v <- engine_versions()
  expect_length(v$missing, 0L)
})

test_that("kurulu sürümler renv.lock ile birebir aynı (SPEC_REVIEW REP-1)", {
  lock <- file.path(engine_dir, "renv.lock")
  expect_true(file.exists(lock))
  mism <- lockfile_mismatches(lock)
  if (length(mism)) {
    msg <- vapply(names(mism), function(n) sprintf("%s: kilit %s, kurulu %s (%s)",
      n, mism[[n]]$locked, mism[[n]]$installed, mism[[n]]$reason), character(1))
    fail(paste(msg, collapse = "\n"))
  } else {
    succeed()
  }
})

test_that("kurulu olmayan paket uydurulmaz, 'missing' listesine girer", {
  v <- engine_versions(c("lavaan", "olceklabYokBoylePaket"))
  expect_identical(v$missing, "olceklabYokBoylePaket")
  expect_null(v$packages$olceklabYokBoylePaket)
})
