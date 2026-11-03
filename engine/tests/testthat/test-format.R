# Biçim kuralları (SPEC M10; SPEC_REVIEW REP-3). Beklenen metinler istatistik değil,
# biçim kuralının tanımıdır.

test_that("Türkçe ondalık virgülü, İngilizce nokta", {
  expect_identical(fmt_num(3.14159, 2, "tr"), "3,14")
  expect_identical(fmt_num(3.14159, 2, "en"), "3.14")
})

test_that("binlik ayraç dile göre", {
  expect_identical(fmt_num(1517.788, 2, "tr"), "1.517,79")
  expect_identical(fmt_num(1517.788, 2, "en"), "1,517.79")
  expect_identical(fmt_int(200000, "tr"), "200.000")
  expect_identical(fmt_int(200000, "en"), "200,000")
})

test_that("APA: 1'i geçemeyen istatistikte baştaki sıfır yazılmaz", {
  expect_identical(fmt_num(0.794, 3, "tr", bounded = TRUE), ",794")
  expect_identical(fmt_num(0.794, 3, "en", bounded = TRUE), ".794")
  expect_identical(fmt_num(-0.25, 2, "en", bounded = TRUE), "−.25")
  expect_identical(fmt_num(1, 3, "en", bounded = TRUE), "1.000")
})

test_that("eksi işareti U+2212; sıfıra yuvarlanan negatif işaretsiz", {
  expect_identical(fmt_num(-1.5, 1, "en"), "−1.5")
  expect_identical(fmt_num(-0.0004, 3, "en"), "0.000")
})

test_that("eksik ve sonsuz değer uzun tire olur", {
  expect_identical(fmt_num(c(NA, Inf), 2, "tr"), c("—", "—"))
})

test_that("p değeri kuralları", {
  expect_identical(fmt_p(0.0004, "tr"), "< ,001")
  expect_identical(fmt_p(0.0004, "en"), "< .001")
  expect_identical(fmt_p(0.045, "tr"), ",045")
})

test_that("yüzde işareti Türkçede başta, İngilizcede sonda", {
  expect_identical(fmt_pct(0.125, "tr"), "%12,5")
  expect_identical(fmt_pct(0.125, "en"), "12.5%")
  expect_identical(fmt_pct(-0.01, "tr"), "\u2212%1,0")
  expect_identical(fmt_pct(-0.01, "en"), "\u22121.0%")
  expect_identical(fmt_pct(NA, "tr"), FMT_MISSING)
})

test_that("make_table iki dilde biçimli satır üretir, ham değeri korur", {
  t <- make_table("T1", "Başlık", "Title",
                  list(tbl_col("a", "A", "A", "num", 3L, TRUE), tbl_col("b", "B", "B", "text")),
                  data.frame(a = 0.123456789, b = "x"))
  expect_identical(t$rows$a, 0.123456789)
  expect_identical(t$rows_fmt$tr$a, ",123")
  expect_identical(t$rows_fmt$en$a, ".123")
  expect_identical(t$columns[[1]]$type, "number")
  expect_error(make_table("T", "", "", list(tbl_col("yok", "", "")), data.frame(a = 1)), "olmayan")
})

test_that("süre biçimi R'de üretilir", {
  expect_identical(fmt_duration(3725, "tr"), "1 sa 2 dk 5 sn")
  expect_identical(fmt_duration(65, "en"), "1 min 5 s")
  expect_identical(fmt_duration(4.4, "tr"), "4 sn")
  expect_identical(fmt_duration(NA), FMT_MISSING)
})
