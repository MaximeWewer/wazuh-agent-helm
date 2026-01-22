# Wazuh Agent Helm Chart

A Helm chart for deploying [Wazuh](https://wazuh.com) agents on Kubernetes as a DaemonSet.

## Overview

This Helm chart deploys Wazuh agents across all nodes in your Kubernetes cluster, enabling security monitoring, intrusion detection, and log analysis at the node level.

### Features

- **DaemonSet deployment** - Automatically deploys agents on all nodes (including control-plane)
- **Flexible configuration** - Customizable volumes, log monitoring, and agent settings
- **Security-focused** - RBAC, NetworkPolicy, and PodDisruptionBudget support
- **Easy registration** - Automatic agent registration with Wazuh manager

## Prerequisites

- Kubernetes 1.20+
- Helm 3.0+
- A running Wazuh manager

## Quick Start

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

## Documentation

For detailed configuration options, examples, and troubleshooting, see the [chart documentation](./chart/README.md).

## Examples

Example configurations are available in the [`chart/examples/`](./chart/examples/) directory:

- **[values-auditlog.yaml](./chart/examples/values-auditlog.yaml)** - Monitor Kubernetes audit logs on control-plane nodes

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Links

- [Wazuh Documentation](https://documentation.wazuh.com/)
- [Wazuh GitHub](https://github.com/wazuh/wazuh)
- [Wazuh Agent Docker Image](https://hub.docker.com/r/wazuh/wazuh-agent)
