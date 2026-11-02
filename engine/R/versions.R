# Sürüm bilgisi (SPEC §2 "her çıktıda paket sürümleri gösterilir", §6.2 "engine").

engine_core_packages <- c(
  "lavaan", "semTools", "psych", "GPArotation", "MASS",
  "plumber", "mirai", "nanonext", "officer", "flextable",
  "jsonlite", "readxl", "digest"
)

installed_version <- function(pkg) {
  v <- tryCatch(utils::packageVersion(pkg), error = function(e) NULL)
  if (is.null(v)) NA_character_ else as.character(v)
}

engine_versions <- function(pkgs = engine_core_packages) {
  vers <- vapply(pkgs, installed_version, character(1))
  si <- utils::sessionInfo()
  list(
    R = paste(R.version$major, R.version$minor, sep = "."),
    packages = as.list(vers[!is.na(vers)]),
    missing = I(unname(pkgs[is.na(vers)])),
    platform = R.version$platform,
    blas = if (is.null(si$BLAS)) NA_character_ else si$BLAS,
    lapack = if (is.null(si$LAPACK)) NA_character_ else si$LAPACK,
    rng_kind = as.list(stats::setNames(RNGkind(), c("kind", "normal_kind", "sample_kind")))
  )
}

# renv.lock içindeki sürümlerle kurulu sürümleri karşılaştırır.
lockfile_mismatches <- function(lockfile, pkgs = engine_core_packages) {
  lock <- jsonlite::fromJSON(lockfile, simplifyVector = FALSE)
  out <- list()
  for (p in pkgs) {
    locked <- lock$Packages[[p]]$Version
    have <- installed_version(p)
    if (is.null(locked)) {
      out[[p]] <- list(locked = NA_character_, installed = have, reason = "kilit dosyasında yok")
    } else if (is.na(have)) {
      out[[p]] <- list(locked = locked, installed = NA_character_, reason = "kurulu değil")
    } else if (package_version(locked) != package_version(have)) {
      out[[p]] <- list(locked = locked, installed = have, reason = "sürüm farklı")
    }
  }
  r_locked <- lock$R$Version
  r_have <- paste(R.version$major, R.version$minor, sep = ".")
  if (!identical(r_locked, r_have)) {
    out[["R"]] <- list(locked = r_locked, installed = r_have, reason = "R sürümü farklı")
  }
  out
}
