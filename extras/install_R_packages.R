#!/usr/bin/env Rscript
# ---------------------------------------------------------------------------
# Install the R packages RiboTaper needs, in a way that works on modern R
# (tested on R 4.5.3).  Run this once inside the RiboTaper environment:
#
#     Rscript extras/install_R_packages.R
#
# It is idempotent: packages already present are skipped.
# ---------------------------------------------------------------------------

repos <- "https://cloud.r-project.org"
have  <- function(p) requireNamespace(p, quietly = TRUE)

# 1) Ordinary CRAN packages. These normally come from conda (environment.yml),
#    but we install any that are missing (e.g. r-multitaper has no conda build
#    on linux-aarch64, so it is compiled here from source).
cran_pkgs <- c("seqinr", "ade4", "multitaper", "doMC", "foreach", "iterators")
for (p in cran_pkgs) {
  if (!have(p)) {
    message("Installing ", p, " from CRAN ...")
    install.packages(p, repos = repos)
  }
}

# 2) XNomial — used by RiboTaper for the exact multinomial test (xmulti()).
#    It was ARCHIVED on CRAN in 2021, so it must be installed from the archive.
#    Its C sources use the S-compatibility macros Calloc/Free/Realloc, which
#    were removed from R's public headers in R 4.5 (STRICT_R_HEADERS). We map
#    them to their canonical R_Calloc/R_Free/R_Realloc replacements at compile
#    time via a generated src/Makevars, so the package builds cleanly.
if (!have("XNomial")) {
  message("Installing XNomial 1.0.4 from the CRAN archive (with R>=4.5 build fix) ...")
  url <- "https://cran.r-project.org/src/contrib/Archive/XNomial/XNomial_1.0.4.tar.gz"
  td  <- tempfile("xnomial_"); dir.create(td)
  tb  <- file.path(td, "XNomial_1.0.4.tar.gz")
  utils::download.file(url, tb, quiet = TRUE)
  utils::untar(tb, exdir = td)
  writeLines(
    "PKG_CPPFLAGS = -DCalloc=R_Calloc -DFree=R_Free -DRealloc=R_Realloc",
    file.path(td, "XNomial", "src", "Makevars")
  )
  install.packages(file.path(td, "XNomial"), repos = NULL, type = "source")
}

# 3) Report.
pkgs <- c("XNomial", "multitaper", "foreach", "doMC", "iterators", "seqinr", "ade4")
ok   <- vapply(pkgs, have, logical(1))
print(data.frame(package = pkgs, installed = ok, row.names = NULL))
if (!all(ok)) stop("Some R packages failed to install: ",
                   paste(pkgs[!ok], collapse = ", "))
cat("\nAll RiboTaper R dependencies are installed and loadable.\n")
