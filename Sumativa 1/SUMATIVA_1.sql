/* ============================================================
   ACTIVIDAD SUMATIVA
   ============================================================ */

VAR b_fecha_proceso VARCHAR2(14);
EXEC :b_fecha_proceso := TO_CHAR(SYSDATE,'YYYYMMDDHH24MISS');

DECLARE
  /* ------------------------------------------------------------
     Fecha de proceso usando BIND
     ------------------------------------------------------------ */
    v_fecha_proceso   DATE := TO_DATE (:b_fecha_proceso, 'YYYYMMDDHH24MISS');

  /* ------------------------------------------------------------
     Variables %TYPE
     ------------------------------------------------------------ */
    v_id_emp          empleado.id_emp%TYPE;
    v_numrun_emp      empleado.numrun_emp%TYPE;
    v_dvrun_emp       empleado.dvrun_emp%TYPE;
    v_pnombre_emp     empleado.pnombre_emp%TYPE;
    v_snombre_emp     empleado.snombre_emp%TYPE;
    v_appat_emp       empleado.appaterno_emp%TYPE;
    v_apmat_emp       empleado.apmaterno_emp%TYPE;
    v_fecha_nac       empleado.fecha_nac%TYPE;
    v_fecha_cont      empleado.fecha_contrato%TYPE;
    v_sueldo_base     empleado.sueldo_base%TYPE;
    v_estado_civil    estado_civil.nombre_estado_civil%TYPE;
    v_nombre_empleado usuario_clave.nombre_empleado%TYPE;
    v_nombre_usuario  usuario_clave.nombre_usuario%TYPE;
    v_clave_usuario   usuario_clave.clave_usuario%TYPE;

  /* Auxiliares */
    v_run_str         VARCHAR2(20);
    v_anos_trabajados NUMBER(4);
    v_tercer_dig_run  VARCHAR2(1);
    v_anio_nac_mas2   VARCHAR2(4);
    v_ult3_sueldo     NUMBER(3);
    v_ult3_sueldo_str VARCHAR2(3);
    v_dos_letras_ap   VARCHAR2(2);
    v_mm_yyyy         VARCHAR2(6);

  /* Control transaccional */
    v_total_empleados NUMBER := 0;
    v_contador_ok     NUMBER := 0;

  /* Cursor con datos base */
    CURSOR c_emp IS
    SELECT
        e.id_emp,
        e.numrun_emp,
        e.dvrun_emp,
        e.appaterno_emp,
        e.apmaterno_emp,
        e.pnombre_emp,
        e.snombre_emp,
        e.fecha_nac,
        e.fecha_contrato,
        e.sueldo_base,
        ec.nombre_estado_civil
    FROM
        empleado e
        JOIN estado_civil ec ON ec.id_estado_civil = e.id_estado_civil
    WHERE
        e.id_emp BETWEEN 100 AND 320
    ORDER BY
        e.id_emp;

BEGIN
  /* Si por alguna razón viene NULL, cae a SYSDATE */
    IF v_fecha_proceso IS NULL THEN
        v_fecha_proceso := SYSDATE;
    END IF;

  /*TRUNCATE para re-ejecución */
    EXECUTE IMMEDIATE 'TRUNCATE TABLE USUARIO_CLAVE';

  /* Total de empleados esperados */
    SELECT
        COUNT(*)
    INTO v_total_empleados
    FROM
        empleado
    WHERE
        id_emp BETWEEN 100 AND 320;

  /* Iteración por todos los empleados */
    FOR r IN c_emp LOOP
        v_id_emp := r.id_emp;
        v_numrun_emp := r.numrun_emp;
        v_dvrun_emp := r.dvrun_emp;
        v_appat_emp := r.appaterno_emp;
        v_apmat_emp := r.apmaterno_emp;
        v_pnombre_emp := r.pnombre_emp;
        v_snombre_emp := r.snombre_emp;
        v_fecha_nac := r.fecha_nac;
        v_fecha_cont := r.fecha_contrato;
        v_sueldo_base := r.sueldo_base;
        v_estado_civil := r.nombre_estado_civil;

    /* Nombre completo */
        v_nombre_empleado := RTRIM(v_pnombre_emp || ' ' || NVL(v_snombre_emp || ' ', '') || v_appat_emp || ' ' || v_apmat_emp);

    /* Años trabajando */
        v_anos_trabajados := TRUNC(MONTHS_BETWEEN(v_fecha_proceso, v_fecha_cont) / 12);

    /* 3er dígito del RUN */
        v_run_str := TO_CHAR(v_numrun_emp);
        v_tercer_dig_run := SUBSTR(LPAD(v_run_str, 3, '0'), 3, 1);

    /* Año nacimiento + 2 */
        v_anio_nac_mas2 := TO_CHAR(EXTRACT(YEAR FROM v_fecha_nac) + 2);

    /* Últimos 3 dígitos sueldo - 1
        - Primero obtiene el modulo de la division del sueldo base menos 1 entre 1000 lo que da los ultimos 3 numeros, luego si ese numero es de menos de 3 digitos rellena con 0s los digitos faltantes    
    */
        v_ult3_sueldo := MOD(ROUND(v_sueldo_base) -1, 1000);
        v_ult3_sueldo_str := LPAD(TO_CHAR(v_ult3_sueldo), 3, '0');

    /* 2 letras del apellido paterno según estado civil */
        IF v_estado_civil IN ('CASADO', 'ACUERDO DE UNION CIVIL') 
        THEN
            v_dos_letras_ap := LOWER(SUBSTR(v_appat_emp, 1, 2));
        ELSIF v_estado_civil IN ('DIVORCIADO', 'SOLTERO') 
        THEN
            v_dos_letras_ap := LOWER(SUBSTR(v_appat_emp, 1, 1) || SUBSTR(v_appat_emp, -1, 1));
        ELSIF v_estado_civil = 'VIUDO' 
        THEN
            v_dos_letras_ap := LOWER(SUBSTR(v_appat_emp, -3, 1) || substr(v_appat_emp, -2, 1));
        ELSIF v_estado_civil = 'SEPARADO'
        THEN
            v_dos_letras_ap := LOWER(SUBSTR(v_appat_emp, -2, 2));
        END IF;


    /* Mes y año (MMYYYY) */
        v_mm_yyyy := TO_CHAR(v_fecha_proceso, 'MMYYYY');

    /* NOMBRE_USUARIO */
        v_nombre_usuario :=
        
        /* La primera letra de su estado civil en minúscula */
        LOWER(SUBSTR(v_estado_civil, 1, 1))
                            ||
         /* b)	Las tres primeras letras del primer nombre del empleado */
        SUBSTR(v_pnombre_emp, 1, 3)
                            ||
        /* c)	El largo de su primer nombre */
        LENGTH(v_pnombre_emp)
                            ||
        /* d)	Un ASTERISCO */
        '*'
                            ||
        /* e)	El último dígito de su sueldo base */ 
        SUBSTR(TO_CHAR(v_sueldo_base), -1, 1)
                            ||
        /* f)	El dígito verificador del run del empleado */
        v_dvrun_emp
                            ||
        /* g)	Los años que lleva trabajando en la empresa */
        TO_CHAR(v_anos_trabajados);
      
        /* h)	Si el empleado lleva menos de 10 años trabajando en TRUCK RENTAL, se agrega además una X*/
        IF v_anos_trabajados < 10 
        THEN
            v_nombre_usuario := v_nombre_usuario || 'X';
        END IF;

    /* CLAVE_USUARIO */
        v_clave_usuario := v_tercer_dig_run || v_anio_nac_mas2 || v_ult3_sueldo_str || v_dos_letras_ap || to_char(v_id_emp) || v_mm_yyyy;

    /* INSERT en tabla USUARIO_CLAVE */
        INSERT INTO usuario_clave (
            id_emp,
            numrun_emp,
            dvrun_emp,
            nombre_empleado,
            nombre_usuario,
            clave_usuario
        ) VALUES ( v_id_emp,
                   v_numrun_emp,
                   v_dvrun_emp,
                   v_nombre_empleado,
                   v_nombre_usuario,
                   v_clave_usuario );

        v_contador_ok := v_contador_ok + 1;
    END LOOP;

  /* Commit solo si procesó todo */
    IF v_contador_ok = v_total_empleados THEN
        COMMIT;
    ELSE
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20001, 'Proceso incompleto (' || v_contador_ok ||'/'|| v_total_empleados || ')');
    END IF;
END;
/

SELECT * FROM usuario_clave ORDER BY id_emp;