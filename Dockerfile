FROM bellsoft/liberica-openjdk-debian:25
LABEL maintainer="mikheevevgeny@gmail.com" version="1.0" description="Docker image based on bellsoft/liberica-openjdk-debian:25 with Maven, npm, nodejs and sshpass"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Сначала устанавливаем инструменты, необходимые для подключения репозиториев.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        gnupg; \
    rm -rf /var/lib/apt/lists/*

# Подключаем NodeSource и репозиторий Google Chrome.
RUN set -eux; \
    curl -fsSL "https://deb.nodesource.com/setup_24.x" \
        -o /tmp/nodesource_setup.sh; \
    bash /tmp/nodesource_setup.sh; \
    rm -f /tmp/nodesource_setup.sh; \
    \
    install -d -m 0755 /etc/apt/keyrings; \
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
        | gpg --dearmor --yes \
            -o /etc/apt/keyrings/google-chrome.gpg; \
    \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
        > /etc/apt/sources.list.d/google-chrome.list

# Устанавливаем основные пакеты.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        git \
        nodejs \
        google-chrome-stable \
        chromium \
        chromium-driver \
        sshpass \
        openssh-client \
        bash \
        build-essential \
        firefox-esr \
        python3 \
        python3-setuptools \
        xvfb; \
    rm -rf /var/lib/apt/lists/* /tmp/*

ARG MAVEN_VERSION=3.9.16
ARG GECKODRIVER_VERSION=0.37.1
ARG USER_HOME_DIR="/root"
ARG SHA=831a8591fe20c8243b1dbe7d71e3244f31d1665b0804b2e825e38cbbe5ce0cafb8338851f90780735568773e0a6cd07bbec107cda0b896b008b861075358b6f6
ARG BASE_URL=https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries

RUN mkdir -p /usr/share/maven /usr/share/maven/ref \
  && curl -fsSL -o /tmp/apache-maven.tar.gz ${BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
  && echo "${SHA}  /tmp/apache-maven.tar.gz" | sha512sum -c - \
  && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
  && rm -f /tmp/apache-maven.tar.gz \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

RUN set -eux; \
    wget -q "https://github.com/mozilla/geckodriver/releases/download/v${GECKODRIVER_VERSION}/geckodriver-v${GECKODRIVER_VERSION}-linux64.tar.gz" \
        -O /tmp/geckodriver.tar.gz; \
    tar -xzf /tmp/geckodriver.tar.gz -C /usr/local/bin; \
    chmod +x /usr/local/bin/geckodriver; \
    rm -f /tmp/geckodriver.tar.gz

ENV MAVEN_HOME=/usr/share/maven
ENV MAVEN_CONFIG="${USER_HOME_DIR}/.m2"
ENV PATH="${MAVEN_HOME}/bin:${PATH}"
ENV DISPLAY=:99

COPY mvn-entrypoint.sh /usr/local/bin/mvn-entrypoint.sh
RUN chmod +x /usr/local/bin/mvn-entrypoint.sh
COPY settings-docker.xml /usr/share/maven/ref/

ENTRYPOINT ["/usr/local/bin/mvn-entrypoint.sh"]
CMD ["mvn"]
