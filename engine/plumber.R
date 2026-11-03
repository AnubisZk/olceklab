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
    # Özgün baytlar yalnızca bellekte tutulur (proje dosyasına kullanıcının onayıyla eklenebilsin diye; M12).
    id <- dataset_put(list(data = v$data, hash = v$hash, filename = v$filename, raw = req$bodyRaw,
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
  ds$requests <- list(roles = request_json(req))
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
                  ds$requests$clean <- request_json(req)
                  dataset_update(id, ds)
                  analysis_store(v$record, id, request = ds$requests$clean)
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
    analysis_store(rec, ds$id, request = request_json(req))
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

#* M9: popülasyon tanımını bir DFA sonucundan kur (yalnızca özet parametreler)
#* @post /simulations/population/from-cfa
#* @parser json list(simplifyVector = FALSE)
function(req) {
  b <- req$body
  a <- analysis_get(if (is.null(b$analysis_id)) "" else b$analysis_id)
  ds <- dataset_get(a$dataset_id)
  shift <- if (is.null(b$shift)) 0 else as.numeric(b$shift)
  if (is.na(shift) || shift < 0 || shift > 0.3) api_stop("invalid_setting", "Duyarlılık kaydırması 0 ile ,30 arasında olmalıdır.", 422L)
  population_from_cfa(a$record, ds$clean$data, ds$config, shift)
}

#* M9: süre tahmini (en büyük N'li koşulda iki tekrar)
#* @post /simulations/estimate
#* @parser json list(simplifyVector = FALSE)
# İşçi sayısı ana süreçte okunur: tahmin işçide ölçülür ama işi ana süreçteki zamanlayıcı dağıtır.
function(req, res) run_in_worker(res, "sim_estimate", list(body = req$body, workers = .olceklab$workers))

#* M9: simülasyon işi başlat → job_id
#* @post /simulations
#* @parser json list(simplifyVector = FALSE)
function(req) {
  id <- sim_job_create(req$body)
  sim_job_schedule(id)
  sim_job_status(id)
}

#* İş durumu: ilerleme ve tahmini kalan süre
#* @get /jobs/<id>
function(id) sim_job_status(id)

#* İşi iptal et (yazılmış parçalar korunur)
#* @post /jobs/<id>/cancel
function(id) sim_job_cancel(id)

#* İşi kaldığı yerden sürdür
#* @post /jobs/<id>/resume
function(id) sim_job_resume(id)

#* Simülasyon sonuçları (iş tamamlanınca)
#* @get /simulations/<id>/results
function(id, res) {
  j <- sim_job_get(id)
  if (!is.null(j$results)) return(j$results)
  st <- sim_job_status(id)
  if (st$status != "done") api_stop("job_not_done", "Simülasyon henüz tamamlanmadı.", 409L)
  run_in_worker(res, "sim_results_for", list(dir = j$dir, job_id = id), then = function(rec) {
    .olceklab$jobs[[id]]$results <- rec
    analysis_store(rec, NA_character_)  # rapora eklenebilsin diye (M10); veri setine bağlı değildir
    rec
  })
}

#* Bağımsız R paketi (zip)
#* @get /simulations/<id>/package
#* @serializer contentType list(type = "application/zip")
function(id, res) {
  j <- sim_job_get(id)
  res$setHeader("Content-Disposition", "attachment; filename=\"olceklab_simulasyon.zip\"")
  sim_export_package(readRDS(file.path(j$dir, "spec.rds")), id)
}

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

#* M10: Word raporu (R şablonları; isteğe bağlı, onaylı ve etiketli AI metinleri)
#* @post /reports/docx
#* @parser json list(simplifyVector = FALSE)
#* @serializer contentType list(type = "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
function(req, res) {
  b <- req$body
  lang <- if (is.null(b$lang)) "tr" else as.character(b$lang)
  if (!(lang %in% c("tr", "en"))) api_stop("invalid_setting", "Rapor dili tr ya da en olmalıdır.", 422L)
  raw <- report_docx(b$analysis_ids, lang, b$title, b$ai_texts)
  res$setHeader("Content-Disposition", "attachment; filename=\"olceklab_rapor.docx\"")
  raw
}

#* M10: rapor önizlemesi (Word belgesine girecek şablon metinler ve tablo numaraları)
#* @post /reports/preview
#* @parser json list(simplifyVector = FALSE)
function(req) {
  b <- req$body
  lang <- if (is.null(b$lang)) "tr" else as.character(b$lang)
  if (!(lang %in% c("tr", "en"))) api_stop("invalid_setting", "Rapor dili tr ya da en olmalıdır.", 422L)
  report_preview(b$analysis_ids, lang, b$ai_texts)
}

#* M10: tablo CSV olarak (biçimli ya da ham değerler)
#* @get /analyses/<id>/tables/<tid>/csv
#* @serializer contentType list(type = "text/csv; charset=utf-8")
function(id, tid, res, lang = "tr", values = "formatted") {
  a <- analysis_get(id)
  if (!(lang %in% c("tr", "en"))) api_stop("invalid_setting", "Dil tr ya da en olmalıdır.", 422L)
  if (!(values %in% c("formatted", "raw"))) api_stop("invalid_setting", "values formatted ya da raw olmalıdır.", 422L)
  res$setHeader("Content-Disposition", sprintf("attachment; filename=\"%s_%s_%s.csv\"", a$module, tid, values))
  charToRaw(enc2utf8(report_table_csv(a$record, tid, lang, values)))
}

#* M12: proje dosyası (.olceklab.zip) dışa aktarma
#* @post /projects/export
#* @parser json list(simplifyVector = FALSE)
#* @serializer contentType list(type = "application/zip")
function(req, res) {
  b <- req$body
  raw <- project_export(if (is.null(b$dataset_id)) "" else as.character(b$dataset_id), b$analysis_ids,
                        include_data = isTRUE(b$include_data), data_consent = isTRUE(b$data_consent))
  res$setHeader("Content-Disposition", "attachment; filename=\"proje.olceklab.zip\"")
  raw
}

#* M12: proje dosyasını içe aktar (gövde: zip baytları) → özet, sürüm uyarıları
#* @post /projects/import
#* @parser octet
function(req) {
  p <- project_read_zip(req$bodyRaw)
  id <- project_store(p)
  project_summary(id, p)
}

#* M12: içe aktarılan projeyi yeniden üret ve 17 basamakla karşılaştır
#* @post /projects/<id>/reproduce
#* @parser json list(simplifyVector = FALSE)
function(id, req, res) {
  p <- project_get(id)
  man <- p$manifest; d <- man$dataset
  b <- req$body
  user_ds <- NULL
  src <- if (!is.null(p$data_raw)) list(raw = p$data_raw, filename = d$filename)
         else if (identical(d$source$type, "example")) list(example = d$source$name)
         else {
           if (is.null(b$dataset_id)) api_stop("data_required", "Bu projede veri dosyası yok; aynı veri dosyasını yükleyip yeniden deneyin.", 409L)
           user_ds <- dataset_get(as.character(b$dataset_id))
           if (!identical(user_ds$hash, d$hash))
             api_stop("hash_mismatch", "Yüklenen dosyanın SHA-256 özeti projedeki veriyle aynı değil; sonuçlar karşılaştırılamaz.", 422L,
                      detail = sprintf("proje: %s; yüklenen: %s", d$hash, user_ds$hash))
           list(data = user_ds$data, hash = user_ds$hash)
         }
  run_in_worker(res, "project_reproduce_job", list(source = src, roles_json = d$roles_request, clean_json = d$clean_request, analyses = man$analyses),
                then = function(out) project_reproduce_finish(id, p, out, user_ds))
}

#* M12: analizin R betiği
#* @get /analyses/<id>/script
#* @serializer text
function(id) {
  a <- analysis_get(id)
  if (is.null(a$r_script)) api_stop("script_not_available", "Bu analiz için betik yok.", 404L)
  a$r_script
}
