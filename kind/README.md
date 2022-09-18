# Probando con kind

Simplificamos las pruebas usando un cluster kind que a su vez luego
aprovisionamos con helmfile.

## Creando el cluster

En este mismo directorio, proveemos un `.envrc` que setea la variable
`KUBECONFIG` para que kind trabaje en este directorio.

Procedemos entonces a crear un cluster kind:

```
kind create cluster
```

Luego, instalamos las herramientas necesarias con helmfile:

```
helmfile --no-color apply
```

Analizamos la salida de helmfile y conectamos con port-forward como explica el
INFO del chart de argocd. Recordar que la contraseña de admin, es **mikroways**.

La instalación de argocd, utiliza helm secrets con una clave KMS de mikroways
que garantiza que argocd configure un repositorio que pueda acceder a descargar
el chart de helm.

