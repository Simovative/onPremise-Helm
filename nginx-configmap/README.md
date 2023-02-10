# Nginx ingress configuration

the Nginx Ingress Controller has its configs inside a ConfigMap resource using the syntax specified on the docs: https://docs.nginx.com/nginx-ingress-controller/configuration/global-configuration/configmap-resource/

# how to find the configmap

since The ingress controller is installed via Helm, it automatically gets a ConfigMap from the helm installation process.
The fastest way to overwrite it, would be finding the used configmap, and overwriting it with the name:

1. get controller pod name:

```
kubectl get pods -n ingress-nginx
```

2. describe pod and grep for configmap:

```
kubectl -n ingress-nginx describe pod yourNginxIngressPod | grep configmap
```

3. change the name in nginx-configmap.yaml to match the assigned -nginx-configmaps= configmap and overwrite it.

```shell
vi nginx-configmap.yaml
kubectl apply -f nginx-configmap.yaml
```
