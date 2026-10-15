package com.bodega.backend.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;

import java.util.HashMap;
import java.util.Map;

@ControllerAdvice
public class GlobalExceptionHandler {

    // Atrapa reglas de negocio controladas y previene fuga de errores internos de BD
    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<Map<String, String>> handleRuntimeException(RuntimeException ex) {
        Map<String, String> error = new HashMap<>();
        String msg = ex.getMessage();

        // Si la excepción contiene trazas técnicas de Hibernate o PostgreSQL, se sanitiza
        if (msg != null && (msg.contains("org.hibernate") || msg.contains("PSQLException") 
                || msg.contains("SQLException") || msg.contains("could not execute statement"))) {
            msg = "Error interno al procesar la operación en la base de datos.";
        }

        error.put("error", (msg != null && !msg.isBlank()) ? msg : "Error inesperado al procesar la solicitud.");
        return new ResponseEntity<>(error, HttpStatus.BAD_REQUEST);
    }

    // Atrapa credenciales incorrectas en login
    @ExceptionHandler(BadCredentialsException.class)
    public ResponseEntity<Map<String, String>> handleBadCredentials(BadCredentialsException ex) {
        Map<String, String> error = new HashMap<>();
        error.put("error", "Usuario o contraseña incorrectos.");
        return new ResponseEntity<>(error, HttpStatus.UNAUTHORIZED);
    }

    // Atrapa intentos de acceso no autorizados por RBAC (@PreAuthorize)
    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<Map<String, String>> handleAccessDenied(AccessDeniedException ex) {
        Map<String, String> error = new HashMap<>();
        error.put("error", "No tienes permisos suficientes para realizar esta acción.");
        return new ResponseEntity<>(error, HttpStatus.FORBIDDEN);
    }

    // Atrapa validaciones de DTO rotas (Ej. Nombres vacíos, Precio en cero)
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, String>> handleValidationExceptions(MethodArgumentNotValidException ex) {
        Map<String, String> errors = new HashMap<>();
        ex.getBindingResult().getFieldErrors().forEach(error -> 
            errors.put(error.getField(), error.getDefaultMessage()));
        return new ResponseEntity<>(errors, HttpStatus.BAD_REQUEST);
    }

    // Captura universal de cualquier error inesperado no controlado para evitar fuga de trazas o stack traces
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> handleGeneralException(Exception ex) {
        Map<String, String> error = new HashMap<>();
        error.put("error", "Error interno al procesar la solicitud en el servidor.");
        return new ResponseEntity<>(error, HttpStatus.INTERNAL_SERVER_ERROR);
    }
}
