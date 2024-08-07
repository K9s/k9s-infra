#!/usr/bin/env bash
set -eE

KIND_VERSION=${KIND_VERSION:-"0.23.0"}
KIND_K8S_VERSION=${KIND_K8S_VERSION:-"1.30.0"}
KIND_IMAGE_DIGEST=${KIND_IMAGE_DIGEST:-"047357ac0cfea04663786a612ba1eaba9702bef25227a794b52890dd8bcd692e"}

docker build --build-arg BASE_IMAGE=kindest/node:v${KIND_VERSION}@sha256:${KIND_IMAGE_DIGEST} . -t kindest/node:current

if [[ -z "${DELETE_CLUSTER}" ]]; then
  DELETE_CLUSTER=false
else
  DELETE_CLUSTER=true
fi

if [[ -z "${CLUSTER_NAME}" ]]; then
  CLUSTER_NAME=local
else
  CLUSTER_NAME=$CLUSTER_NAME
fi

if hash kubectl; then
  echo "kubectl is already present @ $(which kubectl)"
else
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
fi

if hash kustomize; then
  echo "kustomize is already present @ $(which kustomize)"
else
  curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
  sudo install -o root -g root -m 0755 kustomize /usr/local/bin/kustomize
fi

if kind --version | grep "${KIND_VERSION}"; then
  echo "kind v${KIND_VERSION} is already present @ $(which kind)"
else
  sudo curl -Lo /usr/local/bin/kind -z /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-amd64
  sudo chmod +x /usr/local/bin/kind
fi

if $DELETE_CLUSTER -eq "true"; then
  kind delete cluster --name $CLUSTER_NAME
fi

if kind get clusters | grep $CLUSTER_NAME > /dev/null; then
  echo "Kind Cluster ${CLUSTER_NAME} already exists"
else
  kind create cluster --config=kind-cluster.yaml --name $CLUSTER_NAME
fi

kubectl config use-context kind-$CLUSTER_NAME

if hash flux; then
  echo "Flux command present at $(which flux)"
else
  curl -s https://fluxcd.io/install.sh | sudo bash
fi

KUBESEAL_VERSION="0.27.0"
if kubeseal --version | grep $KUBESEAL_VERSION; then
  echo "kubeseal command present at $(which kubeseal)"
else
  curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
  tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
  sudo install -m 755 kubeseal /usr/local/bin/kubeseal
  rm kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz || true
  rm kubeseal || true
fi

## Minio
docker run --name minio -d --restart=always --net=kind --mount type=bind,source=$(realpath ../../../../../),target=/data -p 9000:9000 -p 9001:9001 --user $(id -u):$(id -g) quay.io/minio/minio:RELEASE.2022-05-26T05-48-41Z server /data --console-address ":9001" || true

## Local registry and pull-through proxy
echo "<------Starting local registry and registry proxies"
docker run -d --restart=always --net=kind -p "127.0.0.1:5000:5000" --name "registry" registry:2  > /dev/null 2>&1 || true
docker run -d --restart=always --net=kind -p "127.0.0.1:5001:5000" --name "proxy-docker-io" -e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io registry:2  > /dev/null 2>&1 || true
docker run -d --restart=always --net=kind -p "127.0.0.1:5002:5000" --name "proxy-k8s-gcr-io" -e REGISTRY_PROXY_REMOTEURL=https://k8s.gcr.io registry:2  > /dev/null 2>&1 || true
docker run -d --restart=always --net=kind -p "127.0.0.1:5003:5000" --name "proxy-quay-io" -e REGISTRY_PROXY_REMOTEURL=https://quay.io registry:2  > /dev/null 2>&1 || true
docker run -d --restart=always --net=kind -p "127.0.0.1:5004:5000" --name "proxy-gcr-io" -e REGISTRY_PROXY_REMOTEURL=https://gcr.io registry:2  > /dev/null 2>&1 || true
docker run -d --restart=always --net=kind -p "127.0.0.1:5005:5000" --name "proxy-gitlab-com" -e REGISTRY_PROXY_REMOTEURL=https://registry.gitlab.com registry:2  > /dev/null 2>&1 || true

# Document the local registry
# https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:5000
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

kustomize build --load-restrictor=LoadRestrictionsNone --reorder=legacy flux-system/ | kubectl apply -f - || true  # Note this has to be run twice due to missing Flux CRs
kustomize build --load-restrictor=LoadRestrictionsNone --reorder=legacy flux-system/ | kubectl apply -f -

sleep 5

kubectl apply -f ../../../../../state/sealed-master.yaml

echo "<------Waiting for Flux Kustomization infrastructure-services to be created------>"
while ! kubectl get -n flux-system kustomizations infrastructure-services; do sleep 5; done
echo "<------Waiting for Flux Kustomization infrastructure-services to be ready------>"
kubectl wait -n flux-system --for=condition=ready --timeout=240s Kustomization infrastructure-services
echo "<------Waiting for all helmreleases to be ready------>"
while kubectl get --no-headers -A helmreleases | grep -v True; do sleep 5 && echo --------------------------------; done
echo "<------helmreleases ready------>"
kubectl get --no-headers -A helmreleases

echo "<######## Bootstrap complete ########>"
