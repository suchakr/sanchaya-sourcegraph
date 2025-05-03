# Updating Environment Files for GCP

When deploying to GCP, the `04_sourcegraph_start.sh` script will automatically set up the environment based on whether you choose HTTP or HTTPS mode.

## For HTTP Deployment (Initial Testing)

When running `./04_sourcegraph_start.sh` (without parameters), the script will automatically configure these values:

```bash
SG_PORT=7080
SG_EXTERNAL_URL=http://YOUR_VM_IP:7080
SG_SITE_ADDRESS=YOUR_VM_IP
SG_HTTPS_ENABLED=false
SG_CADDY_CONFIG=./caddy/builtins/http.Caddyfile
```

The script will automatically detect your VM's external IP address and replace `YOUR_VM_IP` accordingly.

## For HTTPS Deployment (Production)

When running `./04_sourcegraph_start.sh https`, the script will automatically configure these values:

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

## Manually Modifying the Environment

If you need to manually modify these settings, you can edit the `.env` file that is created by the script. After making changes, restart Sourcegraph with:

```bash
./05_sourcegraph_stop.sh
./04_sourcegraph_start.sh  # or ./04_sourcegraph_start.sh https
```
