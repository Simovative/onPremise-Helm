{{/*
One env var taken from a Secret. Renders nothing when no Secret is named.

No `optional: true` on purpose: a missing Secret must stop the Pod instead of letting it start
without a password and fail confusingly later.

Expects a dict: envName, secretName, secretKey, field.
*/}}
{{- define "casChart.secretEnvVar" -}}
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
{{- define "casChart.externalSecretEnv" -}}
{{- $s := .Values.secret -}}
{{- include "casChart.secretEnvVar" (dict "envName" "REDIS_SESSION_AUTH" "field" "redis_session_auth" "secretName" $s.redis_session_auth_secret_name "secretKey" $s.redis_session_auth_secret_key) }}
{{- include "casChart.secretEnvVar" (dict "envName" "REDIS_CACHE_AUTH" "field" "redis_cache_auth" "secretName" $s.redis_cache_auth_secret_name "secretKey" $s.redis_cache_auth_secret_key) }}
{{- /* The entrypoint only writes CA_CERT_VALUE to disk when CA_CERT_FILE is set. */ -}}
{{- if and $s.ca_cert_value_secret_name (not .Values.global.ca_cert_file) }}{{ fail "ca_cert_value_secret_name is set but global.ca_cert_file is empty - the container would ignore the certificate" }}{{ end }}
{{- include "casChart.secretEnvVar" (dict "envName" "CA_CERT_VALUE" "field" "ca_cert_value" "secretName" $s.ca_cert_value_secret_name "secretKey" $s.ca_cert_value_secret_key) }}
{{- include "casChart.secretEnvVar" (dict "envName" "CAS_FILESTORAGE_ENDPOINT_URL" "field" "filestorage_endpoint_url" "secretName" $s.filestorage_endpoint_url_secret_name "secretKey" $s.filestorage_endpoint_url_secret_key) }}
{{- end }}
