applicationsets:
  - name: equipos-por-producto
    generators:
      - git:
          repoURL: $GH_REPO_URL
          revision: $GH_REVISION
          files:
              - path: projects/**/values.yaml
    template:
      metadata:
        name: '{{path[1]}}-{{path[2]}}-{{path[3]}}-{{path[4]}}'
      spec:
        syncPolicy:
          automated:
            prune: false
            selfHeal: true
        project: default
        source:
          path: charts/custom-argo-project
          repoURL: $GH_REPO_URL
          targetRevision: $GH_REVISION
          helm:
            values: |
              argo-project:
                namespace: '{{path[1]}}-{{path[2]}}-{{path[4]}}'
                cluster:
                  name: '{{ path[3] }}'
                  nameSuffix: 'cluster'
                argo:
                  namespace: argocd
                  baseApplication:
                    helm:
                      parameters:
                        - name: namespace
                          value: '{{path[1]}}-{{path[2]}}-{{path[4]}}'
                    syncPolicy:
                      automated: {}
            valueFiles:
              - secrets+age-import-kubernetes://argocd/helm-secrets-age-private-key#key.txt?../../{{path}}/values.yaml
        destination:
          server: https://kubernetes.default.svc
          namespace: default
