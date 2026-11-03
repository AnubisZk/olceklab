# Uçtan uca: gerçek plumber sunucusu (analizler ana süreçte, ENGINE_WORKERS = 0).

eng <- start_engine(workers = 0L)
call_api <- eng$api

test_that("GET /health 200 ve status = ok döndürür", {
  r <- call_api("/health")
  expect_identical(httr2::resp_status(r), 200L)
  b <- body_json(r)
  expect_identical(b$status, "ok")
  expect_identical(b$service, "engine")
  expect_match(b$time, "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$")
})

test_that("GET /versions sunucunun gerçek R ve paket sürümlerini döndürür", {
  b <- body_json(call_api("/versions"))
  expect_identical(b$R, paste(R.version$major, R.version$minor, sep = "."))
  expect_identical(b$packages$lavaan, as.character(utils::packageVersion("lavaan")))
  expect_identical(b$packages$psych, as.character(utils::packageVersion("psych")))
  expect_length(b$missing, 0L)
})

test_that("Faz 5 itibarıyla 501 dönen uç nokta kalmadı; rapor uç noktası boş istekte standart hata döndürür", {
  expect_identical(nrow(planned_endpoints), 0L)
  r <- call_api("/reports/docx", method = "POST")
  expect_identical(httr2::resp_status(r), 422L)
  b <- body_json(r)
  expect_identical(b$error$code, "report_empty")
  expect_null(b$results)
  r <- call_api("/jobs/abc123")
  expect_identical(httr2::resp_status(r), 404L)
  expect_identical(body_json(r)$error$code, "job_not_found")
})

test_that("bilinmeyen yol 404 ve standart hata döndürür", {
  r <- call_api("/boyle-bir-yol-yok")
  expect_identical(httr2::resp_status(r), 404L)
  expect_identical(body_json(r)$error$code, "not_found")
})

test_that("CORS yalnızca izin verilen kaynağa açık", {
  ok <- call_api("/health", origin = "http://localhost:5173")
  expect_identical(httr2::resp_header(ok, "Access-Control-Allow-Origin"), "http://localhost:5173")
  bad <- call_api("/health", origin = "http://evil.example")
  expect_identical(httr2::resp_status(bad), 403L)
  expect_identical(body_json(bad)$error$code, "origin_not_allowed")
  expect_null(httr2::resp_header(bad, "Access-Control-Allow-Origin"))
  pre <- call_api("/analyses/efa", method = "OPTIONS", origin = "http://localhost:5173")
  expect_identical(httr2::resp_status(pre), 204L)
  denied_pre <- call_api("/analyses/efa", method = "OPTIONS", origin = "http://evil.example")
  expect_identical(httr2::resp_status(denied_pre), 403L)
  # Basit POST istekleri ön kontrol yapmadan gönderilebilir; işleme alınmamalıdır.
  denied_post <- call_api("/datasets/examples/holzinger", method = "POST", origin = "http://evil.example")
  expect_identical(httr2::resp_status(denied_post), 403L)
  expect_identical(body_json(denied_post)$error$code, "origin_not_allowed")
})

test_that("hata durumları doğru HTTP kodlarıyla döner", {
  expect_identical(httr2::resp_status(call_api("/datasets/yok/roles", "POST", json = list(roles = list()))), 404L)
  expect_identical(body_json(call_api("/datasets", "POST", raw = charToRaw("a,b\n1,2")))$error$code, "missing_filename")
  ex <- body_json(call_api("/datasets/examples/holzinger", "POST"))
  r <- call_api("/analyses/item", "POST", json = list(dataset_id = ex$dataset_id))
  expect_identical(httr2::resp_status(r), 409L)
  expect_identical(body_json(r)$error$code, "not_cleaned")
  r <- call_api(sprintf("/datasets/%s/clean", ex$dataset_id), "POST", json = list(rules = list()))
  expect_identical(body_json(r)$error$code, "roles_missing")
})
