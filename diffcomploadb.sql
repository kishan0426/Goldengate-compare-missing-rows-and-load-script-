SET SERVEROUTPUT ON
SET TIMING ON

DECLARE
    v_batch     NUMBER;
    v_max_batch NUMBER;
    v_count     NUMBER;
BEGIN

    SELECT MAX(batch_no)
    INTO v_max_batch
    FROM system.gg_discard_batches;

    FOR v_batch IN 1 .. v_max_batch LOOP

        INSERT INTO schema.table
        SELECT s.*
        FROM schema.table@dblnk s
        JOIN system.gg_discard_batches d
          ON d.id = s.dtid
        WHERE d.batch_no = v_batch;

        v_count := SQL%ROWCOUNT;

        COMMIT;

        DBMS_OUTPUT.PUT_LINE(
            'Batch ' || v_batch ||
            '/' || v_max_batch ||
            ' : ' || v_count || ' rows inserted'
        );

    END LOOP;

END;
/
