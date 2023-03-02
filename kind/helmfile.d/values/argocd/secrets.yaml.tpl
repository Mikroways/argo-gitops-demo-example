configs:
    secret:
        # admin password is mikroways
        argocdServerAdminPassword: $2a$10$dsTwvxtgWugKmwV8cS9XuuBtDjUFnjI1/lKADNPx.ahujPnK1YWLe
    credentialTemplates:
      github-personal:
        url: https://github.com/$GH_USER
        username: $GH_USER
        password: $GH_PASSWORD
#        gitlab:
#            url: https://gitlab.com
#            username: readonly
#            password: supersecretpassword
#    repositories:
#      gitlab-deps-oci:
#        enableOCI: "true"
#        url: registry.gitlab.com
#        name: gitlab-helm-repo
#        type: helm
#        username: helm
#        password: supersecretpassword

extraObjects:
    - apiVersion: v1
      kind: Secret
      type: Opaque
      metadata:
        labels:
          component: helm-secrets-age
        name: helm-secrets-age-private-key
      data:
        key.txt: $AGE_KEY_B64
