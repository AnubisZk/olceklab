test_that("veri seti belleğe yazılır, okunur ve süre dolunca silinir", {
  id <- dataset_put(list(data = data.frame(a = 1), hash = "h"))
  expect_identical(dataset_get(id)$hash, "h")
  expect_length(session_purge(now = Sys.time()), 0L)
  expired <- session_purge(now = Sys.time() + 61 * 60, ttl_minutes = 60)
  expect_true(id %in% expired)
  e <- tryCatch(dataset_get(id), error = function(e) e)
  expect_identical(e$code, "dataset_not_found")
  expect_identical(e$status, 404L)
})

test_that("son erişim süresi okuma ile yenilenir", {
  id <- dataset_put(list(data = data.frame(a = 1), hash = "h"))
  .olceklab$datasets[[id]]$last_access <- Sys.time() - 50 * 60
  dataset_get(id)
  expect_false(id %in% session_purge(now = Sys.time() + 20 * 60, ttl_minutes = 60))
})

test_that("tohum doğrulaması", {
  expect_identical(tryCatch(with_seeded_rng(1.5, 1), error = function(e) e$code), "invalid_seed")
  expect_identical(with_seeded_rng(1L, stats::runif(1))$value, { RNGkind("Mersenne-Twister", "Inversion", "Rejection"); set.seed(1L); stats::runif(1) })
})
