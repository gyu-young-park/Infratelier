# ubuntu-server 설치

## docker 설치
먼저 gpg키 관련 도구와 인증서 관련 패키지를 설치하도록 하자.
```sh
sudo apt update
sudo apt install -y ca-certificates curl gnupg
```

다음으로 docker repo에 대한 gpg 키를 준비하도록 하자.
```sh
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

docker source 리스트를 추가하고 gpg키를 사용하여 검증하도록 하자.
```sh
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

이제 완료되었다면 설치하도록 하자.
```sh
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

설치가 잘 완료되었다면 서버 부팅 시에도 docker가 자동 실행되도록 systemd를 활용하도록 하자.
```sh
sudo systemctl enable docker
sudo systemctl start docker
```

아래와 같이 systemd의 결과가 잘 나오면 성공이다.
```sh
sudo systemctl status docker
● docker.service - Docker Application Container Engine
     Loaded: loaded (/lib/systemd/system/docker.service; enabled; vendor preset: enabled)
     Active: active (running) since Wed 2025-07-30 15:29:53 UTC; 1min 7s ago
TriggeredBy: ● docker.socket
       Docs: https://docs.docker.com
   Main PID: 3937 (dockerd)
      Tasks: 11
     Memory: 22.5M
        CPU: 512ms
     CGroup: /system.slice/docker.service
             └─3937 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock

Jul 30 15:29:52 host01 dockerd[3937]: time="2025-07-30T15:29:52.303385093Z" level=info msg="detected 127.>
Jul 30 15:29:52 host01 dockerd[3937]: time="2025-07-30T15:29:52.345199561Z" level=info msg="Creating a co>
Jul 30 15:29:52 host01 dockerd[3937]: time="2025-07-30T15:29:52.464229573Z" level=info msg="Loading conta>
Jul 30 15:29:53 host01 dockerd[3937]: time="2025-07-30T15:29:53.009705593Z" level=info msg="Loading conta>
Jul 30 15:29:53 host01 dockerd[3937]: time="2025-07-30T15:29:53.032230060Z" level=info msg="Docker daemon>
Jul 30 15:29:53 host01 dockerd[3937]: time="2025-07-30T15:29:53.032564970Z" level=info msg="Initializing >
Jul 30 15:29:53 host01 dockerd[3937]: time="2025-07-30T15:29:53.088774214Z" level=info msg="Completed bui>
Jul 30 15:29:53 host01 dockerd[3937]: time="2025-07-30T15:29:53.106041188Z" level=info msg="Daemon has co>
Jul 30 15:29:53 host01 dockerd[3937]: time="2025-07-30T15:29:53.106138661Z" level=info msg="API listen on>
Jul 30 15:29:53 host01 systemd[1]: Started Docker Application Container Engine.
```

docker container를 띄워보고 잘 동작하는 지 확인해보도록 하자.
```sh
sudo docker run --name my-nginx -d -p 8080:80 nginx

url localhost:8080
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
```
성공적으로 동작하고 있는 것을 확인하였다.

`sudo` 유저가 아니라 현재 유저로도 docker 명령어를 사용하고 싶다면 user를 추가해야한다.
```sh
sudo usermod -aG docker $USER
```
현재 user를 `docker` group에 추가하는 것이다. 이렇게 설정하면 슈퍼 유저가 아니라도 docker관련 명령어에 접근할 수 있다.

이 다음에는 재시작을 해주어야 한다. `sudo reboot -nf`을 입력하도록 하자.

## IP 고정 시키기
ubuntu-server로 구동시키면 초기 설정 값이 박힌, cloud-init netplan이 재시작 시에 적용된다. 그렇기 때문에 netplan 설정 관련해서 cloud-init이 초기화를 하지 못하도록 disabled 시켜야한다.

```sh
sudo mkdir -p /etc/cloud/cloud.cfg.d
echo "network: {config: disabled}" | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
```
위의 명령어처럼 `/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg` 경로에 `network: {config: disabled}`을 넣어주면 된다.

이제 다음으로 고정하고 싶은 IP를 netplan에 넣어주도록 하자. 만약 내가 고정시키고 싶은 IP가 `192.168.111.20`라면 다음과 같이 설정할 수 있다.

- /etc/netplan/01-static.yaml
```yaml
network:
  version: 2
  ethernets:
    enp3s0:
      dhcp4: false
      dhcp6: false
      addresses:
        - 192.168.111.20/24
      gateway4: 192.168.111.1
      nameservers:
        addresses:
          - 1.1.1.1
          - 8.8.8.8
```
1. gateway4의 경우는 `ip route | grep default`로 나오는 결과를 입력해주도록 하자.
2. nameservers는 cloudflare의 `1.1.1.1`과 google의 `8.8.8.8`로 설정했는데, 이는 기존의 nameserver IP를 DHCP로 받았는데 이제는 DHCP를 disable시킬 것이기 때문에 고정된 DNS IP를 준 것이다.

마지막으로 netplan을 적용시키도록 하자.
```sh
sudo netplan apply
```

성공하였다면 IP가 고정된 것을 볼 수 있을 것이다.
```sh
ip -br addr
```

## Kubernetes 설치
설치 전에 swap을 off시키도록 하자.
```sh
# 즉시 swap 비활성화
sudo swapoff -a

# 부팅 시에도 비활성화되도록 fstab 수정
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

다음으로 필요한 커널 모듈을 활성화하도록 하자.
```sh
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# 커널 모듈 적용
sudo modprobe overlay
sudo modprobe br_netfilter
```
`overlay`와 `br_netfilter` 커널 모듈을 로딩하는 것이다. kubernetes CNI가 overlay network를 구성하고 netfilter를 사용하여 service 통신을 하기 위해서 해당 커널 모듈이 node에 반드시 동작해야한다.

네트워크 관련 커널 파라미터도 설정하도록 하자.
```sh
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# 적용
sudo sysctl --system
```
기본적으로 linux는 bridge network의 packet에 대해서 iptable rule을 따르지 않는다. 따라서, iptables rule을 bridge network에서도 따르도록 설정하여 Kubernetes의 service, CNI network policy 설정이 적용되도록 하는 것이다.

또한, `net.ipv4.ip_forward`도 활성화해주어야 하는데, 기본적으로 linux에서는 자신의 IP가 source IP인 packet에 대해서만 처리하고 그렇지 않으면 버린다. 문제는 kubernetes pod 간의 통신에 있어서 다른 node로부터 온 packet을 포워딩(라우터 처럼)해야할 때가 있다. 가령 `10.0.0.1`이 `10.0.1.1`에 온 packet에 대해서 `eth0`으로 전달해야할 때가 있는 것이다. (eth0가 유일하게 활성화된 인터넷 네트워크이거나, 다른 노드와 연결된 지점일 수 있다.) 이 경우에 source IP가 `10.0.1.1`로 적힌 packet을 `10.0.0.1`이 처리해야하는데 `net.ipv4.ip_forward`가 비활성화되어 있으면 포워딩을 하지 않고 버리게 된다. 그래서 활성화 시켜주는 것이다.

이제 containerd를 설치하도록 하자.
```sh
sudo apt-get update
sudo apt install -y containerd
containerd config default | sudo tee /etc/containerd/config.toml
```

설정의 일부 구간을 수정하도록 하자.
```sh
# Systemd cgroup 드라이버 사용 설정 (중요)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
```

설정을 수정했다면 systemd로 재시작해주도록 하자.
```sh
sudo systemctl restart containerd
sudo systemctl enable containerd
```

필요한 package들과 keyring을 설치하도록 하자.
```sh
sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

다음으로 kubernetes 설치에 필요한 package들을 설치하도록 하자.
```sh
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

이제 `kubeadm`을 통해서 kubernetes를 설치해보도록 하자.
```sh
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

설치가 완료된 후에는 cluster config를 node에 등록하도록 하자.
```sh
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

`kubectl`로 확인해보도록 하자.
```sh
kubectl get po -A
NAMESPACE     NAME                             READY   STATUS    RESTARTS   AGE
kube-system   coredns-674b8bbfcf-6mktb         0/1     Pending   0          33s
kube-system   coredns-674b8bbfcf-g2qml         0/1     Pending   0          33s
kube-system   etcd-host01                      1/1     Running   0          39s
kube-system   kube-apiserver-host01            1/1     Running   0          39s
kube-system   kube-controller-manager-host01   1/1     Running   0          40s
kube-system   kube-proxy-gs2bz                 1/1     Running   0          33s
kube-system   kube-scheduler-host01            1/1     Running   0          39s
```

잘 설정된 것을 볼 수 있다. `coredns`의 경우는 CNI가 설치되어야 시작한다.

`kubectl` 명령어 자동 완성 스크립트를 활성화하도록 하자.
```sh
echo 'source <(kubectl completion bash)' >> ~/.bashrc
source ~/.bashrc
```

현재는 싱글 노드이므로 master node에 있는 taint를 없애주도록 하자. 없애주면 해당 master node도 worker node처럼 pod를 배포할 수 있다.
```sh
kubectl taint nodes <노드이름> node-role.kubernetes.io/control-plane:NoSchedule-
```

다음으로 CNI를 설치하도록 하자.

## Cilium CNI 설치
https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/

`cilium` CLI를 설치하도록 하자.
```sh
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64

if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
```

설치 완료 후에는 CLI의 version을 확인하도록 하자.
```sh
cilium version
cilium-cli: v0.18.5 compiled with go1.24.4 on linux/amd64
cilium image (default): v1.17.5
cilium image (stable): v1.18.0
cilium image (running): unknown. Unable to obtain cilium version. Reason: release: not found
```
cilium 버전이 stable로 `v1.18.0`이라고 하였으니 명시적으로 해당 버전으로 설치하도록 명령어를 주자

```sh
cilium install --version 1.18.0

ℹ️  Using Cilium version 1.18.0
🔮 Auto-detected cluster name: kubernetes
🔮 Auto-detected kube-proxy has been installed
```

설치가 완료되었다면 정상적으로 동작하고 있는 지 확인해보도록 하자.
```sh
cilium status --wait
```

추가적으로 `cilium`의 연결성 테스트도 가능하다.
```sh
cilium connectivity test
...
✅ [cilium-test-1] All 74 tests (293 actions) successful, 49 tests skipped, 1 scenarios skipped.
```
이렇게 나오면 성공이다.

node의 상태를 확인해보자
```sh
ubectl get nodes -A
NAME     STATUS   ROLES           AGE   VERSION
host01   Ready    control-plane   26m   v1.33.3
```
정상적으로 동작하는 것을 볼 수 있다.

## nerdctl 설치
containerd의 명령어를 사용하는 것보다 docker 명령어 사용방법을 containerd에 적용할 수 있는 `nerdctl`을 사용하는 것이 더 좋다.

먼저 `containerd`가 설치되어있는 지 확인하도록 하자.
```sh
containerd --version

containerd github.com/containerd/containerd 1.7.27 
```

nerdctl 최신 버전은 해당 링크에서 볼 수 있다. 현재는 최신 버전이 `2.1.3`이다. https://github.com/containerd/nerdctl/releases
```sh
# 1. 최신 nerdctl 릴리즈 다운로드
VERSION="2.1.3"
wget https://github.com/containerd/nerdctl/releases/download/v${VERSION}/nerdctl-${VERSION}-linux-amd64.tar.gz

# 2. 압축 해제 및 이동
tar -zxvf nerdctl-${VERSION}-linux-amd64.tar.gz
sudo mv nerdctl /usr/local/bin/

# 3. 설치 확인
nerdctl --version
```

잘 설치되었다면 `k8s.io` namespace로 kubernetes 관련 pod의 container들을 보도록 하자.
```sh
nerdctl ps --namespace k8s.io
```'

## Golang 설치
https://go.dev/doc/install

```sh
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.24.5.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
go version
```