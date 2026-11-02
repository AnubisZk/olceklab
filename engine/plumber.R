# ÖlçekLab R analiz motoru — plumber API giriş noktası (SPEC §3, §8).
# plumb() bu dosyayı okurken çalışma dizini dosyanın klasörüdür.

for (f in sort(list.files("R", pattern = "[.]R$", full.names = TRUE, recursive = TRUE))) {
  source(f, local = FALSE, encoding = "UTF-8")
}

#* @plumber
function(pr) {
  pr |>
    plumber::pr_set_serializer(serializer_engine_json()) |>
    plumber::pr_set_error(engine_error_handler) |>
    plumber::pr_set_404(engine_404_handler) |>
    register_planned_endpoints()
}

#* CORS ve ön kontrol (OPTIONS) istekleri
#* @filter cors
function(req, res) {
  apply_cors(req, res)
  if (identical(req$REQUEST_METHOD, "OPTIONS")) {
    res$status <- 204L
    return(list())
  }
  plumber::forward()
}

#* Sağlık denetimi. Hızlıdır ve ana süreçte çalışır.
#* @get /health
function() {
  health_payload()
}

#* R ve paket sürümleri
#* @get /versions
function() {
  engine_versions()
}
