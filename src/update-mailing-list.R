# Regenerate auxiliary-data/mailing-list.txt from the contributor emails in model-metadata/.
#
# The output is a single line of semicolon-separated addresses, which pastes
# directly into the To, Cc or Bcc field of Outlook. Addresses already in the
# file are kept (so hub staff or data owners can be added by hand); addresses
# found in metadata are added. Nothing is ever removed automatically.

metadata_dir <- "model-metadata"
list_file <- "auxiliary-data/mailing-list.txt"

read_list <- function(path) {
  if (!file.exists(path)) return(character())
  text <- paste(readLines(path, warn = FALSE), collapse = ";")
  trimws(strsplit(text, ";", fixed = TRUE)[[1]])
}

metadata_emails <- function(dir) {
  files <- list.files(dir, pattern = "[.]ya?ml$", full.names = TRUE)
  unlist(lapply(files, function(f) {
    m <- tryCatch(suppressWarnings(yaml::read_yaml(f)), error = function(e) {
      stop("Could not parse ", f, ": ", conditionMessage(e), call. = FALSE)
    })
    vapply(m$model_contributors, function(c) {
      if (is.null(c$email)) NA_character_ else trimws(as.character(c$email))
    }, character(1))
  }))
}

emails <- c(read_list(list_file), metadata_emails(metadata_dir))
emails <- emails[!is.na(emails) & nzchar(emails)]
valid <- grepl("^[^@[:space:];,<>]+@[^@[:space:];,<>]+[.][^@[:space:];,<>]+$", emails)
if (any(!valid)) {
  warning("Skipping entries that are not email addresses: ",
          paste(emails[!valid], collapse = ", "), call. = FALSE)
  emails <- emails[valid]
}
# de-duplicate case-insensitively, keeping the first spelling seen
emails <- emails[!duplicated(tolower(emails))]
emails <- emails[order(tolower(emails))]

writeLines(paste(emails, collapse = "; "), list_file)
cat(length(emails), "addresses written to", list_file, "\n")
