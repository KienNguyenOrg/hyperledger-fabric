-- Secure login query
DECLARE
    v_username VARCHAR2(100) := 'admin';
    v_password VARCHAR2(100) := 'secret123';
    v_count NUMBER;
BEGIN
    EXECUTE IMMEDIATE
        'SELECT COUNT(*) FROM users
         WHERE username = :username
         AND password = :password'
    INTO v_count
    USING v_username, v_password;

    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Login successful');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Login failed');
    END IF;
END;
/