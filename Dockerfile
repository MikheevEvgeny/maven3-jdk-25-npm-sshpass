FROM bellsoft/liberica-openjdk-debian:25
LABEL maintainer="mikheevevgeny@gmail.com" version="1.0" description="Docker image based on bellsoft/liberica-openjdk-debian:25 with Maven, npm, nodejs and sshpass"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -eux \
  && curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
  && apt-get update \
  && apt-get install -y --no-install-recommends sshpass nodejs build-essential \
  && rm -rf /var/lib/apt/lists/*

ARG MAVEN_VERSION=3.9.16
ARG USER_HOME_DIR="/root"
ARG SHA=831a8591fe20c8243b1dbe7d71e3244f31d1665b0804b2e825e38cbbe5ce0cafb8338851f90780735568773e0a6cd07bbec107cda0b896b008b861075358b6f6
ARG BASE_URL=https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries

RUN mkdir -p /usr/share/maven /usr/share/maven/ref \
  && curl -fsSL -o /tmp/apache-maven.tar.gz ${BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
  && echo "${SHA}  /tmp/apache-maven.tar.gz" | sha512sum -c - \
  && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
  && rm -f /tmp/apache-maven.tar.gz \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

ENV MAVEN_HOME=/usr/share/maven
ENV MAVEN_CONFIG="$USER_HOME_DIR/.m2"

COPY mvn-entrypoint.sh /usr/local/bin/mvn-entrypoint.sh
RUN chmod +x /usr/local/bin/mvn-entrypoint.sh
COPY settings-docker.xml /usr/share/maven/ref/

ENTRYPOINT ["/usr/local/bin/mvn-entrypoint.sh"]
CMD ["mvn"]
