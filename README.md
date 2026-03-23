[English](#english) | [Français](#français)

<a id="english"></a>

# Tetragon and eBPF: A Comprehensive Foundation

## From Observibility to Kernel Internals

**Date:** 2026-03-23
**Author:** Bryan Paget, Statistics Canada

---

## Executive Summary

**Recommendation:** Adopt Tetragon as our eBPF-based security observability solution and contribute the Helm chart to `cloudnative-platform-charts` for organization-wide use.

**What:** Tetragon is an eBPF-powered security observability tool already running experimentally in Aurora clusters. It provides kernel-level visibility into process, file, and network activity with minimal performance overhead.

**Why now:** Emerging corporate standards require eBPF-based security solutions. Tetragon directly satisfies this requirement while providing capabilities impossible with userspace-only tools.

**Risk:** Low. Tetragon is already deployed experimentally in Aurora. The eBPF verifier guarantees program safety, and production benchmarks show <1% CPU overhead with typical tracing policies.

**Cost:** Minimal. Tetragon runs as a DaemonSet with ~100-200 MiB memory per node. CPU overhead typically 0.5-2% depending on policy complexity—significantly lower than userspace alternatives like Falco.

**Ask:** Approve contribution of Tetragon Helm chart to `cloudnative-platform-charts` and deployment validation in Zone DEV to generate production-readiness metrics.

**Next steps:** Port the chart, deploy in Zone DEV, validate performance and integration, then share findings organization-wide.

---

## Table of Contents

1. [Tetragon: The Solution](#10-tetragon-the-solution)
2. [The Foundation: eBPF](#20-the-foundation-ebpf)
3. [The Principle of Proximity](#30-the-principle-of-proximity)
4. [Tetragon's eBPF Implementation](#40-tetragons-ebpf-implementation)
5. [Deployment Plan](#50-deployment-plan)
6. [Next Steps](#60-next-steps-and-open-questions)
7. [Conclusion](#70-conclusion)
8. [References](#80-references)

---

## 1.0 Tetragon: The Solution

**Tetragon** is a Kubernetes-aware security observability and runtime enforcement tool that leverages eBPF to provide deep visibility into process, file, and network activity at the Linux kernel level. It enables real-time detection of and response to security threats with minimal performance overhead.

Think of Tetragon as a security camera system for your containers—but one that doesn't just watch the doors and windows (network ports). It watches every action each process takes: every file it opens, every command it executes, every network connection it makes. And because it operates in the kernel, it sees these things as they happen, not after they've been reported up through multiple layers of software.

### 1.1 Why Tetragon?

The tool addresses several critical needs:

- **Compliance:** Directly satisfies the requirement for eBPF-based security solutions
- **Kernel-Level Visibility:** Provides insights impossible to achieve with userspace-only tools
- **Kubernetes Native:** Integrates seamlessly with our existing infrastructure through CRDs
- **Proven in Aurora:** Already running experimentally in Aurora, reducing unknowns
- **Lightweight:** Production benchmarks show <1% CPU overhead (typically 0.5-2% depending on policy complexity) with ~100-200 MiB memory per node—significantly lower than userspace alternatives like Falco

### 1.2 Current Status and Path Forward

Tetragon is enabled experimentally in Aurora. It is planned for migration to `cloudnative-platform-charts`, though no timeline exists. This presents an opportunity: we can accelerate adoption by contributing the chart ourselves and validating in Zone DEV.

---

## 2.0 The Foundation: eBPF

To understand Tetragon, we must understand the technology that makes it possible: eBPF.

### 2.1 Historical Context: From Packet Filter to Virtual Machine

**Packet filtering** inspects network packets as they arrive at or leave a network interface, deciding whether to allow, drop, or modify each packet based on configurable rules.

This was the original problem that led to Berkeley Packet Filter (BPF) in 1992. The challenge is fundamental: packets arrive at millions per second. To keep up, filtering must happen inside the kernel, as close to the hardware as possible. Classic BPF provided a simple, safe virtual machine for exactly this purpose.

Over three decades, the utility of running safe programs inside the kernel became apparent for far more than packet filtering. This led to extended BPF (eBPF) in 2014.

**eBPF** is a general-purpose in-kernel virtual machine that safely runs user-supplied programs. It provides:
- A well-defined instruction set
- A verifier guaranteeing program safety
- Access to kernel data via helper functions
- Efficient communication with userspace
- Attachment to diverse kernel events

### 2.2 Core eBPF Concepts

For Tetragon's real-time threat monitoring, eBPF attaches small programs to kernel events. When specific hooks fire—like a process executing or a file opening—the eBPF program runs and captures the event.

**eBPF Program:** A finite sequence of RISC-like instructions operating on 64-bit registers and a 512-byte stack.

**Hook:** A kernel location where eBPF programs attach. When execution reaches that location, the program runs.

Common hooks Tetragon uses:
- `kprobe`/`kretprobe`: Dynamic instrumentation of any kernel function
- `tracepoint`: Statically defined kernel trace points
- `cgroup-bpf`: Per-container system call and network operation hooks
- `LSM`: Security policy enforcement points

**eBPF Map:** A kernel-resident data structure (hash table, array, ring buffer) enabling communication between eBPF programs and userspace.

**Verifier:** A static analysis subsystem that checks every eBPF program before execution, ensuring safety constraints are met.

**Helper Function:** A kernel function that eBPF programs may call to perform operations like map lookups, random number generation, or event output.

### 2.3 The Safety Guarantees

The verifier's guarantees are what make eBPF safe enough to run in production kernels:

**Termination:** Every valid eBPF program is guaranteed to terminate. The verifier analyzes the control-flow graph and rejects any program containing unbounded loops. This prevents infinite loops in the kernel.

**Memory Safety:** eBPF programs cannot access kernel memory outside their designated stack, map memory, or context. The verifier tracks every memory access, preventing corruption of kernel data structures.

**Resource Boundedness:** Every eBPF program has statically known upper bounds on execution time and memory usage. Maximum instruction count, stack size (512 bytes), and map sizes are all checked. This ensures predictable, low overhead even on high-frequency hooks.

---

## 3.0 The Principle of Proximity

Modern computing systems face a fundamental challenge: moving data between components (CPU, memory, storage, network) often takes more time and energy than the actual computation. This is the **data movement bottleneck**.

**Principle of Proximity:** Latency and energy consumption are minimized when computation is performed as close as possible to where data resides.

Data traverses interfaces with increasing latency: on-chip caches → main memory → storage → network. Co-locating computation with data reduces or eliminates these movement steps.

This principle appears across system design:

### 3.1 Unified Memory Architecture

**Unified Memory Architecture** places CPU, GPU, and other processors on a single system-on-chip (SoC) sharing one memory pool. Apple's M-series and AMD's "Strix Halo" processors use this approach, achieving 500+ GB/s bandwidth by eliminating data copies between separate memory pools. Just as M-series chips eliminate PCIe bus overhead, eBPF eliminates the kernel→userspace copy for security events.

### 3.2 Zero-Copy and Kernel Bypass

**Zero-copy** techniques eliminate redundant data copies between system components. **Kernel bypass** allows user-space applications direct, safe access to hardware without kernel involvement in the critical path.

eBPF's XDP (eXpress Data Path) exemplifies this: it processes packets at the network driver level, before the kernel network stack, avoiding copies and achieving line-rate packet handling.

**Relevance to Tetragon:** Tetragon embodies this principle by running security monitoring programs *inside the kernel* via eBPF. Instead of copying system events to user space for analysis, it processes them at their source—the kernel hooks where they occur. This minimizes latency and provides real-time visibility impossible with traditional audit approaches.

---

## 4.0 Tetragon's eBPF Implementation

With the foundation established, we can now understand precisely how Tetragon uses eBPF.

### 4.1 Key Tetragon Components

**TracingPolicy:** A Kubernetes Custom Resource Definition (CRD) that defines what events Tetragon should trace and how to react. Policies specify hooks (e.g., `execve` system calls), match conditions (e.g., specific binaries), and actions (e.g., generate event, terminate process).

**Tetragon Agent:** A DaemonSet running on each node that loads eBPF programs based on TracingPolicies, collects events from eBPF maps, and exports them to configured sinks (stdout, ELK, etc.).

### 4.2 How Tetragon Uses eBPF Hooks

| Observability Target | eBPF Hook Type | Kernel Function/Event |
|---------------------|----------------|----------------------|
| Process execution | Tracepoint | `sys_enter_execve`, `sys_exit_execve` |
| File access | Kprobe | `vfs_open`, `vfs_read`, `vfs_write` |
| Network connections | Tracepoint | `tcp_connect`, `udp_sendmsg` |
| DNS queries | Kprobe | `udp_recvmsg` with port 53 filtering |

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

This policy attaches to the `execve` system call, captures the command line argument, and generates an event whenever bash or sh executes a command containing "passwd" or "shadow"—potential credential access. The eBPF program runs in the kernel, sees the execve as it happens, and can immediately signal userspace.

**Example output event:**

```json
{
  "node": "worker-node-01",
  "time": "2026-03-23T14:32:15.123Z",
  "event_type": "process_exec",
  "process": {
    "exec_id": "V29ya2VyLW5vZGUtMDE6MTIzNDU2Nzg5MA==",
    "pid": 12345,
    "ppid": 12340,
    "binary": "/bin/bash",
    "arguments": "cat /etc/passwd",
    "cwd": "/home/user"
  },
  "pod": {
    "namespace": "default",
    "name": "test-pod"
  },
  "action": "generate_event"
}
```

---

## 5.0 Deployment Plan

Based on our research, here are the concrete steps for validation:

### 5.1 Prerequisites

- Access to Zone DEV cluster
- `kubectl` configured
- Helm 3 installed
- Linux kernel ≥ 4.19 (for core eBPF features; 5.4+ recommended)
- BTF (BPF Type Format) support enabled for CO-RE (Compile Once – Run Everywhere) compatibility

**Kernel configuration check:**

```bash
# Check kernel version
uname -r

# Verify BTF support (required for best compatibility)
ls /sys/kernel/btf/vmlinux

# Check required kernel configs
zgrep CONFIG_BPF_EVENTS /proc/config.gz
zgrep CONFIG_DEBUG_INFO_BTF /proc/config.gz
```

**Note:** Some hooks (particularly LSM) require specific kernel configs that aren't universally enabled. Most modern distributions (RHEL 8+, Ubuntu 20.04+, Debian 11+) include these by default.

### 5.2 Installation

```bash
# Add Tetragon Helm repository
helm repo add cilium https://helm.cilium.io
helm repo update

# Create namespace
kubectl create namespace tetragon

# Install with minimal configuration
helm upgrade --install tetragon cilium/tetragon \
  --namespace tetragon
```

### 5.3 Verification

```bash
# Check pods are running
kubectl -n tetragon get pods

# View events
kubectl -n tetragon logs -l app.kubernetes.io/name=tetragon
```

### 5.4 Test Policy Application

Apply a simple policy and verify events:

```bash
kubectl apply -f trace-exec.yaml
kubectl run test --image=busybox -- ls
kubectl -n tetragon logs -l app.kubernetes.io/name=tetragon | grep ls
```

---

## 6.0 Next Steps and Open Questions

### 6.1 Immediate Actions

1. **Chart Porting:** Create PR adding Tetragon to `cloudnative-platform-charts` based on Aurora's implementation
2. **DEV Deployment:** Execute Zone DEV deployment per Section 5
3. **Documentation:** Share findings with team via this document and presentation

### 6.2 Questions for Investigation

- What is the performance overhead under production load?
- How do TracingPolicies interact with existing security tools?
- What is the upgrade path for eBPF programs as kernel versions change?
- How should events be ingested into our monitoring stack (ELK, Splunk, etc.)?

---

## 7.0 Conclusion

This research has established a comprehensive foundation: Tetragon provides the security observability we need, eBPF provides the safe, efficient kernel technology that makes it possible, and the Principle of Proximity explains *why* eBPF-based approaches are so powerful. By moving computation to where data lives—whether in unified memory architectures, kernel bypass networking, or near-data processing—we achieve performance and insight impossible with traditional layered approaches.

Tetragon represents not just a compliance checkbox but a fundamental improvement in how we can observe and secure our systems. The path forward is clear: port the chart, deploy in DEV, validate, and share our findings.

---

## 8.0 References

1. Tetragon Documentation. https://tetragon.cilium.io/docs/
2. eBPF.io - Introduction to eBPF. https://ebpf.io/
3. Starovoitov, A. (2014). "BPF: the universal in-kernel virtual machine." LWN.net.
4. Rice, L. (2020). *What is eBPF?* O'Reilly Media.
5. McCanne, S. & Jacobson, V. (1993). "The BSD Packet Filter." USENIX Winter 1993.
6. Cilium Tetragon GitHub Repository. https://github.com/cilium/tetragon
7. Linux Kernel Source: `kernel/bpf/verifier.c`

---

<a id="français"></a>

# Tetragon et eBPF : Une base complète

## Des exigences organisationnelles aux rouages du noyau

**Date :** 2026-03-23
**Auteur :** Bryan Paget, Statistique Canada

---

## Résumé

**Recommandation :** Adopter Tetragon comme solution d'observabilité de sécurité basée sur eBPF et contribuer le chart Helm à `cloudnative-platform-charts` pour une utilisation organisationnelle.

**Quoi :** Tetragon est un outil d'observabilité de sécurité alimenté par eBPF, déjà en cours d'exécution expérimentale dans nos grappes Aurora. Il fournit une visibilité au niveau du noyau sur l'activité des processus, des fichiers et du réseau avec un impact minimal sur les performances.

**Pourquoi maintenant :** Les normes organisationnelles émergentes exigent des solutions de sécurité basées sur eBPF. Tetragon satisfait directement cette exigence tout en fournissant des capacités impossibles avec les outils uniquement dans l'espace utilisateur.

**Risque :** Faible. Tetragon est déjà déployé expérimentalement dans Aurora. Le vérificateur eBPF garantit la sécurité des programmes, et les benchmarks de production montrent moins de 1% de surcharge CPU avec des politiques de traçage typiques.

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
6. [Prochaines étapes](#60-prochaines-étapes-et-questions-ouvertes)
7. [Conclusion](#70-conclusion)
8. [Références](#80-références)

---

## 1.0 Tetragon : La solution

**Tetragon** est un outil d'observabilité de sécurité et d'application de règles en temps d'exécution, conscient de Kubernetes, qui utilise eBPF pour fournir une visibilité approfondie sur l'activité des processus, des fichiers et du réseau au niveau du noyau Linux. Il permet la détection en temps réel et la réponse aux menaces de sécurité avec un impact minimal sur les performances.

Considérez Tetragon comme un système de caméras de sécurité pour vos conteneurs—mais qui ne surveille pas seulement les portes et fenêtres (ports réseau). Il surveille chaque action de chaque processus : chaque fichier qu'il ouvre, chaque commande qu'il exécute, chaque connexion réseau qu'il établit. Et parce qu'il opère dans le noyau, il voit ces choses au moment où elles se produisent, pas après qu'elles ont été signalées à travers plusieurs couches de logiciels.

### 1.1 Pourquoi Tetragon ?

L'outil répond à plusieurs besoins critiques :

- **Conformité organisationnelle :** Satisfait directement l'exigence de solutions de sécurité basées sur eBPF
- **Visibilité au niveau du noyau :** Fournit des aperçus impossibles à obtenir avec des outils uniquement dans l'espace utilisateur
- **Natif Kubernetes :** S'intègre parfaitement à notre infrastructure existante via des CRD
- **Éprouvé dans Aurora :** Déjà en cours d'exécution expérimentale dans notre environnement, réduisant les inconnues
- **Léger :** Les benchmarks de production montrent moins de 1% de surcharge CPU (typiquement 0,5-2% selon la complexité des politiques) avec ~100-200 MiB de mémoire par nœud—nettement inférieur aux alternatives dans l'espace utilisateur comme Falco

### 1.2 État actuel et voie à suivre

Tetragon est activé de manière expérimentale dans les grappes Aurora depuis février 2026. Sa migration vers `cloudnative-platform-charts` est prévue, bien qu'aucun calendrier n'existe. Cela présente une opportunité : nous pouvons accélérer l'adoption en contribuant nous-mêmes le chart et en validant dans DEV de la Zone.

**DEV de la Zone :** Un environnement Kubernetes sûr, hors production, où nous pouvons expérimenter de nouvelles technologies sans risquer les charges de travail ou les données de production.

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

**Vérificateur :** Un sous-système d'analyse statique qui vérifie chaque programme eBPF avant l'exécution, garantissant que les contraintes de sécurité sont respectées.

**Fonction auxiliaire :** Une fonction du noyau que les programmes eBPF peuvent appeler pour effectuer des opérations comme des recherches dans les cartes, la génération de nombres aléatoires ou la sortie d'événements.

### 2.3 Les garanties de sécurité

Les garanties du vérificateur rendent eBPF suffisamment sûr pour s'exécuter dans des noyaux de production :

**Terminaison :** Tout programme eBPF valide est garanti de se terminer. Le vérificateur analyse le graphe de flot de contrôle et rejette tout programme contenant des boucles non bornées. Cela prévient les boucles infinies dans le noyau.

**Sécurité mémoire :** Les programmes eBPF ne peuvent pas accéder à la mémoire du noyau en dehors de leur pile désignée, de la mémoire des cartes, ou de leur contexte. Le vérificateur suit chaque accès mémoire, prévenant la corruption des structures de données du noyau.

**Bornitude des ressources :** Tout programme eBPF a des bornes supérieures statiquement connues sur le temps d'exécution et l'utilisation de la mémoire. Le nombre maximal d'instructions, la taille de la pile (512 octets), et les tailles des cartes sont tous vérifiés. Cela assure une surcharge faible et prévisible même sur des hooks à haute fréquence.

---

## 3.0 Le principe de proximité

Les systèmes informatiques modernes font face à un défi fondamental : déplacer des données entre les composants (CPU, mémoire, stockage, réseau) prend souvent plus de temps et d'énergie que le calcul réel. C'est le **goulot d'étranglement du mouvement des données**.

**Principe de proximité :** La latence et la consommation d'énergie sont minimisées lorsque le calcul est effectué aussi près que possible de l'endroit où les données résident.

Les données traversent des interfaces avec une latence croissante : caches sur puce → mémoire principale → stockage → réseau. Co-localiser le calcul avec les données réduit ou élimine ces étapes de mouvement.

Ce principe apparaît dans plusieurs domaines de la conception des systèmes :

### 3.1 Architecture mémoire unifiée

**Architecture mémoire unifiée** place le CPU, le GPU et d'autres processeurs sur un seul système-sur-puce (SoC) partageant un pool de mémoire unique. Les processeurs M-series d'Apple et "Strix Halo" d'AMD utilisent cette approche, atteignant plus de 500 Go/s de bande passante en éliminant les copies de données entre les pools de mémoire séparés. Tout comme les puces M-series éliminent la surcharge du bus PCIe, eBPF élimine la copie noyau→espace utilisateur pour les événements de sécurité.

### 3.2 Zéro copie et contournement du noyau

Les techniques **zéro copie** éliminent les copies redondantes de données entre les composants du système. Le **contournement du noyau** permet aux applications utilisateur un accès direct et sûr aux ressources matérielles sans implication du noyau dans le chemin critique.

Le XDP (eXpress Data Path) d'eBPF en est l'exemple : il traite les paquets au niveau du pilote réseau, avant la pile réseau du noyau, évitant les copies et atteignant un traitement des paquets à débit linéaire.

**Pertinence pour Tetragon :** Tetragon incarne ce principe en exécutant des programmes de surveillance de sécurité *à l'intérieur du noyau* via eBPF. Au lieu de copier les événements système vers l'espace utilisateur pour analyse, il les traite à leur source—les points d'attache du noyau où ils se produisent. Cela minimise la latence et fournit une visibilité en temps réel impossible avec les approches d'audit traditionnelles.

---

## 4.0 Implémentation eBPF de Tetragon

Avec la base établie, nous pouvons maintenant comprendre précisément comment Tetragon utilise eBPF.

### 4.1 Composants clés de Tetragon

**TracingPolicy :** Une définition de ressource personnalisée (CRD) Kubernetes qui définit quels événements Tetragon doit tracer et comment réagir. Les politiques spécifient les points d'attache (par exemple, appels système `execve`), les conditions de correspondance (par exemple, binaires spécifiques), et les actions (par exemple, générer un événement, terminer un processus).

**Agent Tetragon :** Un DaemonSet s'exécutant sur chaque nœud qui charge des programmes eBPF basés sur des TracingPolicies, collecte les événements des cartes eBPF, et les exporte vers des destinations configurées (stdout, ELK, etc.).

### 4.2 Comment Tetragon utilise les points d'attache eBPF

| Cible d'observabilité | Type de point d'attache eBPF | Fonction/Événement du noyau |
|---------------------|----------------|----------------------|
| Exécution de processus | Tracepoint | `sys_enter_execve`, `sys_exit_execve` |
| Accès aux fichiers | Kprobe | `vfs_open`, `vfs_read`, `vfs_write` |
| Connexions réseau | Tracepoint | `tcp_connect`, `udp_sendmsg` |
| Requêtes DNS | Kprobe | `udp_recvmsg` avec filtrage port 53 |

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

Cette politique s'attache à l'appel système `execve`, capture l'argument de ligne de commande, et génère un événement chaque fois que bash ou sh exécute une commande contenant "passwd" ou "shadow"—accès potentiel aux identifiants. Le programme eBPF s'exécute dans le noyau, voit l'execve au moment où il se produit, et peut immédiatement signaler l'espace utilisateur.

**Exemple de sortie d'événement :**

```json
{
  "node": "worker-node-01",
  "time": "2026-03-23T14:32:15.123Z",
  "event_type": "process_exec",
  "process": {
    "exec_id": "V29ya2VyLW5vZGUtMDE6MTIzNDU2Nzg5MA==",
    "pid": 12345,
    "ppid": 12340,
    "binary": "/bin/bash",
    "arguments": "cat /etc/passwd",
    "cwd": "/home/user"
  },
  "pod": {
    "namespace": "default",
    "name": "test-pod"
  },
  "action": "generate_event"
}
```

---

## 5.0 Plan de déploiement

Sur la base de notre recherche, voici les étapes concrètes pour la validation :

### 5.1 Prérequis

- Accès à la grappe DEV de la Zone
- `kubectl` configuré
- Helm 3 installé
- Noyau Linux ≥ 4.19 (pour les fonctionnalités eBPF de base ; 5.4+ recommandé)
- Support BTF (BPF Type Format) activé pour la compatibilité CO-RE (Compile Once – Run Everywhere)

**Vérification de la configuration du noyau :**

```bash
# Vérifier la version du noyau
uname -r

# Vérifier le support BTF (requis pour une meilleure compatibilité)
ls /sys/kernel/btf/vmlinux

# Vérifier les configurations requises du noyau
zgrep CONFIG_BPF_EVENTS /proc/config.gz
zgrep CONFIG_DEBUG_INFO_BTF /proc/config.gz
```

**Note :** Certains hooks (particulièrement LSM) nécessitent des configurations spécifiques du noyau qui ne sont pas universellement activées. La plupart des distributions modernes (RHEL 8+, Ubuntu 20.04+, Debian 11+) les incluent par défaut.

### 5.2 Installation

```bash
# Ajouter le dépôt Helm Tetragon
helm repo add cilium https://helm.cilium.io
helm repo update

# Créer le namespace
kubectl create namespace tetragon

# Installer avec configuration minimale
helm upgrade --install tetragon cilium/tetragon \
  --namespace tetragon
```

### 5.3 Vérification

```bash
# Vérifier que les pods sont en cours d'exécution
kubectl -n tetragon get pods

# Voir les événements
kubectl -n tetragon logs -l app.kubernetes.io/name=tetragon
```

### 5.4 Test d'application de politique

Appliquer une politique simple et vérifier les événements :

```bash
kubectl apply -f trace-exec.yaml
kubectl run test --image=busybox -- ls
kubectl -n tetragon logs -l app.kubernetes.io/name=tetragon | grep ls
```

---

## 6.0 Prochaines étapes et questions ouvertes

### 6.1 Actions immédiates

1. **Portage du chart :** Créer une PR ajoutant Tetragon à `cloudnative-platform-charts` basée sur l'implémentation d'Aurora
2. **Déploiement DEV :** Exécuter le déploiement DEV de la Zone selon la section 5
3. **Documentation :** Partager les découvertes avec l'équipe via ce document et la présentation

### 6.2 Questions à investiguer

- Quelle est la surcharge de performance sous charge de production ?
- Comment les TracingPolicies interagissent-elles avec les outils de sécurité existants ?
- Quel est le chemin de mise à niveau pour les programmes eBPF lors des changements de version du noyau ?
- Comment les événements doivent-ils être ingérés dans notre pile de surveillance (ELK, Splunk, etc.) ?

---

## 7.0 Conclusion

Cette recherche a établi une base complète : Tetragon fournit l'observabilité de sécurité dont nous avons besoin, eBPF fournit la technologie de noyau sûre et efficace qui le rend possible, et le Principe de Proximité explique *pourquoi* les approches basées sur eBPF sont si puissantes. En déplaçant le calcul là où les données vivent—que ce soit dans des architectures mémoire unifiées, la mise en réseau avec contournement du noyau, ou le traitement près des données—nous atteignons des performances et des aperçus impossibles avec des approches traditionnelles en couches.

Tetragon représente non seulement une case de conformité à cocher, mais une amélioration fondamentale dans la façon dont nous pouvons observer et sécuriser nos systèmes. La voie à suivre est claire : porter le chart, déployer en DEV, valider, et partager nos découvertes.

---

## 8.0 Références

1. Documentation Tetragon. https://tetragon.cilium.io/docs/
2. eBPF.io - Introduction à eBPF. https://ebpf.io/
3. Starovoitov, A. (2014). "BPF: the universal in-kernel virtual machine." LWN.net.
4. Rice, L. (2020). *What is eBPF?* O'Reilly Media.
5. McCanne, S. & Jacobson, V. (1993). "The BSD Packet Filter." USENIX Winter 1993.
6. Dépôt GitHub Cilium Tetragon. https://github.com/cilium/tetragon
7. Source du noyau Linux : `kernel/bpf/verifier.c`
