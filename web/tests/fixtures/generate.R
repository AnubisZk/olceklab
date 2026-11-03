# Arayüz testleri için fikstürler: gerçek R motoru çıktıları (uydurma sayı yok).
# Depo kökünden: LANG=C.UTF-8 Rscript web/tests/fixtures/generate.R
engine <- normalizePath("engine")
for (f in sort(list.files(file.path(engine, "R"), pattern = "[.]R$", full.names = TRUE, recursive = TRUE))) source(f, encoding = "UTF-8")
out <- file.path("web", "tests", "fixtures")
write_fx <- function(x, name) writeLines(as.character(to_json(x)), file.path(out, name), useBytes = TRUE)

v <- load_example("bfi")
ds <- list(id = "fixture-bfi", data = v$data, hash = v$hash, filename = v$filename,
           source = list(type = "example", name = "bfi", label = v$source), suggested_config = v$suggested_config)
write_fx(dataset_overview(ds), "bfi_overview.json")
cfg <- build_config(ds$data, v$suggested_config)
cl <- analysis_clean(ds$data, cfg, list(), ds$hash)
write_fx(cl$record, "bfi_clean.json")
ds$config <- cfg; ds$clean <- cl$clean; ds$clean_rules <- list()
item <- analysis_item(cl$clean$data, cfg, list(), ds$hash, cl$clean$item_missing)
item$r_script <- build_r_script("item_analysis", ds, item$settings)
write_fx(item, "bfi_item.json")
fn <- analysis_factor_number(cl$clean$data, cfg, list(extraction = "both", reference = "resampled_bootstrap", n_iter = 50L, seed = 20261030L), ds$hash)
fn$r_script <- build_r_script("factor_number", ds, fn$settings, fn$seed)
write_fx(fn, "bfi_factor_number.json")
cat("fikstürler yazıldı:", paste(list.files(out, pattern = "json$"), collapse = ", "), "\n")

# --- Faz 2 fikstürleri ---------------------------------------------------------------
efa <- analysis_efa(cl$clean$data, cfg, list(nfactors = 5L, seed = 20261030L), ds$hash)
efa$r_script <- build_r_script("efa", ds, efa$settings, efa$seed)
write_fx(efa, "bfi_efa.json")

h <- load_example("holzinger")
hd <- list(id = "fixture-holzinger", data = h$data, hash = h$hash, filename = h$filename,
           source = list(type = "example", name = "holzinger", label = h$source), suggested_config = h$suggested_config)
write_fx(dataset_overview(hd), "holz_overview.json")
hcfg <- build_config(hd$data, h$suggested_config)
hcl <- analysis_clean(hd$data, hcfg, list(), hd$hash)
write_fx(hcl$record, "holz_clean.json")
hd$config <- hcfg; hd$clean <- hcl$clean; hd$clean_rules <- list()
m3 <- default_model_from_subscales(hcfg)
write_fx(analysis_model_preview(hcfg, m3), "holz_preview_default.json")
m3c <- c(m3, list(covariances = list(c("x7", "x8"))))
write_fx(analysis_model_preview(hcfg, m3c), "holz_preview_cov.json")
write_fx(analysis_model_preview(hcfg, list(syntax = "g =~ x1 + x2 + x3 + x4 + x5 + x6 + x7 + x8 + x9")), "holz_preview_syntax.json")
cfa <- analysis_cfa(hcl$clean$data, hcfg, list(model = m3, likelihood = "wishart", bootstrap = 100L, seed = 20261030L), hd$hash)
cfa$r_script <- build_r_script("cfa", hd, cfa$settings, cfa$seed, cfa$results)
write_fx(cfa, "holz_cfa.json")
two <- list(factors = list(list(name = "vt", items = paste0("x", 1:6)), list(name = "speed", items = c("x7", "x8", "x9"))))
cmp <- analysis_cfa_compare(hcl$clean$data, hcfg, list(models = list(list(name = "Model 1", model = m3), list(name = "Model 2", model = two)),
                                                     likelihood = "wishart"), hd$hash)
cmp$r_script <- build_r_script("cfa_compare", hd, cmp$settings, cmp$seed, cmp$results)
write_fx(cmp, "holz_compare.json")
rel <- analysis_reliability(hcl$clean$data, hcfg, list(model = m3), hd$hash)
rel$r_script <- build_r_script("reliability", hd, rel$settings, rel$seed, rel$results)
write_fx(rel, "holz_reliability.json")
cat("Faz 2 fikstürleri yazıldı\n")

# --- Faz 3 fikstürleri ---------------------------------------------------------------
inv <- analysis_invariance(hcl$clean$data, hcfg, list(model = m3), hd$hash)
inv$r_script <- build_r_script("invariance", hd, inv$settings, inv$seed, inv$results)
write_fx(inv, "holz_invariance.json")
invs <- analysis_invariance_scores(hcl$clean$data, hcfg, list(model = m3, step = "scalar"), hd$hash)
invs$r_script <- build_r_script("invariance_scores", hd, invs$settings, invs$seed, invs$results)
write_fx(invs, "holz_scores.json")
cat("Faz 3 fikstürleri yazıldı\n")

# --- Faz 4 fikstürleri (simülasyon; küçük ama gerçek bir çalıştırma) ------------------
Sys.setenv(JOBS_DIR = tempfile("fx-jobs-"))
.olceklab$workers <- 1L
sim_fx_body <- list(population = list(
  factors = list(list(name = "visual", items = c("x1", "x2", "x3")), list(name = "textual", items = c("x4", "x5", "x6"))),
  loadings = list(x1 = .7, x2 = .6, x3 = .65, x4 = .7, x5 = .6, x6 = .7), factor_cor = list(list(a = "visual", b = "textual", r = .4)),
  data_type = "ordinal", category_props = c(.1, .2, .4, .2, .1),
  groups = list(list(name = "Pasteur"), list(name = "Grant-White")),
  dif = list(list(name = "x1 eşik DIF", group = "Grant-White", effects = list(list(item = "x1", type = "threshold", size = .5))))),
  conditions = list(N = c(200, 400)), estimators = list("ML"), reps = 20L, chunk_size = 10L, seed = 20261030L,
  analyses = list(cfa = TRUE, invariance = TRUE, reliability = TRUE))
write_fx(sim_estimate(sim_fx_body), "sim_estimate.json")
sid <- sim_job_create(sim_fx_body)
.olceklab$jobs[[sid]]$status <- "running"
ch1 <- sim_run_chunk(.olceklab$jobs[[sid]]$dir, .olceklab$jobs[[sid]]$chunks[[1]])
.olceklab$jobs[[sid]]$seconds <- ch1$seconds  # gerçek ölçülen süre
write_fx(sim_job_status(sid), "sim_job_running.json")
write_fx(sim_job_run_sync(sid), "sim_job_done.json")
write_fx(sim_results_for(.olceklab$jobs[[sid]]$dir, sid), "sim_results.json")
hcfa_rec <- analysis_cfa(hcl$clean$data, hcfg, list(model = m3), hd$hash)
write_fx(population_from_cfa(hcfa_rec, hcl$clean$data, hcfg, shift = 0.05), "holz_population.json")
cat("Faz 4 fikstürleri yazıldı\n")

# --- Faz 5 fikstürleri (rapor önizlemesi; proje dışa → içe aktarma → yeniden üretim, gerçek kod yolu) ------------
for (r in list(cfa, rel)) analysis_store(r, hd$id)
write_fx(report_preview(c(cfa$analysis_id, rel$analysis_id), "tr"), "holz_report_preview.json")
pid_ds <- dataset_put(list(data = h$data, hash = h$hash, filename = h$filename, source = list(type = "example", name = "holzinger", label = h$source),
                           suggested_config = h$suggested_config))
pds <- dataset_get(pid_ds)
roles_json <- as.character(to_json(h$suggested_config)); clean_json <- "{\"rules\":{}}"
pds$config <- build_config(pds$data, project_parse(roles_json, TRUE))
pcl <- analysis_clean(pds$data, pds$config, list(), pds$hash)
pds$clean <- pcl$clean; pds$clean_rules <- list(); pds$requests <- list(roles = roles_json, clean = clean_json)
dataset_update(pid_ds, pds)
analysis_store(pcl$record, pid_ds, request = clean_json)
cfa_req <- as.character(to_json(list(dataset_id = pid_ds, settings = list(model = m3))))
pcfa <- analysis_cfa(pcl$clean$data, pds$config, project_parse(cfa_req, FALSE)$settings, pds$hash)
pcfa$r_script <- build_r_script("cfa", pds, pcfa$settings, pcfa$seed, pcfa$results)
analysis_store(pcfa, pid_ds, request = cfa_req)
pz <- project_export(pid_ds)
pp <- project_read_zip(pz)
ppid <- project_store(pp)
write_fx(project_summary(ppid, pp), "project_summary.json")
pman <- pp$manifest
pout <- project_reproduce_job(list(example = "holzinger"), pman$dataset$roles_request, pman$dataset$clean_request, pman$analyses)
write_fx(project_reproduce_finish(ppid, pp, pout), "project_reproduction.json")
cat("Faz 5 fikstürleri yazıldı\n")
