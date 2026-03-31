<!-- Diapositive de titre -->
<!-- _class: lead -->
# Qu'est-ce que Tetragon (et eBPF) ?
![bg left:20%](./img/canada-1.png)

<br>

![w:128px](https://tetragon.io/images/tetragon-shield.png)

### L'observabilité de sécurité depuis le noyau

<br>

#### Statistique Canada 2026

*Présenté par l'équipe de la Zone*

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

<!-- Qu'est-ce que Tetragon? -->
## Qu'est-ce que Tetragon ?

**Observabilité de sécurité et application d'exécution basées sur eBPF**

![bg left:20%](./img/canada-1.png)
![w:128px](https://tetragon.io/images/home/hero-illustration.png)

- Visibilité au niveau du noyau impossible avec les outils utilisateurs
- Natif Kubernetes via les Custom Resource Definitions (TracingPolicy)
- Filtre et applique les politiques directement dans le noyau – impact minimal
- <1% CPU, ~100-200 MiB de mémoire par nœud

<blockquote>
Surveillance de sécurité depuis le noyau.
</blockquote>

**En savoir plus :** <a href="https://tetragon.io/">tetragon.io</a>

---

<!-- Qu'est-ce que eBPF? -->
## Qu'est-ce que eBPF ?

**eBPF (Extended Berkeley Packet Filter) :** Une machine virtuelle dans le noyau qui exécute en toute sécurité des programmes fournis par l'utilisateur.

![bg left:20%](./img/canada-1.png)
![w:128px](https://upload.wikimedia.org/wikipedia/commons/thumb/b/b0/EBPF_logo.png/250px-EBPF_logo.png)

- S'exécute dans le noyau Linux – aucun module noyau requis
- **Vérificateur** garantit la sécurité avant le chargement (prouvé mathématiquement)
- S'attache aux appels système, entrée/sortie de fonctions, points de trace, hooks LSM
- **Garanties de sécurité :** pas de boucles infinies, sécurité mémoire, bornes de ressources

<blockquote>
Code prouvé sûr dans le noyau – vérifié avant le chargement.
</blockquote>

---

<!-- Pourquoi l'espace noyau? -->
## Pourquoi l'espace noyau importe

**Le principe de proximité :** Déplacer le calcul vers les données.

![bg left:20%](./img/canada-1.png)

**Le problème :** Les outils de sécurité dans l'espace utilisateur paient une taxe cachée :
- Changements de contexte (noyau↔utilisateur)
- Copie de données
- Latence – quand l'espace utilisateur voit l'événement, le moment est passé

**Exemple concret : NTSYNC (Wine 11)**
- Synchronisation des threads gérée dans le noyau → jusqu'à **778 % d'amélioration FPS** dans les jeux multi-threadés

<blockquote>
Déplacer le calcul vers les données, pas les données vers le calcul.
</blockquote>

---

<!-- Architecture eBPF -->
<!-- _class: lead -->

## Architecture eBPF

![](https://ebpf.io/static/e293240ecccb9d506587571007c36739/691bc/overview.webp)

---

<!-- Architecture de déploiement -->
## Architecture de déploiement

![bg left:20%](./img/canada-1.png)

**Composants :**
- **DaemonSet :** Un agent par nœud, charge les programmes eBPF
- **Operator :** Contrôle centralisé, gère les TracingPolicy CRDs
- **Export d'événements :** Elasticsearch, Kafka, gRPC, stdout

**Ressources :**
- CPU : #sym.lt 1% par nœud
- Mémoire : ~100-200 MiB par nœud
- Conteneur privilégié requis

---

<!-- Comment nous interagissons -->
## Comment nous interagissons avec Tetragon

### CLI (`tetra`)

![bg left:20%](./img/canada-1.png)

Visualisation des événements en temps réel et débogage.

```bash
# Streamer les événements de tous les pods
tetra getevents -o compact

# Surveiller un namespace spécifique
tetra getevents --namespace default \
  --field-selector "process.pod.name=my-app"
```

---

### TracingPolicies as Code

![bg left:20%](./img/canada-1.png)

- Configuration YAML, versionnée dans **Git**
- Déployée via **ArgoCD** (GitOps)

Extrait de politique :
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

### Export d'événements et tableaux de bord

![bg left:20%](./img/canada-1.png)

- **Elasticsearch** – stocke tous les événements Tetragon
- **Grafana** – crée des tableaux de bord personnalisés avec la source de données Elasticsearch
  - Visualiser les exécutions de processus, flux réseau et événements de sécurité
  - Alerter en cas d'activité suspecte

---

### API gRPC

![bg left:20%](./img/canada-1.png)

Accès programmatique pour les intégrations personnalisées (p. ex. SIEM, automatisation).

```python
import tetragon_grpc

client = tetragon_grpc.TetragonClient()
for event in client.get_events():
    print(event.process.exec)
```

---

### GitOps avec ArgoCD

![bg left:20%](./img/canada-1.png)

- TracingPolicies stockées dans le dépôt Git
- ArgoCD synchronise automatiquement les politiques vers les grappes
- Permet le contrôle de version, l'audit et le rollback

---

> **Résultat :** Observabilité de sécurité unifiée utilisant des outils familiers – CLI, Git, Elasticsearch, Grafana, ArgoCD.

---

<!-- Flux d'événements -->
## Flux d'événements et notifications

![bg left:20%](./img/canada-1.png)

**Cycle de vie :**
Événement noyau → Capture eBPF → Enrichissement Kubernetes → Export → Alerte

**Chemins de notification :**
- **Critique :** PagerDuty → garde
- **Élevé :** Slack #security-alerts
- **Moyen :** Résumé par courriel
- **Faible :** Rapport quotidien

**Intégration Zone :** ELK, PagerDuty existant, tableaux de bord Kubernetes

---

<!-- Points d'attache eBPF -->
## Comment Tetragon utilise les points d'attache eBPF

![bg left:20%](./img/canada-1.png)

**Ce qu'on surveille :**

- **Démarrage processus :** `sys_enter_execve` (Tracepoint)
- **Lecture fichiers :** `vfs_read` (Kprobe)
- **Connexions TCP :** `tcp_connect` (Tracepoint)
- **Requêtes DNS :** `udp_recvmsg:53` (Kprobe)

**Pourquoi ces hooks ?**
- `sys_*` – entrée/sortie des appels système (activité de processus de haut niveau)
- `vfs_*` – couche de système de fichiers virtuel (opérations sur les fichiers)
- `tcp_*`, `udp_*` – pile réseau (connexions et DNS)

---

## Comment Tetragon utilise les points d'attache eBPF (suite)

![bg left:20%](./img/canada-1.png)

**Dans notre grappe Kubeflow :**

- **Pods Jupyter notebook** – Détecter les échappements de shell via `sys_execve` quand `/bin/sh` ou `/bin/bash` est lancé depuis le processus notebook
- **Tâches d'entraînement** – Capturer l'accès aux identifiants via `vfs_read` sur `/etc/shadow`, `/etc/passwd` ou `~/.kube/config`
- **Points de terminaison d'inférence** – Surveiller les connexions externes via `tcp_connect` vers des IPs hors CIDR de la grappe

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

<!-- Ce qu'on surveille -->
## Ce qu'on surveille : Cas d'utilisation

![bg left:20%](./img/canada-1.png)

- **Accès identifiants :** `/etc/shadow`, `~/.kube/config` – prévenir le vol
- **Échappements shell :** `/bin/bash` depuis notebooks – prévenir breakout
- **Exfiltration :** IPs externes, gros transferts – détecter vol de données
- **Élévation privilèges :** `setuid`, `setgid`, `capset` – prévenir attaques
- **Fichiers sensibles :** Secrets, jetons, certificats – protéger comptes de service

---

<!-- Éviter les faux positifs -->
## Éviter les faux positifs

![bg left:20%](./img/canada-1.png)

**Mode audit :** Déployer sans application, ligne de base 1-2 semaines.

**Être spécifique :** Chemins exacts (`/usr/bin/python3`) pas de motifs.

**Par namespace :** Lignes de base différentes selon la charge.

**Raffinement itératif :** Déployer → observer → affiner → répéter.

**Documenter :** Runbook des faux positifs connus.

---

<!-- Politiques maintenables -->
## Construire des politiques maintenables

![bg left:20%](./img/canada-1.png)

**Contrôle de version :** Stocker dans Git, review via pull requests.

**Pipeline CI/CD :** Valider YAML, déployer DEV, tester, promouvoir.

**Documentation :** Détection, faux positifs, réponse, propriétaire.

**Cycle de vie :** Review trimestriel, supprimer inutilisé, mettre à jour.

---

<!-- Plan de déploiement -->
## Plan de déploiement / Installation (1/2)

![bg left:20%](./img/canada-1.png)

   ```bash
   # 1. Ajouter le dépôt Helm Cilium :
   helm repo add cilium https://helm.cilium.io
   helm repo update

   # 2. Installer Tetragon avec Helm :
   helm install tetragon cilium/tetragon \
     --namespace tetragon \
     --create-namespace

   # 3. Vérifier l'installation :
   kubectl -n tetragon get pods
   # Devrait voir les pods DaemonSet tetragon-* en cours d'exécution

   # 4. Installer tetra CLI (optionnel) :
   go install github.com/cilium/tetragon/tetra@latest
   ```

---

<!-- Plan de déploiement -->
## Plan de déploiement / Installation (2/2)

![bg left:20%](./img/canada-1.png)

   ```bash
   # 5. Déployer une TracingPolicy :
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

   # 6. Voir les événements en temps réel :
   kubectl port-forward -n tetragon ds/tetragon 54321:54321
   tetra getevents -o compact
   ```

---

<!-- Configuration du déploiement Aurora -->
## Configuration du déploiement Aurora

![bg left:20%](./img/canada-1.png)

**Configuration validée dans Aurora :**

- **Namespace :** `tetragon-system`
- **Sécurité des pods :** `privileged` (requis pour eBPF)
- **Injection Istio :** Désactivée
- **Quota de ressources :** 60 pods
- **Agent :** DaemonSet (s'exécute sur chaque nœud)
- **Opérateur :** Deployment (contrôle centralisé)
- **Politiques réseau :** Même namespace, CIDR API server, konnectivity-agent
- **Statut :** Expérimental dans Aurora

<blockquote>
Configuration prête pour la production validée dans Aurora.
</blockquote>

---

<!-- Prochaines étapes -->
## Prochaines étapes

![bg left:20%](./img/canada-1.png)

**Actions immédiates :**

1. **Portage du chart :** Ajouter Tetragon à `cloudnative-platform-charts`
2. **Déploiement DEV :** Déployer dans Zone DEV (AKS) avec :
   - Créer le namespace `tetragon`
   - Installer via Helm avec des remplacements pour AKS
   - Appliquer les TracingPolicies de base (exécution de processus, écritures de fichiers, réseau)
3. **Documentation :** Documenter la configuration, les politiques et l'intégration avec la surveillance existante (ELK / Splunk)

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

<!-- Feuille de route -->
## Feuille de route d'implémentation

![bg left:20%](./img/canada-1.png)

**Semaines 1-2 : Déployer et établir une ligne de base**
- Déployer Tetragon dans la grappe AKS Zone DEV
- Déployer les TracingPolicies de base (mode audit)
- Exporter les événements vers un index Elasticsearch de test
- Mesurer la surcharge (CPU #sym.lt 1%, mémoire #sym.lt 200 MiB)

**Semaines 3-4 : Ajuster et intégrer**
- Affiner les politiques selon les événements observés
- Définir les SLO (latence #sym.lt 100ms, disponibilité 99,9%)
- Créer un module Terraform pour `cloudnative-platform-charts`
- Intégrer avec ELK/Splunk existant

**Semaines 5-6 : Automatiser et alerter**
- Créer un pipeline CI/CD pour les mises à jour de TracingPolicy
- Implémenter l'alerte (PagerDuty, Slack, courriel)
- Documenter les procédures et guides de dépannage
- Partager les découvertes à l'échelle de l'organisation

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
<!-- _class: references -->
## Références

![bg left:20%](./img/canada-1.png)

**Tetragon et eBPF :**

1. <a href="https://tetragon.cilium.io/docs/">Documentation Tetragon</a>
2. <a href="https://ebpf.io/">eBPF.io – Introduction à eBPF</a>
3. <a href="https://github.com/cilium/tetragon">GitHub Cilium Tetragon</a>

**Ressources techniques :**

4. Starovoitov, A. (2014). <a href="https://lwn.net/Articles/599755/">"BPF: the universal in-kernel virtual machine."</a> LWN.net.
5. Rice, L. (2020). <a href="https://www.oreilly.com/library/view/learning-ebpf/9781098135119/ch01.html"><i>Learning eBPF</i></a>. O'Reilly Media.
6. McCanne, S. & Jacobson, V. (1993). <a href="https://www.tcpdump.org/papers/bpf-usenix93.pdf">"The BSD Packet Filter."</a> USENIX.

---
<!-- _class: references -->
## Références (suite)

![bg left:20%](./img/canada-1.png)

**Noyau Linux :**

7. Source du noyau Linux : <a href="https://github.com/torvalds/linux/blob/master/kernel/bpf/verifier.c"><code>kernel/bpf/verifier.c</code></a>

**Implémentation Aurora :**

8. <a href="https://github.com/gccloudone-aurora/aurora-platform-charts/tree/main/stable/aurora-platform/charts/aurora-core/templates/tetragon">Aurora Platform Charts</a>
