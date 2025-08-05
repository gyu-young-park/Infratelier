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
| tnode1-ubuntu | Ubuntu 20.04 | 2 | 2GB | 30GB | 192.168.100.6 |
| tnode2-rhel | RHEL 8.8 | 2 | 2GB | 30GB | 192.168.100.7 |

`ansible-server`는 ansible을 설치되고 inventory와 playbook이 위치할 제어 노드로 `CentOS Stream8`로 구성한다. 

```sh
                                               +------------------------------+                                                              
+------------------------------+               |         tnode1-ubuntu        |                                                              
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

ubuntu에서 KVM 및 virt-manager를 설치하도록 하자.

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
wget https://releases.ubuntu.com/focal/ubuntu-20.04.6-live-server-amd64.iso
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

```sh
sudo virt-install \
    --name tnode1-ubuntu \
    --os-variant ubuntu20.04 \
    --ram 2048 \
    --vcpus 2 \
    --disk path=/var/lib/libvirt/images/tnode1-ubuntu.qcow2,size=30 \
    --network network=default,model=virtio \
    --location /경로/to/ubuntu-20.04.6-live-server-amd64.iso \
    --noautoconsole
```

```sh
sudo virt-install \
    --name tnode2-rhel \
    --os-variant rhel8.8 \
    --ram 2048 \
    --vcpus 2 \
    --disk path=/var/lib/libvirt/images/tnode2-rhel.qcow2,size=30 \
    --network network=default,model=virtio \
    --location /경로/to/rhel-8.8-x86_64-dvd.iso \
    --noautoconsole
```