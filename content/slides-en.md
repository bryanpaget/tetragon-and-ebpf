<!-- Title Slide -->
<!-- _class: lead -->
# Tetragon and eBPF

<br>

### Security Observability from the Kernel Up

<br>
<br>

#### Statistics Canada 2026

<br>
<br>
<br>

###### *Presented by the Zone Team*
![bg left:20%](./img/canada-1.png)

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

<!-- Current Status -->
## Current Status and Path Forward

![bg left:20%](./img/canada-1.png)

**As of February 2026:**

- Tetragon enabled **experimentally in Aurora clusters**
- Planned migration to `cloudnative-platform-charts` (no timeline)

**Opportunity:**

- Accelerate adoption by contributing the chart ourselves
- Validate in **Zone DEV** using AKS + Kubeflow

<blockquote>
Knowledge from SSC's Aurora to StatCan's The Zone – collaboration for a better future.
</blockquote>

---

<!-- Motivation: Why Kernel Space? -->
## Why Kernel Space Matters

![bg left:20%](./img/canada-1.png)

**The Problem:** Userspace security tools pay a hidden tax on every event.

**Why userspace is slower:**
1. **Context switches:** CPU must save/restore state crossing kernel/userspace boundary
2. **Data copying:** Event data copied from kernel memory to userspace buffers
3. **Latency:** By the time userspace sees the event, the moment has passed

---

## Why Kernel Space Matters (cont.)

![bg left:20%](./img/canada-1.png)

**Real-world example: NTSYNC (Wine 11)**
- **Before:** Thread sync required round‑trips from userspace to wineserver
- **After:** NTSYNC kernel module handles sync primitives directly in‑kernel
- **Result:** Up to **778% FPS improvement** in multi‑threaded games

**The pattern:** Hardware and software both follow the **Principle of Proximity**.

<blockquote>
Move computation to data, not data to computation.
</blockquote>

---

<!-- The Principle of Proximity -->
## The Principle of Proximity

![bg left:20%](./img/canada-1.png)

**Data Movement Bottleneck:** Moving data between components often costs more than computation.

**Principle:** Latency minimized when computation occurs **as close as possible to where data resides**.

Data traverses: on‑chip caches → main memory → storage → network

---

## The Principle of Proximity (cont.)

![bg left:20%](./img/canada-1.png)

**Manifestations across computing:**
- **Hardware:** Unified Memory (Apple M-series) eliminates PCIe overhead
- **Gaming:** NTSYNC keeps thread synchronization in‑kernel
- **Security:** eBPF processes events at their source, before copying to userspace

<blockquote>
A fundamental optimization principle across all computing.
</blockquote>

---

<!-- What is Tetragon? -->
## What is Tetragon?

![bg left:20%](./img/canada-1.png)

**Tetragon:** Security observability platform that uses eBPF to monitor Kubernetes clusters from the kernel up.

**What it monitors:**
- Process execution and signals
- File system operations
- Network connections and DNS queries
- All done in kernel space, limiting overhead and latency – real‑time monitoring for security and bugs

---

## What is Tetragon? (cont.)

![bg left:20%](./img/canada-1.png)

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

![bg left:20%](./img/canada-1.png)

**eBPF (Extended Berkeley Packet Filter):** An in‑kernel virtual machine that safely runs user‑supplied programs.

**Key Properties:**
- Runs inside the Linux kernel – no kernel module required
- **Verifier** guarantees safety before loading (proven mathematically)
- Attaches to kernel events: system calls, function entry/exit, tracepoints, LSM hooks
- Access to kernel data via controlled helper functions

<blockquote>
1992: BPF for packet filtering. 2014: eBPF generalized beyond networking.
</blockquote>

---

<!-- Core eBPF Concepts -->
## Core eBPF Concepts

![bg left:20%](./img/canada-1.png)

For Tetragon's real‑time threat monitoring, eBPF attaches small programs to kernel events.

**eBPF Program:** Finite sequence of RISC‑like instructions on 64‑bit registers, 512‑byte stack

**Hook:** Kernel location where eBPF programs attach:
- `kprobe` / `kretprobe`: Dynamic kernel function instrumentation
- `tracepoint`: Statically defined trace points (e.g., `sys_enter_execve`)
- `cgroup‑bpf`: Per‑container system call hooks (critical for Kubernetes)
- `LSM`: Linux Security Module hooks – enforce security policies

<blockquote>
Safe, efficient code running in the kernel.
</blockquote>

---

<!-- Safety Guarantees -->
## The Safety Guarantees

![bg left:20%](./img/canada-1.png)

The verifier guarantees make eBPF safe for production:

**Termination**
- No infinite loops. All backward jumps must be bounded

**Memory Safety**
- Cannot access kernel memory outside designated stack, maps, or context

**Resource Boundedness**
- Statically known upper bounds on execution time and memory
- Maximum instruction count, 512‑byte stack, fixed map sizes

<blockquote>
Provably safe code in the kernel – verified before loading.
</blockquote>

---

<!-- Tetragon's eBPF Implementation -->
## Tetragon's eBPF Implementation

![bg left:20%](./img/canada-1.png)

**Key Components:**

**TracingPolicy:** Kubernetes CRD defining:
- What events to trace (hooks)
- Match conditions (binaries, arguments)
- Actions (generate event, terminate process)

**Tetragon Agent:** DaemonSet on each node that:
- Loads eBPF programs from policies
- Collects events from eBPF maps
- Exports to configured sinks (stdout, ELK, etc.)

---

<!-- eBPF Hooks -->
## How Tetragon Uses eBPF Hooks

![bg left:20%](./img/canada-1.png)

| What we monitor | Kernel function | Hook type |
|-----------------|-----------------|-----------|
| Process starts | `sys_enter_execve` | Tracepoint |
| File reads | `vfs_read` | Kprobe |
| TCP connections | `tcp_connect` | Tracepoint |
| DNS queries | `udp_recvmsg:53` | Kprobe |

**Why these hooks?**
- `sys_*` – system call entry/exit (high‑level process activity)
- `vfs_*` – virtual filesystem layer (file operations)
- `tcp_*`, `udp_*` – network stack (connections and DNS)

**In our Kubeflow cluster:** These hooks give us visibility into:
- Jupyter notebook pods – monitor shell escapes
- Training jobs – detect unusual file access
- Inference endpoints – observe network connections

<blockquote>
Deep visibility into system activity – from container to kernel.
</blockquote>

---

<!-- Example: Detect Credential Access -->
## Example: Detect Credential Access

![bg left:20%](./img/canada-1.png)

**Policy:** Alert when bash executes commands containing `passwd` or `shadow`

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

<!-- Deployment Plan -->
## Deployment Plan

![bg left:20%](./img/canada-1.png)

**Prerequisites:**
- AKS cluster with Linux nodes (Ubuntu 20.04+ recommended)
- Kubeflow installed (optional, but we'll monitor Kubeflow components)
- `helm` and `kubectl` access

**Installation steps:**

1. **Add the Cilium Helm repository**
   ```bash
   helm repo add cilium https://helm.cilium.io
   helm repo update
   ```

2. **Create namespace and install Tetragon**
   ```bash
   kubectl create namespace tetragon
   helm install tetragon cilium/tetragon -n tetragon
   ```

3. **Verify installation**
   ```bash
   kubectl -n tetragon get pods
   # Should see tetragon-* DaemonSet pods running
   ```

4. **Deploy a TracingPolicy** (e.g., the credential access example)

---

<!-- Aurora Deployment Configuration -->
## Aurora Deployment Configuration

![bg left:20%](./img/canada-1.png)

| Setting | Value |
|---------|-------|
| Namespace | `tetragon-system` |
| Pod Security | `privileged` (required for eBPF) |
| Istio Injection | `disabled` |
| Resource Quota | 60 pods |
| Agent | DaemonSet |
| Operator | Deployment |
| Network Policies | same‑namespace, API server CIDR, konnectivity‑agent |
| Status | Experimental in Aurora |

<blockquote>
Production‑ready configuration validated in Aurora.
</blockquote>

---

<!-- Next Steps -->
## Next Steps and Open Questions

![bg left:20%](./img/canada-1.png)

**Immediate Actions:**

1. **Chart Porting:** Add Tetragon to `cloudnative-platform-charts`
2. **DEV Deployment:** Deploy to Zone DEV (AKS) with:
   - Create `tetragon` namespace
   - Install via Helm with overrides for AKS
   - Apply baseline TracingPolicies (process exec, file writes, network)
3. **Documentation:** Document configuration, policies, and integration with existing monitoring (ELK / Splunk)

**Questions to Answer:**
- Performance overhead under production load (especially with Kubeflow training jobs)?
- How to integrate Tetragon events with our existing SIEM?
- What policies are most useful for Kubeflow components?

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

<!-- References -->
<!-- _class: references -->
## References

**Tetragon & eBPF:**

1. <a href="https://tetragon.cilium.io/docs/">Tetragon Documentation</a>
2. <a href="https://ebpf.io/">eBPF.io – Introduction to eBPF</a>
3. <a href="https://github.com/cilium/tetragon">Cilium Tetragon GitHub</a>

**Technical Resources:**

4. Starovoitov, A. (2014). <a href="https://lwn.net/Articles/599755/">"BPF: the universal in‑kernel virtual machine."</a> LWN.net.
5. Rice, L. (2020). <a href="https://www.oreilly.com/library/view/learning-ebpf/9781098135119/ch01.html"><i>Learning eBPF</i></a>. O'Reilly Media.
6. McCanne, S. & Jacobson, V. (1993). <a href="https://www.tcpdump.org/papers/bpf-usenix93.pdf">"The BSD Packet Filter."</a> USENIX.
7. Linux Kernel Source: <a href="https://github.com/torvalds/linux/blob/master/kernel/bpf/verifier.c"><code>kernel/bpf/verifier.c</code></a>

**Aurora Implementation:**

8. <a href="https://github.com/gccloudone-aurora/aurora-platform-charts/tree/main/stable/aurora-platform/charts/aurora-core/templates/tetragon">Aurora Platform Charts</a>
