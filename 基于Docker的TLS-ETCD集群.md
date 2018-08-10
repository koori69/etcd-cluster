---
title: 基于Docker的TLS ETCD集群
date: 2018-08-06 11:21:57
tags:
  - etcd
  - ssl
categories:
  - etcd
  - ssl

---

# SSL证书

## 下载cfssl

```shell
curl -L https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 > /usr/local/bin/cfssl
curl -L https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 > /usr/local/bin/cfssljson
chmod +x /usr/local/bin/cfssl
chmod +x /usr/local/bin/cfssljson
```

## 创建CA

```shell
mkdir /root/ssl
cd /root/ssl
cfssl print-defaults config > ca-config.json
cfssl print-defaults csr > ca-csr.json
```

修改ca-config.json 

```shell
[root@etc0 ssl]# cat ca-config.json
{
    "signing": {
        "default": {
            "expiry": "8760h"
        },
        "profiles": {
            "kubernetes": {
                "expiry": "8760h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]
          }
        }
    }
}
```

server auth表示client可以用该ca对server提供的证书进行验证

client auth表示server可以用该ca对client提供的证书进行验证

创建证书签名请求

```shell
[root@etc0 ssl]# cat ca-csr.json
{
    "CN": "kubernetes",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "US",
            "L": "CA",
            "ST": "San Francisco",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
```

生成CA证书和私钥

```shell
# cfssl gencert -initca ca-csr.json | cfssljson -bare ca
# ls ca*
ca-config.json ca.csr ca-csr.json ca-key.pem ca.pem
```

 

## 创建kubernetes证书



```shell
[root@etc0 ssl]# cat kubernetes-csr.json
{
    "CN": "kubernetes",
    "hosts": [
        "127.0.0.1",
        "10.32.242.213",
        "10.32.242.216",
        "10.32.242.218",
        "10.32.242.222",
        "10.32.242.219",
        "10.32.242.217",
        "10.32.242.221",
        "10.32.242.220",
        "10.32.242.205"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
        "C": "CN",
        "ST": "BeiJing",
        "L": "BeiJing",
        "O": "k8s",
        "OU": "System"
        }
    ]
}
```

生成Kubernetes证书和密钥

```
# cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
# ls kubernetes*
kubernetes.csr kubernetes-csr.json kubernetes-key.pem kubernetes.pem
```

## 分发证书文件

在每台etcd机器中运行

```
# mkdir -p /etc/kubernetes/ssl
# cp *.pem /etc/kubernetes/ssl
```

# ETCD启动

```shell
#/bin/bash
REGISTRY=xxx:5000/etcd
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
CLUSTER=${NAME_1}=https://${HOST_1}:${LISTENING_PORT},${NAME_2}=https://${HOST_2}:${LISTENING_PORT},${NAME_3}=https://${HOST_3}:${LISTENING_PORT}
ETCD_DATA_DIR=/mnt/etcd
ETCD_SSL_DIR=/etc/kubernetes/ssl
mkdir ${ETCD_DATA_DIR}

# node
THIS_NAME=${NAME_1}
THIS_IP=${HOST_1}

docker run -d \
  --restart="always" \
  -p 2379:2379 \
  -p 2380:2380 \
  --volume=${ETCD_DATA_DIR}:/etcd-data \
  --volume=${ETCD_SSL_DIR}:/ssl \
  --name etcd ${REGISTRY}:${ETCD_VERSION} \
  /usr/local/bin/etcd \
  --data-dir=/etcd-data --name ${THIS_NAME} \
  --cert-file=/ssl/kubernetes.pem \
  --key-file=/ssl/kubernetes-key.pem \
  --peer-cert-file=/ssl/kubernetes.pem \
  --peer-key-file=/ssl/kubernetes-key.pem \
  --trusted-ca-file=/ssl/ca.pem \
  --client-cert-auth=true \
  --auto-tls=true \
  --peer-trusted-ca-file=/ssl/ca.pem \
  --initial-advertise-peer-urls https://${THIS_IP}:2380 \
  --listen-peer-urls https://0.0.0.0:2380 \
  --advertise-client-urls https://${THIS_IP}:2379 \
  --listen-client-urls https://0.0.0.0:2379 \
  --initial-cluster ${CLUSTER} \
  --initial-cluster-state ${CLUSTER_STATE} \
  --initial-cluster-token ${TOKEN}
```

## 查看成员状态

```shell
etcdctl member list --cacert /etc/kubernetes/ssl/ca.pem --cert /etc/kubernetes/ssl/kubernetes.pem --key /etc/kubernetes/ssl/kubernetes-key.pem
```

```shell
docker exec etcd /bin/sh -c "export ETCDCTL_API=3 && /usr/local/bin/etcdctl member list --cacert /ssl/ca.pem --cert /ssl/kubernetes.pem --key /ssl/kubernetes-key.pem"
```

## 查看Cluster健康状态

```shell
ETCDCTL_API=2 etcdctl --ca-file  /etc/kubernetes/ssl/ca.pem --cert-file /etc/kubernetes/ssl/kubernetes.pem --key-file /etc/kubernetes/ssl/kubernetes-key.pem --endpoints=https://127.0.0.1:2379 cluster-health
```

