// Tetragon et eBPF - Rapport technique
// Statistique Canada | Mars 2026

#import "@preview/barcala:0.3.0": informe

#show: informe.with(
  institucion: text(size: 24pt, weight: "bold")[🍁],
  unidad-academica: text(size: 18pt)[Statistique Canada],
  asignatura: "Équipe de la Zone | Plateforme cloud-native",
  trabajo: [Rapport technique],
  equipo: [Observabilité de sécurité],
  autores: (
    (nombre: "Paget, Bryan", email: "bryan.paget@statcan.gc.ca"),
  ),
  titulo: [Tetragon et eBPF],
  resumen: [
    Nous recommandons d'adopter *Tetragon* comme plateforme principale d'observabilité de sécurité pour l'infrastructure Kubernetes de Statistique Canada. Tetragon est déjà en cours d'exécution expérimentale dans les grappes Aurora (service Kubernetes géré de SSC). Le profil de risque est faible : le vérificateur eBPF garantit mathématiquement la sécurité des programmes et la consommation de ressources est minimale (CPU #sym.lt 1%, mémoire ~100-200 MiB par nœud). Ce rapport fournit les détails techniques, la stratégie de déploiement et une feuille de route d'implémentation de six semaines.
  ],
  fecha: "2026-03-26",
  formato: (
    tipografia: "Inter",
    margenes: "simétricos",
  ),
)

= Résumé

== Recommandation

Adopter *Tetragon* comme plateforme principale d'observabilité de sécurité pour l'infrastructure Kubernetes de Statistique Canada et contribuer le chart Helm au dépôt `cloudnative-platform-charts`.

== Contexte

Tetragon est déjà en cours d'exécution expérimentale dans les grappes Aurora (service Kubernetes géré de SSC). Plutôt que d'attendre le calendrier de l'équipe Aurora, Statistique Canada peut accélérer l'adoption en validant Tetragon indépendamment dans Zone DEV en utilisant notre grappe AKS avec les charges de travail Kubeflow.

== Risque et coût

Le profil de risque est faible. Le vérificateur eBPF garantit mathématiquement la sécurité des programmes et Tetragon a été validé dans Aurora. La consommation de ressources est minimale :

#list(
  [Surcharge CPU : #sym.lt 1% par nœud],
  [Mémoire : ~100-200 MiB par nœud],
  [Aucun agent utilisateur supplémentaire requis],
)

= Pourquoi l'espace noyau importe

== La taxe de performance

Les outils de sécurité traditionnels fonctionnent dans l'espace utilisateur, imposant trois pénalités de performance :

#enum(
  [
    *Changements de contexte :* Chaque observation nécessite de passer entre mode utilisateur et noyau, consommant 1-10 microsecondes par événement.
  ],
  [
    *Copie de données :* Les données d'événement doivent être copiées de la mémoire du noyau vers les tampons utilisateur via `copy_to_user()`.
  ],
  [
    *Latence :* Au moment où l'espace utilisateur observe un événement, il est déjà complété, permettant aux attaquants d'agir avant la détection.
  ],
)

== Exemple concret : NTSYNC dans Wine 11

Wine doit émuler les primitives de synchronisation Windows NT pour les applications Windows multi-threadées sur Linux. L'architecture originale nécessitait des appels RPC à un processus wineserver (deux changements de contexte par opération).

Wine 11 a introduit NTSYNC, un module noyau gérant la synchronisation dans le noyau. Résultats :

#table(
  columns: (1fr, 1fr, 1fr),
  inset: 6pt,
  [Jeu], [Avant (FPS)], [Après (FPS)],
  [Dirt 3], [110,6], [860,7],
  [Resident Evil 2], [26], [77],
  [Tiny Tina's Wonderlands], [130], [360],
)

Cela démontre le *Principe de Proximité* : déplacer le calcul vers l'endroit où résident les données.

= Qu'est-ce que Tetragon ?

== Aperçu de la plateforme

Tetragon est une plateforme d'observabilité de sécurité par Cilium (Isovalent) utilisant eBPF pour surveiller Kubernetes depuis le noyau. Il surveille :

#list(
  [
    *Exécution des processus :* démarrages, fins, signaux, relations parent-enfant
  ],
  [
    *Opérations fichiers :* lectures, écritures, suppressions, accès aux chemins sensibles
  ],
  [
    *Activité réseau :* connexions TCP/UDP, requêtes DNS, métadonnées HTTP
  ],
)

== Architecture

#list(
  [
    *TracingPolicy (CRD) :* Spécifie de manière déclarative quels événements surveiller
  ],
  [
    *Agent Tetragon (DaemonSet) :* S'exécute sur chaque nœud, charge les programmes eBPF, enrichit les événements avec les métadonnées Kubernetes
  ],
  [
    *Composants noyau :* Programmes eBPF, cartes et tampons perf
  ],
)

= Comprendre eBPF

== Définition

eBPF (Extended Berkeley Packet Filter) est une machine virtuelle dans le noyau qui exécute en toute sécurité des programmes fournis par l'utilisateur sans chargement de module noyau.

== Garanties de sécurité

Le vérificateur eBPF effectue une analyse statique exhaustive :

#list(
  [
    *Terminaison :* Pas de boucles infinies—tous les sauts arrière doivent être bornés
  ],
  [
    *Sécurité mémoire :* Peut seulement accéder à la pile de 512 octets, aux cartes pré-enregistrées et à la structure de contexte
  ],
  [
    *Bornes de ressources :* ~1M d'instructions max, 512 octets de pile, limites de cartes configurables
  ],
)

== Performance

#list(
  [Exécution native via compilation JIT],
  [Accès aux données sans copie dans la mémoire du noyau],
  [Impact de latence #sym.lt 1 microseconde par événement],
)

== Écosystème en croissance

Les cas d'utilisation d'eBPF s'étendent bien au-delà de la surveillance de sécurité. Les développements récents du noyau incluent :

#list(
  [
    *Ordonnancement CPU (Linux 6.12+) :* sched_ext permet de charger dynamiquement des ordonnanceurs CPU personnalisés sans recompilation du noyau
  ],
  [
    *Ordonnancement E/S (RFC 2026) :* UFQ déplace l'ordonnancement des E/S vers l'espace utilisateur pour plus de flexibilité
  ],
  [
    *Traitement réseau :* XDP fournit un filtrage de paquets haute performance avant la pile réseau du noyau
  ],
  [
    *Observabilité de sécurité :* Tetragon fournit une détection de menaces au niveau du noyau avec un impact minimal
  ],
)

Cette dynamique de l'écosystème indique qu'eBPF devient un [*mécanisme central d'extensibilité du noyau*] — une technologie stratégique dans laquelle il vaut la peine d'investir.

= Stratégie de déploiement

== Prérequis

#table(
  columns: (1fr, 1fr, 1fr),
  inset: 6pt,
  [Exigence], [Minimum], [Recommandé],
  [Noyau Linux], [4.19], [5.8+ pour fonctionnalités eBPF],
  [Kubernetes], [1.20], [1.25+],
  [Mémoire nœud], [2 Go], [4 Go+],
  [CPU nœud], [1 cœur], [2+ cœurs],
  [Helm], [3.x], [Dernier 3.x],
)

== Installation avec Helm

La méthode la plus simple est d'utiliser Helm. Ceci déploie Tetragon comme un DaemonSet, assurant que l'agent de sécurité s'exécute sur chaque nœud.

=== Étape 1 : Ajouter le dépôt Helm Cilium

```bash
helm repo add cilium https://helm.cilium.io
helm repo update
```

=== Étape 2 : Déployer Tetragon

Installer dans le namespace `kube-system` avec l'API gRPC activée pour l'CLI `tetra` :

```bash
helm install tetragon cilium/tetragon \
  --namespace kube-system \
  --create-namespace \
  --set tetragon.grpc.enabled=true
```

=== Étape 3 : Vérifier l'installation

Attendre le déploiement et confirmer que les pods sont en cours d'exécution :

```bash
kubectl rollout status -n kube-system ds/tetragon -w
kubectl get pods -n kube-system -l app.kubernetes.io/name=tetragon
```

== Interagir avec Tetragon

Une fois installé, utilisez l'CLI `tetra` pour voir les événements de sécurité en temps réel :

```bash
# Port-forward vers un pod Tetragon
kubectl port-forward -n kube-system ds/tetragon 54321:54321

# Voir les événements en format compact
tetra getevents -o compact
```

Pour des configurations avancées, appliquez des TracingPolicies (Custom Resource Definitions) pour surveiller des namespaces spécifiques ou appliquer des politiques.

== Considérations Azure AKS

Azure Kubernetes Service nécessite des conteneurs privilégiés pour eBPF. Utilisez `az aks update` pour les activer. Les valeurs Helm doivent spécifier les demandes de ressources (100m CPU, 256 MiB mémoire) et les limites (500m CPU, 512 MiB mémoire), activer le mode privilégié et configurer l'export d'événements vers Elasticsearch.

= Feuille de route d'implémentation

== Phase 1 : Validation dans DEV (Semaines 1-2)

Déployer Tetragon dans la grappe AKS Zone DEV et valider avec Kubeflow :

#list(
  [Déployer Tetragon via Helm avec des valeurs spécifiques à AKS],
  [Déployer des TracingPolicies de base pour l'exécution de processus, l'accès aux fichiers et les connexions réseau],
  [Configurer l'export d'événements vers un index Elasticsearch de test],
  [Établir les mesures de référence (CPU #sym.lt 1%, mémoire #sym.lt 200 MiB par nœud)],
)

*Critères de succès :* Pods Tetragon sur tous les nœuds, événements dans Elasticsearch, surcharge dans les cibles.

== Phase 2 : Prêt pour la production (Semaines 3-4)

Définir les standards opérationnels et créer l'infrastructure-comme-code :

#list(
  [Définir les SLO : latence #sym.lt 100 ms, débit 10 000 événements/s, disponibilité 99,9%],
  [Créer un module Terraform pour `cloudnative-platform-charts`],
  [Ajouter Tetragon aux scripts d'approvisionnement des grappes],
  [Documenter les procédures de mise à niveau],
)

== Phase 3 : Intégration et automatisation (Semaines 5-6)

Automatiser le déploiement des politiques et implémenter l'alerte :

#list(
  [Créer un pipeline CI/CD pour les mises à jour de TracingPolicy],
  [Implémenter l'alerte : accès identifiants → PagerDuty, connexions inhabituelles → Slack, volume élevé → courriel],
  [Documenter les procédures, guides de dépannage et lignes directrices de politiques],
)

= Performance et sécurité

== Consommation de ressources

#table(
  columns: (1fr, 1fr),
  inset: 6pt,
  [Métrique], [Valeur],
  [CPU (inactif)], [#sym.lt 0,1%],
  [CPU (normal)], [0,3-0,5%],
  [CPU (volume élevé)], [0,8-1,2%],
  [Mémoire agent], [100-150 MiB par nœud],
  [Mémoire opérateur], [50-70 MiB],
  [Cartes eBPF], [10-20 MiB par nœud],
)

== Sécurité et confidentialité

Tetragon détecte les techniques MITRE ATT&CK :

#list(
  [
    *T1003 (Dump d'identifiants) :* Surveille l'accès à `/etc/shadow` et `/etc/passwd`
  ],
  [
    *T1059 (Interpréteur de commandes) :* Surveille l'exécution de shells
  ],
  [
    *T1078 (Comptes valides) :* Surveille l'accès aux fichiers d'identifiants
  ],
  [
    *T1095 (Protocole non application) :* Surveille les connexions réseau inhabituelles
  ],
)

*Confidentialité :* Tetragon collecte seulement des métadonnées (chemins binaires, arguments, horodatages, PIDs)—pas de contenus de fichiers, de charges utiles réseau ou de sorties de commandes.

= Comparaison et conclusion

== Comparaison des alternatives

#table(
  columns: (1fr, 1fr, 1fr, 1fr),
  inset: 6pt,
  [*Fonctionnalité*], [*Tetragon*], [*Falco*], [*Audit K8s*],
  [Implémentation], [eBPF natif], [Module noyau/eBPF], [API server seulement],
  [Surcharge CPU], [#sym.lt 1%], [2-5%], [Variable],
  [Intégration K8s], [CRD natifs], [Config externe], [API seulement],
  [Langage de politiques], [YAML], [Lua], [N/A],
  [Actions de réponse], [Dans le noyau], [Espace utilisateur], [Aucune],
)

== Recommandation finale

Tetragon représente une amélioration fondamentale de l'observabilité de sécurité Kubernetes :

#list(
  [
    *Excellence technique :* eBPF fournit une surveillance au niveau du noyau sûre et efficace avec des garanties prouvables
  ],
  [
    *Avantages opérationnels :* #sym.lt 1% de CPU, intégration K8s automatique, détection en temps réel
  ],
  [
    *Alignement stratégique :* Répond aux exigences eBPF organisationnelles, déjà validé dans Aurora
  ],
  [
    *Risque faible :* Technologie mature avec fort soutien industriel
  ],
)

Procéder avec le plan en trois phases : validation immédiate dans DEV, contribution à court terme du chart Helm, expansion à moyen terme en production et intégration à long terme avec le SIEM.

= Références

#list(
  [Cilium. *Documentation Tetragon.* https://tetragon.io/docs/],
  [Cilium. *Guide d'installation Tetragon.* https://tetragon.io/docs/installation/kubernetes/],
  [Fondation eBPF. *Qu'est-ce que eBPF?* https://ebpf.io/],
  [Rice, L. (2020). *Learning eBPF.* O'Reilly Media.],
  [Documentation du noyau Linux. *Sous-système eBPF.* https://www.kernel.org/doc/html/latest/bpf/],
  [MITRE. *Cadre ATT&CK.* https://attack.mitre.org/],
  [Équipe Aurora SSC. *Charts de la plateforme Aurora.* https://github.com/gccloudone-aurora/aurora-platform-charts],
  [Lakshman, S. *Securing Kubernetes: Integrating AKS with Tetragon.* Medium.],
  [Stream Security. *How to Deploy Tetragon on an EKS Cluster.*],
  [Oracle. *Tetragon eBPF Observability on OKE.* https://docs.oracle.com/en/learn/tetragon-ebpf-observability-oke/],
)
