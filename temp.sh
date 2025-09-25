
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OUT="${ROOT}/support-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${OUT}"/{env,etcd,k3s,helm,kube-system,traefik,cert-manager,argo,dns,manifests}
echo "Support output dir: ${OUT}"
{
  echo "==== [ENV] OS & Kernel ===="
  uname -a || true
  cat /etc/os-release || true

  echo "==== [ENV] Docker ===="
  docker version || true
  docker info || true

  echo "==== [ENV] Network ===="
  ip addr || true
  ip route || true

  echo "==== [ENV] Firewall ===="
  command -v ufw >/dev/null && ufw status verbose || true
  command -v firewall-cmd >/dev/null && firewall-cmd --list-all || true
  iptables -S || true
  nft list ruleset || true
} | tee "${OUT}/env/host.txt"
{
  echo "==== [ETCD] docker ps ===="
  docker ps --filter "name=core-etcd" -a

  echo "==== [ETCD] health ===="
  curl -sfv http://127.0.0.1:2379/health || true

  echo "==== [ETCD] logs ===="
  docker logs --tail=500 core-etcd || true
} | tee "${OUT}/etcd/etcd.txt"
{
  echo "==== [K3S] Version ===="
  k3s --version || true

  echo "==== [K3S] systemd status ===="
  systemctl status k3s --no-pager || true
} | tee "${OUT}/k3s/status.txt"

# Journal logs (1500 lines cap)
journalctl -u k3s.service --no-pager -n 1500 > "${OUT}/k3s/journal-k3s.log" || true
journalctl -u k3s.service --no-pager -o short-iso > "${OUT}/k3s/journal-k3s-all.log" || true
{
  echo "==== [K8S] Nodes ===="
  kubectl get nodes -o wide || true
  echo "==== [K8S] Versions ===="
  kubectl version --output=yaml || true
  echo "==== [K8S] Recent events (kube-system) ===="
  kubectl -n kube-system get events --sort-by=.lastTimestamp | tail -n 200 || true
} | tee "${OUT}/kube-system/cluster.txt"
{
  echo "==== [HELM-CONTROLLER] Deploy & logs ===="
  kubectl -n kube-system get deploy helm-controller -o yaml || true
  kubectl -n kube-system logs deploy/helm-controller --tail=1000 || true

  echo "==== [HELM-CHART] traefik HelmChart & HelmChartConfig ===="
  kubectl -n kube-system get helmchart traefik -o yaml || true
  kubectl -n kube-system get helmchartconfig traefik -o yaml || true

  echo "==== [HELM JOBS] traefik ===="
  kubectl -n kube-system get jobs | grep -i traefik || true
  for j in helm-install-traefik-crd helm-install-traefik; do
    echo "---- Job ${j} desc ----"
    kubectl -n kube-system describe job "${j}" || true
    echo "---- Job ${j} pods ----"
    pods=$(kubectl -n kube-system get pods --selector=job-name="${j}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
    for p in ${pods}; do
      echo "---- Pod ${p} logs ----"
      kubectl -n kube-system logs "${p}" --all-containers --tail=1000 || true
      kubectl -n kube-system describe pod "${p}" || true
    done
  done
} | tee "${OUT}/helm/traefik-helm.txt"
{
  echo "==== [TRAEFIK] CRDs ===="
  for c in ingressroutes.traefik.io ingressroutetcps.traefik.io ingressrouteudps.traefik.io middlewares.traefik.io traefikservices.traefik.io tlsoptions.traefik.io serverstransports.traefik.io; do
    kubectl get crd "$c" -o yaml || true
  done

  echo "==== [TRAEFIK] Deployment & Service ===="
  kubectl -n kube-system get deploy traefik -o yaml || true
  kubectl -n kube-system get svc traefik -o yaml || true

  echo "==== [TRAEFIK] Pods logs ===="
  kubectl -n kube-system logs -l app.kubernetes.io/name=traefik --all-containers --tail=1000 || true
} | tee "${OUT}/traefik/traefik.txt"
{
  echo "==== [ARGO] NS and Pods ===="
  kubectl -n argocd get all || true
  echo "==== [ARGO] Server logs ===="
  kubectl -n argocd logs -l app.kubernetes.io/name=argocd-server --tail=1000 || true
  echo "==== [ARGO] Application objects ===="
  kubectl -n argocd get applications.argoproj.io -o yaml || true
} | tee "${OUT}/argo/argocd.txt"
{
  echo "==== [CM] Pods ===="
  kubectl -n cert-manager get all || true
  echo "==== [CM] logs ===="
  kubectl -n cert-manager logs -l app.kubernetes.io/instance=cert-manager --all-containers --tail=1000 || true
  echo "==== [CM] Issuers/ClusterIssuers ===="
  kubectl get clusterissuer,issuer -A -o yaml || true
  echo "==== [CM] Certificates/Orders/Challenges ===="
  kubectl get certificate,order,challenge -A -o yaml || true
} | tee "${OUT}/cert-manager/cm.txt"

# 单独导出你 repo 中的关键 manifest 内容，确保版本一致对齐
cp -a kubernetes/manifests "${OUT}/manifests/" || true
# dig from Cloudflare resolver
dig @1.1.1.1 argocd.core01.prod.gglohh.top +short | tee "${OUT}/dns/argocd.txt"
dig @1.1.1.1 n8n.core01.prod.gglohh.top +short | tee "${OUT}/dns/n8n.txt"
dig @1.1.