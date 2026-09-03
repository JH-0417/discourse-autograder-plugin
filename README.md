# Discourse Autograder Plugin

Discourse 토픽의 댓글에 첨부된 CSV 제출 파일을 자동채점 서비스로 전달하고, 제출 점수·문제별 최고 점수·카테고리별 랭킹·종합 랭킹을 Discourse에 표시하는 플러그인입니다.

이 플러그인은 **Discourse/Ruby 플러그인**입니다. Python 패키지가 아니므로 `pip install`로 설치하지 않습니다. Docker 기반 Discourse의 `app.yml`에 GitHub 저장소를 등록하고 `launcher rebuild app`으로 설치합니다.

> 실제 CSV 판정과 비공개 정답 비교는 별도 Python 채점 서버인 [`JH-0417/discourse-autograder`](https://github.com/JH-0417/discourse-autograder)가 담당합니다. 이 플러그인만 설치하면 UI와 Discourse 측 제출·랭킹 기능이 설치되지만, 실제 자동채점까지 사용하려면 Python 채점 서버도 별도로 설치하고 연결해야 합니다.

## 목차

1. [기능](#기능)
2. [전체 아키텍처](#전체-아키텍처)
3. [사전 요구 사항](#사전-요구-사항)
4. [설치 전 확인](#설치-전-확인)
5. [Discourse 플러그인 설치](#discourse-플러그인-설치)
6. [재빌드 및 설치 확인](#재빌드-및-설치-확인)
7. [Python 채점 서버 연결](#python-채점-서버-연결)
8. [문제·정답 데이터 운영](#문제정답-데이터-운영)
9. [동작 테스트](#동작-테스트)
10. [업데이트](#업데이트)
11. [롤백](#롤백)
12. [제거](#제거)
13. [문제 해결](#문제-해결)
14. [보안 및 운영 원칙](#보안-및-운영-원칙)

## 기능

- Discourse 문제 토픽의 댓글에 첨부된 CSV 제출 파일 처리
- 제출별 자동채점 결과 및 점수 저장
- 사용자별·문제별 최고 점수 선택
- 카테고리별 랭킹 표시
- 여러 카테고리를 합산한 종합 랭킹 표시
- 현재 토픽이 속한 카테고리를 기준으로 랭킹 집계
- 제출자 사용자 정보 및 소속 플러그인과의 연동을 고려한 랭킹 표시
- Discourse 게임화 점수와의 동기화 지원

## 전체 아키텍처

이 프로젝트는 다음 세 구성 요소로 운영하는 것을 전제로 합니다.

```text
[사용자]
  └── Discourse 문제 토픽 댓글에 submission.csv 첨부

[Discourse Docker 컨테이너]
  ├── Discourse-user-affiliation 플러그인
  └── discourse-autograder-plugin (이 저장소)
       ├── 제출 처리
       ├── 채점 결과 저장
       └── 랭킹 화면·API 제공

[별도 Python 채점 서버]
  └── JH-0417/discourse-autograder
       ├── CSV 검증
       ├── 비공개 정답 CSV 로드
       ├── 평가 지표 계산
       └── 채점 결과 반환

[운영 서버의 비공개 데이터]
  └── ground_truths/topic_<TOPIC_ID>.csv
```

### 저장소별 책임

| 저장소 | 책임 | 설치 방식 |
|---|---|---|
| `Discourse-user-affiliation` | 사용자 소속 정보·사용자 카드 표시 | Discourse `app.yml` + rebuild |
| `discourse-autograder-plugin` | 제출 처리, 점수 저장, 랭킹 UI·API | Discourse `app.yml` + rebuild |
| `discourse-autograder` | Python CSV 채점 API와 정답 비교 | Git clone + venv + `pip install` + systemd |

## 사전 요구 사항

다음 조건을 만족해야 합니다.

- Docker 기반 self-hosted Discourse가 정상 동작 중이어야 합니다.
- 서버에 SSH 접속 및 `sudo` 권한이 있어야 합니다.
- 서버가 GitHub에 HTTPS로 접근할 수 있어야 합니다.
- Discourse Docker 설치 경로로 `/var/discourse`를 사용한다고 가정합니다.
- 실제 자동채점을 사용하려면 별도 Python 채점 서버가 필요합니다.
- Python 채점 서버와 Discourse 컨테이너가 서로 통신할 수 있어야 합니다.

Discourse 컨테이너 상태를 확인합니다.

```bash
cd /var/discourse || exit 1
sudo ./launcher status
```

## 설치 전 확인

### 1. app.yml 백업

```bash
APP_YML=/var/discourse/containers/app.yml
sudo cp "$APP_YML" "${APP_YML}.backup-$(date +%Y%m%d-%H%M%S)"
```

백업이 생성됐는지 확인합니다.

```bash
ls -lh /var/discourse/containers/app.yml.backup-*
```

### 2. 기존 hooks 확인

```bash
sudo grep -n -A 60 -B 3 '^hooks:' /var/discourse/containers/app.yml
```

> 중요: `app.yml`에 이미 `hooks:` 또는 `after_code:`가 있다면 새 블록을 중복 생성하지 마세요. 기존 `after_code:` 목록에 필요한 `exec` 항목만 추가합니다.

### 3. 설치 버전 결정

운영 환경에서는 `main` 최신 상태를 매번 설치하지 말고, 검증한 40자리 Git commit SHA를 고정합니다.

이 README가 기준으로 사용하는 검증 커밋은 다음입니다.

```text
a58e75898eaba9ac272a56a530d94930c437ad93
```

이 버전은 랭킹을 제출 레코드의 과거 카테고리가 아니라 **현재 토픽 카테고리**를 기준으로 집계하도록 수정한 버전입니다.

## Discourse 플러그인 설치

### 방법 A: app.yml에 hooks가 없는 경우

`/var/discourse/containers/app.yml`에 다음 블록을 추가합니다.

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd: git clone https://github.com/JH-0417/discourse-autograder-plugin.git discourse-autograder

    - exec:
        cd: $home/plugins/discourse-autograder
        cmd: git checkout a58e75898eaba9ac272a56a530d94930c437ad93
```

### 방법 B: app.yml에 after_code가 이미 있는 경우

기존 `hooks:` → `after_code:` 목록 끝에 아래 두 항목만 추가합니다.

```yaml
    - exec:
        cd: $home/plugins
        cmd: git clone https://github.com/JH-0417/discourse-autograder-plugin.git discourse-autograder

    - exec:
        cd: $home/plugins/discourse-autograder
        cmd: git checkout a58e75898eaba9ac272a56a530d94930c437ad93
```

### 소속 플러그인과 함께 설치하는 예시

소속 정보 표시도 사용할 경우 `Discourse-user-affiliation`을 같은 `after_code:` 목록에 함께 등록합니다.

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd: git clone https://github.com/JH-0417/Discourse-user-affiliation.git discourse-user-affiliation

    - exec:
        cd: $home/plugins/discourse-user-affiliation
        cmd: git checkout <검증된_AFFILIATION_PLUGIN_SHA>

    - exec:
        cd: $home/plugins
        cmd: git clone https://github.com/JH-0417/discourse-autograder-plugin.git discourse-autograder

    - exec:
        cd: $home/plugins/discourse-autograder
        cmd: git checkout a58e75898eaba9ac272a56a530d94930c437ad93
```

### 사설 저장소인 경우

저장소를 private으로 운영할 경우 빌드 중 HTTPS clone 인증이 필요합니다. deploy key, 최소 권한의 fine-grained GitHub token, GitHub App 또는 조직의 내부 Git 미러를 사용하세요.

GitHub token·deploy key·SMTP 비밀번호·채점 API 비밀값을 `app.yml`, Git URL, README 또는 저장소에 평문으로 커밋하지 마세요.

## 재빌드 및 설치 확인

### 1. app.yml 검토

```bash
sudo grep -n -E 'discourse-autograder-plugin|discourse-autograder|a58e758' \
  /var/discourse/containers/app.yml
```

### 2. Discourse 재빌드

```bash
cd /var/discourse || exit 1
sudo ./launcher rebuild app
```

> 주의: 재빌드 과정에서 포럼 서비스가 잠시 중단됩니다. 운영 환경에서는 점검 시간을 공지하세요.

### 3. 컨테이너 상태 확인

```bash
cd /var/discourse || exit 1
sudo ./launcher status
```

### 4. 컨테이너 내부 플러그인 경로 확인

```bash
cd /var/discourse || exit 1
sudo ./launcher enter app

cd /var/www/discourse/plugins/discourse-autograder
ls -la
cat plugin.rb

exit
```

`plugin.rb`가 보이면 새 컨테이너 이미지에 플러그인 코드가 포함된 것입니다.

### 5. 웹 UI 확인

1. 관리자 계정으로 Discourse에 로그인합니다.
2. `/admin/plugins`에서 Autograder 관련 플러그인이 보이는지 확인합니다.
3. `/admin/site_settings/category/plugins`에서 Autograder 관련 설정을 확인합니다.
4. 플러그인이 제공하는 랭킹 화면 또는 API 경로가 열리는지 확인합니다.

이 저장소에는 플러그인 라우트와 사이트 설정 정의가 포함되어 있습니다. 실제 사이트 설정 이름은 배포한 저장소 버전의 관리자 화면에서 확인하고 설정하세요.

## Python 채점 서버 연결

이 플러그인은 CSV를 직접 판정하지 않습니다. 실제 채점은 별도 Python 저장소가 담당합니다.

```text
https://github.com/JH-0417/discourse-autograder
```

Python 채점 서버 설치는 해당 저장소의 README를 따르세요. 개념적으로 다음 작업이 필요합니다.

```bash
cd /home/<SERVER_USER>
git clone https://github.com/JH-0417/discourse-autograder.git discourse_autograder
cd discourse_autograder

python3 -m venv autograder-env
source autograder-env/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

채점 서버는 systemd 서비스로 등록하여 서버 재부팅 후에도 자동 시작되게 하는 것을 권장합니다.

```text
discourse-autograder.service
```

### 연결 전 점검

Discourse 플러그인이 채점 API에 요청하기 전에 아래를 확인하세요.

- Python 채점 서버 프로세스가 실행 중인지
- 채점 서버가 예상 포트에서 응답하는지
- Discourse Docker 컨테이너에서 채점 서버 주소로 접근 가능한지
- Discourse 관리자 화면의 Autograder 플러그인 설정에 채점 API 주소가 올바르게 입력됐는지

컨테이너에서 통신을 확인하는 예시입니다. 실제 URL과 health endpoint는 채점 서버 구현에 맞게 바꾸세요.

```bash
cd /var/discourse || exit 1
sudo ./launcher enter app

curl -i http://<AUTOGRADER_HOST>:<AUTOGRADER_PORT>/<HEALTH_ENDPOINT>

exit
```

채점 서버를 외부 인터넷에 불필요하게 공개하지 마세요. 같은 호스트에서 운영한다면 `127.0.0.1` 바인딩, Docker host gateway 또는 reverse proxy를 포함한 내부 네트워크 연결을 우선 검토하세요.

## 문제·정답 데이터 운영

### 공개 데이터

문제 토픽 원글에는 참가자에게 제공할 파일만 첨부합니다.

```text
train.csv
test.csv
sample_submission.csv
```

### 비공개 정답 데이터

정답 데이터는 Discourse 토픽, GitHub 저장소, 공개 파일 첨부에 올리면 안 됩니다.

운영 서버의 보호된 경로에 topic ID별로 저장합니다.

```text
/home/<SERVER_USER>/discourse_autograder/ground_truths/topic_<TOPIC_ID>.csv
```

예시:

```text
/home/ahyeon/discourse_autograder/ground_truths/topic_39.csv
```

권한 예시:

```bash
install -d -m 700 /home/<SERVER_USER>/discourse_autograder/ground_truths
install -m 600 <LOCAL_GROUND_TRUTH_FILE> \
  /home/<SERVER_USER>/discourse_autograder/ground_truths/topic_<TOPIC_ID>.csv
```

### 정답 CSV 검증 원칙

채점 전에 다음을 확인합니다.

- CSV가 비어 있지 않은지
- 필요한 열 이름이 정확한지
- `id`가 중복되지 않는지
- `id` 수가 테스트 데이터 행 수와 같은지
- label 값과 자료형이 채점 서버 요구 사항에 맞는지
- 파일명이 실제 Discourse topic ID와 일치하는지

## 동작 테스트

### 1. 문제 토픽 생성

1. 대상 카테고리에서 새 문제 토픽을 만듭니다.
2. 공개 데이터 `train.csv`, `test.csv`, `sample_submission.csv`만 원글에 첨부합니다.
3. 토픽 URL에서 실제 numeric topic ID를 확인합니다.
4. 서버의 비공개 정답을 `topic_<TOPIC_ID>.csv`로 등록합니다.

### 2. 테스트 제출

문제 토픽의 **답글**에 아래 형식의 CSV를 첨부합니다.

```csv
id,prediction
1001,0.42
1002,0.87
1003,0.15
```

제출 CSV는 채점 서버 규칙에 맞아야 합니다.

- 파일 확장자: `.csv`
- 열: `id`, `prediction`
- 모든 테스트 ID를 한 번씩 포함
- prediction은 채점 서버에서 요구하는 범위와 형식 준수

### 3. 확인 항목

```text
[ ] 댓글 제출이 감지된다.
[ ] 채점 서버 요청이 성공한다.
[ ] 제출 점수와 세부 지표가 표시된다.
[ ] 제출 레코드가 저장된다.
[ ] 같은 사용자·같은 문제의 최고 점수가 선택된다.
[ ] 카테고리 랭킹이 갱신된다.
[ ] 종합 랭킹이 갱신된다.
[ ] 사용자 소속 정보가 설정된 경우 랭킹 표시가 정상이다.
[ ] 필요 시 게임화 점수가 동기화된다.
```

## 업데이트

### 1. 새 버전 검증

먼저 개발 또는 스테이징 환경에서 새 커밋을 검증합니다.

### 2. app.yml의 SHA 변경

```bash
OLD_SHA='a58e75898eaba9ac272a56a530d94930c437ad93'
NEW_SHA='<새로_검증한_40자리_커밋_SHA>'
APP_YML='/var/discourse/containers/app.yml'

sudo cp "$APP_YML" "${APP_YML}.backup-$(date +%Y%m%d-%H%M%S)"
sudo sed -i "s/${OLD_SHA}/${NEW_SHA}/g" "$APP_YML"

sudo grep -n "$NEW_SHA" "$APP_YML"
```

### 3. 재빌드

```bash
cd /var/discourse || exit 1
sudo ./launcher rebuild app
```

### main을 그대로 쓰는 방식

`git checkout` 줄을 빼면 매 재빌드마다 그 시점의 `main` 최신 코드가 설치됩니다. 개발 환경에서는 편할 수 있지만, 운영 환경에서는 검증되지 않은 변경이 자동 유입될 수 있으므로 권장하지 않습니다.

## 롤백

문제가 생기면 이전 정상 SHA로 변경한 뒤 재빌드합니다.

```bash
ROLLBACK_SHA='<이전에_검증된_40자리_커밋_SHA>'
APP_YML='/var/discourse/containers/app.yml'

sudo sed -i \
  "s/git checkout [a-f0-9]\{40\}/git checkout ${ROLLBACK_SHA}/" \
  "$APP_YML"

sudo grep -n 'git checkout' "$APP_YML"

cd /var/discourse || exit 1
sudo ./launcher rebuild app
```

또는 설치 전 만든 `app.yml` 백업을 복원합니다.

```bash
sudo cp /var/discourse/containers/app.yml.backup-<백업시각> \
  /var/discourse/containers/app.yml

cd /var/discourse || exit 1
sudo ./launcher rebuild app
```

## 제거

### 1. app.yml에서 두 hook 제거

아래 두 항목을 `app.yml`에서 모두 삭제합니다.

```yaml
- exec:
    cd: $home/plugins
    cmd: git clone https://github.com/JH-0417/discourse-autograder-plugin.git discourse-autograder

- exec:
    cd: $home/plugins/discourse-autograder
    cmd: git checkout a58e75898eaba9ac272a56a530d94930c437ad93
```

### 2. 재빌드

```bash
cd /var/discourse || exit 1
sudo ./launcher rebuild app
```

> 주의: 플러그인을 제거하기 전에 제출 이력, 점수, 랭킹 관련 데이터의 보존·백업 정책을 검토하세요. 플러그인 제거는 새 코드의 로드를 중지하지만, 이미 데이터베이스에 저장된 데이터의 삭제 여부는 마이그레이션과 운영 정책에 따라 별도로 판단해야 합니다.

## 문제 해결

### 빌드에서 Git clone이 실패하는 경우

```bash
getent hosts github.com
curl -I https://github.com
```

- GitHub 네트워크 접근이 가능한지 확인합니다.
- private 저장소라면 안전한 인증 수단을 구성합니다.
- 저장소 URL의 대소문자·철자가 맞는지 확인합니다.

### `destination path ... already exists` 오류

동일 clone hook이 `app.yml`에 중복됐을 가능성이 높습니다.

```bash
sudo grep -n -E 'discourse-autograder-plugin|discourse-autograder' \
  /var/discourse/containers/app.yml
```

같은 저장소를 clone하는 항목이 한 번만 남도록 정리한 뒤 재빌드합니다.

### `git checkout`이 실패하는 경우

- SHA가 존재하는지 GitHub에서 확인합니다.
- 40자리 SHA 전체를 정확히 사용합니다.
- copy/paste 과정에서 공백·줄바꿈이 들어가지 않았는지 확인합니다.

### 플러그인 설치 후 랭킹 페이지 또는 API가 404인 경우

- 재빌드 로그에 플러그인 로드 오류가 없는지 확인합니다.
- 컨테이너 내 플러그인 경로와 `plugin.rb` 존재 여부를 확인합니다.
- 배포한 커밋에 해당 라우트가 포함돼 있는지 확인합니다.
- Discourse 관리자 화면에서 플러그인 설정과 활성 상태를 확인합니다.

```bash
cd /var/discourse || exit 1
sudo ./launcher logs app
```

### 제출은 됐지만 자동채점되지 않는 경우

- 제출 파일이 CSV인지 확인합니다.
- CSV 열 이름, 행 수, ID 범위가 문제 요구 사항과 맞는지 확인합니다.
- Python 채점 서비스가 실행 중인지 확인합니다.
- Discourse 컨테이너에서 채점 API에 접근 가능한지 확인합니다.
- 비공개 정답 파일이 `topic_<TOPIC_ID>.csv` 이름으로 존재하는지 확인합니다.
- 정답 파일의 파일 권한과 채점 서비스 계정의 읽기 권한을 확인합니다.

Python 서비스 로그 예시:

```bash
sudo systemctl status discourse-autograder.service --no-pager
sudo journalctl -u discourse-autograder.service -n 200 --no-pager
```

### 토픽을 다른 카테고리로 옮긴 뒤 랭킹이 이상한 경우

이 README의 기본 SHA는 랭킹 집계 시 제출 레코드의 과거 카테고리 값 대신, 연결된 토픽의 **현재 카테고리**를 조회하도록 수정한 버전입니다. 실제 배포 SHA가 `a58e75898eaba9ac272a56a530d94930c437ad93` 이상인지 확인하고 재빌드하세요.

### 재빌드 후 사이트가 시작되지 않는 경우

- 마지막으로 수정한 `app.yml` YAML 들여쓰기를 확인합니다.
- Git SHA와 clone 경로를 확인합니다.
- 직전 정상 `app.yml` 백업을 복원합니다.
- 다시 재빌드합니다.

## 보안 및 운영 원칙

- 운영 환경에서는 `main`이 아닌 검증된 commit SHA를 고정합니다.
- `app.yml`을 수정하기 전에 항상 백업합니다.
- 플러그인 업데이트는 스테이징 환경에서 먼저 검증합니다.
- 비공개 정답 CSV는 GitHub, Discourse 첨부파일, 공개 웹 경로에 올리지 않습니다.
- 정답 디렉터리는 `700`, 정답 파일은 `600` 권한을 권장합니다.
- GitHub token, deploy key, API key, webhook secret은 Git에 커밋하지 않습니다.
- 채점 API는 불필요하게 공용 인터넷에 노출하지 않습니다.
- 재빌드 전에 예상 중단 시간을 공지합니다.
- 배포 시각, 배포 SHA, 담당자, 롤백 SHA를 운영 기록에 남깁니다.

## 라이선스

이 저장소의 배포·재사용 정책은 `LICENSE` 파일로 명시하세요.
