#/bin/bash
REGISTRY=xxxx:5000/etcd
ETCD_VERSION=v3.3.9
TOKEN=my-etcd-token
CLUSTER_STATE=new
LISTENING_PORT=2380
NAME_1=etcd-node-1
NAME_2=etcd-node-2
NAME_3=etcd-node-3
HOST_1=10.32.242.213
HOST_2=10.32.242.216
HOST_3=10.32.242.218
CLUSTER=${NAME_1}=http://${HOST_1}:${LISTENING_PORT},${NAME_2}=http://${HOST_2}:${LISTENING_PORT},${NAME_3}=http://${HOST_3}:${LISTENING_PORT}
ETCD_DATA_DIR=/mnt/etcd
mkdir ${ETCD_DATA_DIR}

# node
THIS_NAME=${NAME_1}
THIS_IP=${HOST_1}

docker run -d \
  -p 2379:2379 \
  -p 2380:2380 \
  --volume=${ETCD_DATA_DIR}:/etcd-data \
  --name etcd ${REGISTRY}:${ETCD_VERSION} \
  /usr/local/bin/etcd \
  --data-dir=/etcd-data --name ${THIS_NAME} \
  --initial-advertise-peer-urls http://${THIS_IP}:2380 \
  --listen-peer-urls http://0.0.0.0:2380 \
  --advertise-client-urls http://${THIS_IP}:2379 \
  --listen-client-urls http://0.0.0.0:2379 \
  --initial-cluster ${CLUSTER} \
  --initial-cluster-state ${CLUSTER_STATE} \
  --initial-cluster-token ${TOKEN}