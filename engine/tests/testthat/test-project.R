# M12 — proje dosyası (.olceklab.zip): dışa aktarma, açık onay, içe aktarma, yeniden üretim ve 17 basamaklı
# karşılaştırma; sürüm uyuşmazlığı uyarısı; veri özeti (SHA-256) denetimi. Gerçek plumber sunucusu, iki mirai işçisi.

eng <- start_engine(workers = 2L)
api <- eng$api

items <- c(paste0("N", 1:5), paste0("C", 1:5))
src <- psych::bfi[, c(items, "gender")]
names(src)[names(src) == "gender"] <- "Cinsiyet"
csv_file <- tempfile(fileext = ".csv")
utils::write.csv(src, csv_file, row.names = FALSE, na = "")
raw <- readBin(csv_file, "raw", file.size(csv_file)); unlink(csv_file)
roles_body <- list(
  roles = c(stats::setNames(as.list(rep("item", 10)), items), list(Cinsiyet = "group")),
  items = lapply(stats::setNames(items, items), function(i) list(min = 1, max = 6, reverse = i %in% c("C4", "C5"), subscale = substr(i, 1, 1))),
  group_valid_values = c("1", "2"))
model <- list(factors = list(list(name = "N", items = paste0("N", 1:5)), list(name = "C", items = paste0("C", 1:5))))

setup_session <- function() {
  up <- body_json(api("/datasets", "POST", raw = raw, query = list(filename = "bfi10.csv")))
  id <- up$dataset_id
  api(sprintf("/datasets/%s/roles", id), "POST", json = roles_body)
  cl <- body_json(api(sprintf("/datasets/%s/clean", id), "POST", json = list(rules = list(straightline = FALSE))))
  post <- function(path, settings) body_json(api(path, "POST", json = list(dataset_id = id, settings = settings)))
  recs <- list(
    item = post("/analyses/item", list(r_drop_threshold = 0.3)),
    suit = post("/analyses/suitability", list(correlation = "pearson")),
    fn = post("/analyses/factor-number", list(n_iter = 20, seed = 7)),
    efa = post("/analyses/efa", list(nfactors = 2, seed = 11)),
    cfa = post("/analyses/cfa", list(model = model, estimator = "MLR")),
    rel = post("/analyses/reliability", list(model = model)),
    inv = post("/analyses/invariance", list(model = model, partial = list("N=~N2"))))
  list(id = id, clean = cl, recs = recs)
}
s1 <- setup_session()

zip_entries <- function(z) { f <- tempfile(fileext = ".zip"); writeBin(z, f); on.exit(unlink(f)); utils::unzip(f, list = TRUE)$Name }
zip_read <- function(z, name) { f <- tempfile(fileext = ".zip"); writeBin(z, f); on.exit(unlink(f)); con <- unz(f, name, "rb"); on.exit(close(con), add = TRUE)
  readBin(con, "raw", 5e7) }
zip_rewrite <- function(z, edit) {
  d <- tempfile("pz-"); dir.create(d); on.exit(unlink(d, recursive = TRUE))
  f <- file.path(d, "in.zip"); writeBin(z, f); utils::unzip(f, exdir = file.path(d, "x")); unlink(f)
  edit(file.path(d, "x"))
  out <- file.path(d, "out.zip"); zip::zip(out, files = list.files(file.path(d, "x"), recursive = TRUE), root = file.path(d, "x"))
  readBin(out, "raw", file.size(out))
}

test_that("dışa aktarma: manifest, sonuç JSON'ları, R betikleri, sürümler; veri varsayılan olarak eklenmez", {
  r <- api("/projects/export", "POST", json = list(dataset_id = s1$id))
  expect_identical(httr2::resp_status(r), 200L)
  expect_identical(httr2::resp_header(r, "Content-Type"), "application/zip")
  z <- httr2::resp_body_raw(r)
  nm <- zip_entries(z)
  expect_true(all(c("manifest.json", "versions.json", "BENIOKU.md") %in% nm))
  expect_false(any(startsWith(nm, "data/")))
  man <- jsonlite::parse_json(rawToChar(zip_read(z, "manifest.json")))
  expect_identical(man$format, "olceklab-project")
  expect_identical(man$dataset$hash, paste0("sha256:", digest::digest(raw, "sha256", serialize = FALSE)))
  expect_identical(vapply(man$analyses, `[[`, "", "module"),
                   c("data_clean", "item_analysis", "suitability", "factor_number", "efa", "cfa", "reliability", "invariance"))
  expect_true(all(vapply(man$analyses[-1], function(a) paste0("scripts/", sprintf("%02d_%s.R", a$order, a$module)) %in% nm, logical(1))))
  cfa <- jsonlite::parse_json(rawToChar(zip_read(z, man$analyses[[6]]$record_file)))
  expect_identical(cfa$analysis_id, s1$recs$cfa$analysis_id)
  expect_identical(cfa$results$fit, s1$recs$cfa$results$fit)  # 17 basamak: aynı JSON
})

test_that("veri dosyası yalnızca açık onayla eklenir; eklenen baytlar özgün dosyanın aynısıdır", {
  r <- api("/projects/export", "POST", json = list(dataset_id = s1$id, include_data = TRUE))
  expect_identical(httr2::resp_status(r), 422L)
  expect_identical(body_json(r)$error$code, "consent_required")
  z <- httr2::resp_body_raw(api("/projects/export", "POST", json = list(dataset_id = s1$id, include_data = TRUE, data_consent = TRUE)))
  expect_true("data/bfi10.csv" %in% zip_entries(z))
  expect_identical(zip_read(z, "data/bfi10.csv"), raw)
})

test_that("veriyle birlikte içe aktarılan proje yeniden üretilir: bütün analizler 17 basamakta aynı", {
  z <- httr2::resp_body_raw(api("/projects/export", "POST", json = list(dataset_id = s1$id, include_data = TRUE, data_consent = TRUE)))
  im <- body_json(api("/projects/import", "POST", raw = z))
  expect_false(im$needs_data)
  expect_true(im$dataset$included)
  expect_length(im$version_warnings, 0L)
  expect_length(im$analyses, 8L)
  rp <- body_json(api(sprintf("/projects/%s/reproduce", im$project_id), "POST", json = list()))
  expect_true(rp$all_identical)
  expect_true(rp$hash_ok)
  st <- vapply(rp$comparisons, `[[`, "", "status")
  expect_identical(unname(st), rep("identical", 8L))
  expect_true(all(vapply(rp$comparisons, `[[`, 0L, "n_numeric") > 0L))
  expect_match(rp$comparisons[[6]]$text_tr, "^Aynı \\(")
  expect_false(identical(rp$dataset$dataset_id, s1$id))
  expect_identical(rp$dataset$dataset_hash, im$dataset$hash)
  expect_length(rp$records, 7L)
  expect_identical(rp$records[[5]]$results$fit, s1$recs$cfa$results$fit)
  expect_identical(unlist(rp$roles$group_valid_values), roles_body$group_valid_values)
  # Yeniden üretilen oturumda analizler sürdürülebilir
  r2 <- body_json(api("/analyses/reliability", "POST", json = list(dataset_id = rp$dataset$dataset_id, settings = list(model = model))))
  expect_identical(r2$results$omega, s1$recs$rel$results$omega)
})

test_that("veri olmadan: aynı dosya yüklenmeden yeniden üretilmez; farklı dosya reddedilir; aynı dosyayla aynı sonuç", {
  z <- httr2::resp_body_raw(api("/projects/export", "POST", json = list(dataset_id = s1$id)))
  im <- body_json(api("/projects/import", "POST", raw = z))
  expect_true(im$needs_data)
  r <- api(sprintf("/projects/%s/reproduce", im$project_id), "POST", json = list())
  expect_identical(httr2::resp_status(r), 409L)
  expect_identical(body_json(r)$error$code, "data_required")
  other <- c(raw, charToRaw("\n"))
  o <- body_json(api("/datasets", "POST", raw = other, query = list(filename = "bfi10.csv")))
  r <- api(sprintf("/projects/%s/reproduce", im$project_id), "POST", json = list(dataset_id = o$dataset_id))
  expect_identical(httr2::resp_status(r), 422L)
  expect_identical(body_json(r)$error$code, "hash_mismatch")
  same <- body_json(api("/datasets", "POST", raw = raw, query = list(filename = "kopya.csv")))
  rp <- body_json(api(sprintf("/projects/%s/reproduce", im$project_id), "POST", json = list(dataset_id = same$dataset_id)))
  expect_true(rp$all_identical)
  expect_identical(rp$dataset$dataset_id, same$dataset_id)
})

test_that("karşılaştırma farkı yakalar; sürüm farkı uyarılır; bozuk veri dosyası reddedilir", {
  z <- httr2::resp_body_raw(api("/projects/export", "POST", json = list(dataset_id = s1$id, include_data = TRUE, data_consent = TRUE)))
  z2 <- zip_rewrite(z, function(d) {
    m <- jsonlite::read_json(file.path(d, "manifest.json"))
    m$engine$packages$lavaan <- "0.0.1"
    jsonlite::write_json(m, file.path(d, "manifest.json"), auto_unbox = TRUE, digits = I(17), null = "null")
    f <- file.path(d, m$analyses[[7]]$record_file)
    rec <- jsonlite::read_json(f)
    rec$results$omega[[1]] <- rec$results$omega[[1]] + 1e-12
    jsonlite::write_json(rec, f, auto_unbox = TRUE, digits = I(17), null = "null")
  })
  im <- body_json(api("/projects/import", "POST", raw = z2))
  w <- Filter(function(x) identical(x$component, "lavaan"), im$version_warnings)
  expect_length(w, 1L)
  expect_match(w[[1]]$message_tr, "projede 0.0.1", fixed = TRUE)
  rp <- body_json(api(sprintf("/projects/%s/reproduce", im$project_id), "POST", json = list()))
  expect_false(rp$all_identical)
  st <- vapply(rp$comparisons, `[[`, "", "status")
  expect_identical(unname(st[7]), "different")
  expect_identical(rp$comparisons[[7]]$n_diff, 1L)
  expect_match(rp$comparisons[[7]]$diffs[[1]], "^results/omega")
  expect_true(all(st[-7] == "identical"))
  z3 <- zip_rewrite(z, function(d) writeBin(c(raw, as.raw(10)), file.path(d, "data", "bfi10.csv")))
  r <- api("/projects/import", "POST", raw = z3)
  expect_identical(httr2::resp_status(r), 422L)
  expect_identical(body_json(r)$error$code, "hash_mismatch")
  r <- api("/projects/import", "POST", raw = charToRaw("değil"))
  expect_identical(body_json(r)$error$code, "invalid_project")
})

test_that("örnek veriyle kurulan proje veri eklenmeden yeniden üretilir", {
  ex <- body_json(api("/datasets/examples/holzinger", "POST"))
  api(sprintf("/datasets/%s/roles", ex$dataset_id), "POST", json = ex$suggested_config)
  api(sprintf("/datasets/%s/clean", ex$dataset_id), "POST", json = list(rules = list()))
  m3 <- list(factors = list(list(name = "visual", items = c("x1", "x2", "x3")), list(name = "textual", items = c("x4", "x5", "x6")),
                            list(name = "speed", items = c("x7", "x8", "x9"))))
  c0 <- body_json(api("/analyses/cfa", "POST", json = list(dataset_id = ex$dataset_id, settings = list(model = m3, bootstrap = 100, seed = 3))))
  z <- httr2::resp_body_raw(api("/projects/export", "POST", json = list(dataset_id = ex$dataset_id, include_data = TRUE, data_consent = TRUE)))
  expect_false(any(startsWith(zip_entries(z), "data/")))
  im <- body_json(api("/projects/import", "POST", raw = z))
  expect_false(im$needs_data)
  rp <- body_json(api(sprintf("/projects/%s/reproduce", im$project_id), "POST", json = list()))
  expect_true(rp$all_identical)
  expect_identical(rp$records[[1]]$results$bollen_stine, c0$results$bollen_stine)  # tohumlu bootstrap da aynı
})

test_that("dışa aktarma geçici dosya bırakmaz (yerel çağrı)", {
  hs <- example_ds("holzinger")
  .olceklab$datasets[[hs$id]] <- c(hs, list(last_access = Sys.time(), requests = list(roles = "{}", clean = "{}")))
  analysis_store(hs$clean_record, hs$id, request = "{}")
  before <- list.files(tempdir(), pattern = "^olceklab-proje-")
  z <- project_export(hs$id)
  expect_identical(list.files(tempdir(), pattern = "^olceklab-proje-"), before)
  expect_identical(z[1:2], as.raw(c(0x50, 0x4b)))
})

test_that("HTTP: Word raporu, önizleme ve CSV uç noktaları; hata gövdesi JSON", {
  ids <- list(s1$recs$cfa$analysis_id, s1$recs$rel$analysis_id)
  r <- api("/reports/docx", "POST", json = list(analysis_ids = ids, lang = "tr", title = "Rapor"))
  expect_identical(httr2::resp_status(r), 200L)
  expect_identical(httr2::resp_header(r, "Content-Type"), "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
  f <- tempfile(fileext = ".docx"); writeBin(httr2::resp_body_raw(r), f)
  s <- officer::docx_summary(officer::read_docx(f)); unlink(f)
  expect_true(all(c("Rapor", "Doğrulayıcı faktör analizi", "Tablo 1") %in% s$text))
  pv <- body_json(api("/reports/preview", "POST", json = list(analysis_ids = ids, lang = "en")))
  expect_identical(pv$items[[1]]$title, "Confirmatory factor analysis")
  expect_identical(pv$items[[2]]$tables[[1]]$number, length(s1$recs$cfa$tables) + 1L)
  e <- api("/reports/docx", "POST", json = list(analysis_ids = list()))
  expect_identical(httr2::resp_status(e), 422L)
  expect_identical(body_json(e)$error$code, "report_empty")
  c1 <- api(sprintf("/analyses/%s/tables/T1/csv", s1$recs$rel$analysis_id), query = list(lang = "tr"))
  expect_identical(httr2::resp_status(c1), 200L)
  expect_match(httr2::resp_header(c1, "Content-Type"), "^text/csv")
  txt <- httr2::resp_body_string(c1)
  expect_match(txt, s1$recs$rel$tables[[1]]$rows_fmt$tr[[1]]$alpha, fixed = TRUE)
  c2 <- api(sprintf("/analyses/%s/tables/T9/csv", s1$recs$rel$analysis_id))
  expect_identical(body_json(c2)$error$code, "table_not_found")
})
