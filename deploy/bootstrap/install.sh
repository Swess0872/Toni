#!/usr/bin/env bash
# One-time cluster bootstrap: installs Argo CD and hands everything else to GitOps.
#
#   REPO_URL=https://github.com/<owner>/toni \
#   ACME_EMAIL=you@example.com \
#   ./deploy/bootstrap/install.sh
#
# Optional:
#   ADMIN_USERNAME / ADMIN_PASSWORD  first Toni login (password is generated if empty)
#   GITHUB_TOKEN                     PAT with repo + read:packages, only for a private repo / private GHCR images
#   GITHUB_USER                      owner of that token (default: taken from REPO_URL)
set -euo pipefail

: "${REPO_URL:?REPO_URL fehlt, z.B. https://github.com/<owner>/toni}"
: "${ACME_EMAIL:?ACME_EMAIL fehlt (für Let's Encrypt)}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
GITHUB_USER="${GITHUB_USER:-$(echo "$REPO_URL" | sed -E 's#https://github.com/([^/]+)/.*#\1#')}"
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "==> Argo CD installieren"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -k "$HERE/../argocd"
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s

echo "==> Toni-Secrets anlegen"
kubectl create namespace toni --dry-run=client -o yaml | kubectl apply -f -
if ! kubectl -n toni get secret toni-secrets >/dev/null 2>&1; then
  if [ -z "$ADMIN_PASSWORD" ]; then
    ADMIN_PASSWORD="$(openssl rand -base64 12)"
    GENERATED_PASSWORD=1
  fi
  kubectl -n toni create secret generic toni-secrets \
    --from-literal=jwtKey="$(openssl rand -base64 48)" \
    --from-literal=adminUsername="$ADMIN_USERNAME" \
    --from-literal=adminPassword="$ADMIN_PASSWORD"
else
  echo "    toni-secrets existiert bereits — unverändert gelassen"
fi

IMAGE_PULL_SECRET=""
if [ -n "${GITHUB_TOKEN:-}" ]; then
  echo "==> Zugang zum privaten Repo und zu GHCR einrichten"
  kubectl -n argocd create secret generic toni-repo \
    --from-literal=type=git \
    --from-literal=url="$REPO_URL" \
    --from-literal=username="$GITHUB_USER" \
    --from-literal=password="$GITHUB_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n argocd label secret toni-repo argocd.argoproj.io/secret-type=repository --overwrite
  kubectl -n toni create secret docker-registry ghcr \
    --docker-server=ghcr.io \
    --docker-username="$GITHUB_USER" \
    --docker-password="$GITHUB_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
  IMAGE_PULL_SECRET="ghcr"
fi

TRAEFIK_ENABLED=true
if kubectl get ingressclass traefik >/dev/null 2>&1 && ! kubectl get ns traefik >/dev/null 2>&1; then
  echo "    Vorhandenes Traefik gefunden (z.B. k3s) — es wird kein zweites installiert"
  TRAEFIK_ENABLED=false
fi

echo "==> Root-Application anlegen"
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $REPO_URL
    targetRevision: main
    path: deploy/platform
    helm:
      valuesObject:
        repoURL: $REPO_URL
        acmeEmail: $ACME_EMAIL
        traefik:
          enabled: $TRAEFIK_ENABLED
        imagePullSecret: "$IMAGE_PULL_SECRET"
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

echo
echo "Fertig. Argo CD installiert jetzt Traefik, cert-manager, Postgres und Toni."
echo "Status:    kubectl -n argocd get applications"
echo "Argo-UI:   kubectl -n argocd port-forward svc/argocd-server 8080:443  →  https://localhost:8080"
echo "Argo-Login: admin / \$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
if [ "${GENERATED_PASSWORD:-}" = 1 ]; then
  echo "Toni-Login: $ADMIN_USERNAME / $ADMIN_PASSWORD   (bitte nach dem ersten Login im Profil ändern)"
fi
