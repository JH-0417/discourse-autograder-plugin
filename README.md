# Discourse Auto Grader

CSV 제출물을 자동 채점하고, 제출 이력·개인 랭킹·팀 랭킹을 제공하는 Discourse 플러그인입니다.

## 검증 환경

- Discourse: `2026.8.0-latest.1`
- Plugin: `0.1`
- Ruby/Rails: Discourse 기본 환경
- 외부 채점 서버: Python, FastAPI, Uvicorn
- 채점 서버 예시 포트: `8000`

## 기능

- 지정 카테고리의 댓글에 첨부된 CSV 파일 자동 감지
- 백그라운드 job을 통한 외부 채점 서버 요청
- AUC, Precision, Brier score, 종합 점수 저장
- 제출 댓글 아래 자동채점 결과 댓글 작성
- 동일 사용자·동일 문제에서 최고 점수 기준 랭킹 계산
- 개인 랭킹 및 팀(Affiliation) 랭킹 제공
- 비로그인 사용자를 포함한 공개 랭킹 페이지 제공
- Discourse Gamification 점수 동기화

## 구성

이 프로젝트는 Discourse 플러그인입니다. CSV 점수를 계산하는 Python 채점 서버는 별도로 실행해야 합니다.

```text
Discourse 플러그인
  └─ CSV 댓글 감지, 제출 저장, 채점 요청, 결과·랭킹 표시

Python 채점 서버
  └─ CSV 다운로드, 정답 파일 비교, 점수 계산, JSON 응답
```

## 플러그인 설치

Self-hosted Discourse 서버에서 `containers/app.yml`의 `hooks.after_code`에 아래 내용을 추가합니다.

```yaml
- exec:
    cd: $home/plugins
    cmd:
      - git clone https://github.com/JH-0417/discourse-autograder-plugin.git discourse-autograder
```

특정 검증 버전을 고정하려면 clone 명령 뒤에 commit checkout을 추가합니다.

```yaml
- exec:
    cd: $home/plugins
    cmd:
      - git clone https://github.com/JH-0417/discourse-autograder-plugin.git discourse-autograder && cd discourse-autograder && git checkout COMMIT_SHA
```

그 후 Discourse를 rebuild합니다.

```bash
cd /var/discourse
./launcher rebuild app
```

설치가 끝나면 관리자 계정으로 `/admin/plugins`에서 `discourse-autograder`를 확인합니다.

## Site Settings

관리자 화면의 `/admin/site_settings`에서 `autograder`를 검색해 아래 값을 설정합니다.

| 설정 키 | 설명 |
|---|---|
| `autograder_enabled` | 자동채점 기능 활성화 여부 |
| `autograder_liver_category_id` | 첫 번째 채점 카테고리 ID |
| `autograder_lung_category_id` | 두 번째 채점 카테고리 ID |
| `autograder_dual_participation_bonus` | 두 카테고리 참여 보너스 점수 |
| `autograder_grader_url` | 외부 채점 서버의 전체 POST URL |

`autograder_grader_url`에는 경로까지 포함한 전체 주소를 입력해야 합니다.

```text
http://채점서버주소:8000/grade-submission
```

## 외부 채점 서버 API

플러그인은 `autograder_grader_url`에 JSON POST 요청을 보냅니다.

```json
{
  "post": {
    "id": 46,
    "topic_id": 16,
    "user_id": 1,
    "post_number": 14,
    "cooked": "CSV 첨부파일을 포함한 Discourse HTML"
  }
}
```

채점 서버는 성공 시 아래 형식의 JSON을 반환해야 합니다.

```json
{
  "status": "채점 완료",
  "auc": 0.8333,
  "precision": 0.7500,
  "brier": 0.1987,
  "final_score": 0.7949
}
```

## 사용 방법

1. 관리자 Site Settings에서 채점 대상 카테고리 ID와 채점 서버 URL을 설정합니다.
2. 사용자가 대상 카테고리의 문제 토픽에 CSV 파일을 새 댓글로 첨부합니다.
3. 플러그인이 제출을 생성하고 채점 서버에 요청합니다.
4. 채점 완료 후 제출 댓글 아래에 결과 댓글이 작성됩니다.
5. `/autograder/rankings`에서 개인·팀 랭킹을 확인합니다.

## 운영 주의사항

- 채점 서버는 Discourse와 별도로 실행해야 합니다.
- 채점 서버 주소, 포트, Discourse API Key는 코드에 하드코딩하지 않습니다.
- `.env` 파일에는 실제 API Key나 토큰을 저장하고 Git에 올리지 않습니다.
- `.env.example`에는 변수 이름만 기록합니다.
- DB 변경은 반드시 `db/migrate` migration으로 추가합니다.
- 운영 업데이트 전 staging 환경에서 설치·CSV 제출·랭킹을 검증합니다.
- 플러그인 업데이트는 Git commit을 고정한 뒤 `app.yml`을 갱신하고 rebuild합니다.

## 개발 및 테스트

```bash
git clone https://github.com/JH-0417/discourse-autograder-plugin.git
cd discourse-autograder-plugin
```

새 Discourse 환경에서 플러그인을 설치한 뒤 다음을 확인합니다.

1. Migration이 정상 적용되는지
2. Site Settings가 표시되는지
3. 대상 카테고리 CSV 댓글이 제출로 등록되는지
4. 외부 채점 서버 요청 및 결과 저장이 되는지
5. 자동채점 결과 댓글이 작성되는지
6. 개인·팀 랭킹이 표시되는지
7. 비로그인 상태에서 `/autograder/rankings`가 열리는지

## 라이선스

배포 전 프로젝트 라이선스를 결정해 여기에 명시합니다.
