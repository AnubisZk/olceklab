test_that("varsayılan CORS kaynakları hem localhost hem 127.0.0.1 içerir", {
  withr::local_envvar(ALLOWED_ORIGINS = NA)
  expect_setequal(allowed_origins(), c("http://localhost:5173", "http://127.0.0.1:5173"))
})

test_that("ALLOWED_ORIGINS virgülle ayrılır ve boşluklar kırpılır", {
  withr::local_envvar(ALLOWED_ORIGINS = "https://a.example , https://b.example")
  expect_identical(allowed_origins(), c("https://a.example", "https://b.example"))
})
