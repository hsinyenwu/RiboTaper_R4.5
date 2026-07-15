# RiboTaper — Modernization notes (2026)

This is an updated copy of **RiboTaper 1.3.1a** (Calviello *et al.*, *Nature Methods* 2016;
Ohler lab, MDC Berlin). The original code targets software that is now ~10 years old —
**bedtools v2.17, samtools 0.1.19 and R 3.0** — and its build system actively refuses to
configure against a modern bedtools. This copy updates it to run on the current stack while
keeping the scientific logic byte-for-byte identical.

**Validated with:** bedtools **2.31.1**, samtools **1.24**, R **4.5.3**, and the R packages
XNomial (patched, see §7), multitaper, seqinr, ade4, doMC, foreach, iterators. The complete
pipeline was run end-to-end on a synthetic dataset (see §9).

The original download is preserved unmodified in `../Original/`. Everything below lives in
`../Claude_update/`.

---

## 1. Build system — `configure.ac`

The original `configure.ac` **caps** bedtools at 2.18 and errors out otherwise:

```m4
BEDTOOLS_VERSION_MAX=2.18.0
AX_COMPARE_VERSION([$BEDTOOLS_VERSION], [gt], [$BEDTOOLS_VERSION_MAX],
      [AC_MSG_ERROR([... Please install Bedtools $BEDTOOLS_VERSION_MAX or lower.])])
```

Changes:

- **Removed the upper bound.** bedtools is now required to be **≥ 2.27.0** (a *lower* bound),
  because the modernized scripts rely on the post-2.24 `coverage` semantics and on
  `getfasta -nameOnly` (added in 2.27). See §3 and §4.
- **Added an explicit samtools check** (**≥ 1.7**) and an **R version check** (hard minimum
  **4.0**, recommended **≥ 4.5**; a warning is printed for 4.0–4.4).
- **Dropped detection of the six deprecated standalone bedtools commands**
  (`coverageBed`, `bamToBed`, `closestBed`, `windowBed`, `intersectBed`, `fastaFromBed`).
  Only the single `bedtools` driver is now located and substituted (`@BEDTOOLS@`).
- **R-package checks** now also cover `iterators` and `ade4`, and the `XNomial` check prints
  actionable install instructions on failure (it is no longer on CRAN — see §7).
- **`configure` was regenerated** with autoconf 2.72 / automake 1.17, so the shipped
  `configure` already contains all of the above — you do **not** need autotools installed to
  build, only to re-generate.

## 2. bedtools — unified `bedtools <subcommand>` interface

Modern bedtools ships a single driver binary; the old per-command executables are deprecated.
All calls were rewritten:

| Original (v2.17)        | Modernized                    |
|-------------------------|-------------------------------|
| `coverageBed …`         | `bedtools coverage …`         |
| `bamToBed …`            | `bedtools bamtobed …`         |
| `closestBed …`          | `bedtools closest …`          |
| `windowBed …`           | `bedtools window …`           |
| `intersectBed …`        | `bedtools intersect …`        |
| `fastaFromBed …`        | `bedtools getfasta …`         |

## 3. bedtools `coverage` — the `-a`/`-b` semantics flip (most important change)

**This is the change most likely to silently corrupt results if done naively.**
In **bedtools 2.24.0** the `coverage` tool was changed so that coverage is computed **for the
`-a` file** (consistent with the rest of the suite), whereas previously it was computed **for
the `-b` file**. RiboTaper (written for 2.17) relies on the *old* meaning and also uses the
now-removed `-abam` flag.

Every `coverage` call was rewritten to **swap the operands** so that the per-region output is
preserved exactly, and `-abam <bam>` became `-b <bam>` (BAM is auto-detected):

```bash
# original (old semantics: coverage computed for the region file given to -b)
coverageBed -s -split -abam RIBO_unique.bam -b $1
coverageBed -s -d -a P_sites_all -b $1

# modernized (new semantics: region file is -a, reads/points are -b -> identical output)
bedtools coverage -s -split -a $1 -b RIBO_unique.bam
bedtools coverage -s -d -a $1 -b P_sites_all
```

The strandedness (`-s`), split-read handling (`-split`) and per-base depth (`-d`) options are
preserved, and the appended count/depth columns land in exactly the same positions the
downstream `awk`/R code expects. Affected files: `scripts/create_tracks.bash.in`,
`scripts/analyze_multi_clust.bash.in` (12 call sites total).

## 3.1 Coverage memory — stream large BAMs with `-sorted`

A consequence of the `-a`/`-b` swap in §3: bedtools computes coverage for `-a` and
**loads the `-b` file into memory**, whereas the original `-abam` form *streamed*
the BAM and loaded only the small region file. With the swap the large BAMs became
the in-memory (`-b`) input, so on real datasets `create_tracks.bash` could exhaust
RAM (observed on a real run: OOM-killed at 30 GB on the `RIBO_best.bam` coverage
step, which silently produced empty `RIBO_best_counts_*`/`RIBO_tracks_*` files and
then failed `tracks_analysis.R`).

Fix: the six BAM-based coverage calls in `create_tracks.bash` (and the four in
`analyze_multi_clust.bash`) now use bedtools' **sorted/streaming** algorithm, which
streams both inputs and keeps memory low and flat regardless of BAM size:

```bash
# genome file in the BAM's coordinate-sort order, region sorted to match
samtools view -H RIBO_best.bam | awk -F'\t' '/^@SQ/{...print SN,LN}' > genome.txt
bedtools sort -g genome.txt -i regions.bed > regions.sorted.bed
bedtools coverage -sorted -g genome.txt -s -split -a regions.sorted.bed -b RIBO_best.bam
```

The STAR BAMs are already coordinate-sorted, so only the small region file needs
sorting. Output is **byte-identical** to the default algorithm (verified for both
count and per-base `-d` modes). The lighter `P_sites_all` / `Centered_RNA` point
files stay on the default algorithm.

## 4. bedtools `getfasta` — `-name` → `-nameOnly`

From **bedtools 2.27**, `getfasta -name` writes headers of the form `name::chr:start-end`
instead of just `name`. RiboTaper builds a custom name, then parses it back by splitting on
`_`, so the extra `::chr:start-end` would corrupt every parsed record. The three affected
calls in `scripts/create_annotations_files.bash.in.in` now use **`-nameOnly`**, which restores
the original "name only" header. Verified: the resulting `sequences_ccds` name column is
`chr_start_end_CCDS_gene_strand`, exactly as before.

## 5. bedtools `closest` — sorted inputs

Modern `bedtools closest` requires both inputs to be coordinate-sorted. The metaplot pipelines
(`create_metaplots.bash.in.in`, `create_metaplots_nodo.bash.in`) now sort the streamed `-a`
input **numerically** (`sort -k1,1 -k2,2n`, previously `-k2,2g`) and also sort the `-b` file on
the fly:

```bash
… | sort -k1,1 -k2,2n | bedtools closest -s -t "last" -a stdin -b <(sort -k1,1 -k2,2n $2)
```

## 6. samtools (0.1.19 → 1.x)

- The read-selection filters are unchanged and 1.x-compatible:
  `samtools view -b -q 50 …` (unique) and `samtools view -b -F 0x100 …` (primary).
  `samtools view -c …` in `quality_check.R` is likewise unchanged.
- The metaplot **down-sampling** was simplified. The original wrote an intermediate headerless
  SAM and re-attached the header in three steps; modern samtools does it in one, because
  `view -b` always emits a header:

  ```bash
  # original (3 steps)
  samtools view -s 1.1 $1 > sample_to_metapl.sam
  cat <(samtools view -H $1) <(cat sample_to_metapl.sam) | samtools view - -bS > sample_to_metapl.bam
  # modernized (1 step)
  samtools view -b -s 1.1 $1 > sample_to_metapl.bam
  ```

## 7. R 4.5 compatibility

- **No changes were required to the RiboTaper R source.** The scripts already pass
  `stringsAsFactors = FALSE` explicitly wherever it matters, so R 4.0's change of the default
  does not affect them, and there are no `class(x) == "…"` comparisons that would trip R ≥ 4.2.
  All 13 R scripts parse and run under R 4.5.3 unchanged.
- **XNomial** (used for the exact multinomial test, `xmulti()`) was **archived on CRAN in
  2021** and cannot be installed the normal way. It is now installed from the CRAN archive,
  and — because its C sources use the S-compatibility macros `Calloc`/`Free`/`Realloc` that
  **R 4.5 removed** (`STRICT_R_HEADERS`) — it is compiled with those mapped to the canonical
  replacements:

  ```
  PKG_CPPFLAGS = -DCalloc=R_Calloc -DFree=R_Free -DRealloc=R_Realloc
  ```

  This is handled automatically by `extras/install_R_packages.R`.
- **multitaper** has no conda build on some architectures (e.g. arm64); the same helper
  compiles it from CRAN source when needed.

## 8. Reproducible environments

New files provide three interchangeable ways to get the exact stack:

- **`environment.yml`** — conda/mamba environment (solves on linux-64 and linux-aarch64).
- **`extras/install_R_packages.R`** — installs XNomial (patched) and any R package lacking a
  conda build; idempotent.
- **`Dockerfile`** and **`apptainer.def`** — fully reproducible container images that build and
  install RiboTaper on top of the environment.

See `INSTALL_MODERN.md` for copy-paste instructions.

## 9. Validation — synthetic end-to-end smoke test

Because RiboTaper needs Ribo-seq + RNA-seq BAMs plus a genome/GTF, a small synthetic dataset
was generated (a genome with 12 protein-coding genes carrying real ATG→STOP ORFs plus 3
non-coding genes, and Ribo-seq reads placed to give clean 3-nt periodicity, with RNA-seq
coverage). The **whole pipeline ran end-to-end** on the modernized code:

| Step | Script | Result |
|------|--------|--------|
| Annotation | `create_annotation_files.bash` | 12 CCDS + 3 non-CCDS regions, sequences parsed correctly (`-nameOnly`) |
| BAM filters | `Ribotaper.sh` (samtools) | unique/primary BAMs produced |
| P-sites | `P_sites_RNA_sites_calc.bash` | 37,926 P-sites (bamtobed) |
| Tracks | `create_tracks.bash` | coverage tracks for all regions (coverage a/b swap) |
| Track analysis | `tracks_analysis.R` | 12 + 12 + 3 exons; **perfect periodicity, multitaper p ≈ 2e-28** |
| Exon annotation | `annotate_exons.R` | 24 annotated rows |
| CCDS ORF finding | `CCDS_orf_finder.R` | **12 ORFs** (uses XNomial `xmulti`) |
| non-CCDS ORF finding | `NONCCDS_orf_finder.R` | 3 ncORFs |
| Protein DB | `create_protein_db.R` | `protein_db_max.fasta` |
| Final results | `ORF_final_results.R` | **15 ORFs total**, `Final_ORF_results.pdf`, translated-ORF BEDs |
| Metaplots | `create_metaplots.bash` | `metaplots/*.pdf` (samtools `-s`, window, sorted closest) |

**One step is not exercised by the smoke test: `quality_check.R`.** It produces QC plots only
(it does not feed ORF finding) and is written for real-scale data — it bins exons into
length×RPKM quantiles and only plots bins with **>10 exons**, which a tiny test set cannot
satisfy. It parses cleanly under R 4.5 and its only modernized dependency (`samtools view -c`)
works; it should behave exactly as before on real datasets.

## 10. Operational note — keep your genome index current

`bedtools getfasta` will happily use a **stale** `.fai` index and silently skip any feature
that lies beyond the length recorded there. If you regenerate or swap your genome FASTA, delete
the old `genome.fa.fai` (or re-run `samtools faidx genome.fa`) first. This is unchanged upstream
behavior, but worth flagging.

---

### File-by-file summary

| File | Change |
|------|--------|
| `configure.ac` | rewrote tool/version checks (see §1); regenerated `configure`, `Makefile.in`, `aclocal.m4` |
| `scripts/create_tracks.bash.in` | 8× `coverageBed` → `bedtools coverage` with `-a`/`-b` swap (§3) |
| `scripts/analyze_multi_clust.bash.in` | 4× `coverageBed` → `bedtools coverage` with `-a`/`-b` swap (§3) |
| `scripts/create_annotations_files.bash.in.in` | `fastaFromBed` → `bedtools getfasta`; `-name` → `-nameOnly` (§4) |
| `scripts/P_sites_RNA_sites_calc.bash.in` | `bamToBed` → `bedtools bamtobed` (§2) |
| `scripts/create_metaplots.bash.in.in` | samtools down-sample simplified (§6); bamtobed/window; sorted `closest` (§5) |
| `scripts/create_metaplots_nodo.bash.in` | bamtobed/window; sorted `closest` (§5) |
| `scripts/CCDS_orf_finder.R.in.in`, `scripts/NONCCDS_orf_finder.R.in.in` | `intersectBed` → `bedtools intersect` (§2) |
| `environment.yml`, `Dockerfile`, `apptainer.def`, `extras/install_R_packages.R` | new — reproducible environments (§8) |
| R scripts | **no source changes** (§7) |
