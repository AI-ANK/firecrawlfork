#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Firecrawl Local Free Mode - Simple Plug & Play Startup
# No API keys, no Docker, no complicated setup
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="$SCRIPT_DIR/apps/api"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "\n${BOLD}${GREEN}==> $1${NC}"; }

# ---- Helper: check if a command exists ----
has_cmd() { command -v "$1" &>/dev/null; }

# ---- Helper: check if a service is running on a port ----
port_open() { nc -z localhost "$1" 2>/dev/null; }

# ============================================================
# Step 1: Check / Install prerequisites
# ============================================================
log_step "Checking prerequisites..."

# Node.js
if has_cmd node; then
    log_ok "Node.js $(node --version) found"
else
    log_error "Node.js is required. Install it from https://nodejs.org/"
    exit 1
fi

# pnpm
if has_cmd pnpm; then
    log_ok "pnpm $(pnpm --version) found"
else
    log_info "Installing pnpm..."
    npm install -g pnpm
    log_ok "pnpm installed"
fi

# Go (needed for html-to-markdown)
if has_cmd go; then
    log_ok "Go $(go version | awk '{print $3}') found"
else
    log_warn "Go is not installed. Some features (html-to-markdown) may not work."
    log_warn "Install Go from https://go.dev/dl/"
fi

# ============================================================
# Step 2: Install and start Redis
# ============================================================
log_step "Setting up Redis..."

if port_open 6379; then
    log_ok "Redis already running on port 6379"
else
    if has_cmd redis-server; then
        log_info "Starting Redis..."
        redis-server --daemonize yes --port 6379 --loglevel warning
        sleep 1
        if port_open 6379; then
            log_ok "Redis started on port 6379"
        else
            log_error "Failed to start Redis"
            exit 1
        fi
    else
        log_info "Installing Redis..."
        if has_cmd apt-get; then
            sudo apt-get update -qq && sudo apt-get install -y -qq redis-server
        elif has_cmd brew; then
            brew install redis
        elif has_cmd dnf; then
            sudo dnf install -y redis
        elif has_cmd pacman; then
            sudo pacman -S --noconfirm redis
        else
            log_error "Cannot install Redis automatically. Please install Redis manually."
            exit 1
        fi
        redis-server --daemonize yes --port 6379 --loglevel warning
        sleep 1
        log_ok "Redis installed and started"
    fi
fi

# ============================================================
# Step 3: Install and start PostgreSQL
# ============================================================
log_step "Setting up PostgreSQL..."

POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-firecrawl}"

if port_open 5432; then
    log_ok "PostgreSQL already running on port 5432"
else
    if has_cmd pg_isready; then
        log_info "Starting PostgreSQL..."
        if has_cmd pg_ctlcluster; then
            # Debian/Ubuntu
            sudo pg_ctlcluster $(pg_lsclusters -h | head -1 | awk '{print $1, $2}') start 2>/dev/null || true
        elif has_cmd pg_ctl; then
            pg_ctl start -D /var/lib/postgresql/data 2>/dev/null || sudo -u postgres pg_ctl start -D /var/lib/postgresql/data 2>/dev/null || true
        fi
        sleep 2
    else
        log_info "Installing PostgreSQL..."
        if has_cmd apt-get; then
            sudo apt-get update -qq && sudo apt-get install -y -qq postgresql postgresql-contrib
            sudo pg_ctlcluster $(pg_lsclusters -h | head -1 | awk '{print $1, $2}') start 2>/dev/null || true
        elif has_cmd brew; then
            brew install postgresql@16 && brew services start postgresql@16
        elif has_cmd dnf; then
            sudo dnf install -y postgresql-server postgresql && sudo postgresql-setup --initdb && sudo systemctl start postgresql
        else
            log_error "Cannot install PostgreSQL automatically. Please install it manually."
            exit 1
        fi
        sleep 2
    fi

    if port_open 5432; then
        log_ok "PostgreSQL running on port 5432"
    else
        log_error "Failed to start PostgreSQL"
        exit 1
    fi
fi

# Create database and user if needed
log_info "Ensuring PostgreSQL database '$POSTGRES_DB' exists..."
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$POSTGRES_USER'" 2>/dev/null | grep -q 1 || \
    sudo -u postgres psql -c "CREATE USER $POSTGRES_USER WITH SUPERUSER PASSWORD '$POSTGRES_PASSWORD';" 2>/dev/null || true
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='$POSTGRES_DB'" 2>/dev/null | grep -q 1 || \
    sudo -u postgres createdb -O "$POSTGRES_USER" "$POSTGRES_DB" 2>/dev/null || true
log_ok "PostgreSQL database ready"

# Run NUQ schema migrations (local version without pg_cron)
NUQ_LOCAL_SQL="$SCRIPT_DIR/apps/nuq-postgres/nuq-local.sql"
if [ -f "$NUQ_LOCAL_SQL" ]; then
    log_info "Running NUQ PostgreSQL schema setup..."
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$NUQ_LOCAL_SQL" 2>/dev/null || true
    log_ok "NUQ schema applied"
fi

# ============================================================
# Step 4: Install and start RabbitMQ
# ============================================================
log_step "Setting up RabbitMQ..."

if port_open 5672; then
    log_ok "RabbitMQ already running on port 5672"
else
    if has_cmd rabbitmq-server; then
        log_info "Starting RabbitMQ..."
        sudo rabbitmq-server -detached 2>/dev/null || rabbitmq-server -detached 2>/dev/null || true
        sleep 3
    else
        log_info "Installing RabbitMQ..."
        if has_cmd apt-get; then
            sudo apt-get update -qq && sudo apt-get install -y -qq rabbitmq-server
            sudo rabbitmq-server -detached 2>/dev/null || true
        elif has_cmd brew; then
            brew install rabbitmq && brew services start rabbitmq
        elif has_cmd dnf; then
            sudo dnf install -y rabbitmq-server && sudo systemctl start rabbitmq-server
        else
            log_error "Cannot install RabbitMQ automatically. Please install it manually."
            exit 1
        fi
        sleep 3
    fi

    if port_open 5672; then
        log_ok "RabbitMQ running on port 5672"
    else
        log_error "Failed to start RabbitMQ"
        exit 1
    fi
fi

# ============================================================
# Step 5: Set up .env file
# ============================================================
log_step "Setting up environment..."

if [ ! -f "$API_DIR/.env" ]; then
    cp "$API_DIR/.env.local" "$API_DIR/.env"
    log_ok "Created .env from .env.local (free local mode)"
else
    # Check if USE_DB_AUTHENTICATION is already false
    if grep -q "USE_DB_AUTHENTICATION=false" "$API_DIR/.env"; then
        log_ok ".env already configured for local free mode"
    else
        log_warn ".env exists but USE_DB_AUTHENTICATION may not be set to false"
        log_warn "For free local mode, ensure USE_DB_AUTHENTICATION=false in .env"
    fi
fi

# Ensure NUQ_DATABASE_URL is set
export NUQ_DATABASE_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:5432/${POSTGRES_DB}"
export NUQ_DATABASE_URL_LISTEN="$NUQ_DATABASE_URL"
export NUQ_RABBITMQ_URL="amqp://localhost:5672"

# Write these to .env if not already there
grep -q "NUQ_DATABASE_URL" "$API_DIR/.env" 2>/dev/null || echo "NUQ_DATABASE_URL=$NUQ_DATABASE_URL" >> "$API_DIR/.env"
grep -q "NUQ_DATABASE_URL_LISTEN" "$API_DIR/.env" 2>/dev/null || echo "NUQ_DATABASE_URL_LISTEN=$NUQ_DATABASE_URL_LISTEN" >> "$API_DIR/.env"

# ============================================================
# Step 6: Install dependencies and start Firecrawl
# ============================================================
log_step "Installing dependencies..."

cd "$API_DIR"
pnpm install

log_step "Starting Firecrawl (free local mode)..."
echo ""
echo -e "${BOLD}${GREEN}============================================${NC}"
echo -e "${BOLD}${GREEN}  Firecrawl Local Free Mode${NC}"
echo -e "${BOLD}${GREEN}  No API key required!${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}"
echo ""
echo -e "  API URL:     ${BOLD}http://localhost:3002${NC}"
echo -e "  Auth:        ${BOLD}DISABLED${NC} (no API key needed)"
echo -e "  Credits:     ${BOLD}UNLIMITED${NC}"
echo -e "  Rate Limits: ${BOLD}UNLIMITED${NC}"
echo ""
echo -e "  ${YELLOW}Usage example:${NC}"
echo -e "  curl -X POST http://localhost:3002/v1/scrape \\"
echo -e "    -H 'Content-Type: application/json' \\"
echo -e "    -H 'Authorization: Bearer fc-local' \\"
echo -e "    -d '{\"url\": \"https://example.com\"}'"
echo ""
echo -e "  ${YELLOW}Or without any auth header:${NC}"
echo -e "  curl -X POST http://localhost:3002/v1/scrape \\"
echo -e "    -H 'Content-Type: application/json' \\"
echo -e "    -d '{\"url\": \"https://example.com\"}'"
echo ""

# Set env vars and start
export USE_DB_AUTHENTICATION=false
export REDIS_URL=redis://localhost:6379
export REDIS_RATE_LIMIT_URL=redis://localhost:6379
export NUQ_DATABASE_URL
export NUQ_DATABASE_URL_LISTEN
export NUQ_RABBITMQ_URL

pnpm start
