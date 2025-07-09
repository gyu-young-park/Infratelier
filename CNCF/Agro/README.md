# Argo Project

## ArgoCD
ArgoCD를 kubernetes cluster에 설치해보도록 하자.

https://argo-cd.readthedocs.io/en/stable/

위의 링크를 참조하여 ArgoCD를 설치할 수 있다.

```sh
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

설치가 완료되었다면 다음의 결과가 나온다.

```sh
kubectl get po -n argocd 
NAME                                               READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                    1/1     Running   0          37s
argocd-applicationset-controller-67c79fccd-jdh5f   1/1     Running   0          37s
argocd-dex-server-76686f75bd-j9m2g                 1/1     Running   0          37s
argocd-notifications-controller-588d87b767-4trsb   1/1     Running   0          37s
argocd-redis-59c6f8b4b5-tdbjv                      1/1     Running   0          37s
argocd-repo-server-57db679bf7-wdddc                1/1     Running   0          37s
argocd-server-67b6bf4f8d-n7gv9                     1/1     Running   0          37s
```

ingress를 열어 접근해보도록 하자. 만약 ingress를 쓸 필요가 없는 상황이면 NodePort나 cloud에서 제공하느 loadbalancer를 사용하면 된다.


잘 접속되었다면 이제 테스트 앱을 배포해보도록 하자. 예제로 가장 많이 사용되는 `guestbook`을 사용하도록 하자.
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default

  source:
    repoURL: https://github.com/argoproj/argocd-example-apps
    targetRevision: HEAD
    path: guestbook

  destination:
    server: https://kubernetes.default.svc
    namespace: default

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```
1. `source`: 가져올 github link이다. repo 정보와 branch 이름, 어느 디렉터리를 쓸 지 선택할 수 있다. 실제 https://github.com/argoproj/argocd-example-apps/tree/master/guestbook 에 방문하면 yaml 파일이 있는 것을 볼 수 있다. kubernetes resource 말고도 helm, kustomize도 가능하다.
2. `destination`: source에 해당하는 project를 어느 cluster에 설치할 지 결정하는 것이다. 위와 같이 적으면 argo가 설치된 local에 설치하겠다는 것이다. 
3. `syncPolicy`: argocd는 source를 직접 쳐다보면서 차분이 있으면 현재 cluster에 반영하는데, 어떤 policy로 할 지 결정하는 부분이다.