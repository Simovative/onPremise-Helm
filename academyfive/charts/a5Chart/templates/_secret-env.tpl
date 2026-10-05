{{/*
One env var taken from a Secret. Renders nothing when no Secret is named.

Expects a dict: envName, secretName, secretKey, field.
*/}}
{{- define "a5Chart.secretEnvVar" -}}
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
Env vars taken from Secrets that are created outside this chart.
Shared by the academy pod, the cron pod and the migration job.

The credential references below do not; see a5Chart.secretEnvVar.
*/}}
{{- define "a5Chart.externalSecretEnv" -}}
{{- $i := .Values.infrastructureData -}}
- name: A5_RABBITMQ_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ $i.rabbitmq_secret_name }}
      key: username
      optional: true
- name: A5_RABBITMQ_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $i.rabbitmq_secret_name }}
      key: password
      optional: true
- name: A5_RABBITMQ_N8N_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ $i.rabbitmq_n8n_secret_name }}
      key: username
      optional: true
- name: A5_RABBITMQ_N8N_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $i.rabbitmq_n8n_secret_name }}
      key: password
      optional: true
- name: N8N_OWNER_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ $i.n8n_owner_credentials_secret_name }}
      key: email
      optional: true
- name: N8N_OWNER_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ $i.n8n_owner_credentials_secret_name }}
      key: password
      optional: true
- name: N8N_OWNER_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ $i.n8n_owner_credentials_secret_name }}
      key: apiToken
      optional: true
- name: N8N_USER_MANAGEMENT_JWT_SECRET
  valueFrom:
    secretKeyRef:
      name: {{ $i.n8n_user_management_jwt_secret_name }}
      key: password
      optional: true
{{- include "a5Chart.secretEnvVar" (dict "envName" "REDIS_SESSION_AUTH" "field" "redis_session_auth" "secretName" $i.redis_session_auth_secret_name "secretKey" $i.redis_session_auth_secret_key) }}
{{- include "a5Chart.secretEnvVar" (dict "envName" "TIDEWAYS_API_KEY" "field" "tideways_api_key" "secretName" $i.tideways_api_key_secret_name "secretKey" $i.tideways_api_key_secret_key) }}
{{- /* The entrypoint only writes CA_CERT_VALUE to disk when CA_CERT_FILE is set. */ -}}
{{- if and $i.ca_cert_value_secret_name (not .Values.global.ca_cert_file) }}{{ fail "ca_cert_value_secret_name is set but global.ca_cert_file is empty - the container would ignore the certificate" }}{{ end }}
{{- include "a5Chart.secretEnvVar" (dict "envName" "CA_CERT_VALUE" "field" "ca_cert_value" "secretName" $i.ca_cert_value_secret_name "secretKey" $i.ca_cert_value_secret_key) }}
{{- include "a5Chart.secretEnvVar" (dict "envName" "AC5_FILESTORAGE_ENDPOINT_URL" "field" "filestorage_endpoint_url" "secretName" $i.filestorage_endpoint_url_secret_name "secretKey" $i.filestorage_endpoint_url_secret_key) }}
{{- end }}
