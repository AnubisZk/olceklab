# M12 — Proje dosyası (.olceklab.zip) dışa/içe aktarma ve yeniden üretim (SPEC §7 M12).
# Paket: ayarlar (her analizin özgün istek gövdesi), sonuç JSON'ları, R betikleri, sürüm bilgisi, veri özeti (SHA-256).
# Veri dosyası yalnızca kullanıcının açık onayıyla eklenir. İçe aktarmada aynı veriyle bütün analizler yeniden çalıştırılır
# ve sonuçlar 17 anlamlı basamaklı değerlerle karşılaştırılır; paket sürümleri farklıysa uyarı verilir.
# Gizlilik (SPEC §10): zip yalnızca işlem süresince geçici dizinde bulunur ve hemen silinir; veri bellekte tutulur.

PROJECT_FORMAT <- "olceklab-project"
PROJECT_FORMAT_VERSION <- 1L

# Uç nokta fonksiyonları ve plumber ayrıştırıcıları (Faz 1 uç noktaları JSON'u basitleştirir, Faz 2+ basitleştirmez).
project_modules <- list(
  item_analysis = list(fun = "analysis_item", simplify = TRUE),
  suitability = list(fun = "analysis_suitability", simplify = TRUE),
  factor_number = list(fun = "analysis_factor_number", simplify = TRUE),
  efa = list(fun = "analysis_efa", simplify = FALSE),
  cfa = list(fun = "analysis_cfa", simplify = FALSE),
  cfa_compare = list(fun = "analysis_cfa_compare", simplify = FALSE),
  reliability = list(fun = "analysis_reliability", simplify = FALSE),
  invariance = list(fun = "analysis_invariance", simplify = FALSE),
  invariance_scores = list(fun = "analysis_invariance_scores", simplify = FALSE))

project_parse <- function(json, simplify) {
  if (is.null(json) || !nzchar(json)) return(list())
  jsonlite::parse_json(json, simplifyVector = simplify)
}

request_json <- function(req) {
  raw <- req$bodyRaw
  if (is.null(raw) || !length(raw)) return("")
  x <- rawToChar(raw); Encoding(x) <- "UTF-8"; x
}

# --- Dışa aktarma -----------------------------------------------------------------------
# Son temizleme kaydı + (seçilen ya da son temizlemeden sonra üretilen) analizler, oluşturulma sırasıyla.
project_export_entries <- function(ds, analysis_ids = NULL) {
  all <- Filter(function(a) identical(a$dataset_id, ds$id), .olceklab$analyses)
  all <- all[order(vapply(all, function(a) as.numeric(a$created), 0))]
  cleans <- Filter(function(a) a$module == "data_clean", all)
  if (!length(cleans)) api_stop("not_cleaned", "Önce veri temizleme adımını çalıştırın.", 409L)
  last_clean <- cleans[[length(cleans)]]
  mods <- Filter(function(a) a$module %in% names(project_modules), all)
  if (length(analysis_ids)) {
    want <- as.character(unlist(analysis_ids))
    have <- vapply(mods, function(a) a$record$analysis_id, "")
    bad <- setdiff(want, c(have, last_clean$record$analysis_id))
    if (length(bad)) api_stop("analysis_not_found", "Projeye eklenecek analizlerden biri bu veri setine ait değil.", 404L)
    mods <- mods[have %in% want]
  } else {
    mods <- Filter(function(a) as.numeric(a$created) >= as.numeric(last_clean$created), mods)
  }
  c(list(last_clean), mods)
}

project_manifest <- function(ds, ent, include_data) {
  list(
    format = PROJECT_FORMAT, format_version = PROJECT_FORMAT_VERSION,
    created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    engine = engine_versions(),
    dataset = list(filename = ds$filename, source = ds$source, hash = ds$hash, n_rows = nrow(ds$data), n_cols = ncol(ds$data),
                   roles_request = ds$requests$roles, clean_request = ds$requests$clean,
                   included = isTRUE(include_data), data_file = if (isTRUE(include_data)) paste0("data/", basename(ds$filename)) else NULL),
    analyses = lapply(seq_along(ent), function(i) {
      a <- ent[[i]]
      list(order = i, analysis_id = a$record$analysis_id, module = a$module,
           request = if (is.null(a$request)) NULL else a$request,
           record_file = sprintf("analyses/%02d_%s.json", i, a$module),
           script_file = if (!is.null(a$r_script)) sprintf("scripts/%02d_%s.R", i, a$module) else NULL)
    }))
}

project_export <- function(dataset_id, analysis_ids = NULL, include_data = FALSE, data_consent = FALSE) {
  ds <- dataset_get(dataset_id)
  if (is.null(ds$clean)) api_stop("not_cleaned", "Önce veri temizleme adımını çalıştırın.", 409L)
  include_data <- isTRUE(include_data)
  if (include_data && !isTRUE(data_consent))
    api_stop("consent_required", "Veri dosyasının projeye eklenmesi için açık onay gerekir.", 422L)
  if (include_data && is.null(ds$raw) && !identical(ds$source$type, "example"))
    api_stop("data_unavailable", "Özgün veri dosyasının baytları bellekte yok; dosyayı yeniden yükleyin.", 409L)
  if (identical(ds$source$type, "example")) include_data <- FALSE  # örnek veri adla yeniden yüklenir
  ent <- project_export_entries(ds, analysis_ids)
  man <- project_manifest(ds, ent, include_data)
  dir <- tempfile("olceklab-proje-")
  dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE, force = TRUE), add = TRUE)
  w <- function(rel, txt) { f <- file.path(dir, rel); dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE); writeLines(txt, f, useBytes = TRUE) }
  w("manifest.json", as.character(to_json(man)))
  w("versions.json", as.character(to_json(engine_versions())))
  for (i in seq_along(ent)) {
    w(man$analyses[[i]]$record_file, as.character(to_json(ent[[i]]$record)))
    if (!is.null(man$analyses[[i]]$script_file)) w(man$analyses[[i]]$script_file, ent[[i]]$r_script)
  }
  if (include_data) { f <- file.path(dir, man$dataset$data_file); dir.create(dirname(f), showWarnings = FALSE); writeBin(ds$raw, f) }
  w("BENIOKU.md", paste0(
    "# ÖlçekLab proje dosyası\n\n",
    "- `manifest.json`: veri özeti (SHA-256), sütun rolleri ve temizleme isteği, analizlerin sırası ve özgün istek gövdeleri.\n",
    "- `analyses/`: her analizin tam sonuç kaydı (17 anlamlı basamaklı sayılar ve R'nin biçimlediği metinler).\n",
    "- `scripts/`: her analiz için bağımsız çalışan R betiği (veri yolu yer tutucuyla).\n",
    "- `versions.json`: R ve paket sürümleri, BLAS/LAPACK, RNG türü.\n",
    if (include_data) "- `data/`: özgün veri dosyası (kullanıcının açık onayıyla eklendi).\n" else
      "- Veri dosyası eklenmedi. İçe aktarırken aynı dosyayı yükleyin; SHA-256 özeti denetlenir.\n",
    "\nÖlçekLab'de Başlangıç → Projeyi içe aktar ile açın: analizler yeniden çalıştırılır ve sonuçlar karşılaştırılır.\n"))
  zf <- file.path(dir, "proje.olceklab.zip")
  files <- setdiff(list.files(dir, recursive = TRUE), "proje.olceklab.zip")
  zip::zip(zf, files = files, root = dir)
  readBin(zf, "raw", file.size(zf))
}

# --- İçe aktarma ------------------------------------------------------------------------
project_read_zip <- function(raw) {
  if (!is.raw(raw) || length(raw) < 4L || !identical(raw[1:2], as.raw(c(0x50, 0x4b))))
    api_stop("invalid_project", "Dosya bir ÖlçekLab proje dosyası (.olceklab.zip) değil.", 422L)
  if (length(raw) > max_upload_bytes() * 2) api_stop("file_too_large", "Proje dosyası çok büyük.", 413L)
  zf <- tempfile(fileext = ".zip")
  on.exit(unlink(zf, force = TRUE), add = TRUE)
  writeBin(raw, zf)
  lst <- tryCatch(utils::unzip(zf, list = TRUE), error = function(e) NULL)
  if (is.null(lst) || !("manifest.json" %in% lst$Name)) api_stop("invalid_project", "Proje dosyasında manifest.json yok.", 422L)
  read_entry <- function(name, binary = FALSE) {
    k <- match(name, lst$Name)
    if (is.na(k)) api_stop("invalid_project", sprintf("Proje dosyasında %s eksik.", name), 422L)
    con <- unz(zf, name, open = "rb"); on.exit(close(con), add = TRUE)
    b <- readBin(con, "raw", n = lst$Length[k])
    if (binary) return(b)
    x <- rawToChar(b); Encoding(x) <- "UTF-8"; x
  }
  man <- tryCatch(jsonlite::parse_json(read_entry("manifest.json"), simplifyVector = FALSE), error = function(e) NULL)
  if (!is.list(man) || !identical(man$format, PROJECT_FORMAT)) api_stop("invalid_project", "manifest.json bir ÖlçekLab proje tanımı değil.", 422L)
  if (!isTRUE(man$format_version <= PROJECT_FORMAT_VERSION))
    api_stop("project_version", "Proje dosyası bu ÖlçekLab sürümünden daha yeni bir biçimde.", 422L)
  recs <- lapply(man$analyses, function(a) jsonlite::parse_json(read_entry(a$record_file), simplifyVector = FALSE))
  data_raw <- if (isTRUE(man$dataset$included)) read_entry(man$dataset$data_file, binary = TRUE) else NULL
  if (!is.null(data_raw)) {
    h <- paste0("sha256:", digest::digest(data_raw, algo = "sha256", serialize = FALSE))
    if (!identical(h, man$dataset$hash)) api_stop("hash_mismatch", "Projedeki veri dosyasının SHA-256 özeti manifest ile uyuşmuyor.", 422L)
  }
  list(manifest = man, records = recs, data_raw = data_raw)
}

project_version_warnings <- function(man) {
  cur <- engine_versions(); old <- man$engine
  out <- list()
  add <- function(name, a, b) out[[length(out) + 1L]] <<- list(component = name, project = a, current = b,
    message_tr = sprintf("%s: projede %s, bu motorda %s. Sonuçlar farklı çıkabilir.", name, a, b),
    message_en = sprintf("%s: %s in the project, %s in this engine. Results may differ.", name, a, b))
  if (!identical(as.character(old$R), as.character(cur$R))) add("R", as.character(old$R), as.character(cur$R))
  for (p in union(names(old$packages), names(cur$packages))) {
    a <- if (is.null(old$packages[[p]])) "—" else as.character(old$packages[[p]])
    b <- if (is.null(cur$packages[[p]])) "—" else as.character(cur$packages[[p]])
    if (!identical(a, b)) add(p, a, b)
  }
  if (!identical(as.character(old$blas %||% ""), as.character(cur$blas %||% ""))) add("BLAS", as.character(old$blas %||% "—"), as.character(cur$blas %||% "—"))
  out
}


project_summary <- function(pid, p) {
  man <- p$manifest; d <- man$dataset
  dtext <- function(lang) sprintf(if (lang == "tr") "%s · %s satır × %s sütun · %s" else "%s · %s rows × %s columns · %s",
                                  d$filename, fmt_int(d$n_rows, lang), fmt_int(d$n_cols, lang), d$hash)
  list(project_id = pid, created_at = man$created_at, format_version = man$format_version,
       dataset = list(filename = d$filename, hash = d$hash, n_rows = d$n_rows, n_cols = d$n_cols, source_type = d$source$type,
                      example_name = d$source$name, included = isTRUE(d$included), text_tr = dtext("tr"), text_en = dtext("en")),
       needs_data = !isTRUE(d$included) && !identical(d$source$type, "example"),
       analyses = lapply(man$analyses, function(a) list(order = a$order, module = a$module, analysis_id = a$analysis_id,
                                                       title_tr = report_module_titles[[a$module]][["tr"]] %||% a$module,
                                                       title_en = report_module_titles[[a$module]][["en"]] %||% a$module)),
       version_warnings = project_version_warnings(man))
}

project_store <- function(p) {
  if (is.null(.olceklab$projects)) .olceklab$projects <- list()
  id <- uuid::UUIDgenerate(use.time = FALSE)
  p$created <- Sys.time(); p$last_access <- p$created
  .olceklab$projects[[id]] <- p
  id
}

project_get <- function(id) {
  p <- if (is.null(.olceklab$projects)) NULL else .olceklab$projects[[id]]
  if (is.null(p)) api_stop("project_not_found", "İçe aktarılan proje bulunamadı. Oturum süresi dolmuş olabilir.", 404L)
  .olceklab$projects[[id]]$last_access <- Sys.time()
  p
}

# --- Yeniden üretim (işçide) ------------------------------------------------------------
project_reproduce_run <- function(data, hash, roles_json, clean_json, analyses) {
  roles <- project_parse(roles_json, TRUE)
  config <- build_config(data, roles)
  cb <- project_parse(clean_json, TRUE)
  rules <- if (is.list(cb$rules)) cb$rules else list()
  cl <- analysis_clean(data, config, rules, hash)
  out <- lapply(analyses, function(a) {
    if (a$module == "data_clean") return(list(ok = TRUE, record = cl$record))
    m <- project_modules[[a$module]]
    if (is.null(m) || is.null(a$request)) return(list(ok = FALSE, message = "İstek gövdesi projede yok."))
    b <- project_parse(a$request, m$simplify)
    args <- list(data = cl$clean$data, config = config, settings = if (is.list(b$settings)) b$settings else list(), dataset_hash = hash)
    if (m$fun == "analysis_item") args$item_missing <- cl$clean$item_missing
    tryCatch(list(ok = TRUE, record = do.call(m$fun, args)), api_error = function(e) list(ok = FALSE, message = conditionMessage(e)),
             error = function(e) list(ok = FALSE, message = conditionMessage(e)))
  })
  list(config = config, clean = cl$clean, rules = rules, results = out)
}

# Karşılaştırma: iki kayıt aynı JSON serileştirmesinden (17 anlamlı basamak) geçirilir; results ve tablolar
# (ham ve biçimli) yaprak yaprak karşılaştırılır. Kimlik, zaman damgası ve betik karşılaştırılmaz.
project_leaves <- function(x, path = character()) {
  if (is.null(x)) return(list())
  if (is.list(x)) {
    nm <- names(x)
    if (is.null(nm)) nm <- as.character(seq_along(x))
    out <- list()
    for (i in seq_along(x)) out <- c(out, project_leaves(x[[i]], c(path, nm[i])))
    return(out)
  }
  stats::setNames(list(x), paste(path, collapse = "/"))
}

project_comparable <- function(rec) {
  rec <- jsonlite::parse_json(as.character(to_json(rec)), simplifyVector = FALSE)
  tabs <- stats::setNames(lapply(rec$tables, function(t) t[c("rows", "rows_fmt")]), vapply(rec$tables, function(t) t$id, ""))
  list(results = rec$results, tables = tabs)
}

project_compare <- function(old, new) {
  a <- project_leaves(project_comparable(old)); b <- project_leaves(project_comparable(new))
  keys <- union(names(a), names(b))
  num <- 0L; diffs <- character(); maxd <- 0
  for (k in keys) {
    x <- a[[k]]; y <- b[[k]]
    if (is.numeric(x) || is.numeric(y)) num <- num + 1L
    if (identical(x, y)) next
    if (is.numeric(x) && is.numeric(y)) maxd <- max(maxd, abs(x - y))
    diffs <- c(diffs, k)
  }
  list(n_values = length(keys), n_numeric = num, n_diff = length(diffs), max_abs_diff = maxd, diffs = I(utils::head(diffs, 10L)))
}

fmt_sci <- function(x, lang) {
  s <- formatC(x, digits = 2L, format = "e")
  s <- sub("e([+-])0*([0-9])", " × 10^\\1\\2", s)
  s <- sub("^-", "\u2212", sub("\\^-", "^\u2212", sub("\\^\\+", "^", s)))
  if (lang == "tr") sub(".", ",", s, fixed = TRUE) else s
}

project_comparison_text <- function(cmp, lang) {
  if (!is.null(cmp$error)) return(if (lang == "tr") paste("Yeniden çalıştırılamadı:", cmp$error) else paste("Could not be re-run:", cmp$error))
  if (cmp$n_diff == 0L) return(sprintf(if (lang == "tr") "Aynı (%s değer, %s sayı; 17 anlamlı basamak)" else "Identical (%s values, %s numbers; 17 significant digits)",
                                       fmt_int(cmp$n_values, lang), fmt_int(cmp$n_numeric, lang)))
  base <- sprintf(if (lang == "tr") "Farklı: %s / %s değer" else "Different: %s of %s values", fmt_int(cmp$n_diff, lang), fmt_int(cmp$n_values, lang))
  if (cmp$max_abs_diff > 0) paste0(base, sprintf(if (lang == "tr") "; en büyük sayısal fark %s" else "; largest numeric difference %s", fmt_sci(cmp$max_abs_diff, lang))) else base
}

# İşçide: veriyi kaynağından okur (projedeki dosya, örnek veri ya da kullanıcının yüklediği veri) ve yeniden üretir.
project_reproduce_job <- function(source, roles_json, clean_json, analyses) {
  if (!is.null(source$raw)) {
    v <- parse_upload(source$raw, source$filename)
    data <- v$data; hash <- v$hash; meta <- list(filename = v$filename, delimiter = v$delimiter, type = "upload")
  } else if (!is.null(source$example)) {
    v <- load_example(source$example)
    data <- v$data; hash <- v$hash; meta <- list(filename = v$filename, type = "example", label = v$source, suggested_config = v$suggested_config)
  } else {
    data <- source$data; hash <- source$hash; meta <- NULL
  }
  run <- project_reproduce_run(data, hash, roles_json, clean_json, analyses)
  list(data = if (is.null(meta)) NULL else data, hash = hash, meta = meta, run = run)
}

# Ana süreçte: yeniden üretilen veri setini ve kayıtları oturuma yazar, karşılaştırmaları kurar.
project_reproduce_finish <- function(pid, p, out, user_ds = NULL) {
  man <- p$manifest; d <- man$dataset
  if (is.null(user_ds)) {
    m <- out$meta
    src <- if (identical(m$type, "example")) list(type = "example", name = d$source$name, label = m$label) else list(type = "upload", delimiter = m$delimiter)
    id <- dataset_put(c(list(data = out$data, hash = out$hash, filename = m$filename, source = src, raw = p$data_raw),
                        if (!is.null(m$suggested_config)) list(suggested_config = m$suggested_config)))
    ds <- dataset_get(id)
  } else ds <- user_ds
  ds$config <- out$run$config; ds$clean <- out$run$clean; ds$clean_rules <- out$run$rules
  ds$requests <- list(roles = d$roles_request, clean = d$clean_request)
  dataset_update(ds$id, ds)
  ds <- dataset_get(ds$id)
  comps <- list(); records <- list(); clean_rec <- NULL
  for (i in seq_along(man$analyses)) {
    a <- man$analyses[[i]]; r <- out$run$results[[i]]
    title <- report_module_titles[[a$module]] %||% c(tr = a$module, en = a$module)
    if (!isTRUE(r$ok)) {
      cmp <- list(error = r$message)
    } else {
      rec <- r$record
      if (a$module == "data_clean") { clean_rec <- rec; analysis_store(rec, ds$id, request = a$request) }
      else {
        rec$r_script <- build_r_script(rec$module, ds, rec$settings, rec$seed, rec$results)
        analysis_store(rec, ds$id, request = a$request)
        records[[length(records) + 1L]] <- rec
      }
      cmp <- project_compare(p$records[[i]], rec)
      cmp$new_analysis_id <- rec$analysis_id
    }
    comps[[i]] <- c(list(order = a$order, module = a$module, title_tr = title[["tr"]], title_en = title[["en"]], old_analysis_id = a$analysis_id,
                         status = if (!is.null(cmp$error)) "error" else if (cmp$n_diff == 0L) "identical" else "different"),
                    cmp, list(text_tr = project_comparison_text(cmp, "tr"), text_en = project_comparison_text(cmp, "en")))
  }
  hash_ok <- identical(ds$hash, d$hash)
  warn <- project_version_warnings(man)
  if (!hash_ok) warn[[length(warn) + 1L]] <- list(component = "data", project = d$hash, current = ds$hash,
    message_tr = "Yeniden yüklenen örnek verinin SHA-256 özeti projedekinden farklı (paket sürümü değişmiş olabilir).",
    message_en = "The SHA-256 digest of the reloaded example data differs from the project (the package version may have changed).")
  list(project_id = pid, dataset = dataset_overview(ds), roles = project_parse(d$roles_request, TRUE),
       clean = clean_rec, records = records, comparisons = comps,
       all_identical = all(vapply(comps, function(c) identical(c$status, "identical"), logical(1))),
       hash_ok = hash_ok, version_warnings = warn)
}
