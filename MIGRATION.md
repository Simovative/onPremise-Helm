# Migrating from `kubernetes/ingress-nginx` to F5/NGINX Inc. Ingress Controller

`kubernetes/ingress-nginx` is being retired on **31 March 2026**. academyfive
chart 19.0.0 switches the default Ingress controller target from
`kubernetes/ingress-nginx` to F5/NGINX Inc.'s
[`nginx/kubernetes-ingress`](https://github.com/nginx/kubernetes-ingress).

The Kubernetes Ingress API itself (`networking.k8s.io/v1`) is **not**
deprecated — only the community controller. Customers who already use AWS
ALB or another controller via their own `ingressClassName` + annotations
remain unaffected.

This guide walks through a zero-downtime cutover.

---

## What changed in the chart

| | 18.x | 19.0 |
|---|---|---|
| Target controller | `kubernetes/ingress-nginx` | `nginx/kubernetes-ingress` (F5 NGINX Inc.) |
| Annotation prefix | `nginx.ingress.kubernetes.io/*` | `nginx.org/*` |
| ConfigMap key for global snippet | `http-snippet` (singular) | `http-snippets` (plural) |
| ConfigMap management | manual (`nginx-configmap/`) | manual **or** managed (new `nginxControllerConfig` subchart) |
| `gzip`, `http2` | per-Ingress annotation | global ConfigMap key |
| `proxy_cache_path` | global, manual ConfigMap | global, managed or manual |
| CORS | `enable-cors` annotation | `add_header` lines in `nginx.org/location-snippets` |
| Asset-cache regex paths | `use-regex: "true"` | `nginx.org/path-regex: "case_sensitive"` |

A cutover toggle `global.ingressAnnotationStyle` controls which annotation
set is rendered:

```yaml
global:
  # "nginx-inc"      (default) — emit nginx.org/* only
  # "ingress-nginx"  — emit legacy nginx.ingress.kubernetes.io/* only
  # "both"           — emit both sets (cutover mode)
  ingressAnnotationStyle: "nginx-inc"
```

Both controllers silently ignore the other's annotation prefix, so `"both"`
is safe for running side-by-side during the cutover.

---

## Recommended cutover path (zero downtime)

### 1. Update the chart to 19.x without switching the controller

Set the cutover style and keep your existing controller running:

```yaml
global:
  ingressAnnotationStyle: "both"
```

Re-deploy. Your Ingress resources now carry both annotation sets. The active
`ingress-nginx` controller still handles traffic; the new annotations are
inert until an F5 NGINX controller picks them up.

### 2. Install the F5 NGINX Inc. Ingress Controller in parallel

```shell
helm install nginx-ingress oci://ghcr.io/nginx/charts/nginx-ingress \
  --namespace nginx-ingress --create-namespace \
  --set controller.ingressClass.name=nginx-f5 \
  --set controller.config.name=nginx-ingress
```

Use a **distinct** `ingressClass` name (here: `nginx-f5`) so it doesn't
collide with the existing `nginx` class served by `ingress-nginx`.

### 3. Provide the controller ConfigMap

**Option A — managed (recommended for a dedicated controller):**

```yaml
nginxControllerConfig:
  enabled: true
  configMap:
    name: nginx-ingress          # must match controller.config.name above
    namespace: nginx-ingress
```

**Option B — manual (recommended for a shared controller):**

```shell
# edit nginx-configmap/nginx-configmap.yaml to match your controller's
# -nginx-configmaps flag, then:
kubectl apply -f nginx-configmap/nginx-configmap.yaml
```

### 4. Switch Ingress traffic per resource

Override the IngressClass for each Ingress subchart, one at a time, and
re-deploy:

```yaml
a5Ingress:
  ingress:
    ingressClassName: nginx-f5
  assets:
    ingressClassName: nginx-f5
casIngress:
  ingress:
    ingressClassName: nginx-f5
oasChart:
  ingress:
    ingressClassName: nginx-f5
n8nSsoProxyChart:
  ingress:
    ingressClassName: nginx-f5
```

Each `helm upgrade` flips one Ingress from the old controller to the new.
Smoke-test in between. If anything misbehaves, flip just that one back to
`nginx`.

### 5. Drop the legacy annotations and the old controller

Once all Ingresses are on `nginx-f5`:

```yaml
global:
  ingressAnnotationStyle: "nginx-inc"
```

Re-deploy, then remove the old controller:

```shell
helm uninstall ingress-nginx -n ingress-nginx
```

Optionally rename `nginx-f5` back to `nginx` in your controller install
(and the chart values) so customer-facing config stays the same as before.

---

## Customer-provided annotation overrides

Customers who set their own `nginx.ingress.kubernetes.io/*` annotations on
top of the chart (via `ingress.annotations`) need to translate them to
`nginx.org/*` keys. The most common mappings:

| `kubernetes/ingress-nginx` | F5/NGINX Inc. equivalent |
|---|---|
| `proxy-body-size` | `nginx.org/client-max-body-size` |
| `proxy-buffering` | `nginx.org/proxy-buffering` |
| `proxy-buffer-size` | `nginx.org/proxy-buffer-size` |
| `proxy-buffer-number` (+ `proxy-buffer-size`) | `nginx.org/proxy-buffers` (combined: `"16 16k"`) |
| `proxy-next-upstream` | `nginx.org/proxy-next-upstream` |
| `proxy-connect-timeout` | `nginx.org/proxy-connect-timeout` |
| `proxy-read-timeout` | `nginx.org/proxy-read-timeout` |
| `proxy-send-timeout` | `nginx.org/proxy-send-timeout` |
| `configuration-snippet` | `nginx.org/location-snippets` |
| `server-snippet` | `nginx.org/server-snippets` |
| `use-regex` | `nginx.org/path-regex: "case_sensitive"` |
| `use-gzip` / `gzip-level` | ConfigMap `http-snippets`: `gzip on; gzip_comp_level <N>;` |
| `use-http2` | ConfigMap key `http2: "true"` |
| `keep-alive` / `keep-alive-requests` | ConfigMap keys `keepalive-timeout` / `keepalive-requests`, or `nginx.org/server-snippets` for per-Ingress |
| `client-body-buffer-size`, `client-*-timeout`, `large-client-header-buffers` | `nginx.org/server-snippets` (no per-Ingress annotation in F5 NGINX) |
| `enable-cors` / `cors-allow-origin` | `add_header Access-Control-Allow-*` in `nginx.org/location-snippets` |

Full reference:
https://docs.nginx.com/nginx-ingress-controller/configuration/ingress-resources/advanced-configuration-with-annotations/

---

## AWS ALB customers

No change. Continue using your own `ingressClassName` (e.g. `alb`) and
`alb.ingress.kubernetes.io/*` annotations. Example annotations are kept
commented out in each subchart's `values.yaml`.
