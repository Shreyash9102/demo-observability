FROM alpine:latest

# Install bash, curl and netcat for the script to run
RUN apk add --no-cache bash curl netcat-openbsd

# Copy the update script (when built from project root, use relative path)
COPY sidecar/config-updater/update-prometheus-config.sh /usr/local/bin/update-prometheus-config.sh
RUN chmod +x /usr/local/bin/update-prometheus-config.sh

# Mount docker socket and prometheus config at runtime
CMD ["/usr/local/bin/update-prometheus-config.sh"]
