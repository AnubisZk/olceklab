# No model call: the number-bearing text is derived from the real R analysis.
test_that("approved AI text is labelled in preview and Word; disclosure identifies provider/model", {
  hs <- example_ds("holzinger")
  rec <- analysis_cfa(hs$clean$data, hs$config, list(model = default_model_from_subscales(hs$config)), hs$hash)
  analysis_store(rec, "test-report-ai")
  text <- paste("CFI =", rpt_kv(rec, "T1", "cfi", "tr", "value"))
  ai <- list(list(record_id = rec$analysis_id, text = text, check_passed = TRUE, provider = "api", model = "test-model"))
  for (lang in c("tr", "en")) {
    p <- report_preview(rec$analysis_id, lang, ai)
    expect_identical(p$items[[1]]$ai[[1]]$text, text)
    expect_identical(p$items[[1]]$ai[[1]]$label, report_ai_label(lang))
    expect_match(p$note, "api / test-model", fixed = TRUE)
    f <- tempfile(fileext = ".docx")
    writeBin(report_docx(rec$analysis_id, lang, ai_texts = ai), f)
    output <- officer::docx_summary(officer::read_docx(f))$text
    unlink(f)
    expect_true(text %in% output)
    expect_true(report_ai_label(lang) %in% output)
    expect_true(any(grepl("api / test-model", output, fixed = TRUE)))
    expect_false(any(grepl("no AI was used|yapay zekâ kullanılmamıştır", output)))
  }
  expect_match(report_preview(rec$analysis_id, "tr")$note, "yapay zekâ kullanılmamıştır")
  invalid <- ai; invalid[[1]]$check_passed <- FALSE
  expect_error(report_preview(rec$analysis_id, ai_texts = invalid), "Yapay zekâ metni")
  expect_error(report_docx(rec$analysis_id, ai_texts = invalid), "Yapay zekâ metni")
  invalid <- ai; invalid[[1]]$record_id <- "other"
  expect_error(report_preview(rec$analysis_id, ai_texts = invalid), "Yapay zekâ metni")
  invalid <- ai; invalid[[1]]$check_passed <- "true"
  expect_error(report_preview(rec$analysis_id, ai_texts = invalid), "Yapay zekâ metni")
  expect_error(report_preview(rec$analysis_id, ai_texts = c(ai, ai)), "Yapay zekâ metni")
})
