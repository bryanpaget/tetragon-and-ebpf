<!-- Title Slide -->
<!-- _class: lead -->
# What is Tetragon (and eBPF)?
![bg left:20%](./img/canada-1.png)

<br>

![w:128px](https://tetragon.io/images/tetragon-shield.png)

### Security Observability from the Kernel Up

<br>

#### Statistics Canada 2026

*Presented by the Zone Team*

---

<!-- Executive Summary -->
## Executive Summary

![bg left:20%](./img/canada-1.png)

- **What:** Tetragon is a security observability tool using eBPF. It is already running experimentally in Aurora; we will implement it in The Zone to meet corporate eBPF security standards.
- **Why:** eBPF-based security solutions are mandatory. Tetragon provides real-time, kernel‑level visibility with minimal overhead.
- **Risk:** Low – eBPF verifier guarantees safety; Tetragon is already validated in Aurora.
- **Cost:** Minimal – <1% CPU overhead, ~100-200 MiB memory per node (kernel space, no extra agents).

<blockquote>
From research to production-ready deployment.
</blockquote>

---

<!-- What is Tetragon? -->
## What is Tetragon?

**eBPF-based Security Observability and Runtime Enforcement**

![bg left:20%](./img/canada-1.png)
![w:128px](https://tetragon.io/images/home/hero-illustration.png)

- Kernel‑level visibility impossible with userspace tools
- Kubernetes native via Custom Resource Definitions (TracingPolicy)
- Filters and enforces policy directly in the kernel – minimal overhead
- <1% CPU, ~100-200 MiB memory per node

<blockquote>
Security monitoring from the kernel up.
</blockquote>

**Learn more:** <a href="https://tetragon.io/">tetragon.io</a>

---

<!-- What is eBPF? -->
## What is eBPF?

**eBPF (Extended Berkeley Packet Filter):** An in‑kernel virtual machine that safely runs user‑supplied programs.

![bg left:20%](./img/canada-1.png)
![w:128px](https://upload.wikimedia.org/wikipedia/commons/thumb/b/b0/EBPF_logo.png/250px-EBPF_logo.png)

- Runs inside the Linux kernel – no kernel module required
- **Verifier** guarantees safety before loading (proven mathematically)
- Attaches to system calls, function entry/exit, tracepoints, LSM hooks
- **Safety guarantees:** no infinite loops, memory safe, resource bounded

<blockquote>
Provably safe code in the kernel – verified before loading.
</blockquote>

---

<!-- Why Kernel Space? -->
## Why Kernel Space Matters

**The Principle of Proximity:** Move computation to where data resides.

![bg left:20%](./img/canada-1.png)

**The Problem:** Userspace security tools pay a hidden tax:
- Context switches (kernel↔user)
- Data copying
- Latency – by the time userspace sees the event, the moment has passed

**Real-world example: NTSYNC (Wine 11)**
- Thread sync handled in‑kernel → up to **778% FPS improvement** in multi‑threaded games

<blockquote>
Move computation to data, not data to computation.
</blockquote>

---

<!-- eBPF Architecture -->
<!-- _class: lead -->

## eBPF Architecture

![](https://ebpf.io/static/e293240ecccb9d506587571007c36739/691bc/overview.webp)

---

<!-- Tetragon Architecture -->
<!-- _class: lead -->

## Tetragon Architectural Diagram

![](https://tetragon.io/svgs/diagram-illustration.svg)

---

<!-- How Tetragon Uses eBPF Hooks -->
## How Tetragon Uses eBPF Hooks

![bg left:20%](./img/canada-1.png)

**What we monitor:**

- **Process starts:** `sys_enter_execve`
- **File reads:** `vfs_read`
- **TCP connections:** `tcp_connect`
- **DNS queries:** `udp_recvmsg:53`

**In our Kubeflow cluster:**
- **Jupyter notebooks** – detect shell escapes via `sys_execve`
- **Training jobs** – catch credential access via `vfs_read` on `/etc/shadow`, `~/.kube/config`
- **Inference endpoints** – monitor external connections via `tcp_connect`

---

<!-- Event Flow & Notifications -->
## Event Flow & Notifications

![bg left:20%](./img/canada-1.png)

**Event Lifecycle:**

Kernel event → eBPF capture → Kubernetes enrichment → Export → Alert

**Notification Paths:**
- **Critical:** PagerDuty → on-call
- **High:** Slack #security-alerts
- **Medium:** Email digest
- **Low:** Daily report

**Zone Integration:** ELK stack, existing PagerDuty, Kubernetes dashboards

---

<!-- Interaction: CLI -->
## How We Interact with Tetragon

### CLI (`tetra`)

![bg left:20%](./img/canada-1.png)

Real‑time event streaming and debugging from your terminal.

```bash
# Stream all events in compact format
tetra getevents -o compact

# Filter by namespace and pod
tetra getevents --namespace default \
  --field-selector "process.pod.name=my-app"

# Export to JSON for further processing
tetra getevents -o json | jq '.process.exec'
```

**Installation:**
```bash
go install github.com/cilium/tetragon/tetra@latest
```

---

<!-- Interaction: TracingPolicies as Code -->
## How We Interact with Tetragon

### Policies as Code

![bg left:20%](./img/canada-1.png)

TracingPolicies are **Kubernetes CRDs** – defined in YAML, versioned in Git.

```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: monitor-curl
spec:
  podSelector:
    matchLabels:
      app: my-app
  hooks:
    - path: /usr/bin/curl
      syscalls:
        - execve
      args:
        - action: Post
          valueFd: 1
```

**Deployed via GitOps (ArgoCD)** – automated sync, version control, rollback.

---

<!-- Interaction: Event Export & Dashboards -->
## How We Interact with Tetragon

### Export & Dashboards

![bg left:20%](./img/canada-1.png)

**Exporters:** Elasticsearch, Kafka, gRPC, stdout

**Grafana Dashboards:** Build custom visualizations using Elasticsearch as data source.

- Track process executions across namespaces
- Alert on suspicious network connections
- Filter by pod labels, namespaces, or specific syscalls

**Example query:** Count of shell executions per namespace in last hour.

---

<!-- Interaction: gRPC API -->
## How We Interact with Tetragon

### gRPC API

![bg left:20%](./img/canada-1.png)

Programmatic access for custom integrations (SIEM, automation, alerting).

```python
import tetragon_grpc

client = tetragon_grpc.TetragonClient()
for event in client.get_events():
    if event.process.exec.binary == "/bin/bash":
        print(f"Shell detected in {event.process.pod.namespace}")
```

**Use cases:**
- Feed events into a custom SIEM
- Trigger automated responses
- Enrich with external threat intelligence

---

<!-- What We Monitor: Key Use Cases -->
## What We Monitor: Key Use Cases

![bg left:20%](./img/canada-1.png)

- **Credential Access:** `/etc/shadow`, `~/.kube/config` – detect theft and lateral movement
- **Shell Escapes:** `/bin/bash` from notebooks – container breakout attempts
- **Data Exfiltration:** Connections to unknown external IPs – potential data theft
- **Privilege Escalation:** `setuid`, `setgid`, `capset` – prevent privilege escalation
- **Sensitive Files:** Secrets, tokens, certificates – protect service accounts

**Why these matter:** Common MITRE ATT&CK techniques in containerised environments.

---

<!-- Policy Management: Avoiding False Positives -->
## Policy Management: Avoiding False Positives

![bg left:20%](./img/canada-1.png)

**Start in Audit Mode:** Deploy without enforcement, baseline for 1‑2 weeks.

**Be Specific:** Use exact paths (`/usr/bin/python3`) not patterns (`*python*`).

**Namespace‑Specific:** Different baselines for Jupyter vs training vs inference.

**Iterative Refinement:** Deploy → observe → refine → repeat.

**Document:** Maintain a runbook of known false positives and their remediation.

---

<!-- Policy Management: Maintainable Policies -->
## Policy Management: Maintainable Policies

![bg left:20%](./img/canada-1.png)

- **Version Control:** Store in Git, review via pull requests.
- **CI/CD Pipeline:** Validate YAML, deploy to DEV, test, promote.
- **Documentation:** Include purpose, false positives, response, ownership.
- **Lifecycle:** Review quarterly, remove unused, update for new threats.
- **Testing:** Simulate events against policies before deployment.

---

<!-- Deployment: Helm Installation -->
## Deployment

### Helm Installation

![bg left:20%](./img/canada-1.png)

```bash
# 1. Add the Cilium Helm repository
helm repo add cilium https://helm.cilium.io
helm repo update

# 2. Create namespace and install Tetragon
helm install tetragon cilium/tetragon \
  --namespace tetragon \
  --create-namespace

# 3. Verify the DaemonSet is running
kubectl -n tetragon get pods
```

**Expected output:**
```
NAME               READY   STATUS    RESTARTS   AGE
tetragon-xxxxx     1/1     Running   0          1m
tetragon-operator  1/1     Running   0          1m
```

---

<!-- Deployment: Deploying a TracingPolicy -->
## Deployment

### Deploying a TracingPolicy

![bg left:20%](./img/canada-1.png)

```bash
# Example: detect credential access attempts
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

**Verify policy is active:**
```bash
kubectl get tracingpolicies
```

---

<!-- Deployment: Viewing Events -->
## Deployment

### Viewing Events

![bg left:20%](./img/canada-1.png)

**Forward the gRPC port and stream events:**

```bash
# Port‑forward to the Tetragon DaemonSet
kubectl port-forward -n tetragon ds/tetragon 54321:54321

# In another terminal, stream events
tetra getevents -o compact
```

**Example event output:**
```
🚀 process /bin/bash cat /etc/shadow
   pod: default/test-pod, container: app
```

**Export to Elasticsearch:** Configure the Helm chart with `exporters.elasticsearch.enabled=true`.

---

<!-- Implementation Plan: Phase 1 -->
## Implementation Plan

### Phase 1 – Validation in DEV

![bg left:20%](./img/canada-1.png)

- Deploy Tetragon to Zone DEV AKS
- Apply baseline policies (process exec, file access, network)
- Export events to test Elasticsearch
- Measure overhead (<1% CPU, <200 MiB memory)

---

<!-- Implementation Plan: Phases 2–3 -->
## Implementation Plan

### Phases 2–3 – Production & Automation

![bg left:20%](./img/canada-1.png)

**Phase 2: Production Readiness**
- Define SLOs for event latency & throughput
- Create Terraform module in `cloudnative-platform-charts`
- Integrate with cluster provisioning scripts

**Phase 3: Automation & Handover**
- CI/CD pipeline for TracingPolicy updates
- Alerting on critical events (PagerDuty, Slack)
- Documentation and runbooks

---

<!-- Implementation Roadmap: Weeks 1–2 -->
## Implementation Roadmap

### Weeks 1–2 – Deploy & Baseline

![bg left:20%](./img/canada-1.png)

- Deploy Tetragon to Zone DEV AKS
- Deploy baseline TracingPolicies (audit mode)
- Export events to test Elasticsearch
- Measure overhead

---

<!-- Implementation Roadmap: Weeks 3–6 -->
## Implementation Roadmap

### Weeks 3–6 – Tune, Integrate, Automate

![bg left:20%](./img/canada-1.png)

**Weeks 3–4: Tune & Integrate**
- Refine policies based on observed events
- Define SLOs (latency <100ms, 99.9% availability)
- Create Terraform module for `cloudnative-platform-charts`
- Integrate with existing ELK/Splunk

**Weeks 5–6: Automate & Alert**
- CI/CD pipeline for TracingPolicy updates
- Implement alerting (PagerDuty, Slack, email)
- Document runbooks
- Share findings organization-wide

---

<!-- Conclusion -->
## Conclusion

![bg left:20%](./img/canada-1.png)

- **What:** Tetragon delivers kernel‑level security observability with minimal overhead.
- **Why:** eBPF is safe, efficient, and mandatory for modern security stacks.
- **How:** We’ll deploy to Zone DEV, validate, refine policies, and integrate with existing monitoring.
- **Next Step:** Port the Helm chart and deploy to Zone DEV this sprint.

---

<!-- References -->
## References

![bg left:20%](./img/canada-1.png)

**Tetragon & eBPF:**

1. <a href="https://tetragon.cilium.io/docs/">Tetragon Documentation</a>
2. <a href="https://ebpf.io/">eBPF.io – Introduction to eBPF</a>
3. <a href="https://github.com/cilium/tetragon">Cilium Tetragon GitHub</a>

**Technical Resources:**

4. Starovoitov, A. (2014). <a href="https://lwn.net/Articles/599755/">"BPF: the universal in‑kernel virtual machine."</a> LWN.net.
5. Rice, L. (2020). <a href="https://www.oreilly.com/library/view/learning-ebpf/9781098135119/ch01.html"><i>Learning eBPF</i></a>. O'Reilly Media.
6. McCanne, S. & Jacobson, V. (1993). <a href="https://www.tcpdump.org/papers/bpf-usenix93.pdf">"The BSD Packet Filter."</a> USENIX.

---

<!-- References -->
## References

![bg left:20%](./img/canada-1.png)

**Linux Kernel:**

7. Linux Kernel Source: <a href="https://github.com/torvalds/linux/blob/master/kernel/bpf/verifier.c"><code>kernel/bpf/verifier.c</code></a>

**Aurora Implementation:**

8. <a href="https://github.com/gccloudone-aurora/aurora-platform-charts/tree/main/stable/aurora-platform/charts/aurora-core/templates/tetragon">Aurora Platform Charts</a>
