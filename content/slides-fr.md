<!-- Diapositive de titre -->
<!-- _class: lead -->
# Tetragon et eBPF
### Une base complète
#### Des exigences organisationnelles aux rouages du noyau

<br>
<br>

## Statistique Canada | Mars 2026

<br>

###### *Présenté par l'équipe de la Zone*
![bg left:33%](./img/canada-1.png)

---

<!-- Résumé -->
## Résumé

![bg left:33%](./img/canada-1.png)

- Mandat de mettre en œuvre des **solutions de sécurité basées sur eBPF**
- Exploration de **Tetragon**, déjà en cours d'exécution expérimentale dans Aurora
- Cette présentation synthétise : ce qu'est Tetragon, comment il fonctionne, pourquoi eBPF est révolutionnaire
- Construit à partir des **principes fondamentaux**, ancré dans la compréhension pratique

<blockquote>
Observabilité de sécurité au niveau du noyau avec impact minimal.
</blockquote>

---

<!-- Qu'est-ce que Tetragon? -->
## Qu'est-ce que Tetragon ?

![bg left:33%](./img/canada-1.png)

**Définition :** Un outil d'observabilité de sécurité conscient de Kubernetes exploitant eBPF pour une visibilité approfondie sur :
- L'activité des processus
- Les opérations sur les fichiers
- Les connexions réseau

Considérez-le comme un **système de caméras de sécurité pour conteneurs**—surveillant chaque action au niveau du noyau, en temps réel.

**Avantages clés :**
- Conformité aux exigences eBPF
- Visibilité au niveau du noyau impossible avec les outils utilisateurs
- Natif Kubernetes via les CRD
- Léger : impact minimal sur les performances

<blockquote>
Surveillance de sécurité depuis le noyau.
</blockquote>

---

<!-- État actuel -->
## État actuel et voie à suivre

![bg left:33%](./img/canada-1.png)

**En février 2026 :**
- Tetragon activé **de manière expérimentale dans les grappes Aurora**
- Migration prévue vers `cloudnative-platform-charts` (aucun calendrier)

**Opportunité :**
- Accélérer l'adoption en contribuant nous-mêmes le chart
- Valider dans **DEV de la Zone**—notre environnement Kubernetes sûr, hors production

<blockquote>
De l'expérimental au prêt pour la production.
</blockquote>

---

<!-- Le fondement : eBPF -->
## Le fondement : eBPF

![bg left:33%](./img/canada-1.png)

Pour comprendre Tetragon, nous devons comprendre eBPF.

**Contexte historique :**
- **1992 :** Berkeley Packet Filter (BPF) pour le filtrage de paquets
- **2014 :** BPF étendu (eBPF) généralisé au-delà du réseau

**Définition :** Une **machine virtuelle dans le noyau à usage général** qui exécute en toute sécurité des programmes fournis par l'utilisateur avec :
- Un jeu d'instructions bien défini
- Un vérificateur garantissant la sécurité
- Un accès aux données du noyau via des fonctions auxiliaires
- Une attache à divers événements du noyau

<blockquote>
30+ ans d'évolution du filtre de paquets à la VM universelle du noyau.
</blockquote>

---

<!-- Concepts de base eBPF -->
## Concepts de base d'eBPF

![bg left:33%](./img/canada-1.png)

**Programme eBPF :** Séquence finie d'instructions de type RISC sur des registres 64 bits, pile de 512 octets

**Point d'attache :** Emplacement du noyau où les programmes eBPF s'attachent :
- `kprobe`/`kretprobe` : Instrumentation dynamique de fonctions du noyau
- `tracepoint` : Points de trace statiquement définis
- `XDP` : Traitement des paquets au niveau du pilote réseau
- `cgroup-bpf` : Points d'attache des appels système par conteneur
- `LSM` : Points d'application de la politique de sécurité

**Carte eBPF :** Structures de données résidentes dans le noyau pour la communication

**Vérificateur :** Analyse statique assurant la sécurité des programmes

<blockquote>
Code sûr et efficace s'exécutant dans le noyau.
</blockquote>

---

<!-- Théorèmes de sécurité -->
## Les théorèmes de sécurité

![bg left:33%](./img/canada-1.png)

Les garanties du vérificateur rendent eBPF sûr pour la production :

**Théorème 1 : Terminaison**
- Pas de boucles infinies—tous les sauts arrière doivent être bornés

**Théorème 2 : Sécurité mémoire**
- Ne peut pas accéder à la mémoire du noyau en dehors de la pile, des cartes ou du contexte désignés

**Théorème 3 : Bornitude des ressources**
- Bornes supérieures statiquement connues sur le temps d'exécution et la mémoire
- À l'origine 4096 instructions, maintenant jusqu'à 1 million avec les appels en queue

<blockquote>
Code prouvé sûr dans le noyau.
</blockquote>

---

<!-- Le principe de proximité -->
## Le principe de proximité

![bg left:33%](./img/canada-1.png)

**Le goulot d'étranglement du mouvement des données :** Déplacer des données entre les composants coûte souvent plus que le calcul lui-même.

**Théorème :** La latence et l'énergie sont minimisées lorsque le calcul se produit **aussi près que possible de l'endroit où les données résident**.

*Pourquoi cela tient :* Les données traversent des interfaces avec une latence croissante :
- Caches sur puce → mémoire principale → stockage → réseau

**Manifestations :**
- Architecture mémoire unifiée (Apple M-series, AMD Strix Halo)
- Techniques de zéro copie et contournement du noyau
- **eBPF : le calcul là où les données vivent—dans le noyau**

<blockquote>
Déplacer le calcul vers les données, pas les données vers le calcul.
</blockquote>

---

<!-- Pertinence pour Tetragon -->
## Comment Tetragon incarne ce principe

![bg left:33%](./img/canada-1.png)

**Approche traditionnelle :**
1. Le noyau détecte l'événement
2. L'événement est copié vers l'espace utilisateur
3. L'outil utilisateur analyse
4. La réponse est générée

**Approche eBPF de Tetragon :**
1. Le programme eBPF s'exécute **dans le noyau**
2. Les événements sont traités **à leur source**
3. Les résultats sont exportés vers l'espace utilisateur

<blockquote>
Surveillance de sécurité là où les événements se produisent—latence minimale, visibilité en temps réel.
</blockquote>

---

<!-- Implémentation de Tetragon -->
## L'implémentation eBPF de Tetragon

![bg left:33%](./img/canada-1.png)

**Composants clés :**

**TracingPolicy :** CRD Kubernetes définissant :
- Quels événements tracer (points d'attache)
- Conditions de correspondance (binaires, arguments)
- Actions (générer un événement, terminer un processus)

**Agent Tetragon :** DaemonSet sur chaque nœud qui :
- Charge les programmes eBPF depuis les politiques
- Collecte les événements des cartes eBPF
- Exporte vers des destinations configurées (stdout, ELK, etc.)

<blockquote>
Observabilité de sécurité native Kubernetes.
</blockquote>

---

<!-- Tableau des points d'attache -->
## Comment Tetragon utilise les points d'attache eBPF

![bg left:33%](./img/canada-1.png)

| Cible d'observabilité | Type de point d'attache eBPF | Fonction/Événement du noyau |
|---------------------|----------------|----------------------|
| Exécution de processus | Tracepoint | `sys_enter_execve`, `sys_exit_execve` |
| Accès aux fichiers | Kprobe | `vfs_open`, `vfs_read`, `vfs_write` |
| Connexions réseau | Tracepoint | `tcp_connect`, `udp_sendmsg` |
| Requêtes DNS | Kprobe | `udp_recvmsg` (port 53) |

<blockquote>
Visibilité approfondie sur l'activité du système.
</blockquote>

---

<!-- Exemple de politique -->
## Exemple de TracingPolicy

![bg left:33%](./img/canada-1.png)

```yaml
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
      - "/bin/bash"
      - "/bin/sh"
      matchArgs:
      - index: 0
        operator: "Contains"
        values: ["passwd", "shadow"]
```

Détecte l'accès potentiel aux identifiants lorsque bash/sh exécute des commandes contenant "passwd" ou "shadow".

<blockquote>
Politiques de sécurité déclaratives comme ressources Kubernetes.
</blockquote>

---

<!-- Plan de déploiement -->
## Plan de déploiement

![bg left:33%](./img/canada-1.png)

**Prérequis :**
- Accès à la grappe DEV de la Zone
- `kubectl` configuré, Helm 3 installé
- Noyau Linux ≥ 4.18 (5.4+ recommandé)

**Installation :**
```bash
helm repo add cilium https://helm.cilium.io
kubectl create namespace tetragon
helm upgrade --install tetragon cilium/tetragon \
  --namespace tetragon
```

**Vérification :**
```bash
kubectl -n tetragon get pods
kubectl -n tetragon logs -l app.kubernetes.io/name=tetragon
```

<blockquote>
De la recherche à la validation.
</blockquote>

---

<!-- Prochaines étapes -->
## Prochaines étapes et questions ouvertes

![bg left:33%](./img/canada-1.png)

**Actions immédiates :**
1. **Portage du chart :** Ajouter Tetragon à `cloudnative-platform-charts`
2. **Déploiement DEV :** Exécuter le déploiement DEV de la Zone
3. **Documentation :** Partager les découvertes avec l'équipe

**Questions à investiguer :**
- Surcharge de performance sous charge de production ?
- Interaction avec les outils de sécurité existants ?
- Chemin de mise à niveau pour les programmes eBPF ?
- Ingestion des événements dans la pile de surveillance (ELK, Splunk) ?

<blockquote>
Voie claire à suivre avec des questions de recherche ouvertes.
</blockquote>

---

<!-- Conclusion -->
## Conclusion

![bg left:33%](./img/canada-1.png)

**Fondement de la recherche :**
- Tetragon fournit l'observabilité de sécurité nécessaire
- eBPF fournit la technologie de noyau sûre et efficace
- Le Principe de Proximité explique *pourquoi* eBPF est si puissant

**Insight clé :** Déplacer le calcul là où les données vivent atteint des performances et des aperçus impossibles avec des approches traditionnelles en couches.

**Voie à suivre :** Porter le chart → Déployer en DEV → Valider → Partager les découvertes

<blockquote>
Pas seulement la conformité—une amélioration fondamentale de l'observabilité de sécurité.
</blockquote>

---

<!-- Références -->
## Références

![bg left:33%](./img/canada-1.png)

1. Documentation Tetragon. https://tetragon.cilium.io/docs/
2. eBPF.io - Introduction à eBPF. https://ebpf.io/
3. Starovoitov, A. (2014). "BPF: the universal in-kernel virtual machine." LWN.net.
4. Rice, L. (2020). *What is eBPF?* O'Reilly Media.
5. McCanne, S. & Jacobson, V. (1993). "The BSD Packet Filter." USENIX Winter 1993.
6. GitHub Cilium Tetragon. https://github.com/cilium/tetragon
7. Source du noyau Linux : `kernel/bpf/verifier.c`

<blockquote>
Construit sur des décennies de recherche et développement.
</blockquote>

---

<!-- Merci -->
<!-- _class: lead -->
# Merci

### Des questions ?

<br>

###### *Statistique Canada | Statistics Canada*
![bg left:33%](./img/canada-1.png)
