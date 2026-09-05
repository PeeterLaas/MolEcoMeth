# Course-wide facts (title, repository, semester start, logo paths) live in
# _quarto.yml so they are stated once. Quarto does not hand project-level
# metadata to the knitr engine here, so read the file directly instead of
# going through rmarkdown::metadata.

# Estonian titles have to survive the trip through R. Under a C locale R
# escapes them to <U+00F6> in kable() output, so claim a UTF-8 locale first.
if (!isTRUE(l10n_info()[["UTF-8"]])) {
  for (loc in c("C.UTF-8", "C.utf8", "en_US.UTF-8", "en_US.utf8")) {
    if (suppressWarnings(Sys.setlocale("LC_CTYPE", loc)) != "") break
  }
}

course_root <- function(from = getwd()) {
  root <- normalizePath(from, mustWork = TRUE)
  while (!file.exists(file.path(root, "_quarto.yml"))) {
    parent <- dirname(root)
    if (identical(parent, root)) {
      stop("No _quarto.yml found above ", from, call. = FALSE)
    }
    root <- parent
  }
  root
}

course_meta <- function(key = NULL) {
  # Read the bytes and mark them UTF-8 rather than letting the connection
  # re-encode: the file holds Estonian titles and em-dashes, and R may be
  # running under a C locale here or on a CI runner.
  path <- file.path(course_root(), "_quarto.yml")
  txt  <- rawToChar(readBin(path, "raw", n = file.info(path)$size))
  Encoding(txt) <- "UTF-8"
  meta <- yaml::yaml.load(txt)
  if (is.null(key)) return(meta)
  value <- meta[[key]]
  if (is.null(value)) stop("`", key, "` is not set in _quarto.yml", call. = FALSE)
  value
}

# Resolve a project-relative path (as written in _quarto.yml) against the
# directory the current document renders from.
course_path <- function(...) {
  file.path(course_root(), ...)
}

# --- Estonian dates ---------------------------------------------------------
# Rendered without touching LC_TIME: et_EE.UTF-8 is not installed on the CI
# runner, so %B and %a would silently fall back to English month and weekday
# names on the published site. Same reasoning as the LC_CTYPE block above.

ET_MONTHS <- c("jaanuar", "veebruar", "märts", "aprill", "mai", "juuni",
               "juuli", "august", "september", "oktoober", "november",
               "detsember")

# ISO weekday order, so %u indexes straight into it.
ET_WEEKDAYS <- c("E", "T", "K", "N", "R", "L", "P")

# 04.09.2026
et_date <- function(x) format(as.Date(x), "%d.%m.%Y")

# 4. september 2026
et_date_long <- function(x) {
  x <- as.Date(x)
  paste0(as.integer(format(x, "%d")), ". ",
         ET_MONTHS[as.integer(format(x, "%m"))], " ",
         format(x, "%Y"))
}

# R 04.09
et_date_weekday <- function(x) {
  x <- as.Date(x)
  paste0(ET_WEEKDAYS[as.integer(format(x, "%u"))], " ", format(x, "%d.%m"))
}
