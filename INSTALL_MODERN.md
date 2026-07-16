# Installing modernized RiboTaper

An end-to-end guide, from downloading the code to a working install. Validated with
bedtools 2.31.1, samtools 1.24 and R 4.5.3. See `CHANGES_MODERNIZATION.md` for what changed
and why.

RiboTaper installs its commands under a prefix **you choose** (`<PREFIX>/bin`), which you then
add to your `PATH`. Nothing requires root if you pick a writable prefix (e.g. inside a conda
environment, or under your home directory).

---

## 1. Download the code

```bash
git clone https://github.com/hsinyenwu/RiboTaper_R4.5.git
cd RiboTaper_R4.5
chmod +x configure          # in case the executable bit was dropped on upload
```

All commands below are run from inside this `RiboTaper_R4.5` directory.

---

## 2. Install RiboTaper — pick one option

### Option A — conda / mamba (recommended; no root, works on CentOS / HPC)

```bash
# (a) Already have conda (miniconda/anaconda)? Update it and use the free conda-forge +
#     bioconda channels (Anaconda's paid "defaults" ToS does not apply to those two).
conda update -n base -c conda-forge conda -y
conda config --add channels bioconda
conda config --add channels conda-forge
conda config --set channel_priority strict
conda install -n base -c conda-forge mamba -y          # optional, much faster solver
#     No conda yet? Install Miniforge: https://github.com/conda-forge/miniforge

# (b) Create the environment (modern bedtools / samtools / R)
mamba env create -f environment.yml                    # or: conda env create -f environment.yml
conda activate ribotaper

# (c) Install XNomial (patched for R >= 4.5) + anything lacking a conda build for your CPU
Rscript extras/install_R_packages.R

# (d) Build and install into the environment, then expose the commands
./configure --prefix="$CONDA_PREFIX/ribotaper"
make && make install
export PATH="$CONDA_PREFIX/ribotaper/bin:$PATH"         # add to ~/.bashrc to make permanent
```

> The shipped `./configure` is already regenerated, so autotools are not required to build.
> If it is missing or errors as out of date, run `autoreconf -fi` once first (autotools are in
> the environment).

### Option B — Docker

Builds a self-contained image (no local conda/R needed):

```bash
docker build -t ribotaper:r4.5 .
docker run --rm -v "$PWD":/data -w /data ribotaper:r4.5 \
    Ribotaper.sh RIBO.bam RNA.bam annot_dir 26,28,29 9,12,12 4
```

### Option C — Apptainer / Singularity (HPC clusters)

```bash
apptainer build ribotaper.sif apptainer.def
apptainer exec --bind "$PWD":/data ribotaper.sif \
    create_annotations_files.bash /data/annotation.gtf /data/genome.fa false false /data/annot_dir
```

### Option D — existing modules (bedtools / samtools / R already available)

Make sure your tools meet these minimums, then build into any writable prefix:

| Tool | Minimum |
|------|---------|
| bedtools | **2.27.0** (unified `bedtools <subcommand>` interface) |
| samtools | **1.7** (HTSlib-based) |
| R | **4.0** (≥ **4.5** recommended) |
| R packages | seqinr, ade4, multitaper, doMC, foreach, iterators, **XNomial** |

```bash
PREFIX="$HOME/ribotaper"                                # or any writable location you like
Rscript extras/install_R_packages.R                     # ensures XNomial (+ any missing) are present
./configure BEDTOOLS=$(command -v bedtools) SAMTOOLS=$(command -v samtools) \
            R=$(command -v R) RSCRIPT=$(command -v Rscript) --prefix="$PREFIX"
make && make install
export PATH="$PREFIX/bin:$PATH"
```

`./configure` verifies every tool and R package and stops with a clear message if anything is
missing or too old.

---

## 3. Verify the install

```bash
which create_annotations_files.bash Ribotaper.sh        # both should resolve to <PREFIX>/bin
```

---

## 4. Quick self-test (optional)

A tiny end-to-end run on your own inputs confirms everything is wired up (see the README for
argument details and `CHANGES_MODERNIZATION.md` §9 for the validated steps):

```bash
samtools faidx genome.fa                                # make sure the genome is indexed
create_annotations_files.bash annotation.gtf genome.fa false false annot_dir
Ribotaper.sh RIBO.bam RNA.bam annot_dir <read_lengths> <offsets> <n_cores>
```

---

## Notes

- **Each new shell:** `conda activate ribotaper` (Option A) and re-add the prefix to `PATH`,
  or put the `export PATH=...` line in your `~/.bashrc`.
- **Stale genome index:** if you change your genome FASTA, refresh its index
  (`samtools faidx genome.fa`) so `bedtools getfasta` doesn't skip regions from a stale `.fai`
  (see `CHANGES_MODERNIZATION.md` §10).
- **Chromosome names** must match exactly across your GTF, FASTA and BAM files, with no
  underscores — see the README's "Input requirements".
