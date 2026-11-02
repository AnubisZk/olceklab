# R motoru testleri. engine/ klasöründe çalıştırın:  Rscript tests/testthat.R
library(testthat)
dir.create("test-results", showWarnings = FALSE)
reporter <- MultiReporter$new(list(
  ProgressReporter$new(show_praise = FALSE),
  JunitReporter$new(file = file.path(normalizePath("test-results"), "testthat.xml"))
))
test_dir("tests/testthat", reporter = reporter, stop_on_failure = TRUE)
