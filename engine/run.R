# Sunucuyu başlatır. Bağlantı noktası PORT ortam değişkeninden okunur
# (yerel: 8000, Hugging Face Space: 7860).
engine_dir <- Sys.getenv("OLCEKLAB_ENGINE_DIR", "")
if (!nzchar(engine_dir)) {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- sub("^--file=", "", args[grep("^--file=", args)])
  engine_dir <- if (length(file_arg)) dirname(normalizePath(file_arg)) else getwd()
}

port <- as.integer(Sys.getenv("PORT", "8000"))
host <- Sys.getenv("HOST", "0.0.0.0")

pr <- plumber::plumb(file.path(engine_dir, "plumber.R"))
pr$run(host = host, port = port, docs = FALSE, quiet = FALSE)
