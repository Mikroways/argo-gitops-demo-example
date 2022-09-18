# Ejemplo gitops

Este repositorio nos permite entender el flujo que proponemos desde Mikroways
para la gestión de despliegues basada en gitops.

## Principios

* El flujo propuesto únicamente aplica a despliegue de workloads desarrollados
  por equipos de devs
* Los despliegues de servicios de base, como ser CSI, ingress controllers,
  monitoreo y demás, se recomienda no manejarlos con ArgoCD. No al menos en este
  contexto.
* Este repositorio, debe contener un chart que es simplementeun wrapper del
  chart que da [origen al flujo](https://gitlab.com/mikroways/k8s/charts/gitops/argo-project).
  La razón, es que para que el flujo sea GitOps desde sus inicios, necesitamos
  un chart con los values en el mismo repositorio, para poder justamente crear
  aplicaciones con valueFiles realtivos.
* Este repositorio, usará [ApplicationSets](https://argocd-applicationset.readthedocs.io/en/stable/)
  con el fin de poder generar aplicaciones cuando encuentre archivos dentro de
  una carpeta específica de éste mismo repositorio.
  * Los archivos no pueden estar vacíos para que sean considerados
* Solamente los cluster admins podrán modificar este repositorio, creando de
  esta forma nuevos ambientes
* Si bien la idea es la de automatizar y generar la menor cantidad de errores
  por tareas repetibles, queremos que sea simple:
  * Probar nuevas funcionalides en un despliegue específico sin afectar al resto
  * Poder aplicar cambios masivos con el menor esfuerzo posible

## ¿Cómo funciona?

Una vez instalado ArgoCD con soporte de ApplicationSets, se crea un appset
basado en un generator de tipo git, que buscará archivos `values.yaml`. Estos
archivos, si existen, serán usados para generar ArgoCD Applications. El nombre
de éstas aplicaciones, serán parte de alguna convención. A modo de ejemplo,
hemos armado diferentes estrategias que se corresponden con diferentes
escenarios que hemos visto repetirse en diferentes clientes:

### Organismos con equipos por producto

En este escenario, tenemos múltiples equipos de desarrolladores, cada uno
gestiona múltiples aplicaciones. Esas aplicaciones se desplegarán de a _grupos 
de ellas mismas_, llamando a éstos grupos **proyectos**. Entonces, un proyecto
corresponde a un equipo, y desplegará varias aplicaciones que desarrolla ese
mismo equipo. Entonces, un proyecto debe tener varios ambientes (prod, qa, dev,
por ejemplo).

Aplican a este escenario, varios organismos gubernamentales. En este ejemplo,
representamos este escenario bajo la carpeta `proyectos/`. Bajo
esta carpeta se crea una carpeta con el nombre del **equipo**, dentro del
equipo, crearemos una carpeta para cada **proyecto** del equipo. Luego, en cada
proyecto de un equipo, se debe crear una carpeta con el nombre del cluster
dentro de ArgoCD: por defecto, el mismo cluster se lo llama **in-cluster**, pero
si creamos más clusters, por ejemplo **testing-cluster** y
**production-cluster**, entonces habrá una carpeta para cada despliegue de un
ambiente en un cluster: no es necesario usar el sufijo _-cluster_, simplemente
se crearán carpetas **in**, **testing** o **production**. Finalmente, dentro de
un cluster, para un proyecto de un team, se creará la carpeta con el nombre del
ambiente: prod, dev, qa, etc. Ya con la jerarquía completa de carpetas para este
ejemplo, se debe crear un archivo `values.yaml` **con algún contendio**. Los
valores de éste chart, se corresponderán con los aceptados por el [chart
específico en éste mismo repositorio](./charts/custom-argo-project).

El ApplicationSet que da vida a este flujo se llama `equipos-por-producto`.

### Organismos con un producto enlatado y multiples clientes

TODO

## El chart en este repositorio

Analizando el ApplicationSet del escenario correspondiente, se podrá
identificar que la lógica empleada es la de generar valores a partir de la
estructura de directorios correspondiente al escenario. Además, la de utilizar
en cada Application generado, un `valueFiles:` que tomará el valor del
`values.yaml` que representan a un Application determinado. 

### Las aplicaciones del chart

El chart en cuestión creará en ArgoCD un Proyecto limitando qué roles podrán
acceder como administradores o sólo lectura,  a ArgoCD para operar con un
ambiente determinado. Además define tres aplicaciones que se crean en el orden
en que se mencionan a continuación:

* **Aplicación base:** crea el namespace donde se desplegarán las siguientes
  aplicaciones. De esta forma, preapara LimitRange y ResourceQuota,
  NetworkPolicies y así podríamos agregar más restricciones que asegurarán tener
  ambientes controlados.
* **Aplicación de requerimientos:** permite antes de desplegar la aplicación,
  crear todos los recursos que sean necesarios. Por ejemplo bases de datos.
  _Esta aplicación es opcional_.
* **Aplicación en sí:** la aplicaicón que desencadenará el despliegue completo
  de aquellas aplicaciones que define un equipo determinado. _Esta aplicación es
  opcional_.

Si bien las dos últimas son opcionales, la idea es que estén definidas. Sin
embargo, mientras se crean, muchas veces es conveniente que los desarrolladores
prueben manualmente los despliegues hasta encontrar un equilibrio que luego
podrán versionar y sí usar un flujo completo de GitOps como el propuesto.
