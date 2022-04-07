#!/usr/bin/env bash
set -e

docker build --build-arg BASE_IMAGE=kindest/node:v1.23.4@sha256:0e34f0d0fd448aa2f2819cfd74e99fe5793a6e4938b328f657c8e3f81ee0dfb9 . -t kindest/node:v1.23.4

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

if hash kustomize; then
  echo "kustomize is already present @ $(which kustomize)"
else
  curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
  mv kustomize /usr/local/bin
  sudo chmod +x /usr/local/bin/kustomize
fi

if hash kind; then
  echo "kind is already present @ $(which kind)"
else
  sudo curl -Lo /usr/local/bin/kind -z /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.12.0/kind-linux-amd64
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

## Minio
docker run --name minio -d --restart=always --net=kind --mount type=bind,source=$(realpath ../../../../),target=/data -p 9000:9000 -p 9001:9001 minio/minio server /data --console-address ":9001" || true

## Local registry and pull-through proxy
docker run -d --restart=always --net=kind -p "127.0.0.1:5000:5000" --name "registry" registry:2 || true
docker run -d --restart=always --net=kind -p "127.0.0.1:5001:5000" --name "proxy-docker-io" -e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io registry:2 || true
docker run -d --restart=always --net=kind -p "127.0.0.1:5002:5000" --name "proxy-k8s-gcr-io" -e REGISTRY_PROXY_REMOTEURL=https://k8s.gcr.io registry:2 || true
docker run -d --restart=always --net=kind -p "127.0.0.1:5003:5000" --name "proxy-quay-io" -e REGISTRY_PROXY_REMOTEURL=https://quay.io registry:2 || true
docker run -d --restart=always --net=kind -p "127.0.0.1:5004:5000" --name "proxy-gcr-io" -e REGISTRY_PROXY_REMOTEURL=https://gcr.io registry:2 || true

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

echo "Bootstrap complete"
