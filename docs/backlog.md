# Backlog

ID 형식: `<영역>-<번호>`. Slack에서 `@Codex APP-01 진행해줘`처럼 ID로 지시한다.
완료 시 `[x]`로 바꾸고 PR 링크를 붙인다. 순서는 위에서부터 의존성 순.

## [data] 데이터

- [ ] DATA-01 `db/migrations/0001_init.sql` 검토 후 마이그레이션 도구 선정(sqlx/golang-migrate/Flyway 중) 및 적용 스크립트
- [ ] DATA-02 메시지 쓰기 트랜잭션 SQL: `last_seq += 2` 예약 + 유저 메시지 insert + `client_msg_id` 중복 처리
- [ ] DATA-03 컨텍스트 로드 쿼리(요약 + 최근 16턴), 이력 페이지네이션(`seq < cursor`), 재접속 동기화(`seq > last_seen`)
- [ ] DATA-04 캐시 키/포맷 정의(`conv:{conversation_id}`), write-through·무효화 규칙 문서화
- [ ] DATA-05 S3 아카이브(180일 경과 메시지 → Parquet) 배치 설계

## [app] 앱 서버

- [ ] APP-01 언어/프레임워크 제안(스트리밍·동시성 기준)과 `services/` 스캐폴딩
- [ ] APP-02 chat-api: `POST /conversations/{id}/messages` (SSE 스트리밍 응답), 멱등 처리
- [ ] APP-03 chat-api: 프롬프트 조립(페르소나 prefix 고정), LLM 호출, 1.8초 TTFT 타임아웃 + 폴백
- [ ] APP-04 chat-api: `GET /conversations/{id}/messages?before=&after=` 이력·동기화 API
- [ ] APP-05 chat-api: `/startup` `/ready` `/healthz` `/drain`, 동시 요청 상한(초과 시 503), Prometheus 메트릭
- [ ] APP-06 chat-worker: SQS FIFO 소비 → AI 응답 저장(예약 seq) → 캐시 갱신
- [ ] APP-07 chat-worker: N턴마다 롤링 요약 생성·저장
- [ ] APP-08 mock LLM 서버(OpenAI 호환, 고정 응답, 지연 주입 가능) — 로컬·테스트용

## [infra] 인프라·플랫폼

- [ ] INFRA-01 로컬: kind 클러스터 + PostgreSQL + Redis + LocalStack(SQS) + mock LLM, `make up` 한 번에 기동
- [ ] INFRA-02 `k8s/overlays/local` 완성(replicas 1, llm-server → mock 교체, 로컬 엔드포인트)
- [ ] INFRA-03 Service/Ingress(ALB)/PDB/KEDA ScaledObject 매니페스트 추가
- [ ] INFRA-04 Terraform: VPC 3 AZ, EKS, Karpenter(일반 + GPU NodePool)
- [ ] INFRA-05 Terraform: Aurora PostgreSQL, ElastiCache, SQS FIFO, S3, Secrets Manager
- [ ] INFRA-06 CI: 이미지 빌드 → ECR, 매니페스트 검증(kubeconform), CD는 Argo CD
- [ ] INFRA-07 비용 절감용 "축소 운영 프로필"(GPU 1장, Serverless v2 최소, 야간 정지)

## [llm] LLM 서빙

- [ ] LLM-01 후보 모델 비교표(한국어 캐릭터 연기 품질, 라이선스, 8B/14B)
- [ ] LLM-02 KV 캐시 인지 라우터(`llm-router`) 선정·매니페스트
- [ ] LLM-03 부하 테스트 스크립트(입력 1,500 / 출력 80 토큰, 목표 100 req/s) → GPU 장수 산정
- [ ] LLM-04 KEDA 스케일링(`vllm:num_requests_waiting`) + 피크 전 cron 스케일

## [client] 클라이언트 연동·관측

- [ ] CLIENT-01 클라이언트용 API 명세(OpenAPI), 스트리밍 방식(SSE vs WebSocket) 결정
- [ ] CLIENT-02 재접속 동기화 시나리오 테스트(앱 종료 중 응답 도착, 100시간 공백)
- [ ] CLIENT-03 대시보드·알림: TTFT p95, 폴백률, 캐시 적중률, SQS 적체, Aurora 지연
