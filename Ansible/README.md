# Ansible
ansible의 특징을 정리하면 다음과 같다.

1. Agent가 없다: puppet이나 chef의 경우 자동화 관리 대상 서버에 별도의 에이전트를 설치하고 이를 통해 자동화 업무를 수행한다. 그러나 ansible은 별도의 agent없이 ssh로 접속해서 쉽게 대상 서버들을 관리할 수 있다.
2. 멱등성: ansible은 멱등성을 제공하여 시스템을 원하는 상태로 표현해 유지하도록 설계되어 있다. 동일한 작업을 여러 번 실행해도 같은 결과를 내도록 한다는 것이다.
3. 쉬운 사용법과 다양한 모듈: ansible은 다른 자동화 도구에 비해 복잡하지 않다. yaml 설정만으로 쉽게 사용이 가능하고 다양한 모듈이 있어서 쉽게 자동화가 가능하다.

ansible은 파이썬 앤서블 코어만 설치하면 어디에서나 플레이북(yaml 형식의 작업들을 순서대로 작성해 놓은 파일)을 작성하고 이를 실행시킬 수 있다. 앤서블은 이렇게 앤서블 코어가 설치되고 플레이북을 작성하여 실행할 수 있는 control node(제어 노드)와 플레이 북이 실행되어 application 설치나 클라우드 시스템의 가상 서버 생성과 같은 작업이 수행되는 managed node(관리 노드)로 구성된다. 앤서블은 관리 노드에는 설치되지 않고 제어 노드에만 설치가되는데, 제어 노드에 앤서블 코어가 설치되며 사용자에 의해 정의된 플레이북과 관리 노드를 정의해놓은 인벤토리 파일에 의해 `SSH` protocol을 기반으로 다양한 환경의 관리 노드 업무 자동화를 수행할 수 있다.

```                                                       
                                               +------------------------------+
                                               |                              |
                                               |      Managed Node1           |
+------------------------------+               |                              |
|                              |-------------- +------------------------------+
|     Control Node             |               +------------------------------+
|                              |               |                              |
|+-----------------+           |---------------|      Managed Node2           |
|| Ansible Core    | Inventory |               |                              |
||                 | Playbook  |               +------------------------------+
|+-----------------+           |               +------------------------------+
|                              |----------------                              |
+------------------------------+               |      Managed Node3           |
                                               |                              |
                                               +------------------------------+                       
```

## Ansible architecture
ansible 커뮤니티는 크게 두개로 나누어 설명할 수 있다.

1. 커뮤니티 앤서블: 오픈소스 형태로 운영체제가 리눅스라면 어디에서나 설치 가능
2. 레드햇 앤서블 오토메이션 플랫폼: 레드햇 구독을 통해 사용 가능

우리는 돈이 없으니 커뮤니티 앤서블의 아키텍처만 보도록 하자.

### 커뮤니티 앤서블
앤서블 아키텍처는 제어노드와 관리노드라는 두 가지 유형의 시스템으로 구성된다. 제어노드에서 앤서블이 실행되며 앤서블이 실행되기 위해서는 python이 기본적으로 설치되어 있어야 한다. 또한, 앤서블 안에는 다양한 모듈과 플러그인이 함께 설치되어 있으며, 앤서블이 관리하는 노드 정보를 저장하고 있는 인벤토리와 관리 노드에서 수행될 작업 절차가 작성되어 있는 플레이북이 존재한다.

1. 제어 노드: 앤서블이 설치되는 노드로 파이썬이 설치되어 있어야 한다.
2. 관리 노드: 앤서블이 원격 제어하는 원격 시스템 또는 호스트를 의미한다. 리눅스가 설치된 노드일 수도 윈도우나 클라우드, 가상 서버도 가능하다. 단 SSH 통신이 가능해야하며 파이썬이 설치되어 있어야 한다.
3. 인벤토리: 제어 노드가 관리하는 관리 노드의 목록을 나열해놓은 파일이다. 앤서블은 인벤토리에 사전에 정의도어 있는 관리 노드에만 접근이 가능하다.

```sh
$ vi inventory
192.168.10.101

[WebServer]
web1.example.com
web2.example.com

[DBServer]
db1.example.com
db2.example.com
```
다음과 같이 노드의 성격 별로 그룹핑할 수도 있다.

4. 모듈: 앤서블은 관리 노드의 작업을 수행할 때 SSH 통해 연결한 후 앤서블 모듈이라는 스크립트를 푸시하여 작동한다. 대부분의 모듈은 원하는 시스템 상태를 설명하는 매개 변수를 허용하며, 모듈 실행이 완료되면 제거한다.
5. 플러그인: 플러그인은 앤서블의 핵심 기능을 강화한다. 모듈이 대상 시스템에서 별도의 프로세스로 실행되는 동안 플러그인이 제어 노드에서 실행된다. 플러그인은 앤서블의 핵심 기능인 데이터 변환, 로그 출력, 인벤토리 연결 등에 대한 옵션 및 확장 기능을 제공한다.
6. 플레이북: 플레이북은 관리 노드에서 수행할 작업들을 YAML 문법을 이용해 순서대로 작성해놓은 파일이다. 앤서블은 이렇게 작성된 플레이북을 활용하여 관리 노드에 SSH로 접근하여 작업을 수행한다. 

```yaml
---
- hosts: webservers
  serial: 5 # 한 번에 5대의 머신을 업데이트하라
  roles:
  - common
  - webapp
- hosts: content_servers
  roles:
  - common
  - content
```

## Ansible 실습 환경
VM을 만들어 ansible 실습 환경을 구축해보도록 하자.

| Node Name | OS | CPU | Memory | Disk | NIC |
|-----------|------|--------|------------|-----------|------------|
| ansible-server | CentOS stream 8 | 2 | 4GB | 50GB | 192.168.100.4 |
| tnode1-centos8 | CentOS stream 8 | 2 | 2GB | 30GB | 192.168.100.6 |
| tnode2-rhel | RHEL 8.8 | 2 | 2GB | 30GB | 192.168.100.7 |

`ansible-server`는 ansible을 설치되고 inventory와 playbook이 위치할 제어 노드로 `CentOS Stream8`로 구성한다. 

```sh
                                               +------------------------------+                                                              
+------------------------------+               |         tnode1-centos8       |                                                              
|                              |               |         Managed Node1        |                                                              
| Control Node(ansible server) |               |        (192.168.100.6)       |                                                              
|        (192.168.100.4)       |-------------- +------------------------------+                                                              
|+-----------------+           |                                                                                                             
|| Ansible Core    | Inventory |               +------------------------------+                                                              
||                 | Playbook  |---------------|         tnode2-rhel          |                                                              
|+-----------------+           |               |         Managed Node2        |                                                              
|                              |               |        (192.168.100.7)       |                                                              
+------------------------------+               +------------------------------+ 
```

KVM 및 virt-manager를 설치하도록 하자.

먼저 가상화를 지원하는 CPU인지 확인하도록 하자. intel이면 `vmx`이고 AMD이면 `svm`으로 나온다.
```bash
cat /proc/cpuinfo | egrep "vmx|svm"
```

다음으로 시스템 업데이트 후에 kvm과 virt-manager 패키지들을 설치하도록 하자.
```sh
sudo apt update
sudo apt install qemu-kvm libvirt-daemon-system virt-manager bridge-utils libvirt-clients
```
1. `qemu-kvm`: QEMU와 KVM을 통합한 패키지이다. KVM은 kernel-based virtual machine으로 linux 커널에 내장된 가상화 기술이다. CPU의 가상화 확장 기능인 (Intel VT-x, AMD-V)을 직접 확용하여 매우 빠른 성능을 제공한다. 단, KVM은 하드웨어 가속기 역할만 하고, 실제 VM을 구동하는 하드웨어 에뮬레이터가 필요하다. 그 애뮬레이터가 바로 QEMU이다. QEMU는 다양한 하드웨어 아키텍처를 에뮬레이션하는 프로그램으로 KVM과 함께 사용될 때, QEMU 가상 머신의 디바이스(네트워크 카드, 디스크, 그래픽 카드 등)을 애뮬레이션하는 역할을 맡는다. `qemu-kvm` 패키지는 이 두 기술을 결합하여 가상 머신을 만들고 실행하는 핵심적인 기능을 담당한다.  
2. `libvirt-daemon-system`: `libvirt`라는 가상화 관리 라이브러리의 시스템 데몬이다. `libvirt`는 KVM, QEMU, Xen, LXC 등 다양한 가상화 기술을 관리하기 위한 추상화 계층으로 가상 머신을 보다 쉽게 관리할 수 있도록 해준다. 즉, 가상 머신의 시작, 삭제, 중지, 모니터링 등 복잡한 관리 작업을 처리한다.
3. `virt-manager`: `libvirt`를 기반으로 한 가상 머신 관리 도구로 GUI를 제공하여 사용자가 그래픽으로 쉽게 가상 머신을 만들고 설정을 변경하고 상태를 확인할 수 있도록 해준다. `libvirt-daemon-system`가 백엔드이고 `virt-manager`가 프론트가 되는 것이다.
4. `bridge-utils`: 가상 네트워크 브릿지를 설정하는 데 필요한 도구들을 모아놓은 패키지이다. 가상 머신이 외부 네트워크에 직접 접근하거나 호스트 컴퓨터와 통신하기 위해서는 네트워크 브릿지가 필요하다.
5. `libvirt-clients`: `libvirt` 데몬을 제어하는 클라이언트 도구 모음으로 `virsh`이 가장 대표적이다. `virsh`은 CLI를 통해 `libvirt`를 제어할 수 있도록 해준다.

이제 VM 생성에 필요한 이미지들을 설치해보도록 하자.
```sh
mkdir ./os_image && cd ./os_image
wget https://dl.rockylinux.org/vault/centos/8-stream/isos/x86_64/CentOS-Stream-8-20240603.0-x86_64-dvd1.iso
wget https://archive.org/download/rhel-8.8-x86_64-dvd/rhel-8.8-x86_64-dvd.iso
```

```sh
sudo virt-install \
    --name ansible-server \
    --os-variant centos-stream8 \
    --ram 4096 \
    --vcpus 2 \
    --disk path=/var/lib/libvirt/images/ansible-server.qcow2,size=50 \
    --network network=default,model=virtio \
    --location /var/lib/libvirt/images/CentOS-Stream-8-20240603.0-x86_64-dvd1.iso \
    --extra-args 'console=ttyS0,115200n8 serial' \
    --noautoconsole
```
위 명령어를 실행하면 아래와 같은 로그가 나온다.

```sh
Starting install...
Retrieving 'vmlinuz'                                                                                                                                      |    0 B  00:00:00 ... 
Retrieving 'initrd.img'                                                                                                                                   |    0 B  00:00:00 ... 
Allocating 'ansible-server.qcow2'                                                                                                                         |    0 B  00:00:00 ... 
Creating domain...                                                                                                                                        |    0 B  00:00:00     

Domain is still running. Installation may be in progress.
You can reconnect to the console to complete the installation process.
```
더 설정해주어 설치를 마무리 해주라는 것이다. console에 들어가서 설치 설정을 해주도록 하자.

```sh
sudo virsh console ansible-server
```

1. disk 설정
2. root password 설정
3. host 설정

완료한 뒤에는 `b` 버튼을 누르면 설치를 시작한다. 설치가 완료된 후에는 라이센스에 동의까지 해주어야 한다.

완료된 후에 접속해보도록 하자.
```sh
sudo virsh start ansible-server
```
설정했던 host와 password를 입력하면 vm shell에 접속이 가능하다.
```sh
virsh console ansible-server
```

설치가 완료된 후에는 네트워크 설정을 해주도록 하자. `centos`는 `nmcli`를 사용하면 된다. 참고로 vm을 provisioning하고 있는 host에서의 vm bridge가 `virbr0           UP             192.168.122.1/24 `이기 때문에 `192.168.122.1/24` IP 대역을 vm이 외부와 트래픽을 통신하는 IP로 두도록 하였다.
```sh
su -
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
nmcli con modify enp1s0 ipv4.method manual ipv4.addresses 192.168.122.4/24 ipv4.gateway 192.168.122.1 ipv4.dns 192.168.122.1
nmcli con modify enp1s0 +ipv4.addresses 192.168.100.4/24
nmcli con up enp1s0
```
1. 192.168.122.1/24: vm <-tab-> virtual bridge <-> host <-> internet 연결 IP
2. 192.168.100.1/24: vm 끼리의 통신 IP

확인해보면 다음과 같다.
```sh
ip -br addr
lo               UNKNOWN        127.0.0.1/8 ::1/128 
enp1s0           UP             192.168.122.4/24 192.168.100.4/24 fe80::5054:ff:feef:463f/64 
virbr0           DOWN           192.168.122.1/24
```
잘 설정된 것을 볼 수 있다. vm에서 빠져나오려면 `ctrl + ]`을 눌러야 한다.

다음으로 `tnode1-centos8` VM을 프로비저닝해보도록 하자. 사실 ubuntu vm을 올리는 것이 실습에는 더 좋은데, ubuntu의 경우 console로만 설치할 시에 `--location`이 아니라 `--cdrom`을 사용하여 console 제어를 할 수가 없다. 따라서, 필자는 그냥 centos8로 대체하겠다. 정리하자면 이렇다.

1. `--location`: 설치에 필요한 커널(`vmlinuz`)과 초기 램디스크(`initrd.img`) 파일을 직접 찾아서 호스트 시스템의 메모리에 로디한 후 VM을 부팅한다. VM은 부팅 후 지정된 위치에서 나머지 설치 파일을 가져온다.
2. `--cdrom`: ISO 파일을 VM의 가상 CD-ROM 드라이브에 연결한다. VM은 이 가상 CD-ROM 드라이브를 통해 부팅하고 설치 프로그램이 시작된다. 

보통 ubuntu는 `cdrom` 계열로 가상 CD-ROM으로 마운트하는 것이 가장 안정적이고 RHEL, CentOS, Rocky 같은 경우는 `--location`을 사용하여 ISO 이미지에서 직접 커널을 로드하는 방식이 더 일반적이다. 

```sh
sudo virt-install \
    --name tnode1-centos8 \
    --os-variant centos-stream8 \
    --ram 2048 \
    --vcpus 2 \
    --disk path=/var/lib/libvirt/images/tnode1-centos8.qcow2,size=30 \
    --network network=default,model=virtio \
    --location /var/lib/libvirt/images/CentOS-Stream-8-20240603.0-x86_64-dvd1.iso \
    --extra-args 'console=ttyS0,115200n8 serial' \
    --noautoconsole
```
`virsh console tnode1-centos8`로 접속하여 위에 설정했던 방법 그대로 해주면 된다.

설치할 때는 `Installation Destination`를 먼저 설정하도록 한다. 그러면 대부분의 default 설정으로 다른 설정들도 같이 설정될 것이다.

설치가 완료된 다음에는 접속 테스트 후에 network 설정을 해주도록 하자.
```sh
virsh start tnode1-centos8
virsh console tnode1-centos8

su -
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
nmcli con modify enp1s0 ipv4.method manual ipv4.addresses 192.168.122.6/24 ipv4.gateway 192.168.122.1 ipv4.dns 192.168.122.1
nmcli con modify enp1s0 +ipv4.addresses 192.168.100.6/24
nmcli con up enp1s0
```

```sh
sudo virt-install \
    --name tnode2-rhel \
    --os-variant rhel8.8 \
    --ram 2048 \
    --vcpus 2 \
    --disk path=/var/lib/libvirt/images/tnode2-rhel.qcow2,size=30 \
    --network network=default,model=virtio \
    --location /var/lib/libvirt/images/rhel-8.8-x86_64-dvd.iso \
    --extra-args 'console=ttyS0,115200n8 serial' \
    --noautoconsole
```

설치가 완료된 다음에는 접속 테스트 후에 network 설정을 해주도록 하자.
```sh
virsh start tnode2-rhel 
virsh console tnode2-rhel

su -
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
nmcli con modify enp1s0 ipv4.method manual ipv4.addresses 192.168.122.7/24 ipv4.gateway 192.168.122.1 ipv4.dns 192.168.122.1
nmcli con modify enp1s0 +ipv4.addresses 192.168.100.7/24
nmcli con up enp1s0
```

제대로 설정되었는 지 확인해보도록 하자.
```sh
ip -br addr
lo               UNKNOWN        127.0.0.1/8 ::1/128 
enp1s0           UP             192.168.122.7/24 192.168.100.7/24 fe80::5054:ff:fe81:e778/64 
virbr0           DOWN           192.168.122.1/24 
```
잘 설정된 것을 볼 수 있다.

나중에 vm을 제거할 때는 다음의 명령어를 사용하면 된다. 
```sh
sudo virsh destroy ansible-server
sudo virsh undefine ansible-server
sudo rm /var/lib/libvirt/images/ansible-server.qcow2

sudo virsh destroy tnode1-centos8
sudo virsh undefine tnode1-centos8
sudo rm /var/lib/libvirt/images/tnode1-centos8.qcow2

sudo virsh destroy tnode2-rhel # vm 종료
sudo virsh undefine tnode2-rhel # vm 정의 삭제
sudo rm /var/lib/libvirt/images/tnode2-rhel.qcow2 # vm 디스크 삭제
```

설치가 완료된 후에는 다음과 같이 나오면 정상이다.
```sh
virsh list --all
 Id   Name             State
--------------------------------
 5    ansible-server   running
 15   tnode2-rhel      running
 18   tnode1-centos8   running
```

이제 ansible을 설치하도록 하자. centos 환경으로 가서 `epel-release` 명령어로 CentOS 패키지 repo를 먼저 설치해야한다.
```sh
virsh console ansible-server
yum install epel-release
yum install ansible
```

만약 설치 과정에서 다음의 에러를 만날 수 있다. 이는 centos8의 `mirrorlist.centos.org`가 운영을 종료했기 때문에 발생한 문제이다.
```sh
yum install epel-release

CentOS Stream 8 - AppStream                     0.0  B/s |   0  B     00:00    

Errors during downloading metadata for repository 'appstream':

  - Curl error (6): Couldn't resolve host name for http://mirrorlist.centos.org/?release=8-stream&arch=x86_64&repo=AppStream&infra=stock [Could not resolve host: mirrorlist.centos.org]

Error: Failed to download metadata for repo 'appstream': Cannot prepare internal mirrorlist: Curl error (6): Couldn't resolve host name for http://mirrorlist.centos.org/?release=8-stream&arch=x86_64&repo=AppStream&infra=stock [Could not resolve host: mirrorlist.centos.org]
```

그래서 아래와 같이 mirror 서버를 `vault.centos.org`로 바꾸도록 하자.
```sh
cd /etc/yum.repos.d/
sudo sed -i 's/mirrorlist/#mirrorlist/g' CentOS-Stream-*.repo
sudo sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' CentOS-Stream-*.repo
```
이제 다시 위에 있는 설치 명령어를 실행하면 성공할 것이다.

설치가 완료되었다면 이제 버전을 확인해보도록 하자.
```sh
ansible --version
ansible [core 2.16.3]
  config file = /etc/ansible/ansible.cfg
  configured module search path = ['/root/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3.12/site-packages/ansible
  ansible collection location = /root/.ansible/collections:/usr/share/ansible/collections
  executable location = /usr/bin/ansible
  python version = 3.12.1 (main, Feb 21 2024, 14:18:26) [GCC 8.5.0 20210514 (Red Hat 8.5.0-21)] (/usr/bin/python3.12)
  jinja version = 3.1.2
  libyaml = True
```
이렇게 나오면 성공이다.

## VM 재시작 시에도 nmcli 설정
왜인지는 모르겠는데 자꾸 호스트를 재시작하면 VM의 network 설정이 초기화된다. 아예 systemd에 설정해서 초기에 설정되도록 하자.

ansible-server의 설정은 다음과 같다.

- /usr/local/bin/setup-network.sh
```sh
#!/bin/bash

# resolv.conf에 DNS 추가
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# 기본 IP, 게이트웨이, DNS 설정
nmcli con modify enp1s0 ipv4.method manual \
    ipv4.addresses 192.168.122.4/24 \
    ipv4.gateway 192.168.122.1 \
    ipv4.dns 192.168.122.1

# 추가 IP 주소 설정 (Secondary IP)
nmcli con modify enp1s0 +ipv4.addresses 192.168.100.4/24

# 연결 활성화
nmcli con up enp1s0
```

다음으로 권한을 바꿔주도록 하자.
```sh
sudo chmod +x /usr/local/bin/setup-network.sh
sudo chown root:root /usr/local/bin/setup-network.sh
```

이제 systemd 서비스 파일을 생성해주도록 하자.

- /etc/systemd/system/setup-network.service
```sh
[Unit]
Description=Custom network setup on boot
After=NetworkManager.service
Requires=NetworkManager.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup-network.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
```

바로 적용시켜보도록 하자.
```sh
sudo systemctl daemon-reload
sudo systemctl enable setup-network.service
sudo systemctl start setup-network.service   # 즉시 적용
```

ip가 잘 붙었는 지 확인해보도록 하자.
```sh
ip -br addr
lo               UNKNOWN        127.0.0.1/8 ::1/128 
enp1s0           UP             192.168.122.4/24 192.168.100.4/24 fe80::5054:ff:feef:463f/64 
virbr0           DOWN           192.168.122.1/24 
```
성공한 것을 볼 수 있다. 이제 나머지 tnode1-centos8과 tnode2-rhel에도 해주면 된다.

## 인벤토리 사용법
어떤 시스템의 호스트를 자동화할 것인지 대상 호스트를 선정하는 것이 먼저이다. 대상 호스트 선정이 되면 인벤토리를 통해 대상 호스트를 설정할 수 있다. 인벤토리를 이용하여 자동화 대상 호스트를 설정하는 방법에 대해서 알아보도록 하자.

인벤토리 파일은 텍스트 파일이며, 앤서블이 자동화 대상으로 하는 관리 호스트를 지정한다. 이 파일은 `INI` 스타일 형식(이름=값) 또는 YAML을 포함한 다양한 형식을 사용할 수 있다.

가장 간단한 형식인 `INI` 스타일 인벤토리는 다음과 같이 호스트명 또는 IP 주소를 한 줄 씩 나열하는 목록 형태이다.
```sh
web1.example.com
db1.example.com
192.0.2.42
```

우리의 대상 타겟들에 대한 IP를 적어주도록 하자.
```
cd /home/ansible-server
mkdir ./my-ansible && cd ./my-ansible
echo 192.168.100.6 > ./inventory
echo 192.168.100.7 >> ./inventory
```

`cat ./inventory `으로 확인하면 다음과 같다.
```sh
192.168.100.6
192.168.100.7
```

이렇게하면 inventory가 완성이다.

만약 이렇게 IP 주소가 아니라 host 이름으로 하고 싶다면 `/etc/hosts`에 다음의 데이터를 추가한다음에 inventory를 수정하면 된다.
```sh
vi /etc/hosts

192.168.100.6   tnode1-centos8.exp.com
192.168.100.7   tnode2-rhel.exp.com
```

설정이 완료되었다면 이제 inventory를 host 이름으로 수정하도록 하자.
```sh
vi ./inventory

tnode1-centos8.exp.com
tnode2-rhel.exp.com
```

### 그룹별 호스트 설정
그룹별로 호스트를 설정하여 사용하면 앤서블 플레이북 실행 시 그룹별로 작업을 처리할 수 있어 좀 더 효과적이다. 이 경우 다음과 같이 `[]`으로 그룹명을 작성하여 해당 그룹에 속하는 호스트명이나 IP를 한줄에 하나씩 나열한다. 참고로 host들은 서로 다른 그룹에 속할 수 있다. 즉, 하나의 host가 하나의 그룹에 속한다고 해서 다른 그룹에 속하지 못하는 것은 아니다. 

```
[webservers]
web1.example.com
web2.example.com
192.0.2.42

[db-servers]
db01.example.com
db02.example.com

[east-datacenter]
web1.example.com
db01.example.com
```

### 중첩 그룹 정의
앤서블 인벤토리는 호스트 그룹에 기존에 정의한 로스트 그룹을 포함할 수도 있다. 이 경우 호스트 그룹 이름 생성시 `:children` 접미사를 추가하면 된다. 다음은 `[datacenter:children]` 그룹이 `[webservers]`, `[db-servers]` 그룹을 포함하고 있다는 것을 보여준다. 

```sh
[webservers]
web1.example.com
web2.example.com
192.0.2.42

[db-servers]
db01.example.com
db02.example.com

[datacenter:children]
webservers
dbservers
```

### 범위를 사용한 호스트 사양 간소화
호스트 또는 IP 주소를 지정할 때 범위를 지정할 수 있다. 가령 `192.168.100.0`에서 `192.168.100.255`까지 모두 포함하고 싶은 경우가 있을 수 있다. 이 같은 경우 `192.168.100.[0:255]`과 같이 간단하게 쓸 수 있다. 정리하면 다음과 같다.
```
[start:end]
```

아래의 예제를 보도록 하자.
```sh
[webservers]
web[1:2].example.com

[db-servers]
db[01:02].example.com

[defaults]
192.168.4.[0:255]
```
1. `web1.example.com`, `web2.example.com` 두 개가 나온다.
2. `db01.example.com`, `db02.example.com` 두 개가 나온다.
3. `192.168.4.0`에서 `192.168.4.255`까지 표현된다.

숫자 범위 뿐만 아니라 문자도 가능하다. 가령 abc까지라면
```sh
[dns]
[a:c].dns.example.com
```
1. `a.dns.example.com`, `b.dns.example.com`, `c.dns.example.com` 이렇게 3개가 나온다.

더 자세한 예제들은 `/etc/ansible/hosts`에 들어가면 설명한 인벤토리 사용 예들을 자세히 볼 수 있다.

### 인벤토리 확인
인벤토리를 지정하여 해당 인벤토리의 구조가 어떻게되어 있는 지 한 눈에 확인할 수 있는 명령어도 있다. `ansible-inventory` 라는 명령어를 사용하면 된다.

```sh
ansible-inventory -i ./inventory --graph
@all:
  |--@ungrouped:
  |  |--tnode2-centos8.exp.com
  |  |--tnode3-rhel.exp.com
```
`-i` 옵션으로 inventory 파일을 지정한다. `--graph`로 그래프 형식의 모습을 볼 수 있다. `--list`로 바꾸면 json 형식으로 볼 수 있다.

우리의 인벤토리를 다음과 같이 바꿔보도록 하자.
```sh
vi ./inventory

[web]
tnode1-centos8.exp.com

[db]
tnode2-rhel.exp.com

[all:children]
web
db
```
이 다음 `ansible-inventory -i ./inventory --list`로 확인하면 다음과 같다.

```json
{
    "_meta": {
        "hostvars": {}
    },
    "all": {
        "children": [
            "ungrouped",
            "web",
            "db"
        ]
    },
    "db": {
        "hosts": [
            "tnode2-rhel.exp.com"
        ]
    },
    "web": {
        "hosts": [
            "tnode1-centos8.exp.com"
        ]
    }
}
```

`-i` 옵션을 쓰지 않고 현재 프로젝트의 ansible의 적용되고 있는 inventory의 구성을 확인하기 위해서는 `-i`옵션을 빼고 `inventory` 파일을 쓰지 않으면 된다. 단, 먼저 `ansible.cfg`에 어떤 inventory를 사용할 지 지정되어 있어야 한다. 이제 현재 디렉터리 내에 `ansible.cfg`라는 앤서블 환경 설정 파일을 다음과 같이 구성하도록 하자.

```sh
vi ./ansible.cfg

[defaults]
inventory = ./inventory
```

`ansible-inventory --list` 명령어를 사용 현재 프로젝트에 적용 중인 inventory 구성이 나온다.
```sh
{
    "_meta": {
        "hostvars": {}
    },
    "all": {
        "children": [
            "ungrouped",
            "web",
            "db"
        ]
    },
    "db": {
        "hosts": [
            "tnode2-rhel.exp.com"
        ]
    },
    "web": {
        "hosts": [
            "tnode1-centos8.exp.com"
        ]
    }
}
```