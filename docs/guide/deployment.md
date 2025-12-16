# Deployment

Guidance for deploying `api.zig` applications in production.

## Recommendations

- Run behind a reverse proxy (nginx, Caddy) or a load-balancer for TLS termination.
- Use systemd or container orchestrators (Docker, Kubernetes) for process supervision.
- Configure environment variables for runtime config (port, address, feature flags).

## Example systemd unit

```
[Unit]
Description=api.zig service
After=network.target

[Service]
Type=simple
User=www-data
ExecStart=/opt/myapp/bin/myapp
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

## Containers

- Build small images (static binary will help) and use health and readiness probes in orchestrators.
- For multi-replica setups, use an external session store (Redis) and centralized logs/metrics.

Refer to the docs above (Metrics, Health Checks, Caching) for production concerns.