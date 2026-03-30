<!-- Title Slide -->
<!-- _class: lead -->
# What is Tetragon (and eBPF)?
![bg left:20%](./img/canada-1.png)

![w:200px](https://tetragon.io/images/tetragon-shield.png)

<br>

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

<!-- Motivation: Why Kernel Space? -->
## Why Kernel Space Matters

**The Problem:** Userspace security tools pay a hidden tax on every event.

![bg left:20%](./img/canada-1.png)

**Why userspace is slower:**
1. **Context switches:** CPU must save/restore state crossing kernel-user boundary
2. **Data copying:** Event data copied from kernel memory to userspace buffers
3. **Latency:** By the time userspace sees the event, the moment has passed


---

<!-- Motivation: Why Kernel Space? -->
## Why Kernel Space Matters (cont.)

**The Principle of Proximity:** Move computation to where data resides.

![bg left:20%](./img/canada-1.png)

**Real-world example: NTSYNC (Wine 11)**
- **Before:** Thread sync required round‑trips to wineserver (2 context switches)
- **After:** NTSYNC kernel module handles sync in‑kernel
- **Result:** Up to **778% FPS improvement** in multi‑threaded games

<blockquote>
Move computation to data, not data to computation.
</blockquote>

---

<!-- What is Tetragon? -->
## What is Tetragon?

**eBPF-based Security Observability and Runtime Enforcement**

![bg left:20%](./img/canada-1.png)
![w:128px](https://tetragon.io/images/home/hero-illustration.png)

Tetragon is a flexible Kubernetes-aware security observability and runtime enforcement tool that operates in kernel space using eBPF. By applying policy and filtering directly in the kernel, it allows for reduced observation overhead, tracking of any process, and real-time enforcement of policies.

**Learn more:** <a href="https://tetragon.io/">tetragon.io</a>

---

## What is Tetragon? (cont.)

![bg left:20%](./img/canada-1.png)
![w:128px](https://tetragon.io/images/home/hero-illustration.png)

**Key Benefits:**
- Corporate compliance with eBPF requirements
- Kernel‑level visibility impossible with userspace tools
- Kubernetes native via Custom Resource Definitions (TracingPolicy)
- <1% CPU overhead, ~100-200 MiB memory per node

<blockquote>
Security monitoring from the kernel up.
</blockquote>

---

<!-- What is eBPF? -->
## What is eBPF?

**eBPF (Extended Berkeley Packet Filter):** An in‑kernel virtual machine that safely runs user‑supplied programs.

![bg left:20%](./img/canada-1.png)
![w:128px](https://upload.wikimedia.org/wikipedia/commons/thumb/b/b0/EBPF_logo.png/250px-EBPF_logo.png)

**Key Properties:**
- Runs inside the Linux kernel – no kernel module required
- **Verifier** guarantees safety before loading (proven mathematically)
- Attaches to kernel events: system calls, function entry/exit, tracepoints, LSM hooks

---

<!-- What is eBPF? -->
## What is eBPF? (cont.)

**eBPF (Extended Berkeley Packet Filter):** An in‑kernel virtual machine that safely runs user‑supplied programs.

![w:128px](https://upload.wikimedia.org/wikipedia/commons/thumb/b/b0/EBPF_logo.png/250px-EBPF_logo.png)
![bg left:20%](./img/canada-1.png)

**Safety Guarantees:**
- No infinite loops – all programs terminate
- Memory safe – can only access designated stack, maps, context
- Resource bounded – ~1M instructions max, 512 bytes stack

<blockquote>
Provably safe code in the kernel – verified before loading.
</blockquote>

---

<!-- Tetragon Architecture -->
<!-- _class: lead -->

![](https://tetragon.io/svgs/diagram-illustration.svg)

---

<!-- Deployment Architecture -->
## Deployment Architecture

![bg left:20%](./img/canada-1.png)

**Components:**
- **DaemonSet:** One agent per node, loads eBPF programs
- **Operator:** Centralized control, manages TracingPolicy CRDs
- **Event Export:** Elasticsearch, Kafka, gRPC, stdout

**Resources:**
- CPU: < 1% per node
- Memory: ~100-200 MiB per node
- Privileged container required

---

<!-- How We Interact -->
## How We Interact with Tetragon

**No dedicated UI** – integrates seamlessly with existing tools.

---

## CLI (`tetra`)

![bg left:20%](./img/canada-1.png)

Real-time event viewing and debugging.

```bash
# Stream events from all pods
tetra getevents -o compact

# Watch specific namespace
tetra getevents --namespace default \
  --field-selector "process.pod.name=my-app"
```

---

## TracingPolicies as Code

![bg left:20%](./img/canada-1.png)

- YAML configuration, versioned in **Git**
- Deployed via **ArgoCD** (GitOps)

Example policy snippet:
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

---

## Event Export & Dashboards

![bg left:20%](./img/canada-1.png)

- **Elasticsearch** – store all Tetragon events
- **Grafana** – build custom dashboards using Elasticsearch data source
  - Visualize process executions, network flows, and security events
  - Alert on suspicious activity

---

## gRPC API

![bg left:20%](./img/canada-1.png)

Programmatic access for custom integrations (e.g., SIEM, automation).

```python
import tetragon_grpc

client = tetragon_grpc.TetragonClient()
for event in client.get_events():
    print(event.process.exec)
```

---

## GitOps with ArgoCD

![bg left:20%](./img/canada-1.png)

- TracingPolicies stored in Git repository
- ArgoCD syncs policies automatically to clusters
- Enables version control, auditing, and rollback

---

> **Outcome:** Unified security observability using familiar tools – CLI, Git, Elasticsearch, Grafana, ArgoCD.

---

<!-- Event Flow -->
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

<!-- eBPF Hooks -->
## How Tetragon Uses eBPF Hooks

![bg left:20%](./img/canada-1.png)

**What we monitor:**

- **Process starts:** `sys_enter_execve` (Tracepoint)
- **File reads:** `vfs_read` (Kprobe)
- **TCP connections:** `tcp_connect` (Tracepoint)
- **DNS queries:** `udp_recvmsg:53` (Kprobe)

**Why these hooks?**
- `sys_*` – system call entry/exit (high‑level process activity)
- `vfs_*` – virtual filesystem layer (file operations)
- `tcp_*`, `udp_*` – network stack (connections and DNS)

---

## How Tetragon Uses eBPF Hooks (cont.)

![bg left:20%](./img/canada-1.png)

**In our Kubeflow cluster:**

- **Jupyter notebook pods** – Detect shell escapes via `sys_execve` when `/bin/sh` or `/bin/bash` spawns from notebook process
- **Training jobs** – Catch credential access via `vfs_read` on `/etc/shadow`, `/etc/passwd`, or `~/.kube/config`
- **Inference endpoints** – Monitor external connections via `tcp_connect` to IPs outside cluster CIDR

<blockquote>
Deep visibility into system activity – from container to kernel.
</blockquote>

---

<!-- Example: Detect Credential Access -->
## Example: Detect Credential Access

![bg left:20%](./img/canada-1.png)

**Policy:** Alert when bash executes `passwd` or `shadow`

```yaml
kind: TracingPolicy
spec:
  kprobes:
  - call: sys_execve
    selectors:
    - matchBinaries: [{operator: In, values: [/bin/bash]}]
      matchArgs: [{index: 0, operator: Contains, values: [passwd, shadow]}]
```

**Event generated:**
```json
{
  "event_type": "process_exec",
  "binary": "/bin/bash",
  "arguments": "cat /etc/passwd",
  "pod": {"namespace": "default", "name": "test-pod"}
}
```

---

<!-- What We Monitor -->
## What We Monitor: Use Cases

![bg left:20%](./img/canada-1.png)

- **Credential Access:** `/etc/shadow`, `~/.kube/config` – prevent theft and lateral movement
- **Shell Escapes:** `/bin/bash` from notebooks – prevent container breakout
- **Data Exfiltration:** External IPs, large transfers – detect data theft
- **Privilege Escalation:** `setuid`, `setgid`, `capset` – prevent attacks
- **Sensitive Files:** Secrets, tokens, certificates – protect service accounts

---

<!-- Avoiding False Positives -->
## Avoiding False Positives

![bg left:20%](./img/canada-1.png)

**Start in Audit Mode:** Deploy without enforcement, baseline for 1-2 weeks.

**Be Specific:** Use exact paths (`/usr/bin/python3`) not patterns (`*python*`).

**Namespace-Specific:** Different baselines for Jupyter vs training vs inference.

**Iterative Refinement:** Deploy → observe → refine → repeat.

**Document:** Maintain runbook of known false positives.

---

<!-- Building Maintainable Policies -->
## Building Maintainable Policies

![bg left:20%](./img/canada-1.png)

**Version Control:** Store in Git, review via pull requests.

**CI/CD Pipeline:** Validate YAML, deploy to DEV, test, promote.

**Documentation:** What it detects, false positives, response, ownership.

**Lifecycle:** Review quarterly, remove unused, update for threats.

---

<!-- Deployment Plan -->
## Deployment Plan / Installation (1/2)

![bg left:20%](./img/canada-1.png)

   ```bash
   # 1. Add the Cilium Helm repository:
   helm repo add cilium https://helm.cilium.io
   helm repo update

   # 2. Install Tetragon with Helm:
   helm install tetragon cilium/tetragon \
     --namespace tetragon \
     --create-namespace

   # 3. Verify installation:
   kubectl -n tetragon get pods
   # Should see tetragon-* DaemonSet pods running

   # 4. Install tetra CLI (optional):
   go install github.com/cilium/tetragon/tetra@latest
   ```

---

<!-- Deployment Plan -->
## Deployment Plan / Installation (2/2)

![bg left:20%](./img/canada-1.png)

   ```bash
   # 5. Deploy a TracingPolicy:
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

   # 6. View events in real-time:
   kubectl port-forward -n tetragon ds/tetragon 54321:54321
   tetra getevents -o compact
   ```

---

<!-- Next Steps -->
## Next Steps

![bg left:20%](./img/canada-1.png)

**Immediate Actions:**

1. **Chart Porting:** Add Tetragon to `cloudnative-platform-charts`
2. **DEV Deployment:** Deploy to Zone DEV (AKS) with:
   - Create `tetragon` namespace
   - Install via Helm with overrides for AKS
   - Apply baseline TracingPolicies (process exec, file writes, network)
3. **Documentation:** Document configuration, policies, and integration with existing monitoring (ELK / Splunk)

---

<!-- Implementation Steps for The Zone -->
## Implementation Steps for The Zone

![bg left:20%](./img/canada-1.png)

**Phase 1: Validation in DEV**
- Deploy Tetragon to Zone DEV AKS cluster
- Deploy a few TracingPolicies:
  - **Process execution** in Kubeflow namespaces
  - **File access** to `/etc/shadow`, `/etc/passwd`, `/home/*/.kube`
  - **Network connections** from unknown external IPs
- Export events to a test Elasticsearch index
- Measure CPU/memory overhead (baseline vs. with policies)

---

<!-- Implementation Steps for The Zone -->
## Implementation Steps for The Zone

![bg left:20%](./img/canada-1.png)

**Phase 2: Production Readiness**
- Define service level objectives (SLOs) for event latency and throughput
- Create Terraform module for Tetragon deployment (as part of `cloudnative-platform-charts`)
- Add Tetragon to cluster provisioning scripts

**Phase 3: Integration & Automation**
- Create CI/CD pipeline for TracingPolicy updates
- Implement alerting on critical events (e.g., credential access)
- Document for the wider team

---

<!-- Implementation Roadmap -->
## Implementation Roadmap

![bg left:20%](./img/canada-1.png)

**Weeks 1-2: Deploy & Baseline**
- Deploy Tetragon to Zone DEV AKS
- Deploy baseline TracingPolicies (audit mode)
- Export events to test Elasticsearch index
- Measure overhead (CPU #sym.lt 1%, memory #sym.lt 200 MiB)

**Weeks 3-4: Tune & Integrate**
- Refine policies based on observed events
- Define SLOs (latency #sym.lt 100ms, 99.9% availability)
- Create Terraform module for `cloudnative-platform-charts`
- Integrate with existing ELK/Splunk

**Weeks 5-6: Automate & Alert**
- Create CI/CD pipeline for TracingPolicy updates
- Implement alerting (PagerDuty, Slack, email)
- Document runbooks and troubleshooting guides
- Share findings organization-wide

---

<!-- Conclusion -->
## Conclusion

![bg left:20%](./img/canada-1.png)

**Research Foundation:**
- Tetragon provides needed security observability
- eBPF provides safe, efficient kernel technology
- Principle of Proximity explains *why* eBPF is so powerful

**Path Forward:** Port chart → Deploy in DEV → Validate → Share findings

**Immediate Next Step:** Deploy Tetragon in Zone DEV this sprint.

---
<!-- _class: references -->
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
<!-- _class: references -->
## References (continued)

![bg left:20%](./img/canada-1.png)

**Linux Kernel:**

7. Linux Kernel Source: <a href="https://github.com/torvalds/linux/blob/master/kernel/bpf/verifier.c"><code>kernel/bpf/verifier.c</code></a>

**Aurora Implementation:**

8. <a href="https://github.com/gccloudone-aurora/aurora-platform-charts/tree/main/stable/aurora-platform/charts/aurora-core/templates/tetragon">Aurora Platform Charts</a>
