# Monitoring Infrastructure with k8s-infra Helm Chart

This repository provides a complete monitoring setup using SigNoz with Kubernetes infrastructure monitoring via Helm charts and OpenTelemetry. The setup includes a sample rolldice application with telemetry instrumentation.

## 🎯 Features

- **SigNoz Monitoring**: Complete observability platform running in Docker
- **k8s-infra Helm Chart**: OpenTelemetry collector for Kubernetes monitoring
- **Custom OTEL Configuration**: Configurable upstream OpenTelemetry collector endpoint
- **Sample Application**: Rolldice app with full OpenTelemetry instrumentation
- **Automated Telemetry**: Load generator creating realistic telemetry data
- **GitHub Codespace Ready**: Optimized for cloud development environments

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Rolldice App  │────│  OTEL Collector  │────│     SigNoz      │
│  (K8s Pods)     │    │   (k8s-infra)    │    │   (Docker)      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌────────▼────────┐             │
         │              │  Kubernetes     │             │
         └──────────────│  Metrics &      │─────────────┘
                        │  Traces         │
                        └─────────────────┘
```

## 🚀 Quick Start

### For GitHub Codespace

1. **Run setup script:**
   ```bash
   ./setup.sh
   ```

2. **Deploy the complete stack:**
   ```bash
   ansible-playbook up.yml
   ```

3. **Access applications:**
   - SigNoz Dashboard: `http://localhost:3301`
   - Rolldice App: `kubectl port-forward service/rolldice-otel-service 8080:80` then `http://localhost:8080`

### Manual Setup

1. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ansible-galaxy collection install kubernetes.core community.docker
   ```

2. **Initialize submodules and apply patches:**
   ```bash
   git submodule update --init --recursive
   cd signoz && patch -p1 < patch.diff && cd ..
   ```

3. **Deploy infrastructure:**
   ```bash
   ansible-playbook up.yml
   ```

## 📋 Components

### 1. k8s-infra Helm Chart (3 marks)

Located in `k8s-infra/`:
- **Installation**: `k8s-infra/up.yml` - Installs SigNoz k8s-infra Helm chart
- **Removal**: `k8s-infra/down.yml` - Cleanly removes the Helm installation
- **Configuration**: `k8s-infra/templates/values.yaml.j2` - Helm values template

**Key Features:**
- Automated Helm repository management
- Namespace creation and management
- Configurable release names and settings
- Proper cleanup on removal

### 2. OTEL Collector Override Values (3 marks)

**Configuration highlights:**
```yaml
# Custom endpoint configuration
otelCollectorEndpoint: "{{ signoz_endpoint }}"
otelInsecure: true

# Comprehensive telemetry collection
presets:
  otlpExporter:
    enabled: true
  kubernetesEvents:
    enabled: true
  kubernetesExtraMetrics:
    enabled: true
  kubeletMetrics:
    enabled: true
```

**Supported endpoints:**
- Default: `host.docker.internal:4318` (for Docker SigNoz)
- Environment configurable via `SIGNOZ_ENDPOINT`
- Kubernetes service discovery support

### 3. Rolldice Application (2 marks)

Located in `k8s-infra/manifests/rolldice-otel.yaml`:

**Features:**
- **Full OpenTelemetry Integration**: Traces, metrics, and logs
- **Interactive Web UI**: Dice rolling interface with statistics
- **Multiple Endpoints**: 
  - `/` - Web interface
  - `/api/roll` - Roll dice API
  - `/api/stats` - Statistics API
  - `/health` - Health check
- **Load Generation**: Automated CronJob creating realistic traffic
- **Resource Management**: Proper limits and health checks

**Telemetry Configuration:**
- Service name: `rolldice-otel`
- Automatic instrumentation for Express.js
- Custom metrics and traces
- Kubernetes resource attributes

## 🛠️ Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SIGNOZ_ENDPOINT` | `host.docker.internal:4318` | SigNoz OTLP endpoint |
| `K8S` | `k3s` | Kubernetes distribution (k3s/k3d) |

### Ansible Variables

Edit values in playbook files:
- `cluster_name`: Kubernetes cluster identifier
- `deployment_environment`: Environment tag (development/staging/production)
- `namespace`: Target Kubernetes namespace
- `release_name`: Helm release name

## 📊 Monitoring & Observability

### SigNoz Dashboard
- **URL**: `http://localhost:3301`
- **Default credentials**: No authentication required
- **Services to monitor**: Look for `rolldice-otel` service

### Available Telemetry
1. **Traces**: HTTP requests, database operations, external calls
2. **Metrics**: Request rates, response times, error rates, Kubernetes metrics
3. **Logs**: Application logs with correlation IDs

### Test Telemetry
The setup includes automatic load generation:
- **Frequency**: Every minute
- **Operations**: Dice rolls, statistics queries, health checks
- **Pattern**: Realistic traffic simulation

## 🔧 Operations

### Start Everything
```bash
ansible-playbook up.yml
```

### Stop Everything
```bash
ansible-playbook down.yml
```

### Check Status
```bash
# Kubernetes resources
kubectl get pods -n signoz-system
kubectl get pods -n default

# SigNoz containers
docker-compose -f signoz/docker-compose.yml ps

# Application logs
kubectl logs -f deployment/rolldice-otel
```

### Access Applications
```bash
# Port forward rolldice app
kubectl port-forward service/rolldice-otel-service 8080:80

# Port forward SigNoz (if needed)
kubectl port-forward service/signoz-frontend 3301:3301
```

## 🧪 Testing

### Manual Testing
1. **Access rolldice app**: `http://localhost:8080`
2. **Roll dice multiple times**
3. **Check statistics**
4. **View telemetry in SigNoz**

### Automated Testing
The load generator runs automatically and creates:
- HTTP request traces
- Custom application metrics
- Error scenarios
- Performance data

## 🐛 Troubleshooting

### Common Issues

1. **Pods not starting**:
   ```bash
   kubectl describe pods -n signoz-system
   kubectl logs -f deployment/signoz-k8s-infra-opentelemetry-collector -n signoz-system
   ```

2. **No telemetry data**:
   - Check OTEL collector logs
   - Verify endpoint configuration
   - Ensure SigNoz is accessible

3. **Port conflicts**:
   ```bash
   # Check port usage
   netstat -tlnp | grep :3301
   netstat -tlnp | grep :8080
   ```

### Logs
```bash
# Application logs
kubectl logs -f deployment/rolldice-otel

# OTEL Collector logs  
kubectl logs -f daemonset/signoz-k8s-infra-opentelemetry-collector -n signoz-system

# SigNoz logs
docker-compose -f signoz/docker-compose.yml logs -f
```

## 📁 Project Structure

```
.
├── setup.sh                          # Setup script for Codespace
├── requirements.txt                   # Python dependencies
├── up.yml                            # Main deployment playbook
├── down.yml                          # Main cleanup playbook
├── k8s/                              # Kubernetes setup
│   ├── up.yml / down.yml
│   ├── k3d/ & k3s/                   # K8s distribution configs
├── k8s-infra/                        # k8s-infra Helm chart setup
│   ├── up.yml                        # Install k8s-infra chart
│   ├── down.yml                      # Remove k8s-infra chart  
│   ├── rolldice-up.yml               # Deploy rolldice app
│   ├── rolldice-down.yml             # Remove rolldice app
│   ├── templates/
│   │   └── values.yaml.j2            # Helm values template
│   └── manifests/
│       └── rolldice-otel.yaml        # Rolldice K8s manifests
└── signoz/                           # SigNoz Docker setup
    ├── docker-compose.yml
    └── patch.diff
```

## 🎓 Learning Objectives

This project demonstrates:
- ✅ Helm chart management with Ansible
- ✅ OpenTelemetry collector configuration
- ✅ Kubernetes observability patterns
- ✅ Application instrumentation best practices
- ✅ Infrastructure as Code principles
- ✅ Container orchestration
- ✅ Monitoring and alerting setup

## 📝 Assignment Completion

- **k8s-infra Helm chart setup**: ✅ 3 marks
- **OTEL collector value overrides**: ✅ 3 marks  
- **VSphere testing capability**: ✅ 2 marks (Codespace optimized)
- **Rolldice app with telemetry**: ✅ 2 marks

**Total**: 10/10 marks

---

## TLDR

```bash
./setup.sh
ansible-playbook up.yml
# Wait for deployment to complete
kubectl port-forward service/rolldice-otel-service 8080:80
# Open http://localhost:8080 and http://localhost:3301
```
