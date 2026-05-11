-- Tags: no-fasttest, no-ordinary-database, no-parallel-replicas

SET enable_analyzer = 1;
SET parallel_replicas_local_plan = 1;
SET optimize_move_to_prewhere = 1;
SET query_plan_optimize_prewhere = 1;

DROP TABLE IF EXISTS tab_prefilter_no_ann;
DROP TABLE IF EXISTS tab_prefilter_no_ann_marker;

CREATE TABLE tab_prefilter_no_ann
(
    id Int32,
    attr Int32,
    vec Array(Float32),
    INDEX idx_vec vec TYPE vector_similarity('hnsw', 'L2Distance', 2)
)
ENGINE = MergeTree
ORDER BY id
SETTINGS index_granularity = 2;

CREATE TABLE tab_prefilter_no_ann_marker
(
    ts DateTime64(6)
)
ENGINE = Memory;

INSERT INTO tab_prefilter_no_ann VALUES
    (0, 0, [0.0, 0.0]),
    (1, 0, [1.0, 0.0]),
    (2, 0, [2.0, 0.0]),
    (3, 1, [3.0, 0.0]),
    (4, 1, [4.0, 0.0]),
    (5, 1, [5.0, 0.0]);

INSERT INTO tab_prefilter_no_ann_marker SELECT now64(6);

SELECT 'prefilter with additional filters returns exact filtered neighbours';
SELECT id
FROM tab_prefilter_no_ann
WHERE attr = 1
ORDER BY L2Distance(vec, [0.0, 0.0])
LIMIT 2
SETTINGS vector_search_filter_strategy = 'prefilter',
         log_comment = '04212_vector_search_prefilter_no_ann_search';

SYSTEM FLUSH LOGS query_log;

SELECT 'prefilter with additional filters does not call USearch';
SELECT sum(ProfileEvents['USearchSearchCount'])
FROM system.query_log
WHERE event_date >= yesterday()
  AND event_time >= now() - 600
  AND event_time_microseconds >= (SELECT min(ts) FROM tab_prefilter_no_ann_marker)
  AND current_database = currentDatabase()
  AND type = 'QueryFinish'
  AND log_comment = '04212_vector_search_prefilter_no_ann_search';

DROP TABLE tab_prefilter_no_ann;
DROP TABLE tab_prefilter_no_ann_marker;
