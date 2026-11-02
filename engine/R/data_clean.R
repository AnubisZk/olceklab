# M1 — Veri yükleme ve temizleme (SPEC §6.1, §7 M1, §10).

max_upload_bytes <- function() {
  as.numeric(Sys.getenv("MAX_UPLOAD_MB", "10")) * 1024^2
}

max_rows <- function() {
  as.integer(Sys.getenv("MAX_ROWS", "100000"))
}

# --- Dosya ayrıştırma ----------------------------------------------------------

parse_upload <- function(raw, filename) {
  if (!is.raw(raw) || length(raw) == 0L) api_stop("empty_file", "Dosya boş.", 400L)
  if (length(raw) > max_upload_bytes()) {
    api_stop("file_too_large",
             sprintf("Dosya boyutu sınırı (%s MB) aşıldı.", format(max_upload_bytes() / 1024^2)), 413L)
  }
  ext <- tolower(tools::file_ext(filename))
  df <- switch(ext,
    csv = , txt = , tsv = parse_delimited_bytes(raw),
    xlsx = , xls = parse_excel_bytes(raw, ext),
    api_stop("unsupported_format", "Desteklenmeyen dosya biçimi. CSV ya da XLSX yükleyin.", 415L)
  )
  validate_frame(df)
  list(
    data = df,
    hash = paste0("sha256:", digest::digest(raw, algo = "sha256", serialize = FALSE)),
    filename = basename(filename),
    delimiter = attr(df, "delimiter")
  )
}

parse_delimited_bytes <- function(raw) {
  if (length(raw) >= 3L && identical(raw[1:3], as.raw(c(0xEF, 0xBB, 0xBF)))) raw <- raw[-(1:3)]
  if (any(raw == as.raw(0))) {
    api_stop("not_utf8", "Dosya UTF-8 metin dosyası değil. Dosyayı UTF-8 CSV olarak kaydedip yeniden yükleyin.", 422L)
  }
  txt <- rawToChar(raw)
  Encoding(txt) <- "UTF-8"
  if (!validUTF8(txt)) {
    api_stop("not_utf8", "Dosya UTF-8 kodlamasında değil. Dosyayı UTF-8 CSV olarak kaydedip yeniden yükleyin.", 422L)
  }
  lines <- strsplit(txt, "\r\n|\n|\r")[[1]]
  lines <- lines[nzchar(trimws(lines))]
  if (length(lines) < 2L) api_stop("no_rows", "Dosyada başlık satırından sonra veri yok.", 422L)
  header <- gsub("\"[^\"]*\"", "", lines[1])
  counts <- c(";" = lengths(regmatches(header, gregexpr(";", header, fixed = TRUE))),
              "," = lengths(regmatches(header, gregexpr(",", header, fixed = TRUE))),
              "\t" = lengths(regmatches(header, gregexpr("\t", header, fixed = TRUE))))
  if (max(counts) == 0L) api_stop("delimiter_not_found", "Sütun ayracı bulunamadı (; , ya da sekme).", 422L)
  sep <- names(counts)[which.max(counts)]
  con <- textConnection(lines, encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  df <- tryCatch(
    utils::read.table(con, sep = sep, header = TRUE, quote = "\"", colClasses = "character",
                      check.names = FALSE, na.strings = c("", "NA", "NaN"), strip.white = TRUE,
                      comment.char = "", encoding = "UTF-8", stringsAsFactors = FALSE),
    error = function(e) api_stop("parse_error", "Dosya okunamadı: satırlardaki sütun sayısı tutarsız olabilir.",
                                 422L, conditionMessage(e))
  )
  names(df) <- trimws(names(df))
  df <- convert_columns(df, decimal_comma = sep != ",")
  attr(df, "delimiter") <- sep
  df
}

parse_excel_bytes <- function(raw, ext) {
  # readxl dosya yolu ister. Dosya bellek tabanlı /dev/shm altında kısa süre tutulur ve hemen silinir.
  dir <- if (dir.exists("/dev/shm") && file.access("/dev/shm", 2L) == 0L) "/dev/shm" else tempdir()
  path <- tempfile("olceklab-", tmpdir = dir, fileext = paste0(".", ext))
  on.exit(unlink(path, force = TRUE), add = TRUE)
  writeBin(raw, path)
  df <- tryCatch(
    readxl::read_excel(path, sheet = 1L, col_types = "text", .name_repair = "minimal"),
    error = function(e) api_stop("parse_error", "Excel dosyası okunamadı.", 422L, conditionMessage(e))
  )
  df <- as.data.frame(df, stringsAsFactors = FALSE, check.names = FALSE)
  names(df) <- trimws(names(df))  # ör. "Madde1 " (Excel'de sık görülür)
  df <- convert_columns(df, decimal_comma = TRUE)
  attr(df, "delimiter") <- NA_character_
  df
}

convert_columns <- function(df, decimal_comma) {
  for (j in seq_along(df)) {
    v <- trimws(as.character(df[[j]]))
    v[v %in% c("", "NA", "NaN")] <- NA_character_
    cand <- if (decimal_comma) gsub(",", ".", v, fixed = TRUE) else v
    num <- suppressWarnings(as.numeric(cand))
    df[[j]] <- if (all(is.na(v) == is.na(num))) num else v
  }
  df
}

validate_frame <- function(df) {
  nm <- names(df)
  if (ncol(df) == 0L || nrow(df) == 0L) api_stop("no_rows", "Dosyada veri yok.", 422L)
  if (any(is.na(nm) | !nzchar(trimws(nm)))) api_stop("blank_column_name", "Adı boş olan sütun var.", 422L)
  if (anyDuplicated(nm)) {
    api_stop("duplicate_column_name",
             sprintf("Aynı adı taşıyan sütunlar var: %s", paste(unique(nm[duplicated(nm)]), collapse = ", ")), 422L)
  }
  if (nrow(df) > max_rows()) api_stop("too_many_rows", sprintf("Satır sınırı (%d) aşıldı.", max_rows()), 413L)
  invisible(TRUE)
}

# --- Sütun özeti ve kimlik sütunu algılama ------------------------------------

normalize_name <- function(x) {
  x <- tolower(x)
  x <- chartr("ışğüöçâîû", "isguocaiu", x)
  gsub("[^a-z0-9]+", "_", x)
}

tc_kimlik_valid <- function(x) {
  s <- gsub("\\.0+$", "", trimws(as.character(x)))
  ok <- !is.na(s) & grepl("^[1-9][0-9]{10}$", s)
  res <- rep(FALSE, length(s))
  if (!any(ok)) return(res)
  d <- do.call(rbind, lapply(strsplit(s[ok], ""), as.integer))
  odd <- d[, 1] + d[, 3] + d[, 5] + d[, 7] + d[, 9]
  even <- d[, 2] + d[, 4] + d[, 6] + d[, 8]
  d10 <- ((odd * 7L - even) %% 10L + 10L) %% 10L
  d11 <- rowSums(d[, 1:10, drop = FALSE]) %% 10L
  res[ok] <- d[, 10] == d10 & d[, 11] == d11
  res
}

identifier_name_patterns <- c(
  "^ad$", "^adi$", "^isim", "^soyad", "^ad_?soyad", "^adsoyad", "^ogrenci_?(no|num)", "^numara",
  "^no$", "^okul_?no", "^tc", "kimlik", "tckn", "^id$", "e_?posta", "^email", "^mail$", "^telefon", "^tel$"
)

detect_identifier_columns <- function(df) {
  out <- list()
  n <- nrow(df)
  for (nm in names(df)) {
    v <- df[[nm]]
    nn <- v[!is.na(v)]
    reason <- NULL
    if (any(vapply(identifier_name_patterns, grepl, logical(1), x = normalize_name(nm)))) {
      reason <- "name"
    } else if (length(nn) && mean(tc_kimlik_valid(nn)) >= 0.8) {
      reason <- "tc_kimlik"
    } else if (is.character(v) && length(nn) >= 10L && length(unique(nn)) == length(nn)) {
      reason <- "unique_text"
    }
    if (!is.null(reason)) out[[length(out) + 1L]] <- list(column = nm, reason = reason)
  }
  out
}

group_name_patterns <- c("^grup", "^group", "^cinsiyet", "^gender", "^sex$", "^sinif", "^kademe",
                         "^okul$", "^school", "^bolge", "^il$", "^sube")

column_summary <- function(df) {
  ids <- vapply(detect_identifier_columns(df), `[[`, "", "column")
  lapply(names(df), function(nm) {
    v <- df[[nm]]
    num <- is.numeric(v)
    u <- sort(unique(v[!is.na(v)]))
    integer_valued <- num && length(u) > 0L && all(u == round(u))
    is_group_name <- any(vapply(group_name_patterns, grepl, logical(1), x = normalize_name(nm)))
    role <- if (nm %in% ids) "id"
            else if (is_group_name && length(u) <= 20L) "group"
            else if (num) "item"
            else "ignore"
    list(
      name = nm,
      type = if (num) "number" else "text",
      n_missing = sum(is.na(v)),
      n_unique = length(u),
      values = I(utils::head(as.character(u), 12L)),
      min = if (num && length(u)) min(u) else NULL,
      max = if (num && length(u)) max(u) else NULL,
      integer_valued = integer_valued,
      suggested_role = role
    )
  })
}

dataset_overview <- function(ds) {
  list(
    dataset_id = ds$id,
    dataset_hash = ds$hash,
    filename = ds$filename,
    source = ds$source,
    n_rows = nrow(ds$data),
    n_cols = ncol(ds$data),
    columns = column_summary(ds$data),
    preview = utils::head(ds$data, 5L),
    identifier_suggestions = detect_identifier_columns(ds$data),
    suggested_config = ds$suggested_config
  )
}

# --- Örnek veri setleri -------------------------------------------------------

example_csv_hash <- function(df) {
  txt <- paste(utils::capture.output(utils::write.csv(df, row.names = FALSE)), collapse = "\n")
  paste0("sha256:", digest::digest(charToRaw(enc2utf8(txt)), algo = "sha256", serialize = FALSE))
}

load_example <- function(name) {
  if (identical(name, "holzinger")) {
    df <- lavaan::HolzingerSwineford1939
    df$school <- as.character(df$school)
    items <- paste0("x", 1:9)
    roles <- stats::setNames(rep("ignore", ncol(df)), names(df))
    roles[items] <- "item"; roles["id"] <- "id"; roles["school"] <- "group"
    cfg <- list(roles = as.list(roles),
                items = lapply(stats::setNames(items, items), function(i) list(reverse = FALSE,
                  subscale = c("visual", "textual", "speed")[(as.integer(sub("x", "", i)) - 1L) %/% 3L + 1L])))
    source <- sprintf("lavaan %s: HolzingerSwineford1939", as.character(utils::packageVersion("lavaan")))
  } else if (identical(name, "bfi")) {
    df <- psych::bfi
    rownames(df) <- NULL
    items <- names(df)[1:25]
    reverse <- c("A1", "C4", "C5", "E1", "E2", "O2", "O5")
    roles <- stats::setNames(rep("ignore", ncol(df)), names(df))
    roles[items] <- "item"; roles["gender"] <- "group"
    cfg <- list(roles = as.list(roles),
                items = lapply(stats::setNames(items, items), function(i) list(min = 1, max = 6,
                  reverse = i %in% reverse, subscale = substr(i, 1, 1))))
    source <- sprintf("psych %s: bfi", as.character(utils::packageVersion("psych")))
  } else {
    api_stop("example_not_found", "Örnek veri seti bulunamadı (holzinger ya da bfi).", 404L)
  }
  list(data = df, hash = example_csv_hash(df), filename = paste0(name, ".csv"),
       source = source, suggested_config = cfg)
}

# --- Sütun rolleri ve madde ayarları ------------------------------------------

build_config <- function(df, body) {
  roles <- body$roles
  if (!is.list(roles) || is.null(names(roles))) api_stop("invalid_roles", "Sütun rolleri bir nesne olmalıdır.", 422L)
  unknown <- setdiff(names(roles), names(df))
  if (length(unknown)) api_stop("unknown_column", sprintf("Veride olmayan sütun: %s", paste(unknown, collapse = ", ")), 422L)
  roles <- vapply(roles, function(r) as.character(r)[1], "")
  bad <- roles[!(roles %in% c("item", "group", "id", "ignore"))]
  if (length(bad)) api_stop("invalid_role", sprintf("Geçersiz rol: %s", paste(unique(bad), collapse = ", ")), 422L)
  items <- names(roles)[roles == "item"]
  groups <- names(roles)[roles == "group"]
  if (length(items) < 2L) api_stop("too_few_items", "En az iki madde sütunu seçilmelidir.", 422L)
  if (length(groups) > 1L) api_stop("too_many_groups", "En fazla bir grup değişkeni seçilebilir.", 422L)
  not_num <- items[!vapply(df[items], is.numeric, logical(1))]
  if (length(not_num)) {
    api_stop("item_not_numeric", sprintf("Madde sütunları sayısal olmalıdır: %s", paste(not_num, collapse = ", ")), 422L)
  }
  item_cfg <- body$items
  rows <- lapply(items, function(i) {
    ic <- if (is.list(item_cfg)) item_cfg[[i]] else NULL
    mn <- ic$min; mx <- ic$max
    has_range <- !is.null(mn) || !is.null(mx)
    if (has_range) {
      if (is.null(mn) || is.null(mx) || !is.numeric(mn) || !is.numeric(mx) || mn != round(mn) || mx != round(mx) || mn >= mx) {
        api_stop("invalid_range", sprintf("'%s' için en küçük ve en büyük kategori tam sayı olmalı ve küçük < büyük olmalıdır.", i), 422L)
      }
    }
    rev <- isTRUE(ic$reverse)
    if (rev && !has_range) api_stop("reverse_needs_range", sprintf("'%s' ters kodlanacaksa kategori aralığı verilmelidir.", i), 422L)
    sub <- ic$subscale
    data.frame(name = i, min = if (has_range) as.numeric(mn) else NA_real_,
               max = if (has_range) as.numeric(mx) else NA_real_, reverse = rev,
               subscale = if (is.null(sub) || !nzchar(sub)) NA_character_ else as.character(sub),
               stringsAsFactors = FALSE)
  })
  list(
    items = do.call(rbind, rows),
    group = if (length(groups)) groups else NULL,
    group_valid_values = if (length(groups) && length(body$group_valid_values)) I(as.character(body$group_valid_values)) else NULL,
    id_columns = I(names(roles)[roles == "id"])
  )
}

# --- Temizleme (SPEC M1; sıra SPEC_REVIEW CL-1, v1.2'de belge sahibinin sırasıyla) ----
# Sıra: geçersiz grup → eksik → aralık dışı → düz yanıt (ham) → ters kodlama.
# Satır bazlı kurallar olduğu için son N sıradan bağımsızdır; sıra yalnızca hangi
# satırın hangi adımda sayıldığını belirler (§11.3 adım sayıları bu sıraya göredir).
# rules: list(invalid_group, missing, out_of_range, straightline, reverse); her biri TRUE/FALSE.

clean_rule_keys <- c("invalid_group", "missing", "out_of_range", "straightline", "reverse")

clean_dataset <- function(data, config, rules = list()) {
  on <- function(key) if (is.null(rules[[key]])) TRUE else isTRUE(rules[[key]])
  items <- config$items$name
  grp <- config$group
  x <- data
  n_raw <- nrow(x)
  keep <- rep(TRUE, n_raw)
  steps <- data.frame(step = character(), removed = integer(), remaining = integer(), stringsAsFactors = FALSE)
  add_step <- function(step, bad) {
    newly <- bad & keep
    keep <<- keep & !newly
    steps[nrow(steps) + 1L, ] <<- list(step, sum(newly), sum(keep))
  }
  item_missing <- vapply(items, function(i) mean(is.na(x[[i]])), numeric(1))

  if (!is.null(grp) && on("invalid_group")) {
    g <- x[[grp]]
    bad <- is.na(g)
    if (length(config$group_valid_values)) bad <- bad | !(as.character(g) %in% config$group_valid_values)
    add_step("invalid_group", bad)
  }
  if (on("missing")) {
    add_step("missing", !stats::complete.cases(x[, items, drop = FALSE]))
  }
  bounded <- items[!is.na(config$items$min)]
  if (length(bounded) && on("out_of_range")) {
    bad <- rep(FALSE, n_raw)
    for (i in bounded) {
      v <- x[[i]]
      lo <- config$items$min[config$items$name == i]
      hi <- config$items$max[config$items$name == i]
      bad <- bad | (!is.na(v) & (v < lo | v > hi | v != round(v)))
    }
    add_step("out_of_range", bad)
  }
  if (on("straightline")) {
    m <- as.matrix(x[, items, drop = FALSE])
    bad <- apply(m, 1L, function(r) {
      r <- r[!is.na(r)]
      length(r) >= 2L && all(r == r[1])
    })
    add_step("straightline", bad)
  }

  out <- x[keep, c(items, grp), drop = FALSE]
  rownames(out) <- NULL
  reversed <- character()
  if (on("reverse")) {
    for (k in which(config$items$reverse)) {
      i <- config$items$name[k]
      out[[i]] <- config$items$min[k] + config$items$max[k] - out[[i]]
      reversed <- c(reversed, i)
    }
  }
  list(data = out, steps = steps, n_raw = n_raw, n_final = nrow(out),
       item_missing = item_missing, reversed = reversed)
}

clean_step_labels <- list(
  invalid_group = c(tr = "hatalı grup", en = "invalid group"),
  missing = c(tr = "eksik", en = "missing"),
  out_of_range = c(tr = "aralık dışı", en = "out of range"),
  straightline = c(tr = "düz yanıt", en = "straight-lining")
)

clean_summary_text <- function(cl, lang) {
  lbl <- function(s) clean_step_labels[[s]][[lang]]
  parts <- c(sprintf("%s: %s", if (lang == "tr") "Ham" else "Raw", fmt_int(cl$n_raw, lang)))
  for (k in seq_len(nrow(cl$steps))) {
    if (cl$steps$removed[k] > 0L) parts <- c(parts, sprintf("%s %s", lbl(cl$steps$step[k]), fmt_int(cl$steps$removed[k], lang)))
  }
  parts <- c(parts, sprintf("%s: %s", if (lang == "tr") "analiz" else "analysed", fmt_int(cl$n_final, lang)))
  paste(parts, collapse = " → ")
}

analysis_clean <- function(data, config, rules, dataset_hash) {
  rules <- rules[intersect(names(rules), clean_rule_keys)]
  cl <- clean_dataset(data, config, rules)
  steps <- cl$steps
  steps$label_tr <- vapply(steps$step, function(s) clean_step_labels[[s]][["tr"]], "")
  steps$label_en <- vapply(steps$step, function(s) clean_step_labels[[s]][["en"]], "")
  t1_rows <- rbind(
    data.frame(step = "raw", label_tr = "Ham veri", label_en = "Raw data", removed = NA_integer_, remaining = cl$n_raw),
    steps[, c("step", "label_tr", "label_en", "removed", "remaining")]
  )
  t1 <- make_table("T1", "Temizleme özeti", "Cleaning summary",
    list(tbl_col("label_tr", "Adım", "Step"), tbl_col("removed", "Çıkarılan", "Removed", "int"),
         tbl_col("remaining", "Kalan", "Remaining", "int")),
    t1_rows,
    note_tr = paste("Kurallar bu sırayla uygulanır; bir satır yalnızca ilk eşleştiği kuralda sayılır.",
                    "Düz yanıt, ters kodlamadan önce ham yanıtlarda aranır."),
    note_en = paste("Rules are applied in this order; a row is counted only under the first rule it matches.",
                    "Straight-lining is detected on raw responses, before reverse coding."))
  t1$rows_fmt$en$label_tr <- t1_rows$label_en
  t2 <- make_table("T2", "Madde bazında eksik yanıt oranı (ham veri)", "Item missingness (raw data)",
    list(tbl_col("item", "Madde", "Item"), tbl_col("missing", "Eksik", "Missing", "pct", 1L)),
    data.frame(item = names(cl$item_missing), missing = unname(cl$item_missing)))
  warns <- list()
  if (isTRUE(rules$straightline %||% TRUE) && !any(config$items$reverse)) {
    warns[[length(warns) + 1L]] <- warning_item("straightline_no_reverse",
      "Ölçekte ters madde yok: düz yanıt kuralı, uç ama tutarlı yanıt veren katılımcıları da silebilir.",
      "The scale has no reverse-keyed items: the straight-lining rule may also remove extreme but consistent respondents.")
  }
  if (cl$n_final < 2L) api_stop("no_rows_left", "Temizlemeden sonra analiz edilecek satır kalmadı.", 422L)
  list(
    clean = cl,
    record = make_record(
      module = "data_clean", dataset_hash = dataset_hash,
      settings = list(rules = lapply(stats::setNames(clean_rule_keys, clean_rule_keys), function(k) is.null(rules[[k]]) || isTRUE(rules[[k]])),
                      group_valid_values = config$group_valid_values),
      results = list(n_raw = cl$n_raw, n_final = cl$n_final, steps = cl$steps, reversed = I(cl$reversed),
                     summary_tr = clean_summary_text(cl, "tr"), summary_en = clean_summary_text(cl, "en")),
      tables = list(t1, t2), warnings = warns
    )
  )
}
