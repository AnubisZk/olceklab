test_that("sayılar JSON'a tam duyarlıkla yazılır (sessiz yuvarlama yok)", {
  values <- list(a = pi, b = 1.234567890123456e-12, c = -0.000123456789012345, d = 281.168,
                 e = 0.1, f = 1 / 3, g = 1e300, h = .Machine$double.xmin)
  back <- jsonlite::fromJSON(to_json(values))
  for (nm in names(values)) expect_identical(back[[nm]], values[[nm]])
})

test_that("jsonlite'ın varsayılanı ve digits = NA yuvarlar; bu yüzden özel ayar gerekir", {
  default_out <- jsonlite::fromJSON(jsonlite::toJSON(list(x = pi), auto_unbox = TRUE))$x
  expect_false(identical(default_out, pi))
  na_out <- jsonlite::fromJSON(jsonlite::toJSON(list(x = pi), auto_unbox = TRUE, digits = NA))$x
  expect_false(identical(na_out, pi))
})

test_that("NA ve NULL JSON null olur", {
  out <- as.character(to_json(list(a = NA, b = NULL)))
  expect_match(out, '"a":null', fixed = TRUE)
  expect_match(out, '"b":null', fixed = TRUE)
})

test_that("plumber serileştiricisi aynı seçenekleri kullanır", {
  ser <- serializer_engine_json()
  expect_true(is.function(ser))
  res <- plumber:::PlumberResponse$new()
  out <- ser(list(x = pi), list(), res, function(e) stop(e))
  expect_identical(jsonlite::fromJSON(out$body)$x, pi)
})

test_that("tek elemanlı diziler JSON'da dizi kalır (I() ile işaretli alanlar)", {
  out <- jsonlite::fromJSON(to_json(list(a = I("x"), b = I(1), c = I(character()))), simplifyVector = FALSE)
  expect_identical(out$a, list("x"))
  expect_identical(out$b, list(1L))
  expect_identical(out$c, list())
  v <- jsonlite::fromJSON(to_json(engine_versions(c("lavaan", "olceklabYokBoylePaket"))), simplifyVector = FALSE)
  expect_identical(v$missing, list("olceklabYokBoylePaket"))
})
