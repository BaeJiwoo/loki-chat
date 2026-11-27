# AGENTS.md — loki-chat

게임 내 AI 캐릭터 챗 마이크로서비스. 이 파일은 이 저장소에서 작업하는 에이전트(Codex 등)의 기준 문서다.
설계 결정은 여기 적힌 것이 우선이며, 바꿔야 하면 PR 설명에 이유를 쓰고 이 파일도 함께 고친다.

## 1. 요구사항 (변경 불가)

1. 유저별 대화 이력을 조회할 수 있어야 한다.
2. 유저는 100시간 뒤에 답장하거나 게임을 껐다 켜고 이어서 대화할 수 있다.
3. AI 응답은 2초 이내여야 한다. (기준: 첫 토큰(TTFT) 2초 — 미확정, 응답 완료 기준으로 바뀔 수 있음)
4. DBMS(컴퓨트)와 스토리지 엔진이 분리된 DB를 쓴다 → Aurora PostgreSQL.

## 2. 결정 사항

| 항목 | 결정 |
| --- | --- |
| 운영 환경 | AWS 서울(ap-northeast-2), EKS 3 AZ |
| 진입 | Route 53 → WAF + ALB (least outstanding requests, `target-type: ip`), sticky session 없음 |
| DB | Aurora PostgreSQL (Writer 1 + Reader 1). 진실의 원천 |
| 캐시 | ElastiCache (Valkey), 최근 16턴 + 요약, TTL 48h. 유실돼도 DB에서 재구성 |
| 큐 | SQS FIFO, `MessageGroupId = conversation_id` |
| LLM | 오픈 모델 자체 서빙: vLLM on EKS GPU(G6e/G7e), OpenAI 호환 API, prefix caching |
| 스케일링 | KEDA(Pod), Karpenter(노드) |
| 규모 | DAU 10만, 피크 LLM 약 100 req/s (가정치) |
| 로컬 개발 | kind/k3d + PostgreSQL + Redis + LocalStack(SQS) + mock LLM |

## 3. 아키텍처

```
Game client → Route53/WAF/ALB → chat-api ──┬─> llm-router → llm-server (vLLM, GPU)
                                           ├─> ElastiCache (hot context)
                                           ├─> Aurora (user msg 동기 저장, 캐시 미스 시 컨텍스트 로드)
                                           └─> SQS FIFO → chat-worker → Aurora (AI 응답 저장, 롤링 요약)
```

- `chat-api`: 실시간 경로. 무상태. 2초 예산이 걸린 유일한 경로.
- `chat-worker`: 비동기 경로. 응답 저장, N턴마다 요약 갱신, 캐시 갱신.
- `llm-server`: vLLM. 0으로 스케일 다운 금지(콜드 스타트 수 분).

## 4. 핵심 규칙 (위반 금지)

- Pod에 대화 상태를 두지 않는다. 어떤 Pod가 어떤 요청을 받아도 동작해야 한다.
- 유저 메시지는 LLM 호출 **전에** Aurora에 동기 저장한다.
- 메시지 순서는 `conversations.last_seq`로 매긴다. 유저 메시지 수신 시 한 트랜잭션에서 `last_seq += 2` → n(유저), n+1(AI 응답 예약).
- `client_msg_id`(UUID)는 멱등 키다. 중복이면 LLM을 다시 부르지 않고 기존 응답을 돌려준다.
- LLM 첫 토큰 타임아웃 1.8초. 초과 시 캐릭터 폴백 대사를 먼저 보내고 응답은 나중에 전달(`status='fallback'`).
- 프롬프트 = [고정 페르소나 prefix] + [요약] + [최근 16턴] + [유저 입력]. 페르소나를 맨 앞에 고정해 prefix cache 적중률을 지킨다.
- liveness는 프로세스 생존만 본다. DB/LLM 의존성은 readiness에만.
- 키는 UUID(앱에서 UUIDv7 생성). DB 시퀀스·트리거에 의존하지 않는다(향후 Aurora DSQL 이전 대비).
- 비밀값은 커밋 금지. AWS는 Secrets Manager + External Secrets, 로컬은 `.env`(gitignore).

## 5. 저장소 구조

```
AGENTS.md               이 파일
docs/backlog.md         책임 영역별 작업 목록 (작업하면 체크하고 갱신)
db/migrations/          Aurora PostgreSQL 마이그레이션 (번호 순)
k8s/base/               chat-api, chat-worker, llm-server 매니페스트
k8s/overlays/local/     로컬(kind) 오버레이
k8s/overlays/aws/       EKS 오버레이
services/               (생성 예정) chat-api, chat-worker 소스
infra/                  (생성 예정) Terraform
```

## 6. 책임 영역

작업 요청은 영역 하나에 한정한다. 영역 경계를 넘는 변경은 PR을 나눈다.

| 영역 | 태그 | 범위 |
| --- | --- | --- |
| 인프라·플랫폼 | `[infra]` | `infra/`, `k8s/`, VPC, EKS, Karpenter, ALB/WAF, KEDA, CI/CD |
| 데이터 | `[data]` | `db/`, Aurora, ElastiCache, SQS, S3 아카이브, 백업 |
| LLM 서빙 | `[llm]` | `llm-server`, 라우터, 모델 선정, 부하 테스트 |
| 앱 서버 | `[app]` | `services/chat-api`, `services/chat-worker` |
| 클라이언트 연동·관측 | `[client]` | 게임 클라이언트 API/스트리밍, 재접속 동기화, 모니터링 |

## 7. 작업 방식

- Slack 스레드 하나 = 백로그 항목 하나(`docs/backlog.md`의 ID, 예: `APP-03`).
- 작업 후 PR 설명에: 무엇을 했는지, 테스트 방법, 이 파일의 규칙과 충돌한 부분.
- 끝나면 `docs/backlog.md`의 해당 항목을 체크하고, 새로 발견한 작업은 같은 영역에 추가한다.
- 언어: 문서와 PR 설명은 한국어, 코드 식별자는 영어.
- 미결정 사항(아래)에 걸리는 작업은 가정을 PR에 명시하고 진행한다.

## 8. 미결정 사항

- 대화방 단위: 유저 × 캐릭터당 1개(현재 가정) vs 여러 개
- "2초" 기준: TTFT(현재 가정) vs 응답 완료
- 모델 크기: 8B급(현재 가정) vs 14B급, 파인튜닝 여부
- 앱 서버 언어/프레임워크 (미정 — APP-01에서 제안)
