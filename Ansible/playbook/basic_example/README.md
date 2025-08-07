# 플레이북 작성하기
인벤토리를 사용하여 대상 호스트를 정의했다면 대상 호스트에 수행될 작업들을 정의하기 위한 플레이북을 작성해보도록 하자. `ansible.cfg`라는 환경 설정 파일이 존재하는 디렉터리가 앤서블 프로젝트 디렉터리가 될 수 있다. 

플레이북을 작성하고 실행하려면 여러 가지 설정을 미리 해주어야 한다. 가령 어떤 호스트에서 플레이북을 실행할 것인지 플레이북을 root 권한으로 실행할 지, 대상 호스트에 접근할 때는 `SSH` 키를 이용할 것인지 패스워드를 이용할 것인지 등을 설정해주어야 한다. 

앤서블 프로벡트 디렉터리에 `ansible.cfg` 파일을 생성하면 다양한 앤서블 설정을 적용할 수 있다. 앤서블 환경 설정 파일에는 각 섹션에 키-값 쌍으로 정의된 설정이 포함되며, 여러 개의 섹션으로 구성된다. 섹션 제목은 대괄호로 묶여 있으며, 기본적인 실행을 위해 다음과 같이 `[default]`와 `[previlege_escalation]` 두 개의 섹션을 구성한다.

- ansible.cfg
```sh
[defaults]
inventory = ./inventory
[defaults]
inventory = ./inventory
remote_user = user
ask_pass = false

[privilege_escalation]
become = true
become_method = sudo
become_user = root
become_ask_pass = false
```

## [defaults] 섹션
앤서블 작업을 위한 기본값을 설정하며 매개 변수별 설정값은 다음과 같은 의미를 갖는다.
1. inventory: 인벤토리 파일의 경로를 지정
2. remote_user: 앤서블이 관리 호스트에 연결할 때, 연결하려는 호스트의 사용자 이름을 지정한다. 이때 사용자 이름을 지정하지 않으면 현재 사용자 이름으로 지정된다.
3. ask_pass: SSH 암호를 묻는 메시지 표시 여부를 지정한다. SSH 공개 키 인증을 사용하면 기본값이 false이다.

만약 각 호스트마다 user 이름이 다르다면 다음과 같이 쓸 수 있다.
```sh
[web]
tnode1 ansible_host=tnode1-centos8.exp.com ansible_user=tnode1-centos8

[db]
tnode2 ansible_host=tnode2-rhel.exp.com ansible_user=tnode2-rhel

[all:children]
web
db
```
다음과 같이 `ansible_user`로 각 host의 user를 지정할 수도 있다.

## [privilege_escalation] 섹션
보안과 감사로 인해 앤서블의 원격 로스트에 권한이 없는 사용자로 먼저 연결한 후 관리 액세스 권한을 에스컬레이션하여 루트 사용자로 가져와야 할 때도 있다. 이 경우 해당 권한을 여기에 설정할 수 있다. 

1. become: 연결 후 관리 호스트에서 자동으로 사용자를 전환할 지 여부를 지정한다. 일반적으로 `root`로 전환되며 플레이북에서도 지정할 수 있다.
2. become_method: 권한을 에스컬레이션하는 사용자 전환 방식을 의미한다. 일반적으로 기본값은 `sudo`를 사용하며 `su`는 옵션으로 설정할 수 있다.
3. becomd_user: 관리 호스트에서 전환할 사용자를 지정한다. 일반적으로 `root`이다.
4. become_ask_pass: `become_method` 매개 변수에 대한 암호를 묻는 메시지 표시 여부를 지정한다. 기본값은 `false`이다. 

앤서블은 기본적으로 SSH로 remote host에 연결한다. 앤서블에서 관리 호스트에 연결하는 방법을 제어하는 가장 중요한 매개 변수는 `[defaults]` 섹션에 설정되어 있다. 또한, 별도로 설정되어 있지 않으면 앤서블은 실행 시 로컬 사용자와 같은 사용자 이름으로 관리 호스트에 연결한다. 

## 앤서블 접근을 위한 SSH 인증 구성
앤서블은 로컬 사용자에게 개인 SSH 키가 있거나 관리 호스트에서 원격 사용자임을 인증 가능한 키가 구성된 경우 자동으로 로그인된다. SSH 키 기반의 인증을 구성할 때는 `ssh-keygen`을 사용하여 다음과 같이 생성할 수 있다. 또한 `ssh-copy-id` 명령어를 사용하여 SSH 공개 키를 해당 호스트로 복사할 수 있다.

먼저 `ssh-keygen`으로 ansible-server의 SSH key를 만들도록 하자. 모두 enter를 누르면 key가 생성된 것을 볼 수 있다.
```sh
ssh-keygen 
Generating public/private rsa key pair.
Enter file in which to save the key (/home/ansible-server/.ssh/id_rsa): 
/home/ansible-server/.ssh/id_rsa already exists.
Overwrite (y/n)? y
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /home/ansible-server/.ssh/id_rsa.
Your public key has been saved in /home/ansible-server/.ssh/id_rsa.pub.
The key fingerprint is:
```
필자의 공개 SSh key는 `home/ansible-server/.ssh/id_rsa`에 저장되었다.

SSH 키가 생성되면 `ssh-copy-id` 명령어로 관리 노드로 ssh 공개 키를 복사시킨다.
```sh
for i in {6..7}; do ssh-copy-id root@192.168.100.$i; done
```
참고로 ssh key를 사용한 방식에서 공개키를 관리 호스트에 전달하는 이유는 관리 호스트에 서버가 접속하려고 시도할 때, 관리 호스트가 공개키를 사용하여 challenge(랜덤 문자)를 암호화하고, 클라이언트인 ansible-server가 개인키로 이를 해독하여 관리 호스트에 전달하면 인증이 성공하는 방식이다. 이는 디지털 서명 개념과 동일하다.

실제로 ssh가 성공하는 지 확인하도록 하자.
```sh
ssh root@192.168.100.6
ssh root@192.168.100.7
```

이제 인벤토리 파일을 생성했던 `my-ansible` 디렉토리로 전환하여 `ansible.cfg`를 다음과 같이 수정하자.

- ansible.cfg
```sh
[defaults]
inventory = ./inventory
remote_user = root
ask_pass = false

[privilege_escalation]
become = true
become_method = sudo
become_user = root
become_ask_pass = false
```

인벤토리도 다음과 같이 설정해주도록 하자.

- inventory
```sh
[web]
tnode1-centos8.exp.com

[db]
tnode2-rhel.exp.com

[all:children]
web
db
```

앤서블 환경 설정이 준비되면 `ansible` 명령어로 `ping` test를 진행한다. ping 모듈을 이용하여 `web` 그룹 호스트로 정상적으로 통신이 이루어지면 `SUCCESS`라는 결과가 나온다. 
```sh
ansible -m ping web

tnode1-centos8.exp.com | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/libexec/platform-python"
    },
    "changed": false,
    "ping": "pong"
}
```

## 플레이북 만들기
플레이북은 `yaml` 포맷으로 `.yml` 확장자를 사용하여 저장된다. 플레이북은 앞서 말했듯이 대상 호스트나 호스트 집합에 수행할 작업을 정의하고 이를 실행한다. 이때 특정 작업 단위를 수행하기 위해 모듈을 적용한다.

가상 심플한 플레이북을 만들어보자. 

- first-playbook.yml
```yml
---
- hosts: all
  tasks:
    - name: Pring message
      debug:
        msg: Hello Ansible World
```
위의 플레이북은 `debug` 모듈을 이용하여 `Hello Ansible World`라는 문자열을 출력한다.

현재 디렉토리 구조를 보면 다음과 같다.
```sh
[root@localhost my-ansible]# tree
.
├── ansible.cfg
├── first-playbook.yml
└── inventory
```

이제 플레이북 문법을 체크해보자. 플레이북 작성 시 엄격한 공백 문자 때문에 문법 오류가 발생할 확률이 높다. 앤서블은 플레이북 실행 시 작체적으로 제공하는 모듈을 사용했는 지 그리고 공백은 잘 들여쓰기가 되었는 지를 체크할 수 있다. 다음과 같이 `ansible-playbook` 명령어에 `--syntax-check` 옵션을 추가한 후 실행하고자 하는 플레이북 `yml` 파일명을 입력하면 문법 체크를 수행한다. 특별한 오류가 없으면 다음 결과를 확인할 수 있다.

```sh
ansible-playbook --syntax-check first-playbook.yml

playbook: first-playbook.yml
```

만약 오류가 있다면 붉은 색으로 표시가 된다.

## 플레이북 실행
이제 첫번째 플레이북을 실행해보도록 하자.

플레이북 실행 명령어는 다음과 같다.
```sh
ansible-playbook {playbook}
```

우리의 경우 다음과 같이쓰면 된다.
```sh
ansible-playbook first-playbook.yml
```

다음과 같이 SSH 클라이언트가 처음보는 호스트와 접속하려고 할 때의 문의가 나올 수 있다.
```sh
The authenticity of host 'tnode2-rhel.exp.com (192.168.100.7)' can't be established.
ECDSA key fingerprint is SHA256:...
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

이런 값들이 나오지 않고 싶다면 다음과 같이 실행하면 된다.
```sh
ansible-playbook playbook.yml -e ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

실행 후 결과를 보도록 하자.
```sh

PLAY [all] *********************************************************************

TASK [Gathering Facts] *********************************************************
ok: [tnode2-rhel.exp.com]
ok: [tnode1-centos8.exp.com]

TASK [Pring message] ***********************************************************
ok: [tnode1-centos8.exp.com] => {
    "msg": "Hello Ansible World"
}
ok: [tnode2-rhel.exp.com] => {
    "msg": "Hello Ansible World"
}

PLAY RECAP *********************************************************************
tnode1-centos8.exp.com     : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
tnode2-rhel.exp.com        : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```
제대로 성공한 것을 볼 수 있다.

플레이북을 실행하기 전에 제대로 실행될 지 궁금하다면 `--check` 옵션을 사용하여 실행 상태를 미리 점검 할 수 있다. 이 옵션을 사용하면 앤서블에서 플레이북을 실행해도 대상 호스트는 실제로 변경되지 않고 어떤 내용이 변경될지만 미리 알 수 있다.

`--check` 옵션을 사용하기 위해서 예제로 `restart-service.yml`을 만들어보도록 하자.

- restart-service.yml
```sh
---
- hosts: all
  tasks:
    - name: Restart sshd service
      ansible.builtin.service:
        name: sshd
        state: restarted

```

이제 `--check` 옵션을 사용해 `ansible-playbook`을 실행해보자. 그러면 `ssh` 서비스가 재시작되어 서비스 상태가 변경될 예정이므로 `Restart sshd service` 태스크에 `changed`라는 문구를 확인할 수 있다.
```sh
ansible-playbook --check restart-service.yml 

PLAY [all] *********************************************************************

TASK [Gathering Facts] *********************************************************
ok: [tnode2-rhel.exp.com]
ok: [tnode1-centos8.exp.com]

TASK [Restart sshd service] ****************************************************
changed: [tnode1-centos8.exp.com]
changed: [tnode2-rhel.exp.com]

PLAY RECAP *********************************************************************
tnode1-centos8.exp.com     : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
tnode2-rhel.exp.com        : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

이번에는 실제로 실행해보도록 하자.
```sh
ansible-playbook restart-service.yml 


PLAY [all] *********************************************************************

TASK [Gathering Facts] *********************************************************
ok: [tnode1-centos8.exp.com]
ok: [tnode2-rhel.exp.com]

TASK [Restart sshd service] ****************************************************
changed: [tnode2-rhel.exp.com]
changed: [tnode1-centos8.exp.com]

PLAY RECAP *********************************************************************
tnode1-centos8.exp.com     : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
tnode2-rhel.exp.com        : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

잘 실행된 것을 볼 수 있다. 결과를 확인하기 위해서 관리 호스트에 들어가 `/var/log/message`를 보도록 하자.

```sh
[tnode1-centos8@tnode1-centos8 ~]$ sudo tail -n 10 /var/log/messages 
Aug  7 10:53:28 tnode1-centos8 systemd[1]: Reached target sshd-keygen.target.
Aug  7 10:53:28 tnode1-centos8 systemd[1]: Starting OpenSSH server daemon...
Aug  7 10:53:28 tnode1-centos8 systemd[1]: Started OpenSSH server daemon.
Aug  7 10:54:17 tnode1-centos8 dbus-daemon[809]: [system] Activating via systemd: service name='net.reactivated.Fprint' unit='fprintd.service' requested by ':1.238' (uid=0 pid=5292 comm="sudo tail -n 20 /var/log/messages " label="unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023")
Aug  7 10:54:17 tnode1-centos8 systemd[1]: Starting Fingerprint Authentication Daemon...
Aug  7 10:54:17 tnode1-centos8 dbus-daemon[809]: [system] Successfully activated service 'net.reactivated.Fprint'
Aug  7 10:54:17 tnode1-centos8 systemd[1]: Started Fingerprint Authentication Daemon.
Aug  7 10:54:29 tnode1-centos8 systemd[1]: session-21.scope: Succeeded.
Aug  7 10:54:29 tnode1-centos8 systemd-logind[803]: Session 21 logged out. Waiting for processes to exit.
Aug  7 10:54:29 tnode1-centos8 systemd-logind[803]: Removed session 21.
```
`sshd` 재시작 로그를 볼 수 있다.