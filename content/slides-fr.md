<!-- Diapositive de titre -->
<!-- _class: lead -->
# Tetragon et eBPF

<br>

### L'observabilité de sécurité depuis le noyau

<br>
<br>

#### Statistique Canada 2026

<br>
<br>
<br>

###### *Présenté par l'équipe de la Zone*
![bg left:20%](./img/canada-1.png)

---

<!-- Résumé -->
## Résumé

![bg left:20%](./img/canada-1.png)

- **Quoi :** Tetragon est un outil d'observabilité de sécurité utilisant eBPF. Déjà en cours d'exécution expérimentale dans Aurora; nous l'implémenterons dans The Zone pour répondre aux normes de sécurité eBPF.
- **Pourquoi :** Les solutions de sécurité basées sur eBPF sont obligatoires. Tetragon fournit une visibilité en temps réel au niveau du noyau avec un impact minimal.
- **Risque :** Faible – le vérificateur eBPF garantit la sécurité; Tetragon est déjà validé dans Aurora.
- **Coût :** Minimal – <1% de surcharge CPU, ~100-200 MiB de mémoire par nœud (espace noyau, aucun agent supplémentaire).

<blockquote>
De la recherche au déploiement prêt pour la production.
</blockquote>

---

<!-- État actuel -->
## État actuel et voie à suivre

![bg left:20%](./img/canada-1.png)

**En février 2026 :**

- Tetragon activé **de manière expérimentale dans les grappes Aurora**
- Migration prévue vers `cloudnative-platform-charts` (aucun calendrier)

**Opportunité :**

- Accélérer l'adoption en contribuant nous-mêmes le chart
- Valider dans **Zone DEV** utilisant AKS + Kubeflow

<blockquote>
Connaissances de SSC Aurora à StatCan The Zone – collaboration pour un avenir meilleur.
</blockquote>

---

<!-- Motivation : Pourquoi l'espace noyau? -->
## Pourquoi l'espace noyau importe

![bg left:20%](./img/canada-1.png)

**Le problème :** Les outils de sécurité dans l'espace utilisateur paient une taxe cachée sur chaque événement.

**Pourquoi l'espace utilisateur est plus lent :**
1. **Changements de contexte :** Le CPU doit sauvegarder/restaurer l'état en traversant la frontière noyau↔utilisateur
2. **Copie de données :** Les événements sont copiés de la mémoire du noyau vers les tampons utilisateurs
3. **Latence :** Quand l'espace utilisateur voit l'événement, le moment est passé

---

## Pourquoi l'espace noyau importe (suite)

![bg left:20%](./img/canada-1.png)

**Exemple concret : NTSYNC (Wine 11)**
- **Avant :** La synchronisation des threads nécessitait des allers-retours vers le processus wineserver
- **Après :** Le module noyau NTSYNC gère les primitives de synchronisation directement dans le noyau
- **Résultat :** Jusqu'à **778 % d'amélioration FPS** dans les jeux multi-threadés

**Le motif :** Le matériel et le logiciel suivent tous deux le **Principe de Proximité**.

<blockquote>
Déplacer le calcul vers les données, pas les données vers le calcul.
</blockquote>

---

<!-- Le principe de proximité -->
## Le principe de proximité

![bg left:20%](./img/canada-1.png)

**Goulot d'étranglement du mouvement des données :** Déplacer des données entre les composants coûte souvent plus que le calcul.

**Principe :** La latence est minimisée lorsque le calcul se produit **aussi près que possible de l'endroit où les données résident**.

Les données traversent : caches sur puce → mémoire principale → stockage → réseau

---

## Le principe de proximité (suite)

![bg left:20%](./img/canada-1.png)

**Manifestations dans l'informatique :**
- **Matériel :** Mémoire unifiée (Apple M-series) élimine la surcharge PCIe
- **Jeux :** NTSYNC garde la synchronisation des threads dans le noyau
- **Sécurité :** eBPF traite les événements à leur source, avant la copie vers l'espace utilisateur

<blockquote>
Un principe d'optimisation fondamental dans toute l'informatique.
</blockquote>

---

<!-- Qu'est-ce que Tetragon? -->
## Qu'est-ce que Tetragon ?

![bg left:20%](./img/canada-1.png)

**Tetragon :** Plateforme d'observabilité de sécurité qui utilise eBPF pour surveiller les grappes Kubernetes depuis le noyau.

**Ce qu'il surveille :**
- Exécution des processus et signaux
- Opérations sur le système de fichiers
- Connexions réseau et requêtes DNS
- Tout fait dans l'espace noyau, limitant l'impact et la latence – surveillance en temps réel pour la sécurité et les bogues

---

## Qu'est-ce que Tetragon ? (suite)

![bg left:20%](./img/canada-1.png)

**Avantages clés :**
- Conformité aux exigences eBPF
- Visibilité au niveau du noyau impossible avec les outils utilisateurs
- Natif Kubernetes via les CRD (TracingPolicy)
- <1% de surcharge CPU, ~100-200 MiB de mémoire par nœud

<blockquote>
Surveillance de sécurité depuis le noyau.
</blockquote>

---

<!-- Qu'est-ce que eBPF? -->
## Qu'est-ce que eBPF ?

![bg left:20%](./img/canada-1.png)

**eBPF (Extended Berkeley Packet Filter) :** Une machine virtuelle dans le noyau qui exécute en toute sécurité des programmes fournis par l'utilisateur.

**Propriétés clés :**
- S'exécute dans le noyau Linux — aucun module noyau requis
- **Vérificateur** garantit la sécurité avant le chargement (prouvé mathématiquement)
- S'attache aux événements du noyau : appels système, entrée/sortie de fonctions, points de trace, hooks LSM
- Accès aux données du noyau via des fonctions auxiliaires contrôlées

<blockquote>
1992 : BPF pour le filtrage de paquets. 2014 : eBPF généralisé au-delà du réseau.
</blockquote>

---

<!-- Concepts de base eBPF -->
## Concepts de base d'eBPF

![bg left:20%](./img/canada-1.png)

Pour la surveillance des menaces en temps réel de Tetragon, eBPF attache de petits programmes aux événements du noyau.

**Programme eBPF :** Séquence finie d'instructions de type RISC sur des registres 64 bits, pile de 512 octets

**Point d'attache :** Emplacement du noyau où les programmes eBPF s'attachent :
- `kprobe` / `kretprobe` : Instrumentation dynamique de fonctions du noyau
- `tracepoint` : Points de trace statiquement définis (p. ex. `sys_enter_execve`)
- `cgroup-bpf` : Points d'attache des appels système par conteneur (critique pour Kubernetes)
- `LSM` : Points d'attache du module de sécurité Linux – appliquent les politiques de sécurité

<blockquote>
Code sûr et efficace s'exécutant dans le noyau.
</blockquote>

---

<!-- Théorèmes de sécurité -->
## Les garanties de sécurité

![bg left:20%](./img/canada-1.png)

Les garanties du vérificateur rendent eBPF sûr pour la production :

**Terminaison**
- Pas de boucles infinies. Tous les sauts arrière doivent être bornés

**Sécurité mémoire**
- Ne peut pas accéder à la mémoire du noyau en dehors de la pile, des cartes ou du contexte désignés

**Bornitude des ressources**
- Bornes supérieures statiquement connues sur le temps d'exécution et la mémoire
- Nombre maximal d'instructions, pile de 512 octets, tailles de cartes fixes

<blockquote>
Code prouvé sûr dans le noyau – vérifié avant le chargement.
</blockquote>

---

<!-- Implémentation eBPF de Tetragon -->
## L'implémentation eBPF de Tetragon

![bg left:20%](./img/canada-1.png)

**Composants clés :**

**TracingPolicy :** CRD Kubernetes définissant :
- Quels événements tracer (points d'attache)
- Conditions de correspondance (binaires, arguments)
- Actions (générer un événement, terminer un processus)

**Agent Tetragon :** DaemonSet sur chaque nœud qui :
- Charge les programmes eBPF depuis les politiques
- Collecte les événements des cartes eBPF
- Exporte vers des destinations configurées (stdout, ELK, etc.)

---

<!-- Points d'attache eBPF -->
## Comment Tetragon utilise les points d'attache eBPF

![bg left:20%](./img/canada-1.png)

| Ce qu'on surveille | Fonction noyau | Type de hook |
|-------------------|----------------|--------------|
| Démarrage processus | `sys_enter_execve` | Tracepoint |
| Lecture fichiers | `vfs_read` | Kprobe |
| Connexions TCP | `tcp_connect` | Tracepoint |
| Requêtes DNS | `udp_recvmsg:53` | Kprobe |

**Pourquoi ces hooks ?**
- `sys_*` – entrée/sortie des appels système (activité de processus de haut niveau)
- `vfs_*` – couche de système de fichiers virtuel (opérations sur les fichiers)
- `tcp_*`, `udp_*` – pile réseau (connexions et DNS)

**Dans notre grappe Kubeflow :** Ces hooks nous donnent de la visibilité sur :
- Pods Jupyter notebook – surveillent les échappements de shell
- Tâches d'entraînement – détectent l'accès inhabituel aux fichiers
- Points de terminaison d'inférence – observent les connexions réseau

<blockquote>
Visibilité approfondie sur l'activité du système – du conteneur au noyau.
</blockquote>

---

<!-- Exemple : Détecter accès aux identifiants -->
## Exemple : Détecter l'accès aux identifiants

![bg left:20%](./img/canada-1.png)

**Politique :** Alerter lorsque bash exécute des commandes contenant `passwd` ou `shadow`

```yaml
kind: TracingPolicy
spec:
  kprobes:
  - call: sys_execve
    selectors:
    - matchBinaries: [{operator: In, values: [/bin/bash]}]
      matchArgs: [{index: 0, operator: Contains, values: [passwd, shadow]}]
```

**Événement généré :**
```json
{
  "event_type": "process_exec",
  "binary": "/bin/bash",
  "arguments": "cat /etc/passwd",
  "pod": {"namespace": "default", "name": "test-pod"}
}
```

---

<!-- Plan de déploiement -->
## Plan de déploiement

![bg left:20%](./img/canada-1.png)

**Prérequis :**
- Grappe AKS avec nœuds Linux (Ubuntu 20.04+ recommandé)
- Kubeflow installé (optionnel, mais nous surveillerons les composants Kubeflow)
- Accès `helm` et `kubectl`

**Étapes d'installation :**

1. **Ajouter le dépôt Helm Cilium**
   ```bash
   helm repo add cilium https://helm.cilium.io
   helm repo update
   ```

2. **Créer le namespace et installer Tetragon**
   ```bash
   kubectl create namespace tetragon
   helm install tetragon cilium/tetragon -n tetragon
   ```

3. **Vérifier l'installation**
   ```bash
   kubectl -n tetragon get pods
   # Devrait voir les pods DaemonSet tetragon-* en cours d'exécution
   ```

4. **Déployer une TracingPolicy** (p. ex. l'exemple d'accès aux identifiants)

---

<!-- Configuration du déploiement Aurora -->
## Configuration du déploiement Aurora

![bg left:20%](./img/canada-1.png)

| Paramètre | Valeur |
|-----------|--------|
| Namespace | `tetragon-system` |
| Sécurité des pods | `privileged` (requis pour eBPF) |
| Injection Istio | `désactivée` |
| Quota de ressources | 60 pods |
| Agent | DaemonSet |
| Opérateur | Deployment |
| Politiques réseau | même namespace, CIDR API server, konnectivity-agent |
| Statut | Expérimental dans Aurora |

<blockquote>
Configuration prête pour la production validée dans Aurora.
</blockquote>

---

<!-- Prochaines étapes -->
## Prochaines étapes et questions ouvertes

![bg left:20%](./img/canada-1.png)

**Actions immédiates :**

1. **Portage du chart :** Ajouter Tetragon à `cloudnative-platform-charts`
2. **Déploiement DEV :** Déployer dans Zone DEV (AKS) avec :
   - Créer le namespace `tetragon`
   - Installer via Helm avec des remplacements pour AKS
   - Appliquer les TracingPolicies de base (exécution de processus, écritures de fichiers, réseau)
3. **Documentation :** Documenter la configuration, les politiques et l'intégration avec la surveillance existante (ELK / Splunk)

**Questions à répondre :**
- Surcharge de performance sous charge de production (surtout avec les tâches d'entraînement Kubeflow) ?
- Comment intégrer les événements Tetragon avec notre SIEM existant ?
- Quelles politiques sont les plus utiles pour les composants Kubeflow ?

---

<!-- Étapes de mise en œuvre pour The Zone -->
## Étapes de mise en œuvre pour The Zone

![bg left:20%](./img/canada-1.png)

**Phase 1 : Validation dans DEV**
- Déployer Tetragon dans la grappe AKS Zone DEV
- Déployer quelques TracingPolicies :
  - **Exécution de processus** dans les namespaces Kubeflow
  - **Accès aux fichiers** vers `/etc/shadow`, `/etc/passwd`, `/home/*/.kube`
  - **Connexions réseau** depuis des IPs externes inconnues
- Exporter les événements vers un index Elasticsearch de test
- Mesurer l'impact CPU/mémoire (référence vs avec politiques)

---

<!-- Étapes de mise en œuvre pour The Zone -->
## Étapes de mise en œuvre pour The Zone

![bg left:20%](./img/canada-1.png)

**Phase 2 : Prêt pour la production**
- Définir les objectifs de niveau de service (SLO) pour la latence et le débit des événements
- Créer un module Terraform pour le déploiement de Tetragon (dans le cadre de `cloudnative-platform-charts`)
- Ajouter Tetragon aux scripts d'approvisionnement de grappes

**Phase 3 : Intégration et automatisation**
- Créer un pipeline CI/CD pour les mises à jour TracingPolicy
- Implémenter l'alerte sur les événements critiques (p. ex. accès aux identifiants)
- Documenter pour l'équipe élargie

---

<!-- Conclusion -->
## Conclusion

![bg left:20%](./img/canada-1.png)

**Fondement de la recherche :**
- Tetragon fournit l'observabilité de sécurité nécessaire
- eBPF fournit la technologie de noyau sûre et efficace
- Le Principe de Proximité explique *pourquoi* eBPF est si puissant

**Voie à suivre :** Porter le chart → Déployer en DEV → Valider → Partager les découvertes

**Prochaine étape immédiate :** Déployer Tetragon dans Zone DEV ce sprint.

---

<!-- Références -->
<!-- _class: references -->
## Références

**Tetragon et eBPF :**

1. <a href="https://tetragon.cilium.io/docs/">Documentation Tetragon</a>
2. <a href="https://ebpf.io/">eBPF.io – Introduction à eBPF</a>
3. <a href="https://github.com/cilium/tetragon">GitHub Cilium Tetragon</a>

**Ressources techniques :**

4. Starovoitov, A. (2014). <a href="https://lwn.net/Articles/599755/">"BPF: the universal in-kernel virtual machine."</a> LWN.net.
5. Rice, L. (2020). <a href="https://www.oreilly.com/library/view/learning-ebpf/9781098135119/ch01.html"><i>Learning eBPF</i></a>. O'Reilly Media.
6. McCanne, S. & Jacobson, V. (1993). <a href="https://www.tcpdump.org/papers/bpf-usenix93.pdf">"The BSD Packet Filter."</a> USENIX.
7. Source du noyau Linux : <a href="https://github.com/torvalds/linux/blob/master/kernel/bpf/verifier.c"><code>kernel/bpf/verifier.c</code></a>

**Implémentation Aurora :**

8. <a href="https://github.com/gccloudone-aurora/aurora-platform-charts/tree/main/stable/aurora-platform/charts/aurora-core/templates/tetragon">Aurora Platform Charts</a>
