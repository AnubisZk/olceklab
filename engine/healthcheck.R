# Docker HEALTHCHECK: /health "ok" dönmezse 1 ile çıkar.
url <- sprintf("http://127.0.0.1:%s/health", Sys.getenv("PORT", "8000"))
ok <- tryCatch({
  body <- paste(readLines(url, warn = FALSE), collapse = "")
  identical(jsonlite::fromJSON(body)$status, "ok")
}, error = function(e) FALSE)
quit(status = if (isTRUE(ok)) 0L else 1L)
