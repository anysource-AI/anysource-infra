{{/*
Expand the name of the chart.
*/}}
{{- define "anysource.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "anysource.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "anysource.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "anysource.labels" -}}
helm.sh/chart: {{ include "anysource.chart" . }}
{{ include "anysource.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
environment: {{ .Values.global.environment }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "anysource.selectorLabels" -}}
app.kubernetes.io/name: {{ include "anysource.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Backend labels
*/}}
{{- define "anysource.backend.labels" -}}
{{ include "anysource.labels" . }}
app.kubernetes.io/component: backend
{{- end }}

{{/*
Backend selector labels
*/}}
{{- define "anysource.backend.selectorLabels" -}}
{{ include "anysource.selectorLabels" . }}
app.kubernetes.io/component: backend
{{- end }}

{{/*
Frontend labels
*/}}
{{- define "anysource.frontend.labels" -}}
{{ include "anysource.labels" . }}
app.kubernetes.io/component: frontend
{{- end }}

{{/*
Frontend selector labels
*/}}
{{- define "anysource.frontend.selectorLabels" -}}
{{ include "anysource.selectorLabels" . }}
app.kubernetes.io/component: frontend
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "anysource.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "anysource.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Database connection string
*/}}
{{- define "anysource.database.host" -}}
{{- if .Values.externalDatabase.enabled }}
{{- .Values.externalDatabase.host }}
{{- else if .Values.postgresql.enabled }}
{{- $pgName := default "postgresql" .Values.postgresql.fullnameOverride -}}
{{- if eq (default "standalone" .Values.postgresql.architecture) "replication" -}}
{{- printf "%s-primary" $pgName -}}
{{- else -}}
{{- printf "%s" $pgName -}}
{{- end -}}
{{- end }}
{{- end }}

{{/*
Database port
*/}}
{{- define "anysource.database.port" -}}
{{- if .Values.externalDatabase.enabled }}
{{- .Values.externalDatabase.port }}
{{- else if .Values.postgresql.enabled }}
{{- "5432" }}
{{- end }}
{{- end }}

{{/*
Database name
*/}}
{{- define "anysource.database.name" -}}
{{- if .Values.externalDatabase.enabled }}
{{- .Values.externalDatabase.database }}
{{- else if .Values.postgresql.enabled }}
{{- .Values.postgresql.auth.database }}
{{- end }}
{{- end }}

{{/*
Database username
*/}}
{{- define "anysource.database.username" -}}
{{- if .Values.externalDatabase.enabled }}
{{- .Values.externalDatabase.username }}
{{- else if .Values.postgresql.enabled }}
{{- .Values.postgresql.auth.username }}
{{- end }}
{{- end }}

{{/*
Redis host
*/}}
{{- define "anysource.redis.host" -}}
{{- if .Values.externalRedis.enabled }}
{{- .Values.externalRedis.host }}
{{- else if .Values.redis.enabled }}
{{- printf "redis-master" }}
{{- end }}
{{- end }}

{{/*
Redis port
*/}}
{{- define "anysource.redis.port" -}}
{{- if .Values.externalRedis.enabled }}
{{- .Values.externalRedis.port }}
{{- else if .Values.redis.enabled }}
{{- "6379" }}
{{- end }}
{{- end }}

{{/*
Redis URL
*/}}
{{- define "anysource.redis.url" -}}
{{- if .Values.externalRedis.enabled -}}
{{- if .Values.externalRedis.password -}}
{{- printf "redis://:%s@%s:%s/0" .Values.externalRedis.password (include "anysource.redis.host" .) (include "anysource.redis.port" .) -}}
{{- else -}}
{{- printf "redis://%s:%s/0" (include "anysource.redis.host" .) (include "anysource.redis.port" .) -}}
{{- end -}}
{{- else if .Values.redis.enabled -}}
{{- if .Values.redis.auth.enabled -}}
{{- printf "redis://:%s@%s:%s/0" .Values.redis.auth.password (include "anysource.redis.host" .) (include "anysource.redis.port" .) -}}
{{- else -}}
{{- printf "redis://%s:%s/0" (include "anysource.redis.host" .) (include "anysource.redis.port" .) -}}
{{- end -}}
{{- end -}}
{{- end }}
