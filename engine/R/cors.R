# CORS: yalnızca ALLOWED_ORIGINS içindeki kaynaklara açık (SPEC §10).

allowed_origins <- function() {
  raw <- Sys.getenv("ALLOWED_ORIGINS", "http://localhost:5173,http://127.0.0.1:5173")
  trimws(strsplit(raw, ",", fixed = TRUE)[[1]])
}

apply_cors <- function(req, res) {
  origin <- req$HTTP_ORIGIN
  if (!is.null(origin) && origin %in% allowed_origins()) {
    res$setHeader("Access-Control-Allow-Origin", origin)
    res$setHeader("Vary", "Origin")
    res$setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    res$setHeader("Access-Control-Allow-Headers", "Content-Type")
  }
  invisible(NULL)
}
