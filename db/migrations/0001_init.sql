-- Aurora PostgreSQL 초기 스키마 (초안)
-- 가정: 대화방은 유저 × 캐릭터당 1개. 키는 앱에서 생성한 UUIDv7. 시퀀스/트리거 미사용.

CREATE TABLE conversations (
  conversation_id  uuid        PRIMARY KEY,
  user_id          bigint      NOT NULL,
  character_id     int         NOT NULL,
  persona_version  int         NOT NULL,
  last_seq         bigint      NOT NULL DEFAULT 0,
  last_message_at  timestamptz,
  summary          text,
  summary_upto_seq bigint      NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, character_id)
);

CREATE INDEX idx_conv_user_recent ON conversations (user_id, last_message_at DESC);

CREATE TABLE messages (
  conversation_id  uuid        NOT NULL,
  seq              bigint      NOT NULL,
  role             text        NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content          text        NOT NULL,
  client_msg_id    uuid,                       -- 멱등 키 (user 메시지)
  reply_to_seq     bigint,
  status           text        NOT NULL DEFAULT 'ok' CHECK (status IN ('ok', 'fallback', 'failed')),
  model            text,
  tokens_in        int,
  tokens_out       int,
  created_at       timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (conversation_id, seq),
  UNIQUE (conversation_id, client_msg_id)
);
