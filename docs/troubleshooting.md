# Troubleshooting

| Problem | Fix |
|---------|-----|
| Gateway not running (macOS) | `bash scripts/diagnose_gateway.sh vars.yml` · `./start_gateway.sh` · `pgrep -fl "hermes.*gateway run"` · logs: `~/.hermes/logs/gateway.stderr.log` |
| LaunchAgent not loaded | `./start_gateway.sh` or `scripts/macos_launchd_gateway.sh start ~` |
| Process up, LaunchAgent down | Detached fallback — re-run `./start_gateway.sh` |
| `gateway.stderr.log` missing | Run `./start_gateway.sh` first |
| Hermes CLI not found | Run `deploy_hermes.yml`; check `~/.local/bin/hermes` |
| Skill playbook fails | Core deploy must run first — use `deploy_local.sh` |
| `invalid choice: 'workspace'` | Pull latest playbooks |
| LM Studio 401 | Enable token in LM Studio Developer; set `hermes_model_api_key` |
| `lms get` fails | Playbooks use Hugging Face URL; log: `~/.hermes/logs/lms-get.log` |
| Deploy stuck on `lms load` | First 12B load can take 5–15 min; log: `~/.hermes/logs/lms-load.log` |
| `Model not found` / load fails | Re-run `./deploy_local.sh`; check `lms-get.log`, `lms-load.log` |
| `lms: command not found` | `source ~/.hermes/bin/lmstudio-path.sh` |
| Artifact resolve error | Set `lmstudio_model_download_url` to full Hugging Face repo URL |
| MLX load fails | Use GGUF key from vars.yml; re-run deploy with `--gguf` config |
| Digest smoke test timeout | Pre-warm reports or `SMOKE_TEST_TIMEOUT=10800 ./test_hermes_daily_digest.sh` |
| Digest passes, no Telegram | Re-run deploy to install `hermes-daily-digest.sh` (sends via `hermes send`) |
| Digest fails | LM Studio up; re-deploy for `config.yaml` sync; reload model with `--context-length 65536` |
| Context length ~6K error | Stale Ollama in `.env` — re-run deploy/smoke test to sync config + `.env` |
| `context window ... below 64000` | Set `hermes_model_context_length: 65536`, re-deploy, `lms unload && lms load ...` |
| `no API keys or providers found` | Re-deploy; Hermes needs `config.yaml` with `provider: custom` |
| macOS job not firing | `launchctl list \| grep hermes`; reload plist after re-deploy |

**Hugging Face token:** only needed for gated models. Public LM Studio picks in `vars.example..yml` do not require one.

See also [gateway diagnostics](gateway.md) and [smoke tests](smoke-tests.md).
