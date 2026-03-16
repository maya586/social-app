# Social App Deployment

## Prerequisites

- Docker and Docker Compose installed
- SSL certificates (for production)

## Quick Start

1. Generate self-signed certificates for development:
```bash
cd deploy/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout key.pem -out cert.pem \
  -subj "/CN=localhost"
```

2. Start all services:
```bash
cd deploy
docker-compose up -d
```

3. Check service health:
```bash
docker-compose ps
curl http://localhost:8080/health
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| Nginx | 80, 443 | Reverse proxy, SSL termination |
| API Server | 8080 | Go backend service |
| PostgreSQL | 5432 | Database |
| Redis | 6379 | Cache and session store |
| MinIO | 9000, 9001 | Object storage |

## API Endpoints

- Auth: `/api/v1/auth/*`
- Contacts: `/api/v1/contacts/*`
- Messages: `/api/v1/messages/*`
- Files: `/api/v1/files/*`
- Calls: `/api/v1/calls/*`
- WebSocket: `/ws`
- Health: `/health`

## Production Configuration

1. Update environment variables in `docker-compose.yml`:
   - `JWT_SECRET`: Use a strong random key
   - Database passwords
   - MinIO credentials

2. Replace SSL certificates in `deploy/ssl/`:
   - `cert.pem`: SSL certificate
   - `key.pem`: SSL private key

3. Update `nginx.conf`:
   - Change `server_name` to your domain
   - Configure SSL settings as needed

## Rate Limits

| Endpoint Type | Limit |
|---------------|-------|
| Auth | 10 requests/minute/IP |
| Messages | 100 requests/minute/user |
| Files | 20 uploads/hour/user |
| Other APIs | 300 requests/minute/user |

## Monitoring

View logs:
```bash
docker-compose logs -f server
docker-compose logs -f nginx
```

## Scaling

For horizontal scaling, consider:
- Using external PostgreSQL/Redis/MinIO
- Load balancing multiple server instances
- Container orchestration (Kubernetes)