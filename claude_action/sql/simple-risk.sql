-- Insecure login query (DO NOT USE)
DECLARE
    v_username VARCHAR2(100) := 'admin';
    v_password VARCHAR2(100) := ''' OR ''1''=''1';
    v_count NUMBER;
BEGIN
    EXECUTE IMMEDIATE
        'SELECT COUNT(*) FROM users 
         WHERE username = ''' || v_username || '''
         AND password = ''' || v_password || ''''
    INTO v_count;

    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Login successful');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Login failed');
    END IF;
END;
/