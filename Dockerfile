FROM python:3.7-slim-buster as base
FROM base as builder

RUN apt-get update && apt-get install -y \
    g++ \
    unixodbc-dev \
    build-essential \
    cmake \
    git \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /app/python/requirements.txt
COPY install-pyrequirements.sh .
RUN /install-pyrequirements.sh

RUN git clone git://git.samba.org/nss_wrapper.git /tmp/nss_wrapper && \
    mkdir /tmp/nss_wrapper/build && \
    cd /tmp/nss_wrapper/build && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local/lib64 .. && \
    make && \
    make install && \
    rm -rf /tmp/nss_wrapper


FROM base
COPY --from=builder /usr/local/lib64/lib /usr/local/lib
COPY --from=builder /usr/local/lib/python3.7/site-packages /usr/local/lib/python3.7/site-packages

COPY install-packages.sh .
RUN /install-packages.sh

ADD spark-defaults.conf /root/.local/lib/python3.7/site-packages/pyspark/conf/spark-defaults.conf
  
ENV USER_NAME=root \
    NSS_WRAPPER_PASSWD=/tmp/passwd \
    NSS_WRAPPER_GROUP=/tmp/group \
    PATH=/usr/lib/jvm/java-8-openjdk-amd64/bin:${PATH} \
    HOME=/tmp \
    SPARK_HOME=/usr/local/lib/python3.7/site-packages/pyspark \
    PYTHONPATH=/usr/local/lib/python3.7/site-packages

RUN chgrp -R 0 /usr/local/lib/python3.7/ && \
    chmod -R g=u /usr/local/lib/python3.7/ && \
    chgrp -R 0 /root/ && \
    chmod -R g=u /root/ && \
    chgrp -R 0 /tmp/ && \
    chmod -R g=u /tmp/  && \
    chgrp -R 0  /usr/local/ && \
    chmod -R g=u  /usr/local/


RUN for path in "$NSS_WRAPPER_PASSWD" "$NSS_WRAPPER_GROUP"; do \
  touch $path && chmod 666 $path ; done

COPY nss-wrap.sh /nss-wrap.sh

ENTRYPOINT ["/nss-wrap.sh"]
