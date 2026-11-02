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

#* CORS, ön kontrol (OPTIONS) ve süresi dolan oturumların temizlenmesi
#* @filter cors
function(req, res) {
  apply_cors(req, res)
  if (identical(req$REQUEST_METHOD, "OPTIONS")) {
    res$status <- 204L
    return(list())
  }
  session_purge()
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

#* M1: dosya yükle. Gövde ham dosya baytlarıdır.
#* @post /datasets
#* @parser octet
function(req, res, filename = "") {
  if (!nzchar(filename)) api_stop("missing_filename", "Dosya adı (filename) belirtilmelidir.", 400L)
  run_in_worker(res, "parse_upload", list(raw = req$bodyRaw, filename = filename), then = function(v) {
    id <- dataset_put(list(data = v$data, hash = v$hash, filename = v$filename,
                           source = list(type = "upload", delimiter = v$delimiter)))
    dataset_overview(dataset_get(id))
  })
}

#* M1: örnek veri seti (holzinger, bfi)
#* @post /datasets/examples/<name>
function(name) {
  v <- load_example(name)
  id <- dataset_put(list(data = v$data, hash = v$hash, filename = v$filename,
                         source = list(type = "example", name = name, label = v$source),
                         suggested_config = v$suggested_config))
  dataset_overview(dataset_get(id))
}

#* M1: sütun rolleri ve madde ayarları
#* @post /datasets/<id>/roles
#* @parser json
function(id, req) {
  ds <- dataset_get(id)
  cfg <- build_config(ds$data, req$body)
  ds$config <- cfg
  ds$clean <- NULL
  dataset_update(id, ds)
  list(dataset_id = id, items = cfg$items, group = cfg$group, id_columns = cfg$id_columns)
}

#* M1: temizleme
#* @post /datasets/<id>/clean
#* @parser json
function(id, req, res) {
  ds <- dataset_get(id)
  if (is.null(ds$config)) api_stop("roles_missing", "Önce sütun rollerini kaydedin.", 409L)
  rules <- if (is.list(req$body$rules)) req$body$rules else list()
  run_in_worker(res, "analysis_clean",
                list(data = ds$data, config = ds$config, rules = rules, dataset_hash = ds$hash),
                then = function(v) {
                  ds <- dataset_get(id)
                  ds$clean <- v$clean
                  ds$clean_rules <- rules
                  dataset_update(id, ds)
                  analysis_store(v$record, id)
                  v$record
                })
}

analysis_endpoint <- function(req, res, fun) {
  b <- req$body
  ds <- dataset_get(if (is.null(b$dataset_id)) "" else b$dataset_id)
  if (is.null(ds$clean)) api_stop("not_cleaned", "Önce veri temizleme adımını çalıştırın.", 409L)
  args <- list(data = ds$clean$data, config = ds$config,
               settings = if (is.list(b$settings)) b$settings else list(), dataset_hash = ds$hash)
  if (fun == "analysis_item") args$item_missing <- ds$clean$item_missing
  run_in_worker(res, fun, args, then = function(rec) {
    rec$r_script <- build_r_script(rec$module, ds, rec$settings, rec$seed, rec$results)
    analysis_store(rec, ds$id)
    rec
  })
}

#* M2: madde analizi
#* @post /analyses/item
#* @parser json
function(req, res) analysis_endpoint(req, res, "analysis_item")

#* M3: uygunluk
#* @post /analyses/suitability
#* @parser json
function(req, res) analysis_endpoint(req, res, "analysis_suitability")

#* M4: faktör sayısı
#* @post /analyses/factor-number
#* @parser json
function(req, res) analysis_endpoint(req, res, "analysis_factor_number")

# Faz 2 uç noktalarında JSON basitleştirilmez: iç içe model tanımları (faktör listeleri, model listeleri)
# veri çerçevesine ya da matrise dönüşmesin diye. Motor fonksiyonları liste girdisini bekler.

#* M5: açımlayıcı faktör analizi
#* @post /analyses/efa
#* @parser json list(simplifyVector = FALSE)
function(req, res) analysis_endpoint(req, res, "analysis_efa")

#* M6: doğrulayıcı faktör analizi (tek model)
#* @post /analyses/cfa
#* @parser json list(simplifyVector = FALSE)
function(req, res) analysis_endpoint(req, res, "analysis_cfa")

#* M6: model karşılaştırma
#* @post /analyses/cfa/compare
#* @parser json list(simplifyVector = FALSE)
function(req, res) analysis_endpoint(req, res, "analysis_cfa_compare")

#* M7: güvenirlik ve geçerlik
#* @post /analyses/reliability
#* @parser json list(simplifyVector = FALSE)
function(req, res) analysis_endpoint(req, res, "analysis_reliability")

#* M8: ölçme değişmezliği ve gizil ortalamalar
#* @post /analyses/invariance
#* @parser json list(simplifyVector = FALSE)
function(req, res) analysis_endpoint(req, res, "analysis_invariance")

#* M8: kısmi değişmezlik sihirbazı — skor testleri
#* @post /analyses/invariance/score-tests
#* @parser json list(simplifyVector = FALSE)
function(req, res) analysis_endpoint(req, res, "analysis_invariance_scores")

#* Model kurucu önizlemesi: lavaan sözdizimi ve yapı (analiz yapmaz). Model verilmezse M1 alt boyutlarından varsayılan model.
#* @post /models/preview
#* @parser json list(simplifyVector = FALSE)
function(req) {
  b <- req$body
  ds <- dataset_get(if (is.null(b$dataset_id)) "" else b$dataset_id)
  if (is.null(ds$config)) api_stop("roles_missing", "Önce sütun rollerini kaydedin.", 409L)
  spec <- b$model
  if (is.null(spec)) {
    spec <- default_model_from_subscales(ds$config)
    if (is.null(spec)) api_stop("no_default_model", "Maddelere alt boyut atanmadığı için varsayılan model kurulamadı.", 422L)
  }
  analysis_model_preview(ds$config, spec)
}

#* M12: analizin R betiği
#* @get /analyses/<id>/script
#* @serializer text
function(id) {
  a <- analysis_get(id)
  if (is.null(a$r_script)) api_stop("script_not_available", "Bu analiz için betik yok.", 404L)
  a$r_script
}
