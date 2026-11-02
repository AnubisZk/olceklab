# Uçtan uca: yükleme → roller → temizleme → M2/M3/M4, mirai işçileriyle (ENGINE_WORKERS = 2).
# HTTP ile dönen sayılar, aynı veriyle yerelde çağrılan motor fonksiyonlarıyla birebir karşılaştırılır
# (17 basamaklı JSON sayesinde kayıpsız).

eng <- start_engine(workers = 2L)
api <- eng$api

items <- c(paste0("N", 1:5), paste0("C", 1:5))
src <- psych::bfi[, c(items, "gender")]
names(src)[names(src) == "gender"] <- "Cinsiyet"
csv_file <- tempfile(fileext = ".csv")
utils::write.csv(src, csv_file, row.names = FALSE, na = "")
raw <- readBin(csv_file, "raw", file.size(csv_file))
unlink(csv_file)

roles_body <- list(
  roles = c(stats::setNames(as.list(rep("item", 10)), items), list(Cinsiyet = "group")),
  items = lapply(stats::setNames(items, items), function(i) list(min = 1, max = 6, reverse = i %in% c("C4", "C5"),
                                                                    subscale = substr(i, 1, 1))),
  group_valid_values = c("1", "2")
)

up <- body_json(api("/datasets", "POST", raw = raw, query = list(filename = "bfi10.csv")))
id <- up$dataset_id

test_that("POST /datasets dosyayı okur; özet SHA-256 ile tanımlanır", {
  expect_match(id, "^[0-9a-f-]{36}$")
  expect_identical(up$dataset_hash, paste0("sha256:", digest::digest(raw, "sha256", serialize = FALSE)))
  expect_identical(up$n_rows, nrow(src))
  expect_identical(vapply(up$columns, `[[`, "", "name"), names(src))
  expect_identical(up$columns[[11]]$suggested_role, "group")
})

test_that("roller ve temizleme HTTP üzerinden çalışır ve yerel hesapla aynıdır", {
  r <- api(sprintf("/datasets/%s/roles", id), "POST", json = roles_body)
  expect_identical(httr2::resp_status(r), 200L)
  rec <- body_json(api(sprintf("/datasets/%s/clean", id), "POST", json = list(rules = list())))
  local_df <- parse_upload(raw, "bfi10.csv")$data
  cfg <- build_config(local_df, roles_body)
  ref <- clean_dataset(local_df, cfg, list())
  expect_identical(rec$results$n_final, ref$n_final)
  expect_identical(vapply(rec$results$steps, `[[`, 0L, "removed"), ref$steps$removed)
})

local_ds <- function() {
  df <- parse_upload(raw, "bfi10.csv")$data
  cfg <- build_config(df, roles_body)
  cl <- clean_dataset(df, cfg, list())
  list(data = cl$data, config = cfg, item_missing = cl$item_missing)
}

test_that("M2 HTTP sonucu yerel analysis_item ile birebir aynı", {
  rec <- body_json(api("/analyses/item", "POST", json = list(dataset_id = id)))
  l <- local_ds()
  ref <- analysis_item(l$data, l$config, list(), "h", l$item_missing)
  expect_identical(rec$results$alpha, ref$results$alpha)
  expect_identical(vapply(rec$results$items, function(r) r$r_drop, 0), ref$results$items$r_drop)
  expect_identical(rec$tables[[1]]$rows_fmt$tr[[1]]$r_drop, ref$tables[[1]]$rows_fmt$tr$r_drop[1])
  expect_match(rec$r_script, up$dataset_hash, fixed = TRUE)
  s <- api(sprintf("/analyses/%s/script", rec$analysis_id))
  expect_identical(httr2::resp_status(s), 200L)
  expect_identical(httr2::resp_body_string(s), rec$r_script)
})

test_that("M3 HTTP sonucu yerel analysis_suitability ile birebir aynı", {
  rec <- body_json(api("/analyses/suitability", "POST", json = list(dataset_id = id, settings = list(correlation = "pearson"))))
  l <- local_ds()
  ref <- analysis_suitability(l$data, l$config, list(correlation = "pearson"), "h")
  expect_identical(rec$results$kmo, ref$results$kmo)
  expect_identical(rec$results$bartlett$chisq, ref$results$bartlett$chisq)
})

test_that("M4 işçide çalışır; sonuç yerel çağrıyla ve psych ile birebir aynı", {
  st <- list(extraction = "pc", reference = "simulated_normal", n_iter = 200L, seed = 42L)
  rec <- body_json(api("/analyses/factor-number", "POST", json = list(dataset_id = id, settings = st)))
  l <- local_ds()
  ref <- analysis_factor_number(l$data, l$config, st, "h")
  expect_identical(unlist(rec$results$pc$reference_quantile), ref$results$pc$reference_quantile)
  expect_identical(rec$results$pc$suggested, ref$results$pc$suggested)
  expect_identical(rec$results$psych_check$ncomp, ref$results$psych_check$ncomp)
  expect_identical(rec$rng$mc_cores, 1L)
})

test_that("işçideki ayar hatası 422 ve standart hata biçimiyle döner", {
  r <- api("/analyses/factor-number", "POST", json = list(dataset_id = id, settings = list(correlation = "polychoric", reference = "simulated_normal")))
  expect_identical(httr2::resp_status(r), 422L)
  expect_identical(body_json(r)$error$code, "invalid_reference_for_polychoric")
})

test_that("ARCH-1: uzun bir paralel analiz sürerken /health hemen yanıt verir", {
  long <- callr::r_bg(function(base, id) {
    httr2::request(paste0(base, "/analyses/factor-number")) |>
      httr2::req_body_json(list(dataset_id = id, settings = list(extraction = "pc", n_iter = 4000L, seed = 1L)), auto_unbox = TRUE) |>
      httr2::req_timeout(300) |> httr2::req_perform() |> httr2::resp_status()
  }, args = list(base = eng$base, id = id))
  withr::defer(long$kill())
  Sys.sleep(1.5)
  expect_true(long$is_alive())  # analiz hâlâ sürüyor
  t0 <- Sys.time()
  h <- api("/health", timeout = 5)
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  expect_identical(httr2::resp_status(h), 200L)
  expect_lt(elapsed, 1)
  expect_true(long$is_alive())
  long$wait(300000)
  expect_identical(long$get_result(), 200L)
})

# --- Faz 2: M5, M6, M7 ve model önizlemesi ---------------------------------------

m_nc <- list(factors = list(list(name = "N", items = paste0("N", 1:5)), list(name = "C", items = paste0("C", 1:5))))

test_that("POST /models/preview: varsayılan model alt boyutlardan; kurucu modeli sözdizimine çevrilir", {
  d <- body_json(api("/models/preview", "POST", json = list(dataset_id = id)))
  expect_identical(d$syntax, "N =~ N1 + N2 + N3 + N4 + N5\nC =~ C1 + C2 + C3 + C4 + C5")
  p <- body_json(api("/models/preview", "POST", json = list(dataset_id = id, model = list(syntax = "F =~ N1 + N2 + C1"))))
  expect_identical(p$source, "syntax")
  expect_identical(p$warnings, list())
  bad <- api("/models/preview", "POST", json = list(dataset_id = id, model = list(syntax = "F =~ N1 + Q9")))
  expect_identical(httr2::resp_status(bad), 422L)
  expect_identical(body_json(bad)$error$code, "model_unknown_item")
})

test_that("M5 HTTP sonucu yerel analysis_efa ile birebir aynı", {
  st <- list(nfactors = 2L, seed = 3L)
  rec <- body_json(api("/analyses/efa", "POST", json = list(dataset_id = id, settings = st)))
  l <- local_ds()
  ref <- analysis_efa(l$data, l$config, st, "h")
  f1 <- ref$results$factors[[1]]
  expect_identical(unlist(rec$results$loadings[[f1]]), as.numeric(ref$results$loadings[[f1]]))
  expect_identical(rec$results$fit$tli, ref$results$fit$tli)
  expect_match(rec$r_script, "psych::fa(x, nfactors = 2L", fixed = TRUE)
})

test_that("M6 HTTP sonucu (ML, wishart) yerel analysis_cfa ile birebir aynı; betik indirilebilir", {
  st <- list(model = m_nc, likelihood = "wishart")
  rec <- body_json(api("/analyses/cfa", "POST", json = list(dataset_id = id, settings = st)))
  l <- local_ds()
  ref <- analysis_cfa(l$data, l$config, st, "h")
  expect_identical(rec$results$fit$chisq, ref$results$fit$chisq)
  expect_identical(rec$results$fit$rmsea_ci_upper, ref$results$fit$rmsea_ci_upper)
  expect_identical(vapply(rec$results$loadings, `[[`, 0, "std"), ref$results$loadings$std)
  expect_identical(rec$figures[[1]]$type, "path")
  s <- api(sprintf("/analyses/%s/script", rec$analysis_id))
  expect_match(httr2::resp_body_string(s), "lavaan::cfa(model, data = x, estimator = \"ML\", likelihood = \"wishart\"", fixed = TRUE)
})

test_that("M6 karşılaştırma ve M7 güvenirlik HTTP üzerinden yerel hesapla aynı", {
  one <- list(factors = list(list(name = "G", items = items)))
  st <- list(models = list(list(name = "İki", model = m_nc), list(name = "Tek", model = one)), estimator = "MLR")
  rec <- body_json(api("/analyses/cfa/compare", "POST", json = list(dataset_id = id, settings = st)))
  l <- local_ds()
  ref <- analysis_cfa_compare(l$data, l$config, st, "h")
  expect_identical(rec$results$tests[[1]]$chisq_diff, ref$results$tests[[1]]$chisq_diff)
  expect_identical(rec$results$tests[[1]]$method, "satorra.bentler.2001")
  rl <- body_json(api("/analyses/reliability", "POST", json = list(dataset_id = id, settings = list(model = m_nc))))
  rr <- analysis_reliability(l$data, l$config, list(model = m_nc), "h")
  expect_identical(rl$results$omega$N, rr$results$omega$N)
  expect_identical(rl$results$htmt$N$C, rr$results$htmt$N$C)
})

test_that("Bollen–Stine kilidi HTTP'de 422 ve gerekçeli iletiyle döner", {
  r <- api("/analyses/cfa", "POST", json = list(dataset_id = id, settings = list(model = m_nc, estimator = "MLR", bootstrap = 200L)))
  expect_identical(httr2::resp_status(r), 422L)
  b <- body_json(r)
  expect_identical(b$error$code, "bollen_stine_unavailable")
  expect_match(b$error$message_tr, "yalnızca ML", fixed = TRUE)
})
