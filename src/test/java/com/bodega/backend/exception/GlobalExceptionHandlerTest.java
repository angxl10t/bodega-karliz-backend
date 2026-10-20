package com.bodega.backend.exception;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.CannotAcquireLockException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.DisabledException;
import org.springframework.security.authentication.LockedException;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

public class GlobalExceptionHandlerTest {

    private GlobalExceptionHandler exceptionHandler;

    @BeforeEach
    void setUp() {
        exceptionHandler = new GlobalExceptionHandler();
    }

    @Test
    void testHandleDataIntegrityViolation_UniqueConstraint() {
        DataIntegrityViolationException ex = new DataIntegrityViolationException(
                "error", new RuntimeException("duplicate key value violates unique constraint")
        );

        ResponseEntity<Map<String, String>> response = exceptionHandler.handleDataIntegrityViolation(ex);

        assertNotNull(response);
        assertEquals(HttpStatus.CONFLICT, response.getStatusCode());
        assertTrue(response.getBody().get("error").contains("Ya existe un registro"));
    }

    @Test
    void testHandleDataIntegrityViolation_ForeignKeyConstraint() {
        DataIntegrityViolationException ex = new DataIntegrityViolationException(
                "error", new RuntimeException("violates foreign key constraint")
        );

        ResponseEntity<Map<String, String>> response = exceptionHandler.handleDataIntegrityViolation(ex);

        assertNotNull(response);
        assertEquals(HttpStatus.CONFLICT, response.getStatusCode());
        assertTrue(response.getBody().get("error").contains("está vinculado a otros datos"));
    }

    @Test
    void testHandleConcurrencyConflict() {
        CannotAcquireLockException ex = new CannotAcquireLockException("lock error");

        ResponseEntity<Map<String, String>> response = exceptionHandler.handleConcurrencyConflict(ex);

        assertNotNull(response);
        assertEquals(HttpStatus.CONFLICT, response.getStatusCode());
        assertTrue(response.getBody().get("error").contains("simultáneamente"));
    }

    @Test
    void testHandleRuntimeException_SanitizaTrazasSql() {
        RuntimeException ex = new RuntimeException("PSQLException: could not execute statement");

        ResponseEntity<Map<String, String>> response = exceptionHandler.handleRuntimeException(ex);

        assertNotNull(response);
        assertEquals(HttpStatus.BAD_REQUEST, response.getStatusCode());
        assertFalse(response.getBody().get("error").contains("PSQLException"));
        assertTrue(response.getBody().get("error").contains("base de datos"));
    }

    @Test
    void testHandleBadCredentials() {
        BadCredentialsException ex = new BadCredentialsException("bad credentials");

        ResponseEntity<Map<String, String>> response = exceptionHandler.handleBadCredentials(ex);

        assertNotNull(response);
        assertEquals(HttpStatus.UNAUTHORIZED, response.getStatusCode());
        assertTrue(response.getBody().get("error").contains("incorrectos"));
    }

    @Test
    void testHandleDisabledAccount() {
        DisabledException ex = new DisabledException("La tienda o bodega asignada se encuentra desactivada.");

        ResponseEntity<Map<String, String>> response = exceptionHandler.handleDisabledAccount(ex);

        assertNotNull(response);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        assertEquals("La tienda o bodega asignada se encuentra desactivada.", response.getBody().get("error"));
    }

    @Test
    void testHandleLockedAccount() {
        LockedException ex = new LockedException("Cuenta bloqueada");

        ResponseEntity<Map<String, String>> response = exceptionHandler.handleLockedAccount(ex);

        assertNotNull(response);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        assertEquals("Cuenta bloqueada", response.getBody().get("error"));
    }

    @Test
    void testHandleAccessDenied() {
        AccessDeniedException ex = new AccessDeniedException("denied");

        ResponseEntity<Map<String, String>> response = exceptionHandler.handleAccessDenied(ex);

        assertNotNull(response);
        assertEquals(HttpStatus.FORBIDDEN, response.getStatusCode());
        assertTrue(response.getBody().get("error").contains("permisos"));
    }

    @Test
    void testHandleGeneralException_Throwable() {
        Throwable ex = new Exception("Unexpected catastrophic failure");

        ResponseEntity<Map<String, String>> response = exceptionHandler.handleGeneralException(ex);

        assertNotNull(response);
        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, response.getStatusCode());
        assertFalse(response.getBody().get("error").contains("catastrophic"));
        assertTrue(response.getBody().get("error").contains("error interno"));
    }
}
