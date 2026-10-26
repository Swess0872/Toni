#!/usr/bin/env bash
# One-time cluster bootstrap: makes sure Argo CD runs and hands everything else to GitOps.
# Components that already exist in the cluster (Argo CD, Traefik, cert-manager,
# CloudNativePG) are detected and left alone.
#
#   REPO_URL=https://github.com/<owner>/toni \
#   ACME_EMAIL=you@example.com \
#   ./deploy/bootstrap/install.sh
#
# Optional:
#   ARGOCD_NAMESPACE                 namespace of Argo CD (default: argocd)
#   ADMIN_USERNAME / ADMIN_PASSWORD  first Toni login (password is generated if empty)
#   GITHUB_TOKEN                     PAT with repo + read:packages, only for a private repo / private GHCR images
#   GITHUB_USER                      owner of that token (default: taken from REPO_URL)
set -euo pipefail

: "${REPO_URL:?REPO_URL fehlt, z.B. https://github.com/<owner>/toni}"
: "${ACME_EMAIL:?ACME_EMAIL fehlt (Kontakt-Mail für die Lets-Encrypt-Zertifikate)}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
GITHUB_USER="${GITHUB_USER:-$(echo "$REPO_URL" | sed -E 's#https://github.com/([^/]+)/.*#\1#')}"
HERE="$(cd "$(dirname "$0")" && pwd)"

exists() { kubectl get "$@" >/dev/null 2>&1; }

# ---- What is already installed? ---------------------------------------------
ARGOCD_SELF_MANAGED=true
if exists crd applications.argoproj.io; then
  echo "==> Argo CD ist bereits installiert — wird nicht angefasst"
  ARGOCD_SELF_MANAGED=false
  if ! exists -n "$ARGOCD_NAMESPACE" deploy/argocd-server; then
    echo "    Kein argocd-server im Namespace '$ARGOCD_NAMESPACE' gefunden."
    echo "    Läuft Argo CD in einem anderen Namespace? Dann ARGOCD_NAMESPACE=<ns> setzen." >&2
    exit 1
  fi
else
  echo "==> Argo CD installieren"
  kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -n "$ARGOCD_NAMESPACE" --server-side --force-conflicts -k "$HERE/../argocd"
  kubectl -n "$ARGOCD_NAMESPACE" rollout status deploy/argocd-repo-server --timeout=300s
fi

TRAEFIK_ENABLED=true
if exists ingressclass traefik && ! exists -n "$ARGOCD_NAMESPACE" application traefik; then
  echo "    Vorhandenes Traefik gefunden — es wird kein zweites installiert"
  TRAEFIK_ENABLED=false
fi

CERT_MANAGER_ENABLED=true
if exists crd certificates.cert-manager.io && ! exists -n "$ARGOCD_NAMESPACE" application cert-manager; then
  echo "    Vorhandenen cert-manager gefunden — wird mitbenutzt"
  CERT_MANAGER_ENABLED=false
fi

CNPG_ENABLED=true
if exists crd clusters.postgresql.cnpg.io && ! exists -n "$ARGOCD_NAMESPACE" application cloudnative-pg; then
  echo "    Vorhandenes CloudNativePG gefunden — wird mitbenutzt"
  CNPG_ENABLED=false
fi

# ---- Secrets ----------------------------------------------------------------
echo "==> Toni-Secrets anlegen"
kubectl create namespace toni --dry-run=client -o yaml | kubectl apply -f -
if ! exists -n toni secret toni-secrets; then
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
  kubectl -n "$ARGOCD_NAMESPACE" create secret generic toni-repo \
    --from-literal=type=git \
    --from-literal=url="$REPO_URL" \
    --from-literal=username="$GITHUB_USER" \
    --from-literal=password="$GITHUB_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n "$ARGOCD_NAMESPACE" label secret toni-repo argocd.argoproj.io/secret-type=repository --overwrite
  kubectl -n toni create secret docker-registry ghcr \
    --docker-server=ghcr.io \
    --docker-username="$GITHUB_USER" \
    --docker-password="$GITHUB_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
  IMAGE_PULL_SECRET="ghcr"
fi

# ---- Root application ---------------------------------------------------------
echo "==> Root-Application 'toni-root' anlegen"
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: toni-root
  namespace: $ARGOCD_NAMESPACE
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
        imagePullSecret: "$IMAGE_PULL_SECRET"
        argocd:
          selfManaged: $ARGOCD_SELF_MANAGED
        traefik:
          enabled: $TRAEFIK_ENABLED
        certManager:
          enabled: $CERT_MANAGER_ENABLED
        cnpg:
          enabled: $CNPG_ENABLED
  destination:
    server: https://kubernetes.default.svc
    namespace: $ARGOCD_NAMESPACE
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

echo
echo "Fertig. Argo CD installiert jetzt die fehlenden Komponenten und Toni."
echo "  Argo CD selbst verwalten:   $ARGOCD_SELF_MANAGED"
echo "  Traefik installieren:       $TRAEFIK_ENABLED"
echo "  cert-manager installieren:  $CERT_MANAGER_ENABLED"
echo "  CloudNativePG installieren: $CNPG_ENABLED"
echo
echo "Status:   kubectl -n $ARGOCD_NAMESPACE get applications"
if [ "$ARGOCD_SELF_MANAGED" = true ]; then
  echo "Argo-UI:  kubectl -n $ARGOCD_NAMESPACE port-forward svc/argocd-server 8080:443  →  https://localhost:8080"
  echo "Argo-Login: admin / \$(kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
fi
if [ "${GENERATED_PASSWORD:-}" = 1 ]; then
  echo "Toni-Login: $ADMIN_USERNAME / $ADMIN_PASSWORD   (bitte nach dem ersten Login im Profil ändern)"
fi
