

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON

DECLARE
    v_total_ids       NUMBER;
    v_parallel_max    NUMBER;
    v_parallel_degree NUMBER := 0;
    v_estimated_gb    NUMBER;

    v_start_time      NUMBER;
    v_elapsed_sec     NUMBER;
    v_inserted        NUMBER;

BEGIN

    /* Number of IDs to process */
    SELECT COUNT(*)
    INTO v_total_ids
    FROM system.gg_discard_ids;

    /*
       Get Oracle's configured maximum parallel servers.
       If NULL, use a conservative default.
    */
    SELECT NVL(value, 0)
    INTO v_parallel_max
    FROM v$parameter
    WHERE name = 'parallel_max_servers';

    /*
       Estimate source size.

       Replace 5000 with your estimated average row size
       in bytes if you know it more accurately.

       Example:
       5000 bytes/row = approximately 1 GB for 193K rows.
    */
    v_estimated_gb :=
        (v_total_ids * 5000) / 1024 / 1024 / 1024;

    /*
       Automatically choose degree.
    */

    IF v_estimated_gb < 1 THEN

        v_parallel_degree := 0;

    ELSIF v_estimated_gb < 5 THEN

        v_parallel_degree := LEAST(2, FLOOR(v_parallel_max / 2));

    ELSIF v_estimated_gb < 20 THEN

        v_parallel_degree := LEAST(4, FLOOR(v_parallel_max / 2));

    ELSIF v_estimated_gb < 50 THEN

        v_parallel_degree := LEAST(8, FLOOR(v_parallel_max / 2));

    ELSE

        v_parallel_degree := LEAST(
            16,
            FLOOR(v_parallel_max / 2)
        );

    END IF;

    /* Don't use parallel if Oracle doesn't have enough servers */

    IF v_parallel_degree < 2 THEN
        v_parallel_degree := 0;
    END IF;


    DBMS_OUTPUT.PUT_LINE('==========================================');
    DBMS_OUTPUT.PUT_LINE('GoldenGate Missing Row Restore');
    DBMS_OUTPUT.PUT_LINE('==========================================');
    DBMS_OUTPUT.PUT_LINE('IDs to process       : ' || v_total_ids);
    DBMS_OUTPUT.PUT_LINE(
        'Estimated data size  : ' ||
        TO_CHAR(v_estimated_gb, '990.00') || ' GB'
    );
    DBMS_OUTPUT.PUT_LINE(
        'parallel_max_servers : ' ||
        v_parallel_max
    );

    IF v_parallel_degree = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Parallel degree      : SERIAL');
    ELSE
        DBMS_OUTPUT.PUT_LINE(
            'Parallel degree      : ' ||
            v_parallel_degree
        );
    END IF;

    DBMS_OUTPUT.PUT_LINE('==========================================');


    v_start_time := DBMS_UTILITY.GET_TIME;


    IF v_parallel_degree = 0 THEN

        INSERT INTO schema.table
        SELECT s.*
        FROM schema.table@bil20 s
        JOIN system.gg_discard_ids d
          ON d.id = s.keyid
        WHERE NOT EXISTS (
            SELECT 1
            FROM schema.table t
            WHERE t.keyid = s.keyid
        );

    ELSE

        EXECUTE IMMEDIATE
            'ALTER SESSION ENABLE PARALLEL DML';

        EXECUTE IMMEDIATE
            'INSERT /*+ APPEND PARALLEL(' ||
            v_parallel_degree ||
            ') */ INTO schema.table
             SELECT /*+ PARALLEL(s,' ||
            v_parallel_degree ||
            ') */
                    s.*
             FROM schema.table@bil20 s
             JOIN system.gg_discard_ids d
               ON d.id = s.keyid
             WHERE NOT EXISTS (
                 SELECT 1
                 FROM schema.table t
                 WHERE t.keyid =
                       s.keyid
             )';

    END IF;


    v_inserted := SQL%ROWCOUNT;

    COMMIT;


    v_elapsed_sec :=
        (DBMS_UTILITY.GET_TIME - v_start_time) / 100;


    DBMS_OUTPUT.PUT_LINE('==========================================');
    DBMS_OUTPUT.PUT_LINE('Completed');
    DBMS_OUTPUT.PUT_LINE('Rows inserted : ' || v_inserted);
    DBMS_OUTPUT.PUT_LINE(
        'Elapsed       : ' ||
        TRUNC(v_elapsed_sec / 3600) || 'h ' ||
        TRUNC(MOD(v_elapsed_sec,3600) / 60) || 'm ' ||
        TRUNC(MOD(v_elapsed_sec,60)) || 's'
    );

    IF v_elapsed_sec > 0 THEN
        DBMS_OUTPUT.PUT_LINE(
            'Rows/sec      : ' ||
            TO_CHAR(
                v_inserted / v_elapsed_sec,
                '9999990.00'
            )
        );
    END IF;

    DBMS_OUTPUT.PUT_LINE('==========================================');

END;
/
