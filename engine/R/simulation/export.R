# M9 — Bağımsız R paketi (SPEC §7 M9 9.8). Paket, platformun kullandığı fonksiyonların birebir kopyasını içerir;
# aynı params.json ile aynı sonuçları üretir. Kendi bilgisayarında ya da bir hesaplama düğümünde çalıştırılabilir.

sim_export_functions <- c(
  "api_stop", "api_error_body", "setting_choice", "setting_number", "setting_flag", "lavaan_name_ok",
  "sim_pop_error", "sim_as_list", "normalize_population", "sim_model_syntax", "sim_group_sizes", "sim_generate",
  "sim_seed", "sim_try_fit", "sim_fm", "sim_empty_category", "sim_cfa_args", "sim_analyse_cfa", "sim_inv_steps",
  "sim_analyse_invariance", "sim_pa_reference", "sim_analyse_pa", "sim_replicate", "cfa_lrt_method", "cfa_estimators",
  "count_leading", "quiet", "collect_conditions", "online_limits", "sim_spec_defaults", "normalize_sim_spec",
  "sim_chunks", "sim_chunk_file", "sim_condition", "sim_pa_ref_for", "sim_run_chunk")
sim_export_truth <- c("sim_pop_ordinal_moments", "sim_alpha_pop", "sim_true_values")
sim_export_summary <- c("sim_rate", "sim_param_summary", "sim_summarise_cell", "sim_step_kind", "sim_power_target", "sim_criteria_met", "sim_recommend", "sim_summary")

embed_objects <- function(names) {
  paste(vapply(names, function(n) {
    obj <- get(n)
    if (is.function(obj)) paste0(n, " <- ", paste(deparse(obj, width.cutoff = 100L), collapse = "\n"))
    else paste0(n, " <- ", r_literal(obj))
  }, ""), collapse = "\n\n")
}

sim_params_json <- function(spec, job_id) {
  truth <- sim_true_values(spec$pop, spec$estimators)
  scen <- vapply(spec$pop$dif, `[[`, "", "name")
  list(
    olceklab = list(job_id = job_id, created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), engine = engine_versions()),
    body = spec$body,
    rng = list(kind = "Mersenne-Twister", normal_kind = "Inversion", sample_kind = "Rejection", mc_cores = 1L),
    seed_rule = "tekrar tohumu = seed + 10000 * koşul + tekrar (tekrar = 1..R); koşul başına paralel analiz referansı: tekrar = 0",
    conditions = lapply(seq_len(nrow(spec$grid)), function(i) {
      g <- spec$grid[i, ]
      list(index = g$index, N = g$N, ratio = I(spec$ratios[[g$ratio]]), scenario = scen[g$scenario],
           first_seed = sim_seed(spec$seed, g$index, 1L), last_seed = sim_seed(spec$seed, g$index, spec$reps))
    }),
    estimands = lapply(spec$estimators, function(e) list(estimator = e,
      parameters = truth[[e]]$params, reliability = truth[[e]]$reliability, latent_means = truth[[e]]$latent_means,
      scale = "yükler ve faktör korelasyonları: std.all; eşikler: y*; gizil ortalama farkı: referans grup SS'si"))
  )
}

sim_package_files <- function(spec, job_id) {
  hdr <- function(title) paste0("## ÖlçekLab bağımsız simülasyon paketi — ", title, "\n## ", SIM_LABEL_TR, "\n",
                                "stopifnot(isTRUE(l10n_info()[[\"UTF-8\"]]))\n", script_version_check(c("lavaan", "semTools", "psych", "MASS", "pbivnorm", "jsonlite")), "\n")
  sim_r <- paste0(hdr("02 simülasyon"),
    "## Motorun fonksiyonları (birebir kopya; değiştirmeyin)\n", embed_objects(sim_export_functions), "\n\n",
    "params <- jsonlite::fromJSON(\"params.json\", simplifyVector = FALSE)\n",
    "spec <- normalize_sim_spec(params$body)\n",
    "dir.create(\"sonuclar\", showWarnings = FALSE)\n",
    "saveRDS(spec, file.path(\"sonuclar\", \"spec.rds\"))\n",
    "parcalar <- sim_chunks(spec)\n",
    "eksik <- Filter(function(ch) !file.exists(sim_chunk_file(\"sonuclar\", ch)), parcalar)  # kesilen iş kaldığı yerden devam eder\n",
    "cekirdek <- as.integer(Sys.getenv(\"CEKIRDEK\", \"1\"))\n",
    "calistir <- function(ch) { sim_run_chunk(\"sonuclar\", ch); ch$cond }\n",
    "if (cekirdek > 1L && .Platform$OS.type == \"unix\") invisible(parallel::mclapply(eksik, calistir, mc.cores = cekirdek)) else invisible(lapply(eksik, calistir))\n",
    "cat(\"Tamamlanan parça:\", sum(vapply(parcalar, function(ch) file.exists(sim_chunk_file(\"sonuclar\", ch)), logical(1))), \"/\", length(parcalar), \"\\n\")\n")
  truth_r <- paste0(hdr("03 gerçek değerler"),
    embed_objects(c(sim_export_functions, sim_export_truth)), "\n\n",
    "spec <- readRDS(file.path(\"sonuclar\", \"spec.rds\"))\n",
    "gercek <- sim_true_values(spec$pop, spec$estimators)\n",
    "saveRDS(gercek, file.path(\"sonuclar\", \"gercek_degerler.rds\"))\n",
    "for (e in names(gercek)) utils::write.csv(gercek[[e]]$params, file.path(\"sonuclar\", paste0(\"gercek_degerler_\", e, \".csv\")), row.names = FALSE)\n")
  sum_r <- paste0(hdr("05 özet"),
    embed_objects(c(sim_export_functions, sim_export_truth, sim_export_summary)), "\n\n",
    "spec <- readRDS(file.path(\"sonuclar\", \"spec.rds\"))\n",
    "dosyalar <- vapply(sim_chunks(spec), function(ch) sim_chunk_file(\"sonuclar\", ch), \"\")\n",
    "stopifnot(all(file.exists(dosyalar)))\n",
    "tekrarlar <- do.call(c, lapply(dosyalar, readRDS))\n",
    "ozet <- sim_summary(spec, tekrarlar)\n",
    "saveRDS(ozet, file.path(\"sonuclar\", \"ozet.rds\"))\n",
    "satirlar <- do.call(rbind, lapply(ozet$cells, function(c) data.frame(kosul = c$cond, N = c$N, oran = c$ratio, senaryo = c$scenario, kestirici = c$estimator,\n",
    "  tekrar = c$R, yakinsama = c$converged_rate, uygun = c$admissible_rate)))\n",
    "utils::write.csv(satirlar, file.path(\"sonuclar\", \"ozet_tablolar.csv\"), row.names = FALSE)\n",
    "inv <- do.call(rbind, lapply(ozet$cells, function(c) if (!is.null(c$invariance)) cbind(kosul = c$cond, kestirici = c$estimator, c$invariance)))\n",
    "if (!is.null(inv)) utils::write.csv(inv, file.path(\"sonuclar\", \"degismezlik_ozet.csv\"), row.names = FALSE)\n",
    "prm <- do.call(rbind, lapply(ozet$cells, function(c) if (!is.null(c$params)) cbind(kosul = c$cond, kestirici = c$estimator, c$params)))\n",
    "if (!is.null(prm)) utils::write.csv(prm, file.path(\"sonuclar\", \"parametre_ozet.csv\"), row.names = FALSE)\n",
    "cat(\"Özet yazıldı: sonuclar/\\n\")\n")
  sh <- paste0("#!/bin/sh\n# ÖlçekLab bağımsız simülasyon paketi. Kullanım: CEKIRDEK=4 sh 04_calistir.sh\nset -e\n",
               "export LANG=C.UTF-8 LC_ALL=C.UTF-8\n",
               "Rscript 02_simulasyon.R\nRscript 03_gercek_degerler.R\nRscript 05_ozet.R\n")
  readme <- paste0("# ÖlçekLab simülasyon paketi\n\n", SIM_LABEL_TR, "\n\n",
    "Bu paket ÖlçekLab'de tanımlanan simülasyonu kendi bilgisayarınızda ya da bir hesaplama düğümünde baştan üretir.\n\n",
    "## Çalıştırma\n\n```\nCEKIRDEK=4 sh 04_calistir.sh\n```\n\n",
    "- `02_simulasyon.R`: tekrarları üretip analiz eder; her parça `sonuclar/` altına `.rds` olarak yazılır. İş kesilirse yeniden çalıştırın; eksik parçalardan devam eder.\n",
    "- `03_gercek_degerler.R`: gerçek değerleri (üretim parametreleri ya da kesin popülasyon momentlerinden sözde-gerçek değerler) hesaplar.\n",
    "- `05_ozet.R`: yanlılık, kapsama, güç ve I. tip hata özetlerini `sonuclar/` altına yazar.\n\n",
    "## Tekrarlanabilirlik\n\n- RNG: `RNGkind(\"Mersenne-Twister\", \"Inversion\", \"Rejection\")`; tekrar tohumu `seed + 10000 · koşul + tekrar`.\n",
    "- Koşul indeksleri, tohumlar ve kestirilen nicelik tablosu `params.json` dosyasındadır.\n",
    "- Paket, ÖlçekLab'in kullandığı R fonksiyonlarının birebir kopyasını içerir; aynı paket sürümleriyle aynı sonuçları verir. Sürüm farkı varsa betikler uyarı verir.\n",
    "- Çok çekirdekte çalıştırmak sonuçları değiştirmez: her tekrarın tohumu kendine aittir.\n")
  list("params.json" = as.character(to_json(sim_params_json(spec, job_id))), "02_simulasyon.R" = sim_r, "03_gercek_degerler.R" = truth_r,
       "04_calistir.sh" = sh, "05_ozet.R" = sum_r, "BENIOKU.md" = readme)
}

sim_export_package <- function(spec, job_id) {
  files <- sim_package_files(spec, job_id)
  dir <- tempfile("olceklab-paket-")
  root <- file.path(dir, "olceklab_simulasyon")
  dir.create(root, recursive = TRUE)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  for (n in names(files)) writeLines(files[[n]], file.path(root, n), useBytes = TRUE)
  Sys.chmod(file.path(root, "04_calistir.sh"), "0755")
  zf <- file.path(dir, "olceklab_simulasyon.zip")
  zip::zip(zf, files = "olceklab_simulasyon", root = dir)
  readBin(zf, "raw", file.size(zf))
}
