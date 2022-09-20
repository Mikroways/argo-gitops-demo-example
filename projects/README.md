# Organismos con equipos por producto

Este ejemplo representa uno de los escenario planteados. Tendremos un
directorio para cada equipo de desarrolladores. Dentro de ese directorio un
cluster (in es para el caso de in-cluster). Luego, en el directorio que
representa en qué cluster realizar un despliegue, tenemos el ambiente. 

Los ambientes se configurarán con el archivo `values.yaml` que está encriptado
con sops con dos claves:

* La clave kms de mikroways
* Una clave age que permite a argocd desencriptar las claves age

Analizar cómo se configura cada ejemplo en esta estructura. Nos pareció
pertinente hacerlo con:

* Una app tipo wordpress, que ya tiene un chart definido
* Una app como el redmine de mikroways que usa una registry privada y además
  ejemplifica un caso de uso típico.

En los ejemplos, prestar especial atención a como se configuran los
repositorios.
