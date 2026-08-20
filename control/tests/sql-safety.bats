#!/usr/bin/env bats
# sql-safety-check.sh：语句级判定，注释和字符串不参与匹配

load test_helper

setup() {
  SQL_FILE="$BATS_TEST_TMPDIR/test.sql"
}

check() {
  run bash "$SCRIPTS_DIR/sql-safety-check.sh" "$SQL_FILE"
}

@test "合法 SQL 通过" {
  cat > "$SQL_FILE" <<'SQL'
SELECT id, name FROM t_user WHERE tenant_id = 1 AND is_deleted = 0;
UPDATE t_user SET name = 'a' WHERE id = 1;
DELETE FROM t_user WHERE id = 1;
SELECT COUNT(*) FROM t_user WHERE tenant_id = 1;
SQL
  check
  [ "$status" -eq 0 ]
}

@test "跨行的无 WHERE DELETE 被检出" {
  cat > "$SQL_FILE" <<'SQL'
DELETE FROM
  t_user
;
SQL
  check
  [ "$status" -eq 2 ]
  grep -qi 'delete' <<<"$output"
}

@test "跨行的无 WHERE UPDATE 被检出" {
  cat > "$SQL_FILE" <<'SQL'
UPDATE t_user
SET name = 'x',
    status = 1;
SQL
  check
  [ "$status" -eq 2 ]
}

@test "带 WHERE 的 UPDATE 不误报" {
  cat > "$SQL_FILE" <<'SQL'
UPDATE t_user
SET name = 'x'
WHERE id = 1;
SQL
  check
  [ "$status" -eq 0 ]
}

@test "注释中的 SELECT * 不误报" {
  cat > "$SQL_FILE" <<'SQL'
-- 注意：禁止 SELECT * 和 DELETE FROM t;
/* select * from anywhere */
SELECT id FROM t_user WHERE id = 1;
SQL
  check
  [ "$status" -eq 0 ]
}

@test "字符串字面量中的危险词不误报" {
  cat > "$SQL_FILE" <<'SQL'
INSERT INTO t_log (msg) VALUES ('drop table warning: select * detected');
SQL
  check
  [ "$status" -eq 0 ]
}

@test "SELECT * 被检出而 COUNT(*) 放行" {
  cat > "$SQL_FILE" <<'SQL'
SELECT * FROM t_user WHERE id = 1;
SQL
  check
  [ "$status" -eq 2 ]
  grep -qi 'SELECT \*' <<<"$output"
}

@test "无 ON 条件的 JOIN 被检出" {
  cat > "$SQL_FILE" <<'SQL'
SELECT a.id, b.name FROM t_a a JOIN t_b b WHERE a.id = 1;
SQL
  check
  [ "$status" -eq 2 ]
  grep -qi 'join' <<<"$output"
}

@test "带 ON 的 JOIN 不误报" {
  cat > "$SQL_FILE" <<'SQL'
SELECT a.id, b.name FROM t_a a
JOIN t_b b ON a.id = b.a_id
LEFT JOIN t_c c ON c.b_id = b.id
WHERE a.tenant_id = 1;
SQL
  check
  [ "$status" -eq 0 ]
}

@test "DROP 和 TRUNCATE 被检出" {
  cat > "$SQL_FILE" <<'SQL'
DROP TABLE t_old;
SQL
  check
  [ "$status" -eq 2 ]

  cat > "$SQL_FILE" <<'SQL'
TRUNCATE TABLE t_old;
SQL
  check
  [ "$status" -eq 2 ]
}

@test "ALTER TABLE DROP COLUMN 被检出" {
  cat > "$SQL_FILE" <<'SQL'
ALTER TABLE t_user DROP COLUMN legacy_field;
SQL
  check
  [ "$status" -eq 2 ]
}

@test "报错信息带语句行号" {
  cat > "$SQL_FILE" <<'SQL'
SELECT id FROM t_user WHERE id = 1;
SELECT * FROM t_user WHERE id = 2;
SQL
  check
  [ "$status" -eq 2 ]
  grep -q 'line 2' <<<"$output"
}
