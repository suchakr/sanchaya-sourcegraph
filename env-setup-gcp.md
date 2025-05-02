# Updating Environment Files for GCP

When deploying to GCP, you'll need to update your `.env.gcp` file with the correct IP address of your VM instance before starting Sourcegraph.

## For HTTP Deployment (Initial Testing)

Update the following values in your `.env.gcp` file:

```bash
SG_PORT=7080
SG_EXTERNAL_URL=http://YOUR_VM_IP:7080
SG_SITE_ADDRESS=YOUR_VM_IP:7080
SG_HTTPS_ENABLED=false
SG_CADDY_CONFIG=./caddy/builtins/http.Caddyfile
```

Replace `YOUR_VM_IP` with your VM's external IP address, which you can get with:
```bash
curl -s ifconfig.me
```

## For HTTPS Deployment (Production)

When you're ready to switch to HTTPS, update these values in your `.env.gcp` file:

```bash
SG_PORT=443
SG_EXTERNAL_URL=https://YOUR_VM_IP
SG_SITE_ADDRESS=YOUR_VM_IP
SG_HTTPS_ENABLED=true
SG_CADDY_CONFIG=./caddy/builtins/https.lets-encrypt-prod.Caddyfile
SG_ACME_EMAIL=your-email@example.com
```

Also make sure ports 80 and 443 are open in your firewall:
```bash
gcloud compute firewall-rules create allow-https --allow tcp:443 --target-tags=sourcegraph
gcloud compute firewall-rules create allow-http --allow tcp:80 --target-tags=sourcegraph
```

After updating your `.env.gcp` file, run `docker compose down` followed by `docker compose --env-file .env.gcp up -d` to apply the changes.
