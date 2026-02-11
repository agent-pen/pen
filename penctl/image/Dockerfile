FROM docker/sandbox-templates:claude-code

# Base image has non-root user
USER root

# Install generic development tooling
RUN apt update && apt install -y vim clang build-essential llvm openssh-client netcat-openbsd docker-ce supervisor
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

COPY supervisord-dockerd.conf /etc/supervisor/conf.d/dockerd.conf

USER agent
CMD ["sudo", "-E", "supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
