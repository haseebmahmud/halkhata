args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 1L) {
  stop("Pass the repository root as the only argument.")
}

project_root <- normalizePath(args[[1]], winslash = "/", mustWork = TRUE)
runtime_root <- file.path(project_root, "build", "electron-runtime")
r_home_source <- normalizePath(R.home(), winslash = "/", mustWork = TRUE)
is_macos <- identical(Sys.info()[["sysname"]], "Darwin")
framework_version <- basename(dirname(r_home_source))
r_bundle_target <- file.path(runtime_root, "R")
r_home_target <- if (is_macos) {
  file.path(
    runtime_root,
    "mac-r-framework",
    "Library",
    "Frameworks",
    "R.framework",
    "Versions",
    framework_version,
    "Resources"
  )
} else {
  r_bundle_target
}
r_library_target <- file.path(runtime_root, "R-library")
app_target <- file.path(runtime_root, "shiny-app")

if (dir.exists(runtime_root)) {
  unlink(runtime_root, recursive = TRUE)
}
dir.create(r_home_target, recursive = TRUE)
dir.create(r_library_target, recursive = TRUE)
dir.create(app_target, recursive = TRUE)

copy_tree <- function(source, target) {
  if (!file.exists(source)) {
    stop("Required R runtime path does not exist: ", source)
  }
  if (identical(Sys.info()[["sysname"]], "Darwin")) {
    status <- system2("ditto", c(shQuote(source), shQuote(target)))
    if (status != 0L) {
      stop("Could not copy R runtime path: ", source)
    }
  } else {
    dir.create(target, recursive = TRUE, showWarnings = FALSE)
    paths <- list.files(
      source,
      all.files = TRUE,
      full.names = TRUE,
      no.. = TRUE
    )
    if (length(paths) > 0L) {
      copied <- file.copy(
        paths,
        target,
        recursive = TRUE,
        copy.mode = TRUE,
        copy.date = TRUE
      )
      if (!all(copied)) {
        stop("Could not copy all files from R runtime path: ", source)
      }
    }
  }
}

runtime_entries <- c("bin", "etc", "lib", "modules", "share", "fontconfig")
for (entry in runtime_entries) {
  source <- file.path(r_home_source, entry)
  if (file.exists(source)) {
    copy_tree(source, file.path(r_home_target, entry))
  }
}

for (entry in c("Rscript", "R", "COPYING", "SVN-REVISION", "Info.plist")) {
  source <- file.path(r_home_source, entry)
  if (file.exists(source)) {
    if (!file.copy(source, file.path(r_home_target, entry), copy.mode = TRUE)) {
      stop("Could not copy R runtime file: ", source)
    }
  }
}

if (is_macos) {
  framework_root <- file.path(
    runtime_root,
    "mac-r-framework",
    "Library",
    "Frameworks",
    "R.framework"
  )
  version_dir <- dirname(r_home_target)
  create_link <- function(target, link) {
    if (!file.symlink(target, link)) {
      stop("Could not create R framework link: ", link)
    }
  }
  create_link("Resources/lib/libR.dylib", file.path(version_dir, "R"))
  create_link("Resources/include", file.path(version_dir, "Headers"))
  create_link(
    framework_version,
    file.path(framework_root, "Versions", "Current")
  )
  create_link("Versions/Current/Resources", file.path(framework_root, "Resources"))
  create_link("Versions/Current/R", file.path(framework_root, "R"))
  create_link(
    "Versions/Current/Resources/lib",
    file.path(framework_root, "Libraries")
  )
  create_link("Versions/Current/Headers", file.path(framework_root, "Headers"))
  system_r_home <- "/Library/Frameworks/R.framework/Resources"
  writeLines(
    paste0(
      '{"rHome":"',
      system_r_home,
      '","rscript":"',
      file.path(system_r_home, "Rscript"),
      '"}'
    ),
    file.path(runtime_root, "r-runtime.json")
  )
  writeLines(framework_version, file.path(runtime_root, "r-framework-version"))
}

base_library <- R.home("library")
base_packages <- installed.packages(lib.loc = base_library)
base_packages <- rownames(base_packages)[
  !is.na(base_packages[, "Priority"]) & base_packages[, "Priority"] == "base"
]
dir.create(file.path(r_home_target, "library"), recursive = TRUE)
for (package in base_packages) {
  source <- file.path(base_library, package)
  copy_tree(source, file.path(r_home_target, "library", package))
}

package_source <- file.path(runtime_root, "package-source", "halkhata")
dir.create(package_source, recursive = TRUE)
for (file in c("DESCRIPTION", "NAMESPACE", "LICENSE.md")) {
  if (!file.copy(file.path(project_root, file), package_source)) {
    stop("Could not stage package file: ", file)
  }
}
for (directory in c("R", "man")) {
  source <- file.path(project_root, directory)
  pattern <- if (directory == "R") "\\.R$" else "\\.Rd$"
  files <- list.files(source, pattern = pattern, full.names = TRUE)
  destination <- file.path(package_source, directory)
  dir.create(destination)
  for (file in files) {
    if (!file.copy(file, destination)) {
      stop("Could not stage package source: ", file)
    }
  }
}

description <- read.dcf(file.path(package_source, "DESCRIPTION"))
imports <- trimws(strsplit(description[1, "Imports"], ",", fixed = TRUE)[[1]])
imports <- sub("\\s*\\(.*$", "", imports)

utils::install.packages(
  imports,
  lib = r_library_target,
  repos = c(CRAN = "https://cloud.r-project.org"),
  dependencies = NA
)

package_build_dir <- file.path(runtime_root, "package-build")
dir.create(package_build_dir)
old_working_directory <- setwd(package_build_dir)
status <- system2(
  file.path(R.home("bin"), "R"),
  c(
    "CMD",
    "build",
    "--no-build-vignettes",
    "--no-manual",
    "--no-resave-data",
    shQuote(package_source)
  ),
  stdout = "",
  stderr = ""
)
setwd(old_working_directory)
if (status != 0L) {
  stop("Building the sanitized halkhata package source failed.")
}
package_tarball <- list.files(
  package_build_dir,
  pattern = "^halkhata_.*\\.tar\\.gz$",
  full.names = TRUE
)
if (length(package_tarball) != 1L) {
  stop("Could not locate the sanitized halkhata source archive.")
}
utils::install.packages(
  package_tarball,
  repos = NULL,
  type = "source",
  lib = r_library_target,
  dependencies = FALSE
)
unlink(c(file.path(runtime_root, "package-source"), package_build_dir), recursive = TRUE)

app_source <- file.path(project_root, "inst", "shiny-app")
for (file in c("app.R")) {
  if (!file.copy(file.path(app_source, file), file.path(app_target, file))) {
    stop("Could not stage Shiny app file: ", file)
  }
}
if (!file.copy(
  file.path(app_source, "www"),
  app_target,
  recursive = TRUE
)) {
  stop("Could not stage Shiny app assets.")
}
