# M9 — Popülasyon modeli (SPEC §7 M9 9.1; SPEC_REVIEW MC-2, MC-7, MC-13).
#
# Şema (JSON ile aynı; population.json olarak içe/dışa aktarılır):
#   factors:      [{ name, items: [...] }]                 — basit yapı: her madde tek faktörde
#   loadings:     { madde: standardize yük }                — referans grupta, var(y*) = 1 ölçeğinde
#   factor_cor:   [{ a, b, r }]                             — referans grubun faktör korelasyonları (verilmeyen 0)
#   data_type:    "ordinal" | "continuous"
#   category_props: [p1, ..., pK]  ya da  { madde: [p1, ..., pK] } — referans grubun kategori oranları
#   groups:       [{ name, latent_means: { F: α }, latent_var: { F: ψ } }] — ilk grup referanstır (α = 0, ψ = 1)
#   dif:          [{ name, group, effects: [{ item, type: threshold|intercept|loading, size }] }]
# Değişmez (kontrol) senaryosu her zaman birinci senaryodur.

sim_pop_error <- function(msg) api_stop("invalid_population", msg, 422L)

sim_as_list <- function(x) if (is.null(x)) list() else x

normalize_population <- function(spec) {
  if (!is.list(spec)) sim_pop_error("Popülasyon tanımı bir nesne olmalıdır.")
  fs <- sim_as_list(spec$factors)
  if (!length(fs)) sim_pop_error("Popülasyon modelinde en az bir faktör olmalıdır.")
  fnames <- vapply(fs, function(f) as.character(f$name)[1], "")
  if (anyDuplicated(fnames) || any(!lavaan_name_ok(fnames))) sim_pop_error("Faktör adları benzersiz ve lavaan'da kullanılabilir olmalıdır.")
  items_by <- lapply(fs, function(f) as.character(unlist(f$items)))
  items <- unlist(items_by)
  if (anyDuplicated(items)) sim_pop_error("Popülasyon modelinde her madde tek bir faktöre bağlı olmalıdır (basit yapı).")
  if (any(!lavaan_name_ok(items))) sim_pop_error("Madde adları lavaan'da kullanılabilir olmalıdır.")
  if (any(lengths(items_by) < 2L)) sim_pop_error("Her faktörde en az iki madde olmalıdır.")
  p <- length(items); k <- length(fnames)
  lam_in <- sim_as_list(spec$loadings)
  Lambda <- matrix(0, p, k, dimnames = list(items, fnames))
  for (j in seq_len(k)) for (it in items_by[[j]]) {
    v <- lam_in[[it]]
    if (is.null(v) || !is.numeric(v) || length(v) != 1L || is.na(v) || abs(v) >= 1 || v == 0) sim_pop_error(sprintf("'%s' için standardize yük (0 dışında, mutlak değeri 1'den küçük) verilmelidir.", it))
    Lambda[it, j] <- as.numeric(v)
  }
  Psi <- diag(k); dimnames(Psi) <- list(fnames, fnames)
  for (fc in sim_as_list(spec$factor_cor)) {
    a <- as.character(fc$a); b <- as.character(fc$b); r <- as.numeric(fc$r)
    if (!(a %in% fnames) || !(b %in% fnames) || a == b || length(r) != 1L || is.na(r) || abs(r) >= 1) sim_pop_error("Faktör korelasyonları iki farklı faktör ve mutlak değeri 1'den küçük bir değer içermelidir.")
    Psi[a, b] <- Psi[b, a] <- r
  }
  if (min(eigen(Psi, symmetric = TRUE, only.values = TRUE)$values) <= 1e-8) sim_pop_error("Faktör korelasyon matrisi pozitif tanımlı değil.")
  theta <- 1 - diag(Lambda %*% Psi %*% t(Lambda))
  if (any(theta <= 0)) sim_pop_error(sprintf("Şu maddelerde artık varyans pozitif değil (yükler çok büyük): %s.", paste(items[theta <= 0], collapse = ", ")))
  data_type <- if (is.null(spec$data_type)) "ordinal" else as.character(spec$data_type)
  if (!(data_type %in% c("ordinal", "continuous"))) sim_pop_error("data_type 'ordinal' ya da 'continuous' olmalıdır.")
  tau <- NULL; props <- NULL
  if (data_type == "ordinal") {
    cp <- spec$category_props
    if (is.null(cp)) sim_pop_error("Sıralı veri için kategori oranları (category_props) verilmelidir.")
    props <- if (is.list(cp) && !is.null(names(cp))) lapply(items, function(it) as.numeric(unlist(cp[[it]]))) else rep(list(as.numeric(unlist(cp))), p)
    names(props) <- items
    for (it in items) {
      pr <- props[[it]]
      if (length(pr) < 3L || any(is.na(pr)) || any(pr <= 0) || abs(sum(pr) - 1) > 1e-6) {
        sim_pop_error(sprintf("'%s' için kategori oranları en az üç pozitif değer olmalı ve toplamı 1 olmalıdır (ikili madde v1'de desteklenmez).", it))
      }
    }
    tau <- lapply(props, function(pr) stats::qnorm(cumsum(pr)[-length(pr)]))
  }
  gs <- sim_as_list(spec$groups)
  if (!length(gs)) gs <- list(list(name = "Tek grup"))
  gnames <- vapply(gs, function(g) as.character(g$name)[1], "")
  if (anyDuplicated(gnames) || any(!nzchar(gnames))) sim_pop_error("Grup adları benzersiz olmalıdır.")
  groups <- lapply(seq_along(gs), function(i) {
    g <- gs[[i]]
    alpha <- stats::setNames(rep(0, k), fnames); psi <- Psi
    if (i > 1L) {
      for (f in names(sim_as_list(g$latent_means))) { if (!(f %in% fnames)) sim_pop_error(sprintf("Bilinmeyen faktör: %s", f)); alpha[[f]] <- as.numeric(g$latent_means[[f]]) }
      for (f in names(sim_as_list(g$latent_var))) {
        if (!(f %in% fnames)) sim_pop_error(sprintf("Bilinmeyen faktör: %s", f))
        v <- as.numeric(g$latent_var[[f]]); if (is.na(v) || v <= 0) sim_pop_error("Gizil varyans pozitif olmalıdır.")
        s <- sqrt(v); psi[f, ] <- psi[f, ] * s; psi[, f] <- psi[, f] * s
      }
    } else if (length(g$latent_means) || length(g$latent_var)) {
      sim_pop_error("Referans grubun (ilk grup) gizil ortalaması 0, varyansı 1'dir; değiştirilemez.")
    }
    list(name = gnames[i], alpha = alpha, psi = psi)
  })
  dif <- list(list(name = "Değişmez (kontrol)", group = NULL, effects = list(), control = TRUE))
  for (d in sim_as_list(spec$dif)) {
    nm <- as.character(d$name)[1]
    if (is.na(nm) || !nzchar(nm)) sim_pop_error("Her farklılık senaryosunun adı olmalıdır.")
    if (length(groups) < 2L) sim_pop_error("Farklılık (DIF) senaryosu için en az iki grup gerekir.")
    g <- as.character(d$group)[1]
    if (!(g %in% gnames[-1])) sim_pop_error(sprintf("'%s' senaryosundaki grup referans dışı bir grup olmalıdır.", nm))
    eff <- lapply(sim_as_list(d$effects), function(e) {
      it <- as.character(e$item); ty <- as.character(e$type); sz <- as.numeric(e$size)
      if (!(it %in% items)) sim_pop_error(sprintf("'%s' senaryosunda bilinmeyen madde: %s", nm, it))
      if (!(ty %in% c("threshold", "intercept", "loading"))) sim_pop_error("Etki türü threshold, intercept ya da loading olmalıdır.")
      if (ty == "threshold" && data_type != "ordinal") sim_pop_error("Eşik kayması yalnızca sıralı veride tanımlıdır; sürekli veride intercept kullanın.")
      if (ty == "intercept" && data_type == "ordinal") sim_pop_error("Sıralı veride kesişim kayması yerine threshold kullanın.")
      if (length(sz) != 1L || is.na(sz)) sim_pop_error("Etki büyüklüğü bir sayı olmalıdır.")
      list(item = it, type = ty, size = sz)
    })
    if (!length(eff)) sim_pop_error(sprintf("'%s' senaryosunda en az bir etki olmalıdır.", nm))
    dif[[length(dif) + 1L]] <- list(name = nm, group = g, effects = eff, control = FALSE)
  }
  if (anyDuplicated(vapply(dif, `[[`, "", "name"))) sim_pop_error("Senaryo adları benzersiz olmalıdır.")
  list(factors = stats::setNames(items_by, fnames), items = items, fnames = fnames, Lambda = Lambda, Psi = Psi,
       theta = stats::setNames(theta, items), data_type = data_type, props = props, tau = tau, groups = groups,
       gnames = gnames, dif = dif, spec = spec)
}

# lavaan sözdizimi (analiz modeli = doğru model).
sim_model_syntax <- function(pop) {
  paste(vapply(pop$fnames, function(f) sprintf("%s =~ %s", f, paste(pop$factors[[f]], collapse = " + ")), ""), collapse = "\n")
}

# M6 DFA kaydından popülasyon tanımı (9.1 a): yalnızca özet parametreler kullanılır (standardize yükler, faktör
# korelasyonları, kategori oranları). İsteğe bağlı duyarlılık: bütün yüklerden `shift` çıkarılır (MC-13).
population_from_cfa <- function(rec, data, config, shift = 0) {
  if (!identical(rec$module, "cfa")) api_stop("invalid_source", "Popülasyon yalnızca bir DFA sonucundan kurulabilir.", 422L)
  ld <- rec$results$loadings
  m <- rec$settings$model
  if (length(m$first_order) != length(m$factors)) api_stop("invalid_source", "İkinci düzey faktörlü modelden popülasyon kurulamaz.", 422L)
  items <- unlist(lapply(m$factors, function(f) as.character(f$items)))
  if (anyDuplicated(items)) api_stop("invalid_source", "Çapraz yüklü modelden basit yapılı popülasyon kurulamaz.", 422L)
  lam <- stats::setNames(as.list(pmax(-0.95, pmin(0.95, ld$std - sign(ld$std) * shift))), ld$item)
  fc <- rec$results$factor_correlations
  cors <- list()
  if (!is.null(fc)) {
    fn <- names(fc)
    for (j in seq_along(fn)) for (i in seq_len(j - 1L)) cors[[length(cors) + 1L]] <- list(a = fn[i], b = fn[j], r = fc[[fn[i]]][[fn[j]]])
  }
  est <- rec$settings$estimator
  ordinal <- !any(is.na(config$items$min[match(items, config$items$name)]))
  if (est == "ML" || est == "MLR") ordinal <- FALSE  # ML ile kestirilmiş modelden yalnızca sürekli veri (MC-7)
  out <- list(factors = lapply(m$factors, function(f) list(name = f$name, items = I(as.character(f$items)))),
              loadings = lam, factor_cor = cors, data_type = if (ordinal) "ordinal" else "continuous")
  if (ordinal) {
    out$category_props <- lapply(stats::setNames(items, items), function(it) {
      k <- config$items[config$items$name == it, ]
      v <- factor(data[[it]], levels = seq(k$min, k$max))
      pr <- as.numeric(table(v)) / sum(!is.na(data[[it]]))
      if (any(pr == 0)) pr <- (pr + 0.5 / length(pr)) / sum(pr + 0.5 / length(pr))  # boş kategori: küçük düzeltme (belgelenir)
      I(pr)
    })
  }
  ml <- est %in% c("ML", "MLR")
  list(population = out,
       notes_tr = c("Popülasyon, örnek kestirimlerini gerçek değer kabul eder; bu nedenle sonuçlar iyimser olabilir (Hoenig ve Heisey, 2001).",
                    if (shift > 0) sprintf("Duyarlılık: bütün standardize yükler %s azaltıldı.", fmt_num(shift, 2L, "tr", bounded = TRUE)) else NULL,
                    if (ml) "Model ML/MLR ile kestirildiği için yalnızca sürekli veri üretilir (SPEC_REVIEW MC-7)." else NULL),
       notes_en = c("The population treats sample estimates as true values, so results may be optimistic (Hoenig & Heisey, 2001).",
                    if (shift > 0) sprintf("Sensitivity: all standardized loadings reduced by %s.", fmt_num(shift, 2L, "en", bounded = TRUE)) else NULL,
                    if (ml) "The model was estimated with ML/MLR, so only continuous data are generated (SPEC_REVIEW MC-7)." else NULL))
}
