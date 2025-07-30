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