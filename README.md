# Service Deployment Helm Chart

A production-ready Helm chart for deploying microservices to Kubernetes, following the 12-factor app methodology and best practices.

## Features

- **Production-Ready Configuration**
  - Configurable resource limits and requests
  - Security context settings
  - Graceful shutdown handling
  - Health checks (liveness, readiness, startup probes)

- **High Availability**
  - Horizontal Pod Autoscaling (HPA)
  - Pod Disruption Budget (PDB)
  - Rolling update strategy
  - Configurable replicas

- **Networking**
  - Ingress configuration with Traefik
  - Network policies
  - Service configuration
  - TLS support

- **Observability**
  - Prometheus metrics integration
  - ServiceMonitor for metrics collection
  - Configurable logging
  - Log aggregation support (Elasticsearch)

- **Security**
  - Non-root container execution
  - Read-only root filesystem
  - Network policies
  - Configurable security contexts

- **Configuration Management**
  - Environment variables
  - ConfigMaps
  - Secrets management
  - External configuration support

## Prerequisites

- Kubernetes 1.21+
- Helm 3.0+
- Prometheus Operator (for metrics)
- Traefik Ingress Controller
- Elasticsearch (optional, for log aggregation)

## Installation

```bash
# Add the repository
helm repo add file-convert https://file-convert.github.io/helm-charts

# Update the repository
helm repo update

# Install the chart
helm install my-service file-convert/service-deployment-helm-chart \
  --namespace my-namespace \
  --create-namespace \
  --values values.yaml
```

## Configuration

The following table lists the configurable parameters of the chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `app.name` | Application name | `example-service` |
| `app.version` | Application version | `v1` |
| `app.port` | Application port | `8080` |
| `container.image.repository` | Container image repository | `file-convert/app` |
| `container.image.tag` | Container image tag | `latest` |
| `container.resources` | Container resource requests and limits | See values.yaml |
| `deployment.replicas` | Number of replicas | `1` |
| `ingress.enabled` | Enable ingress | `true` |
| `metrics.enabled` | Enable metrics | `true` |
| `logging.enabled` | Enable logging | `true` |
| `logging.aggregation.enabled` | Enable log aggregation | `true` |

For more configuration options, please refer to the [values.yaml](chart/values.yaml) file.

## Usage

### Basic Deployment

```yaml
# values.yaml
app:
  name: my-service
  version: v1.0.0
  port: 8080

container:
  image:
    repository: my-registry/my-service
    tag: latest

deployment:
  replicas: 2
```

### With Metrics and Logging

```yaml
# values.yaml
metrics:
  enabled: true
  port: 9090
  path: /metrics

logging:
  enabled: true
  format: json
  level: info
  aggregation:
    enabled: true
    type: elasticsearch
```

### With Ingress

```yaml
# values.yaml
ingress:
  enabled: true
  entryPoints:
    - web
    - websecure
  routes:
    - match: Host(`example.com`) && PathPrefix(`/api`)
      services:
        - name: my-service
          port: 80
  tls:
    enabled: true
    secretName: example-tls
```

## Best Practices

This Helm chart implements several best practices:

1. **12-Factor App Methodology**
   - Configuration via environment variables
   - Stateless processes
   - Logs as event streams
   - Port binding
   - Concurrency
   - Disposability

2. **Security**
   - Non-root containers
   - Network policies
   - Security contexts
   - TLS support

3. **Observability**
   - Health checks
   - Metrics
   - Logging
   - Tracing support

4. **High Availability**
   - HPA
   - PDB
   - Rolling updates
   - Resource management

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
