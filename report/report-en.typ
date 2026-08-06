// Tetragon and eBPF - Technical Report
// Statistics Canada | March 2026

#import "@preview/barcala:0.3.0": informe

#show: informe.with(
  institucion: image("tetragon-shield.png", width: 80pt),
  unidad-academica: text(size: 18pt)[Statistics Canada],
  asignatura: "Zone Team | Cloud-Native Platform",
  trabajo: [Technical Report],
  equipo: [Security Observability],
  autores: (
    (nombre: "Paget, Bryan", email: "bryan.paget@statcan.gc.ca"),
  ),
  titulo: [Tetragon and eBPF],
  resumen: [
    We recommend adopting *Tetragon* as the primary security observability platform for Statistics Canada's Kubernetes infrastructure. Tetragon is already running in Aurora clusters (SSC's managed Kubernetes service). The risk profile is low: the eBPF verifier mathematically guarantees program safety, and resource consumption is minimal (CPU #sym.lt 1%, memory ~100-200 MiB per node). This report provides technical details, deployment strategy, and a six-week implementation roadmap.
  ],
  fecha: "2026-03-30",
  formato: (
    tipografia: "Inter",
    margenes: "simétricos",
  ),
)

= Executive Summary

== Recommendation

Adopt *Tetragon* as the primary security observability platform for Statistics Canada's Kubernetes infrastructure and contribute the Helm chart to the `cloudnative-platform-charts` repository.

== Context

Tetragon is already running in Aurora clusters (SSC's managed Kubernetes service). Rather than waiting for the Aurora team's timeline, Statistics Canada can accelerate adoption by validating Tetragon independently in Zone DEV using our AKS cluster with Kubeflow workloads.

== Risk and Cost

The risk profile is low. The eBPF verifier mathematically guarantees program safety, and Tetragon has been validated in Aurora. Resource consumption is minimal:

#list(
  [CPU overhead: #sym.lt 1% per node],
  [Memory: ~100-200 MiB per node],
  [No additional userspace agents required],
)

= Why Kernel Space Matters

== The Performance Tax

Traditional security tools operate in userspace, imposing three performance penalties:

#enum(
  [
    *Context switches:* Each observation requires switching between user and kernel mode, consuming 1-10 microseconds per event.
  ],
  [
    *Data copying:* Event data must be copied from kernel memory to userspace buffers via `copy_to_user()`.
  ],
  [
    *Latency:* By the time userspace observes an event, it has already completed, allowing attackers to act before detection.
  ],
)

== Real-World Example: NTSYNC in Wine 11

Wine must emulate Windows NT synchronization primitives for multi-threaded Windows applications on Linux. The original architecture required RPC calls to a wineserver process (two context switches per operation).

Wine 11 introduced NTSYNC, a kernel module handling synchronization in-kernel. Results:

#table(
  columns: (1fr, 1fr, 1fr),
  inset: 6pt,
  [Game], [Before (FPS)], [After (FPS)],
  [Dirt 3], [110.6], [860.7],
  [Resident Evil 2], [26], [77],
  [Tiny Tina's Wonderlands], [130], [360],
)

This demonstrates the *Principle of Proximity*: moving computation to where data resides.

= What is Tetragon?

== Platform Overview

[*eBPF-based Security Observability and Runtime Enforcement*]

Tetragon is a flexible Kubernetes-aware security observability and runtime enforcement tool that applies policy and filtering directly with eBPF, allowing for reduced observation overhead, tracking of any process, and real-time enforcement of policies.

Learn more: https://tetragon.io/

Tetragon monitors:

#list(
  [
    *Process execution:* starts, exits, signals, parent-child relationships
  ],
  [
    *File operations:* reads, writes, deletions, sensitive path access
  ],
  [
    *Network activity:* TCP/UDP connections, DNS queries, HTTP metadata
  ],
)

== Architecture

#list(
  [
    *TracingPolicy (CRD):* Declaratively specifies what events to monitor
  ],
  [
    *Tetragon Agent (DaemonSet):* Runs on every node, loads eBPF programs, enriches events with Kubernetes metadata
  ],
  [
    *Kernel components:* eBPF programs, maps, and perf buffers
  ],
)

== Tetragon Architecture

![](https://tetragon.io/svgs/diagram-illustration.svg)

= Understanding eBPF

== Definition

eBPF (Extended Berkeley Packet Filter) is an in-kernel virtual machine that safely executes user-supplied programs without kernel module loading.

== Safety Guarantees

The eBPF verifier performs exhaustive static analysis:

#list(
  [
    *Termination:* No infinite loops—all backward jumps must be bounded
  ],
  [
    *Memory safety:* Can only access 512-byte stack, pre-registered maps, and context structure
  ],
  [
    *Resource bounds:* ~1M instructions max, 512 bytes stack, configurable map limits
  ],
)

== Performance

#list(
  [Native execution via JIT compilation],
  [Zero-copy data access in kernel memory],
  [Latency impact #sym.lt 1 microsecond per event],
)

== Growing Ecosystem

eBPF's use cases extend well beyond security monitoring. Recent kernel developments include:

#list(
  [
    *CPU scheduling (Linux 6.12+):* sched_ext allows custom CPU schedulers loaded dynamically without kernel recompilation
  ],
  [
    *I/O scheduling (RFC 2026):* UFQ moves I/O scheduling to user-space for greater flexibility
  ],
  [
    *Network processing:* XDP provides high-performance packet filtering before the kernel network stack
  ],
  [
    *Security observability:* Tetragon provides kernel-level threat detection with minimal overhead
  ],
)

This ecosystem momentum indicates eBPF is becoming a [*core kernel extensibility mechanism*] — a strategic technology worth investing in.

== eBPF Architecture

![](https://ebpf.io/static/e293240ecccb9d506587571007c36739/691bc/overview.webp)

= Deployment Strategy

== Prerequisites

#table(
  columns: (1fr, 1fr, 1fr),
  inset: 6pt,
  [Requirement], [Minimum], [Recommended],
  [Linux Kernel], [4.19], [5.4+ for CO-RE (BTF)],
  [Kubernetes], [1.20], [1.25+],
  [Node Memory], [2 GB], [4 GB+],
  [Node CPU], [1 core], [2+ cores],
  [Helm], [3.x], [Latest 3.x],
)

== Installation with Helm

The most straightforward method is using Helm. This deploys Tetragon as a DaemonSet, ensuring the security agent runs on every node.

=== Step 1: Add Cilium Helm Repository

```bash
helm repo add cilium https://helm.cilium.io
helm repo update
```

=== Step 2: Deploy Tetragon

Install into the `tetragon` namespace with gRPC API enabled for the `tetra` CLI:

```bash
helm install tetragon cilium/tetragon \
  --namespace tetragon \
  --create-namespace \
  --set tetragon.grpc.enabled=true
```

=== Step 3: Verify Installation

Wait for rollout and confirm pods are running:

```bash
kubectl rollout status -n tetragon ds/tetragon -w
kubectl get pods -n tetragon -l app.kubernetes.io/name=tetragon
```

== Interacting with Tetragon

Once installed, use the `tetra` CLI to view real-time security events:

```bash
# Port-forward to a Tetragon pod
kubectl port-forward -n tetragon ds/tetragon 54321:54321

# View events in compact format
tetra getevents -o compact
```

== Example: Deploy a TracingPolicy

Deploy a policy to detect credential access attempts:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: detect-credential-access
spec:
  kprobes:
  - call: sys_execve
    selectors:
    - matchBinaries:
        - operator: In
          values: [/bin/bash, /bin/sh]
      matchArgs:
        - index: 0
          operator: Contains
          values: [passwd, shadow]
EOF
```

This policy detects when bash executes commands containing `passwd` or `shadow` (potential credential access).

For advanced setups, apply additional TracingPolicies to monitor specific namespaces or enforce policies.

== Azure AKS Considerations

Azure Kubernetes Service requires privileged containers for eBPF. Use `az aks update` to enable them. Helm values should specify resource requests (100m CPU, 256 MiB memory) and limits (500m CPU, 512 MiB memory), enable privileged mode, and configure event export to Elasticsearch.

= Operations Guide

== How We Interact with Tetragon

Tetragon has no dedicated UI—it integrates with existing tools:

=== CLI (`tetra`)

Real-time event viewing and debugging:

```bash
# Stream events from all pods
tetra getevents -o compact

# Watch specific namespace
tetra getevents --namespace default \
  --pods my-app
```

=== TracingPolicies as Code

- YAML configuration, versioned in Git
- Deployed via ArgoCD (GitOps)
- Enables version control, auditing, and rollback

Example policy:
```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: monitor-curl
spec:
  kprobes:
  - call: sys_execve
    syscall: true
    args:
    - index: 0
      type: "string"
    selectors:
    - matchBinaries:
      - operator: "In"
        values:
        - "/usr/bin/curl"
```

=== Event Export & Dashboards

- Elasticsearch: Store all Tetragon events
- Grafana: Build custom dashboards using Elasticsearch data source
  - Visualize process executions, network flows, and security events
  - Alert on suspicious activity

=== gRPC API

Programmatic access for custom integrations (SIEM, automation):

```python
import grpc
from tetragon import sensors_pb2_grpc, events_pb2

channel = grpc.insecure_channel("localhost:54321")
stub = sensors_pb2_grpc.FineGuidanceSensorsStub(channel)

for event in stub.GetEvents(events_pb2.GetEventsRequest()):
    print(event)
```

=== GitOps with ArgoCD

- TracingPolicies stored in Git repository
- ArgoCD syncs policies automatically to clusters
- Continuous deployment with audit trail

[*Outcome:*] Unified security observability using familiar tools – CLI, Git, Elasticsearch, Grafana, ArgoCD.

== Event Flow & Notifications

Events follow this lifecycle:

#enum(
  [
    *Kernel Event:* Process executes, file accessed, connection made
  ],
  [
    *eBPF Capture:* Tetragon agent captures event in kernel via eBPF
  ],
  [
    *Enrichment:* Agent adds Kubernetes metadata (pod, namespace, labels)
  ],
  [
    *Export:* Event sent to configured sink (Elasticsearch, Kafka, stdout)
  ],
  [
    *Alerting:* SIEM/monitoring tools trigger alerts based on rules
  ],
)

[*Notification Paths:*]

#table(
  columns: (1fr, 1fr, 1fr),
  inset: 6pt,
  [Severity], [Example], [Notification],
  [Critical], [Credential access], [PagerDuty → on-call],
  [High], [Shell escape], [Slack channel],
  [Medium], [Unusual connections], [Email digest],
  [Low], [Policy violations], [Daily report],
)

== Building Maintainable Policies

Version Control:
Store TracingPolicies in Git, review via pull requests, tag releases with chart versions.

CI/CD Pipeline:
Validate YAML syntax, deploy to DEV, run smoke tests, promote to production.

Policy Documentation:
Each policy should document: what it detects, known false positives, appropriate response, and ownership.

Lifecycle Management:
Review policies quarterly, remove unused policies, update based on new threat intelligence.

== Avoiding False Positives

Start in Audit Mode:
Deploy policies without enforcement. Baseline normal behavior for 1-2 weeks. Tune based on observed events.

Be Specific:
Use exact binary paths (`/usr/bin/python3`) not patterns (`*python*`).

Namespace-Specific Policies:
Different baselines for different workloads. Jupyter namespace ≠ training namespace ≠ inference.

Iterative Refinement:
Deploy → observe → identify false positives → refine → repeat until acceptable signal-to-noise ratio.

== What We Monitor: Use Cases

#list(
  [
    #strong[Credential Access Detection:]
    Files: `/etc/shadow`, `/etc/passwd`, `~/.kube/config`. Commands: `passwd`, `ssh-keygen`, `kubectl config`. Prevents credential theft and lateral movement.
  ],
  [
    #strong[Shell Escape Prevention:]
    Detect `/bin/sh`, `/bin/bash` spawned from notebook processes. Context: Jupyter pods, training jobs. Prevents container breakout attempts.
  ],
  [
    #strong[Data Exfiltration:]
    Connections to IPs outside cluster CIDR, large outbound data transfers. Detects data theft, crypto mining.
  ],
  [
    #strong[Privilege Escalation:]
    `setuid`, `setgid`, `capset` system calls, unexpected root access. Prevents privilege escalation attacks.
  ],
  [
    #strong[Sensitive File Access:]
    Secrets, tokens, certificates, `/var/run/secrets/kubernetes.io`. Protects service account tokens.
  ],
)

= Implementation Roadmap

== Phase 1: Validation in DEV (Weeks 1-2)

Deploy Tetragon to Zone DEV AKS cluster and validate with Kubeflow:

#list(
  [Deploy Tetragon via Helm with AKS-specific values],
  [Deploy baseline TracingPolicies for process execution, file access, and network connections],
  [Configure event export to test Elasticsearch index],
  [Establish baseline metrics (CPU #sym.lt 1%, memory #sym.lt 200 MiB per node)],
)

*Success criteria:* Tetragon pods on all nodes, events in Elasticsearch, overhead within targets.

== Phase 2: Production Readiness (Weeks 3-4)

Define operational standards and create infrastructure-as-code:

#list(
  [Define SLOs: event latency #sym.lt 100 ms, throughput 10,000 events/s, 99.9% availability],
  [Create Terraform module for `cloudnative-platform-charts`],
  [Add Tetragon to cluster provisioning scripts],
  [Document upgrade procedures],
)

== Phase 3: Integration and Automation (Weeks 5-6)

Automate policy deployment and implement alerting:

#list(
  [Create CI/CD pipeline for TracingPolicy updates],
  [Implement alerting: credential access → PagerDuty, unusual connections → Slack, high volume → email],
  [Document runbooks, troubleshooting guides, and policy guidelines],
)

= Performance and Security

== Resource Consumption

#table(
  columns: (1fr, 1fr),
  inset: 6pt,
  [Metric], [Value],
  [CPU (idle)], [#sym.lt 0.1%],
  [CPU (normal)], [0.3-0.5%],
  [CPU (high volume)], [0.8-1.2%],
  [Agent memory], [100-150 MiB per node],
  [Operator memory], [50-70 MiB],
  [eBPF maps], [10-20 MiB per node],
)

== Security and Privacy

Tetragon detects MITRE ATT&CK techniques:

#list(
  [
    *T1003 (Credential Dumping):* Monitors `/etc/shadow` and `/etc/passwd` access
  ],
  [
    *T1059 (Command Interpreter):* Monitors shell execution
  ],
  [
    *T1078 (Valid Accounts):* Monitors credential file access
  ],
  [
    *T1095 (Non-App Protocol):* Monitors unusual network connections
  ],
)

*Privacy:* Tetragon collects only metadata (binary paths, arguments, timestamps, PIDs)—not file contents, network payloads, or command output.

= Comparison and Conclusion

== Alternatives Comparison

#table(
  columns: (1fr, 1fr, 1fr, 1fr),
  inset: 6pt,
  [*Feature*], [*Tetragon*], [*Falco*], [*K8s Audit*],
  [Implementation], [eBPF-native], [Kernel module/eBPF], [API server only],
  [CPU overhead], [#sym.lt 1%], [2-5%], [Variable],
  [K8s integration], [Native CRDs], [External config], [API-only],
  [Policy language], [YAML], [Lua], [N/A],
  [Response actions], [In-kernel], [Userspace], [None],
)

== Final Recommendation

Tetragon represents a fundamental improvement in Kubernetes security observability:

#list(
  [
    *Technical excellence:* eBPF provides safe, efficient kernel-level monitoring with provable guarantees
  ],
  [
    *Operational benefits:* #sym.lt 1% CPU overhead, automatic K8s integration, real-time detection
  ],
  [
    *Strategic alignment:* Meets corporate eBPF requirements, already validated in Aurora
  ],
  [
    *Low risk:* Mature technology with strong industry backing
  ],
)

Proceed with the three-phase plan: immediate DEV validation, short-term Helm chart contribution, medium-term production expansion, and long-term SIEM integration.

= References

#list(
  [Cilium. *Tetragon Documentation.* https://tetragon.io/docs/],
  [Cilium. *Tetragon Installation Guide.* https://tetragon.io/docs/installation/kubernetes/],
  [eBPF Foundation. *What is eBPF?* https://ebpf.io/],
  [Rice, L. (2020). *Learning eBPF.* O'Reilly Media.],
  [Linux Kernel Documentation. *eBPF Subsystem.* https://www.kernel.org/doc/html/latest/bpf/],
  [MITRE. *ATT&CK Framework.* https://attack.mitre.org/],
  [SSC Aurora Team. *Aurora Platform Charts.* https://github.com/gccloudone-aurora/aurora-platform-charts],
  [Lakshman, S. *Securing Kubernetes: Integrating AKS with Tetragon.* Medium.],
  [Stream Security. *How to Deploy Tetragon on an EKS Cluster.*],
  [Oracle. *Tetragon eBPF Observability on OKE.* https://docs.oracle.com/en/learn/tetragon-ebpf-observability-oke/],
)
