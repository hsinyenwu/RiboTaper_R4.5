dnl -*- Autoconf -*-
dnl
dnl RiboTaper configure.ac
dnl
dnl Original: Copyright (C) 2016 Lorenzo Calviello / Ricardo Wurmus (MDC Berlin)
dnl Modernized 2026: updated for the unified `bedtools <subcommand>` interface
dnl (bedtools >= 2.27), samtools >= 1.x and R >= 4.x.  See CHANGES_MODERNIZATION.md
dnl for the full rationale behind every change.

AC_INIT([RiboTaper], [1.3.1a-mod2026])
AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_MACRO_DIR([m4])
AM_INIT_AUTOMAKE([color-tests -Wall -Wno-portability foreign])
AM_SILENT_RULES([yes])

# Check for any variant of "awk" and store path in "AWK" variable
AC_PROG_AWK
AC_PROG_SED

# ---------------------------------------------------------------------------
# External programmes.
#
# Modern bedtools ships a single `bedtools' driver binary and the old
# standalone commands (coverageBed, bamToBed, closestBed, windowBed,
# intersectBed, fastaFromBed) are deprecated.  The RiboTaper scripts now call
# the sub-command form (`bedtools coverage', `bedtools bamtobed', ...), so we
# only need to locate the single `bedtools' executable.
# ---------------------------------------------------------------------------
AC_ARG_VAR(GNUBASH,  override location of "bash" executable)
AC_ARG_VAR(SAMTOOLS, override location of "samtools" executable)
AC_ARG_VAR(BEDTOOLS, override location of "bedtools" executable)
AC_ARG_VAR(RSCRIPT,  override location of "Rscript" executable)
AC_ARG_VAR(R,        override location of "R" executable)

AS_IF([test -z "$GNUBASH"],
      [AC_PATH_PROG([GNUBASH], [bash])],
      [AC_MSG_NOTICE([Using $GNUBASH as bash executable.])])
AS_IF([test "x$GNUBASH" = x],
      [AC_MSG_ERROR([bash could not be found.])])

# ---- bedtools (require the modern unified interface) ----------------------
AS_IF([test -z "$BEDTOOLS"],
      [AC_PATH_PROG([BEDTOOLS], [bedtools])],
      [AC_MSG_NOTICE([Using $BEDTOOLS as bedtools executable.])])
AS_IF([test "x$BEDTOOLS" = x],
      [AC_MSG_ERROR([bedtools could not be found.  RiboTaper requires bedtools >= 2.27.0.])])
BEDTOOLS_VERSION_MIN=2.27.0
BEDTOOLS_VERSION=$($BEDTOOLS --version | $SED 's/^bedtools v//')
AC_MSG_NOTICE([Found bedtools version $BEDTOOLS_VERSION (minimum required: $BEDTOOLS_VERSION_MIN).])
AX_COMPARE_VERSION([$BEDTOOLS_VERSION], [lt], [$BEDTOOLS_VERSION_MIN],
      [AC_MSG_ERROR([The modernized RiboTaper scripts assume the bedtools >= 2.24 `coverage' semantics and the `getfasta -nameOnly' option (bedtools >= 2.27). Your bedtools is $BEDTOOLS_VERSION. Please install bedtools >= $BEDTOOLS_VERSION_MIN (latest recommended).])])

# ---- samtools (1.x) -------------------------------------------------------
AS_IF([test -z "$SAMTOOLS"],
      [AC_PATH_PROG([SAMTOOLS], [samtools])],
      [AC_MSG_NOTICE([Using $SAMTOOLS as samtools executable.])])
AS_IF([test "x$SAMTOOLS" = x],
      [AC_MSG_ERROR([samtools could not be found.  RiboTaper requires samtools >= 1.7.])])
SAMTOOLS_VERSION_MIN=1.7
SAMTOOLS_VERSION=$($SAMTOOLS --version | head -n1 | $SED 's/^samtools //')
AC_MSG_NOTICE([Found samtools version $SAMTOOLS_VERSION (minimum required: $SAMTOOLS_VERSION_MIN).])
AX_COMPARE_VERSION([$SAMTOOLS_VERSION], [lt], [$SAMTOOLS_VERSION_MIN],
      [AC_MSG_ERROR([RiboTaper requires samtools >= $SAMTOOLS_VERSION_MIN (the modern HTSlib-based series). Your samtools is $SAMTOOLS_VERSION.])])

# ---- R / Rscript ----------------------------------------------------------
AS_IF([test -z "$RSCRIPT"],
      [AC_PATH_PROG([RSCRIPT], [Rscript])],
      [AC_MSG_NOTICE([Using $RSCRIPT as Rscript executable.])])
AS_IF([test -z "$R"],
      [AC_PATH_PROG([R], [R])],
      [AC_MSG_NOTICE([Using $R as R executable.])])
AS_IF([test "x$R" = x],
      [AC_MSG_ERROR([R could not be found, so we cannot test for R packages.])])

# Hard minimum R 4.0; RiboTaper is developed/tested against R >= 4.5.
R_VERSION_MIN=4.0.0
R_VERSION_REC=4.5.0
R_VERSION=$($R --version | head -n1 | $SED -n 's/^R version \([[0-9.]]*\).*/\1/p')
AC_MSG_NOTICE([Found R version $R_VERSION (minimum required: $R_VERSION_MIN, recommended: >= $R_VERSION_REC).])
AX_COMPARE_VERSION([$R_VERSION], [lt], [$R_VERSION_MIN],
      [AC_MSG_ERROR([RiboTaper requires R >= $R_VERSION_MIN. Your R is $R_VERSION.])])
AX_COMPARE_VERSION([$R_VERSION], [lt], [$R_VERSION_REC],
      [AC_MSG_WARN([R $R_VERSION is older than the recommended $R_VERSION_REC. RiboTaper should still work, but >= $R_VERSION_REC is advised.])])

# ---------------------------------------------------------------------------
# Required R packages.
# ---------------------------------------------------------------------------
AC_DEFUN([AX_TEST_R_PACKAGE], [
    pushdef([PKG],$1)
    AC_MSG_CHECKING([for R package "PKG"])
    if test -z "$HURRY"
    then
      TEST=$($R --no-echo --vanilla -e 'if(!require("PKG", quietly=TRUE)) stop("not found")' 2>/dev/null)
      AS_IF([test $? != 0],
            [AC_MSG_ERROR([R package PKG could not be loaded. See CHANGES_MODERNIZATION.md / environment.yml for installation help.])],
            [AC_MSG_RESULT([OK])])
    else
      AC_MSG_RESULT([OK])
    fi
    popdef([PKG])
])

# XNomial was archived on CRAN (2021).  Give a targeted, actionable message.
AC_MSG_CHECKING([for R package "XNomial"])
if test -z "$HURRY"; then
  $R --no-echo --vanilla -e 'if(!require("XNomial", quietly=TRUE)) stop("not found")' >/dev/null 2>&1
  AS_IF([test $? != 0],
        [AC_MSG_ERROR([R package XNomial could not be loaded.
   XNomial was removed from the main CRAN repository in 2021 and must be
   installed from the CRAN archive, e.g. from R:
       install.packages(
         "https://cran.r-project.org/src/contrib/Archive/XNomial/XNomial_1.0.4.tar.gz",
         repos = NULL, type = "source")
   (a C/C++ toolchain is required to build it).  The provided conda
   environment.yml / Dockerfile already handle this for you.])],
        [AC_MSG_RESULT([OK])])
else
  AC_MSG_RESULT([OK])
fi

AX_TEST_R_PACKAGE([foreach])
AX_TEST_R_PACKAGE([iterators])
AX_TEST_R_PACKAGE([doMC])
AX_TEST_R_PACKAGE([multitaper])
AX_TEST_R_PACKAGE([seqinr])
AX_TEST_R_PACKAGE([ade4])

# Substitute placeholders to generate these target files
AC_CONFIG_FILES([Makefile
                 scripts/P_sites_RNA_sites_calc.bash
                 scripts/create_metaplots_nodo.bash
                 scripts/analyze_multi_clust.bash
                 scripts/create_tracks.bash
                 scripts/tracks_analysis.R.in
                 scripts/metag.R
                 scripts/gtf_to_start_stop_tr.R
                 scripts/genes_coor.R
                 scripts/quality_check.R
                 scripts/NONCCDS_orf_finder.R.in
                 scripts/annotate_exons.R.in
                 scripts/create_protein_db.R
                 scripts/ORF_final_results.R
                 scripts/write_startstops.R
                 scripts/include_multi_nomerge.R
                 scripts/CCDS_orf_finder.R.in])

AC_CONFIG_FILES([scripts/Ribotaper.sh.in], [chmod +x scripts/Ribotaper.sh.in])
AC_CONFIG_FILES([scripts/Ribotaper_ORF_find.sh.in], [chmod +x scripts/Ribotaper_ORF_find.sh.in])
AC_CONFIG_FILES([scripts/create_annotations_files.bash.in], [chmod +x scripts/create_annotations_files.bash.in])
AC_CONFIG_FILES([scripts/create_metaplots.bash.in], [chmod +x scripts/create_metaplots.bash.in])

AC_OUTPUT
