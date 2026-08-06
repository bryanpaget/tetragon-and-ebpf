<!-- Title Slide -->
<!-- _class: lead -->
# Qu'est-ce que Tetragon (et eBPF) ?
![bg left:20%](./img/canada-1.png)

<br>
<br>

![w:128px](https://tetragon.io/images/tetragon-shield.png)

### Observabilité de sécurité depuis le noyau

<br>
<br>

#### Statistique Canada 2026

*Présenté par l'équipe de la Zone*

---

<!-- Executive Summary -->
## Résumé

![bg left:20%](./img/canada-1.png)

- **Quoi :** Tetragon est un outil d’observabilité de sécurité utilisant eBPF. Il est déjà en cours d’exécution expérimentale dans Aurora ; nous l’implanterons dans la Zone pour répondre aux normes de sécurité eBPF de l’organisation.
- **Pourquoi :** Les solutions de sécurité basées sur eBPF sont obligatoires. Tetragon offre une visibilité en temps réel au niveau du noyau avec une charge minimale.
- **Risque :** Faible – le vérificateur eBPF garantit la sécurité ; Tetragon est déjà validé dans Aurora.
- **Coût :** Minime – moins de 1 % d’utilisation CPU, environ 100‑200 MiB de mémoire par nœud (espace noyau, aucun agent additionnel).

<blockquote>
De la recherche au déploiement prêt pour la production.
</blockquote>

---

<!-- What is Tetragon? -->
## Qu’est‑ce que Tetragon ?

**Observabilité de sécurité et application en temps réel basées sur eBPF**

![bg left:20%](./img/canada-1.png)
![w:128px](https://tetragon.io/images/home/hero-illustration.png)

- Visibilité au niveau du noyau impossible avec les outils d’espace utilisateur
- Natif Kubernetes grâce aux définitions de ressources personnalisées (TracingPolicy)
- Filtrage et application des politiques directement dans le noyau – charge minimale
- Moins de 1 % CPU, environ 100‑200 MiB de mémoire par nœud

<blockquote>
Surveillance de sécurité depuis le noyau.
</blockquote>

**Pour en savoir plus :** <a href="https://tetragon.io/">tetragon.io</a>

---

<!-- What is eBPF? -->
## Qu’est‑ce que eBPF ?

**eBPF (Extended Berkeley Packet Filter) :** Une machine virtuelle dans le noyau qui exécute en toute sécurité des programmes fournis par l’utilisateur.

![bg left:20%](./img/canada-1.png)
![w:128px](https://upload.wikimedia.org/wikipedia/commons/thumb/b/b0/EBPF_logo.png/250px-EBPF_logo.png)

- S’exécute à l’intérieur du noyau Linux – aucun module noyau requis
- **Vérificateur** garantit la sécurité avant chargement (preuve mathématique)
- S’attache aux appels système, entrées/sorties de fonctions, points de trace, hooks LSM
- **Garanties de sécurité :** pas de boucles infinies, sécurité mémoire, bornes de ressources

<blockquote>
Code prouvé sûr dans le noyau – vérifié avant chargement.
</blockquote>

---

<!-- Why Kernel Space? -->
## Pourquoi l'espace noyau importe

**Le principe de proximité :** Déplacer le calcul là où se trouvent les données.

![bg left:20%](./img/canada-1.png)

**Le problème :** Les outils de sécurité en espace utilisateur paient une taxe cachée :
- Changements de contexte (noyau ↔ utilisateur)
- Copie de données
- Latence – au moment où l’espace utilisateur voit l’événement, l’instant est passé

**Exemple concret : NTSYNC dans Wine 11**
- La synchronisation des fils d’exécution gérée dans le noyau → jusqu’à **778 % d’amélioration des FPS** dans les jeux multithreadés

<blockquote>
Déplacer le calcul vers les données, pas les données vers le calcul.
</blockquote>

---

<!-- eBPF Architecture -->
<!-- _class: lead -->

## Architecture eBPF

![](https://ebpf.io/static/e293240ecccb9d506587571007c36739/691bc/overview.webp)

---

<!-- Tetragon Architecture -->
<!-- _class: lead -->

## Diagramme d’architecture Tetragon

![](https://tetragon.io/svgs/diagram-illustration.svg)

---

<!-- How Tetragon Uses eBPF Hooks -->
## Comment Tetragon utilise les hooks eBPF

![bg left:20%](./img/canada-1.png)

**Ce que nous surveillons :**

- **Démarrage de processus :** `sys_enter_execve`
- **Lectures de fichiers :** `vfs_read`
- **Connexions TCP :** `tcp_connect`
- **Requêtes DNS :** `udp_recvmsg` (kprobe sur le trafic DNS, filtré par le port de destination 53)

**Dans notre grappe Kubeflow :**
- **Carnets Jupyter** – détection d’échappements de shell via `sys_execve`
- **Tâches d’entraînement** – capture d’accès aux identifiants via `vfs_read` sur `/etc/shadow`, `~/.kube/config`
- **Points de terminaison d’inférence** – surveillance des connexions externes via `tcp_connect`

---

<!-- Event Flow & Notifications -->
## Flux d’événements et notifications

![bg left:20%](./img/canada-1.png)

### Cycle de vie d'un événement :

Événement noyau → capture eBPF → enrichissement Kubernetes → export → alerte

### Chemins de notification :
- **Critique :** PagerDuty → personne de garde
- **Élevée :** Slack #alertes-securite
- **Moyenne :** Résumé par courriel
- **Faible :** Rapport quotidien

### Intégration Zone :
pile ELK, PagerDuty existant, tableaux de bord Kubernetes

---

<!-- Interaction: CLI -->
## Comment nous interagissons avec Tetragon

### CLI (`tetra`)

![bg left:20%](./img/canada-1.png)

Diffusion d’événements en temps réel et débogage depuis votre terminal.

```bash
# Diffuser tous les événements en format compact
tetra getevents -o compact

# Filtrer par espace de noms et pod
tetra getevents --namespace default \
  --pods my-app

# Exporter en JSON pour traitement ultérieur
tetra getevents -o json | jq '.process.exec'
```

### Installation :
```bash
go install github.com/cilium/tetragon/tetra@latest
```

---

<!-- Interaction: TracingPolicies as Code -->
## Comment nous interagissons avec Tetragon

### Politiques sous forme de code

![bg left:20%](./img/canada-1.png)

Les TracingPolicies sont des **CRD Kubernetes** – définies en YAML, versionnées dans Git.

```yaml
apiVersion: cilium.io/v1alpha1
kind: TracingPolicy
metadata:
  name: monitor-curl
spec:
  kprobes:
  - call: sys_execve
    syscall: true
    args:
    - index: 0
      type: "string"
    selectors:
    - matchBinaries:
      - operator: "In"
        values:
        - "/usr/bin/curl"
```

**Déployées via GitOps (ArgoCD)** – synchronisation automatique, contrôle de version, retour arrière possible.

---

<!-- Interaction: Event Export & Dashboards -->
## Comment nous interagissons avec Tetragon

### Export et tableaux de bord

![bg left:20%](./img/canada-1.png)

### Exportateurs :
Elasticsearch, Kafka, gRPC, stdout

### Tableaux de bord Grafana :
Créez des visualisations personnalisées en utilisant Elasticsearch comme source de données.

- Suivre les exécutions de processus par espace de noms
- Alerter sur les connexions réseau suspectes
- Filtrer par libellés de pod, espaces de noms ou appels système spécifiques

### Exemple de requête :
Nombre d'exécutions de shell par espace de noms dans la dernière heure.

---

<!-- Interaction: gRPC API -->
## Comment nous interagissons avec Tetragon

### API gRPC

![bg left:20%](./img/canada-1.png)

Accès programmatique pour des intégrations personnalisées (SIEM, automatisation, alertes).

```python
import grpc
from tetragon import sensors_pb2_grpc, events_pb2

channel = grpc.insecure_channel("localhost:54321")
stub = sensors_pb2_grpc.FineGuidanceSensorsStub(channel)

for event in stub.GetEvents(events_pb2.GetEventsRequest()):
    if event.process_exec:
        if event.process_exec.process.binary == "/bin/bash":
            ns = event.process_exec.process.pod.namespace
            print(f"Shell détecté dans l'espace de noms {ns}")
```

### Cas d'usage :
- Alimenter un SIEM personnalisé
- Déclencher des réponses automatisées
- Enrichir avec des renseignements sur les menaces externes

---

<!-- What We Monitor: Key Use Cases -->
## Ce que nous surveillons : cas d’utilisation clés

![bg left:20%](./img/canada-1.png)

- **Accès aux identifiants :** `/etc/shadow`, `~/.kube/config` – détecter le vol et les déplacements latéraux
- **Échappements de shell :** `/bin/bash` depuis les carnets – tentatives de sortie du conteneur
- **Exfiltration de données :** connexions vers des IP externes inconnues – vol potentiel de données
- **Élévation de privilèges :** `setuid`, `setgid`, `capset` – prévenir l’élévation de privilèges
- **Fichiers sensibles :** secrets, jetons, certificats – protéger les comptes de service

### Pourquoi ces éléments sont importants :
techniques MITRE ATT&CK courantes dans les environnements conteneurisés.

---

<!-- Policy Management: Avoiding False Positives -->
## Gestion des politiques : éviter les faux positifs

![bg left:20%](./img/canada-1.png)

### Commencer en mode audit :
Déployer sans application, établir une référence pendant 1‑2 semaines.

### Être spécifique :
Utiliser des chemins exacts (`/usr/bin/python3`) plutôt que des motifs (`*python*`).

### Politiques spécifiques aux espaces de noms :
Différentes références pour Jupyter, l'entraînement et l'inférence.

### Affinage itératif :
Déployer → observer → affiner → répéter.

### Documenter :
Tenir un manuel des faux positifs connus et de leurs correctifs.

---

<!-- Policy Management: Maintainable Policies -->
## Gestion des politiques : politiques maintenables

![bg left:20%](./img/canada-1.png)

- **Contrôle de version :** Stocker dans Git, réviser via des demandes de tirage.
- **Pipeline CI/CD :** Valider le YAML, déployer en DEV, tester, promouvoir.
- **Documentation :** Inclure l’objectif, les faux positifs, la réponse, la responsabilité.
- **Cycle de vie :** Réviser trimestriellement, supprimer les politiques inutilisées, mettre à jour face aux nouvelles menaces.
- **Test :** Simuler des événements par rapport aux politiques avant le déploiement.

---

<!-- Deployment: Helm Installation -->
## Déploiement

### Installation avec Helm

![bg left:20%](./img/canada-1.png)

```bash
# 1. Ajouter le dépôt Helm de Cilium
helm repo add cilium https://helm.cilium.io
helm repo update

# 2. Créer l’espace de noms et installer Tetragon
helm install tetragon cilium/tetragon \
  --namespace tetragon \
  --create-namespace

# 3. Vérifier que le DaemonSet est en cours d'exécution
kubectl -n tetragon get pods
```

### Sortie attendue :
```
NAME               READY   STATUS    RESTARTS   AGE
tetragon-xxxxx     1/1     Running   0          1m
tetragon-operator  1/1     Running   0          1m
```

---

<!-- Deployment: Deploying a TracingPolicy -->
### Déployer une TracingPolicy

![bg left:20%](./img/canada-1.png)

```bash
# Exemple : détecter les tentatives d’accès aux identifiants
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

### Vérifier que la politique est active :
```bash
kubectl get tracingpolicies
```

---

<!-- Deployment: Viewing Events -->
## Déploiement

### Visualiser les événements

![bg left:20%](./img/canada-1.png)

### Transmettre le port gRPC et diffuser les événements :

```bash
# Transmettre le port vers le DaemonSet Tetragon
kubectl port-forward -n tetragon ds/tetragon 54321:54321

# Dans un autre terminal, diffuser les événements
tetra getevents -o compact
```

### Exemple de sortie d'événement :
```
🚀 process /bin/bash cat /etc/shadow
   pod: default/test-pod, container: app
```

### Exporter vers Elasticsearch :
Configurer le chart Helm avec `exporters.elasticsearch.enabled=true`.

---

<!-- Implementation Plan: Phase 1 -->
## Plan d’implantation

### Phase 1 – Validation en DEV

![bg left:20%](./img/canada-1.png)

- Déployer Tetragon dans Zone DEV AKS
- Appliquer des politiques de base (exécution de processus, accès aux fichiers, réseau)
- Exporter les événements vers un Elasticsearch de test
- Mesurer la charge (CPU < 1 %, mémoire < 200 MiB)

---

<!-- Implementation Plan: Phases 2–3 -->
## Plan d’implantation

### Phases 2–3 – Production et automatisation

![bg left:20%](./img/canada-1.png)

**Phase 2 : Préparation à la production**
- Définir des SLO pour la latence et le débit des événements
- Créer un module Terraform dans `cloudnative-platform-charts`
- Intégrer Tetragon aux scripts de provisionnement des grappes

**Phase 3 : Automatisation et transfert**
- Pipeline CI/CD pour les mises à jour de TracingPolicy
- Alertes sur les événements critiques (PagerDuty, Slack)
- Documentation et manuels d’exploitation

---

<!-- Implementation Roadmap: Weeks 1–2 -->
## Feuille de route d’implantation

### Semaines 1‑2 – Déploiement et référence

![bg left:20%](./img/canada-1.png)

- Déployer Tetragon dans Zone DEV AKS
- Déployer des TracingPolicies de base (mode audit)
- Exporter les événements vers un Elasticsearch de test
- Mesurer la charge

---

<!-- Implementation Roadmap: Weeks 3–6 -->
## Feuille de route d’implantation

### Semaines 3‑6 – Ajustement, intégration, automatisation

![bg left:20%](./img/canada-1.png)

**Semaines 3‑4 : Ajustement et intégration**
- Affiner les politiques en fonction des événements observés
- Définir les SLO (latence < 100 ms, 99,9 % de disponibilité)
- Créer un module Terraform pour `cloudnative-platform-charts`
- Intégrer avec ELK/Splunk existant

**Semaines 5‑6 : Automatisation et alertes**
- Pipeline CI/CD pour les mises à jour de TracingPolicy
- Mettre en place les alertes (PagerDuty, Slack, courriel)
- Documenter les manuels d’exploitation
- Partager les résultats dans l’organisation

---

<!-- Conclusion -->
## Conclusion

![bg left:20%](./img/canada-1.png)

- **Quoi :** Tetragon offre une observabilité de sécurité au niveau du noyau avec une charge minimale.
- **Pourquoi :** eBPF est sûr, efficace et obligatoire pour les piles de sécurité modernes.
- **Comment :** Nous déploierons dans Zone DEV, validerons, affinerons les politiques et intégrerons à la surveillance existante.
- **Prochaine étape :** Porter le chart Helm et déployer dans Zone DEV pendant ce sprint.

---

<!-- References -->
## Références

![bg left:20%](./img/canada-1.png)

### Tetragon et eBPF :

1. <a href="https://tetragon.cilium.io/docs/">Documentation Tetragon</a>
2. <a href="https://ebpf.io/">eBPF.io – Introduction à eBPF</a>
3. <a href="https://github.com/cilium/tetragon">Cilium Tetragon GitHub</a>

### Ressources techniques :

4. Starovoitov, A. (2014). <a href="https://lwn.net/Articles/599755/">« BPF: the universal in‑kernel virtual machine. »</a> LWN.net.
5. Rice, L. (2020). <a href="https://www.oreilly.com/library/view/learning-ebpf/9781098135119/ch01.html"><i>Learning eBPF</i></a>. O'Reilly Media.
6. McCanne, S. & Jacobson, V. (1993). <a href="https://www.tcpdump.org/papers/bpf-usenix93.pdf">« The BSD Packet Filter. »</a> USENIX.

---

<!-- References -->
## Références

![bg left:20%](./img/canada-1.png)

### Noyau Linux :

7. Code source du noyau Linux : <a href="https://github.com/torvalds/linux/blob/master/kernel/bpf/verifier.c"><code>kernel/bpf/verifier.c</code></a>

### Implémentation Aurora :

8. <a href="https://github.com/gccloudone-aurora/aurora-platform-charts/tree/main/stable/aurora-platform/charts/aurora-core/templates/tetragon">Aurora Platform Charts</a>
