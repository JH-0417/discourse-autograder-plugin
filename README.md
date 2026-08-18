discourse-autograder-plugin/
├── plugin.rb
├── app/
├── config/
├── db/
├── lib/
├── assets/
└── README.md

| 위치                  | 들어 있는 것                        | 역할                                                         |
| ------------------- | ------------------------------ | ---------------------------------------------------------- |
| plugin.rb           | 플러그인 시작 코드                     | Discourse가 플러그인을 로드할 때 실행됩니다. CSV 답글 게시 이벤트도 여기서 감지합니다     |
| app/models/         | AutograderSubmission 등         | 제출 기록, 점수, 처리 상태를 Discourse DB에 저장합니다                      |
| app/jobs/regular/   | autograder_grade_submission.rb | Python 채점 서버에 요청을 보내는 백그라운드 작업입니다                          |
| app/controllers/    | 리더보드 컨트롤러                      | 순위 페이지 요청을 처리합니다                                           |
| app/views/          | 리더보드 화면                        | 개인·팀 점수표 HTML 화면을 만듭니다                                     |
| config/settings.yml | 관리자 설정 정의                      | 활성화 여부, 대상 카테고리, 채점 URL, 인증 토큰을 설정합니다                      |
| config/routes.rb    | URL 경로 설정                      | /autograder/rankings, /autograder/leaderboard 같은 주소를 추가합니다 |
| db/migrate/         | DB 생성·변경 명령                    | 제출 기록과 게임화 동기화 테이블을 만듭니다                                   |
| lib/autograder/     | 핵심 Ruby 로직                     | 리더보드 계산, 게임화 점수 동기화, 플러그인 엔진 설정을 처리합니다                     |
| assets/             | 화면용 JavaScript·스타일             | Discourse 화면 메뉴나 링크 같은 프런트엔드 요소를 추가합니다                     |
| README.md           | 사용 설명서                         | 현재 비어 있으므로, 나중에 설치·설정·테스트 방법을 문서화하는 것이 좋습니다                |
