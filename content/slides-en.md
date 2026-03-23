<!-- Title Slide -->
<!-- _class: lead -->
# Tetragon and eBPF
### A Comprehensive Foundation
#### From Corporate Requirements to Kernel Internals

<br>
<br>

## Statistics Canada | March 2026

<br>

###### *Brought to you by the Zone Team*
![bg left:33%](./img/canada-1.png)

---

<!-- Executive Summary -->
## Executive Summary

![bg left:33%](./img/canada-1.png)

**Recommendation:** Adopt Tetragon and contribute the Helm chart to `cloudnative-platform-charts`

**What:** eBPF-powered security observability already running experimentally in Aurora

**Why now:** Corporate standards require eBPF-based security solutions

**Risk:** Low—already deployed in Aurora; eBPF verifier guarantees safety

**Cost:** Minimal—<1% CPU overhead, ~100-200 MiB memory per node

**Ask:** Approve chart contribution and Zone DEV deployment validation

<blockquote>
From research to production-ready deployment.
</blockquote>

---

<!-- What is Tetragon? -->
## What is Tetragon?

![bg left:33%](./img/canada-1.png)

**Tetragon:** Kubernetes-aware security observability leveraging eBPF for:
- Process, file, and network activity visibility

Think of it as a **security camera system for containers**—watching every action at the kernel level, in real-time.

**Key Benefits:**
- Corporate compliance with eBPF requirements
- Kernel-level visibility impossible with userspace tools
- Kubernetes native via CRDs
- <1% CPU overhead, ~100-200 MiB memory per node

<blockquote>
Security monitoring from the kernel up.
</blockquote>

---

<!-- Current Status -->
## Current Status and Path Forward

![bg left:33%](./img/canada-1.png)

**As of February 2026:**
- Tetragon enabled **experimentally in Aurora clusters**
- Planned migration to `cloudnative-platform-charts` (no timeline)

**Opportunity:**
- Accelerate adoption by contributing the chart ourselves
- Validate in **Zone DEV**—our safe, non-production Kubernetes environment

<blockquote>
From experimental to production-ready.
</blockquote>

---

<!-- The Foundation: eBPF -->
## The Foundation: eBPF

![bg left:33%](./img/canada-1.png)

To understand Tetragon, we must understand eBPF.

**Historical Context:**
- **1992:** Berkeley Packet Filter (BPF) for network packet filtering
- **2014:** Extended BPF (eBPF) generalized beyond networking

**eBPF:** A general-purpose in-kernel virtual machine that safely runs user-supplied programs with:
- Well-defined instruction set
- Verifier guaranteeing safety
- Access to kernel data via helper functions
- Attachment to diverse kernel events

<blockquote>
30+ years of evolution from packet filter to universal kernel VM.
</blockquote>

---

<!-- Core eBPF Concepts -->
## Core eBPF Concepts

![bg left:33%](./img/canada-1.png)

For Tetragon's real-time threat monitoring, eBPF attaches small programs to kernel events.

**eBPF Program:** Finite sequence of RISC-like instructions on 64-bit registers, 512-byte stack

**Hook:** Kernel location where eBPF programs attach:
- `kprobe`/`kretprobe`: Dynamic kernel function instrumentation
- `tracepoint`: Statically defined trace points
- `cgroup-bpf`: Per-container system call hooks
- `LSM`: Security policy enforcement points

<blockquote>
Safe, efficient code running in the kernel.
</blockquote>

---

<!-- Safety Guarantees -->
## The Safety Guarantees

![bg left:33%](./img/canada-1.png)

The verifier guarantees make eBPF safe for production:

**Termination**
- No infinite loops—all backward jumps must be bounded

**Memory Safety**
- Cannot access kernel memory outside designated stack, maps, or context

**Resource Boundedness**
- Statically known upper bounds on execution time and memory
- Maximum instruction count, 512-byte stack, fixed map sizes

<blockquote>
Provably safe code in the kernel.
</blockquote>

---

<!-- The Principle of Proximity -->
## The Principle of Proximity

![bg left:33%](./img/canada-1.png)

**Data Movement Bottleneck:** Moving data between components often costs more than computation.

**Principle:** Latency minimized when computation occurs **as close as possible to where data resides**.

Data traverses: on-chip caches → main memory → storage → network

**Manifestations:**
- Unified Memory (Apple M-series) — eliminates PCIe overhead
- Zero-copy/kernel bypass techniques
- **eBPF: eliminates kernel→userspace copy for security events**

<blockquote>
Move computation to data, not data to computation.
</blockquote>

---

<!-- Relevance to Tetragon -->
## How Tetragon Embodies This Principle

![bg left:33%](./img/canada-1.png)

**Traditional approach:**
1. Kernel detects event
2. Event copied to userspace
3. Userspace tool analyzes
4. Response generated

**Tetragon's eBPF approach:**
1. eBPF program runs **in the kernel**
2. Events processed **at their source**
3. Results exported to userspace

<blockquote>
Security monitoring where events occur—minimal latency, real-time visibility.
</blockquote>

---

<!-- Tetragon's Implementation -->
## Tetragon's eBPF Implementation

![bg left:33%](./img/canada-1.png)

**Key Components:**

**TracingPolicy:** Kubernetes CRD defining:
- What events to trace (hooks)
- Match conditions (binaries, arguments)
- Actions (generate event, terminate process)

**Tetragon Agent:** DaemonSet on each node that:
- Loads eBPF programs from policies
- Collects events from eBPF maps
- Exports to configured sinks (stdout, ELK, etc.)

<blockquote>
Kubernetes-native security observability.
</blockquote>

---

<!-- eBPF Hooks Table -->
## How Tetragon Uses eBPF Hooks

![bg left:33%](./img/canada-1.png)

| Observability Target | eBPF Hook Type | Kernel Function/Event |
|---------------------|----------------|----------------------|
| Process execution | Tracepoint | `sys_enter_execve`, `sys_exit_execve` |
| File access | Kprobe | `vfs_open`, `vfs_read`, `vfs_write` |
| Network connections | Tracepoint | `tcp_connect`, `udp_sendmsg` |
| DNS queries | Kprobe | `udp_recvmsg` (port 53) |

<blockquote>
Deep visibility into system activity.
</blockquote>

---

<!-- Example Policy -->
## Example TracingPolicy

![bg left:33%](./img/canada-1.png)

```
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: "trace-sensitive-commands"
spec:
  kprobes:
  - call: "sys_execve"
    syscall: true
    selectors:
    - matchBinaries:
      - operator: "In"
        values: ["/bin/bash", "/bin/sh"]
      matchArgs:
      - index: 0
        operator: "Contains"
        values: ["passwd", "shadow"]
```

Detects potential credential access when bash/sh executes commands containing "passwd" or "shadow".

<blockquote>
Declarative security policies as Kubernetes resources.
</blockquote>

---

<!-- Example Event Output -->
## Example Event Output

![bg left:33%](./img/canada-1.png)

When the policy triggers, Tetragon exports structured JSON events:

```
{
  "node": "worker-node-01",
  "time": "2026-03-23T14:32:15.123Z",
  "event_type": "process_exec",
  "process": {
    "pid": 12345,
    "binary": "/bin/bash",
    "arguments": "cat /etc/passwd"
  },
  "pod": {
    "namespace": "default",
    "name": "test-pod"
  }
}
```

Events flow to configured sinks: stdout, ELK, Splunk, or OpenTelemetry.

<blockquote>
Structured events ready for analysis.
</blockquote>

---

<!-- Deployment Plan -->
## Deployment Plan

![bg left:33%](./img/canada-1.png)

**Prerequisites:**
- Zone DEV cluster access, `kubectl`, Helm 3
- Linux kernel ≥ 4.19 (5.4+ recommended)
- BTF support for CO-RE compatibility

**Kernel check:**
```
uname -r && ls /sys/kernel/btf/vmlinux
```

**Install:**
```
helm repo add cilium https://helm.cilium.io
helm install tetragon cilium/tetragon -n tetragon
```

<blockquote>
From research to validation.
</blockquote>

---

<!-- Next Steps -->
## Next Steps and Open Questions

![bg left:33%](./img/canada-1.png)

**Immediate Actions:**
1. **Chart Porting:** Add Tetragon to `cloudnative-platform-charts`
2. **DEV Deployment:** Execute Zone DEV deployment
3. **Documentation:** Share findings with team

**Questions:**
- Performance overhead under production load?
- Integration with existing security tools?
- Event ingestion into monitoring stack (ELK, Splunk)?

<blockquote>
Clear path forward with open research questions.
</blockquote>

---

<!-- Conclusion -->
## Conclusion

![bg left:33%](./img/canada-1.png)

**Research Foundation:**
- Tetragon provides needed security observability
- eBPF provides safe, efficient kernel technology
- Principle of Proximity explains *why* eBPF is so powerful

**Path Forward:** Port chart → Deploy in DEV → Validate → Share findings

<blockquote>
Not just compliance—a fundamental improvement in security observability.
</blockquote>

---

<!-- References -->
## References

![bg left:33%](./img/canada-1.png)

1. Tetragon Documentation. https://tetragon.cilium.io/docs/
2. eBPF.io - Introduction to eBPF. https://ebpf.io/
3. Starovoitov, A. (2014). "BPF: the universal in-kernel virtual machine." LWN.net.
4. Rice, L. (2020). *What is eBPF?* O'Reilly Media.
5. McCanne, S. & Jacobson, V. (1993). "The BSD Packet Filter." USENIX Winter 1993.
6. Cilium Tetragon GitHub. https://github.com/cilium/tetragon
7. Linux Kernel Source: `kernel/bpf/verifier.c`

<blockquote>
Building on decades of research and development.
</blockquote>

---

<!-- Thank You -->
<!-- _class: lead -->
# Thank You

### Questions?

<br>

###### *Statistics Canada | Statistique Canada*
![bg left:33%](./img/canada-1.png)
