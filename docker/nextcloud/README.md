# Nextcloud

Self-hosted file sync and collaboration platform.

## Address

| Service | URL |
|---|---|
| **Nextcloud Web** | http://localhost:8080 |

On first launch, Nextcloud will ask you to create an admin account.

## Quick Commands

```bash
cd ~/nextcloud

# Start (detached)
docker compose up -d

# Stop
docker compose down

# Update to latest version
docker compose pull
docker compose up -d

# View logs
docker compose logs -f
```

## Configuration

Edit the `.env` file to configure:

- `NC_PORT` - the port Nextcloud is accessible on (default: `8080`)
- `DB_PASSWORD` - auto-generated during install; change manually if deploying without the installer (`openssl rand -base64 42`)

## Data

- Nextcloud files are stored in `./html/` and `./data/`
- Database is stored in `./postgres/`
- Redis cache is stored in `./redis/`

## Documentation

Full docs: https://docs.nextcloud.com
