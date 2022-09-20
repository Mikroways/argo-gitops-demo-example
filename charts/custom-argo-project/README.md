# Helm chart wrapper

Este chart se crea de ésta forma para poder tomar los values de forma relativa
por ArgoCD. Cuando trabajemos de ésta forma, debemos notar las siguientes
convenciones:

* Ignorar en git `Chart.lock` y `charts/`. De esta forma, si la dependencia
  utiliza un wildcard, siempre estaremos trayendo la última versión para ese
  wildcard.
* Setear values por defecto en caso de ser necesario
