{{- define "platform.syncPolicy" -}}
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
  retry:
    limit: 10
    backoff:
      duration: 15s
      factor: 2
      maxDuration: 5m
{{- end }}
