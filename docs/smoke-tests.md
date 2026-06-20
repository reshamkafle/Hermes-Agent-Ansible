# Smoke tests

Optional localhost checks. None install Hermes or touch remote hosts.

## Telegram

Confirms bot token and chat IDs. Run **before** deploy.

```bash
chmod +x test_telegram.sh && ./test_telegram.sh
```

Playbook: `smoke_test_telegram.yml`

## LM Studio and gateway

Run **after** `./deploy_local.sh`.

```bash
chmod +x test_lmstudio_gateway.sh && ./test_lmstudio_gateway.sh
```

Playbook: `smoke_test_lmstudio_gateway.yml`

**Needs:** `vars.yml` with `lmstudio_base_url` and model key; LM Studio running:

```bash
lms daemon up && lms server start
lms get <model-from-vars.yml> && lms load <model-from-vars.yml>
```

| Check | macOS | Linux |
|-------|-------|-------|
| LM Studio API | yes | yes |
| Model in `/v1/models` | yes | yes |
| Gateway running | `pgrep` | `systemctl` |
| LaunchAgent / Aqua session | yes | — |

Exit `0` = pass. On failure, prints gateway diagnostics to `~/.hermes/logs/gateway-diagnostics.txt`.

**If it fails:** start LM Studio and load model; run `./start_gateway.sh` or [diagnose gateway](gateway.md).

## Daily digest

Full `daily-morning-digest` skill → Telegram HTML. First cold run can take **60–120+ minutes** on a local LLM.

```bash
chmod +x test_hermes_daily_digest.sh && ./test_hermes_daily_digest.sh
```

Playbook: `smoke_test_hermes_daily_digest.yml`

Needs LM Studio, `firecrawl_api_key`, Telegram. Default timeout 7200s:

```bash
SMOKE_TEST_TIMEOUT=10800 ./test_hermes_daily_digest.sh
```

Pre-warm cached reports (news, gold, investment skills) to speed re-runs.
