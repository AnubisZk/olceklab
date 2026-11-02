# Faz 0: analiz paketlerinin bu ortamda yüklenip çalıştığını doğrular.
# Sayısal kabul testleri ilgili fazlarda eklenecek (SPEC §11).

test_that("çekirdek paketlerin ad alanı yüklenir", {
  for (p in engine_core_packages) {
    expect_true(requireNamespace(p, quietly = TRUE), info = p)
  }
})

test_that("lavaan HolzingerSwineford1939 üzerinde gerçekten çalışır ve yakınsar", {
  m <- "visual =~ x1 + x2 + x3\n textual =~ x4 + x5 + x6\n speed =~ x7 + x8 + x9"
  fit <- lavaan::cfa(m, data = lavaan::HolzingerSwineford1939)
  expect_true(lavaan::lavInspect(fit, "converged"))
  expect_true(lavaan::lavInspect(fit, "post.check"))
})
