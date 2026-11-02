# Ortak ölçme modeli: kurucu → lavaan sözdizimi, sözdizimi ayrıştırma ve doğrulama.

hs <- example_ds("holzinger")
items <- hs$config$items$name
m3 <- list(factors = list(list(name = "visual", items = c("x1", "x2", "x3")), list(name = "textual", items = c("x4", "x5", "x6")),
                          list(name = "speed", items = c("x7", "x8", "x9"))))

test_that("kurucudan lavaan sözdizimi üretilir; yapı lavaan ayrıştırıcısıyla aynı", {
  m <- resolve_model(c(m3, list(covariances = list(c("x1", "x4"), c("x4", "x1")))), items)
  expect_identical(m$syntax, "visual =~ x1 + x2 + x3\ntextual =~ x4 + x5 + x6\nspeed =~ x7 + x8 + x9\nx1 ~~ x4")
  pt <- lavaan::lavParseModelString(m$syntax, as.data.frame. = TRUE)
  expect_identical(nrow(pt), 10L)
  expect_identical(as.character(m$observed), items)
  expect_identical(vapply(m$factors, `[[`, "", "name"), c("visual", "textual", "speed"))
  expect_length(m$covariances, 1L)
  expect_identical(m$source, "builder")
})

test_that("sözdizimi girdisi ayrıştırılır; ikinci düzey faktör ve çapraz yük kabul edilir", {
  m <- resolve_model(list(syntax = "v =~ x1 + x2 + x3 + x4\n t =~ x4 + x5 + x6\n s =~ x7 + x8 + x9\n g =~ v + t + s"), items)
  expect_identical(m$source, "syntax")
  expect_identical(as.character(m$first_order), c("v", "t", "s"))
  expect_identical(as.character(m$observed), items)
})

test_that("Türkçe faktör adları kabul edilir", {
  m <- resolve_model(list(factors = list(list(name = "Görsel", items = c("x1", "x2", "x3")), list(name = "Sözel", items = c("x4", "x5", "x6")))), items)
  expect_match(m$syntax, "^Görsel =~ x1 \\+ x2 \\+ x3")
})

test_that("geçersiz modeller açık hata kodlarıyla reddedilir", {
  code <- function(spec, it = items) tryCatch({ resolve_model(spec, it); "ok" }, error = function(e) e$code)
  f <- function(...) list(factors = list(...))
  expect_identical(code(list()), "model_missing")
  expect_identical(code(f(list(name = "a", items = c("x1", "x2")), list(name = "b", items = c("x2", "x3")))), "item_in_two_factors")
  expect_identical(code(f(list(name = "a", items = c("x1", "q9")))), "model_unknown_item")
  expect_identical(code(f(list(name = "a", items = "x1"))), "factor_too_few_items")
  expect_identical(code(f(list(name = "a b", items = c("x1", "x2")))), "factor_name_invalid")
  expect_identical(code(f(list(name = "1a", items = c("x1", "x2")))), "factor_name_invalid")
  expect_identical(code(f(list(name = "x1", items = c("x2", "x3")))), "factor_name_is_item")
  expect_identical(code(f(list(name = "a", items = c("x1", "x2")), list(name = "a", items = c("x3", "x4")))), "factor_name_duplicate")
  expect_identical(code(c(f(list(name = "a", items = c("x1", "x2", "x3"))), list(covariances = list(c("x1", "x9"))))), "covariance_unknown_item")
  expect_identical(code(list(syntax = "a =~ x1 + x2\n x3 ~ a")), "model_has_regression")
  expect_identical(code(list(syntax = "a =~ 1x + x2")), "model_syntax_error")
  expect_identical(code(list(syntax = "a =~ x1 + x2 x3")), "model_syntax_warning")
  expect_identical(code(list(syntax = "x1 ~~ x2")), "model_no_factors")
  expect_identical(code(list(syntax = "a =~ x1 + zz + x2")), "model_unknown_item")
  expect_identical(code(f(list(name = "a", items = c("Madde 1", "x2"))), c("Madde 1", "x2")), "item_name_not_lavaan")
})

test_that("üçten az göstergeli faktör için uyarı verilir (SPEC I-4)", {
  m <- resolve_model(list(factors = list(list(name = "a", items = c("x1", "x2")), list(name = "b", items = c("x3", "x4", "x5")))), items)
  expect_identical(vapply(m$warnings, `[[`, "", "code"), "factor_fewer_than_three")
  expect_match(m$warnings[[1]]$message_tr, "a", fixed = TRUE)
})

test_that("varsayılan model M1'deki alt boyutlardan kurulur", {
  dm <- default_model_from_subscales(hs$config)
  expect_identical(vapply(dm$factors, `[[`, "", "name"), c("visual", "textual", "speed"))
  expect_identical(as.character(dm$factors[[2]]$items), c("x4", "x5", "x6"))
})
