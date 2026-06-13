# Hermes Agent Ansible

Ansible playbooks to deploy [Hermes Agent](https://github.com/NousResearch/hermes-agent) on remote Linux or macOS hosts. The setup installs Ollama, configures Hermes with Firecrawl and Telegram, and schedules automated skills for stock tracking, tech news, and a daily HTML digest.

## What it deploys

| Playbook | Purpose |
|----------|---------|
| `deploy_hermes.yml` | Core install: Ollama, Hermes CLI, workspace, config, and `.env` |
| `deploy_investment.yml` | Midnight stock watchlist reports |
| `deploy_news.yml` | 5 AM IT/AI news digest |
| `deploy_digest.yml` | 6 AM combined Bootstrap HTML briefing via Telegram |

## Prerequisites

- `ansible-playbook` on your control machine
- SSH access to a remote host (this repo does **not** deploy to localhost)
- API keys for Telegram and Firecrawl

## Setup

1. Copy the example files and fill in your values:

```bash
cp vars.example..yml vars.yml
cp inventory.example.ini inventory.ini
```

2. Edit `vars.yml` with your Ollama model, Telegram IDs, Firecrawl key, and stock tickers.

3. Edit `inventory.ini` with your remote host and SSH user.

## Telegram smoke test

Verify your bot token and chat IDs before deploying. This runs on your control machine only and does **not** install Hermes or SSH to remote hosts.

`test_telegram.sh` reads `vars.yml` and exports the same `TELEGRAM_*` environment variables used by Hermes (`TELEGRAM_BOT_TOKEN`, `TELEGRAM_HOME_CHANNEL`, `TELEGRAM_ALLOWED_USERS`, `TELEGRAM_SEND_USERS`), then runs the smoke test playbook:

```bash
chmod +x test_telegram.sh
./test_telegram.sh
```

Set `telegram_bot_token` and at least one of `telegram_chat_id` or `telegram_allowed_users` in `vars.yml`. You should receive a short confirmation message in Telegram.

## Run

Deploy all playbooks to remote hosts (agents stay stopped by default):

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

Run a single playbook:

```bash
ansible-playbook -i inventory.ini deploy_hermes.yml -e hermes_start_agents=false
```

## Configuration

Secrets live in `vars.yml` (gitignored). Shared templates in `templates/` generate `~/.hermes/config.yaml` and `~/.hermes/.env` on the target host. Set `hermes_start_agents: false` in `vars.yml` to deploy config and cron jobs without starting background agents.
