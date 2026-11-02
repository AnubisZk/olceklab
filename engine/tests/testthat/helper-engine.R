# Motor kodunu yükler. test_dir() çalışma dizinini tests/testthat yapar.
engine_dir <- normalizePath(file.path("..", ".."))
for (f in sort(list.files(file.path(engine_dir, "R"), pattern = "[.]R$",
                          full.names = TRUE, recursive = TRUE))) {
  source(f, local = FALSE, encoding = "UTF-8")
}
