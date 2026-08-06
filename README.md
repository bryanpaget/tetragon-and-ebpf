[English](#english) | [Français](#français)

<a id="english"></a>

# Tetragon and eBPF: A Comprehensive Foundation

## From Observability to Kernel Internals

**Date:** 2026-03-30  
**Author:** Bryan Paget, Statistics Canada

---

## About This Repository

This repository contains the source for a bilingual (English/French) research deliverable on Tetragon and eBPF. It builds presentation slides (via [Marp](https://marp.app/)) and technical reports (via [Typst](https://typst.app/)), and publishes the slides as HTML to GitHub Pages.

| Path | Description |
|------|-------------|
| `content/slides-en.md` | English Marp presentation source |
| `content/slides-fr.md` | French Marp presentation source |
| `report/report-en.typ` | English technical report (Typst) |
| `report/report-fr.typ` | French technical report (Typst) |
| `config/header.md` | Shared Marp theme and front-matter |
| `config/landing.html` | GitHub Pages landing page |
| `img/` | Slide images |
| `.github/workflows/` | CI (build), release, and GitHub Pages deployments |

**View the slides online:** <https://bryanpaget.github.io/tetragon-and-ebpf/>

### Build Locally

```bash
make pdf       # EN + FR presentation PDFs (requires marp CLI + Chromium)
make reports   # EN + FR report PDFs (requires typst)
make html      # GitHub Pages site into temp/site
make preview-en / preview-fr   # live slide preview on localhost
```

> **Note on deployments:** a push to `main` builds and deploys the HTML slides to GitHub Pages (source must be set to "GitHub Actions" in the repo's Pages settings). Tagging a release with `v*` builds the PDFs and attaches them to a GitHub Release.

---

## Executive Summary

**Recommendation:** Adopt Tetragon as our eBPF‑based security observability solution and contribute the Helm chart to `cloudnative-platform-charts` for organisation‑wide use.

**What:** Tetragon is an eBPF‑powered security observability tool already running in Aurora clusters. It provides kernel‑level visibility into process, file, and network activity with minimal performance overhead.

**Why now:** Emerging corporate standards require eBPF‑based security solutions. Tetragon directly satisfies this requirement while providing capabilities impossible with userspace‑only tools.

**Risk:** Low. Tetragon is already deployed in Aurora. The eBPF verifier guarantees program safety, and production benchmarks show <1% CPU overhead with typical tracing policies.

**Cost:** Minimal. Tetragon runs as a DaemonSet with ~100‑200 MiB memory per node. CPU overhead typically 0.5‑2% depending on policy complexity—significantly lower than userspace alternatives like Falco.

**Ask:** Approve contribution of the Tetragon Helm chart to `cloudnative-platform-charts` and deployment validation in Zone DEV to generate production‑readiness metrics.

**Next steps:** Port the chart, deploy in Zone DEV, validate performance and integration, then share findings organisation‑wide.

---

## Table of Contents

1. [Tetragon: The Solution](#10-tetragon-the-solution)  
2. [The Foundation: eBPF](#20-the-foundation-ebpf)  
3. [The Principle of Proximity](#30-the-principle-of-proximity)  
4. [Tetragon's eBPF Implementation](#40-tetragons-ebpf-implementation)  
5. [Deployment Plan](#50-deployment-plan)  
6. [Next Steps and Open Questions](#60-next-steps-and-open-questions)  
7. [Conclusion](#70-conclusion)  
8. [References](#80-references)

---

## 1.0 Tetragon: The Solution

**Tetragon** is an eBPF‑based security observability and runtime enforcement tool for Kubernetes. It applies policy and filtering directly with eBPF, allowing for reduced observation overhead, tracking of any process, and real‑time enforcement of policies.

Learn more: [tetragon.io](https://tetragon.io/)

Think of Tetragon as a security camera system for your containers—but one that doesn't just watch the doors and windows (network ports). It watches every action each process takes: every file it opens, every command it executes, every network connection it makes. And because it operates in the kernel, it sees these things as they happen, not after they've been reported up through multiple layers of software.

### 1.1 Why Tetragon?

The tool addresses several critical needs:

- **Compliance:** Directly satisfies the requirement for eBPF‑based security solutions.  
- **Kernel‑Level Visibility:** Provides insights impossible to achieve with userspace‑only tools.  
- **Kubernetes Native:** Integrates seamlessly with our existing infrastructure through CRDs.  
- **Proven in Aurora:** Already running in Aurora clusters, reducing unknowns.  
- **Lightweight:** Production benchmarks show <1% CPU overhead (typically 0.5‑2% depending on policy complexity) with ~100‑200 MiB memory per node—significantly lower than userspace alternatives like Falco.

### 1.2 Current Status and Path Forward

Tetragon is enabled in Aurora clusters as of February 2026. Its migration to `cloudnative-platform-charts` is planned, but no timeline exists. This presents an opportunity: we can accelerate adoption by contributing the chart ourselves and validating in Zone DEV.

**Zone DEV:** A safe, non‑production Kubernetes environment where we can experiment with new technologies without risking production workloads or data.

### 1.3 Tetragon Architecture

![Tetragon Architecture Diagram](https://tetragon.io/svgs/diagram-illustration.svg)

*Figure: Tetragon operates in kernel space via eBPF, capturing events at the source and enriching them with Kubernetes metadata before export to userspace.*

---

## 2.0 The Foundation: eBPF

To understand Tetragon, we must understand the technology that makes it possible: eBPF.

### 2.1 Historical Context: From Packet Filter to Virtual Machine

**Packet filtering** inspects network packets as they arrive at or leave a network interface, deciding whether to allow, drop, or modify each packet based on configurable rules.

This was the original problem that led to Berkeley Packet Filter (BPF) in 1992. The challenge is fundamental: packets arrive at millions per second. To keep up, filtering must happen inside the kernel, as close to the hardware as possible. Classic BPF provided a simple, safe virtual machine for exactly this purpose.

Over three decades, the utility of running safe programs inside the kernel became apparent for far more than packet filtering. This led to extended BPF (eBPF) in 2014.

**eBPF** is a general‑purpose in‑kernel virtual machine that safely runs user‑supplied programs. It provides:
- A well‑defined instruction set  
- A verifier guaranteeing program safety  
- Access to kernel data via helper functions  
- Efficient communication with userspace  
- Attachment to diverse kernel events

### 2.2 Core eBPF Concepts

For Tetragon's real‑time threat monitoring, eBPF attaches small programs to kernel events. When specific hooks fire—like a process executing or a file opening—the eBPF program runs and captures the event.

**eBPF Program:** A finite sequence of RISC‑like instructions operating on 64‑bit registers and a 512‑byte stack.  
**Hook:** A kernel location where eBPF programs attach. When execution reaches that location, the program runs.

Common hooks Tetragon uses:
- `kprobe`/`kretprobe`: Dynamic instrumentation of any kernel function  
- `tracepoint`: Statically defined kernel trace points  
- `cgroup‑bpf`: Per‑container system call and network operation hooks  
- `LSM`: Security policy enforcement points

**eBPF Map:** A kernel‑resident data structure (hash table, array, ring buffer) enabling communication between eBPF programs and userspace.  
**Verifier:** A static analysis subsystem that checks every eBPF program before execution, ensuring safety constraints are met.  
**Helper Function:** A kernel function that eBPF programs may call to perform operations like map lookups, random number generation, or event output.

### 2.3 The Safety Guarantees

The verifier's guarantees are what make eBPF safe enough to run in production kernels:

**Termination:** Every valid eBPF program is guaranteed to terminate. The verifier analyses the control‑flow graph and rejects any program containing unbounded loops. This prevents infinite loops in the kernel.

**Memory Safety:** eBPF programs cannot access kernel memory outside their designated stack, map memory, or context. The verifier tracks every memory access, preventing corruption of kernel data structures.

**Resource Boundedness:** Every eBPF program has statically known upper bounds on execution time and memory usage. Maximum instruction count, stack size (512 bytes), and map sizes are all checked. This ensures predictable, low overhead even on high‑frequency hooks.

### 2.4 eBPF Architecture

![eBPF Architecture Diagram](https://ebpf.io/static/e293240ecccb9d506587571007c36739/691bc/overview.webp)

*Figure: eBPF programs run safely in the kernel, attached to various hook points (kprobes, tracepoints, LSM), with the verifier ensuring safety before loading.*

---

## 3.0 The Principle of Proximity

**Move computation to where data resides.**

Modern computing systems face a fundamental challenge: moving data between components often costs more than the actual computation. The Principle of Proximity states that latency is minimised when computation occurs as close as possible to where data resides.

**Examples across computing:**
- **Hardware:** Apple M‑series Unified Memory eliminates PCIe overhead (500+ GB/s bandwidth).  
- **Gaming:** NTSYNC keeps thread synchronisation in‑kernel (778% FPS improvement in multi‑threaded games).  
- **Security:** eBPF processes events at source, before copying to userspace.

**Relevance to Tetragon:** Tetragon embodies this principle by running security monitoring programs *inside the kernel* via eBPF. Instead of copying system events to user space for analysis, it processes them at their source—the kernel hooks where they occur. This minimises latency and provides real‑time visibility impossible with traditional audit approaches.

---

## 4.0 Tetragon's eBPF Implementation

With the foundation established, we can now understand precisely how Tetragon uses eBPF.

### 4.1 Key Tetragon Components

**TracingPolicy:** A Kubernetes Custom Resource Definition (CRD) that defines what events Tetragon should trace and how to react. Policies specify hooks (e.g., `execve` system calls), match conditions (e.g., specific binaries), and actions (e.g., generate event, terminate process).

**Tetragon Agent:** A DaemonSet running on each node that loads eBPF programs based on TracingPolicies, collects events from eBPF maps, and exports them to configured sinks (stdout, ELK, etc.).

### 4.2 How Tetragon Uses eBPF Hooks

| Observability Target | eBPF Hook Type | Kernel Function/Event |
|----------------------|----------------|------------------------|
| Process execution    | Tracepoint     | `sys_enter_execve`      |
| File access          | Kprobe         | `vfs_read`              |
| Network connections  | Kprobe         | `tcp_connect`           |
| DNS queries          | Kprobe         | `udp_recvmsg` (DPort 53) |

**Why these hooks?**
- `sys_*` – system call entry/exit (high‑level process activity).  
- `vfs_*` – virtual filesystem layer (file operations).  
- `tcp_*`, `udp_*` – network stack (connections and DNS).

**In our Kubeflow cluster:**

- **Jupyter notebook pods** – Detect shell escapes via `sys_execve` when `/bin/sh` or `/bin/bash` spawns from a notebook process.  
- **Training jobs** – Catch credential access via `vfs_read` on `/etc/shadow`, `/etc/passwd`, or `~/.kube/config`.  
- **Inference endpoints** – Monitor external connections via `tcp_connect` to IPs outside the cluster CIDR.

### 4.3 Example TracingPolicy

Here's what a real policy looks like:

```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: "trace-sensitive-commands"
spec:
  kprobes:
  - call: "sys_execve"
    syscall: true
    args:
    - index: 0
      type: "string"
    selectors:
    - matchBinaries:
      - operator: "In"
        values:
        - "/bin/bash"
        - "/bin/sh"
      matchArgs:
      - index: 0
        operator: "Contains"
        values:
        - "passwd"
        - "shadow"
```

This policy attaches to the `execve` system call, captures the command line argument, and generates an event whenever bash or sh executes a command containing `passwd` or `shadow`—potential credential access. The eBPF program runs in the kernel, sees the execve as it happens, and can immediately signal userspace.

**Example output event:**

```json
{
  "process_exec": {
    "process": {
      "exec_id": "V29ya2VyLW5vZGUtMDE6MTIzNDU2Nzg5MA==",
      "pid": 12345,
      "ppid": 12340,
      "binary": "/bin/bash",
      "arguments": "cat /etc/passwd",
      "cwd": "/home/user",
      "pod": {
        "namespace": "default",
        "name": "test-pod"
      }
    }
  },
  "node_name": "worker-node-01",
  "time": "2026-03-23T14:32:15.123Z"
}
```

---

## 5.0 Deployment Plan

### 5.1 Installation

```bash
# 1. Add the Cilium Helm repository
helm repo add cilium https://helm.cilium.io
helm repo update

# 2. Create namespace and install Tetragon
helm install tetragon cilium/tetragon -n tetragon --create-namespace

# 3. Verify installation
kubectl -n tetragon get pods
# Should see tetragon-* DaemonSet pods running
```

### 5.2 Deploy a TracingPolicy (Credential Access Detection)

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

### 5.3 View Events in Real‑Time

```bash
# Port‑forward to Tetragon pod
kubectl port-forward -n tetragon ds/tetragon 54321:54321

# View events in compact format
tetra getevents -o compact
```

### 5.4 Interacting with Tetragon

Tetragon has no dedicated UI—it integrates with existing tools:

**CLI (`tetra`):**
```bash
# Stream all events
tetra getevents -o compact

# Filter by namespace and pod
tetra getevents --namespace default \
  --pods my-app
```

**TracingPolicies as Code:**
- YAML configuration, versioned in Git.  
- Deployed via ArgoCD (GitOps).  

**Event Export & Dashboards:**
- Export to Elasticsearch, Kafka, or stdout.  
- Build Grafana dashboards using Elasticsearch as a data source.

**gRPC API:**
```python
import grpc
from tetragon import sensors_pb2_grpc, events_pb2

channel = grpc.insecure_channel("localhost:54321")
stub = sensors_pb2_grpc.FineGuidanceSensorsStub(channel)

for event in stub.GetEvents(events_pb2.GetEventsRequest()):
    print(event)
```

### 5.5 Prerequisites

- Linux kernel ≥ 4.19 (5.4+ recommended for full eBPF features).  
- Helm 3 installed.  
- `kubectl` configured with cluster access.  
- BTF (BPF Type Format) support for CO‑RE compatibility.

### 5.6 Aurora Configuration

Configuration validated in Aurora:

- **Namespace:** `tetragon-system`  
- **Pod Security:** `privileged` (required for eBPF)  
- **Istio Injection:** Disabled  
- **Resource Quota:** 60 pods  
- **Agent:** DaemonSet (runs on every node)  
- **Operator:** Deployment (centralised control)  
- **Network Policies:** Same‑namespace, API server CIDR, konnectivity‑agent  
- **Status:** Experimental in Aurora

---

## 6.0 Next Steps and Open Questions

### 6.1 Immediate Actions

1. **Chart Porting:** Create PR adding Tetragon to `cloudnative-platform-charts` based on the Aurora implementation.  
2. **DEV Deployment:** Execute Zone DEV deployment as described in Section 5.  
3. **Documentation:** Share findings with the team via this document and the accompanying presentation.

### 6.2 Questions for Investigation

- What is the performance overhead under production load?  
- How do TracingPolicies interact with existing security tools?  
- What is the upgrade path for eBPF programs as kernel versions change?  
- How should events be ingested into our monitoring stack (ELK, Splunk, etc.)?

### 6.3 Implementation Roadmap

**Phase 1: Validation in DEV (Weeks 1–2)**  
- Deploy Tetragon via Helm with AKS‑specific values.  
- Deploy baseline TracingPolicies (process execution, file access, network).  
- Configure event export to a test Elasticsearch index.  
- Establish baseline metrics (CPU <1%, memory <200 MiB per node).

**Phase 2: Production Readiness (Weeks 3–4)**  
- Define SLOs: event latency <100 ms, throughput 10,000 events/s, 99.9% availability.  
- Create Terraform module for `cloudnative-platform-charts`.  
- Add Tetragon to cluster provisioning scripts.  
- Document upgrade procedures.

**Phase 3: Integration and Automation (Weeks 5–6)**  
- Create CI/CD pipeline for TracingPolicy updates.  
- Implement alerting (PagerDuty for critical events, Slack for high severity).  
- Document runbooks, troubleshooting guides, and policy guidelines.

---

## 7.0 Conclusion

This research has established a comprehensive foundation: Tetragon provides the security observability we need, eBPF provides the safe, efficient kernel technology that makes it possible, and the Principle of Proximity explains *why* eBPF‑based approaches are so powerful. By moving computation to where data lives—whether in unified memory architectures, kernel bypass networking, or near‑data processing—we achieve performance and insight impossible with traditional layered approaches.

Tetragon represents not just a compliance checkbox but a fundamental improvement in how we can observe and secure our systems. The path forward is clear: port the chart, deploy in DEV, validate, and share our findings.

---

## 8.0 References

**Tetragon & eBPF:**

1. [Tetragon Documentation](https://tetragon.io/docs/)
2. [Tetragon Installation Guide](https://tetragon.io/docs/installation/kubernetes/)
3. [eBPF.io – Introduction to eBPF](https://ebpf.io/)

**Technical Resources:**

4. Starovoitov, A. (2014). ["BPF: the universal in‑kernel virtual machine."](https://lwn.net/Articles/599755/) LWN.net.
5. Rice, L. (2020). *Learning eBPF*. O'Reilly Media.
6. McCanne, S. & Jacobson, V. (1993). ["The BSD Packet Filter."](https://www.tcpdump.org/papers/bpf-usenix93.pdf) USENIX Winter 1993.

**Linux Kernel:**

7. Linux Kernel Source: `kernel/bpf/verifier.c`

**Aurora Implementation:**

8. [Aurora Platform Charts](https://github.com/gccloudone-aurora/aurora-platform-charts)

---

<a id="français"></a>

# Tetragon et eBPF : Une base complète

## Des exigences organisationnelles aux rouages du noyau

**Date :** 2026-03-30  
**Auteur :** Bryan Paget, Statistique Canada

---

## Résumé

**Recommandation :** Adopter Tetragon comme solution d'observabilité de sécurité basée sur eBPF et contribuer le chart Helm à `cloudnative-platform-charts` pour une utilisation organisationnelle.

**Quoi :** Tetragon est un outil d'observabilité de sécurité alimenté par eBPF, déjà en cours d'exécution dans nos grappes Aurora. Il fournit une visibilité au niveau du noyau sur l'activité des processus, des fichiers et du réseau avec un impact minimal sur les performances.

**Pourquoi maintenant :** Les normes organisationnelles émergentes exigent des solutions de sécurité basées sur eBPF. Tetragon satisfait directement cette exigence tout en fournissant des capacités impossibles avec les outils uniquement dans l'espace utilisateur.

**Risque :** Faible. Tetragon est déjà déployé dans Aurora. Le vérificateur eBPF garantit la sécurité des programmes, et les benchmarks de production montrent moins de 1% de surcharge CPU avec des politiques de traçage typiques.

**Coût :** Minimal. Tetragon s'exécute comme un DaemonSet avec ~100-200 MiB de mémoire par nœud. La surcharge CPU est typiquement de 0,5-2% selon la complexité des politiques—nettement inférieure aux alternatives dans l'espace utilisateur comme Falco.

**Demande :** Approuver la contribution du chart Helm Tetragon à `cloudnative-platform-charts` et le déploiement de validation dans DEV de la Zone pour générer des métriques de maturité en production.

**Prochaines étapes :** Porter le chart, déployer dans DEV de la Zone, valider les performances et l'intégration, puis partager les découvertes à l'échelle de l'organisation.

---

## Table des matières

1. [Tetragon : La solution](#10-tetragon-la-solution)  
2. [Le fondement : eBPF](#20-le-fondement-ebpf)  
3. [Le principe de proximité](#30-le-principe-de-proximité)  
4. [Implémentation eBPF de Tetragon](#40-implémentation-ebpf-de-tetragon)  
5. [Plan de déploiement](#50-plan-de-déploiement)  
6. [Prochaines étapes et questions ouvertes](#60-prochaines-étapes-et-questions-ouvertes)  
7. [Conclusion](#70-conclusion)  
8. [Références](#80-références)

---

## 1.0 Tetragon : La solution

**Tetragon** est un outil d'observabilité de sécurité et d'application d'exécution basées sur eBPF pour Kubernetes. Il applique des politiques et des filtres directement avec eBPF, permettant une surveillance réduite, le suivi de tout processus et l'application de politiques en temps réel.

En savoir plus : [tetragon.io](https://tetragon.io/)

Considérez Tetragon comme un système de caméras de sécurité pour vos conteneurs—mais qui ne surveille pas seulement les portes et fenêtres (ports réseau). Il surveille chaque action de chaque processus : chaque fichier qu'il ouvre, chaque commande qu'il exécute, chaque connexion réseau qu'il établit. Et parce qu'il opère dans le noyau, il voit ces choses au moment où elles se produisent, pas après qu'elles aient été signalées à travers plusieurs couches de logiciels.

### 1.1 Pourquoi Tetragon ?

L'outil répond à plusieurs besoins critiques :

- **Conformité organisationnelle :** Satisfait directement l'exigence de solutions de sécurité basées sur eBPF.  
- **Visibilité au niveau du noyau :** Fournit des aperçus impossibles à obtenir avec des outils uniquement dans l'espace utilisateur.  
- **Natif Kubernetes :** S'intègre parfaitement à notre infrastructure existante via des CRD.  
- **Éprouvé dans Aurora :** Déjà en cours d'exécution dans les grappes Aurora, réduisant les inconnues.  
- **Léger :** Les benchmarks de production montrent moins de 1% de surcharge CPU (typiquement 0,5-2% selon la complexité des politiques) avec ~100-200 MiB de mémoire par nœud—nettement inférieur aux alternatives dans l'espace utilisateur comme Falco.

### 1.2 État actuel et voie à suivre

Tetragon est activé dans les grappes Aurora depuis février 2026. Sa migration vers `cloudnative-platform-charts` est prévue, mais aucun calendrier n'existe. Cela présente une opportunité : nous pouvons accélérer l'adoption en contribuant nous‑mêmes le chart et en validant dans DEV de la Zone.

**DEV de la Zone :** Un environnement Kubernetes sûr, hors production, où nous pouvons expérimenter de nouvelles technologies sans risquer les charges de travail ou les données de production.

### 1.3 Architecture Tetragon

![Diagramme d'architecture Tetragon](https://tetragon.io/svgs/diagram-illustration.svg)

*Figure : Tetragon opère dans l'espace noyau via eBPF, capturant les événements à la source et les enrichissant avec les métadonnées Kubernetes avant l'export vers l'espace utilisateur.*

---

## 2.0 Le fondement : eBPF

Pour comprendre Tetragon, nous devons comprendre la technologie qui le rend possible : eBPF.

### 2.1 Contexte historique : Du filtre de paquets à la machine virtuelle

Le **filtrage de paquets** inspecte les paquets réseau à leur arrivée ou départ d'une interface réseau, décidant d'autoriser, rejeter ou modifier chaque paquet selon des règles configurables.

C'était le problème initial qui a conduit au Berkeley Packet Filter (BPF) en 1992. Le défi est fondamental : les paquets arrivent par millions par seconde. Pour suivre, le filtrage doit se faire dans le noyau, aussi près que possible du matériel. Le BPF classique fournissait une machine virtuelle simple et sûre exactement dans ce but.

Au cours de trois décennies, l'utilité d'exécuter des programmes sûrs à l'intérieur du noyau est devenue apparente pour bien plus que le filtrage de paquets. Cela a conduit au BPF étendu (eBPF) en 2014.

**eBPF** est une machine virtuelle dans le noyau à usage général qui exécute en toute sécurité des programmes fournis par l'utilisateur. Il fournit :
- Un jeu d'instructions bien défini  
- Un vérificateur garantissant la sécurité des programmes  
- Un accès aux données du noyau via des fonctions auxiliaires  
- Une communication efficace avec l'espace utilisateur  
- Une attache à divers événements du noyau

### 2.2 Concepts de base d'eBPF

Pour la surveillance des menaces en temps réel de Tetragon, eBPF attache de petits programmes aux événements du noyau. Lorsque des hooks spécifiques se déclenchent—comme un processus qui s'exécute ou un fichier qui s'ouvre—le programme eBPF s'exécute et capture l'événement.

**Programme eBPF :** Une séquence finie d'instructions de type RISC opérant sur des registres 64 bits et une pile de 512 octets.  
**Point d'attache :** Un emplacement du noyau où les programmes eBPF s'attachent. Lorsque l'exécution atteint cet emplacement, le programme s'exécute.

Les points d'attache courants que Tetragon utilise :
- `kprobe`/`kretprobe` : Instrumentation dynamique de toute fonction du noyau  
- `tracepoint` : Points de trace du noyau statiquement définis  
- `cgroup-bpf` : Points d'attache des appels système et opérations réseau par conteneur  
- `LSM` : Points d'application de la politique de sécurité

**Carte eBPF :** Une structure de données résidente dans le noyau (table de hachage, tableau, tampon en anneau) permettant la communication entre les programmes eBPF et l'espace utilisateur.  
**Vérificateur :** Un sous‑système d'analyse statique qui vérifie chaque programme eBPF avant l'exécution, garantissant que les contraintes de sécurité sont respectées.  
**Fonction auxiliaire :** Une fonction du noyau que les programmes eBPF peuvent appeler pour effectuer des opérations comme des recherches dans les cartes, la génération de nombres aléatoires ou la sortie d'événements.

### 2.3 Les garanties de sécurité

Les garanties du vérificateur rendent eBPF suffisamment sûr pour s'exécuter dans des noyaux de production :

**Terminaison :** Tout programme eBPF valide est garanti de se terminer. Le vérificateur analyse le graphe de flot de contrôle et rejette tout programme contenant des boucles non bornées. Cela prévient les boucles infinies dans le noyau.

**Sécurité mémoire :** Les programmes eBPF ne peuvent pas accéder à la mémoire du noyau en dehors de leur pile désignée, de la mémoire des cartes, ou de leur contexte. Le vérificateur suit chaque accès mémoire, prévenant la corruption des structures de données du noyau.

**Bornitude des ressources :** Tout programme eBPF a des bornes supérieures statiquement connues sur le temps d'exécution et l'utilisation de la mémoire. Le nombre maximal d'instructions, la taille de la pile (512 octets), et les tailles des cartes sont tous vérifiés. Cela assure une surcharge faible et prévisible même sur des hooks à haute fréquence.

### 2.4 Architecture eBPF

![Diagramme d'architecture eBPF](https://ebpf.io/static/e293240ecccb9d506587571007c36739/691bc/overview.webp)

*Figure : Les programmes eBPF s'exécutent en toute sécurité dans le noyau, attachés à divers points d'attache (kprobes, tracepoints, LSM), le vérificateur assurant la sécurité avant le chargement.*

---

## 3.0 Le principe de proximité

**Déplacer le calcul vers les données.**

Les systèmes informatiques modernes font face à un défi fondamental : déplacer des données entre les composants coûte souvent plus que le calcul réel. Le principe de proximité stipule que la latence est minimisée lorsque le calcul se produit aussi près que possible de l'endroit où les données résident.

**Exemples dans l'informatique :**
- **Matériel :** Mémoire unifiée Apple M‑series élimine la surcharge PCIe (500+ Go/s de bande passante).  
- **Jeux :** NTSYNC garde la synchronisation dans le noyau (778 % d'amélioration FPS).  
- **Sécurité :** eBPF traite les événements à la source, avant copie vers l'espace utilisateur.

**Pertinence pour Tetragon :** Tetragon incarne ce principe en exécutant des programmes de surveillance de sécurité *à l'intérieur du noyau* via eBPF. Au lieu de copier les événements système vers l'espace utilisateur pour analyse, il les traite à leur source—les points d'attache du noyau où ils se produisent. Cela minimise la latence et fournit une visibilité en temps réel impossible avec les approches d'audit traditionnelles.

---

## 4.0 Implémentation eBPF de Tetragon

Avec la base établie, nous pouvons maintenant comprendre précisément comment Tetragon utilise eBPF.

### 4.1 Composants clés de Tetragon

**TracingPolicy :** Une définition de ressource personnalisée (CRD) Kubernetes qui définit quels événements Tetragon doit tracer et comment réagir. Les politiques spécifient les points d'attache (par exemple, appels système `execve`), les conditions de correspondance (par exemple, binaires spécifiques), et les actions (par exemple, générer un événement, terminer un processus).

**Agent Tetragon :** Un DaemonSet s'exécutant sur chaque nœud qui charge des programmes eBPF basés sur des TracingPolicies, collecte les événements des cartes eBPF, et les exporte vers des destinations configurées (stdout, ELK, etc.).

### 4.2 Comment Tetragon utilise les points d'attache eBPF

| Cible d'observabilité | Type de point d'attache eBPF | Fonction/Événement du noyau |
|-----------------------|-----------------------------|-----------------------------|
| Exécution de processus | Tracepoint                  | `sys_enter_execve`           |
| Accès aux fichiers     | Kprobe                      | `vfs_read`                   |
| Connexions réseau      | Kprobe                      | `tcp_connect`                |
| Requêtes DNS           | Kprobe                      | `udp_recvmsg` (port 53)      |

**Pourquoi ces hooks ?**
- `sys_*` – entrée/sortie des appels système (activité de processus de haut niveau).  
- `vfs_*` – couche de système de fichiers virtuel (opérations sur les fichiers).  
- `tcp_*`, `udp_*` – pile réseau (connexions et DNS).

**Dans notre grappe Kubeflow :**

- **Pods Jupyter notebook** – Détecter les échappements de shell via `sys_execve` quand `/bin/sh` ou `/bin/bash` est lancé depuis un processus notebook.  
- **Tâches d'entraînement** – Capturer l'accès aux identifiants via `vfs_read` sur `/etc/shadow`, `/etc/passwd` ou `~/.kube/config`.  
- **Points de terminaison d'inférence** – Surveiller les connexions externes via `tcp_connect` vers des IPs hors CIDR de la grappe.

### 4.3 Exemple de TracingPolicy

Voici à quoi ressemble une politique réelle :

```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: "trace-sensitive-commands"
spec:
  kprobes:
  - call: "sys_execve"
    syscall: true
    args:
    - index: 0
      type: "string"
    selectors:
    - matchBinaries:
      - operator: "In"
        values:
        - "/bin/bash"
        - "/bin/sh"
      matchArgs:
      - index: 0
        operator: "Contains"
        values:
        - "passwd"
        - "shadow"
```

Cette politique s'attache à l'appel système `execve`, capture l'argument de ligne de commande, et génère un événement chaque fois que bash ou sh exécute une commande contenant `passwd` ou `shadow`—accès potentiel aux identifiants. Le programme eBPF s'exécute dans le noyau, voit l'execve au moment où il se produit, et peut immédiatement signaler l'espace utilisateur.

**Exemple de sortie d'événement :**

```json
{
  "process_exec": {
    "process": {
      "exec_id": "V29ya2VyLW5vZGUtMDE6MTIzNDU2Nzg5MA==",
      "pid": 12345,
      "ppid": 12340,
      "binary": "/bin/bash",
      "arguments": "cat /etc/passwd",
      "cwd": "/home/user",
      "pod": {
        "namespace": "default",
        "name": "test-pod"
      }
    }
  },
  "node_name": "worker-node-01",
  "time": "2026-03-23T14:32:15.123Z"
}
```

---

## 5.0 Plan de déploiement

### 5.1 Installation

```bash
# 1. Ajouter le dépôt Helm Cilium
helm repo add cilium https://helm.cilium.io
helm repo update

# 2. Créer le namespace et installer Tetragon
helm install tetragon cilium/tetragon -n tetragon --create-namespace

# 3. Vérifier l'installation
kubectl -n tetragon get pods
# Devrait voir les pods DaemonSet tetragon-* en cours d'exécution
```

### 5.2 Déployer une TracingPolicy (Détection d'accès aux identifiants)

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

### 5.3 Voir les événements en temps réel

```bash
# Port-forward vers un pod Tetragon
kubectl port-forward -n tetragon ds/tetragon 54321:54321

# Voir les événements en format compact
tetra getevents -o compact
```

### 5.4 Interagir avec Tetragon

Tetragon n'a pas d'interface utilisateur dédiée—il s'intègre aux outils existants :

**CLI (`tetra`) :**
```bash
# Diffuser tous les événements
tetra getevents -o compact

# Filtrer par namespace et pod
tetra getevents --namespace default \
  --pods my-app
```

**TracingPolicies comme code :**
- Configuration YAML, versionnée dans Git.  
- Déployée via ArgoCD (GitOps).  

**Export d'événements et tableaux de bord :**
- Exporter vers Elasticsearch, Kafka ou stdout.  
- Construire des tableaux de bord Grafana en utilisant Elasticsearch comme source de données.

**API gRPC :**
```python
import grpc
from tetragon import sensors_pb2_grpc, events_pb2

channel = grpc.insecure_channel("localhost:54321")
stub = sensors_pb2_grpc.FineGuidanceSensorsStub(channel)

for event in stub.GetEvents(events_pb2.GetEventsRequest()):
    print(event)
```

### 5.5 Prérequis

- Noyau Linux ≥ 4.19 (5.4+ recommandé pour les fonctionnalités eBPF complètes).  
- Helm 3 installé.  
- `kubectl` configuré avec accès à la grappe.  
- Support BTF (BPF Type Format) pour la compatibilité CO‑RE.

### 5.6 Configuration Aurora

Configuration validée dans Aurora :

- **Namespace :** `tetragon-system`  
- **Sécurité des pods :** `privileged` (requis pour eBPF)  
- **Injection Istio :** Désactivée  
- **Quota de ressources :** 60 pods  
- **Agent :** DaemonSet (s'exécute sur chaque nœud)  
- **Opérateur :** Deployment (contrôle centralisé)  
- **Politiques réseau :** Même namespace, CIDR API server, konnectivity‑agent  
- **Statut :** Expérimental dans Aurora

---

## 6.0 Prochaines étapes et questions ouvertes

### 6.1 Actions immédiates

1. **Portage du chart :** Créer une PR ajoutant Tetragon à `cloudnative-platform-charts` basée sur l'implémentation d'Aurora.  
2. **Déploiement DEV :** Exécuter le déploiement DEV de la Zone selon la section 5.  
3. **Documentation :** Partager les découvertes avec l'équipe via ce document et la présentation accompagnante.

### 6.2 Questions à investiguer

- Quelle est la surcharge de performance sous charge de production ?  
- Comment les TracingPolicies interagissent-elles avec les outils de sécurité existants ?  
- Quel est le chemin de mise à niveau pour les programmes eBPF lors des changements de version du noyau ?  
- Comment les événements doivent-ils être ingérés dans notre pile de surveillance (ELK, Splunk, etc.) ?

### 6.3 Feuille de route de mise en œuvre

**Phase 1 : Validation en DEV (semaines 1‑2)**  
- Déployer Tetragon via Helm avec des valeurs spécifiques à AKS.  
- Déployer des TracingPolicies de base (exécution de processus, accès aux fichiers, réseau).  
- Configurer l'export des événements vers un index Elasticsearch de test.  
- Établir des métriques de base (CPU <1%, mémoire <200 MiB par nœud).

**Phase 2 : Préparation à la production (semaines 3‑4)**  
- Définir des SLO : latence des événements <100 ms, débit 10 000 événements/s, disponibilité 99,9%.  
- Créer un module Terraform pour `cloudnative-platform-charts`.  
- Ajouter Tetragon aux scripts de provisionnement des grappes.  
- Documenter les procédures de mise à niveau.

**Phase 3 : Intégration et automatisation (semaines 5‑6)**  
- Créer un pipeline CI/CD pour les mises à jour de TracingPolicy.  
- Mettre en place une alerte (PagerDuty pour les événements critiques, Slack pour les sévérités élevées).  
- Documenter les manuels d'exploitation, les guides de dépannage et les directives relatives aux politiques.

---

## 7.0 Conclusion

Cette recherche a établi une base complète : Tetragon fournit l'observabilité de sécurité dont nous avons besoin, eBPF fournit la technologie de noyau sûre et efficace qui le rend possible, et le Principe de Proximité explique *pourquoi* les approches basées sur eBPF sont si puissantes. En déplaçant le calcul là où les données vivent—que ce soit dans des architectures mémoire unifiées, la mise en réseau avec contournement du noyau, ou le traitement près des données—nous atteignons des performances et des aperçus impossibles avec des approches traditionnelles en couches.

Tetragon représente non seulement une case de conformité à cocher, mais une amélioration fondamentale dans la façon dont nous pouvons observer et sécuriser nos systèmes. La voie à suivre est claire : porter le chart, déployer en DEV, valider, et partager nos découvertes.

---

## 8.0 Références

**Tetragon et eBPF :**
1. [Documentation Tetragon](https://tetragon.io/docs/)  
2. [Guide d'installation Tetragon](https://tetragon.io/docs/installation/kubernetes/)  
3. [eBPF.io – Introduction à eBPF](https://ebpf.io/)

**Ressources techniques :**
4. Starovoitov, A. (2014). ["BPF: the universal in‑kernel virtual machine."](https://lwn.net/Articles/599755/) LWN.net.  
5. Rice, L. (2020). *Learning eBPF*. O'Reilly Media.  
6. McCanne, S. & Jacobson, V. (1993). ["The BSD Packet Filter."](https://www.tcpdump.org/papers/bpf-usenix93.pdf) USENIX Winter 1993.

**Noyau Linux :**
7. Source du noyau Linux : `kernel/bpf/verifier.c`

**Implémentation Aurora :**
8. [Aurora Platform Charts](https://github.com/gccloudone-aurora/aurora-platform-charts)
