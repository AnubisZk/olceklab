# Uçtan uca: gerçek plumber sunucusunu ayrı bir süreçte başlatıp HTTP ile sınar.

port <- httpuv::randomPort()
base <- sprintf("http://127.0.0.1:%d", port)
server <- callr::r_bg(
  function(dir, port) {
    Sys.setenv(OLCEKLAB_ENGINE_DIR = dir, PORT = port, HOST = "127.0.0.1",
               ALLOWED_ORIGINS = "http://localhost:5173")
    source(file.path(dir, "run.R"))
  },
  args = list(dir = engine_dir, port = port),
  supervise = TRUE
)
withr::defer(server$kill(), teardown_env())

call_api <- function(path, method = "GET", origin = NULL) {
  req <- httr2::request(paste0(base, path)) |>
    httr2::req_method(method) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_timeout(10)
  if (!is.null(origin)) req <- httr2::req_headers(req, Origin = origin)
  httr2::req_perform(req)
}

wait_for_server <- function(timeout = 60) {
  start <- Sys.time()
  repeat {
    ok <- tryCatch(httr2::resp_status(call_api("/health")) == 200L, error = function(e) FALSE)
    if (ok) return(TRUE)
    if (!server$is_alive()) stop("Sunucu başlamadan kapandı:\n", paste(server$read_all_error_lines(), collapse = "\n"))
    if (difftime(Sys.time(), start, units = "secs") > timeout) stop("Sunucu ", timeout, " sn içinde yanıt vermedi")
    Sys.sleep(0.25)
  }
}
wait_for_server()

body_json <- function(resp) jsonlite::fromJSON(httr2::resp_body_string(resp), simplifyVector = FALSE)

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

test_that("henüz uygulanmamış analiz uç noktaları 501 ve standart hata döndürür", {
  for (path in c("/analyses/factor-number", "/analyses/cfa", "/simulations")) {
    r <- call_api(path, method = "POST")
    expect_identical(httr2::resp_status(r), 501L, info = path)
    b <- body_json(r)
    expect_identical(b$error$code, "not_implemented", info = path)
    expect_null(b$results)
  }
  r <- call_api("/jobs/abc123")
  expect_identical(httr2::resp_status(r), 501L)
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
  expect_null(httr2::resp_header(bad, "Access-Control-Allow-Origin"))
  pre <- call_api("/analyses/efa", method = "OPTIONS", origin = "http://localhost:5173")
  expect_identical(httr2::resp_status(pre), 204L)
})
