[English](#english) | [Français](#français)

<a id="english"></a>

# Tetragon and eBPF: A Comprehensive Foundation

## From Corporate Requirements to Kernel Internals

**Date:** 2026-03-23
**Author:** Bryan Paget, Statistics Canada

---

## Executive Summary

We have been tasked with implementing eBPF-based security solutions to comply with emerging corporate standards. This directive led us to explore Tetragon, an eBPF-powered security observability tool already running experimentally in our Aurora clusters. This document synthesizes our research: what Tetragon is, how it works, the eBPF technology that powers it, and the fundamental systems principles that explain why eBPF is so revolutionary.

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

**Definition 1.1 (Tetragon).** Tetragon is a Kubernetes-aware security observability and runtime enforcement tool that leverages eBPF to provide deep visibility into process, file, and network activity at the Linux kernel level. It enables real-time detection of and response to security threats with minimal performance overhead.

Think of Tetragon as a security camera system for your containers—but one that doesn't just watch the doors and windows (network ports). It watches every action each process takes: every file it opens, every command it executes, every network connection it makes. And because it operates in the kernel, it sees these things as they happen, not after they've been reported up through multiple layers of software.

### 1.1 Why Tetragon?

The tool addresses several critical needs:

- **Corporate Compliance:** Directly satisfies the requirement for eBPF-based security solutions.
- **Kernel-Level Visibility:** Provides insights impossible to achieve with userspace-only tools.
- **Kubernetes Native:** Integrates seamlessly with our existing infrastructure through CRDs.
- **Proven in Aurora:** Already running experimentally in our environment, reducing unknowns.
- **Lightweight:** eBPF's efficiency means minimal performance impact on production workloads.

### 1.2 Current Status and Path Forward

Tetragon is enabled experimentally in Aurora clusters as of February 2026. It is planned for migration to `cloudnative-platform-charts`, though no timeline exists. This presents an opportunity: we can accelerate adoption by contributing the chart ourselves and validating in Zone DEV.

**Definition 1.2 (Zone DEV).** A safe, non-production Kubernetes environment where we can experiment with new technologies without risking production workloads or data.

---

## 2.0 The Foundation: eBPF

To understand Tetragon, we must understand the technology that makes it possible: eBPF.

### 2.1 Historical Context: From Packet Filter to Virtual Machine

**Definition 2.1 (Packet Filtering).** Packet filtering is the process of inspecting network packets as they arrive at or leave a network interface and deciding, based on configurable rules, whether to allow, drop, or modify each packet.

Packet filtering was the original problem that led to eBPF's predecessor, the classic Berkeley Packet Filter (BPF), developed in 1992. The challenge is fundamental: packets arrive at millions per second. To keep up, filtering must happen inside the kernel, as close to the hardware as possible, without copying packets to userspace. Classic BPF provided a simple, safe virtual machine for exactly this purpose.

Over three decades, the utility of running safe programs inside the kernel became apparent for far more than packet filtering. This insight led to the development of extended BPF (eBPF) in 2014.

**Definition 2.2 (General-Purpose In-Kernel Virtual Machine).** A general-purpose in-kernel virtual machine is a lightweight execution engine embedded within the operating system kernel that can safely run user-supplied programs. It provides:
- A well-defined instruction set
- A verifier guaranteeing program safety
- Access to kernel data via helper functions
- Efficient communication with userspace
- Attachment to diverse kernel events

**Theorem 2.1 (The eBPF Evolution).** eBPF extends classic BPF by generalizing its attach points beyond network sockets to any kernel event (system calls, tracepoints, function entries/exits) while preserving its core safety and efficiency guarantees.

### 2.2 Core eBPF Concepts

**Definition 2.3 (eBPF Program).** An eBPF program is a finite sequence of instructions in the eBPF instruction set architecture (ISA)—a RISC-like set of arithmetic, load/store, and branch operations operating on 64-bit registers and a 512-byte stack.

**Definition 2.4 (Hook).** A hook is a kernel location (system call entry, tracepoint, network driver, etc.) to which an eBPF program can be attached. When execution reaches that location, the program runs.

Common hooks include:
- `kprobe`/`kretprobe`: Dynamic instrumentation of any kernel function
- `tracepoint`: Statically defined kernel trace points
- `XDP` (eXpress Data Path): Network driver level, earliest possible packet processing
- `cgroup-bpf`: Per-container system call and network operation hooks
- `LSM` (Linux Security Module): Security policy enforcement points

**Definition 2.5 (eBPF Map).** An eBPF map is a kernel-resident data structure (hash table, array, ring buffer, etc.) enabling communication between eBPF programs and userspace, or among eBPF programs themselves.

**Definition 2.6 (Verifier).** The eBPF verifier is a static analysis subsystem that checks every eBPF program before execution, ensuring safety constraints are met.

**Definition 2.7 (Helper Function).** A helper function is a kernel function that eBPF programs may call to perform operations like map lookups, random number generation, or event output.

### 2.3 The Safety Theorems

The verifier's guarantees are what make eBPF safe enough to run in production kernels. Let's state them formally:

**Theorem 2.2 (Termination).** Every valid eBPF program is guaranteed to terminate.

*Proof sketch.* The verifier analyzes the program's control-flow graph and rejects any program containing a loop not provably bounded. All backward jumps must have deterministic upper bounds.

This means no eBPF program accepted by the verifier can contain an infinite loop—a critical safety property when running code in the kernel.

**Theorem 2.3 (Memory Safety).** A valid eBPF program cannot access kernel memory outside its designated stack, map memory, or context.

*Proof sketch.* The verifier tracks the type and bounds of every memory access, ensuring stack pointers stay within the program's stack space, map accesses remain within map boundaries, and context pointers are not dereferenced out of bounds.

So eBPF programs cannot directly modify arbitrary kernel memory; they can only manipulate maps, stack, and context. This prevents them from corrupting kernel data structures.

**Theorem 2.4 (Resource Boundedness).** Every eBPF program has a statically known upper bound on execution time and memory usage.

*Proof sketch.* Maximum instruction count (originally 4096, now up to 1 million with tail calls) is checked. Stack size is fixed at 512 bytes. Map sizes are specified at creation. Helper functions have bounded execution time.

Because resource usage is bounded, eBPF programs introduce predictable, low overhead even when attached to high-frequency hooks. This is essential for production use.

---

## 3.0 The Principle of Proximity

Modern computing systems face a fundamental challenge: moving data between components (CPU, memory, storage, network) often takes more time and energy than the actual computation. This is known as the data movement bottleneck.

**Definition 3.1 (The Data Movement Bottleneck).** The performance limitation where the time and energy spent transferring data between components dominates the time and energy spent on computation.

**Theorem 3.1 (Principle of Proximity).** For a given computational task, end-to-end latency and energy consumption are minimized, and potential throughput maximized, when computation is performed as close as possible to where data resides.

*Why this holds.* Data traverses interfaces with increasing latency and decreasing bandwidth as it moves away from the processor: on-chip caches → main memory → storage → network. Each step adds overhead. Co-locating computation with data reduces or eliminates these movement steps.

This principle manifests in multiple areas of system design.

### 3.1 Unified Memory Architecture

**Definition 3.1.1 (Unified Memory Architecture).** A design where CPU, GPU, and other processors share a single, physically uniform pool of memory, achieved by integrating memory controllers and processors onto a system-on-chip (SoC) with direct memory connections.

Both Apple's M-series chips and AMD's latest "Strix Halo" processors implement this approach. By placing memory on the same package with a wide bus (512-bit in Apple's case), they achieve 500+ GB/s of bandwidth—far exceeding traditional architectures. This eliminates copying data between separate CPU and GPU memory pools.

### 3.2 Zero-Copy and Kernel Bypass

**Definition 3.2.1 (Zero-Copy).** Techniques that eliminate redundant copies of data as it moves between system components (e.g., between kernel space and user space).

**Definition 3.2.2 (Kernel Bypass).** Techniques allowing user-space applications direct, safe access to hardware resources without kernel involvement in the critical data path.

eBPF's XDP (eXpress Data Path) exemplifies this: it processes packets at the network driver level, before the kernel network stack, avoiding copies and achieving line-rate packet handling. Computation occurs where data first enters the system.

**Relevance to Tetragon.** Tetragon embodies this principle by running security monitoring programs *inside the kernel* via eBPF. Instead of copying system events to user space for analysis, it processes them at their source—the kernel hooks where they occur. This minimizes latency and provides real-time visibility impossible with traditional audit approaches.

---

## 4.0 Tetragon's eBPF Implementation

With the foundation established, we can now understand precisely how Tetragon uses eBPF.

### 4.1 Key Tetragon Components

**Definition 4.1 (TracingPolicy).** A Kubernetes Custom Resource Definition (CRD) that defines what events Tetragon should trace and how to react. Policies specify hooks (e.g., `execve` system calls), match conditions (e.g., specific binaries), and actions (e.g., generate event, terminate process).

**Definition 4.2 (Tetragon Agent).** A DaemonSet running on each node that loads eBPF programs based on TracingPolicies, collects events from eBPF maps, and exports them to configured sinks (stdout, ELK, etc.).

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

---

## 5.0 Deployment Plan

Based on our research, here are the concrete steps for validation:

### 5.1 Prerequisites

- Access to Zone DEV cluster
- `kubectl` configured
- Helm 3 installed
- Linux kernel ≥ 4.18 (for core eBPF features; 5.4+ recommended)

### 5.2 Installation

```bash
# Add Tetragon Helm repository
helm repo add cilium https://helm.cilium.io
helm repo update

# Create namespace
kubectl create namespace tetragon

# Install with minimal configuration
helm upgrade --install tetragon cilium/tetragon \
  --namespace tetragon \
  --set tetragonOperator.enabled=true \
  --set tetragon.enabled=true
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

Nous avons reçu le mandat de mettre en œuvre des solutions de sécurité basées sur eBPF afin de nous conformer aux normes organisationnelles émergentes. Cette directive nous a conduits à explorer Tetragon, un outil d'observabilité de sécurité alimenté par eBPF, déjà en cours d'exécution expérimentale dans nos grappes Aurora. Ce document synthétise notre recherche : ce qu'est Tetragon, comment il fonctionne, la technologie eBPF qui le propulse, et les principes fondamentaux des systèmes qui expliquent pourquoi eBPF est si révolutionnaire.

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

**Définition 1.1 (Tetragon).** Tetragon est un outil d'observabilité de sécurité et d'application de règles en temps d'exécution, conscient de Kubernetes, qui utilise eBPF pour fournir une visibilité approfondie sur l'activité des processus, des fichiers et du réseau au niveau du noyau Linux. Il permet la détection en temps réel et la réponse aux menaces de sécurité avec un impact minimal sur les performances.

Considérez Tetragon comme un système de caméras de sécurité pour vos conteneurs—mais qui ne surveille pas seulement les portes et fenêtres (ports réseau). Il surveille chaque action de chaque processus : chaque fichier qu'il ouvre, chaque commande qu'il exécute, chaque connexion réseau qu'il établit. Et parce qu'il opère dans le noyau, il voit ces choses au moment où elles se produisent, pas après qu'elles ont été signalées à travers plusieurs couches de logiciels.

### 1.1 Pourquoi Tetragon ?

L'outil répond à plusieurs besoins critiques :

- **Conformité organisationnelle :** Satisfait directement l'exigence de solutions de sécurité basées sur eBPF.
- **Visibilité au niveau du noyau :** Fournit des aperçus impossibles à obtenir avec des outils uniquement dans l'espace utilisateur.
- **Natif Kubernetes :** S'intègre parfaitement à notre infrastructure existante via des CRD.
**Éprouvé dans Aurora :** Déjà en cours d'exécution expérimentale dans notre environnement, réduisant les inconnues.
- **Léger :** L'efficacité d'eBPF signifie un impact minimal sur les performances des charges de travail en production.

### 1.2 État actuel et voie à suivre

Tetragon est activé de manière expérimentale dans les grappes Aurora depuis février 2026. Sa migration vers `cloudnative-platform-charts` est prévue, bien qu'aucun calendrier n'existe. Cela présente une opportunité : nous pouvons accélérer l'adoption en contribuant nous-mêmes le chart et en validant dans DEV de la Zone.

**Définition 1.2 (DEV de la Zone).** Un environnement Kubernetes sûr, hors production, où nous pouvons expérimenter de nouvelles technologies sans risquer les charges de travail ou les données de production.

---

## 2.0 Le fondement : eBPF

Pour comprendre Tetragon, nous devons comprendre la technologie qui le rend possible : eBPF.

### 2.1 Contexte historique : Du filtre de paquets à la machine virtuelle

**Définition 2.1 (Filtrage de paquets).** Le filtrage de paquets est le processus d'inspection des paquets réseau à leur arrivée ou départ d'une interface réseau et de décision, basée sur des règles configurables, d'autoriser, rejeter ou modifier chaque paquet.

Le filtrage de paquets était le problème initial qui a conduit au prédécesseur d'eBPF, le Berkeley Packet Filter (BPF) classique, développé en 1992. Le défi est fondamental : les paquets arrivent par millions par seconde. Pour suivre, le filtrage doit se faire dans le noyau, aussi près que possible du matériel, sans copier les paquets vers l'espace utilisateur. Le BPF classique fournissait une machine virtuelle simple et sûre exactement dans ce but.

Au cours de trois décennies, l'utilité d'exécuter des programmes sûrs à l'intérieur du noyau est devenue apparente pour bien plus que le filtrage de paquets. Cette intuition a conduit au développement du BPF étendu (eBPF) en 2014.

**Définition 2.2 (Machine virtuelle dans le noyau à usage général).** Une machine virtuelle dans le noyau à usage général est un moteur d'exécution léger intégré au noyau du système d'exploitation qui peut exécuter en toute sécurité des programmes fournis par l'utilisateur. Il fournit :
- Un jeu d'instructions bien défini
- Un vérificateur garantissant la sécurité des programmes
- Un accès aux données du noyau via des fonctions auxiliaires
- Une communication efficace avec l'espace utilisateur
- Une attache à divers événements du noyau

**Théorème 2.1 (L'évolution eBPF).** eBPF étend le BPF classique en généralisant ses points d'attache au-delà des sockets réseau vers tout événement du noyau (appels système, points de trace, entrées/sorties de fonctions) tout en préservant ses garanties fondamentales de sécurité et d'efficacité.

### 2.2 Concepts de base d'eBPF

**Définition 2.3 (Programme eBPF).** Un programme eBPF est une séquence finie d'instructions dans le jeu d'instructions eBPF (ISA)—un ensemble de type RISC d'opérations arithmétiques, de chargement/stockage et de branchement opérant sur des registres 64 bits et une pile de 512 octets.

**Définition 2.4 (Point d'attache).** Un point d'attache est un emplacement du noyau (entrée d'appel système, point de trace, pilote réseau, etc.) auquel un programme eBPF peut être attaché. Lorsque l'exécution atteint cet emplacement, le programme s'exécute.

Les points d'attache courants incluent :
- `kprobe`/`kretprobe` : Instrumentation dynamique de toute fonction du noyau
- `tracepoint` : Points de trace du noyau statiquement définis
- `XDP` (eXpress Data Path) : Niveau du pilote réseau, traitement des paquets le plus précoce possible
- `cgroup-bpf` : Points d'attache des appels système et opérations réseau par conteneur
- `LSM` (Linux Security Module) : Points d'application de la politique de sécurité

**Définition 2.5 (Carte eBPF).** Une carte eBPF est une structure de données résidente dans le noyau (table de hachage, tableau, tampon en anneau, etc.) permettant la communication entre les programmes eBPF et l'espace utilisateur, ou entre les programmes eBPF eux-mêmes.

**Définition 2.6 (Vérificateur).** Le vérificateur eBPF est un sous-système d'analyse statique qui vérifie chaque programme eBPF avant l'exécution, garantissant que les contraintes de sécurité sont respectées.

**Définition 2.7 (Fonction auxiliaire).** Une fonction auxiliaire est une fonction du noyau que les programmes eBPF peuvent appeler pour effectuer des opérations comme des recherches dans les cartes, la génération de nombres aléatoires ou la sortie d'événements.

### 2.3 Les théorèmes de sécurité

Les garanties du vérificateur sont ce qui rend eBPF suffisamment sûr pour s'exécuter dans des noyaux de production. Énonçons-les formellement :

**Théorème 2.2 (Terminaison).** Tout programme eBPF valide est garanti de se terminer.

*Esquisse de preuve.* Le vérificateur analyse le graphe de flot de contrôle du programme et rejette tout programme contenant une boucle non prouvablement bornée. Tous les sauts arrière doivent avoir des bornes supérieures déterministes.

Cela signifie qu'aucun programme eBPF accepté par le vérificateur ne peut contenir de boucle infinie—une propriété de sécurité critique lors de l'exécution de code dans le noyau.

**Théorème 2.3 (Sécurité mémoire).** Un programme eBPF valide ne peut pas accéder à la mémoire du noyau en dehors de sa pile désignée, de la mémoire des cartes, ou de son contexte.

*Esquisse de preuve.* Le vérificateur suit le type et les bornes de chaque accès mémoire, garantissant que les pointeurs de pile restent dans l'espace de pile du programme, que les accès aux cartes restent dans les limites des cartes, et que les pointeurs de contexte ne sont pas déréférencés hors limites.

Ainsi, les programmes eBPF ne peuvent pas directement modifier la mémoire arbitraire du noyau ; ils ne peuvent manipuler que les cartes, la pile et le contexte. Cela les empêche de corrompre les structures de données du noyau.

**Théorème 2.4 (Bornitude des ressources).** Tout programme eBPF a une borne supérieure statiquement connue sur le temps d'exécution et l'utilisation de la mémoire.

*Esquisse de preuve.* Le nombre maximal d'instructions (à l'origine 4096, maintenant jusqu'à 1 million avec les appels en queue) est vérifié. La taille de la pile est fixée à 512 octets. Les tailles des cartes sont spécifiées à la création. Les fonctions auxiliaires ont un temps d'exécution borné.

Parce que l'utilisation des ressources est bornée, les programmes eBPF introduisent une surcharge faible et prévisible même lorsqu'ils sont attachés à des points d'attache à haute fréquence. Ceci est essentiel pour une utilisation en production.

---

## 3.0 Le principe de proximité

Les systèmes informatiques modernes font face à un défi fondamental : déplacer des données entre les composants (CPU, mémoire, stockage, réseau) prend souvent plus de temps et d'énergie que le calcul réel. C'est ce qu'on appelle le goulot d'étranglement du mouvement des données.

**Définition 3.1 (Le goulot d'étranglement du mouvement des données).** La limitation de performance où le temps et l'énergie dépensés à transférer des données entre les composants dominent le temps et l'énergie dépensés pour le calcul.

**Théorème 3.1 (Principe de proximité).** Pour une tâche de calcul donnée, la latence de bout en bout et la consommation d'énergie sont minimisées, et le débit potentiel maximisé, lorsque le calcul est effectué aussi près que possible de l'endroit où les données résident.

*Pourquoi cela tient.* Les données traversent des interfaces avec une latence croissante et une bande passante décroissante à mesure qu'elles s'éloignent du processeur : caches sur puce → mémoire principale → stockage → réseau. Chaque étape ajoute une surcharge. Co-localiser le calcul avec les données réduit ou élimine ces étapes de mouvement.

Ce principe se manifeste dans plusieurs domaines de la conception des systèmes.

### 3.1 Architecture mémoire unifiée

**Définition 3.1.1 (Architecture mémoire unifiée).** Une conception où le CPU, le GPU et d'autres processeurs partagent un seul pool de mémoire physiquement uniforme, réalisé en intégrant les contrôleurs mémoire et les processeurs sur un système-sur-puce (SoC) avec des connexions mémoire directes.

Les puces M d'Apple et les derniers processeurs "Strix Halo" d'AMD implémentent cette approche. En plaçant la mémoire sur le même boîtier avec un bus large (512 bits dans le cas d'Apple), ils atteignent plus de 500 Go/s de bande passante—dépassant de loin les architectures traditionnelles. Cela élimine la copie de données entre les pools de mémoire CPU et GPU séparés.

### 3.2 Zéro copie et contournement du noyau

**Définition 3.2.1 (Zéro copie).** Techniques qui éliminent les copies redondantes de données lors de leur déplacement entre les composants du système (par exemple, entre l'espace noyau et l'espace utilisateur).

**Définition 3.2.2 (Contournement du noyau).** Techniques permettant aux applications utilisateur un accès direct et sûr aux ressources matérielles sans implication du noyau dans le chemin de données critique.

Le XDP (eXpress Data Path) d'eBPF en est l'exemple : il traite les paquets au niveau du pilote réseau, avant la pile réseau du noyau, évitant les copies et atteignant un traitement des paquets à débit linéaire. Le calcul se produit là où les données entrent d'abord dans le système.

**Pertinence pour Tetragon.** Tetragon incarne ce principe en exécutant des programmes de surveillance de sécurité *à l'intérieur du noyau* via eBPF. Au lieu de copier les événements système vers l'espace utilisateur pour analyse, il les traite à leur source—les points d'attache du noyau où ils se produisent. Cela minimise la latence et fournit une visibilité en temps réel impossible avec les approches d'audit traditionnelles.

---

## 4.0 Implémentation eBPF de Tetragon

Avec la base établie, nous pouvons maintenant comprendre précisément comment Tetragon utilise eBPF.

### 4.1 Composants clés de Tetragon

**Définition 4.1 (TracingPolicy).** Une définition de ressource personnalisée (CRD) Kubernetes qui définit quels événements Tetragon doit tracer et comment réagir. Les politiques spécifient les points d'attache (par exemple, appels système `execve`), les conditions de correspondance (par exemple, binaires spécifiques), et les actions (par exemple, générer un événement, terminer un processus).

**Définition 4.2 (Agent Tetragon).** Un DaemonSet s'exécutant sur chaque nœud qui charge des programmes eBPF basés sur des TracingPolicies, collecte les événements des cartes eBPF, et les exporte vers des destinations configurées (stdout, ELK, etc.).

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

---

## 5.0 Plan de déploiement

Sur la base de notre recherche, voici les étapes concrètes pour la validation :

### 5.1 Prérequis

- Accès à la grappe DEV de la Zone
- `kubectl` configuré
- Helm 3 installé
- Noyau Linux ≥ 4.18 (pour les fonctionnalités eBPF de base ; 5.4+ recommandé)

### 5.2 Installation

```bash
# Ajouter le dépôt Helm Tetragon
helm repo add cilium https://helm.cilium.io
helm repo update

# Créer le namespace
kubectl create namespace tetragon

# Installer avec configuration minimale
helm upgrade --install tetragon cilium/tetragon \
  --namespace tetragon \
  --set tetragonOperator.enabled=true \
  --set tetragon.enabled=true
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
