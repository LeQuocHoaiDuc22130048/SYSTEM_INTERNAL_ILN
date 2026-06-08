# Graceful Shutdown

Spring Boot graceful shutdown is enabled:

```yaml
server.shutdown: graceful
spring.lifecycle.timeout-per-shutdown-phase: 60s
```

Override the timeout when attendance sync requests need more time:

```bash
SPRING_SHUTDOWN_TIMEOUT=90s
```

Deployment rules:

- Send `SIGTERM` and wait for the process to exit.
- Do not use `kill -9` unless the process is already stuck past the grace
  period.
- Configure the process manager/orchestrator termination grace period to be
  greater than `SPRING_SHUTDOWN_TIMEOUT`.
- Keep the load balancer or uptime monitor pointed at `/health`; during deploy,
  remove the instance from rotation before terminating it when possible.

Kubernetes example:

```yaml
terminationGracePeriodSeconds: 90
```

Docker Compose/systemd should use a stop timeout of at least 90 seconds when
`SPRING_SHUTDOWN_TIMEOUT=60s`.

This prevents losing in-flight attendance requests during restart or deploy.
