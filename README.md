<h3 align="center">
  <a name="readme-top"></a>
  <img
    src="https://raw.githubusercontent.com/firecrawl/firecrawl/main/img/firecrawl_logo.png"
    height="200"
  >
</h3>

<div align="center">
  <h2>Firecrawl - Free Local Edition</h2>
  <p><strong>Run Firecrawl 100% locally. No API keys. No Docker. No limits. No billing.</strong></p>
</div>

---

> **This is a fork of [firecrawl/firecrawl](https://github.com/firecrawl/firecrawl)** modified for unlimited free local use.
> The official Firecrawl requires an API key and a paid plan. This fork removes all authentication,
> billing, credit limits, and rate limits so you can self-host and use every feature without restrictions.

---

## What Changed From the Original

| | Official Firecrawl | This Fork |
|---|---|---|
| **API Key** | Required (sign up at firecrawl.dev) | Not needed |
| **Credits** | Limited by paid plan | Unlimited |
| **Rate Limits** | Enforced per plan tier | None |
| **Billing** | Credit-based, auto-recharge | Completely disabled |
| **Docker** | Required for self-hosting | Not required |
| **Setup** | Sign up, get API key, configure Docker | Run one script |

### Technical changes made:
- **`.env.local`**: Pre-configured with `USE_DB_AUTHENTICATION=false` and local service URLs
- **`start-local.sh`**: One-command setup that installs Redis, PostgreSQL, RabbitMQ as system services and launches Firecrawl
- **`apps/api/src/harness.ts`**: Detects system-installed PostgreSQL/RabbitMQ before falling back to Docker containers
- **`apps/api/src/lib/withAuth.ts`**: Cleaner bypass message for local mode
- **`apps/nuq-postgres/nuq-local.sql`**: Database schema that works without Docker-only `pg_cron` extension

---

## Quick Start

```bash
git clone https://github.com/AI-ANK/firecrawlfork.git
cd firecrawlfork
./start-local.sh
```

The script handles everything:
1. Installs Redis, PostgreSQL, RabbitMQ (if not already installed)
2. Creates the database and applies schema
3. Installs Node.js dependencies
4. Starts the Firecrawl API on `http://localhost:3002`

### Prerequisites
- **Node.js** >= 18
- **Go** >= 1.21 (for html-to-markdown, optional but recommended)
- Linux (Ubuntu/Debian) or macOS. The script auto-installs Redis, PostgreSQL, and RabbitMQ via your package manager.

---

## Usage

### No API key needed

Every request works without any `Authorization` header:

```bash
curl -X POST http://localhost:3002/v1/scrape \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://example.com"}'
```

If you're using an SDK that requires an API key parameter, pass any string:

```bash
curl -X POST http://localhost:3002/v1/scrape \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer fc-local' \
  -d '{"url": "https://example.com"}'
```

---

## API Endpoints

All endpoints from the original Firecrawl work locally with no restrictions.

### Scrape - Convert any URL to markdown

```bash
curl -X POST http://localhost:3002/v1/scrape \
  -H 'Content-Type: application/json' \
  -d '{
    "url": "https://docs.firecrawl.dev",
    "formats": ["markdown", "html"]
  }'
```

Response:
```json
{
  "success": true,
  "data": {
    "markdown": "# Firecrawl Docs\n\nTurn websites into LLM-ready data...",
    "html": "<!DOCTYPE html><html>...",
    "metadata": {
      "title": "Quickstart | Firecrawl",
      "sourceURL": "https://docs.firecrawl.dev",
      "statusCode": 200
    }
  }
}
```

### Crawl - Scrape an entire website

```bash
curl -X POST http://localhost:3002/v1/crawl \
  -H 'Content-Type: application/json' \
  -d '{
    "url": "https://docs.firecrawl.dev",
    "limit": 50,
    "scrapeOptions": {
      "formats": ["markdown"]
    }
  }'
```

### Map - Discover all URLs on a site

```bash
curl -X POST http://localhost:3002/v1/map \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://firecrawl.dev"}'
```

### Search

```bash
curl -X POST http://localhost:3002/v1/search \
  -H 'Content-Type: application/json' \
  -d '{"query": "firecrawl web scraping", "limit": 5}'
```

### Extract Structured Data (requires OpenAI or Ollama)

```bash
curl -X POST http://localhost:3002/v1/scrape \
  -H 'Content-Type: application/json' \
  -d '{
    "url": "https://firecrawl.dev",
    "formats": ["json"],
    "jsonOptions": {
      "prompt": "Extract the company mission and whether it is open source"
    }
  }'
```

> For LLM-powered features (extract, agent), set `OPENAI_API_KEY` in your `.env` or use a local model via `OLLAMA_BASE_URL`.

---

## Using with SDKs

Point any official Firecrawl SDK to your local server. Pass any string as the API key.

### Python

```bash
pip install firecrawl-py
```

```python
from firecrawl import FirecrawlApp

app = FirecrawlApp(api_key="fc-local", api_url="http://localhost:3002")

# Scrape
result = app.scrape_url("https://example.com")
print(result["markdown"])

# Crawl
crawl = app.crawl_url("https://docs.firecrawl.dev", params={"limit": 10})
for page in crawl["data"]:
    print(page["metadata"]["sourceURL"])

# Map
urls = app.map_url("https://firecrawl.dev")
print(urls)
```

### JavaScript / TypeScript

```bash
npm install @mendable/firecrawl-js
```

```javascript
import FirecrawlApp from '@mendable/firecrawl-js';

const app = new FirecrawlApp({ apiKey: "fc-local", apiUrl: "http://localhost:3002" });

// Scrape
const result = await app.scrapeUrl("https://example.com");
console.log(result.markdown);

// Crawl
const crawl = await app.crawlUrl("https://docs.firecrawl.dev", { limit: 10 });
crawl.data.forEach(page => console.log(page.metadata.sourceURL));
```

---

## Configuration

Edit `apps/api/.env` after first run. Key settings:

```bash
# Port (default 3002)
PORT=3002

# MUST be false for free local mode
USE_DB_AUTHENTICATION=false

# Reduce workers for low-memory machines (Raspberry Pi, etc.)
NUM_WORKERS_PER_QUEUE=2
NUQ_WORKER_COUNT=1

# Add OpenAI key for LLM features (extract, agent)
OPENAI_API_KEY=sk-your-key-here

# Or use free local LLM via Ollama
OLLAMA_BASE_URL=http://localhost:11434
```

---

## Manual Setup (without start-local.sh)

If you prefer to set things up yourself:

```bash
# 1. Install system services
sudo apt install redis-server postgresql rabbitmq-server   # Ubuntu/Debian
# brew install redis postgresql rabbitmq                    # macOS

# 2. Start services
redis-server --daemonize yes
sudo service postgresql start
sudo service rabbitmq-server start

# 3. Create database
sudo -u postgres createdb firecrawl
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"
sudo -u postgres psql -d firecrawl -f apps/nuq-postgres/nuq-local.sql

# 4. Configure environment
cd apps/api
cp .env.local .env

# 5. Install and start
pnpm install
pnpm start
```

---

## Running on Raspberry Pi / Low-Memory Devices

Works on Raspberry Pi 4 (8GB) and similar. Recommendations:

1. **Reduce workers** in `.env`:
   ```
   NUM_WORKERS_PER_QUEUE=2
   NUQ_WORKER_COUNT=1
   ```

2. **Add swap space**:
   ```bash
   sudo fallocate -l 4G /swapfile
   sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
   ```

3. **Use a USB SSD** instead of SD card for much better PostgreSQL performance.

---

## What is Firecrawl?

[Firecrawl](https://firecrawl.dev) is a web scraping API that converts websites into LLM-ready data. It handles:

- **LLM-ready output**: Clean markdown, structured JSON, screenshots, HTML
- **JavaScript rendering**: Handles SPAs and dynamic content
- **Media parsing**: Text extraction from PDFs, DOCX, images
- **Actions**: Click, scroll, type before extracting
- **Batch processing**: Scrape thousands of URLs asynchronously
- **Crawling**: Entire websites with one request

This fork gives you all of that locally, for free, with no restrictions.

---

## Stopping

Press `Ctrl+C` to stop Firecrawl. Background services (Redis, PostgreSQL, RabbitMQ) continue running.

```bash
# To stop everything:
redis-cli shutdown
sudo service postgresql stop
sudo service rabbitmq-server stop
```

---

## Original Project

This is a fork of [firecrawl/firecrawl](https://github.com/firecrawl/firecrawl). All credit for the core scraping engine goes to the Firecrawl team.

## License

AGPL-3.0 (same as original). SDKs are MIT licensed.

---

**It is your responsibility to respect websites' policies when scraping.** Adhere to applicable privacy policies and terms of use. Firecrawl respects robots.txt by default.

<p align="right" style="font-size: 14px; color: #555; margin-top: 20px;">
  <a href="#readme-top" style="text-decoration: none; color: #007bff; font-weight: bold;">
    ↑ Back to Top ↑
  </a>
</p>
