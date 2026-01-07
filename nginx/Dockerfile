FROM nginx:stable
COPY default.conf /etc/nginx/conf.d/default.conf
COPY ssl_password.txt /etc/nginx/ssl_password.txt
RUN mkdir -p /etc/ssl/certs /etc/ssl/private && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/key.pem -out /etc/ssl/certs/cert.pem \
    -subj "/C=US/ST=State/L=City/O=Demo/CN=localhost" 2>/dev/null || true
CMD ["nginx", "-g", "daemon off;"]
