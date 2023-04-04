# Probando con kind

Simplificamos las pruebas usando un cluster kind que a su vez luego
aprovisionamos con helmfile.

## Requerimientos

Para poder completar esta prueba, **deben instalarse las siguientes
herramientas**:

* [kind](https://kind.sigs.k8s.io/)
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
* [helm](https://helm.sh/)
* [helmfile](https://helmfile.readthedocs.io/)
* [helm-secrets](https://github.com/jkroepke/helm-secrets/)
* [age](https://age-encryption.org/)
* [sops](https://github.com/mozilla/sops)
* **gettext:** necesario para poder usar el comando envsubst. Puede instalarse con
  `apt install gettext` o `yum install gettext`.
* **base64:** para (de)codificar strings en base64. Puede instalarse con `apt
  install coreutils` p `yum install coreutils`.

Además, es recomendable setear una serie de variables de ambiente que
simplifican el trabajo, no teniendo que usar más argumentos en los comandos.
Para ello, proponemos utilizar [direnv](https://direnv.net/)
que cargará automáticamente las variables especificadas en el archivo `.envrc`
provisto en el actual repositorio. Si se observa el archivo mencionado, se podrá
entender que las variables seteadas son:

```
export KUBECONFIG=$PWD/.kube/config
export SOPS_AGE_KEY_FILE=$PWD/.age/key
```

Estas variables son usadas para mantener la configuración de kubernetes para
kubectl relativas a este repositorio y no interferir con otras confifuraciones.
Esta variable es `KUBECONFIG` y es utilizada por kind, kubectl y helm, por lo
que recomendamos mantenerla seteada como acá se indica y de esta forma esperar
que la configuración de conexión al cluster esté en `kube/config`.
Por su parte, la variable `SOPS_AGE_KEY_FILE` es usada por sops, y por ende por
helm-secrets y helmfile para (des)cifrar datos sensibles. Age funciona cifrando
de forma asimétrica, trabajando de una forma muy similar a las claves ssh.
Cuando cifremos algo, podremos indicar qué claves públicas age podrán descifrar.

## Creación de un cluster

Kind es una excelente herramienta que simplifica las pruebas en un cluster k8s
que correrá en nuestra PC usando docker. La creación es muy simple, no siendo
necesario especificar una configuración como nosotros usaremos en el ejemplo
siguiente, pero es necesario realizar algunas modificaciones de las estándares:

```bash
kind create cluster --config .kind/config.yaml --name gitops
```

> El comando `kind create` dejará la configuración en `$HOME/.kube/config` o en el
> archivo indicado por la variable `KUBECONFIG`. Por ello, es importante respetar
> el seteo de dicha variable como se explicó anteriormente.

El comando anterior creará un cluster con la configuración que proveemos en
`.kind/config.yaml`. Leer la configuración aclarará las razones de su
existencia. Básicamente fijamos la versión de kubernetes, y agregamos labels al
nodo control plante para poder correr le ingress controller en ese nodo como lo 
[epecifica la documentación oficial de kind](https://kind.sigs.k8s.io/docs/user/ingress/).

Al ejecutar el comando, podremos conectar con el cluster y verificar su
funcionamiento:

```
kubectl get nodes
kubectl get pods -A
```

## Instalación de las herramientas

Luego, procedemos con la instalación de las herramientas necesarias usando
helmfile. Si bien podemos directamente correr el comando explicado a
continución, es importante observar cada archivo yaml dentro de la carpeta
[`helmfile.d/`](./helmfile.d), siguiendo los valores que se van referenciando. 
Puede observarse además, que los datos sensibles del chart de argo, se manejan
de forma cifrada desde el archivo `helmfile.d/values/argocd/secrets.yaml`. Este
archivo no lo versionamos cifrado porque la idea es que cada quien utilice sus 
propias claves y datos a cifrar. Entonces el paso siguiente será el de crear
nuestra clave AGE y cifrar este archivo. Otro archivo referenciado que no
versionaremos es el `helmfile.d/values/argocd-apps/values.yaml` y la razón es
que los datos usados en el ApplicationSet dependerán del nombre de tu
repositorio.

### Creación de clave AGE

Para crear nuestra clave privada age, y obtener la pública asociada, usamos el
siguiente comando (asumiento la variable `SOPS_AGE_KEY_FILE` existe y está
seteada como se mostró anteriormente):

```
mkdir -p .age
age-keygen -o $SOPS_AGE_KEY_FILE
```
> La salida del comando anterior imprime la clave pública y la privada (junto
> con la pública en forma de comentario) se almacena en el archivo indicado en
> la opción `-o`.

Este archivo, **¡¡no debe versionarse!!**. Quien lo posea podrá acceder a las
credenciales que serán cifradas. Por ello, puede observarse que el `.gitignore`
justamente ignora todo bajo `.age/` y `.kube/`.

> La clave Age aquí creada será para gestionar los datos sensibles
> correspondientes a la instalación del cluster kind. O sea que no debe
> confundirse con otra clave Age que luego mencionaremos para que Argo CD pueda
> descifrar otros datos.

### Cifrado de datos sensibles

Para el cifrado de datos usaremos sops. Sops puede cifrar datos usando diversos
mecanismos entre los que podemos mencionar Age, PGP, KMS, vault.

El archivo con datos sensibles de argocd considerará:

* La contraseña del usuario admin de argocd. La contraseña del usuario admin de
  argocd para esta prueba será **mikroways**, pero puede cambiarse como se
  explica en [la FAQ de argocd](https://github.com/argoproj/argo-cd/blob/master/docs/faq.md#i-forgot-the-admin-password-how-do-i-reset-it).
* Un secret usado por helm-secrets que contiene la clave Age privada para
  descifrar datos desde Argo CD. _Esta clave no es la misma que creamos
  anteriormente._
* Credenciales para que Argo CD pueda clonar repositorios git o descargar charts
  de repositorios privados.

La clave Age mencionada, no será la misma que creamos en el paso aterior. Será
otra clave privada que usarán los diferentes equipos que deban desplegar datos
en Argo CD y cifren aquellos sensibles de forma tal que Argo CD pueda
descifrarlos. Esto significa que Argo CD mantendrá una clave privada instalada
en el cluster y compartiremos la correspondiente clave pública para que cada
equipo de desarrolladores que necesite cifrar datos, pueda hacerlo para más de
una claves pública:

* Una compartida por el equipo de desarrollo. Quienes posean la privada podrá
  modificar los datos sensibles.
* Otra que corresponde a Argo CD. Sólamente Argo CD podrá descifrar estos datos.


Creamos entonces una nueva clave Age que usaremos para almacenar como Secret en
nuestro cluster:

```
AGE_KEY=$(age-keygen)

# Podemos ver el contenido de la variable con el comando:
echo $AGE_KEY
```

Por último, como sugerimos al inicio, estimamos trabajas con un repositorio
privado creado a partir del template. Asegurate el repositorio tuyo sea privado,
y procederemos a crear un Github Personal Access Token para darle acceso
únicamente al token para clonar repositorios. Esto se hace ingresando a [las
configuraciones de la cuenta, opciones de desarrollo, personal access
tokens](https://github.com/settings/tokens?type=beta). Crearemos un token que
únicamente pueda acceder a nuestro flamante repositorio privado, creado desde
nuestro template:

![GH personal access token](./assets/gh-personal-token.png)

Como muestra el gráfico:

1. Accedemos a la sección de **Personal access tokens**.
1. Seleccionamos **Fine grained tokens**.
1. Damos un **nombre** al token.
1. Ponemos **fecha de caducidad** al token.
1. Hacemos que **sólo aplique a un subconjunto de repositorios**. Esto dependerá de
   cómo se desee trabajar con Github. En este ejemplo elegimos nuestro
   repositorio personal clonado desde el template.

Más abajo, aparecen más opciones de qué permitimos hacer. Seleccionamos
únicamente **Contents: Read-only**, bajo **Repository Permissions**.

Github nos presentará nuestro token, cuyo formato es bastante extenso parecido
a **`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`**.
Este token debe usarse con nuestro username de github, sólo que al usar esta
contraseña el acceso será limitado.

> Recordar que el token **caducará en el tiempo configurado**.


Procedemos entonces a cifrar el archivo de secretos para argocd. Para
simplificar la tarea, entregamos un template de ese archivo que podemos usar de
la siguiente manera:

```
GH_USER=chrodriguez \
  GH_PASSWORD=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 \
  AGE_KEY_B64=$(echo $AGE_KEY | base64 -w0) \
  envsubst '${GH_USER},${GH_PASSWORD},${AGE_KEY_B64}' \
    < helmfile.d/values/argocd/secrets.yaml.tpl | tee /tmp/secret.yaml
```

> **Notar que se usan datos sensibles propios de su cuenta**.

El comando anterior debería mostrar el resultado de los reemplazos en pantalla
con los valores reemplazados para las variables:

* **`GH_USER`:** corresponde al username de github
* **`GH_PASSWORD`:** corresponde al token obtenido en el paso anterior
* **`AGE_KEY_B64`:** es la clave age privada (y pública como comentario)
  encodadas como base64.

Además de imprimirse en pantalla (con la idea de controlar si los reemplazos
fueron correctos), la salida además se guardará en `/tmp/secret.yaml` gracias al
comando `tee`.

> El archivo generado deja comentadas otras opciones que podrían ser de utilidad
> en otros escenarios. De esta forma cada quién sabrá como modificar el archivo
> generado a su gusto.

El paso final es cifrar la salida del comando anterior usando la clave age [creada
inicialmente](#creación-de-clave-age):

```
sops -e \
    -a $(cat $SOPS_AGE_KEY_FILE | grep public | cut -d: -f 2) \
    /tmp/secret.yaml > helmfile.d/values/argocd/secrets.yaml
```

> El subcomando detrás de `-a` obtiene la clave pública AGE correspondiente a
> la clave generada incialmente. Puede verificarse con la salida del comando
> `cat $SOPS_AGE_KEY_FILE | grep public | cut -d: -f 2`.

Destacamos nuevamente que la clave age que usamos para cifrar este valor,
almacena entre otras cosas, **otra clave age**, la generada y guardada
temporalmente en la variable `AGE_KEY`. Esta nueva clave privada, que residirá
como Secret en el namespace de Argo CD, será usada por Argo para poder descifrar
cualquier valor cifrado por los equipos que realizarán despliegues. Por tanto
_**no debe confundirse con la clave usada en este repositorio para instalar Argo
CD, y demás dependencias**_.

### ApplicationSets en tu repositorio

Este paso utilizará un script similar al usado con el cifrado de datos que
acabamos de completar. En este caso será para configurar el nombre de
tu repositorio en el Application Set:

```
GH_REPO_URL=https://github.com/chrodriguez/argocd-gitops-demo-example.git \
  GH_REVISION=main envsubst '${GH_REPO_URL},${GH_REVISION}' \
    < helmfile.d/values/argocd-apps/values.yaml.tpl \
    | tee helmfile.d/values/argocd-apps/values.yaml
```

> **Notar que se usan datos propios de su cuenta**.

El comando anterior debería mostrar el resultado de los reemplazos en pantalla
con los valores reemplazados para las variables:

* **`GH_REPO_URL`:** la URL del repositorio git. Utilizar https y no ssh.
* **`GH_REVISION`**: la rama donde se está trabajando. EL valor **main** suele
  ser el adecuado, salvo que se quiera probar algo en otra rama.

Además de imprimirse en pantalla, el resultado del comando se guardan en
`helmfile.d/values/argocd-apps/values.yaml`.

## Instalación de herramientas

Ya con los valores adecuados para nuestra demo, sumado a los datos ya cifrados
como hemos explicado en la sección anterior, podemos proceder a instalar todas
las herramientas:

* Argo CD
* Aplicaciones de Argo CD (crea el application set)
* [Nginx ingress controller](https://kubernetes.github.io/ingress-nginx/)

Con el siguiente comando, se instalarán las herramientas, además de crear un
ApplicationSet que dará vida inmediatamente a los despliegues descriptos en este
repositorio.

```bash
helmfile apply
```

> Helmfile utilizará helm, que deberá tener instalado el plugin de helm secrets
> para así poder descifrar los datos necesarios.

## Acceso a Argo CD

Hemos instalado Argo CD y configurado además un ingress controller. Para
acceder a las aplicaciones instaladas dentro del cluster kind, es necesario
entender que en los Linux modernos, aquellos basados en [systemd](https://systemd.io/),
el DNS se maneja con [systemd-resolved](https://www.freedesktop.org/software/systemd/man/systemd-resolved.service.html).
Este resolver nos ofrece la posibilidad de contar con que cualquier nombre de
DNS terminado en `.localhost` o `localhost.localdomain` resuelven a 127.0.0.1 y
::1. Es así como el DNS empleado en este ejemplo es **argocd.gitops.localhost**:

```
kubectl get ingress -A
```

> Debería ser el único ingress existente

Una vez que helmfile finalice de forma correcta, podemos ingresar a nuestro
Argo CD usando la URL http://argocd.gitops.localhost.

Los datos de acceso serán:

* **Usuario:** admin
* **Contraseña:** mikroways (salvo que se haya modificado).


## Recrear el cluster

Es posible destruir el cluster con

```bash
kind delete cluster --name gitops
```

La recreación será únicamente con los pasos:

```bash
kind create cluster --config .kind/config.yaml --name gitops
helmfile apply
```

## Obtener la clave Age pública de Argo CD

Como mencionamos en la instalación de Argo, la segunda clave Age creada es para
que cada equipo de desarrollo trabaje con datos sensibles que Argo CD pueda
descifrar. Obtendremos la clave con el siguiente comando:

```bash
kubectl -n argocd get secrets -l component=helm-secrets-age \
  -o jsonpath='{.items[0].data.key\.txt}' | base64 -d | grep 'public' | cut -d: -f2
```

El comando debe devolver la clave age pública. Algo como por ejemplo
`age1ej9q2trpkmnqah3e8y9776ss2yprkvyqlrp78nkx6scqaqc923mqrn0cys`. Esta clave
debe publicarse explícitamente para que **todos la conozcan y tengan fácil
acceso a ella**.

Los equipos de desarrollo que necesiten cifrar datos para más de una clave,
deberán setear la variable de ambiente **`SOPS_AGE_RECIPIENTS`** con varias
claves públicas separadas por coma. Luego cualquier propietario de alguna de las
privadas asociadas a esta lista de claves públicas podrá descifrar el dato. Más
información en [la documentación de
sops](https://github.com/mozilla/sops#22encrypting-using-age).

## Configurando los despliegues con Application Sets

¡Ya tenemos todas las piezas listas! Solamente nos queda pendiente describir en
este mismo repositorio, bajo la carpeta `../projects` cada despliegue que
queremos realizar de forma declarativa y aplicando GitOps de la forma más pura.
Invitamos a continuar con la lectura de cómo crear ambientes según la
documentación disponible en [`../projects`](../projects).
