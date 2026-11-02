# SPEC §8'deki API yüzeyi. Faz 4'te M1–M9, iş sistemi, /models/preview, /health, /versions ve /analyses/<id>/script çalışır;
# diğerleri, ait oldukları faz gelene kadar 501 + standart hata biçimi döndürür.

planned_endpoints <- data.frame(
  method = "POST", path = "/reports/docx", module = "M10", phase = 5,
  stringsAsFactors = FALSE
)

register_planned_endpoints <- function(pr) {
  for (i in seq_len(nrow(planned_endpoints))) {
    ep <- planned_endpoints[i, ]
    handler <- not_implemented_handler(ep$module, ep$phase)
    pr <- plumber::pr_handle(pr, ep$method, ep$path, handler)
  }
  pr
}

health_payload <- function() {
  list(
    status = "ok",
    service = "engine",
    time = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
}
