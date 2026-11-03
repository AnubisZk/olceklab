# Motor kodunu yükler. test_dir() çalışma dizinini tests/testthat yapar.
engine_dir <- normalizePath(file.path("..", ".."))
for (f in sort(list.files(file.path(engine_dir, "R"), pattern = "[.]R$",
                          full.names = TRUE, recursive = TRUE))) {
  source(f, local = FALSE, encoding = "UTF-8")
}

# Örnek veri setinden temizlenmiş, oturumdakiyle aynı yapıda bir veri seti kurar.
example_ds <- function(name, items = NULL, rules = list()) {
  v <- load_example(name)
  ds <- list(id = paste0("test-", name), data = v$data, hash = v$hash, filename = v$filename,
             source = list(type = "example", name = name), suggested_config = v$suggested_config)
  body <- v$suggested_config
  if (!is.null(items)) {
    drop <- setdiff(names(body$roles)[unlist(body$roles) == "item"], items)
    body$roles[drop] <- "ignore"
    body$items <- body$items[items]
  }
  ds$config <- build_config(ds$data, body)
  out <- analysis_clean(ds$data, ds$config, rules, ds$hash)
  ds$clean <- out$clean
  ds$clean_rules <- rules
  ds$clean_record <- out$record
  ds
}

# Gerçek plumber sunucusunu ayrı bir süreçte başlatır; testin sonunda kapatır.
start_engine <- function(workers = 0L, env = teardown_env()) {
  port <- httpuv::randomPort()
  base <- sprintf("http://127.0.0.1:%d", port)
  server <- callr::r_bg(
    function(dir, port, workers) {
      Sys.setenv(OLCEKLAB_ENGINE_DIR = dir, PORT = port, HOST = "127.0.0.1",
                 ALLOWED_ORIGINS = "http://localhost:5173", ENGINE_WORKERS = workers)
      source(file.path(dir, "run.R"))
    },
    args = list(dir = engine_dir, port = port, workers = workers), supervise = TRUE,
    env = c(callr::rcmd_safe_env(), LANG = "C.UTF-8", LC_ALL = "C.UTF-8")
  )
  withr::defer(server$kill(), envir = env)
  api <- function(path, method = "GET", origin = NULL, json = NULL, raw = NULL, query = list(), timeout = 120) {
    req <- httr2::request(paste0(base, path)) |>
      httr2::req_method(method) |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_timeout(timeout)
    if (length(query)) req <- httr2::req_url_query(req, !!!query)
    if (!is.null(origin)) req <- httr2::req_headers(req, Origin = origin)
    if (!is.null(json)) req <- httr2::req_body_json(req, json, auto_unbox = TRUE, digits = NA)
    if (!is.null(raw)) req <- httr2::req_body_raw(req, raw, type = "application/octet-stream")
    httr2::req_perform(req)
  }
  start <- Sys.time()
  repeat {
    ok <- tryCatch(httr2::resp_status(api("/health", timeout = 2)) == 200L, error = function(e) FALSE)
    if (ok) break
    if (!server$is_alive()) stop("Sunucu başlamadan kapandı:\n", paste(server$read_all_error_lines(), collapse = "\n"))
    if (difftime(Sys.time(), start, units = "secs") > 90) stop("Sunucu 90 sn içinde yanıt vermedi")
    Sys.sleep(0.25)
  }
  list(base = base, api = api, server = server)
}

body_json <- function(resp) jsonlite::fromJSON(httr2::resp_body_string(resp), simplifyVector = FALSE)

# Ayrı bir R sürecinde betiği çalıştırıp `sonuc` nesnesini döndürür.
run_script <- function(script) {
  path <- tempfile(fileext = ".R")
  on.exit(unlink(path), add = TRUE)
  writeLines(script, path, useBytes = TRUE)
  callr::r(function(p) { e <- new.env(); utils::capture.output(sys.source(p, envir = e, keep.source = FALSE)); e$sonuc },
           args = list(p = path), env = c(callr::rcmd_safe_env(), LANG = "C.UTF-8", LC_ALL = "C.UTF-8"))
}
