#!/bin/bash

kind create cluster --config cluster.yml

kubectl apply -f .infrastructure/namespace.yml
kubectl apply -f .infrastructure/secret.yml
kubectl apply -f .infrastructure/configMap.yml
kubectl apply -f .infrastructure/statefulSet.yml

kubectl wait --for=condition=Ready pod/mysql-0 -n mysql --timeout=300s

kubectl apply -f .infrastructure/pv.yml
kubectl apply -f .infrastructure/pvc.yml
kubectl apply -f .infrastructure/deployment.yml
kubectl apply -f .infrastructure/clusterIp.yml
kubectl apply -f .infrastructure/nodeport.yml
