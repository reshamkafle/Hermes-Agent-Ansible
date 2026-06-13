# Hermes Agent Ansible

Deploy [Hermes Agent](https://github.com/NousResearch/hermes-agent) on Linux or macOS — locally or over SSH. Installs Ollama, configures Hermes (Firecrawl + Telegram), and schedules stock, news, and daily digest skills.

## Quick start

1. **Configure secrets**

```bash
cp vars.example..yml vars.yml
# Edit: ollama_model, Telegram IDs, firecrawl_api_key, tracked_stocks
```

2. **Remote only** — add your server to inventory:

```bash
cp inventory.example.ini inventory.ini
```

3. **Test Telegram** (optional, before deploy):

```bash
chmod +x test_telegram.sh && ./test_telegram.sh
```

4. **Deploy**

```bash
# This machine
chmod +x deploy_local.sh && ./deploy_local.sh

# Remote host (requires inventory.ini — not localhost)
chmod +x deploy_all.sh && ./deploy_all.sh
```

5. **Start gateway** (optional — off by default):

```bash
START_HERMES_AGENTS=1 ./deploy_local.sh   # or deploy_all.sh
```

On macOS, attach to the gateway: `tmux attach -t hermes_ws`

## Playbooks

Run in this order (`deploy_local.sh` / `deploy_all.sh` do this automatically):

| Playbook | Purpose |
|----------|---------|
| `deploy_hermes.yml` | Core: Ollama, Hermes CLI, config, `.env` |
| `deploy_investment.yml` | Midnight stock watchlist |
| `deploy_news.yml` | 5 AM IT/AI news digest |
| `deploy_digest.yml` | 6 AM combined HTML briefing via Telegram |

Run `deploy_hermes.yml` first — skill playbooks expect `~/.hermes/` to exist.

## Prerequisites

| | Local (`deploy_local.sh`) | Remote (`deploy_all.sh`) |
|--|---------------------------|--------------------------|
| Required | `ansible-playbook`, `vars.yml` | + SSH, `inventory.ini` |
| macOS | [Homebrew](https://brew.sh/) | Same |
| API keys | Telegram + Firecrawl | Same |

## macOS vs Linux

| | Linux / WSL2 | macOS (local) |
|--|--------------|---------------|
| User / home | `hermes` → `/home/hermes` | Your login user → `~/` |
| Config & skills | `/home/hermes/.hermes/` | `~/.hermes/` |
| Scheduler | cron | LaunchAgents in `~/Library/LaunchAgents/` |

Playbooks auto-find the Hermes CLI (`~/.local/bin/hermes`, Homebrew paths, or PATH). Only `deploy_hermes.yml` installs Hermes if missing.

## Scheduled jobs

| Skill | Time | macOS plist |
|-------|------|-------------|
| Stock tracker | Midnight | `com.hermes.investment.plist` |
| Tech news | 5 AM | `com.hermes.technews.plist` |
| Daily digest | 6 AM | `com.hermes.dailydigest.plist` |

Logs: `~/.hermes/logs/` · Linux gateway: `systemctl status hermes-workspace`

## Smoke tests

**Telegram** — `./test_telegram.sh` — confirms bot token and chat IDs (no Hermes install).

**Daily digest** — after deploy:

```bash
chmod +x test_hermes_daily_digest.sh && ./test_hermes_daily_digest.sh
```

Needs Ollama running, `firecrawl_api_key`, and Telegram configured. May take several minutes; override timeout:

```bash
SMOKE_TEST_TIMEOUT=3600 ./test_hermes_daily_digest.sh
```

## Run one playbook

```bash
# Local
ansible-playbook -i 'localhost,' -c local -e ansible_become=false deploy_hermes.yml

# Remote
ansible-playbook -i inventory.ini deploy_hermes.yml
```

Custom inventory: `INVENTORY=hosts.ini ./deploy_all.sh`

## Key `vars.yml` settings

| Variable | Purpose |
|----------|---------|
| `hermes_start_agents` | Start gateway after deploy (default `false`; use `START_HERMES_AGENTS=1` to override) |
| `ollama_model` | LLM to pull via Ollama |
| `tracked_stocks` | Tickers for investment skill |
| `firecrawl_init_all` / `firecrawl_verify_install` | Firecrawl setup in `~/.hermes/workspace` |

Secrets stay in `vars.yml` (gitignored). Templates generate `~/.hermes/config.yaml` and `~/.hermes/.env`.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Hermes CLI not found | Run `deploy_hermes.yml` first; check `~/.local/bin/hermes` |
| Skill playbook fails | Core deploy must run first — use `deploy_local.sh` / `deploy_all.sh` |
| `invalid choice: 'workspace'` | Pull latest playbooks (CLI commands changed) |
| Digest smoke test fails | Check `ollama list`, `~/.hermes/skills/daily_digest.md`, logs in `~/.hermes/logs/` |
| macOS job not firing | `launchctl list \| grep hermes` · reload plist after re-deploy |

## Project layout

```
deploy_hermes.yml          deploy_investment.yml    deploy_news.yml    deploy_digest.yml
deploy_local.sh            deploy_all.sh            test_telegram.sh   test_hermes_daily_digest.sh
tasks/resolve_hermes_cmd.yml    templates/*.j2    vars.yml (from vars.example..yml)
```
