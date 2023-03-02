# Ambientes y despliegues con GitOps

Esta carpeta probablemente sea la más importante en este repositorio. La razón
es que el Argo CD ApplicationSet configurado en el despliegue original de Argo
CD será el que de vida a cómo se podrán gestionar las aplicaciones con GitOps.
Lo interesante, es que no necesariamente debe existir un único ApplicationSet,
sino que pueden haber más de uno, donde cada uno de ellos utilice diferentes
estrategias para generar Aplicaciones de Argo CD. En esta prueba que exponemos,
seguimos un caso bastante habitual, donde un organismo mantiene equipos de
desarrolladores, donde cada equipo genera diferentes productos. Luego, esos
productos se despliegan en algún ambiente, donde ese ambiente puede estar en el
mismo cluster, otro cluster y un namespace determinado.

Luego de exponer nosotros acá una idea de cómo proceder, cada quién podrá ir
formateando a medida esta propuesta, usando nuevas estrategias o tal vez
probando varias a la vez. La única restricción que debe considerarse es que dos
Aplicaciones de Argo CD generadas por diferentes Application Set no se llamen de
igual forma para evitar problemas.

## Un ejemplo de cómo organizar este repositorio

Este ejemplo mantiene una carpeta dentro de la actual, que representará a cada
equipo de desarrolladores, por ejemplo **mikroways-dev-team**. Dentro de ese
directorio un deberá crearse una carpeta que identificará algún producto, por
ejemplo **product-one**. Luego, debemos indicar el cluster usado para el
despliegue. Finalmente, se debe crear dentro de la carpeta correspondiente al
identificador del cluster, otra con el nombre del ambiente, por ejemplo
**testing** o **production**. O sea, lo que tendremos finalmente es una ruta
completa como la siguiente:

```bash
projects/mikroways-dev-team/product-one/in/testing
```

> Utilizamos como identificador del cluster **in** cuando argocd utilizará como
> cluster de despliegue el mismo donde corre Argo CD, es decir in-cluster.

Dentro de la ruta de un equipo, producto, cluster y ambiente, es donde
configuraremos ese ambiente mediante un archivo `values.yaml` que será cifrado
con alguna clave Age que compartirán quienes gestionan ambientes, y además, la
clave Age que usará Argo CD para descifrar datos sensibles.

### Configurando las claves para trabajar en esta carpeta

Como indicamos en la sección anterior, necesitamos disponer de una clave Age
privada (con su pública asociada) para poder trabajar en un equipo que pueda
trabajar cifrando las configuraciones de cada ambiente. Entonces, siguiendo la
línea de utilizar [direnv](https://direnv.net/) para el seteo de variables
diferentes en cada directorio.

> Los requisitos para tener un cluster ya configurado para usar este flujo, se
> encuentran documentados en la carpeta [`../kind`](../kind)

Creamos entonces en este directorio, un archivo `.envrc` con el siguiente
contenido:

* **`SOPS_AGE_KEY_FILE`:** requerido. Es el archivo que contiene la clave Age
  privada que compartirán los cluster admins para cifrar los datos aquí usados.
* **`SOPS_AGE_RECIPIENTS`:** requerido. Es un arreglo de claves públicas Age:
  una correspondiente a la clave privada mencionada en el punto anterior, la
  otra es la clave pública Age usada por Argo CD y que puede obtenerse como se
  explica en la documentación sobre Argo CD dentro del directorio [`../kind`](../kind/##obtener-la-clave-age-publica-de-argo-cd).
* `KUBECONFIG`: no requierido. Sólo si se quiere mantener acceso al mismo
  cluster kind creado en la explicación dentro de la carpeta `../kind`.

Si se está siguiendo la prueba propuesta, se aconseja entonces ejecutar en **la
carpeta `projects/`**:

```bash
# Enlazamos con las configuraciones de ../kind
ln -fs ../kind/.kube
ln -fs ../kind/.age

# Obtenemos la clave pública Age de ArgoCD
AGE_PK1=$(kubectl --kubeconfig .kube/config -n argocd get secrets \
  -l component=helm-secrets-age -o jsonpath='{.items[0].data.key\.txt}' \
  | base64 -d | grep 'public' | cut -d: -f2 | tr -d ' ')

# Obtenemos la clave pública Age usada por nosotros para cifrar los values
AGE_PK2=$(cat .age/key| grep 'public' | cut -d: -f2 | tr -d ' ')

# Creamos el .envrc con los datos recientemente obtenidos
cat > .envrc <<EOF
export KUBECONFIG=\$PWD/.kube/config
export SOPS_AGE_KEY_FILE=\$PWD/.age/key
export SOPS_AGE_RECIPIENTS=${AGE_PK1},${AGE_PK2}
EOF

```

Al ejecutar el comando anterior, **direnv nos solicitará permitir el `.envrc`
generado**:

```bash
direnv allow
```

## Despliegues con el marco de trabajo

Mostraremos diferentes usos para entender cómo proponemos manejar los ambientes.
Para ello, enunciaremos los ejemplos aquí propuestos e iremos guiando las
pruebas para poder instanciar cada una de ellas:

* Crear un ambiente sin despliegues extra
* Crear un ambiente con un despliegue de una aplicación sin usar un repositorio
  de GitOps
* Crear un ambiente con un despliegue de una aplicación usando un repositorio
  de GitOps
* Crear un ambiente con un despliegue de una aplicación usando un repositorio
  de GitOps que utiliza imágenes en una registry privada
* Crear un ambiente con un despliegue de una aplicación usando un repositorio
  que depende de un chart almacenado en una registry privada

### Un ambiente sin despliegues

Este escenario nos permite usar nuestro marco de GitOps para crear un nuevo
ambiente que únicamente creará un namespace y un proyecto en ArgoCD. La idea es
que podamos:

* Definir para el proyecto Argo CD quiénes pueden acceder a manipular los
  objetos de Argo CD y quienes únicamente verlo.
* Generar quotas mediante Resource Quotas que limitarán en el namespace creado
  cuántos recursos se pueden utilizar, cantidad de pods, servicios, PVC, etc.
* Establecer valores a asignar a los pods que no seteen recursos como requests y
  limits.

Para continuar con esta prueba, en este directorio crearemos entonces un archivo
siguiendo nuestra propuesta de directorios como se explicó anteriormente: un
archivo llamado `values.yaml` dentro de una carpeta con el nombre de un
**equipo**, seguio por el nombre de un **proyecto**, luego el **cluster** y
finalmente el nombre del **ambiente**. Hemos dejado esta estructura creada, con
un archivo que se llama `values.clear.yaml` (que no respeta el nombre necesario
para que Argo CD ApplicationSets lo considere). Entonces, lo que se propone
hacer para que Argo cree este archivo es lo siguiente:

```
cd team-mikroways/sandbox/in/testing
cp values.clear.yaml values.yaml
```

> Es importante estar parados en la carpeta donde reside este `README`, es decir
> `projects/`

Lo que estamos haciendo, es crear el archivo`values.yaml` a partir del entregado
como ejemplo en este repositorio. Es posible dejar este archivo en texto claro o
cifrarlo. Por el momento, no lo ciframos para evidenciar que ambos escenarios
funcionan. Para que argo tome ese cambio, tendremos que subir el cambio.

```
git add .
git commit -m "Add sandbox values.yaml"
git push origin main
```

Inmediatamente después de haber hecho el commit debemos esperar a que
ApplicationSets detecte el cambio (generalmente esto [demora 3
minutos](https://argocd-applicationset.readthedocs.io/en/stable/Generators-Git/#2-configure-applicationset-with-the-webhook-secret-optional)).
Al detectarlo, en la UI de Argo CD veremos que aparece una nueva aplicación en
el projecto default. Esta aplicación creará:

* Un proyecto de Argo CD que limitará los permisos usando los grupos mencionados
  en el `values.yaml` a administradores y readonly users.
* Una aplicación de ArgoCD que creará un namespace nuevo, con el nombre del
  proyecto

Una vez que Argo CD converge, podremos observar con `kubectl` la existencia del
nuevo namespace:

```
kubectl get namespaces
kubectl describe namespace team-mikroways-sandbox-testing
```

Cuya salida será algo parecido a:

```
Name:         team-mikroways-sandbox-testing
Labels:       argocd.argoproj.io/instance=team-mikroways-sandbox-testing-in-base
              kubernetes.io/metadata.name=team-mikroways-sandbox-testing
Annotations:  argocd.argoproj.io/sync-wave: -1
Status:       Active

No resource quota.

No LimitRange resource.
```

### Introduciendo un pequeño cambio

Cambiaremos el archivo de `values.yaml` las líneas que deshabilitaban el uso de
`ResourceQuotas` y `LimitRange`:

```
argo-project:
    argo:
        ...
        baseApplication:
            helm:
                values: |
                    quota:
                      enabled: true
                      ...
                    limits:
                      enabled: true

```

Una vez modificado entonces el archivo, agregarlo a git:

```
git add .
git commit -m "Add sandbox values.yaml"
git push origin main
```

Aguardamos a que Argo CD detecte los cambios (o desde la UI, es posible forzar
un Refresh). Luego podremos evidenciar los cambios con:

```
kubectl describe namespace team-mikroways-sandbox-testing
```

Cuya salida deberá mostrar algo como:

```
Name:         team-mikroways-sandbox-testing
Labels:       argocd.argoproj.io/instance=team-mikroways-sandbox-testing-in-base
              kubernetes.io/metadata.name=team-mikroways-sandbox-testing
Annotations:  argocd.argoproj.io/sync-wave: -1
Status:       Active

Resource Quotas
  Name:                   resource-quota
  Resource                Used  Hard
  --------                ---   ---
  limits.cpu              0     1
  limits.memory           0     2Gi
  persistentvolumeclaims  0     5
  pods                    0     2
  requests.cpu            0     1
  requests.memory         0     1Gi
  resourcequotas          1     1
  services                0     5

Resource Limits
 Type       Resource  Min  Max  Default Request  Default Limit  Max
Limit/Request Ratio
 ----       --------  ---  ---  ---------------  -------------
-----------------------
 Container  cpu       -    -    600m             600m           -
 Container  memory    -    -    256Mi            512Mi          -
```

Este escenario de crear un namespace y un proyecto de Argo CD, con o sin quotas,
nos ayudará a poder trabajar con la UI, o desde la cli de kubernetes para
prototipar lo que luego podremos transformar en un escenario más purista en lo
que respecta a GitOps.

### Creamos un ambiente con un despliegue con requerimientos (no recomendado)

### Creamos un ambiente con un despliegue con requerimientos usando un
repositorio externo


