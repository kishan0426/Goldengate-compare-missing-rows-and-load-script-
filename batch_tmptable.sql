CREATE TABLE system.gg_discard_batches AS
SELECT id,
       CEIL(ROW_NUMBER() OVER (ORDER BY id) / 5000) batch_no
FROM system.gg_discard_ids;

CREATE INDEX system.ix_gg_discard_batches
ON system.gg_discard_batches(batch_no, id);
