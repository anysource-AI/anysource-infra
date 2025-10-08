# anysource

![Version: 0.3.0](https://img.shields.io/badge/Version-0.3.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.3.0](https://img.shields.io/badge/AppVersion-0.3.0-informational?style=flat-square)

Anysource application Helm chart for Kubernetes deployment

**Homepage:** <https://github.com/anysource-AI/Anysource>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| Anysource Team | <team@anysource.dev> |  |

## Source Code

* <https://github.com/anysource-AI/Anysource>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://charts.bitnami.com/bitnami | postgresql | 16.7.20 |
| https://charts.bitnami.com/bitnami | redis | 21.2.12 |
| https://charts.jetstack.io | cert-manager | 1.18.2 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| awsCertificate.arn | string | `""` |  |
| awsCertificate.enabled | bool | `false` |  |
| backend.env.AWS_REGION | string | `"us-east-1"` |  |
| backend.env.DB_MAX_OVERFLOW | string | `"50"` |  |
| backend.env.DB_POOL_PRE_PING | string | `"true"` |  |
| backend.env.DB_POOL_RECYCLE | string | `"3600"` |  |
| backend.env.DB_POOL_SIZE | string | `"50"` |  |
| backend.env.DB_POOL_TIMEOUT | string | `"30"` |  |
| backend.env.HOST | string | `"0.0.0.0"` |  |
| backend.env.PORT | string | `"8000"` |  |
| backend.env.TOKENIZERS_PARALLELISM | string | `"true"` |  |
| backend.livenessProbe.failureThreshold | int | `3` |  |
| backend.livenessProbe.httpGet.path | string | `"/api/v1/utils/health-check/"` |  |
| backend.livenessProbe.httpGet.port | int | `8000` |  |
| backend.livenessProbe.initialDelaySeconds | int | `60` |  |
| backend.livenessProbe.periodSeconds | int | `30` |  |
| backend.livenessProbe.timeoutSeconds | int | `10` |  |
| backend.name | string | `"backend"` |  |
| backend.port | int | `8000` |  |
| backend.readinessProbe.failureThreshold | int | `3` |  |
| backend.readinessProbe.httpGet.path | string | `"/api/v1/utils/health-check/"` |  |
| backend.readinessProbe.httpGet.port | int | `8000` |  |
| backend.readinessProbe.initialDelaySeconds | int | `30` |  |
| backend.readinessProbe.periodSeconds | int | `10` |  |
| backend.readinessProbe.timeoutSeconds | int | `5` |  |
| backend.replicas | int | `2` |  |
| backend.resources.limits.cpu | string | `"4000m"` |  |
| backend.resources.limits.memory | string | `"8192Mi"` |  |
| backend.resources.requests.cpu | string | `"4000m"` |  |
| backend.resources.requests.memory | string | `"8192Mi"` |  |
| backend.secrets.AUTH_API_KEY | string | `"sk_live_your_auth_api_key_here"` |  |
| backend.secrets.MASTER_SALT | string | `"your-master-salt-here-change-in-production"` |  |
| backend.secrets.SECRET_KEY | string | `"your-secret-key-here-change-in-production"` |  |
| certManager.enabled | bool | `false` |  |
| certManager.issuer.email | string | `"your-email@example.com"` |  |
| certManager.issuer.name | string | `"letsencrypt-prod"` |  |
| certManager.issuer.server | string | `"https://acme-v02.api.letsencrypt.org/directory"` |  |
| directorySync.enabled | bool | `true` |  |
| directorySync.resources.limits.cpu | string | `"1000m"` |  |
| directorySync.resources.limits.memory | string | `"2048Mi"` |  |
| directorySync.resources.requests.cpu | string | `"1000m"` |  |
| directorySync.resources.requests.memory | string | `"2048Mi"` |  |
| externalDatabase.database | string | `"postgres"` |  |
| externalDatabase.enabled | bool | `false` |  |
| externalDatabase.existingSecret | string | `""` |  |
| externalDatabase.existingSecretPasswordKey | string | `"password"` |  |
| externalDatabase.host | string | `""` |  |
| externalDatabase.password | string | `""` |  |
| externalDatabase.port | int | `5432` |  |
| externalDatabase.type | string | `"postgresql"` |  |
| externalDatabase.username | string | `"postgres"` |  |
| externalRedis.enabled | bool | `false` |  |
| externalRedis.existingSecret | string | `""` |  |
| externalRedis.existingSecretPasswordKey | string | `"password"` |  |
| externalRedis.host | string | `""` |  |
| externalRedis.password | string | `""` |  |
| externalRedis.port | int | `6379` |  |
| frontend.livenessProbe.failureThreshold | int | `3` |  |
| frontend.livenessProbe.httpGet.path | string | `"/"` |  |
| frontend.livenessProbe.httpGet.port | int | `80` |  |
| frontend.livenessProbe.initialDelaySeconds | int | `30` |  |
| frontend.livenessProbe.periodSeconds | int | `30` |  |
| frontend.livenessProbe.timeoutSeconds | int | `10` |  |
| frontend.name | string | `"frontend"` |  |
| frontend.port | int | `80` |  |
| frontend.readinessProbe.failureThreshold | int | `3` |  |
| frontend.readinessProbe.httpGet.path | string | `"/"` |  |
| frontend.readinessProbe.httpGet.port | int | `80` |  |
| frontend.readinessProbe.initialDelaySeconds | int | `10` |  |
| frontend.readinessProbe.periodSeconds | int | `10` |  |
| frontend.readinessProbe.timeoutSeconds | int | `5` |  |
| frontend.replicas | int | `2` |  |
| frontend.resources.limits.cpu | string | `"1000m"` |  |
| frontend.resources.limits.memory | string | `"2048Mi"` |  |
| frontend.resources.requests.cpu | string | `"1000m"` |  |
| frontend.resources.requests.memory | string | `"2048Mi"` |  |
| fullnameOverride | string | `""` |  |
| global.auth_client_id | string | `"your-auth-client-id"` |  |
| global.domain | string | `"mcp.example.com"` |  |
| global.environment | string | `"production"` |  |
| hpa.backend.enabled | bool | `true` |  |
| hpa.backend.maxReplicas | int | `20` |  |
| hpa.backend.minReplicas | int | `3` |  |
| hpa.backend.targetCPUUtilizationPercentage | int | `70` |  |
| hpa.backend.targetMemoryUtilizationPercentage | int | `80` |  |
| hpa.frontend.enabled | bool | `true` |  |
| hpa.frontend.maxReplicas | int | `20` |  |
| hpa.frontend.minReplicas | int | `3` |  |
| hpa.frontend.targetCPUUtilizationPercentage | int | `70` |  |
| hpa.frontend.targetMemoryUtilizationPercentage | int | `80` |  |
| image.backend.pullPolicy | string | `"Always"` |  |
| image.backend.pullSecrets | list | `[]` |  |
| image.backend.repository | string | `"public.ecr.aws/anysource/anysource-api"` |  |
| image.backend.tag | string | `"latest"` |  |
| image.frontend.pullPolicy | string | `"Always"` |  |
| image.frontend.pullSecrets | list | `[]` |  |
| image.frontend.repository | string | `"public.ecr.aws/anysource/anysource-web"` |  |
| image.frontend.tag | string | `"latest"` |  |
| ingress.annotations."alb.ingress.kubernetes.io/listen-ports" | string | `"[{\"HTTP\": 80}, {\"HTTPS\": 443}]"` |  |
| ingress.annotations."alb.ingress.kubernetes.io/scheme" | string | `"internet-facing"` |  |
| ingress.annotations."alb.ingress.kubernetes.io/ssl-policy" | string | `"ELBSecurityPolicy-TLS-1-2-2017-01"` |  |
| ingress.annotations."alb.ingress.kubernetes.io/target-type" | string | `"ip"` |  |
| ingress.annotations."kubernetes.io/ingress.class" | string | `"alb"` |  |
| ingress.className | string | `"alb"` |  |
| ingress.enabled | bool | `true` |  |
| ingress.forceHttps | bool | `false` |  |
| ingress.tls.enabled | bool | `true` |  |
| ingress.tls.secretName | string | `"anysource-tls"` |  |
| nameOverride | string | `""` |  |
| networkPolicy.enabled | bool | `false` |  |
| networkPolicy.vpcCidr | string | `""` |  |
| nodeSelector | object | `{}` |  |
| podAnnotations."prometheus.io/path" | string | `"/metrics"` |  |
| podAnnotations."prometheus.io/port" | string | `"8000"` |  |
| podAnnotations."prometheus.io/scrape" | string | `"true"` |  |
| podSecurityContext.fsGroup | int | `1000` |  |
| podSecurityContext.seccompProfile.type | string | `"RuntimeDefault"` |  |
| postgresql.architecture | string | `"replication"` |  |
| postgresql.auth.database | string | `"postgres"` |  |
| postgresql.auth.password | string | `"postgres123"` |  |
| postgresql.auth.postgresPassword | string | `"postgres123"` |  |
| postgresql.auth.replicationPassword | string | `"replication123"` |  |
| postgresql.auth.username | string | `"postgres"` |  |
| postgresql.enabled | bool | `true` |  |
| postgresql.fullnameOverride | string | `"postgresql"` |  |
| postgresql.primary.persistence.enabled | bool | `true` |  |
| postgresql.primary.persistence.size | string | `"10Gi"` |  |
| postgresql.primary.persistence.storageClass | string | `"ebs-gp3"` |  |
| postgresql.primary.resources.limits.cpu | string | `"4000m"` |  |
| postgresql.primary.resources.limits.memory | string | `"8192Mi"` |  |
| postgresql.primary.resources.requests.cpu | string | `"4000m"` |  |
| postgresql.primary.resources.requests.memory | string | `"8192Mi"` |  |
| postgresql.readReplicas.persistence.enabled | bool | `true` |  |
| postgresql.readReplicas.persistence.size | string | `"10Gi"` |  |
| postgresql.readReplicas.persistence.storageClass | string | `"ebs-gp3"` |  |
| postgresql.readReplicas.replicaCount | int | `1` |  |
| postgresql.readReplicas.resources.limits.cpu | string | `"4000m"` |  |
| postgresql.readReplicas.resources.limits.memory | string | `"8192Mi"` |  |
| postgresql.readReplicas.resources.requests.cpu | string | `"4000m"` |  |
| postgresql.readReplicas.resources.requests.memory | string | `"8192Mi"` |  |
| prestart.args[0] | string | `"scripts/prestart.sh"` |  |
| prestart.command[0] | string | `"bash"` |  |
| prestart.enabled | bool | `true` |  |
| prestart.image.repository | string | `"public.ecr.aws/anysource/anysource-api"` |  |
| prestart.image.tag | string | `"latest"` |  |
| prestart.resources.limits.cpu | string | `"1000m"` |  |
| prestart.resources.limits.memory | string | `"2048Mi"` |  |
| prestart.resources.requests.cpu | string | `"1000m"` |  |
| prestart.resources.requests.memory | string | `"2048Mi"` |  |
| redis.auth.enabled | bool | `true` |  |
| redis.auth.password | string | `"redis123"` |  |
| redis.enabled | bool | `true` |  |
| redis.fullnameOverride | string | `"redis"` |  |
| redis.master.persistence.enabled | bool | `true` |  |
| redis.master.persistence.size | string | `"5Gi"` |  |
| redis.master.persistence.storageClass | string | `"ebs-gp3"` |  |
| redis.master.resources.limits.cpu | string | `"1000m"` |  |
| redis.master.resources.limits.memory | string | `"2048Mi"` |  |
| redis.master.resources.requests.cpu | string | `"1000m"` |  |
| redis.master.resources.requests.memory | string | `"2048Mi"` |  |
| redis.replica.persistence.storageClass | string | `"ebs-gp3"` |  |
| redis.replica.replicaCount | int | `1` |  |
| redis.replica.resources.limits.cpu | string | `"1000m"` |  |
| redis.replica.resources.limits.memory | string | `"2048Mi"` |  |
| redis.replica.resources.requests.cpu | string | `"1000m"` |  |
| redis.replica.resources.requests.memory | string | `"2048Mi"` |  |
| securityContext.readOnlyRootFilesystem | bool | `false` |  |
| securityContext.runAsGroup | int | `1000` |  |
| securityContext.runAsNonRoot | bool | `false` |  |
| securityContext.runAsUser | int | `0` |  |
| service.backend.port | int | `8000` |  |
| service.backend.targetPort | int | `8000` |  |
| service.backend.type | string | `"ClusterIP"` |  |
| service.frontend.port | int | `80` |  |
| service.frontend.targetPort | int | `80` |  |
| service.frontend.type | string | `"ClusterIP"` |  |
| serviceAccount.annotations."eks.amazonaws.com/role-arn" | string | `""` |  |
| storageClass.allowVolumeExpansion | bool | `true` |  |
| storageClass.enabled | bool | `true` |  |
| storageClass.isDefault | bool | `false` |  |
| storageClass.name | string | `"ebs-gp3"` |  |
| storageClass.parameters.additionalParameters | object | `{}` |  |
| storageClass.parameters.encrypted | string | `"true"` |  |
| storageClass.parameters.iops | string | `"3000"` |  |
| storageClass.parameters.kmsKeyId | string | `""` |  |
| storageClass.parameters.throughput | string | `"125"` |  |
| storageClass.parameters.type | string | `"gp3"` |  |
| storageClass.provisioner | string | `"ebs.csi.aws.com"` |  |
| storageClass.reclaimPolicy | string | `"Delete"` |  |
| storageClass.volumeBindingMode | string | `"WaitForFirstConsumer"` |  |
| tolerations | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
