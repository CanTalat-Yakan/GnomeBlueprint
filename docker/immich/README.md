# Immich

Self-hosted photo and video management solution.

## Address

| Service | URL |
|---|---|
| **Immich Web** | http://localhost:2283 |

On first launch, Immich will ask you to create an admin account.

## Quick Commands

```bash
cd ~/immich

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

- `UPLOAD_LOCATION` — where uploaded photos/videos are stored (default: `./library`)
- `DB_DATA_LOCATION` — where the PostgreSQL database is stored (default: `./postgres`)
- `DB_PASSWORD` — **change this** before first launch
- `IMMICH_VERSION` — pin to a specific version or use `release` for latest

## Data

- Uploaded media is stored in `./library/`
- Database is stored in `./postgres/`

## Documentation

Full docs: https://docs.immich.app
