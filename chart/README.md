# Wazuh Agent Helm Chart

A Helm chart for deploying Wazuh agents on Kubernetes as a DaemonSet.

## Description

This chart deploys Wazuh security agents across all nodes in your Kubernetes cluster. Each agent connects to your Wazuh manager for centralized security monitoring, intrusion detection, vulnerability assessment, and log analysis.

The chart uses a DaemonSet to ensure every node (including control-plane nodes) runs a Wazuh agent, providing comprehensive visibility into your cluster's security posture.

## Prerequisites

- Kubernetes 1.20+
- Helm 3.0+
- A running Wazuh manager

## Installation

### Install from OCI Registry

```bash
helm install wazuh-agent oci://ghcr.io/maximewewer/charts/wazuh-agent \
  --namespace wazuh \
  --create-namespace \
  --set manager.address=<WAZUH_MANAGER_IP> \
  --set registration.password=<REGISTRATION_PASSWORD>
```

### Install from Source

```bash
git clone https://github.com/maximewewer/wazuh-agent-helm.git
cd wazuh-agent-helm

helm install wazuh-agent ./chart \
  --namespace wazuh \
  --create-namespace \
  --set manager.address=<WAZUH_MANAGER_IP> \
  --set registration.password=<REGISTRATION_PASSWORD>
```

## Configuration

### Required Parameters

| Parameter               | Description                                                        |
| ----------------------- | ------------------------------------------------------------------ |
| `manager.address`       | Wazuh manager IP address or hostname                               |
| `registration.password` | Agent registration password (or use `registration.existingSecret`) |

### Manager Configuration

| Parameter          | Description                      | Default |
| ------------------ | -------------------------------- | ------- |
| `manager.address`  | Wazuh manager IP/hostname        | `""`    |
| `manager.port`     | Manager communication port       | `1514`  |
| `manager.protocol` | Communication protocol (tcp/udp) | `tcp`   |

### Registration Configuration

| Parameter                        | Description                                       | Default |
| -------------------------------- | ------------------------------------------------- | ------- |
| `registration.server`            | Registration server (defaults to manager.address) | `""`    |
| `registration.port`              | Registration port                                 | `1515`  |
| `registration.password`          | Registration password                             | `""`    |
| `registration.existingSecret`    | Use existing secret for authd.pass                | `""`    |
| `registration.existingSecretKey` | Key in existing secret                            | `""`    |

### Agent Configuration

| Parameter                   | Description                                             | Default                           |
| --------------------------- | ------------------------------------------------------- | --------------------------------- |
| `agentNamePrefix`           | Prefix for agent name (combined with node name)         | `k8s`                             |
| `localInternalOptions`      | Base content for local_internal_options.conf            | `wazuh_command.remote_commands=1` |
| `extraOssecConf`            | Additional ossec.conf entries (raw XML)                 | `""`                              |
| `extraLocalInternalOptions` | Additional local_internal_options.conf entries          | `""`                              |
| `activeResponseScripts`     | Custom active response scripts (map of name -> content) | `{}`                              |

### Image Configuration

| Parameter              | Description                  | Default             |
| ---------------------- | ---------------------------- | ------------------- |
| `image.repository`     | Wazuh agent image repository | `wazuh/wazuh-agent` |
| `image.tag`            | Image tag                    | `4.14.2`            |
| `image.pullPolicy`     | Image pull policy            | `IfNotPresent`      |
| `initImage.repository` | Init container image         | `busybox`           |
| `initImage.tag`        | Init container image tag     | `1.37`              |
| `imagePullSecrets`     | Image pull secrets           | `[]`                |

### Resources and Scheduling

| Parameter                   | Description         | Default                   |
| --------------------------- | ------------------- | ------------------------- |
| `resources.limits.cpu`      | CPU limit           | `200m`                    |
| `resources.limits.memory`   | Memory limit        | `256Mi`                   |
| `resources.requests.cpu`    | CPU request         | `100m`                    |
| `resources.requests.memory` | Memory request      | `128Mi`                   |
| `nodeSelector`              | Node selector       | `{}`                      |
| `tolerations`               | Pod tolerations     | Control-plane tolerations |
| `affinity`                  | Pod affinity rules  | `{}`                      |
| `priorityClassName`         | Priority class name | `""`                      |

### Pod Configuration

| Parameter                                     | Description                   | Default         |
| --------------------------------------------- | ----------------------------- | --------------- |
| `podLabels`                                   | Additional pod labels         | `{}`            |
| `podAnnotations`                              | Additional pod annotations    | `{}`            |
| `terminationGracePeriodSeconds`               | Termination grace period      | `20`            |
| `updateStrategy.type`                         | DaemonSet update strategy     | `RollingUpdate` |
| `updateStrategy.rollingUpdate.maxUnavailable` | Max unavailable during update | `1`             |

### Security Context

| Parameter                                  | Description                  | Default                |
| ------------------------------------------ | ---------------------------- | ---------------------- |
| `podSecurityContext.fsGroup`               | Pod security context fsGroup | `999`                  |
| `podSecurityContext.fsGroupChangePolicy`   | fsGroup change policy        | `OnRootMismatch`       |
| `securityContext.runAsUser`                | Container runAsUser          | `0`                    |
| `securityContext.runAsGroup`               | Container runAsGroup         | `0`                    |
| `securityContext.allowPrivilegeEscalation` | Allow privilege escalation   | `true`                 |
| `securityContext.capabilities.add`         | Added capabilities           | `["SETGID", "SETUID"]` |

### RBAC and ServiceAccount

| Parameter                    | Description                 | Default |
| ---------------------------- | --------------------------- | ------- |
| `serviceAccount.create`      | Create service account      | `true`  |
| `serviceAccount.name`        | Service account name        | `""`    |
| `serviceAccount.annotations` | Service account annotations | `{}`    |
| `rbac.create`                | Create RBAC resources       | `true`  |

### Persistence

Each Wazuh data directory can be configured independently with its own volume type. Binaries (`bin`, `lib`, `ruleset`, `wodles`) come from the image and don't need persistence.

Supported volume types: `hostPath`, `emptyDir`, `pvc`

| Parameter                                  | Description                            | Default                                |
| ------------------------------------------ | -------------------------------------- | -------------------------------------- |
| `persistence.etc.enabled`                  | Enable persistence for /var/ossec/etc  | `true`                                 |
| `persistence.etc.type`                     | Volume type                            | `hostPath`                             |
| `persistence.etc.hostPath.path`            | Host path                              | `/var/lib/wazuh-agent/etc`             |
| `persistence.logs.enabled`                 | Enable persistence for logs            | `true`                                 |
| `persistence.logs.type`                    | Volume type                            | `hostPath`                             |
| `persistence.logs.hostPath.path`           | Host path                              | `/var/lib/wazuh-agent/logs`            |
| `persistence.queue.enabled`                | Enable persistence for queue           | `false`                                |
| `persistence.var.enabled`                  | Enable persistence for var             | `false`                                |
| `persistence.activeResponse.enabled`       | Enable persistence for active-response | `false`                                |

### Extra Volumes

For mounting additional host paths (e.g., host logs to monitor):

| Parameter           | Description                        | Default |
| ------------------- | ---------------------------------- | ------- |
| `extraVolumeMounts` | Additional volume mounts for agent | `[]`    |
| `extraVolumes`      | Additional volume definitions      | `[]`    |

### Optional Features

| Parameter                          | Description                | Default |
| ---------------------------------- | -------------------------- | ------- |
| `podDisruptionBudget.enabled`      | Enable PodDisruptionBudget | `false` |
| `podDisruptionBudget.minAvailable` | Minimum available pods     | `1`     |
| `networkPolicy.enabled`            | Enable NetworkPolicy       | `false` |
| `networkPolicy.extraEgress`        | Additional egress rules    | `[]`    |

## Examples

### Basic Deployment

```yaml
manager:
  address: "192.168.1.100"

registration:
  password: "my-secure-password"
```

### Using an Existing Secret

```bash
# Create secret
kubectl create secret generic wazuh-authd \
  --namespace wazuh \
  --from-literal=authd.pass='my-secure-password'

# Install with existing secret
helm install wazuh-agent ./chart \
  --namespace wazuh \
  --set manager.address=192.168.1.100 \
  --set registration.existingSecret=wazuh-authd
```

### Monitoring Host Logs

```yaml
manager:
  address: "192.168.1.100"

registration:
  password: "my-secure-password"

extraVolumeMounts:
  - name: host-logs
    mountPath: /host/var/log
    readOnly: true

extraVolumes:
  - name: host-logs
    hostPath:
      path: /var/log
      type: Directory

extraOssecConf: |
  <localfile>
    <log_format>syslog</log_format>
    <location>/host/var/log/syslog</location>
  </localfile>
  <localfile>
    <log_format>syslog</log_format>
    <location>/host/var/log/auth.log</location>
  </localfile>
```

### Custom Active Response Scripts

```yaml
manager:
  address: "192.168.1.100"

registration:
  password: "my-secure-password"

activeResponseScripts:
  log-hostname.sh: |
    #!/bin/bash
    echo "Hostname: $(hostname)" >> /var/ossec/logs/active-responses.log

  notify-slack.sh: |
    #!/bin/bash
    curl -X POST -H 'Content-type: application/json' \
      --data '{"text":"Alert from Wazuh agent"}' \
      https://hooks.slack.com/services/xxx
```

Scripts are automatically installed to `/var/ossec/active-response/bin/` with proper permissions (750, wazuh:wazuh).

### Kubernetes audit logs

See `examples/values-auditlog.yaml` for monitoring Kubernetes audit logs on control-plane nodes.

```bash
helm install wazuh-audit ./chart \
  --namespace wazuh \
  -f examples/values-auditlog.yaml \
  --set manager.address=192.168.1.100 \
  --set registration.password=my-secure-password
```

### Using PVC for persistence

```yaml
persistence:
  etc:
    enabled: true
    type: pvc
    pvc:
      storageClass: "standard"
      accessModes:
        - ReadWriteOnce
      size: 100Mi
  logs:
    enabled: true
    type: pvc
    pvc:
      storageClass: "standard"
      accessModes:
        - ReadWriteOnce
      size: 500Mi
```

## Architecture

The chart deploys the following resources:

| Resource            | Description                                             |
| ------------------- | ------------------------------------------------------- |
| DaemonSet           | Runs a Wazuh agent pod on each node                     |
| ConfigMap           | Contains `ossec.conf` and `local_internal_options.conf` |
| ConfigMap (scripts) | Contains custom active response scripts (if defined)    |
| Secret              | Stores the registration password (`authd.pass`)         |
| ServiceAccount      | Pod identity                                            |
| Role/RoleBinding    | RBAC permissions                                        |
| PodDisruptionBudget | High availability (optional)                            |
| NetworkPolicy       | Network security (optional)                             |

### Init Containers

The pod includes init containers that run in sequence:

1. `cleanup-stale-files` - Removes stale PID and lock files
2. `seed-ossec-tree` - Seeds the ossec directory structure on first run
3. `fix-permissions` - Sets correct ownership and permissions
4. `write-ossec-config` - Writes and customizes ossec.conf
5. `copy-local-options` - Copies local_internal_options.conf
6. `copy-authd-pass` - Copies the registration password
7. `copy-active-response-scripts` - Installs custom scripts (if defined)

## Upgrading

```bash
helm upgrade wazuh-agent ./chart \
  --namespace wazuh \
  -f my-values.yaml
```

## Uninstalling

```bash
helm uninstall wazuh-agent --namespace wazuh
```

> **Note:** The hostPath volume data at `/var/lib/wazuh-agent` is not deleted automatically.

## Troubleshooting

### Check pod status

```bash
kubectl get pods -n wazuh -l app.kubernetes.io/name=wazuh-agent
```

### View agent logs

```bash
kubectl logs -n wazuh -l app.kubernetes.io/name=wazuh-agent -c wazuh-agent --tail=50
```

### Check agent status

```bash
kubectl exec -n wazuh -it <pod-name> -c wazuh-agent -- /var/ossec/bin/ossec-control status
```

### View ossec.conf

```bash
kubectl exec -n wazuh -it <pod-name> -c wazuh-agent -- cat /var/ossec/etc/ossec.conf
```

### List active response scripts

```bash
kubectl exec -n wazuh -it <pod-name> -c wazuh-agent -- ls -la /var/ossec/active-response/bin/
```

### Common Issues

| Issue                  | Solution                                                         |
| ---------------------- | ---------------------------------------------------------------- |
| Agent not connecting   | Verify `manager.address` is correct and reachable                |
| Registration failed    | Check registration password and port (1515)                      |
| Volumes not persisted  | Check `persistence.*` configuration and host paths               |
| Scripts not executable | Scripts from `activeResponseScripts` get 750 permissions automatically |
