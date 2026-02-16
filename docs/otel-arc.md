# OpenTelemetry Configuration Architecture

## Overview

This document provides visual diagrams and detailed breakdowns of your OpenTelemetry collector configuration with full telemetry (logs, metrics, traces) enabled.

## Architecture Diagrams

### Simplified Architecture
See `otel-simplified-diagram.mmd` for a high-level overview showing:
- 📊 Three telemetry sources (Traces, Metrics, Logs)
- 🔧 Collector components (Receivers, Processors, Exporters)
- 💾 Storage backends (Tempo, Prometheus, Loki)
- 📺 Grafana visualization layer

### Detailed Architecture
See `otel-architecture-diagram.mmd` for comprehensive details including:
- All individual data sources
- Complete receiver configurations with ports
- All processors and their functions
- Pipeline flows
- Storage backend connections

## Key Components Breakdown

### 1. Receivers (Data Ingestion)

#### Trace Receivers
| Receiver | Port | Protocol | Purpose |
|----------|------|----------|---------|
| OTLP gRPC | 4317 | gRPC | Modern trace ingestion |
| OTLP HTTP | 4318 | HTTP | Modern trace ingestion (HTTP) |
| Jaeger gRPC | 14250 | gRPC | Legacy Jaeger spans |
| Jaeger HTTP | 14268 | HTTP | Legacy Jaeger spans (HTTP) |
| Jaeger Compact | 6831 | UDP | Legacy Jaeger compact format |
| Zipkin | 9411 | HTTP | Legacy Zipkin spans |

#### Metrics Receivers
| Receiver | Source | Data Collected |
|----------|--------|----------------|
| OTLP | Applications | Custom app metrics via OTLP |
| Prometheus | Various targets | Scraped Prometheus metrics |
| Host Metrics | Node | CPU, memory, disk, network |
| Kubelet Stats | Kubelet | Pod/container resource usage |

#### Logs Receivers
| Receiver | Path Pattern | Service |
|----------|--------------|---------|
| filelog/k8s_containers | `/var/log/pods/*/*/*.log` | All K8s pods |
| filelog/openstack_nova | `/var/log/nova/*.log`<br>`/var/log/pods/*/nova-*/*.log` | Nova compute |
| filelog/openstack_neutron | `/var/log/neutron/*.log`<br>`/var/log/pods/*/neutron-*/*.log` | Neutron networking |
| filelog/openstack_cinder | `/var/log/cinder/*.log`<br>`/var/log/pods/*/cinder-*/*.log` | Cinder block storage |
| filelog/openstack_keystone | `/var/log/keystone/*.log`<br>`/var/log/pods/*/keystone-*/*.log` | Keystone identity |
| filelog/openstack_glance | `/var/log/glance/*.log`<br>`/var/log/pods/*/glance-*/*.log` | Glance images |
| filelog/openstack_horizon | `/var/log/horizon/*.log`<br>`/var/log/apache2/horizon*.log`<br>`/var/log/pods/*/horizon-*/*.log` | Horizon dashboard |
| filelog/openstack_heat | `/var/log/heat/*.log`<br>`/var/log/pods/*/heat-*/*.log` | Heat orchestration |
| filelog/openstack_swift | `/var/log/swift/*.log`<br>`/var/log/pods/*/swift-*/*.log` | Swift object storage |
| filelog/openstack_octavia | `/var/log/octavia/*.log`<br>`/var/log/pods/*/octavia-*/*.log` | Octavia load balancer |
| filelog/openstack_placement | `/var/log/placement/*.log`<br>`/var/log/pods/*/placement-*/*.log` | Placement API |
| filelog/openstack_manila | `/var/log/manila/*.log`<br>`/var/log/pods/*/manila-*/*.log` | Manila shared filesystems |
| filelog/openstack_ironic | `/var/log/ironic/*.log`<br>`/var/log/pods/*/ironic-*/*.log` | Ironic bare metal |
| filelog/openstack_barbican | `/var/log/barbican/*.log`<br>`/var/log/pods/*/barbican-*/*.log` | Barbican secrets |
| filelog/openstack_ceilometer | `/var/log/ceilometer/*.log`<br>`/var/log/pods/*/ceilometer-*/*.log` | Ceilometer telemetry |
| filelog/openstack_gnocchi | `/var/log/gnocchi/*.log`<br>`/var/log/pods/*/gnocchi-*/*.log` | Gnocchi time-series |
| filelog/openstack_skyline | `/var/log/skyline/*.log`<br>`/var/log/pods/*/skyline-*/*.log` | Skyline dashboard |
| filelog/openstack_trove | `/var/log/trove/*.log`<br>`/var/log/pods/*/trove-*/*.log` | Trove DBaaS |

**Total**: 1 K8s receiver + 17 OpenStack service receivers = **18 log receivers**

### 2. Processors (Data Enrichment)

| Processor | Function | Configuration |
|-----------|----------|---------------|
| **memory_limiter** | Prevents OOM | 80% limit, 25% spike |
| **batch** | Batches telemetry | 1024 items, 10s timeout |
| **k8sattributes** | Adds K8s metadata | Pod, namespace, deployment, labels |
| **resourcedetection** | Detects environment | env, system, k8snode |
| **resource/openstack** | Tags OpenStack logs | `service.namespace=openstack` |
| **resource/k8s** | Tags K8s logs | `service.namespace=kube-system` |
| **attributes** | Adds cluster info | Cluster name, environment |

### 3. Exporters (Data Export)

| Exporter | Destination | Port/Endpoint | Telemetry Type |
|----------|-------------|---------------|----------------|
| **otlp/tempo** | Tempo Distributor | `tempo-distributor:4317` | Traces |
| **prometheusremotewrite** | Prometheus Server | `prometheus-server/api/v1/write` | Metrics |
| **prometheus** | Prometheus Scrape | `:8889` | Metrics |
| **otlphttp/loki** | Loki Gateway | `loki-gateway/otlp` | Logs |
| **debug** | Stdout/logs | N/A | All (verbose sampling) |

### 4. Pipelines (Data Flow)

#### Traces Pipeline
```
Sources → Receivers → Processors → Exporters
  ↓          ↓           ↓             ↓
Apps     OTLP/Jaeger  k8sattributes  Tempo
         /Zipkin      resource       Debug
                      batch
                      memory_limiter
```

#### Metrics Pipeline
```
Sources → Receivers → Processors → Exporters
  ↓          ↓           ↓             ↓
K8s       OTLP         k8sattributes  Prometheus
Nodes     Prometheus   resource       (Remote Write
Pods      HostMetrics  batch          & Endpoint)
          Kubelet      memory_limiter Debug
```

#### Logs/K8s Pipeline
```
Sources → Receivers → Processors → Exporters
  ↓          ↓           ↓             ↓
Pods      filelog/k8s  memory_limiter Loki
                       batch          Debug
                       k8sattributes
                       attributes
                       resource/k8s
```

#### Logs/OpenStack Pipeline
```
Sources → Receivers → Processors → Exporters
  ↓          ↓           ↓             ↓
17 OS     filelog/     memory_limiter Loki
Services  openstack_*  batch          Debug
                       attributes
                       resource/os
```

## Port Summary

### Exposed Ports on Collector Service

| Port | Protocol | Purpose |
|------|----------|---------|
| 4317 | gRPC | OTLP receiver (traces & metrics) |
| 4318 | HTTP | OTLP receiver (traces & metrics) |
| 14250 | gRPC | Jaeger receiver |
| 14268 | HTTP | Jaeger receiver |
| 6831 | UDP | Jaeger compact receiver |
| 9411 | HTTP | Zipkin receiver |
| 8888 | HTTP | Collector metrics endpoint |
| 8889 | HTTP | Prometheus exporter |

## Data Flow Summary

### Traces
1. **Applications** send traces via OTLP/Jaeger/Zipkin → **Collector receivers**
2. **Processors** enrich with K8s metadata, batch, limit memory
3. **Tempo exporter** sends to **Grafana Tempo**
4. **Grafana** queries Tempo for trace visualization

### Metrics
1. **K8s components, nodes, pods** expose Prometheus metrics
2. **Collector** scrapes or receives via OTLP
3. **Processors** enrich and batch
4. **Prometheus exporters** send to **Prometheus**
5. **Grafana** queries Prometheus for metrics dashboards

### Logs
1. **Containers** write logs to `/var/log/pods/` (K8s) or service-specific paths (OpenStack)
2. **Filelog receivers** tail and parse logs
3. **Processors** enrich with metadata, batch, limit memory
4. **Loki exporter** sends to **Grafana Loki**
5. **Grafana** queries Loki for log exploration

## Auto-Instrumentation

Applications can be automatically instrumented without code changes:

```yaml
# Add annotation to namespace or pod
instrumentation.opentelemetry.io/inject-python: "true"
instrumentation.opentelemetry.io/inject-java: "true"
instrumentation.opentelemetry.io/inject-nodejs: "true"
instrumentation.opentelemetry.io/inject-dotnet: "true"
instrumentation.opentelemetry.io/inject-go: "true"
```

The operator will inject instrumentation that sends traces to the collector at `collector-daemon:4317`.

## Resource Limits

### Collector DaemonSet
- **CPU Request**: 1024m (1 core)
- **CPU Limit**: 2046m (2 cores)
- **Memory Request**: 1024Mi
- **Memory Limit**: 2046Mi

### Processor Limits
- **Memory Limiter**: 80% of allocated memory with 25% spike allowance
- **Batch Size**: 1024 telemetry items
- **Batch Timeout**: 10 seconds

## Key Metrics to Monitor

Monitor these collector metrics at `:8888/metrics`:

- `otelcol_receiver_accepted_spans_total` - Traces received
- `otelcol_receiver_accepted_metric_points_total` - Metrics received
- `otelcol_receiver_accepted_log_records_total` - Logs received
- `otelcol_exporter_sent_spans_total` - Traces exported
- `otelcol_exporter_sent_metric_points_total` - Metrics exported
- `otelcol_exporter_sent_log_records_total` - Logs exported
- `otelcol_processor_batch_batch_send_size_bucket` - Batch sizes
- `otelcol_exporter_queue_size` - Export queue depth

## Storage Backends

### Grafana Tempo
- **Purpose**: Distributed tracing backend
- **Endpoint**: `tempo-distributor.grafana.svc.cluster.local:4317`
- **Protocol**: OTLP/gRPC
- **Data**: Trace spans with full context

### Prometheus
- **Purpose**: Time-series metrics database
- **Endpoints**: 
  - Remote Write: `prometheus-server/api/v1/write`
  - Scrape: collector `:8889/metrics`
- **Protocol**: Prometheus Remote Write + HTTP scrape
- **Data**: Metrics time-series

### Grafana Loki
- **Purpose**: Log aggregation system
- **Endpoint**: `loki-gateway.grafana.svc.cluster.local/otlp`
- **Protocol**: OTLP/HTTP
- **Data**: Structured logs with labels

## Correlation Features

All three telemetry signals are correlated via common attributes:

- `k8s.namespace.name`
- `k8s.pod.name`
- `k8s.deployment.name`
- `service.name`
- `service.namespace`

This enables:
- 🔍 **Trace → Logs**: Click on a trace span to see related logs
- 📊 **Metrics → Traces**: See traces for pods with high CPU/memory
- 📝 **Logs → Traces**: Find traces associated with error logs

## Summary

Your OpenTelemetry stack now provides:

✅ **18 Log Receivers**: K8s + 17 OpenStack services
✅ **6 Trace Receivers**: OTLP + Jaeger + Zipkin
✅ **4 Metrics Receivers**: OTLP + Prometheus + Host + Kubelet
✅ **7 Processors**: Enrichment, batching, resource detection
✅ **5 Exporters**: Tempo + Prometheus (2) + Loki + Debug
✅ **4 Pipelines**: Traces, Metrics, Logs (K8s), Logs (OpenStack)
✅ **3 Storage Backends**: Tempo, Prometheus, Loki
✅ **1 Unified Frontend**: Grafana with full correlation

**Total observability coverage**: Comprehensive logging, metrics, and distributed tracing for both Kubernetes and OpenStack infrastructure! 🎉
