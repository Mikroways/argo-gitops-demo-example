# Probando con kind

Simplificamos las pruebas usando un cluster kind que a su vez luego
aprovisionamos con helmfile.

## Requerimientos

Para poder completar esta prueba, deben instalarse las siguientes herramientas:

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

Una vez instladas las aplicaciones anteriores, procederemos a crear los
directorios donde se guardarán las configuraciones recién mencionadas:

```
mkdir -p .config .age
```

## Creación de un cluster

Kind es una excelente herramienta que simplifica las pruebas en un cluster k8s
que correrá en nuestra PC usando docker. La creación es muy simple, no siendo
necesario especificar una configuración como nosotros usaremos en el ejemplo
siguiente, pero es necesario realizar algunas modificaciones de las estándares:

```bash
kind create cluster --config .kind/config.yaml
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
age-keygen -o $SOPS_AGE_KEY_FILE
```
> La salida del comando anterior imprime la clave pública y la privada (junto
> con la pública en forma de comentario) se almacena en el archivo indicado en
> la opción `-o`.

Este archivo, **¡¡no debe versionarse!!**. Quien lo posea podrá acceder a las
credenciales que serán cifradas. Por ello, puede observarse que el `.gitignore`
justamente ignora todo bajo `.age/` y `.kube/`.

### Cifrado de datos sensibles

Para el cifrado de datos usaremos sops. Sops puede cifrar datos usando diversos
mecanismos entre los que podemos mencionar Age, PGP, KMS, vault.

El archivo con datos sensibles de argocd considerará:

* La contraseña del usuario admin de argocd
* Un secret usado por helm-secrets para descifrar datos cifrados con una clave
  age determinada
* Credenciales para que Argo CD pueda clonar repositorios git o descargar charts
  de repositorios privados.

La contraseña del usuario admin de argocd será por defecto **mikroways**, pero
puede cambiarse como se explica en [la FAQ de argocd](https://github.com/argoproj/argo-cd/blob/master/docs/faq.md#i-forgot-the-admin-password-how-do-i-reset-it).

La clave Age mencionada, no debería ser la misma que usamos para cifrar el
archivo en custión. Será otra clave privada que será necesaria para que cada
equipo que desarrolle con datos cifrados, considere la clave pública acá creada.
Esto significa que Argo CD mantendrá una clave privada instalada en el cluster y
compartiremos la clave pública asociada para que cada equipo de desarrolladores
que necesite cifrar datos, pueda hacerlo con varias claves públicas: una
compartida por el equipo de desarrollo y la de argocd, para que él pueda
descifrar los datos.

Creamos entonces una nueva clave Age:

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
únicamente pueda acceder a nuestro flamante repositorio, privado y creado desde
nuestro template:

![GH personal access token](./assets/gh-personal-token.png)

Como muestra el gráfico:

1. Accedemos a la sección de Personal access tokens.
1. Seleccionamos Fine grained tokens.
1. Damos un nombre al token.
1. Ponemos fecha de caducidad del token.
1. Hacemos que sólo aplique a un subconjunto de repositorios. Esto dependerá de
   cómo se desee trabajar con Github. En este ejemplo elegimos nuestro
   repositorio personal clonado desde el template.

Más abajo, aparecen más opciones de qué permitimos hacer. Seleccionamos
únicamente **Contents: Read-only**, bajo _Repository Permissions_.

Github nos presentará nuestro token, cuyo formato es bastante extenso parecido
a **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**.
Este token debe usarse con nuestro username de github, sólo que al usar esta
contraseña el acceso será limitado.


Procedemos entonces a cifrar el archivo de secretos para argocd. Para
simplificar la tarea, entregamos un template de ese archivo que podemos usar de
la siguiente manera:

```
GH_USER=chrodriguez \
  GH_PASSWORD=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 \
  GH_REPO_URL=https://github.com/chrodriguez/argocd-gitops-demo-example.git \
  AGE_KEY_B64=$(echo $AGE_KEY | base64 -w0) \
  envsubst '${GH_USER},${GH_PASSWORD},${AGE_KEY_B64},'${GH_REPO_URL}' \
    < helmfile.d/values/argocd/secrets.yaml.tpl | tee /tmp/secret.yaml
```

El comando anterior debería mostrar el template en pantalla con los valores
reemplazados para las variables `GH_USER`, `GH_PASSWORD`, `GH_REPO_URL` y
`AGE_KEY_B64`. **Notar que deben usarse los datos propios de su cuenta**. Además
de imprimirse en pantalla, se guardan en `/tmp/secret.yaml`, gracias al comando
`tee`.

> El template deja otros ejemplos de cómo dar de alta repositorios o templates
> de credenciales que quedan como comentarios pero sirven de guía en caso de
> querer realizar más pruebas.

El paso final es cifrar la salida del comando anterio usando la clave age [creada
inicialmente](#creación-de-clave-age):

```
sops -e \
    -a $(cat $SOPS_AGE_KEY_FILE | grep public | cut -d: -f 2) \
    /tmp/secret.yaml > helmfile.d/values/argocd/secrets.yaml
```

> El subcomando detrás de `-a` obtiene la clave pública AGE correspondiente a
> la clave generada incialmente.

Es para destacar que la clave age que usamos para cifrar este valor, almacena en
un secret **otra clave age**, la generada y guardada temporalmente en la
variable `AGE_KEY`. Esta clave privada, que residirá como Secret en el namespace
de Argo CD, será usada por Argo para poder descifrar cualquier valor. Por tanto
_**no debe confundirse con la clave usada en este repositorio para instalar Argo
CD**_.

### ApplicationSet con tu repositorio

Este paso, utilizará un templae similar al usado con el cifrado de datos que
realizamos en el paso anterior, pero en este caso para configurar el nombre de
tu repositorio, este que creaste desde el template.

```
GH_REPO_URL=https://github.com/chrodriguez/argocd-gitops-demo-example.git \
  GH_REVISION=main envsubst '${GH_REPO_URL},${GH_REVISION}' \
    < helmfile.d/values/argocd-apps/values.yaml.tpl \
    | tee helmfile.d/values/argocd-apps/values.yaml
```

El comando anterior debería mostrar el template en pantalla con los valores
reemplazados para las variables `GH_USER`, `GH_PASSWORD` y `AGE_KEY_B64`. **Notar
que deben usarse los datos propios de su cuenta**. Además de imprimirse en
pantalla, se guardan en `helmfile.d/values/argocd-apps/values.yaml`.

## Instalación de herramientas

Ya con los valores adecuados para nuestra demo, sumado a los datos ya cifrados
como hemos explicado en la sección anterior, podemos proceder a instalar todas
las herramientas:

* Argo CD
* Aplicaciones de Argo CD (crea el application set)
* Nginx ingress controller

Con el siguiente comando, se instalarán las herramientas, además de crear un
ApplicationSet que dará vida inmediatamente a los despliegues descriptos en este
repositorio.

```bash
helmfile apply
```

> Helmfile utilizará helm, que deberá tener instalado el plugin de helm secrets
> para así poder descifrar los datos necesarios.

## Acceso a Argo CD

Hemos instalado Argo CD y configurado además un ingress controller, el de
[nginx](https://kubernetes.github.io/ingress-nginx/). Para que sea posible
acceder a las aplicaciones instaladas dentro del cluster, es necesario entender
que en los Linux modernos, aquellos basados en [systemda](https://systemd.io/),
el DNS se maneja con
[systemd-resolved](https://www.freedesktop.org/software/systemd/man/systemd-resolved.service.html).
Este resolver nos ofrece la posibilidad de contar con que cualquier nombre de
DNS terminado en `.localhost` o `localhost.localdomain` resuelven a 127.0.0.1 y
::1. Es así como el DNS empleado en esta demo es argocd.gitops.localhost:

```
kubectl get ingress -A
```

Una vez que helmfile finalice de forma correcta, podemos ingresar a nuestro
flamante Argo CD usando: http://argocd.gitops.localhost.

Los datos de acceso serán:

* **Usuario:** admin
* **Contraseña:** mikroways (salvo que la hayas modificado).


## Recrear el cluster

Es posible destruir, crear e inicializar el cluster en un comando

```bash
kind delete cluster && kind create cluster && helmfile --no-color apply 
```

## Helm secrets

Los secretos que desencripta ArgoCD podrán encriptarse con las siguiente age
pubic key:

```bash
age193tt38de3fzuujax2krt450mfpaf25zc957h6qp7nrp2uxzj3apsywa3sz
```

Por ejemplo, bajo el directorio [`projects/`](../projects) se define esta
clave como recipiente de AGE. La clave privada está encriptada a su vez con sops
pero con kms
