# SPEC §8'deki API yüzeyi. Faz 1'de M1–M4, /health, /versions ve /analyses/<id>/script çalışır;
# diğerleri, ait oldukları faz gelene kadar 501 + standart hata biçimi döndürür.

planned_endpoints <- data.frame(
  method = c("POST", "POST", "POST", "POST", "POST", "POST", "POST", "GET",
             "POST", "POST", "GET", "GET", "POST"),
  path = c("/analyses/efa", "/analyses/cfa", "/analyses/cfa/compare", "/analyses/reliability",
           "/analyses/invariance", "/analyses/invariance/score-tests", "/simulations", "/jobs/<id>",
           "/jobs/<id>/cancel", "/jobs/<id>/resume", "/simulations/<id>/results",
           "/simulations/<id>/package", "/reports/docx"),
  module = c("M5", "M6", "M6", "M7", "M8", "M8", "M9", "M9", "M9", "M9", "M9", "M9", "M10"),
  phase = c(2, 2, 2, 2, 3, 3, 4, 4, 4, 4, 4, 4, 5),
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
