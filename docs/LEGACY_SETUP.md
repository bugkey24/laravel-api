# 📜 Legacy Manual Setup Guide (v1.0.0)

This document preserves the original manual setup steps used before the automation scripts were introduced in `v2.0.0`. Use this if you need to troubleshoot the automation or prefer manual configuration.

---

## 🏗️ Phase 1: Main Server Manual Setup

1. **Setup Environment Variables:**
   ```bash
   cp .env.example .env
   ```
   Ensure `DB_HOST=database` in your `.env`.

2. **Configure NGINX Manually:**
   Edit `infrastructure/nginx/nginx.conf` (formerly `nginx/nginx.conf`) and replace the IPs:
   ```nginx
   upstream backend_servers {
       server 192.168.1.10:8000; # Local
       server 192.168.1.11:8000; # Worker 1
   }
   ```

3. **Start:** `docker compose up -d`

## 🏗️ Phase 2: Worker Server Manual Setup

1. **Setup Environment Variables:**
   ```bash
   cp .env.example .env
   ```
   Set `DB_HOST` to the **Main Server's IP**.

2. **Start:** `docker compose -f compose.backend.yml up -d`

---

## 🧪 Historical Testing Scenarios

### 1. Concurrency test
Open 5 different browser tabs and hit `GET /api/slow/{id}` simultaneously. You will observe how multiple requests are processed concurrently by different servers without blocking.

### 2. Fault Tolerance test
Turn off one of the worker servers:
```bash
docker compose -f compose.backend.yml down
```
Hit the `/api/data` endpoint again. NGINX will automatically detect the dead node and redirect traffic to surviving nodes.
