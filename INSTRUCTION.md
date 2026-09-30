# Task 9: StatefulSet (MySQL) and app connection

## Prerequisites

- [kind](https://kind.sigs.k8s.io/) and `kubectl` installed
- Docker running

## Create cluster and deploy

From the repository root:

```bash
chmod +x bootstrap.sh
./bootstrap.sh
```

`bootstrap.sh`:

1. Creates a **kind** cluster from **`cluster.yml`** in the repository root (required by Task step 2)
2. Creates namespaces `mysql` and `todoapp`
3. Applies **`secret.yml`** (MySQL + app secrets) and **`configMap.yml`** (app + `init.sql` for MySQL)
4. Applies **`statefulSet.yml`** — headless **Service** + **StatefulSet** (3 replicas)
5. Waits until **`mysql-0`** is Ready
6. Deploys the ToDo app **Deployment** with DB settings from **Secret**

If the cluster already exists, delete it before re-running:

```bash
kind delete cluster --name kind
```

(Adjust the name if your `cluster.yml` sets a custom cluster name.)

## Validate MySQL StatefulSet

```bash
kubectl get ns mysql todoapp
kubectl get svc -n mysql
kubectl get statefulset,pods,pvc -n mysql
```

Headless service `mysql` (first document in `statefulSet.yml`, README § StatefulSet p.8) should have **CLUSTER-IP: None**. Pods: `mysql-0`, `mysql-1`, `mysql-2`. Without it there is no stable DNS `mysql-0.mysql...` for the app `HOST`.

Check probes and resources:

```bash
kubectl describe pod mysql-0 -n mysql
```

### init.sql mount

`init.sql` is provided via ConfigMap `mysql-config` and mounted at **`/docker-entrypoint-initdb.d`** (file `init.sql` inside the pod).

```bash
kubectl exec -n mysql mysql-0 -- ls -la /docker-entrypoint-initdb.d
kubectl exec -n mysql mysql-0 -- cat /docker-entrypoint-initdb.d/init.sql
```

### MySQL credentials from Secret

```bash
kubectl get secret mysql-secret -n mysql -o yaml
kubectl exec -n mysql mysql-0 -- printenv MYSQL_ROOT_PASSWORD MYSQL_USER MYSQL_PASSWORD
```

Connect to DB on **mysql-0**:

```bash
kubectl exec -it -n mysql mysql-0 -- mysql -uroot -p"$(
  kubectl get secret mysql-secret -n mysql -o jsonpath='{.data.MYSQL_ROOT_PASSWORD}' | base64 -d
)" -e "SHOW DATABASES;"
```

Expect database **`tododb`**.

## Validate app → mysql-0

App Secret **`app-secret`** (namespace `todoapp`) must expose `NAME`, `USER`, `PASSWORD`, `HOST`.  
`HOST` points to the **0-index** pod: `mysql-0.mysql.mysql.svc.cluster.local`.

```bash
POD=$(kubectl get pods -n todoapp -l app=todoapp -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n todoapp "$POD" -- printenv NAME USER HOST
kubectl exec -n todoapp "$POD" -- sh -c 'test -n "$PASSWORD" && echo PASSWORD is set'
```

Wait for Deployment:

```bash
kubectl wait --for=condition=Available deployment/todoapp -n todoapp --timeout=300s
kubectl get pods -n todoapp -l app=todoapp
```

Health checks:

```bash
kubectl port-forward -n todoapp service/todoapp-service 8080:80
```

In another terminal:

```bash
curl -sS http://127.0.0.1:8080/api/health
curl -sS http://127.0.0.1:8080/api/ready
```

Open the UI: [http://127.0.0.1:8080/](http://127.0.0.1:8080/)

Logs (migrations / DB errors):

```bash
kubectl logs -n todoapp -l app=todoapp --tail=50
```

## Configuration summary

| Component | Detail |
|-----------|--------|
| StatefulSet | 3 replicas, namespace `mysql`, `volumeClaimTemplates` 5Gi RWO |
| Service | Headless `mysql` (`clusterIP: None`) |
| App DB host | `mysql-0` via DNS `mysql-0.mysql.mysql.svc.cluster.local` |
| Django | `settings.py` uses env `NAME`, `USER`, `PASSWORD`, `HOST` |

## Clean up

```bash
kind delete cluster
```
