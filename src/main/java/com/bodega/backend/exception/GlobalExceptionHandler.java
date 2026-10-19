package com.bodega.backend.exception;

import org.springframework.dao.CannotAcquireLockException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.dao.PessimisticLockingFailureException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;

import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.Map;

@ControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    // Atrapa violaciones de unicidad o llaves foráneas en base de datos
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<Map<String, String>> handleDataIntegrityViolation(DataIntegrityViolationException ex) {
        log.warn("[GlobalExceptionHandler] Violación de integridad de datos: {}", ex.getMessage());
        Map<String, String> error = new HashMap<>();
        String rootMsg = ex.getRootCause() != null ? ex.getRootCause().getMessage() : ex.getMessage();
        if (rootMsg != null) {
            String lower = rootMsg.toLowerCase();
            if (lower.contains("duplicate key") || lower.contains("unique constraint") || lower.contains("llave duplicada") || lower.contains("ya existe la llave")) {
                error.put("error", "Ya existe un registro con estos datos únicos (código de barras, SKU, DNI/RUC o usuario).");
                return new ResponseEntity<>(error, HttpStatus.CONFLICT);
            }
            if (lower.contains("foreign key") || lower.contains("violates foreign key") || lower.contains("clave foránea") || lower.contains("llave foránea")) {
                error.put("error", "No se puede completar la operación porque este registro está vinculado a otros datos (ventas, compras o movimientos asociados).");
                return new ResponseEntity<>(error, HttpStatus.CONFLICT);
            }
        }
        error.put("error", "No se puede procesar la operación debido a restricciones de integridad en los datos.");
        return new ResponseEntity<>(error, HttpStatus.CONFLICT);
    }

    // Atrapa colisiones de concurrencia y bloqueos simultáneos
    @ExceptionHandler({
        OptimisticLockingFailureException.class,
        PessimisticLockingFailureException.class,
        CannotAcquireLockException.class
    })
    public ResponseEntity<Map<String, String>> handleConcurrencyConflict(Exception ex) {
        log.warn("[GlobalExceptionHandler] Conflicto de concurrencia detectado: {}", ex.getMessage());
        Map<String, String> error = new HashMap<>();
        error.put("error", "El registro fue modificado simultáneamente por otra operación o terminal. Por favor refresque e intente nuevamente.");
        return new ResponseEntity<>(error, HttpStatus.CONFLICT);
    }

    // Atrapa validaciones de restricciones en parámetros de URL o entidades (@Validated)
    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<Map<String, String>> handleConstraintViolation(ConstraintViolationException ex) {
        Map<String, String> error = new HashMap<>();
        String primerMensaje = ex.getConstraintViolations().stream()
                .map(ConstraintViolation::getMessage)
                .findFirst()
                .orElse("Parámetros de solicitud no válidos.");
        error.put("error", primerMensaje);
        return new ResponseEntity<>(error, HttpStatus.BAD_REQUEST);
    }

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

    // Atrapa intentos de inicio de sesión con cuentas desactivadas
    @ExceptionHandler(org.springframework.security.authentication.DisabledException.class)
    public ResponseEntity<Map<String, String>> handleDisabledAccount(org.springframework.security.authentication.DisabledException ex) {
        Map<String, String> error = new HashMap<>();
        error.put("error", "Esta cuenta de usuario ha sido desactivada. Contacta al administrador del sistema.");
        return new ResponseEntity<>(error, HttpStatus.FORBIDDEN);
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

    // Atrapa parámetros requeridos de URL ausentes (@RequestParam)
    @ExceptionHandler(org.springframework.web.bind.MissingServletRequestParameterException.class)
    public ResponseEntity<Map<String, String>> handleMissingServletRequestParameter(org.springframework.web.bind.MissingServletRequestParameterException ex) {
        Map<String, String> error = new HashMap<>();
        error.put("error", "El parámetro obligatorio '" + ex.getParameterName() + "' no fue proporcionado en la solicitud.");
        return new ResponseEntity<>(error, HttpStatus.BAD_REQUEST);
    }

    // Atrapa métodos HTTP no soportados (ej. enviar GET a un endpoint POST)
    @ExceptionHandler(org.springframework.web.HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<Map<String, String>> handleMethodNotSupported(org.springframework.web.HttpRequestMethodNotSupportedException ex) {
        Map<String, String> error = new HashMap<>();
        error.put("error", "El método HTTP '" + ex.getMethod() + "' no está permitido para este endpoint.");
        return new ResponseEntity<>(error, HttpStatus.METHOD_NOT_ALLOWED);
    }

    // Atrapa rutas o recursos no existentes
    @ExceptionHandler(org.springframework.web.servlet.resource.NoResourceFoundException.class)
    public ResponseEntity<Map<String, String>> handleNoResourceFound(org.springframework.web.servlet.resource.NoResourceFoundException ex) {
        Map<String, String> error = new HashMap<>();
        error.put("error", "El recurso o endpoint solicitado no existe.");
        return new ResponseEntity<>(error, HttpStatus.NOT_FOUND);
    }

    // Atrapa Content-Type no soportado (ej. enviar text/plain a un endpoint que requiere JSON)
    @ExceptionHandler(org.springframework.web.HttpMediaTypeNotSupportedException.class)
    public ResponseEntity<Map<String, String>> handleMediaTypeNotSupported(org.springframework.web.HttpMediaTypeNotSupportedException ex) {
        Map<String, String> error = new HashMap<>();
        error.put("error", "El tipo de contenido (Content-Type) '" + ex.getContentType() + "' no es soportado. Se requiere 'application/json'.");
        return new ResponseEntity<>(error, HttpStatus.UNSUPPORTED_MEDIA_TYPE);
    }

    // Captura universal de cualquier error inesperado no controlado (previene fuga de trazas técnicas al cliente)
    @ExceptionHandler(Throwable.class)
    public ResponseEntity<Map<String, String>> handleGeneralException(Throwable ex) {
        log.error("[GlobalExceptionHandler] Error no controlado: {}", ex.getMessage(), ex);
        Map<String, String> error = new HashMap<>();
        error.put("error", "Ocurrió un error interno en el servidor. Por favor comuníquese con soporte si el problema persiste.");
        return new ResponseEntity<>(error, HttpStatus.INTERNAL_SERVER_ERROR);
    }
}
