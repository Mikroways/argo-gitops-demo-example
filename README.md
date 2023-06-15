# Ejemplo gitops

Este repositorio nos permite evidenciar cómo es el [marco de trabajo con
GitOps](https://gitops-workflow.mikroways.net/) que proponemos desde
[Mikroways](https://mikroways.net/).

Hemos dispuesto a este repositorio como [template](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-template-repository)
para que puedas **replicar las pruebas con tu usuario u organización** de forma
completa, simulando un ambiente real. Es fundamental que trabajes en un
**repositorio privado** durante tus pruebas. De esta forma podrás comprobar que
cada configuración aquí descripta funciona con tus propias credenciales. Y de
paso se aplican buenas prácticas de seguridad y uno de los patrones propuestos,
el de cifrar datos sensibles.

## Principios

* El flujo propuesto fue pensado para aplicarse en el despliegue de
  aplicaciones, y no para el despliegue de servicios de infraestructura dentro
  del cluster k8s.

  >  Los despliegues de servicios de base, como ser CSI, ingress controllers,
  >  monitoreo y demás, se recomienda no manejarlos con ArgoCD. No al menos con
  >  el marco aquí descripto.

* Este repositorio, más allá de mantener la documentación y ejemplos de cómo
  crear un cluster kind (algo que en un ambiente real no será necesario), debe
  **contener un chart que depende** del chart que da
  [origen al flujo](https://github.com/Mikroways/argo-gitops-flow/tree/main/charts/argo-project).
  En general la carpeta [`kind/`](./kind) no debería estar presente en ámbitos
  productivos.
  * La razón de por qué este repositorio mantiene un chart y una serie de
    directorios para cada equipo, se debe al flujo inherentemente GitOps. Por
    ello, necesitamos versionar los values del chart en el mismo repositorio,
    para poder justamente crear aplicaciones con [`valueFiles`](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/#values-files)
    relativos.
  * Para dar vida al chart en este repositorio usaremos [ApplicationSets](https://argocd-applicationset.readthedocs.io/en/stable/)
    con el fin de poder generar aplicaciones cuando se encuentren nuevos
    contenidos dentro de una carpeta específica de este mismo repositorio.

    >  Los archivos no pueden estar vacíos para que sean considerados.

* Proponemos que únicamente los cluster admins mantengan este repositorio, siendo
  su responsabilidad la creación de nuevos ambientes, asignando ResourceQuotas y
  de esta forma teniendo el control final de qué pude realizar cada equipo.
* Si bien la idea del marco de trabajo es la de automatizar y minimizar la
  cantidad de errores por tareas repetibles, queremos maximizar:
  * Simplicidad en el uso.
  * Permitir realizar pruebas de nuevas funcionalides en un despliegue específico
    sin afectar al resto de los despliegues, desacoplándo cada despliegue de su
    ambiente.
  * Aplicar cambios masivamente con un mínimo esfuerzo.

# Uso del template

[Crear un **repositorio privado** a partir del actual repositorio template](https://github.com/Mikroways/argo-gitops-demo-example/generate),
siguiendo las instrucciones sobre el ejemplo propuesto explicado en la
documentación bajo la carpeta [`kind/`](./kind).

# El chart en este repositorio

Analizando el ApplicationSet utilizado en la prueba propuesta en la carpeta
[`/kind`](./kind), se podrá entender cómo es el [generador de ArgoCD Applications](https://argocd-applicationset.readthedocs.io/en/stable/Generators/)
y de qué forma se inyectan valores a través de `valueFiles:`. Debido que este
archivo suele tener datos sensibles, los datos aquí versionados serán
cifrados y luego versionados con las explicaciones pertinentes que ustedes
deberán seguir para completar las pruebas.

El chart aquí usado depende de [dos charts públicos](https://github.com/Mikroways/argo-gitops-flow)
que coniguran los prerequisitos necesarios para implementar este flujo de gitops
usando el patrón Apps of Apps para crear nuevas aplicaciones ArgoCD
considerando:

* Crear un ambiente para un despliegue
* Asegurarlo y limitar el uso de recursos
* Crear imagePullSecrets
* Desplegar aquellos requerimientos del ambiente
* Desplegar la aplicación del ambiente

Cada despliegue creará tres aplicaciones ArgoCD con las características
mencionadas a continuación:

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
embargo, durante el proceso de construcción de los charts correspondientes al
despliegue de una solución, puede ser útil crear las aplicaciones desde la UI de
ArgoCD hasta lograr cierta madurez y a partir de ese momento, aplicar el marco
completo de GitOps utilizando las aplicaciones de requerimientos y la aplicación
en sí.
