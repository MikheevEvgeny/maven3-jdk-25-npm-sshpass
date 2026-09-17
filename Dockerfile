FROM bellsoft/liberica-openjdk-debian:25

LABEL maintainer="mikheevevgeny@gmail.com" \
      version="1.0" \
      description="Docker image based on bellsoft/liberica-openjdk-debian:25 with Maven, Node.js, Chrome, Firefox, Trivy and sshpass"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG MAVEN_VERSION=3.9.16
ARG GECKODRIVER_VERSION=0.37.1
ARG USER_HOME_DIR="/root"

ARG MAVEN_SHA512=831a8591fe20c8243b1dbe7d71e3244f31d1665b0804b2e825e38cbbe5ce0cafb8338851f90780735568773e0a6cd07bbec107cda0b896b008b861075358b6f6

ARG MAVEN_BASE_URL=https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries


# ------------------------------------------------------------
# Системные пакеты и подключение репозиториев
# ------------------------------------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg; \
    \
    install -d -m 0755 /etc/apt/keyrings; \
    \
    # Node.js 24
    curl -fsSL https://deb.nodesource.com/setup_24.x \
        -o /tmp/nodesource_setup.sh; \
    bash /tmp/nodesource_setup.sh; \
    rm -f /tmp/nodesource_setup.sh; \
    \
    # Google Chrome
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor --yes -o /etc/apt/keyrings/google-chrome.gpg; \
    \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list; \
    \
    # Trivy
    curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor --yes -o /etc/apt/keyrings/trivy.gpg; \
    echo "deb [signed-by=/etc/apt/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" > /etc/apt/sources.list.d/trivy.list; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        git \
        nodejs \
        google-chrome-stable \
        firefox-esr \
        sshpass \
        openssh-client \
        build-essential \
        python3 \
        python3-setuptools \
        xvfb \
        unzip \
        trivy; \
    \
    rm -rf /var/lib/apt/lists/* /tmp/*

# ------------------------------------------------------------
# ChromeDriver
#
# Определяем установленную версию Google Chrome и ставим
# соответствующий ChromeDriver.
# ------------------------------------------------------------
RUN set -eux; \
    \
    CHROME_VERSION="$(google-chrome --product-version)"; \
    CHROME_BUILD="$(echo "${CHROME_VERSION}" | cut -d. -f1-3)"; \
    \
    echo "Installed Google Chrome: ${CHROME_VERSION}"; \
    echo "Chrome build: ${CHROME_BUILD}"; \
    \
    CHROMEDRIVER_VERSION="${CHROME_VERSION}"; \
    CHROMEDRIVER_URL="https://storage.googleapis.com/chrome-for-testing-public/${CHROMEDRIVER_VERSION}/linux64/chromedriver-linux64.zip"; \
    \
    echo "Trying ChromeDriver ${CHROMEDRIVER_VERSION}"; \
    \
    if ! curl -fsSL \
        "${CHROMEDRIVER_URL}" \
        -o /tmp/chromedriver.zip; \
    then \
        echo "Exact ChromeDriver ${CHROME_VERSION} is not available."; \
        echo "Searching latest compatible driver for build ${CHROME_BUILD}..."; \
        \
        CHROMEDRIVER_VERSION="$( \
            curl -fsSL \
                "https://googlechromelabs.github.io/chrome-for-testing/LATEST_RELEASE_${CHROME_BUILD}" \
        )"; \
        \
        CHROMEDRIVER_URL="https://storage.googleapis.com/chrome-for-testing-public/${CHROMEDRIVER_VERSION}/linux64/chromedriver-linux64.zip"; \
        \
        echo "Compatible ChromeDriver: ${CHROMEDRIVER_VERSION}"; \
        \
        curl -fsSL "${CHROMEDRIVER_URL}" -o /tmp/chromedriver.zip; \
    fi; \
    \
    unzip -q /tmp/chromedriver.zip -d /tmp/chromedriver; \
    \
    install -m 0755 /tmp/chromedriver/chromedriver-linux64/chromedriver /usr/local/bin/chromedriver; \
    \
    rm -rf /tmp/chromedriver /tmp/chromedriver.zip; \
    \
    # Проверяем версии
    google-chrome --version; \
    chromedriver --version; \
    \
    CHROMEDRIVER_INSTALLED_VERSION="$(chromedriver --version | awk '{print $2}')"; \
    CHROMEDRIVER_BUILD="$(echo "${CHROMEDRIVER_INSTALLED_VERSION}" | cut -d. -f1-3)"; \
    \
    test "${CHROME_BUILD}" = "${CHROMEDRIVER_BUILD}"


# ------------------------------------------------------------
# Maven
# ------------------------------------------------------------
RUN set -eux; \
    mkdir -p /usr/share/maven /usr/share/maven/ref; \
    \
    curl -fsSL "${MAVEN_BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz" -o /tmp/apache-maven.tar.gz; \
    \
    echo "${MAVEN_SHA512}  /tmp/apache-maven.tar.gz" | sha512sum -c -; \
    \
    tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1; \
    \
    rm -f /tmp/apache-maven.tar.gz; \
    ln -sf /usr/share/maven/bin/mvn /usr/bin/mvn


# ------------------------------------------------------------
# GeckoDriver
# ------------------------------------------------------------
RUN set -eux; \
    curl -fsSL \
        "https://github.com/mozilla/geckodriver/releases/download/v${GECKODRIVER_VERSION}/geckodriver-v${GECKODRIVER_VERSION}-linux64.tar.gz" \
        -o /tmp/geckodriver.tar.gz; \
    \
    tar -xzf /tmp/geckodriver.tar.gz -C /usr/local/bin; \
    \
    chmod +x /usr/local/bin/geckodriver; \
    rm -f /tmp/geckodriver.tar.gz; \
    \
    geckodriver --version


# ------------------------------------------------------------
# Environment
# ------------------------------------------------------------
ENV MAVEN_HOME=/usr/share/maven \
    MAVEN_CONFIG="${USER_HOME_DIR}/.m2" \
    DISPLAY=:99

ENV PATH="${MAVEN_HOME}/bin:${PATH}"


# ------------------------------------------------------------
# Maven configuration
# ------------------------------------------------------------
COPY --chmod=755 mvn-entrypoint.sh /usr/local/bin/mvn-entrypoint.sh
COPY settings-docker.xml /usr/share/maven/ref/


ENTRYPOINT ["/usr/local/bin/mvn-entrypoint.sh"]
CMD ["mvn"]