# Git의 유용한 command들

## Git ignore 대상 알아보는 방법
```sh
git status --ignored


Untracked files:
  (use "git add <file>..." to include in what will be committed)
        .gitignore
        git/

Ignored files:
  (use "git add -f <file>..." to include in what will be committed)
        AWS/aws-cli-ec2-key.pem
```
`--ignored` 명령어를 사용하면 `.gitignore`로 무시된 파일이 무엇인지 볼 수 있다.
