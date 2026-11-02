# Oturum belleği (SPEC §6.1, §10). Veri yalnızca ana süreçte, bellekte tutulur.
# İşlem yapılmadan SESSION_TTL_MINUTES (varsayılan 60) dakika geçen veri setleri silinir.

.olceklab <- new.env(parent = emptyenv())
.olceklab$datasets <- list()
.olceklab$analyses <- list()
.olceklab$workers <- 0L
.olceklab$jobs <- list()

session_ttl_minutes <- function() {
  v <- suppressWarnings(as.numeric(Sys.getenv("SESSION_TTL_MINUTES", "60")))
  if (is.na(v) || v <= 0) 60 else v
}

dataset_put <- function(ds) {
  id <- uuid::UUIDgenerate(use.time = FALSE)
  ds$id <- id
  ds$created <- Sys.time()
  ds$last_access <- ds$created
  .olceklab$datasets[[id]] <- ds
  id
}

dataset_get <- function(id) {
  if (!is.character(id) || length(id) != 1L || !nzchar(id) || is.null(.olceklab$datasets[[id]])) {
    api_stop("dataset_not_found",
             "Veri seti bulunamadı. Oturum süresi dolmuş olabilir; dosyayı yeniden yükleyin.", 404L)
  }
  .olceklab$datasets[[id]]$last_access <- Sys.time()
  .olceklab$datasets[[id]]
}

dataset_update <- function(id, ds) {
  ds$last_access <- Sys.time()
  .olceklab$datasets[[id]] <- ds
  invisible(ds)
}

analysis_store <- function(record, dataset_id) {
  .olceklab$analyses[[record$analysis_id]] <- list(
    dataset_id = dataset_id, module = record$module, r_script = record$r_script,
    record = record, created = Sys.time()
  )
  invisible(record$analysis_id)
}

analysis_get <- function(id) {
  a <- .olceklab$analyses[[id]]
  if (is.null(a)) api_stop("analysis_not_found", "Analiz kaydı bulunamadı.", 404L)
  a
}

session_purge <- function(now = Sys.time(), ttl_minutes = session_ttl_minutes()) {
  ids <- names(.olceklab$datasets)
  expired <- ids[vapply(ids, function(i) {
    difftime(now, .olceklab$datasets[[i]]$last_access, units = "mins") > ttl_minutes
  }, logical(1))]
  for (i in expired) .olceklab$datasets[[i]] <- NULL
  if (length(expired)) {
    keep <- vapply(.olceklab$analyses, function(a) !(a$dataset_id %in% expired), logical(1))
    .olceklab$analyses <- .olceklab$analyses[keep]
  }
  invisible(expired)
}
