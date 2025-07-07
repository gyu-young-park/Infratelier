# K3
테스트를 위해 Kubernetes를 간편하게 배포하고 싶을 때가 있다. EKS를 올리자니 비용과 프로비저닝 시간이 아쉽고, 로컬 서버로 kubernetes를 만들자니 머신 비용이랑 전기세가 아쉽다.

그래서 맥북으로 간단히 kubernetes cluster를 프로비저닝 시킬 수 있는 방법들을 알아보았다. 방법을 조사하니 총 3가지 정도가 있었다.

1. K3
2. Kind
3. Minikube

개인적으로 이 3가지를 모두 써보면서 K3가 가장 쉽고, 설정을 지우기 편했다.

# k3d 사용법
macbook에서는 k3 자체는 사용할 수 없고, k3d를 사용해야한다. `k3d`는 Docker 기반 K3s 클러스터를 빠르게 생성할 수 있는 도구인 것이다.

```bash
brew install k3d
brew install kubectl
```

설치가 잘 되었는 지 확인해보자.
```sh
k3d version

k3d version v5.8.3
k3s version v1.31.5-k3s1 (default)
```

version 정보가 잘 나왔다면 성공한 것이다. 

## k3d cluster
다음으로 k3d를 사용해서 kubernetes cluster를 생성해보도록 하자.

1. cluster 생성
```sh
k3d cluster create {cluster_name}
```

2. cluster 삭제
```sh
k3d cluster delete {cluster_name}
```

3. cluster 목록
```sh
k3d cluster list
```

4. cluster 중지
```sh
k3d cluster stop {cluster_name}
```

5. cluster 시작
```sh
k3d cluster start {cluster_name}
```

6. cluster 설정 변경
```sh
k3d cluster edit {cluster_name}
```

7. cluster 정보 출력
```sh
k3d cluster get {cluster_name}
```

가장 중요한 명령어는 cluster를 생성하는 `cluster create`이다. 옵션을 알아보면 다음과 같다.
1. `--servers`: 마스터 서버 노드 수
2. `--agents`: worker node 수
3. `-p`: 포트 포워딩
4. `--registry-use`: registry 연결
5. `--volume`: host 볼륨 마운트

```sh
k3d cluster create mycluster \
  --servers 1 --agents 2 \
  -p "8080:80@loadbalancer" \
  --registry-use k3d-myregistry.localhost:5000
```
`mycluster`를 만드는데 마스터 노드는 1개이고 워커 노드는 2개라는 것이다. 또한, 클러스터의 80 포트를 host 포트 8080에 포트포워딩하겠다는 것이다. 마지막으로 `registry-use`로 local registry를 등록하는 것이다.

포트포워딩으로 `loadbalancer`을 넣어주어야 host port와 우리가 만든 kubernetes cluster와 포트포워딩 로드밸런싱이 된다.

## k3d node
node 단위로의 제어도 가능하다.

1. 개별 노드 생성
```sh
k3d node create {node_name}
``` 

2. 개별 node 삭제
```sh
k3d node delete {node_name}
```

3. node list
```sh
k3d node list
```

4. node 중지
```sh
k3d node stop
```

5. node 시작
```sh
k3d node start
```

## k3d registry
1. local docker registry 생성
```sh
k3d registry create {registry_name}
```
`--port`로 host port도 지정이 가능하다.

2. registry 목록
```sh
k3d registry delete {registry_name}
```

3. registry 삭제
```sh
k3d registry delete {registry_name}
```

다음과 같이 local registry를 생성한 다음에 docker image를 관리할 수 있다.
```sh
k3d registry create myregistry.localhost --port 5000
docker tag myapp:latest k3d-myregistry.localhost:5000/myapp
docker push k3d-myregistry.localhost:5000/myapp
```

## k3d kubeconfig 명령어
cluster를 간편하게 여러 개 만들 수 있는 만큼, `kubectl`의 kubeconfig를 설정해주어 cluster 제어 타겟을 변경할 수 있다.

1. cluster kubeconfig 가져오기
```sh
k3d kubeconfig get {cluster_name}
```

2. kubeconfig 파일을 별도 파일로 저장
```sh
k3d kubeconfig write {cluster_name}
```

3. cluster의 kubeconfig을 현재 `~/.kube/config` 파일에 추가한다.
```sh
k3d kubeconfig merge {cluster_name}
``` 
`--switch`을 사용하면 바로 해당 cluster로 바뀐다. 만약 `--switch`을 안쓰고 kubectl의 현재 cluster를 바꾸고 싶다면 `kubectl config use-context`를 사용하면 된다.https://www.naver.com/#

## test
이제 제대로 동작하는 지 확인해보도록 하자.

먼저 클러스터를 하나 만들어주자
```sh
k3d cluster create main-cluster \
-p "9090:80@loadbalancer"
```

클러스터가 잘 동작하는 지 확인해보자
```sh
kubectl get po -A
NAMESPACE     NAME                                      READY   STATUS      RESTARTS   AGE
kube-system   coredns-ccb96694c-ctbbf                   1/1     Running     0          62m
kube-system   helm-install-traefik-crd-925rh            0/1     Completed   0          62m
kube-system   helm-install-traefik-fx9xg                0/1     Completed   1          62m
kube-system   local-path-provisioner-5cf85fd84d-r4rt5   1/1     Running     0          62m
kube-system   metrics-server-5985cbc9d7-c2zf2           1/1     Running     0          62m
kube-system   svclb-traefik-4691725b-l875c              2/2     Running     0          62m
kube-system   traefik-5d45fc8cc9-tprts                  1/1     Running     0          62m
```

다음으로 테스트 앱인 nginx pod를 올려보도록 하자.
- nginx-deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
```
`kubectl apply -f nginx-deployment.yaml`을 실행한 다음에 배포가 되었는 지 확인해보도록 하자.

```sh
kubectl get po
NAME                     READY   STATUS    RESTARTS   AGE
nginx-7769f8f85b-8jhhb   1/1     Running   0          9s
```
잘 배포된 것을 볼 수 있다.

다음으로 traefik에서 사용할 ingress를 하나 만들어주자, nginx pod는 `/` path에서 동작하도록 설정하자.

- ingress.yaml
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
    - host: localhost
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx
                port:
                  number: 80
```
배포를 완료했다면 `http://localhost:9090/`에 접속해보도록 하자. 다음의 페이지가 나오면 성공이다.

```sh
Welcome to nginx!
If you see this page, the nginx web server is successfully installed and working. Further configuration is required.

For online documentation and support please refer to nginx.org.
Commercial support is available at nginx.com.

Thank you for using nginx.
```