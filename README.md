# Ejemplo gitops

Este repositorio nos permite entender el flujo que proponemos desde Mikroways
para la gestión de despliegues basada en gitops.

Hemos dispuesto a este repositorio como [template](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-template-repository)
para que puedas **replicarlo con tu usuario u organización** de forma completa,
simulando un ambiente real. Es fundamental que trabajes en un **repositorio
privado** durante esta demo. De esta forma podrás comprobar que cada
configuración aquí descripta funciona con tus propias credenciales. Y de paso
se aplica uno de los patrones propuestos de cifrar claves.

## Principios

* El flujo propuesto fue pensado para aplicarse en el despliegue de
  aplicaciones, y no para el despliegue de servicios de infraestructura dentro
  del cluster k8s.

  >  Los despliegues de servicios de base, como ser CSI, ingress controllers,
  >  monitoreo y demás, se recomienda no manejarlos con ArgoCD. No al menos en
  >  este contexto del flujo descripto.

* Este repositorio, más allá de mantener la documentación y ejemplos de cómo
  crear un cluster kind (algo que en un ambiente real no será necesario), debe
  **contener un chart que depende** del chart que da
  [origen al flujo](https://github.com/Mikroways/argo-gitops-flow/tree/main/charts/argo-project). 
* La razón de la dependencia mencionada en el punto anterior se debe a que el
  flujo sea GitOps desde su concepción. Por ello, necesitamos versionar los
  values del chart el mismo repositorio, para poder justamente crear
  aplicaciones con [`valueFiles`](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/#values-files)
  relativos.
* Para dar vida al chart anterior usaremos [ApplicationSets](https://argocd-applicationset.readthedocs.io/en/stable/)
  con el fin de poder generar aplicaciones cuando se encuentren archivos dentro
  de una carpeta específica de este mismo repositorio.
  * Los archivos no pueden estar vacíos para que sean considerados.
* Solamente los cluster admins podrán modificar este repositorio, creando de
  esta forma nuevos ambientes.
* Si bien la idea es la de automatizar y generar la menor cantidad de errores
  por tareas repetibles, queremos que su uso nos oferzca:
  * Simplicidad en el uso.
  * Probar nuevas funcionalides en un despliegue específico sin afectar al resto
  * Poder aplicar cambios masivos con el menor esfuerzo posible

## Uso del template

Creá un **repositorio privado** a partir de éste template y seguí las
instrucciones sobre el ejemplo completo usando kind.

# TODO revisar para abajo

# Ejemplo completo usando kind

[kind](https://kind.sigs.k8s.io/) permite instanciar un cluster k8s rápidamente
usando docker. Ingresar en la carpeta [`kind/`](./kind) y siguiendo las
instrucciones del readme, podrá tenerse un cluster nuevo con todas las
herramientas necesarias desplegadas en él. Ese despliegue usará herramientas que
son requeridas para esta prueba.

## El chart en este repositorio

Analizando el ApplicationSet del escenario [`/kind`](./kind), se podrá
entender cómo es el generador de ArgoCD Applications y de qué forma se inyectan
valores a través de `valueFiles:`. Debido que este archivo suele tener datos
sensibles, se recomienda (como se muestra en este ejemplo) utilizar cifrado del
archivo usando [helm secrets](https://github.com/jkroepke/helm-secrets), es
decir, se cifrarán usando [sops](https://github.com/mozilla/sops) y
[age](https://github.com/FiloSottile/age).

Las aplicaciones generadas, no representan un despliegue para nuestro flujo,
sino una implementación del patrón Apps of Apps para crear nuevas aplicaciones
ArgoCD que nos permiten:

* Crear el ambiente
* Asegurarlo y limitar el uso de recursos
* Crear imagePullSecrets
* Desplegar aquellos requerimientos del ambiente
* Desplegar la aplicación del ambiente

Para ello, el chart en este repositorio, creará en ArgoCD un Proyecto limitando
qué roles podrán acceder como administradores o sólo lectura a ArgoCD para
operar con ese ambiente. Además define tres aplicaciones que se crean en el
orden en que se mencionan a continuación:

* **Aplicación base:** crea el namespace donde se desplegarán las siguientes
  aplicaciones. De esta forma, prepara LimitRange y ResourceQuota,
  NetworkPolicies y así podríamos agregar más restricciones que asegurarán tener
  ambientes controlados.
* **Aplicación de requerimientos:** permite antes de desplegar la aplicación,
  crear todos los recursos que sean necesarios. Por ejemplo bases de datos.
  _Esta aplicación es opcional_.
* **Aplicación en sí:** la aplicación que desencadenará el despliegue completo
  de aquellas aplicaciones que define un equipo determinado. _Esta aplicación es
  opcional_.

Si bien las dos últimas son opcionales, la idea es que estén definidas. Sin
embargo, mientras se crean, muchas veces es conveniente que los desarrolladores
prueben manualmente los despliegues hasta encontrar un equilibrio que luego
podrán versionar y sí usar un flujo completo de GitOps como el propuesto.
