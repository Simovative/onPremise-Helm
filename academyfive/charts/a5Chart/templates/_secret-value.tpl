{{/*
Resolves one credential-bearing field of the infrastructure config document: either from a
Kubernetes Secret the customer points at, or from the plain value in values.yaml.

Expects a dict:
  ctx        root context, for .Release.Namespace
  field      the values.yaml key, used in error messages only
  secretName <field>_secret_name - empty means "no reference, take the plain value"
  secretKey  <field>_secret_key  - which key of that Secret holds the value
  plain      the value from values.yaml, also the fallback when the Secret cannot be read

Resolution order: Secret key, then plain value, then fail.
*/}}
{{- define "a5Chart.secretOrValue" -}}
{{- if not .secretName -}}

  {{- /* No reference configured: the value stays in values.yaml. */ -}}
  {{- .plain -}}

{{- else -}}

  {{- /* A name without a key cannot resolve - catch the typo instead of silently falling back. */ -}}
  {{- if not .secretKey -}}
    {{- fail (printf "%s_secret_name is set to %q but %s_secret_key is empty" .field .secretName .field) -}}
  {{- end -}}

  {{- /* Empty unless this is a real install/upgrade against a cluster, see above. */ -}}
  {{- $secret := (lookup "v1" "Secret" .ctx.Release.Namespace .secretName) -}}
  {{- $encoded := "" -}}
  {{- if $secret -}}
    {{- $encoded = (index ($secret.data | default dict) .secretKey | default "") -}}
  {{- end -}}

  {{- if $encoded -}}
    {{- $encoded | b64dec -}}
  {{- else if .plain -}}
    {{- .plain -}}
  {{- else -}}
    {{- fail (printf "%s: Secret %q has no key %q and no plain value is set" .field .secretName .secretKey) -}}
  {{- end -}}

{{- end -}}
{{- end -}}
