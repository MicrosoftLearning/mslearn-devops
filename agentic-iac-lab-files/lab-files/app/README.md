# iaclab-api

Sample Node.js Express API used in **Module 6: Infrastructure as Code with GitHub Copilot** (Agentic DevOps Learning Path).

## Endpoints

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/` | App info and environment |
| GET | `/health` | Liveness probe (Kubernetes) |
| GET | `/ready` | Readiness probe (Kubernetes) |
| GET | `/api/resources` | List all resources (supports `?type=` and `?region=` filters) |
| GET | `/api/resources/:id` | Get a single resource by ID |
| GET | `/api/resources/summary/types` | Count resources grouped by type |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `3000` | Port the server listens on |
| `APP_ENV` | `development` | Populated from Kubernetes ConfigMap in the lab |

## Run Locally

```bash
npm install
APP_ENV=development node server.js
```

Test:
```bash
curl http://localhost:3000/health
curl http://localhost:3000/api/resources
curl "http://localhost:3000/api/resources?type=Network"
```
