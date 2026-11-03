fake_res <- function() {
  env <- new.env()
  env$status <- 200L
  env
}
fake_req <- function(method = "POST", path = "/analyses/efa") {
  list(REQUEST_METHOD = method, PATH_INFO = path)
}

test_that("api_stop durum kodlu ve sınıflı hata üretir; işleyici onu kullanır", {
  e <- tryCatch(api_stop("x_code", "ileti", 422L, "ayrıntı"), error = function(e) e)
  expect_s3_class(e, "api_error")
  expect_identical(e$status, 422L)
  res <- fake_res()
  body <- engine_error_handler(fake_req(), res, e)
  expect_identical(res$status, 422L)
  expect_identical(body$error$code, "x_code")
  expect_identical(body$error$detail, "ayrıntı")
})

test_that("hata gövdesi şartnamedeki biçimdedir (SPEC §8)", {
  body <- api_error_body("x_code", "Türkçe ileti", "R ayrıntısı")
  expect_named(body, "error")
  expect_named(body$error, c("code", "message_tr", "detail"))
  expect_identical(body$error$code, "x_code")
})

test_that("boş kod ya da ileti kabul edilmez", {
  expect_error(api_error_body("", "ileti"))
  expect_error(api_error_body("kod", ""))
  expect_error(api_error_body(c("a", "b"), "ileti"))
})

test_that("uygulanmamış uç nokta 501 ve modül/faz bilgisi döndürür, sayı döndürmez", {
  res <- fake_res()
  body <- not_implemented_handler("M5", 2)(fake_req(), res)
  expect_identical(res$status, 501L)
  expect_identical(body$error$code, "not_implemented")
  expect_match(body$error$message_tr, "M5", fixed = TRUE)
  expect_match(body$error$message_tr, "Faz 2", fixed = TRUE)
  expect_null(body$results)
})

test_that("404 ve 500 işleyicileri standart biçimi kullanır", {
  res <- fake_res()
  b404 <- engine_404_handler(fake_req("GET", "/yok"), res)
  expect_identical(res$status, 404L)
  expect_identical(b404$error$code, "not_found")

  res <- fake_res()
  b500 <- engine_error_handler(fake_req(), res, simpleError("deneme hatası"))
  expect_identical(res$status, 500L)
  expect_identical(b500$error$detail, "deneme hatası")
})

test_that("Faz 5 itibarıyla uygulanmamış (501) uç nokta yok; kayıt işlevi boş listeyle çalışır", {
  expect_equal(nrow(planned_endpoints), 0L)
  expect_identical(names(planned_endpoints), c("method", "path", "module", "phase"))
})
