# Container Strategy

This document outlines the containerization strategy for the Eventz Flow backend, focusing on process management and graceful shutdown handling.

## Overview

The Eventz Flow backend runs on Rails with Sidekiq workers in Docker containers. This strategy addresses zombie process prevention, graceful shutdowns, and reliable redeployments.

## Architecture

### Services

| Service | Purpose | Command |
|---------|---------|---------|
| web | Rails application server | `./bin/rails server` |
| sidekiq | Background job processor | `bundle exec sidekiq` |
| postgres-db | PostgreSQL database | (default) |
| redis | Redis for Sidekiq | `redis-server --appendonly yes` |

### Network

All services communicate over the `coolify` Docker network.

## Process Management

### Tini as PID 1

Tini is used as the init process (PID 1) inside each container to handle zombie process reaping.

**Benefits:**
- Prevents zombie processes from accumulating
- Properly forwards signals to child processes
- Ensures child processes are terminated when the container stops

**Implementation:**

```dockerfile
# Dockerfile
RUN apt-get install --no-install-recommends -y curl libvips postgresql-client tini

ENTRYPOINT ["/usr/bin/tini", "--", "/rails/bin/docker-entrypoint"]
```

Tini wraps the entrypoint script, becoming PID 1 and managing all child processes.

### Entrypoint Script

```bash
#!/bin/bash -e

if [ "${1}" == "./bin/rails" ] && [ "${2}" == "server" ]; then
  ./bin/rails db:prepare
fi

exec "${@}"
```

The entrypoint:
1. Prepares the database on first run (creates/migrates)
2. Uses `exec` to replace the shell with the actual process, ensuring Tini tracks it correctly

## Graceful Shutdown Configuration

### Docker Compose Settings

```yaml
stop_signal: SIGTERM
stop_grace_period: 30s
```

**Explanation:**
- `stop_signal: SIGTERM` - Sends SIGTERM for graceful shutdown (instead of SIGKILL)
- `stop_grace_period: 30s` - Gives processes 30 seconds to clean up before SIGKILL

**Applied to:**
- `web` service (lines 42-43)
- `sidekiq` service (lines 65-66)

### Expected Shutdown Flow

1. Docker sends SIGTERM to container
2. Tini forwards SIGTERM to Rails/Sidekiq processes
3. Rails/Sidekiq:
   - Stop accepting new requests/jobs
   - Complete current work (with 30s timeout)
   - Close database/Redis connections
   - Exit gracefully
4. Tini reaps any zombie children
5. Container exits cleanly

## Zombie Process Prevention

### What are Zombie Processes?

Zombie processes are terminated processes that haven't been reaped by their parent. They accumulate when:
- Parent process doesn't call `wait()` 
- Child exits before parent reads its exit status
- Process tree isn't properly managed

### Prevention Strategy

1. **Tini as init process** - Reaps zombies automatically
2. **Graceful shutdown** - Ensures processes exit cleanly
3. **Proper signal handling** - Rails and Sidekiq handle SIGTERM correctly

### Verification

Check for zombies inside a running container:

```bash
docker exec -it <container_name> ps aux | grep 'Z'
```

Or check if Tini is PID 1:

```bash
docker exec <container_name> ps aux | head -5
```

Expected output:
```
PID  USER   COMMAND
1    root   /usr/bin/tini -- /rails/bin/docker-entrypoint
...
```

## Deployment on Coolify

### Redeployment Flow

1. Coolify pulls latest image
2. Creates new containers with health checks
3. Sends SIGTERM to old containers
4. Waits for `stop_grace_period` before force-killing
5. Routes traffic to new containers

### Configuration Requirements

No additional Coolify configuration needed. The docker-compose.yaml settings are respected by Coolify.

### Recommended Settings in Coolify

- **Health Check Interval:** 30s (already configured)
- **Restart Policy:** Unless stopped
- **Shutdown Timeout:** 60s (longer than container's 30s for safety)

## Troubleshooting

### Zombie Processes After Redeploy

**Symptoms:**
- Container uses excessive memory/CPU
- `ps aux` shows processes in `Z` state
- Performance degradation

**Diagnosis:**

```bash
# Check for zombies
docker exec <container_name> ps aux | grep 'Z'

# Check parent processes
docker exec <container_name> ps -eo pid,ppid,stat,comm
```

**Solutions:**

1. **Full container restart:**
   ```bash
   docker compose down && docker compose up -d
   ```

2. **Kill orphaned processes:**
   ```bash
   docker exec <container_name> pkill -9 -f sidekiq
   docker exec <container_name> pkill -9 -f rails
   ```

3. **Force remove zombie by killing parent:**
   ```bash
   docker exec <container_name> kill -9 <zombie_pid>
   # Note: This rarely works; container restart is more reliable
   ```

### Container Won't Shutdown

**Symptoms:**
- Container hangs during redeploy
- `stop_grace_period` exceeded

**Diagnosis:**

```bash
# Check running processes
docker exec <container_name> ps aux

# Check what PID 1 is waiting for
docker exec <container_name> strace -p 1 -f
```

**Solutions:**

1. Increase `stop_grace_period` in docker-compose.yaml
2. Add signal handlers to custom processes
3. Check for stuck database transactions
4. Check for unresponsive Redis operations

### Database Connection Leaks

**Symptoms:**
- PostgreSQL connections accumulate
- "too many connections" errors

**Solutions:**
1. Ensure ActiveRecord connection pool is properly closed
2. Use `ActiveRecord::Base.connection_pool.disconnect!` in shutdown hooks
3. Set `RAILS_MAX_THREADS` appropriately

## Best Practices

### Development

```bash
# Always rebuild after docker-compose changes
docker compose build
docker compose up -d

# Monitor processes
docker compose logs -f
docker exec -it <container> ps aux
```

### Production

1. **Monitor container health** - Use the configured health checks
2. **Set appropriate timeouts** - Match `stop_grace_period` to actual workload
3. **Log process events** - Enable Rails process logging
4. **Regular restarts** - Consider periodic healthy restarts to prevent drift

### Monitoring Checklist

- [ ] Tini is PID 1
- [ ] No zombie processes in `ps aux | grep 'Z'`
- [ ] Graceful shutdown completes within `stop_grace_period`
- [ ] Health checks pass consistently
- [ ] No connection pool leaks after restarts

## References

- [Tini GitHub](https://github.com/krallin/tini)
- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Rails on Docker](https://docs.docker.com/language/ruby/)
- [Coolify Documentation](https://coolify.io/docs)
