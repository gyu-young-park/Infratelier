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

로그인하기 전에 먼저 초기 비밀번호를 확인하도록 하자.
```sh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
`x3kWtcQv7sICMOBx`이렇게 초기 비밀번호가 주어지면 `admin` user로 접근하면 된다.

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

## Argocd project
Argo proejct는 크게 총 4개로 구분 된다.

1. Argocd
2. Argo workflow
3. Argo Event
4. Argo Rollout

Argocd를 먼저 알아 본 다음에 나머지들에 대해서 알아보도록 하자.

ArgoCD는 helm, kustomize, jsonnet 등 선언적 정의 설정 파일을 통해서 배포를 자동화하도록 지원한다. ArgoCD를 구성하는 핵심 요소는 다음과 같다.

![https://argo-cd.readthedocs.io/en/stable/assets/argocd_architecture.png](https://argo-cd.readthedocs.io/en/stable/assets/argocd_architecture.png)

1. API 서버: 웹 UI, CLI, CI/CD 시스템에서 사용하는 API를 제공하는 gRPC/REST 서버이다. Application 상태를 관리하고 동기화, 롤백, 사용자 정의 작업을 호출해준다. 또한, 저장소 및 클러스터 자격 증명을 관리한다. 
2. repo server: Application manifest를 보관하는 git 저장소의 local 캐시를 유지하는 내부 서비스이다. 저장소 URL, revision(commit, tag, branch), application path 등이 주어지면 입력 데이터를 기반으로 Kubernetes manifest를 만들고 반환해준다. Helm, Kustomize, Ksonnet 등 다양한 커스텀 플러그인과 같은 설정 관리 도구를 사용하여 매니페스트를 생성한다. 즉, git repo 복제 및 최신 상태 유지를 도와주고 원하는 설정을 부여하여 manifest를 만드는 것이다.
3. Application controller: 가장 핵심이 되는 로직을 담당하여 실제 실행 중인 application을 지속적으로 모니터링하고 git repository에 지정된 desired state를 현제 클러스터에 반영해준다. 즉, repository 서버를 호출하여 최신 매니페스트를 가져오고 kubernets API 서버를 통해 클러스터 리소스에 변경 사항을 적용한다. 

일련의 흐름은 다음과 같다.

1. Client의 요청이 `argocd-server`에 전달된다. 이 요청은 CLI, UI 등을 통해서 전달되며 argocd에서 관리하는 `Application`을 생성, 수정, 동기화 등을 요청하는 것이다.
2. `argocd-application-controller`는 `argocd-repo-server`를 통해서 등록된 `Application`의 git repository로부터 최신 manifest를 만들어달라고 요청한다. `argocd-repo-server`는 해당 repo를 clone하고 helm, kustomize를 사용하여 kubernetes manifest를 만들어내어 `argocd-application-controller`에게 그 결과를 반환한다.
3. `argocd-application-controller`는 `argocd-server`로부터 받은 `Application` 요청의 상태를 맞추기 위해서 실제 cluster의 현제 상태와 desired state를 비교해 변경 사항을 반영한다. 
4. `argocd-application-controller`가  `Application` 동기화 상태 및 관련 정보를 `argocd-server`에 보고하고, 그 결과가 사용자에게 표시되는 것이다.

ArgoCD는 모든 리소스(Application, Project, Setting 등)을 Kubernetes manifest 형식으로 정의하고 관리한다. 이 manifest들은 일반적으로 ArgoCD가 설치된 동일한 네임스페이스(`argocd`)에 배포되어야 한다. Argocd에서 쓰이는 주요 CRD는 다음과 같다.

1. `Application`: git repository를 통해서 cluster에 배포할 application의 설정을 담은 CRD이다. `source`를 통해 git의 어떤 repo를 사용할 지, `destination`을 통해서 어디 k8s cluster에 배포할 지 설정할 수 있다. 
2. `AppProject`: `Application` CRD 여러 개를 묶어 하나의 논리적 그룹을 만들도록 한다. 이 그룹 안에서 `Application`은 설정의 지배를 받게 되는데, 가령 특정 git repo가 허락되지 않거나, 배포될 수 있는 k8s cluster 목록이 따로 주어질 수도 있다. 또한, cluster 내에서도 네임스페이스 범위나 허용/거부 목록을 지정하여 project 배포 권한을 세말히게 제어할 수 있다. 이는 각 팀이나 사용자 그룹에 고유한 `AppProject`를 할당하여 각자의 배포 환경과 정책을 격리하고 독립적으로 관리할 수 있도록 한다.

git repository 세부 정보는 `Secrets`에 저장된다. 각 repository Secret은 `argocd.argoproj.io/secret-type: repository` label을 가져야 한다. 이 secret이 설정되었다면 원하는 repo의 인증 권한, ssh 설정, proxy, TLS 등이 가능하다. 

kubernetes cluster의 자격 증명도 `Secret`에 저장되며 `argocd.argoproj.io/secret-type: cluster` label을 가져야 한다. 서버의 이름, api-server URL, namespace등을 설정할 수 있으며 `username`, `password` 등의 인증 정보도 설정할 수 있다.

이렇게 ArgoCD는 모든 설정이 kubernetes manifest로 표현되기 때문에 ArgoCD 자신이 자신을 관리할 수도 있다. 이를 `app of apps` 패턴으로 하나의 ArgoCD(`Application`)이 다른 여러 ArgoCD(`Application`) 리소스를 관리하는 방식을 의미한다. 즉, 최상위 application이 하위 application을 배포하고 관리하는 계층 구조를 만드는 것이다.

이 패턴은 ArgoCD가 kubernetes manifest를 git에서 읽어와 cluster에 배포하는 기본적인 작동 방식을 활용한다. `Application` 리소스 자체가 Kubernetes manifest이기 때문에 다른 `Application` 리소스를 배포하는 `Application`을 만드는 것이 가능해진다. 이렇게 `app of apps`을 사용하여 각 환경에 맞는 별도의 `Application` 정의를 git에 저장하고 각 환경별 App of Apps가 해당 환경에 맞는 하위 Application들을 배포하도록 할 수 있다. 가령 `prod-application`라는 App of Apps가 `prod-web-app`, `prod-api-server`, `prod-database` 등의 application을 관리하는 식이다.


