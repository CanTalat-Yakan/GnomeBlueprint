# ZeroTier One

Self-hosted ZeroTier network node running in Docker.

## Address

ZeroTier runs in **host network mode** - once joined to a network, this machine is accessible via its ZeroTier IP.

Manage your networks at: **https://my.zerotier.com**

## Quick Commands

```bash
cd ~/zerotierone

# Start (detached)
docker compose up -d

# Stop
docker compose down

# Update to latest version
docker compose pull
docker compose up -d

# Join a ZeroTier network
docker exec zerotier-one zerotier-cli join <NETWORK_ID>

# Check status
docker exec zerotier-one zerotier-cli status

# List joined networks
docker exec zerotier-one zerotier-cli listnetworks
```

## Data

Network identity and configuration are persisted in `./data/`.

