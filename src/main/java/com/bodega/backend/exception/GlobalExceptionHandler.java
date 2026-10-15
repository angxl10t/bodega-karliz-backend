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
        String primerMensaje = null;
        for (var error : ex.getBindingResult().getFieldErrors()) {
            errors.put(error.getField(), error.getDefaultMessage());
            if (primerMensaje == null) {
                primerMensaje = error.getDefaultMessage();
            }
        }
        if (primerMensaje == null) {
            primerMensaje = "Datos de entrada inválidos.";
        }
        errors.put("error", primerMensaje);
        return new ResponseEntity<>(errors, HttpStatus.BAD_REQUEST);
    }

    // Atrapa JSON mal formado o tipos de datos incompatibles en el cuerpo del request
    @ExceptionHandler(org.springframework.http.converter.HttpMessageNotReadableException.class)
    public ResponseEntity<Map<String, String>> handleHttpMessageNotReadable(org.springframework.http.converter.HttpMessageNotReadableException ex) {
        Map<String, String> error = new HashMap<>();
        error.put("error", "El formato del cuerpo de la solicitud (JSON) es inválido o contiene tipos de datos incorrectos.");
        return new ResponseEntity<>(error, HttpStatus.BAD_REQUEST);
    }

    // Atrapa parámetros de URL con tipos incorrectos (ej. pasar letras donde se espera un ID numérico o fecha)
    @ExceptionHandler(org.springframework.web.method.annotation.MethodArgumentTypeMismatchException.class)
    public ResponseEntity<Map<String, String>> handleMethodArgumentTypeMismatch(org.springframework.web.method.annotation.MethodArgumentTypeMismatchException ex) {
        Map<String, String> error = new HashMap<>();
        String paramName = ex.getName();
        error.put("error", "El parámetro '" + paramName + "' proporcionado en la solicitud tiene un formato o tipo de dato inválido.");
        return new ResponseEntity<>(error, HttpStatus.BAD_REQUEST);
    }

    // Captura universal de cualquier error inesperado no controlado para evitar fuga de trazas o stack traces
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> handleGeneralException(Exception ex) {
        Map<String, String> error = new HashMap<>();
        error.put("error", "Error interno al procesar la solicitud en el servidor.");
        return new ResponseEntity<>(error, HttpStatus.INTERNAL_SERVER_ERROR);
    }
}
