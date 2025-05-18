# Sanchaya Sourcegraph 

This Sanchaya Sourcegraph deployment is specifically configured to enable efficient searching and browsing of the Sanchaya repository, which contains a vast collection of Unicode text files with Indic content. Key features include:

- Full-text search capabilities for Unicode Indic scripts
- Fast indexing and searching of text content
- Easy navigation through Indic language content
- Support for multiple Indic scripts and encodings
- Advanced search features like regular expressions and filters

This setup allows researchers, scholars, and enthusiasts to quickly search and access the rich collection of Indic texts maintained in the Sanchaya repository.

## System Requirements

- Docker Engine
- Docker Compose v2.4+
- Minimum 16GB RAM
- Minimum 100GB disk space

## Getting Started

### Local Mac Development

Ensure you have Docker Desktop installed on your macOS machine. 

1. Clone this repository https://github.com/suchakr/sanchaya-sourcegraph.git
2. Use the Mac-specific script which creates required directories and starts containers:

```sh
# Make the script executable
chmod +x mac_up.sh

# Start Sourcegraph
./mac_up.sh
```

3. Access Sourcegraph at http://localhost:7080

### GCP Deployment Manually

Ensure you have Docker Engine and Docker Compose installed on your GCP VM instance. This deployment is optimized for production use on Google Cloud Platform. 

1. Clone this repository
2. Make sure `/mnt/docker-data` exists (created by `03_sourcegraph_prep.sh`)
3. Run the script to start Sourcegraph:

```sh
./04_sourcegraph_start.sh
```

4. Access Sourcegraph at:
   - Internal HTTP: http://YOUR_VM_INTERNAL_IP:7080
   - External HTTPS: https://sanchaya.mooo.com (via external reverse proxy)

5. To stop the deployment, run:

```sh
# Stop while preserving data volumes
./05_sourcegraph_stop.sh

# Stop and remove all data volumes
./05_sourcegraph_stop.sh -v
```

or to remove volumes:

```sh
docker compose down -v # to remove volumes
```

### GCP Deployment using Scripts

> **Note**: Before running these scripts, ensure you have the Google Cloud SDK installed and configured with appropriate permissions.

These scripts are designed to be run in order to set up a Sourcegraph instance on GCP. These scripts are invoked from your development machine and will create a GCP VM instance, install Docker, set up persistent storage, and start Sourcegraph services.

1. **`00_allocate_gcp.sh`**  
   Creates a new GCP VM instance with the necessary specifications (CPU, memory, disk).

2. **`01_docker_install.sh`**  
   Installs Docker and Docker Compose on the GCP VM instance.

3. **`02_disk_setup.sh`**  
   Formats and mounts additional persistent disk storage for Docker volumes.

4. **`03_sourcegraph_prep.sh`**  
   Prepares the directory structure for Sourcegraph data, setting up `/mnt/docker-data` paths.

5. **`04_sourcegraph_start.sh`**  
   Starts the Sourcegraph services using Docker Compose with GCP-specific settings.


#### Cleanup

When you need to decommission your deployment:

- **`cleanup_gcp.sh`**  
   Removes all GCP resources created for the Sourcegraph deployment.

#### Usage Sequence

```sh
# Step-by-step deployment
./00_allocate_gcp.sh
./01_docker_install.sh
./02_disk_setup.sh
./03_sourcegraph_prep.sh
./04_sourcegraph_start.sh
```

### Environment Files

This deployment uses a simplified environment configuration:

| File | Purpose | Key Settings | Use Case |
|------|---------|--------------|----------|
| `.env` | Default configuration | HTTP on port 7080 | Default for `docker compose up` |
| `.env.mac` | Alternative for Mac with explicit volume paths | Same as default | Used by `mac_up.sh` script |

#### Environment Configuration Details

The deployment uses the default `.env` file:
- HTTP is configured on port 7080
- No SSL certificate is used (plain HTTP)
- Internally accessible via `http://<ip-address>:7080`
- External HTTPS access is provided by a separate reverse proxy

This simplified approach separates concerns:
- Sourcegraph runs with HTTP internally
- External HTTPS is handled by another service's Caddy instance
- This makes the configuration easier to reason about and maintain

## Architecture Components

```mermaid
graph TD
    SR[("Sanchaya\nGitHub Repo")] --> |"Clone/Sync"| G
    
    subgraph Docker ["Docker Environment"]
        subgraph "User Interface"
            F[Frontend]
            F --> ZW[Zoekt WebServer]
        end

        subgraph "Search Services"
            F --> S[Searcher]
            F --> ZW
            ZI[Zoekt Indexer] --> ZW
        end

        subgraph "Repository Management"
            F --> G[Git Server]
            ZI --> G
            S --> G
        end

        subgraph "Databases"
            F --> P[(PostgreSQL)]
            F --> RC[(Redis Cache)]
            F --> RS[(Redis Store)]
        end

        subgraph "Monitoring"
            PR[Prometheus] --> C[cAdvisor]
            PR --> NE[Node Exporter]
            PR --> F
            GF[Grafana] --> PR
        end
    end
    
    U[User Browser] --> F
    SR --> |"Clone/Sync"| G

    style Docker fill:#e5f5f9,stroke:#333,stroke-width:2px
    style U fill:#f9f,stroke:#333,stroke-width:2px
    style F fill:#bbf,stroke:#333,stroke-width:2px
    style ZW fill:#dff,stroke:#333,stroke-width:2px
    style S fill:#dff,stroke:#333,stroke-width:2px
    style ZI fill:#dff,stroke:#333,stroke-width:2px
    style G fill:#bfb,stroke:#333,stroke-width:2px
    style P fill:#fbb,stroke:#333,stroke-width:2px
    style RC fill:#fbb,stroke:#333,stroke-width:2px
    style RS fill:#fbb,stroke:#333,stroke-width:2px
    style PR fill:#ffb,stroke:#333,stroke-width:2px
    style GF fill:#ffb,stroke:#333,stroke-width:2px
    style C fill:#ffb,stroke:#333,stroke-width:2px
    style NE fill:#ffb,stroke:#333,stroke-width:2px
    style SR fill:#d4edda,stroke:#333,stroke-width:2px
```

### Workflow Diagrams

```mermaid
sequenceDiagram
    participant SR as Sanchaya Repo
    participant G as Git Server
    participant ZI as Zoekt Indexer
    participant ZW as Zoekt WebServer
    participant F as Frontend
    participant U as User

    %% Indexing Workflow
    rect rgb(200, 255, 200)
        Note over SR,ZW: Indexing Workflow
        G->>SR: Clone/Sync repository
        G->>ZI: Notify new/updated content
        ZI->>G: Fetch content
        ZI->>ZI: Build search index
        ZI->>ZW: Upload search index
    end

    %% Search Workflow
    rect rgb(200, 200, 255)
        Note over U,ZW: Search Workflow
        U->>F: Search query
        F->>ZW: Search request
        ZW->>ZW: Search indexed content
        ZW->>F: Search results
        F->>U: Display results
    end
```

## Configuration

### External Access

By default, the following ports are exposed:

- Port 7080: HTTP access 
- Port 443: HTTPS access (disabled by default)
- Port 3370: Grafana dashboard
- Port 9090: Prometheus metrics

### External HTTPS Access

This deployment is designed to be accessed securely via HTTPS through an external reverse proxy. The configuration for the external Caddy instance should include:

```
sanchaya.mooo.com {
    # Enable automatic HTTPS with Let's Encrypt
    tls {
        protocols tls1.2 tls1.3
    }
    
    # Enable compression
    encode zstd gzip
    
    # Reverse proxy to the Sourcegraph frontend
    # 172.17.0.1 is the Docker host IP
    reverse_proxy 172.17.0.1:7080 {
        header_up Host {http.request.host}
        header_up X-Real-IP {http.request.remote}
        header_up X-Forwarded-For {http.request.remote}
        header_up X-Forwarded-Proto {http.request.scheme}
    }
}
```

## Storage

Persistent volumes are configured for:

- Git repositories
- Search indexes
- Databases
- Cache data
- Monitoring data

## Monitoring 

Access monitoring dashboards at:

- Grafana: http://localhost:3370
- Prometheus: http://localhost:9090

## Directory Structure and Files

This repository is organized as follows:

### Root Directory

- `docker-compose.yml`: Main Docker Compose configuration file that defines all services
- `docker-compose.override.yml`: Contains customizations for GCP deployment (expects `/mnt/docker-data`)
- `docker-compose.mac.yml`: Mac-specific volume mappings (uses `./sourcegraph-data`)
- `docker-compose.resource.yml`: Resource allocation and constraints for Docker services
- `.env`: Default environment variables (HTTP configuration)
- `.env.mac`: Mac-specific environment variables (same as default)
- `mac_up.sh`: Script to create directories and start containers on macOS
- `mac_down.sh`: Script to stop containers on macOS
- `00_allocate_gcp.sh`: Creates GCP VM instance
- `01_docker_install.sh`: Installs Docker on the VM
- `02_disk_setup.sh`: Formats and mounts persistent disk storage
- `03_sourcegraph_prep.sh`: Sets up directory structure for Sourcegraph data
- `04_sourcegraph_start.sh`: Starts Sourcegraph services
- `05_sourcegraph_stop.sh`: Stops Sourcegraph services
- `cleanup_gcp.sh`: Removes GCP resources

### Caddy Directory (`caddy/`)

Contains configurations for the Caddy web server that handles HTTP traffic:
- `builtins/http.Caddyfile`: HTTP configuration for Caddy web server (internal access)

### Configuration Directory (`config/`)

Contains application-specific configurations:
- `site-config.json`: Core configuration for the Sourcegraph instance

### Data Directory (`sourcegraph-data/`)

Contains persistent data for all services:

- `blobstore/`: Blob storage for uploaded files
- `caddy/`: Caddy web server data
- `codeinsights-db/`: Code Insights PostgreSQL database
- `codeintel-db/`: Code Intelligence PostgreSQL database
- `gitserver-0/`: Git repository data
- `pgsql/`: Primary PostgreSQL database
- `prometheus/`: Prometheus metrics data
- `redis-cache/`: Redis cache data
- `redis-store/`: Redis store data
- `repo-updater/`: Repository updater cache
- `searcher-0/`: Search service cache
- `sourcegraph-frontend-0/`: Frontend service cache
- `sourcegraph-frontend-internal/`: Internal frontend service cache
- `symbols-0/`: Symbols service cache
- `worker/`: Worker service cache
- `zoekt/`: Code search index data

### Purpose of Key Files

- **Docker Compose Files**: Define the multi-container application setup
  - `docker-compose.yaml`: Primary configuration
  - `docker-compose.override.yml`: Custom settings that override defaults
  - `docker-compose.resource.yml`: Resource allocation settings
  
- **Environment Files**:
  - `.env`: Default environment variables
  
- **Configuration Files**:
  - `caddy/builtins/http.Caddyfile`: Controls how HTTP traffic is handled
  - `config/site-config.json`: Configures Sourcegraph application behavior

## Additional Documentation

For more detailed configuration and operation instructions, see:

- [Sourcegraph Docs](https://docs.sourcegraph.com)
- [Docker Compose Deployment Docs](https://docs.sourcegraph.com/admin/install/docker-compose)

