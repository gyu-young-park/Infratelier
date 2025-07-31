# helm 설치
```sh
# 1) 최신 Helm 버전 확인
HELM_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep tag_name | cut -d '"' -f 4)

# 2) 아키텍처 및 OS 확인
ARCH=$(uname -m)
# amd64는 x86_64로 표시됨
if [ "$ARCH" = "x86_64" ]; then
  ARCH=amd64
elif [ "$ARCH" = "aarch64" ]; then
  ARCH=arm64
fi

# 3) Helm tarball 다운로드
curl -LO https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz

# 4) 압축 해제
tar -zxvf helm-${HELM_VERSION}-linux-${ARCH}.tar.gz

# 5) 바이너리 이동
sudo mv linux-${ARCH}/helm /usr/local/bin/helm

# 6) 실행 권한 부여 (대개 필요 없음)
sudo chmod +x /usr/local/bin/helm

# 7) 임시 파일 삭제
rm -rf linux-${ARCH} helm-${HELM_VERSION}-linux-${ARCH}.tar.gz

# 8) 설치 확인
helm version

```