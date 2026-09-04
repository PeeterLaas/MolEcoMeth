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
