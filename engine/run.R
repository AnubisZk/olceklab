# Sunucuyu başlatır. Bağlantı noktası PORT ortam değişkeninden okunur
# (yerel: 8000, Hugging Face Space: 7860). Analiz işçisi sayısı ENGINE_WORKERS
# (varsayılan 2; 0 verilirse analizler ana süreçte çalışır).
engine_dir <- Sys.getenv("OLCEKLAB_ENGINE_DIR", "")
if (!nzchar(engine_dir)) {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- sub("^--file=", "", args[grep("^--file=", args)])
  engine_dir <- if (length(file_arg)) dirname(normalizePath(file_arg)) else getwd()
}

port <- as.integer(Sys.getenv("PORT", "8000"))
host <- Sys.getenv("HOST", "0.0.0.0")

pr <- plumber::plumb(file.path(engine_dir, "plumber.R"))
options(plumber.maxRequestSize = max_upload_bytes() + 65536)
workers_start(Sys.getenv("ENGINE_WORKERS", "2"), engine_dir)
pr$registerHooks(list(exit = function() workers_stop()))
pr$run(host = host, port = port, docs = FALSE, quiet = FALSE)
