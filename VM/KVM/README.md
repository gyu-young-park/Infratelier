# Chapter 1: Understanding Linux Virtualization

- Linux 가상화와 기본 개념
- 가상화의 종류
- 하이퍼바이저(VMM)
- 오픈 소스 가상화 프로젝트
- 클라우드에서의 Linux 가상화
- Linux 가상화의 역사

## Linux 가상화란
Virtualization은 가상 리소스를 생성하고 이를 물리 리소스에 매핑하는 개념이다. 이는 하드웨어 기능(파티셔닝 등)이나 소프트웨어(하이퍼바이저)를 통해 구현할 수 있다.

예를 들어, 16코어 서버에서 KVM 기반 하이퍼바이저를 실행하면, 2코어씩 할당된 여러 VM을 동시에 실행할 수 있다. 가상 머신 개수 제한은 벤더에 따라 다르며, 예를 들어 Red Hat Enterprise Virtualization 4.x는 최대 768 logical CPU까지 지원한다.

## 가상화의 역사
2003년 AMD의 64비트 CPU (Athlon 64, Opteron) 출시 이후, x86 아키텍처에서 가상화가 현실화되기 시작한다. 그 전까지는 IBM S/360, CP-40 등 메인프레임에서만 가능하던 기술이었다. 이후 VMware, Red Hat, Microsoft, Oracle 등의 기업이 가상화 솔루션을 경쟁적으로 출시한다.

## Xen의 등장
2003년, x86 아키텍처용 최초의 오픈소스 하이퍼바이저인 Xen이 등장한다. 다양한 CPU 아키텍처를 지원하며, 여러 운영체제를 동시에 실행할 수 있다. Citrix XenServer, Oracle VM 등에서 사용된다.

Red Hat은 RHEL 5에서 Xen을 포함했지만, RHEL 6부터는 KVM으로 전환한다. 이는 Xen이 메인라인 커널에 포함되지 않았고, Red Hat이 개발에 대한 영향력을 잃어가고 있었기 때문이다.

## KVM 개요
KVM은 리눅스 커널에 포함되는 모듈로, Linux 자체를 하이퍼바이저로 변환한다. Intel VT, AMD-V와 같은 하드웨어 가상화 기술이 필요하며, QEMU와 함께 사용되어 I/O 가상화를 처리한다. 최신 커널 버전의 성능 최적화와 보안 기능이 KVM과 게스트 OS 모두에 적용된다.

## 가상화의 종류
### 1. **Desktop Virtualization (VDI)**
- 중앙 집중식 관리, 장치에 구애받지 않고 접속 가능

### 2. **Server Virtualization**
- 물리 서버 대비 고효율, 백업, 에너지 절약 등 장점

### 3. **Application Virtualization**
- App-V, VMware App Volumes 등 사용

### 4. **Network Virtualization (SDN)**
- 물리적 네트워크 구성과 분리된 소프트웨어 정의 네트워크 구성

### 5. **Storage Virtualization (SDS)**
- 물리 스토리지를 논리적으로 통합, 블록/파일/오브젝트 형태로 제공

## 가상화 방식의 종류

| 방식 | 설명 |
|--------|-----|
| **Partitioning** | CPU를 여러 파티션으로 나누어 독립적으로 운영 |
| **Full Virtualization** | 하드웨어를 완전히 에뮬레이션, 게스트 OS는 가상 환경을 인식하지 못함 |
| **Paravirtualization** | 게스트 OS가 가상화를 인식하고 이에 맞게 수정되어 실행됨 |
| **Hybrid Virtualization** | full과 para를 결합하여 I/O 등에서 성능 향상 |
| **Container-based Virtualization** | VM 없이 컨테이너 단위로 어플리케이션 실행, Docker/Podman 등 |

## 하이퍼바이저/가상 머신 관리자 (VMM)
하이퍼바이저는 가상 머신의 생성, 자원 할당, 수명 주기, 리소스 매핑 등을 제어한다. 하나의 물리 시스템 위에서 여러 OS를 동시에 실행할 수 있으며, VMM은 이를 위한 핵심 구성요소다.

## 하이퍼바이저의 유형

### Type 1 Hypervisor (Bare-metal)
- OS 없이 하드웨어 위에서 직접 동작
- oVirt-node, VMware ESXi, RHEV-H 등

**장점:**
- 설치 간편
- 성능 효율적
- 보안성 높음

**단점:**
- 커스터마이징 어려움

### Type 2 Hypervisor (Hosted)
- 기존 OS 위에서 동작
- VMware Player, VirtualBox 등

**장점:**
- 하드웨어 지원 폭 넓음
- 커스터마이징 쉬움

**사용 예시:**
- Linux 데스크탑 위에 VM 구동 시 Type 2
- 서버에 가상화 전용 설치 시 Type 1



## 오픈소스 가상화 프로젝트

- KVM
- Xen
- VirtualBox
- QEMU
- LXC
- bhyve (FreeBSD)
- UML (User Mode Linux)



## Xen의 구조

- **Xen Hypervisor**: 하드웨어와 VM 간의 인터페이스 담당
- **Dom0**: Xen 환경을 관리하는 특권 VM, 보통 리눅스
- **DomU**: 일반 게스트 VM
- **QEMU**: CPU 및 주변장치 에뮬레이션



## KVM의 구조

- KVM은 리눅스 커널 모듈(`kvm.ko`)로 하이퍼바이저 역할 수행
- QEMU가 가상 하드웨어를 제공
- 최신 리눅스 커널 기능을 그대로 사용 가능



## 클라우드에서의 Linux 가상화

대형 퍼블릭 클라우드들은 대부분 리눅스 기반 가상화를 사용한다:

- **AWS**: KVM + Xen 혼합
- **Google Cloud**: KVM 기반
- **Azure**: Hyper-V 기반

### 오픈소스 클라우드 프로젝트

- **OpenStack**: KVM 중심, IaaS 구축 가능
- **CloudStack**: Xen과 긴밀히 통합됨
- **Eucalyptus**: AWS 호환 프라이빗 클라우드, KVM/Xen 지원



## 리눅스 커널 관점의 KVM vs Xen 비교

| 항목 | KVM | Xen |
|------|--|--|
| 커널 통합 여부 | 커널 모듈로 직접 포함 | 별도 하이퍼바이저 계층 |
| 리눅스 역할 | 하이퍼바이저 자체 | Dom0 역할, Xen 관리 |
| 드라이버 처리 | 리눅스가 직접 사용 | Dom0에서 백엔드 드라이버 처리 |
| 커널 기능 사용 | 모든 최신 기능 사용 가능 | 제한적 |
| 메인라인 포함 | 포함 (2.6.20 이후) | 초기에는 아님 (Dom0는 최근 병합됨) |



## Xen의 Domain(Dom) 구조

| 도메인 | 설명 |
|--|----|
| **Dom0** | Xen 환경 제어를 위한 특권 가상머신, Xen 하이퍼바이저와 게스트 VM 관리 |
| **DomU** | 일반 게스트 VM. Ubuntu, Windows 등 다양한 OS 실행 가능 |

Xen은 전통적인 Host OS 개념이 없으며, Dom0가 그 역할을 대신 수행한다. Xen은 하드웨어 위에 직접 올라가는 베어메탈 하이퍼바이저이며, 리눅스는 Dom0라는 VM으로 Xen을 제어한다.


