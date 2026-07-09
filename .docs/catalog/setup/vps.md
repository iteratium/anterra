# vps — Manual Setup

## Tailscale

```bash
tailscale up --ssh --accept-routes=true
```

- **`tag:peer-relay`** — already applied at the control-plane/registration level (auth key or admin console).
