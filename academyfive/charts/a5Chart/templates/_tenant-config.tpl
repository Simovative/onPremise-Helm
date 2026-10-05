{{- define "a5Chart.infrastructureConfigSecretName" -}}academy-infrastructure-config-dir{{- end }}
{{- define "a5Chart.migrationConfigSecretName" -}}migration-tenant-config{{- end }}

{{/*
The infrastructure config, keyed by global.domain. On-premise runs a single tenant;
global.olddomain adds a second key for the same installation under its previous hostname.
Shared by the runtime Secret and the migration-job hook copy.

The four credential-bearing fields are resolved once here, not per document, so a two-document
render still costs four lookups instead of eight.
*/}}
{{- define "a5Chart.tenantConfig" -}}
{{- $i := .Values.infrastructureData -}}
{{- $resolved := dict
  "dbRead" (include "a5Chart.secretOrValue" (dict "ctx" . "field" "database_read_location" "secretName" $i.database_read_location_secret_name "secretKey" $i.database_read_location_secret_key "plain" $i.database_read_location))
  "dbWrite" (include "a5Chart.secretOrValue" (dict "ctx" . "field" "database_write_location" "secretName" $i.database_write_location_secret_name "secretKey" $i.database_write_location_secret_key "plain" $i.database_write_location))
  "cacheAuth" (include "a5Chart.secretOrValue" (dict "ctx" . "field" "cache_auth" "secretName" $i.cache_auth_secret_name "secretKey" $i.cache_auth_secret_key "plain" .Values.envData.REDIS_CACHE.AUTH))
  "endpointUrl" (include "a5Chart.secretOrValue" (dict "ctx" . "field" "filestorage_endpoint_url" "secretName" $i.filestorage_endpoint_url_secret_name "secretKey" $i.filestorage_endpoint_url_secret_key "plain" .Values.envData.A5_FILESTORAGE_ENDPOINT_URL))
-}}
{{ include "a5Chart.tenantConfigDocument" (dict "ctx" . "domain" .Values.global.domain "tenantId" (.Values.global.tenant_id | default .Values.global.domain) "r" $resolved) }}
{{- if .Values.global.olddomain }}
{{ include "a5Chart.tenantConfigDocument" (dict "ctx" . "domain" .Values.global.olddomain "tenantId" .Values.global.olddomain "r" $resolved) }}
{{- end }}
{{- end }}

{{/*
One config document, keyed by hostname. Expects a dict: ctx, domain, tenantId, r (the resolved
credential fields from a5Chart.tenantConfig).
*/}}
{{- define "a5Chart.tenantConfigDocument" -}}
{{- $r := .r -}}
{{ .domain }}: |
  {
  "Url": {{ quote .domain }},
  "tenant_id": {{ quote .tenantId }},
  "database_type": {{ quote .ctx.Values.infrastructureData.database_type }},
  "database_location": {{ quote $r.dbWrite }},
  "database_read_location": {{ quote $r.dbRead }},
  "database_write_location": {{ quote $r.dbWrite }},
  "filestorage_type": {{ quote .ctx.Values.infrastructureData.file_storage_type }},
  {{- if not (eq .ctx.Values.infrastructureData.a5_file_storage_location "") }}
  "filestorage_location": {{ quote .ctx.Values.infrastructureData.a5_file_storage_location }},
  {{- else }}
  "filestorage_location": "s3://{{.ctx.Values.envData.A5_BUCKET_NAME}}",
  {{- end }}
  {{- if not (eq $r.endpointUrl "")}}
  "filestorage_endpoint_url": {{ quote $r.endpointUrl }},
  {{- end }}
  "oas_a5_domain": {{ quote .ctx.Values.infrastructureData.oas_a5_domain }},
  "services_domain": {{ quote .ctx.Values.infrastructureData.services_domain }},
  "pdf_service_url": {{ quote .ctx.Values.infrastructureData.pdf_service_url }},
  "session_type": {{ quote .ctx.Values.infrastructureData.session_type }},
  "session_location": {{ quote .ctx.Values.envData.REDIS_SESSION.ENDPOINT }},
  "session_cluster": {{ .ctx.Values.envData.REDIS_SESSION.IS_CLUSTER | quote }},
  "cache_type": {{ quote .ctx.Values.infrastructureData.cache_type}},
  "cache_location": {
    "clusterType": {{ .ctx.Values.envData.REDIS_CACHE.IS_CLUSTER | quote }},
    "url":  {{ quote .ctx.Values.envData.REDIS_CACHE.ENDPOINT }}
    {{- if not (eq $r.cacheAuth "no_auth" ) }}
      ,"auth": {{ quote $r.cacheAuth }}
    {{- end }}
  },
  "maintenance_mode": {{ .ctx.Values.infrastructureData.maintenance_mode }},
  "aws_region": {{ quote .ctx.Values.infrastructureData.aws_region}}
  }
{{- end }}
