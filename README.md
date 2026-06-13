# Hermes Agent Ansible

Ansible playbooks to deploy [Hermes Agent](https://github.com/NousResearch/hermes-agent) on Linux or macOS — either on a **remote host** over SSH or on **this machine** (localhost). The setup installs Ollama, configures Hermes with Firecrawl and Telegram, and schedules automated skills for stock tracking, tech news, and a daily HTML digest.

## What it deploys

| Playbook | Purpose |
|----------|---------|
| `deploy_hermes.yml` | Core install: Ollama, Hermes CLI, workspace, config, and `.env` |
| `deploy_investment.yml` | Midnight stock watchlist reports |
| `deploy_news.yml` | 5 AM IT/AI news digest |
| `deploy_digest.yml` | 6 AM combined Bootstrap HTML briefing via Telegram |

## Prerequisites

- `ansible-playbook` installed
- `vars.yml` configured (copy from `vars.example..yml`)
- API keys for Telegram and Firecrawl

**Remote deploy** (`deploy_all.sh`):

- SSH access to a remote host
- `inventory.ini` listing that host (copy from `inventory.example.ini`)

**Local deploy** (`deploy_local.sh`):

- No inventory or SSH required
- macOS: [Homebrew](https://brew.sh/) installed (playbooks install Ollama, git, node, and tmux via brew)

## Setup

1. Copy and edit `vars.yml`:

```bash
cp vars.example..yml vars.yml
```

Fill in your Ollama model, Telegram IDs, Firecrawl key, and stock tickers.

2. For **remote** deploy only, copy and edit the inventory:

```bash
cp inventory.example.ini inventory.ini
```

Replace the example host with your server IP or hostname and SSH user. Do **not** use `localhost` or `127.0.0.1` — `deploy_all.sh` refuses to run without a remote target.

On **local** deploy, `hermes_user` and `hermes_home` in `vars.yml` are ignored on macOS; playbooks use your normal home directory (`~/.hermes/`).

## Telegram smoke test

Verify your bot token and chat IDs before deploying. This runs on your control machine only and does **not** install Hermes or SSH to remote hosts.

`test_telegram.sh` reads `vars.yml` and exports the same `TELEGRAM_*` environment variables used by Hermes (`TELEGRAM_BOT_TOKEN`, `TELEGRAM_HOME_CHANNEL`, `TELEGRAM_ALLOWED_USERS`, `TELEGRAM_SEND_USERS`), then runs the smoke test playbook:

```bash
chmod +x test_telegram.sh
./test_telegram.sh
```

Set `telegram_bot_token` and at least one of `telegram_chat_id` or `telegram_allowed_users` in `vars.yml`. You should receive a short confirmation message in Telegram.

## Run

### Local (this machine)

Deploy all playbooks to localhost (agents stay stopped by default):

```bash
chmod +x deploy_local.sh
./deploy_local.sh
```

To also start the Hermes workspace daemon after deploy:

```bash
START_HERMES_AGENTS=1 ./deploy_local.sh
```

### Remote (SSH)

Deploy all playbooks to hosts in `inventory.ini` (agents stay stopped by default):

```bash
chmod +x deploy_all.sh
./deploy_all.sh
```

Use a custom inventory file:

```bash
INVENTORY=hosts.ini ./deploy_all.sh
```

To also start the Hermes workspace daemon after deploy:

```bash
START_HERMES_AGENTS=1 ./deploy_all.sh
```

### Single playbook

Remote:

```bash
ansible-playbook -i inventory.ini deploy_hermes.yml -e hermes_start_agents=false
```

Local:

```bash
ansible-playbook -i 'localhost,' -c local -e ansible_become=false deploy_hermes.yml -e hermes_start_agents=false
```

| Script | Target |
|--------|--------|
| `deploy_local.sh` | This machine only (`localhost`) |
| `deploy_all.sh` | Remote hosts only (refuses localhost) |

## Configuration

Secrets live in `vars.yml` (gitignored). Shared templates in `templates/` generate `~/.hermes/config.yaml` and `~/.hermes/.env` on the target host. Set `hermes_start_agents: false` in `vars.yml` to deploy config and cron jobs without starting background agents.
