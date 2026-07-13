# RiboTaper (modernized 2026) — reproducible container image
#
#   docker build -t ribotaper:1.3.1a-mod .
#   docker run --rm -v "$PWD":/data -w /data ribotaper:1.3.1a-mod \
#          create_annotation_files.bash annotation.gtf genome.fa false false annot_dir
#
# The image bundles bedtools, samtools and R (+ all R packages, including a
# correctly-patched XNomial) and installs RiboTaper under /usr/local/ribotaper.
# Works on both linux/amd64 and linux/arm64.

FROM condaforge/miniforge3:24.11.3-2

# System locale keeps sort/awk deterministic
ENV LC_ALL=C.UTF-8 LANG=C.UTF-8

WORKDIR /opt/ribotaper
COPY . /opt/ribotaper

# 1) Create the conda environment with the modern tool stack.
RUN mamba env create -f environment.yml && mamba clean -a -y

# 2) Everything below runs inside the `ribotaper` environment.
SHELL ["conda", "run", "--no-capture-output", "-n", "ribotaper", "/bin/bash", "-lc"]

# 3) Install XNomial (CRAN archive, R>=4.5 build fix) and any package missing a
#    conda build for this architecture (e.g. multitaper on arm64).
RUN Rscript extras/install_R_packages.R

# 4) Configure, build and install RiboTaper itself.
RUN autoreconf -fi \
 && ./configure --prefix=/usr/local/ribotaper \
 && make \
 && make install

# 5) Put the RiboTaper commands and the env binaries on PATH for `docker run`.
ENV PATH=/usr/local/ribotaper/bin:/opt/conda/envs/ribotaper/bin:$PATH
ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "ribotaper"]
CMD ["bash"]
