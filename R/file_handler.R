#' Save Attachment
#'
#' Save an uploaded file to the attachments directory with a unique name.
#'
#' @param file_info File info from Shiny fileInput (datapath, name)
#' @param attachments_dir Directory to store attachments
#' @return Relative path to saved file
#' @export
save_attachment <- function(file_info, attachments_dir = "attachments") {
    if (is.null(file_info) || is.null(file_info$datapath)) {
        return(NULL)
    }

    # Create attachments directory if it doesn't exist
    if (!dir.exists(attachments_dir)) {
        dir.create(attachments_dir, recursive = TRUE)
    }

    # Validate file type
    ext <- tolower(tools::file_ext(file_info$name))
    allowed_extensions <- c("pdf", "png", "jpg", "jpeg")

    if (!ext %in% allowed_extensions) {
        stop(sprintf(
            "File type '.%s' not allowed. Allowed types: %s",
            ext, paste(allowed_extensions, collapse = ", ")
        ))
    }

    # Generate unique filename
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    random_id <- paste(sample(c(0:9, letters), 8, replace = TRUE), collapse = "")
    unique_name <- sprintf("%s_%s.%s", timestamp, random_id, ext)

    # Full path to save file
    dest_path <- file.path(attachments_dir, unique_name)

    # Copy file
    file.copy(file_info$datapath, dest_path, overwrite = FALSE)

    # Return relative path
    dest_path
}

#' Get Attachment Path
#'
#' Get the full path to an attachment file.
#'
#' @param relative_path Relative path stored in database
#' @return Full path to attachment
#' @export
get_attachment <- function(relative_path) {
    if (is.null(relative_path) || relative_path == "") {
        return(NULL)
    }

    if (file.exists(relative_path)) {
        return(normalizePath(relative_path))
    }

    NULL
}

#' Delete Attachment
#'
#' Remove an attachment file from the filesystem.
#'
#' @param relative_path Relative path to attachment
#' @return Logical indicating success
#' @export
delete_attachment <- function(relative_path) {
    if (is.null(relative_path) || relative_path == "") {
        return(FALSE)
    }

    if (file.exists(relative_path)) {
        file.remove(relative_path)
        return(TRUE)
    }

    FALSE
}

#' Validate File Type
#'
#' Check if a file has an allowed extension.
#'
#' @param filename File name to check
#' @return Logical indicating if file type is valid
#' @export
validate_file_type <- function(filename) {
    ext <- tolower(tools::file_ext(filename))
    ext %in% c("pdf", "png", "jpg", "jpeg")
}
