# Installing modernized RiboTaper

Three options — pick one. All were validated with bedtools 2.31.1, samtools 1.24 and R 4.5.3.
See `CHANGES_MODERNIZATION.md` for what changed and why.

**First, download the code** from <https://github.com/hsinyenwu/RiboTaper_R4.5> (each option below then enters the folder):

```bash
git clone https://github.com/hsinyenwu/RiboTaper_R4.5.git
```

---

## Option A — conda / mamba (recommended)

```bash
cd RiboTaper_R4.5

# 0. (miniconda3 / anaconda users) update conda and switch to the free channels.
#    Anaconda's paid "defaults" ToS does NOT apply to conda-forge / bioconda.
conda update -n base -c conda-forge conda -y
conda config --add channels bioconda
conda config --add channels conda-forge
conda config --set channel_priority strict
conda install -n base -c conda-forge mamba -y          # optional, faster solver

# 1. Create the environment with the modern tool stack
mamba env create -f environment.yml          # or: conda env create -f environment.yml
conda activate ribotaper

# 2. Install XNomial (patched for R>=4.5) + anything lacking a conda build on your CPU
Rscript extras/install_R_packages.R

# 3. Build and install RiboTaper
./configure --prefix="$CONDA_PREFIX/ribotaper"
make
make install

# 4. Use it
export PATH="$CONDA_PREFIX/ribotaper/bin:$PATH"
create_annotation_files.bash  --help 2>/dev/null || echo "run with the arguments from README"
```

> The shipped `./configure` is already regenerated, so autotools are not required to build.
> They are included in the environment only if you want to re-run `autoreconf -fi`.

## Option B — Docker

```bash
cd RiboTaper_R4.5
docker build -t ribotaper:1.3.1a-mod .

# run a RiboTaper command against data in the current directory
docker run --rm -v "$PWD":/data -w /data ribotaper:1.3.1a-mod \
    Ribotaper.sh RIBO.bam RNA.bam annot_dir 26,28,29 9,12,12 4
```

## Option C — Apptainer / Singularity (HPC clusters)

```bash
cd RiboTaper_R4.5
apptainer build ribotaper.sif apptainer.def

apptainer exec --bind "$PWD":/data ribotaper.sif \
    create_annotation_files.bash /data/annotation.gtf /data/genome.fa false false /data/annot_dir
```

---

## Manual install (existing module-based cluster)

If you already have modules for the tools, just make sure the versions meet the minimums and
build directly:

| Tool | Minimum | Notes |
|------|---------|-------|
| bedtools | **2.27.0** | must expose the unified `bedtools <subcommand>` interface |
| samtools | **1.7** | any modern HTSlib-based release |
| R | **4.0** (≥ **4.5** recommended) | |
| R packages | seqinr, ade4, multitaper, doMC, foreach, iterators, **XNomial** | install XNomial via `extras/install_R_packages.R` |

```bash
./configure \
    BEDTOOLS=$(command -v bedtools) \
    SAMTOOLS=$(command -v samtools) \
    R=$(command -v R) RSCRIPT=$(command -v Rscript) \
    --prefix=/usr/local/ribotaper
make && make install
```

`./configure` will verify every tool and R package and stop with a clear message if anything is
missing or too old.

---

## Quick self-test

A tiny end-to-end check (synthetic data) confirms your install works. See
`CHANGES_MODERNIZATION.md` §9 for the exact steps that were validated; in short:

```bash
create_annotation_files.bash annotation.gtf genome.fa false false annot_dir
Ribotaper.sh RIBO.bam RNA.bam annot_dir <read_lengths> <offsets> <n_cores>
```

Reminder: if you change your genome FASTA, refresh its index (`samtools faidx genome.fa`) so
`bedtools getfasta` doesn't use a stale `.fai` (see `CHANGES_MODERNIZATION.md` §10).
