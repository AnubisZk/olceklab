# M10 — Word raporu, önizleme ve CSV (SPEC §7 M10; Faz 5 kabul: "Word raporu açılır").
# Rapordaki her tablo hücresi analiz kaydındaki R-biçimli metnin aynısıdır; şablon metinlerdeki her sayı kayıttan gelir.

hs <- example_ds("holzinger")
m3 <- default_model_from_subscales(hs$config)
recs <- list(
  hs$clean_record,
  analysis_cfa(hs$clean$data, hs$config, list(model = m3), hs$hash),
  analysis_reliability(hs$clean$data, hs$config, list(model = m3), hs$hash),
  analysis_invariance(hs$clean$data, hs$config, list(model = m3), hs$hash))
for (r in recs) analysis_store(r, "test-report")
ids <- vapply(recs, `[[`, "", "analysis_id")

docx_text <- function(raw) {
  f <- tempfile(fileext = ".docx"); on.exit(unlink(f)); writeBin(raw, f)
  officer::docx_summary(officer::read_docx(f))
}

test_that("Word raporu geçerli bir .docx'tir ve officer ile yeniden okunur; tablo hücreleri kayıttaki biçimli metinlerdir", {
  raw <- report_docx(ids, "tr", "Deneme")
  expect_identical(raw[1:2], as.raw(c(0x50, 0x4b)))
  s <- docx_text(raw)
  pars <- s$text[s$content_type == "paragraph"]
  expect_true("Deneme" %in% pars)
  expect_true(all(c("Veri temizleme", "Doğrulayıcı faktör analizi", "Güvenirlik ve geçerlik", "Ölçme değişmezliği") %in% pars))
  ntab <- sum(vapply(recs, function(r) length(r$tables), 0L))
  expect_true(all(sprintf("Tablo %d", seq_len(ntab)) %in% pars))
  cells <- s[s$content_type == "table cell", ]
  tabs <- unlist(lapply(recs, `[[`, "tables"), recursive = FALSE)
  expect_identical(length(unique(cells$table_index)), length(tabs))
  for (k in seq_along(tabs)) {
    t <- tabs[[k]]
    got <- cells[cells$table_index == k, ]
    body <- got[!got$is_header, ]; head <- got[got$is_header, ]
    keys <- vapply(t$columns, `[[`, "", "key")
    expect_identical(head$text[order(head$cell_id)], vapply(t$columns, `[[`, "", "label_tr"), info = t$id)
    fm <- as.data.frame(t$rows_fmt$tr, stringsAsFactors = FALSE)[, keys, drop = FALSE]
    body <- body[order(body$row_id, body$cell_id), ]
    expect_identical(body$text, as.vector(t(as.matrix(fm))), info = paste(k, t$id))
  }
  expect_true(any(startsWith(pars, "Not. Kaynak: lavaan::cfa")))
  expect_true(any(grepl("Horn|Chen, F. F. \\(2007\\)", pars)))
  expect_true(any(grepl("^Rosseel", pars)))  # lavaan'ın kendi citation() kaydı
})

test_that("İngilizce rapor: Table N, nokta ondalık ve İngilizce başlıklar", {
  s <- docx_text(report_docx(ids[2], "en"))
  pars <- s$text[s$content_type == "paragraph"]
  expect_true(all(c("Confirmatory factor analysis", "Table 1", "Method", "Results") %in% pars))
  cfi <- recs[[2]]$tables[[1]]$rows_fmt$en$value[recs[[2]]$tables[[1]]$rows_fmt$en$key == "cfi"]
  expect_true(any(grepl(paste0("CFI = ", cfi), pars, fixed = TRUE)))
  expect_false(any(grepl("Tablo ", pars, fixed = TRUE)))
})

test_that("şablon metinlerdeki her sayı analiz kaydından gelir (uydurma sayı yok)", {
  num_tokens <- function(x) unlist(regmatches(x, gregexpr("[−-]?[0-9]*[,.]?[0-9]+", x)))
  for (k in 2:4) {
    rec <- recs[[k]]
    pv <- report_preview(rec$analysis_id, "tr")$items[[1]]
    txt <- vapply(c(pv$methods, pv$results), function(p) paste(vapply(p, `[[`, "", "text"), collapse = ""), "")
    allowed <- c(unlist(lapply(rec$tables, function(t) num_tokens(unlist(t$rows_fmt$tr)))),
                 num_tokens(unlist(lapply(rec$tables, `[[`, "title_tr"))), as.character(seq_len(10)), "90", "10000",
                 "1951", "1999", "1981", "2015", "2002", "2007", "2016", "0", "2",
                 num_tokens(fmt_num(range(rec$results$loadings$std, na.rm = TRUE), 3L, "tr", TRUE)),
                 if (is.null(rec$results$htmt)) character() else num_tokens(fmt_num(unlist(rec$results$htmt), 3L, "tr")),
                 num_tokens(vapply(unlist(rec$settings$criteria), function(v) fmt_num(v, 3L, "tr", TRUE), "")),
                 num_tokens(vapply(unlist(rec$settings$criteria), function(v) fmt_num(v, 2L, "tr", TRUE), "")))
    tok <- num_tokens(txt)
    expect_true(length(tok) > 0L, info = rec$module)
    expect_true(all(tok %in% allowed), info = paste(rec$module, paste(setdiff(tok, allowed), collapse = " ")))
  }
})

test_that("önizleme: tablo numaraları ardışık; italik parçalar; DFA bulgusu T1'deki değerlerle", {
  pv <- report_preview(ids, "tr")
  nos <- unlist(lapply(pv$items, function(it) vapply(it$tables, `[[`, 0L, "number")))
  expect_identical(nos, seq_along(nos))
  cfa <- pv$items[[2]]
  res <- paste(vapply(cfa$results[[1]], `[[`, "", "text"), collapse = "")
  t1 <- recs[[2]]$tables[[1]]$rows_fmt$tr
  for (k in c("chisq", "cfi", "rmsea", "srmr")) expect_match(res, t1$value[t1$key == k], fixed = TRUE)
  expect_true(any(vapply(cfa$results[[1]], function(s) isTRUE(s$italic) && s$text %in% c("χ", "p"), logical(1))))
  expect_match(pv$note, "yapay zekâ kullanılmamıştır", fixed = TRUE)
})

test_that("simülasyon raporu SİMÜLASYON etiketini ve sınırlılıklar paragrafını taşır", {
  body <- list(population = list(
    factors = list(list(name = "F1", items = c("y1", "y2", "y3"))), loadings = list(y1 = .7, y2 = .6, y3 = .65),
    data_type = "continuous"), conditions = list(N = c(100, 200)), estimators = "ML", reps = 3, chunk_size = 3, seed = 5,
    analyses = list(cfa = TRUE, reliability = TRUE))
  sid <- sim_job_create(body); sim_job_run_sync(sid)
  rec <- sim_results_for(.olceklab$jobs[[sid]]$dir, sid)
  analysis_store(rec, NA_character_)
  pv <- report_preview(rec$analysis_id, "tr")$items[[1]]
  lim <- vapply(pv$limitations, function(p) paste(vapply(p, `[[`, "", "text"), collapse = ""), "")
  expect_identical(lim[1], SIM_LABEL_TR)
  expect_match(lim[2], "Hoenig ve Heisey", fixed = TRUE)
  s <- docx_text(report_docx(rec$analysis_id, "tr"))
  expect_true(any(s$text == "Sınırlılıklar"))
  expect_true(any(grepl("sentetik veri", s$text[s$content_type == "paragraph"], fixed = TRUE)))
})

test_that("CSV: biçimli (TR ';' ve BOM) ve ham (17 anlamlı basamak, kayıpsız)", {
  t1 <- recs[[3]]$tables[[1]]
  f <- report_table_csv(recs[[3]], "T1", "tr")
  expect_true(startsWith(f, "﻿"))
  d <- utils::read.csv(text = sub("^﻿", "", f), sep = ";", check.names = FALSE, colClasses = "character")
  expect_identical(names(d), vapply(t1$columns, `[[`, "", "label_tr"))
  expect_identical(d[[3]], t1$rows_fmt$tr$alpha)
  r <- report_table_csv(recs[[3]], "T1", "en", "raw")
  d2 <- utils::read.csv(text = sub("^﻿", "", r), check.names = FALSE)
  expect_identical(d2[["α"]], t1$rows$alpha)
  expect_identical(d2[["ω"]], t1$rows$omega)
  e <- tryCatch(report_table_csv(recs[[3]], "T9"), error = function(e) e)
  expect_identical(e$code, "table_not_found")
})

test_that("rapor hataları: boş liste 422, bilinmeyen analiz 404", {
  expect_identical(tryCatch(report_docx(list()), error = function(e) e$code), "report_empty")
  expect_identical(tryCatch(report_docx("yok"), error = function(e) e$code), "analysis_not_found")
})

test_that("Word raporu LibreOffice ile açılır (PDF'e dönüştürülebilir)", {
  soffice <- Sys.which("soffice")
  skip_if(!nzchar(soffice), "LibreOffice yok")
  d <- tempfile("rapor-"); dir.create(d); on.exit(unlink(d, recursive = TRUE))
  f <- file.path(d, "rapor.docx"); writeBin(report_docx(ids, "tr"), f)
  system2(soffice, c("--headless", "--convert-to", "pdf", "--outdir", d, f), stdout = FALSE, stderr = FALSE,
          env = c(paste0("HOME=", d)))
  pdf <- file.path(d, "rapor.pdf")
  expect_true(file.exists(pdf))
  expect_gt(file.size(pdf), 10000)
})

test_that("önizleme JSON'unda kaynakça her zaman dizidir (0 ya da 1 kaynakta da)", {
  j0 <- jsonlite::parse_json(as.character(to_json(report_preview(ids[2], "tr"))), simplifyVector = FALSE)
  expect_true(is.list(j0$references))
  expect_match(as.character(to_json(report_preview(ids[2], "tr"))), "\"references\":\\[", fixed = FALSE)
  rel_only <- jsonlite::parse_json(as.character(to_json(report_preview(ids[3], "tr"))), simplifyVector = FALSE)
  expect_true(is.list(rel_only$references) && length(rel_only$references) >= 1L)
})
