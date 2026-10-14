# CDE 1.26 Virtual Clusters run Python 3.11; the Spark Connect client must match
# Built for linux/amd64 and linux/arm64. Under x86 emulation on Apple Silicon, the Jupyter server deadlocks when it opens a terminal while a kernel is running
FROM python:3.11-slim-bookworm

# Full vim, not vim-tiny: vim-tiny runs vi-compatible, so arrow keys in insert mode type A/B/C/D
RUN apt-get update && apt-get install -y --no-install-recommends gcc make curl bash git vim less jq procps \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash cdeuser
WORKDIR /home/cdeuser

RUN mkdir /home/cdeuser/.cde /home/cdeuser/.cdp
# pip3 installs into the user site. Python only adds it to sys.path at startup if it exists,
# so a notebook kernel started before the Lab 2 pip installs wouldn't find pyspark
RUN mkdir -p /home/cdeuser/.local/lib/python3.11/site-packages

RUN pip3 install --no-cache-dir jupyter \
  jupyterlab
RUN pip3 install --no-cache-dir numpy \
  pandas \
  matplotlib \
  scikit-learn

# CDE 1.26 CLI (linux-amd64), downloaded by docker/build.sh. In the arm64 image it runs through Docker Desktop's x86 emulation
COPY bin/cde /usr/local/bin/cde
RUN chmod 755 /usr/local/bin/cde

# Copy files and directories with ownership set to cdeuser
COPY --chown=cdeuser:cdeuser de-pipeline-manufacturing /home/cdeuser/de-pipeline-manufacturing
COPY --chown=cdeuser:cdeuser de-pipeline-bank /home/cdeuser/de-pipeline-bank
COPY --chown=cdeuser:cdeuser setup /home/cdeuser/setup
COPY --chown=cdeuser:cdeuser img /home/cdeuser/img
COPY --chown=cdeuser:cdeuser config.yaml /home/cdeuser/.cde/config.yaml
COPY --chown=cdeuser:cdeuser credentials /home/cdeuser/.cdp/credentials
# CDE 1.26 Spark Connect tarballs (cdeconnect + pyspark), installed by participants in Lab 2
COPY --chown=cdeuser:cdeuser spark-connect/ /home/cdeuser/
COPY --chown=cdeuser:cdeuser observability /home/cdeuser/observability
COPY --chown=cdeuser:cdeuser Iceberg_TimeTravel_PySpark_banking.ipynb /home/cdeuser/Iceberg_TimeTravel_PySpark_banking.ipynb
COPY --chown=cdeuser:cdeuser Iceberg_TimeTravel_PySpark_manufacturing.ipynb /home/cdeuser/Iceberg_TimeTravel_PySpark_manufacturing.ipynb
COPY --chown=cdeuser:cdeuser pyspark-app.py /home/cdeuser/pyspark-app.py

USER root
RUN chown -R cdeuser:cdeuser /home/cdeuser &&\
    chmod -R u+rw /home/cdeuser &&\
    chmod 600 /home/cdeuser/.cde/config.yaml /home/cdeuser/.cdp/credentials
USER cdeuser

ENV PATH="/home/cdeuser/.local/bin:${PATH}"
# JupyterLab terminals start $SHELL, falling back to sh
ENV SHELL=/bin/bash

EXPOSE 8888

CMD ["bash", "-c", "jupyter-lab --ip='0.0.0.0' --port=8888 --no-browser"]
