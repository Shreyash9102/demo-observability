Generate TLS certs for the demo nginx sidecar

The Dockerfile expects a `certs` directory at `demo-local-observability/nginx/certs` containing:
- `elimu-rsa-cert.pem` (certificate)
- `elimu-rsa-key.pem` (private key)

Two options:

1) Quick: create an unencrypted self-signed cert (no password)

```bash
cd demo-local-observability/nginx
mkdir -p certs
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout certs/elimu-rsa-key.pem \
  -out certs/elimu-rsa-cert.pem \
  -subj "/CN=localhost"
```

- We included `ssl_password.txt` in the image but using `-nodes` (no password) is simplest for local development.

2) Encrypted key (if you want a password-protected key)

```bash
cd demo-local-observability/nginx
mkdir -p certs
openssl genrsa -aes256 -passout pass:changeit -out certs/elimu-rsa-key.pem 2048
openssl req -new -key certs/elimu-rsa-key.pem -passin pass:changeit -out certs/elimu-rsa.csr -subj "/CN=localhost"
openssl x509 -req -in certs/elimu-rsa.csr -signkey certs/elimu-rsa-key.pem -passin pass:changeit -days 365 -out certs/elimu-rsa-cert.pem
# set the same password into ssl_password.txt (we ship one with `changeit` already)
```

After creating the files, rebuild and start the demo stack:

```bash
cd demo-local-observability
docker compose up -d --build
```

If you still see errors, run these to inspect build/logs:

```bash
docker compose build nginx
docker compose up nginx
docker compose logs nginx --follow
```

