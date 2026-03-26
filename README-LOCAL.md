# Firecrawl - Free Local Mode

Run Firecrawl locally with **no API keys, no Docker, no limits, and no billing**.

## Quick Start

```bash
# One command to set up everything and start:
./start-local.sh
```

That's it! The script will:
1. Check/install Redis, PostgreSQL, and RabbitMQ
2. Set up the database
3. Install Node.js dependencies
4. Start Firecrawl on `http://localhost:3002`

## Usage

Once running, use the API with **no API key required**:

### Scrape a page
```bash
curl -X POST http://localhost:3002/v1/scrape \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://example.com"}'
```

### Scrape with a dummy auth header (for SDK compatibility)
```bash
curl -X POST http://localhost:3002/v1/scrape \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer fc-local' \
  -d '{"url": "https://example.com"}'
```

### Crawl a website
```bash
curl -X POST http://localhost:3002/v1/crawl \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://example.com", "limit": 10}'
```

### Map a website
```bash
curl -X POST http://localhost:3002/v1/map \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://example.com"}'
```

### Search
```bash
curl -X POST http://localhost:3002/v1/search \
  -H 'Content-Type: application/json' \
  -d '{"query": "firecrawl web scraping"}'
```

## Using with SDKs

You can use the official Firecrawl SDKs by pointing them to your local server. Pass any string as the API key (it's ignored in local mode):

### Python SDK
```python
from firecrawl import FirecrawlApp

app = FirecrawlApp(api_key="fc-local", api_url="http://localhost:3002")
result = app.scrape_url("https://example.com")
print(result["markdown"])
```

### JavaScript/TypeScript SDK
```javascript
import FirecrawlApp from '@mendable/firecrawl-js';

const app = new FirecrawlApp({ apiKey: "fc-local", apiUrl: "http://localhost:3002" });
const result = await app.scrapeUrl("https://example.com");
console.log(result.markdown);
```

## What's Different from Cloud Firecrawl?

| Feature | Cloud (firecrawl.dev) | Local Free Mode |
|---------|----------------------|-----------------|
| API Key | Required | Not needed |
| Credits | Limited by plan | Unlimited |
| Rate Limits | Per plan | Unlimited |
| Billing | Pay per use | Free |
| Docker | Optional | Not required |
| Setup | Sign up + API key | `./start-local.sh` |

## Prerequisites

The `start-local.sh` script will try to install these automatically, but if you prefer to install them manually:

- **Node.js** >= 18 (required)
- **pnpm** (auto-installed if missing)
- **Redis** (auto-installed if missing)
- **PostgreSQL** (auto-installed if missing)
- **RabbitMQ** (auto-installed if missing)
- **Go** >= 1.21 (for html-to-markdown, optional but recommended)

### Manual install on Ubuntu/Debian:
```bash
sudo apt update
sudo apt install -y redis-server postgresql rabbitmq-server
```

### Manual install on macOS:
```bash
brew install redis postgresql rabbitmq
brew services start redis
brew services start postgresql
brew services start rabbitmq
```

## Manual Setup (without start-local.sh)

If you prefer to set things up yourself:

```bash
# 1. Copy the local config
cd apps/api
cp .env.local .env

# 2. Make sure Redis, PostgreSQL, and RabbitMQ are running

# 3. Create the database
sudo -u postgres createdb firecrawl

# 4. Install dependencies and start
pnpm install
pnpm start
```

## Configuration

Edit `apps/api/.env` to customize. Key settings:

```bash
# Port (default 3002)
PORT=3002

# This MUST be false for free local mode
USE_DB_AUTHENTICATION=false

# Add OpenAI key for LLM features (extract with AI, etc.)
OPENAI_API_KEY=sk-your-key-here

# Or use free local LLM via Ollama
OLLAMA_BASE_URL=http://localhost:11434
```

## Stopping

Press `Ctrl+C` to stop Firecrawl. Redis, PostgreSQL, and RabbitMQ will continue running as system services.

To stop everything:
```bash
# Stop Redis
redis-cli shutdown

# Stop PostgreSQL
sudo systemctl stop postgresql  # or: brew services stop postgresql

# Stop RabbitMQ
sudo systemctl stop rabbitmq-server  # or: brew services stop rabbitmq
```
