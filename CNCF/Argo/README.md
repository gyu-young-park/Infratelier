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

argocd ui에 접근하는 방법은 여러가지가 많은데, 다음을 참고하자. https://argo-cd.readthedocs.io/en/stable/getting_started/

우리의 경우 taefik을 통해 ingress를 열어 접근해보도록 하자. 만약 ingress를 쓸 필요가 없는 상황이면 NodePort나 cloud에서 제공하는 loadbalancer를 사용하면 된다.

- treafik-argo-server-ingress.yaml
```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: strip-argocd-prefix
  namespace: argocd
spec:
  stripPrefix:
    prefixes:
      - /argocd
    forceSlash: false
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-ingress
  namespace: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
    traefik.ingress.kubernetes.io/router.pathmatcher: PathPrefix
spec:
  rules:
  - host: localhost
    http:
      paths:
      - path: /argocd
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
```
위 yaml 파일을 실행시키고 `localhost:8080/argocd` path로 요청을 보내도 argocd ui에 접근이 안될 것이다. 여기에는 두 가지 이유가 있다.

1. argocd UI는 SPA를 사용하므로 path가 `/`로 기본으로 잡혀있다. traefik에서 `/argocd`라는 subpath를 주었지만 argocd UI에서는 `/argocd`라는 path로 static file들을 요청하는 것이 아니라, `/` 기준으로 static file을 얻어오려고 하기 때문에 실패하는 것이다.
2. argocd는 HTTPS가 기본이다. 따라서, HTTP로만 접근하려고 한다면 실패하게 된다. 

두 문제를 해결하기 위해서 `argocd-cmd-params-cm`을 수정하도록 하자. 이 configmap을 통해서 argocd-server deployment에 대해 설정값을 넘겨줄 수 있다.
```sh
data:
  server.insecure: "true"
  server.rootpath: /argocd
```
1. server.insecure: http를 허용하도록 한다.
2. server.rootpath: argocd rootpath를 `/argocd`로 잡도록 하여 static file들을 요청할 때 `/`가 아니라 `/argocd` 기준으로 잡도록 할 수 있다. 우리의 경우 ingress로 argocd-server를 `/argocd`로 열었으니 `/argocd` 경로로 설정해주어야 한다.

이 두 가지가 만족되었다면 접속에 성공할 것이고, 아이디 비밀번호를 입력해야한다.

1. ID: admin
2. PW: `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d && echo`
초기 비밀번호는 secret에 임의로 자동 생성되므로 위의 명령어로 쿼리를 보내도록 해야한다.

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

위 `Application` CRD를 만들었다면, 배포가 시작되고 로컬에 배포된 것을 볼 수 있을 것이다.

```sh
default       guestbook-ui-6cb57c694d-lgwfw                      1/1     Running   0              40s
```

## ArgoCD CLI 연결
https://github.com/argoproj/argo-cd

golang 가장 최신 버전이 설치되어있다면, 위의 github에 가서 직접 cli를 빌드하면 된다.

```sh
make cli-local
```
`./dist` 디렉터리에 cli가 만들어졌을 것이다. 만약 docker로 빌드하고 싶다면 `make cli`를 사용하면 된다.

```bash
./dist/argocd version

argocd: v3.2.0+f4300e1
  BuildDate: 2025-07-16T12:19:47Z
  GitCommit: f4300e1afb1757a6a7f066cea26f8b19a937d937
  GitTreeState: clean
  GoVersion: go1.24.4
  Compiler: gc
  Platform: darwin/arm64
argocd-server: v3.0.6+db93798
  BuildDate: 2025-06-09T21:33:23Z
  GitCommit: db93798d6643a565c056c6fda453e696719dbe12
  GitTreeState: clean
  GoVersion: go1.24.4
  Compiler: gc
  Platform: linux/arm64
  Kustomize Version: v5.6.0 2025-01-14T15:12:17Z
  Helm Version: v3.17.1+g980d8ac
  Kubectl Version: v0.32.2
  Jsonnet Version: v0.20.0
```
다음과 같이 나오면 성공이다.

다음으로 우리의 kubernetes argocd server와 CLI를 연결해주도록 하자. 우리의 argocd server는 taefik에 따라 배포하였는데, 다음과 같다.

1. treafik은 localhost 9090으로 노출되었다.
2. https는 사용하고 있지 않는다.
3. argocd server는 `localhost:9090/argocd` 로 연결되어 있다.

```sh
./argocd login localhost:9090 --plaintext --grpc-web --grpc-web-root-path /argocd
```
하나하나 설명하면 다음과 같다.

1. localhost:9090 서버에 연결을 하겠다.
2. --plaintext: https가 아니라 http로 통신하겠다.
3. --grpc-web: ingress controller 상에서 grpc 통신에 문제가 발생 할 수 있다. 이를 http1.1 방식으로 grpc 요청을 만들어 처리하는 것이다.
4. --grpc-web-root-path: 요청하려는 argocd 서버의 path이다.

이렇게 요청하면 성공하게 된다.

```bash
./argocd login localhost:9090 --plaintext --grpc-web --grpc-web-root-path /argocd
WARNING: server certificate had error: tls: failed to verify certificate: x509: certificate signed by unknown authority. Proceed insecurely (y/n)? y
Username: admin
Password: 
'admin:login' logged in successfully
Context 'localhost:9090/argocd' updated
```

연결에 제대로 성공했는 지 현재 argocd cli의 컨텍스트를 확인하도록 하자.
```bash
 ./argocd context
CURRENT  NAME                   SERVER
*        localhost:9090/argocd  localhost:9090


./argocd app list
NAME              CLUSTER                         NAMESPACE  PROJECT  STATUS  HEALTH   SYNCPOLICY  CONDITIONS  REPO                                             PATH       TARGET
argocd/guestbook  https://kubernetes.default.svc  default    default  Synced  Healthy  Auto-Prune  <none>      https://github.com/argoproj/argocd-example-apps  guestbook  HEAD
```
이전에 배포했던 guestbook이 성공적으로 나오는 것을 확인 할 수 있다.

