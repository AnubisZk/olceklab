# M1 — veri okuma, kimlik sütunu algılama, sütun rolleri ve temizleme.

csv_bytes <- function(lines) charToRaw(enc2utf8(paste(lines, collapse = "\n")))

test_that("virgül ayraçlı CSV okunur; Türkçe sütun adları korunur", {
  r <- parse_upload(csv_bytes(c("Öğrenci_Sınıfı,M1,M2", "A,1,2", "B,3,4")), "veri.csv")
  expect_identical(names(r$data), c("Öğrenci_Sınıfı", "M1", "M2"))
  expect_identical(r$data$M1, c(1, 3))
  expect_identical(r$delimiter, ",")
  expect_match(r$hash, "^sha256:[0-9a-f]{64}$")
})

test_that("noktalı virgül ayraçlı CSV'de ondalık virgülü sayıya çevrilir; BOM atılır", {
  raw <- c(as.raw(c(0xEF, 0xBB, 0xBF)), csv_bytes(c("a;b", "1,5;2", "3;\"4\"")))
  r <- parse_upload(raw, "v.csv")
  expect_identical(names(r$data), c("a", "b"))
  expect_identical(r$data$a, c(1.5, 3))
  expect_identical(r$data$b, c(2, 4))
})

test_that("eksik değerler NA olur; sayısal olmayan sütun metin kalır", {
  r <- parse_upload(csv_bytes(c("a,b", "1,x", ",y", "3,")), "v.csv")
  expect_identical(r$data$a, c(1, NA, 3))
  expect_identical(r$data$b, c("x", "y", NA))
})

test_that("UTF-8 olmayan dosya açık hatayla reddedilir", {
  latin1 <- c(csv_bytes("ad,puan"), as.raw(0x0A), as.raw(c(0xD6, 0x7A, 0x6C, 0x2C, 0x31)))
  e <- tryCatch(parse_upload(latin1, "v.csv"), error = function(e) e)
  expect_identical(e$code, "not_utf8")
  expect_identical(e$status, 422L)
})

test_that("hatalı dosyalar standart hata kodlarıyla reddedilir", {
  code <- function(expr) tryCatch(expr, error = function(e) e$code)
  expect_identical(code(parse_upload(raw(0), "v.csv")), "empty_file")
  expect_identical(code(parse_upload(csv_bytes(c("a,b", "1,2")), "v.sav")), "unsupported_format")
  expect_identical(code(parse_upload(csv_bytes(c("a,a", "1,2")), "v.csv")), "duplicate_column_name")
  expect_identical(code(parse_upload(csv_bytes(c("a,b", "1,2,3,4")), "v.csv")), "parse_error")
  expect_identical(code(parse_upload(csv_bytes("a,b"), "v.csv")), "no_rows")
  withr::local_envvar(MAX_UPLOAD_MB = "0.000001")
  expect_identical(code(parse_upload(csv_bytes(c("a,b", "1,2")), "v.csv")), "file_too_large")
})

test_that("XLSX, readxl ile aynı değerlerle okunur ve geçici dosya kalmaz", {
  path <- readxl::readxl_example("datasets.xlsx")
  raw <- readBin(path, "raw", file.size(path))
  shm_before <- if (dir.exists("/dev/shm")) list.files("/dev/shm", pattern = "^olceklab-") else character()
  r <- parse_upload(raw, "datasets.xlsx")
  ref <- as.data.frame(readxl::read_excel(path, sheet = 1))
  expect_identical(names(r$data), names(ref))
  for (nm in names(ref)) {
    if (is.numeric(ref[[nm]])) expect_equal(r$data[[nm]], ref[[nm]], tolerance = 0, info = nm)
    else expect_identical(r$data[[nm]], ref[[nm]], info = nm)
  }
  shm_after <- if (dir.exists("/dev/shm")) list.files("/dev/shm", pattern = "^olceklab-") else character()
  expect_identical(shm_after, shm_before)
})

# Sağlama algoritmasıyla geçerli T.C. kimlik numarası üretir (test verisi).
make_tc <- function(first9) {
  d <- as.integer(strsplit(first9, "")[[1]])
  d10 <- ((sum(d[c(1, 3, 5, 7, 9)]) * 7 - sum(d[c(2, 4, 6, 8)])) %% 10 + 10) %% 10
  d11 <- (sum(d) + d10) %% 10
  paste0(first9, d10, d11)
}

test_that("T.C. kimlik numarası sağlaması doğru denetlenir", {
  valid <- vapply(c("123456789", "987654321", "100000001"), make_tc, "")
  expect_true(all(tc_kimlik_valid(valid)))
  broken <- valid
  substr(broken, 11, 11) <- as.character((as.integer(substr(valid, 11, 11)) + 1) %% 10)
  expect_false(any(tc_kimlik_valid(broken)))
  expect_false(tc_kimlik_valid("01234567890"))
  expect_false(tc_kimlik_valid("1234"))
})

test_that("kimlik sütunları ad, değer ve benzersiz metin üzerinden önerilir", {
  df <- data.frame(Ad_Soyad = paste("Kişi", 1:12), TCKN_degil = vapply(sprintf("%09d", 100000000 + 1:12), make_tc, ""),
                   Rumuz = paste0("r", 1:12), M1 = rep(1:3, 4), stringsAsFactors = FALSE)
  s <- detect_identifier_columns(df)
  got <- stats::setNames(vapply(s, `[[`, "", "reason"), vapply(s, `[[`, "", "column"))
  expect_identical(got[["Ad_Soyad"]], "name")
  expect_identical(got[["TCKN_degil"]], "name")
  expect_identical(got[["Rumuz"]], "unique_text")
  expect_false("M1" %in% names(got))
  df2 <- data.frame(kod = vapply(sprintf("%09d", 200000000 + 1:12), make_tc, ""), stringsAsFactors = FALSE)
  expect_identical(detect_identifier_columns(df2)[[1]]$reason, "tc_kimlik")
})

test_that("sütun rolleri doğrulanır", {
  df <- data.frame(g = c("a", "b"), m1 = 1:2, m2 = 2:1, t = c("x", "y"), stringsAsFactors = FALSE)
  code <- function(body) tryCatch({ build_config(df, body); "ok" }, error = function(e) e$code)
  expect_identical(code(list(roles = list(m1 = "item"))), "too_few_items")
  expect_identical(code(list(roles = list(m1 = "item", t = "item"))), "item_not_numeric")
  expect_identical(code(list(roles = list(m1 = "item", m2 = "item", yok = "id"))), "unknown_column")
  expect_identical(code(list(roles = list(m1 = "item", m2 = "item", g = "grp"))), "invalid_role")
  expect_identical(code(list(roles = list(m1 = "item", m2 = "item", g = "group", t = "group"))), "too_many_groups")
  expect_identical(code(list(roles = list(m1 = "item", m2 = "item"), items = list(m1 = list(min = 5, max = 1)))), "invalid_range")
  expect_identical(code(list(roles = list(m1 = "item", m2 = "item"), items = list(m1 = list(reverse = TRUE)))), "reverse_needs_range")
  cfg <- build_config(df, list(roles = list(m1 = "item", m2 = "item", g = "group"),
                               items = list(m1 = list(min = 1, max = 5, reverse = TRUE, subscale = "A"))))
  expect_identical(cfg$group, "g")
  expect_identical(cfg$items$reverse, c(TRUE, FALSE))
})

# --- Temizleme ----------------------------------------------------------------
# Test verisi: her sorun türü bilinen satırlara yerleştirilir. Beklenen sayılar,
# kuralların sıralı tanımını izleyen bağımsız bir satır döngüsüyle hesaplanır.

clean_fixture <- function() {
  set.seed(1)
  n <- 60
  df <- data.frame(sinif = sample(c("5", "6", "7"), n, TRUE),
                   M1 = sample(1:5, n, TRUE), M2 = sample(1:5, n, TRUE),
                   M3 = sample(1:5, n, TRUE), M4 = sample(1:5, n, TRUE), stringsAsFactors = FALSE)
  df$sinif[c(1, 2)] <- c(NA, "9")                    # geçersiz grup
  df$M2[c(3, 4)] <- c(7, 2.5)                        # aralık dışı ve tam sayı değil
  df$M3[c(5, 6, 7)] <- NA                            # eksik
  df[8, c("M1", "M2", "M3", "M4")] <- 4              # ham yanıtta düz yanıt
  df[9, c("M1", "M2", "M3", "M4")] <- c(5, 5, 1, 5)  # M3 ters: ham hâli düz değil, ters kodlanınca hep 5
  df$M3[1] <- NA                                     # ilk kurala da uyan satır: yalnızca bir kez sayılmalı
  df
}

reference_clean_counts <- function(df, items, valid, ranges) {
  removed <- c(invalid_group = 0L, out_of_range = 0L, missing = 0L, straightline = 0L)
  for (r in seq_len(nrow(df))) {
    row <- df[r, ]
    vals <- unlist(row[items])
    if (is.na(row$sinif) || !(row$sinif %in% valid)) { removed["invalid_group"] <- removed["invalid_group"] + 1L; next }
    if (any(!is.na(vals) & (vals < ranges[1] | vals > ranges[2] | vals != floor(vals)))) { removed["out_of_range"] <- removed["out_of_range"] + 1L; next }
    if (any(is.na(vals))) { removed["missing"] <- removed["missing"] + 1L; next }
    if (length(unique(vals)) == 1L) { removed["straightline"] <- removed["straightline"] + 1L; next }
  }
  removed
}

fixture_config <- function(df) {
  build_config(df, list(roles = list(sinif = "group", M1 = "item", M2 = "item", M3 = "item", M4 = "item"),
                        items = list(M1 = list(min = 1, max = 5), M2 = list(min = 1, max = 5),
                                     M3 = list(min = 1, max = 5, reverse = TRUE), M4 = list(min = 1, max = 5)),
                        group_valid_values = c("5", "6", "7")))
}

test_that("kurallar CL-1 sırasıyla uygulanır; her satır yalnızca ilk kuralda sayılır", {
  df <- clean_fixture()
  cl <- clean_dataset(df, fixture_config(df), list())
  ref <- reference_clean_counts(df, c("M1", "M2", "M3", "M4"), c("5", "6", "7"), c(1, 5))
  got <- stats::setNames(cl$steps$removed, cl$steps$step)
  expect_identical(got[names(ref)], ref)
  expect_identical(cl$steps$step, c("invalid_group", "out_of_range", "missing", "straightline"))
  expect_identical(cl$n_final, nrow(df) - sum(ref))
  expect_identical(cl$steps$remaining[4], cl$n_final)
})

test_that("düz yanıt ters kodlamadan önce, ham yanıtlarda aranır", {
  df <- clean_fixture()
  cl <- clean_dataset(df, fixture_config(df), list())
  # 9. satır hamda düz değil; temiz veride kalmalı ve ters kodlanmış M3 = 5 olmalı
  kept_raw <- df[!(seq_len(nrow(df)) %in% c(1, 2, 3, 4, 5, 6, 7, 8)), ]
  kept_raw <- kept_raw[apply(kept_raw[, c("M1", "M2", "M3", "M4")], 1, function(r) length(unique(r)) > 1), ]
  expect_identical(nrow(cl$data), nrow(kept_raw))
  expect_identical(cl$data$M3, 6 - kept_raw$M3)
  expect_identical(cl$data$M1, kept_raw$M1)
})

test_that("kurallar tek tek kapatılabilir", {
  df <- clean_fixture()
  cl <- clean_dataset(df, fixture_config(df), list(invalid_group = FALSE, straightline = FALSE, reverse = FALSE))
  expect_identical(cl$steps$step, c("out_of_range", "missing"))
  expect_identical(cl$reversed, character())
  expect_identical(cl$data$M3, df$M3[stats::complete.cases(df[, c("M1", "M2", "M3", "M4")]) &
                                       !(seq_len(nrow(df)) %in% c(3, 4))])
})

test_that("madde bazında eksiklik oranı ham veriden hesaplanır", {
  df <- clean_fixture()
  cl <- clean_dataset(df, fixture_config(df), list())
  expect_identical(unname(cl$item_missing), unname(colMeans(is.na(df[, c("M1", "M2", "M3", "M4")]))))
})

test_that("temizleme kaydı özet metni ve tabloları içerir", {
  df <- clean_fixture()
  out <- analysis_clean(df, fixture_config(df), list(), "sha256:test")
  rec <- out$record
  expect_identical(rec$module, "data_clean")
  expect_match(rec$results$summary_tr, "^Ham: 60 → hatalı grup")
  expect_match(rec$results$summary_en, "analysed: ")
  expect_identical(rec$tables[[1]]$rows_fmt$en$label_tr[1], "Raw data")
})

test_that("ters madde yoksa düz yanıt kuralı için uyarı verilir (CL-2)", {
  df <- clean_fixture()
  cfg <- fixture_config(df)
  cfg$items$reverse <- FALSE
  rec <- analysis_clean(df, cfg, list(), "h")$record
  expect_true("straightline_no_reverse" %in% vapply(rec$warnings, `[[`, "", "code"))
})

test_that("örnek veri setleri yüklenir ve özetleri belirlenimcidir", {
  h1 <- load_example("holzinger"); h2 <- load_example("holzinger")
  expect_identical(h1$hash, h2$hash)
  expect_identical(nrow(h1$data), nrow(lavaan::HolzingerSwineford1939))
  b <- load_example("bfi")
  expect_identical(nrow(b$data), nrow(psych::bfi))
  expect_true(b$suggested_config$items$C4$reverse)
  expect_identical(tryCatch(load_example("yok"), error = function(e) e$code), "example_not_found")
})
