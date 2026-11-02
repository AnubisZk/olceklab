# §11.3 test düzeneğinin kendisinin denetimi (CI'da çalışır; gerçek veri kullanmaz).
# Sentetik ama BİDEKÇET düzenindeki iki Excel dosyası (fixtures/bidekcet_synthetic) üzerinde:
#   (a) belge sahibinin referans betiği (tests/reference/bidekcet_referans.R) ayrı bir R sürecinde çalışır,
#   (b) platform aynı dosyaları kendi yükleme → temizleme → analiz yoluyla işler,
# ve iki yolun bütün ara ve son sonuçları karşılaştırılır. Böylece gizli testte kullanılan düzenek
# (dosya bulma, sütun rolleri, temizleme sırası, model sözdizimi, ayarlar) gerçek veri olmadan doğrulanır.

fx_dir <- file.path(engine_dir, "tests", "testthat", "fixtures", "bidekcet_synthetic")
ref_script <- file.path(engine_dir, "tests", "reference", "bidekcet_referans.R")

run_reference <- function(files) {
  callr::r(function(script) {
    e <- new.env()
    printed <- utils::capture.output(sys.source(script, envir = e, keep.source = FALSE))
    lv <- list(Ortaokul = e$o, Lise = e$l)
    per <- lapply(lv, function(x) {
      f4 <- lavaan::cfa(e$m4, x, likelihood = "wishart"); f1 <- lavaan::cfa(e$m1, x, likelihood = "wishart")
      a <- lavaan::anova(f4, f1)
      fw <- lavaan::cfa(e$m4, x, ordered = e$it, estimator = "WLSMV", std.lv = TRUE)
      list(alpha = psych::alpha(x)$total$raw_alpha, kmo = psych::KMO(x)$MSA,
           m4_chisq = as.numeric(lavaan::fitMeasures(f4, "chisq")), m4_df = as.numeric(lavaan::fitMeasures(f4, "df")),
           m1_chisq = as.numeric(lavaan::fitMeasures(f1, "chisq")), m1_df = as.numeric(lavaan::fitMeasures(f1, "df")),
           dchisq = a[2, "Chisq diff"], ddf = a[2, "Df diff"],
           wlsmv = lapply(c(cfi.scaled = "cfi.scaled", cfi.robust = "cfi.robust", rmsea.scaled = "rmsea.scaled", rmsea.robust = "rmsea.robust"),
                          function(k) as.numeric(lavaan::fitMeasures(fw, k))),
           data = x)
    })
    list(steps = rbind(e$a1, e$a2, e$a3, e$a4), n_raw = c(Ortaokul = e$n_o_ham, Lise = e$n_l_ham),
         pa = c(Ortaokul = e$po$ncomp, Lise = e$pl$ncomp), per = per,
         h_abs = unclass(e$h_abs), h_raw = unclass(e$h_raw), printed = printed)
  }, args = list(script = ref_script),
  env = c(callr::rcmd_safe_env(), LANG = "C.UTF-8", LC_ALL = "C.UTF-8",
          BIDEKCET_ORTAOKUL_XLSX = files$ortaokul, BIDEKCET_LISE_XLSX = files$lise))
}

test_that("sentetik BİDEKÇET dosyaları başlıklarından bulunur; dosya adları gerekmez", {
  files <- withr::with_envvar(c(BIDEKCET_ORTAOKUL_FILE = "", BIDEKCET_LISE_FILE = ""), bidekcet_locate(fx_dir))
  expect_identical(basename(files$ortaokul), "ortaokul_sentetik.xlsx")
  expect_identical(basename(files$lise), "lise_sentetik.xlsx")
})

test_that("platform ile belge sahibinin referans betiği aynı dosyalarda aynı sonuçları verir", {
  files <- withr::with_envvar(c(BIDEKCET_ORTAOKUL_FILE = "", BIDEKCET_LISE_FILE = ""), bidekcet_locate(fx_dir))
  ref <- run_reference(files)
  got <- bidekcet_platform(files, pa_seed = 1L, pa_iter = 200L)
  lv_ref <- c(ortaokul = "Ortaokul", lise = "Lise")
  for (lv in bidekcet_levels) {
    R <- lv_ref[[lv]]; g <- got[[lv]]; r <- ref$per[[R]]
    # Temizleme: ham satır ve her adımdan sonra kalan satır (sıra: sınıf → eksik → aralık → düz yanıt)
    expect_identical(g$n_raw, as.integer(ref$n_raw[[R]]), info = lv)
    expect_identical(unname(g$remaining[c("invalid_group", "missing", "out_of_range", "straightline")]),
                     as.integer(ref$steps[, R]), info = lv)
    # Aynı satırlar, aynı sırayla, aynı değerlerle
    expect_identical(unname(as.matrix(g$data[, bidekcet_item(lv, bidekcet_k)])), unname(as.matrix(r$data)), info = lv)
    expect_identical(g$alpha, r$alpha, info = lv)
    expect_identical(g$kmo, r$kmo, info = lv)
    expect_identical(g$m4_chisq, r$m4_chisq, info = lv)
    expect_identical(g$m4_df, r$m4_df, info = lv)
    expect_identical(g$m1_chisq, r$m1_chisq, info = lv)
    expect_identical(g$dchisq, r$dchisq, info = lv)
    expect_identical(g$ddf, r$ddf, info = lv)
    for (k in names(r$wlsmv)) expect_identical(g$wlsmv[[gsub(".", "_", k, fixed = TRUE)]], unname(r$wlsmv[[k]]), info = paste(lv, k))
  }
  # HTMT (ortaokul): absolute = TRUE ve FALSE
  fn <- c("BK", "FM", "KD", "CT")
  for (a in fn) for (b in fn) {
    expect_identical(got$ortaokul$htmt_abs[[a]][[b]], ref$h_abs[a, b], info = paste("abs", a, b))
    expect_identical(got$ortaokul$htmt_raw[[a]][[b]], ref$h_raw[a, b], info = paste("raw", a, b))
  }
  # Paralel analiz: referans betiği set.seed(1) ve psych'in çok çekirdekli varsayılanıyla çalışır (özdeğerler
  # tohumla tekrarlanamaz, SPEC_REVIEW PA-1); önerilen bileşen sayısı yine de aynı olmalıdır.
  for (lv in bidekcet_levels) expect_identical(got[[lv]]$pa_pc, as.integer(ref$pa[[lv_ref[[lv]]]]), info = lv)
  # Referans betiğinin yazdırdığı temizleme tablosu da aynı sayıları gösterir
  expect_true(any(grepl(sprintf("duz_yanit_sonrasi +%d +%d", got$ortaokul$n_final, got$lise$n_final), ref$printed)))
})

test_that("sentetik dosyalarda temizleme adımları beklenen satırları çıkarır (düzenek kendi içinde tutarlı)", {
  files <- withr::with_envvar(c(BIDEKCET_ORTAOKUL_FILE = "", BIDEKCET_LISE_FILE = ""), bidekcet_locate(fx_dir))
  up <- parse_upload(readBin(files$lise, "raw", file.size(files$lise)), basename(files$lise))
  expect_true(all(paste0("Madde", c(1, 7, 13)) %in% names(up$data)))  # başlıktaki boşluklar atıldı
  # make_fixtures.R'de yerleştirilen sorunlar: 3 geçersiz sınıf, 5 eksik satır (biri aynı zamanda aralık dışı),
  # 1 aralık dışı, 10 düz yanıt
  got <- bidekcet_platform_level(files$lise, "lise", pa_iter = 20L)
  expect_identical(unname(got$removed[c("invalid_group", "missing", "out_of_range", "straightline")]), c(3L, 5L, 1L, 10L))
  got_o <- bidekcet_platform_level(files$ortaokul, "ortaokul", pa_iter = 20L)
  expect_identical(unname(got_o$removed[c("invalid_group", "missing", "out_of_range", "straightline")]), c(2L, 1L, 1L, 4L))
})
