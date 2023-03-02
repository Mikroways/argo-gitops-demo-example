# Helm chart wrapper

Este chart es una dependencia directa del chart que da vida al [marco de trabajo
con GitOps](https://github.com/Mikroways/argo-gitops-flow/tree/main/charts/argo-project).
Al ser dependencia, prácticamente es el mismo chart, salvo que los valores que
seteamos estarán bajo el nombre de la dependencia utilizad, en este caso
**argo-project**. La razón de usar este chart, es porque Argo CD creará
Applications usando ApplicationSets que deberán levantar valores relativos al
repositorio, este repositorio. Es el primer paso de varios para que funcione el
marco propuesto. 

Algunas convenciones más que debemos considerar son:

* Ignorar en git `Chart.lock` y `charts/`. De esta forma, si la dependencia
  utiliza un wildcard en la versión, Argo CD siempre traerá la última versión
  para ese wildcard.
* Setear values por defecto en caso de ser necesario. Por ejemplo, si queremos
  establecer un valor X para los LimitRange o ResourceQuotas, el mejor lugar
  sería acá, usando un `values.yaml` con datos como por ejemplo:

  ```
   argo-project:
      argo:
        baseApplication:
              helm:
                  values:
                    quota:
                      requests:
                        cpu: '4'
                        memory: 8Gi
                      limits:
                        cpu: '8'
                        memory: 16Gi
                      pods: "20"
                      persistentvolumeclaims: "15"
                      resourcequotas: "1"
                      services: "10"

                    limits:
                      default:
                        cpu: 500m
                        memory: 512Mi
                      defaultRequest:
                        cpu: 500m
                        memory: 256Mi
                      type: Container
  ```
