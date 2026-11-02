# M2 — Betimsel istatistikler ve madde analizi (SPEC §7 M2).

# psych::alpha, ters yönlü maddelerin adlarını uyarı ile değil cat() ile yazar (alpha.R satır 81);
# bu çıktı yakalanıp kullanıcıya uyarı olarak iletilir.
alpha_with_notes <- function(x) {
  al <- NULL
  printed <- utils::capture.output(al <- collect_conditions(psych::alpha(x, check.keys = FALSE, warnings = TRUE)))
  printed <- trimws(paste(printed, collapse = " "))
  notes <- al$warnings
  if (grepl("negatively correlated", printed, fixed = TRUE)) {
    notes <- c(notes[!grepl("negatively correlated", notes, fixed = TRUE)], gsub("\\s+", " ", printed))
  }
  list(value = al$value, warnings = notes)
}

item_psych_calls <- function(x) {
  desc <- psych::describe(x, type = 3)
  al <- alpha_with_notes(x)
  list(describe = desc, alpha = al$value, alpha_warnings = al$warnings)
}

analysis_item <- function(data, config, settings, dataset_hash, item_missing = NULL) {
  r_thr <- setting_number(settings, "r_drop_threshold", 0.30, 0, 1)
  skew_thr <- setting_number(settings, "skew_threshold", 2, 0, 100)
  items <- config$items$name
  x <- data[, items, drop = FALSE]
  if (length(items) < 2L) api_stop("too_few_items", "Madde analizi için en az iki madde gerekir.", 422L)
  if (nrow(x) < 3L) api_stop("too_few_rows", "Madde analizi için en az üç satır gerekir.", 422L)

  pc <- item_psych_calls(x)
  d <- pc$describe; al <- pc$alpha
  bounded <- !is.na(config$items$min)
  floor_p <- ceiling_p <- rep(NA_real_, length(items))
  for (k in which(bounded)) {
    v <- x[[items[k]]]
    floor_p[k] <- mean(v == config$items$min[k])
    ceiling_p[k] <- mean(v == config$items$max[k])
  }
  item_tab <- data.frame(
    item = items,
    n = d[items, "n"], mean = d[items, "mean"], sd = d[items, "sd"],
    skew = d[items, "skew"], kurtosis = d[items, "kurtosis"],
    r_drop = al$item.stats[items, "r.drop"],
    alpha_drop = al$alpha.drop[items, "raw_alpha"],
    floor = floor_p, ceiling = ceiling_p,
    missing_raw = if (is.null(item_missing)) NA_real_ else unname(item_missing[items]),
    stringsAsFactors = FALSE
  )
  t1 <- make_table("T1", "Madde istatistikleri", "Item statistics",
    list(tbl_col("item", "Madde", "Item"), tbl_col("n", "n", "n", "int"),
         tbl_col("mean", "Ort.", "M", "num", 2L), tbl_col("sd", "SS", "SD", "num", 2L),
         tbl_col("skew", "Çarpıklık", "Skewness", "num", 2L), tbl_col("kurtosis", "Basıklık", "Kurtosis", "num", 2L),
         tbl_col("r_drop", "Düzeltilmiş madde-toplam r", "Corrected item–total r", "num", 3L, TRUE),
         tbl_col("alpha_drop", "Madde silinirse α", "α if item deleted", "num", 3L, TRUE),
         tbl_col("floor", "Taban", "Floor", "pct", 1L), tbl_col("ceiling", "Tavan", "Ceiling", "pct", 1L),
         tbl_col("missing_raw", "Eksik (ham)", "Missing (raw)", "pct", 1L)),
    item_tab,
    note_tr = sprintf("Kaynak: psych::describe (type = 3; basıklık fazla basıklıktır), psych::alpha (check.keys = FALSE); psych %s.",
                      as.character(utils::packageVersion("psych"))),
    note_en = sprintf("Source: psych::describe (type = 3; excess kurtosis), psych::alpha (check.keys = FALSE); psych %s.",
                      as.character(utils::packageVersion("psych"))))

  # Alfa: toplam ve alt boyutlar
  rel <- data.frame(scale = "total", label_tr = "Toplam", label_en = "Total", k = length(items),
                    alpha = al$total$raw_alpha, std_alpha = al$total$std.alpha, stringsAsFactors = FALSE)
  warns <- list()
  subs <- unique(stats::na.omit(config$items$subscale))
  for (s in subs) {
    si <- config$items$name[!is.na(config$items$subscale) & config$items$subscale == s]
    if (length(si) < 2L) {
      warns[[length(warns) + 1L]] <- warning_item("subscale_too_small",
        sprintf("'%s' alt boyutunda iki maddeden az var; alfa hesaplanmadı.", s),
        sprintf("Subscale '%s' has fewer than two items; alpha not computed.", s))
      next
    }
    sa <- alpha_with_notes(x[, si, drop = FALSE])
    rel[nrow(rel) + 1L, ] <- list(s, s, s, length(si), sa$value$total$raw_alpha, sa$value$total$std.alpha)
    for (w in sa$warnings) warns[[length(warns) + 1L]] <- warning_item("psych_alpha", paste0(s, ": ", w), paste0(s, ": ", w))
  }
  t2 <- make_table("T2", "Cronbach alfa", "Cronbach's alpha",
    list(tbl_col("label_tr", "Ölçek", "Scale"), tbl_col("k", "Madde sayısı", "Items", "int"),
         tbl_col("alpha", "α", "α", "num", 3L, TRUE), tbl_col("std_alpha", "Standart α", "Standardized α", "num", 3L, TRUE)),
    rel,
    note_tr = "Kaynak: psych::alpha, raw_alpha ve std.alpha.", note_en = "Source: psych::alpha, raw_alpha and std.alpha.")
  t2$rows_fmt$en$label_tr <- rel$label_en

  # Kategori frekansları
  tables <- list(t1, t2)
  figures <- list()
  if (any(bounded)) {
    cats <- seq(min(config$items$min[bounded]), max(config$items$max[bounded]))
    freq <- t(vapply(items[bounded], function(i) {
      k <- which(items == i)
      lv <- seq(config$items$min[k], config$items$max[k])
      tab <- table(factor(x[[i]], levels = cats))
      out <- as.numeric(tab)
      out[!(cats %in% lv)] <- NA_real_
      out
    }, numeric(length(cats))))
    colnames(freq) <- as.character(cats)
    prop <- freq / rowSums(freq, na.rm = TRUE)
    fdf <- data.frame(item = items[bounded], freq, check.names = FALSE, stringsAsFactors = FALSE)
    cols <- c(list(tbl_col("item", "Madde", "Item")),
              lapply(as.character(cats), function(cc) tbl_col(cc, cc, cc, "int")))
    tables[[3]] <- make_table("T3", "Kategori frekansları", "Category frequencies", cols, fdf,
      note_tr = "Boş hücre, o maddede tanımlı olmayan kategoridir.",
      note_en = "An empty cell is a category not defined for that item.")
    pct_lab <- function(lang) matrix(fmt_pct(prop, lang, 1L), nrow = nrow(prop))
    figures[[1]] <- list(id = "F1", type = "heatmap", data = list(
      items = I(items[bounded]), categories = I(as.character(cats)), proportions = unname(prop), counts = unname(freq),
      labels = list(tr = pct_lab("tr"), en = pct_lab("en"))))
    for (k in seq_along(items[bounded])) {
      i <- items[bounded][k]
      empty <- cats[!is.na(freq[k, ]) & freq[k, ] == 0]
      if (length(empty)) warns[[length(warns) + 1L]] <- warning_item("empty_category",
        sprintf("%s maddesinde boş kategori: %s.", i, paste(empty, collapse = ", ")),
        sprintf("Item %s has empty categories: %s.", i, paste(empty, collapse = ", ")))
    }
  }

  low_r <- items[!is.na(item_tab$r_drop) & item_tab$r_drop < r_thr]
  if (length(low_r)) warns[[length(warns) + 1L]] <- warning_item("low_item_total",
    sprintf("Düzeltilmiş madde-toplam korelasyonu %s altında: %s.", fmt_num(r_thr, 2, "tr", TRUE), paste(low_r, collapse = ", ")),
    sprintf("Corrected item–total correlation below %s: %s.", fmt_num(r_thr, 2, "en", TRUE), paste(low_r, collapse = ", ")))
  high_skew <- items[!is.na(item_tab$skew) & abs(item_tab$skew) > skew_thr]
  if (length(high_skew)) warns[[length(warns) + 1L]] <- warning_item("high_skew",
    sprintf("|Çarpıklık| > %s: %s.", fmt_num(skew_thr, 0, "tr"), paste(high_skew, collapse = ", ")),
    sprintf("|Skewness| > %s: %s.", fmt_num(skew_thr, 0, "en"), paste(high_skew, collapse = ", ")))
  for (w in pc$alpha_warnings) {
    warns[[length(warns) + 1L]] <- if (grepl("negatively correlated", w, fixed = TRUE)) {
      warning_item("negative_first_component",
        paste("psych::alpha: bazı maddeler ilk temel bileşenle negatif ilişkili; ters kodlama ayarlarını denetleyin.", w),
        paste("psych::alpha: some items correlate negatively with the first principal component; check reverse coding.", w))
    } else warning_item("psych_alpha", w, w)
  }

  make_record(
    module = "item_analysis", dataset_hash = dataset_hash,
    settings = list(r_drop_threshold = r_thr, skew_threshold = skew_thr, items = I(items)),
    results = list(
      n = nrow(x), alpha = al$total$raw_alpha, std_alpha = al$total$std.alpha,
      items = item_tab, reliability = rel[, c("scale", "k", "alpha", "std_alpha")]
    ),
    tables = tables, figures = figures, warnings = warns
  )
}
