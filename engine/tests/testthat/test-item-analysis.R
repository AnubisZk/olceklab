# M2 — beklenen değerler psych fonksiyonları doğrudan çağrılarak üretilir (AGENTS kuralı 2).

bfi_ds <- example_ds("bfi")
bfi_items <- bfi_ds$config$items$name
bfi_x <- bfi_ds$clean$data[, bfi_items]
rec <- analysis_item(bfi_ds$clean$data, bfi_ds$config, list(), bfi_ds$hash, bfi_ds$clean$item_missing)

test_that("madde istatistikleri psych::describe ile birebir aynı", {
  ref <- psych::describe(bfi_x, type = 3)
  got <- rec$results$items
  for (col in c("n", "mean", "sd", "skew", "kurtosis")) {
    expect_identical(got[[col]], ref[bfi_items, col], info = col)
  }
})

test_that("alfa, r.drop ve alpha.drop psych::alpha ile birebir aynı", {
  ref <- quiet(psych::alpha(bfi_x, check.keys = FALSE))$value
  expect_identical(rec$results$alpha, ref$total$raw_alpha)
  expect_identical(rec$results$std_alpha, ref$total$std.alpha)
  expect_identical(rec$results$items$r_drop, ref$item.stats[bfi_items, "r.drop"])
  expect_identical(rec$results$items$alpha_drop, ref$alpha.drop[bfi_items, "raw_alpha"])
})

test_that("alt boyut alfaları psych::alpha ile aynı", {
  rel <- rec$results$reliability
  for (s in c("A", "C", "E", "N", "O")) {
    si <- bfi_items[startsWith(bfi_items, s)]
    ref <- quiet(psych::alpha(bfi_x[, si], check.keys = FALSE))$value$total$raw_alpha
    expect_identical(rel$alpha[rel$scale == s], ref, info = s)
  }
})

test_that("kategori frekansları table() ile aynı; ısı haritası verisi tutarlı", {
  f <- rec$tables[[3]]$rows
  for (i in c("A1", "N5", "O2")) {
    ref <- as.numeric(table(factor(bfi_x[[i]], levels = 1:6)))
    expect_identical(as.numeric(unlist(f[f$item == i, as.character(1:6)])), ref, info = i)
  }
  fig <- rec$figures[[1]]
  expect_identical(fig$type, "heatmap")
  expect_equal(rowSums(fig$data$proportions), rep(1, length(bfi_items)))
})

test_that("taban ve tavan yüzdeleri ve ham eksiklik doğru", {
  got <- rec$results$items
  expect_identical(got$floor[got$item == "A1"], mean(bfi_x$A1 == 1))
  expect_identical(got$ceiling[got$item == "A1"], mean(bfi_x$A1 == 6))
  expect_identical(got$missing_raw[got$item == "A1"], mean(is.na(psych::bfi$A1)))
})

test_that("düşük madde-toplam korelasyonu uyarısı eşik ile tutarlı", {
  ref <- quiet(psych::alpha(bfi_x, check.keys = FALSE))$value
  low <- bfi_items[ref$item.stats[bfi_items, "r.drop"] < 0.30]
  w <- Filter(function(w) w$code == "low_item_total", rec$warnings)
  if (length(low)) {
    expect_length(w, 1L)
    for (i in low) expect_match(w[[1]]$message_tr, i, fixed = TRUE)
  } else {
    expect_length(w, 0L)
  }
})

test_that("boş kategori uyarısı verilir", {
  d <- bfi_ds$clean$data
  d$A1[d$A1 == 6] <- 5
  r2 <- analysis_item(d, bfi_ds$config, list(), "h")
  expect_true(any(vapply(r2$warnings, function(w) w$code == "empty_category" && grepl("A1", w$message_tr), logical(1))))
})

test_that("kayıt SPEC §6.2 yapısında", {
  expect_true(all(c("analysis_id", "module", "dataset_hash", "settings", "engine", "results", "tables",
                    "figures", "warnings", "created_at") %in% names(rec)))
  expect_identical(rec$module, "item_analysis")
  expect_identical(rec$engine$packages$psych, as.character(utils::packageVersion("psych")))
  expect_identical(rec$tables[[1]]$rows_fmt$tr$r_drop, fmt_num(rec$results$items$r_drop, 3, "tr", TRUE))
})

test_that("sürekli maddelerde (HS1939) kategori tablosu üretilmez", {
  h <- example_ds("holzinger")
  r <- analysis_item(h$clean$data, h$config, list(), h$hash)
  expect_length(r$tables, 2L)
  expect_true(all(is.na(r$results$items$floor)))
})

test_that("psych'in ters yönlü madde notu, madde adlarıyla birlikte uyarıya dönüşür", {
  w <- Filter(function(w) w$code == "negative_first_component", rec$warnings)
  expect_length(w, 1L)
  expect_match(w[[1]]$message_tr, "N1", fixed = TRUE)
})
