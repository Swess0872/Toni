{{- define "toni.labels" -}}
app.kubernetes.io/part-of: toni
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "toni.pullSecrets" -}}
{{- with .Values.image.pullSecret }}
imagePullSecrets:
  - name: {{ . }}
{{- end }}
{{- end }}
