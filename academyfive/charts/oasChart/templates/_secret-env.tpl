{{/*
One env var taken from a Secret. Renders nothing when no Secret is named.

No `optional: true` on purpose: a missing Secret must stop the Pod instead of letting it start
without a password and fail confusingly later.

Expects a dict: envName, secretName, secretKey, field.
*/}}
{{- define "oasChart.secretEnvVar" -}}
{{- if .secretName -}}
{{- if not .secretKey }}{{ fail (printf "%s_secret_name is set to %q but %s_secret_key is empty" .field .secretName .field) }}{{ end }}
- name: {{ .envName }}
  valueFrom:
    secretKeyRef:
      name: {{ .secretName }}
      key: {{ .secretKey }}
{{- end -}}
{{- end }}

{{/*
Credentials taken from Secrets created outside this chart. Empty unless configured.
*/}}
{{- define "oasChart.externalSecretEnv" -}}
{{- $s := .Values.secret -}}
{{- include "oasChart.secretEnvVar" (dict "envName" "OAS_S3_ENDPOINT_URL" "field" "s3_endpoint_url" "secretName" $s.s3_endpoint_url_secret_name "secretKey" $s.s3_endpoint_url_secret_key) }}
{{- end }}
