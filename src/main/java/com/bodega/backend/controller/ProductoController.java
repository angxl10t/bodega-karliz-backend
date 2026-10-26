package com.bodega.backend.controller;

import com.bodega.backend.dto.ProductoDTO;
import com.bodega.backend.service.ProductoService;
import jakarta.validation.Valid;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/productos")
public class ProductoController {

    private final ProductoService productoService;

    public ProductoController(ProductoService productoService) {
        this.productoService = productoService;
    }

    @GetMapping
    public ResponseEntity<List<ProductoDTO>> listarActivos() {
        return ResponseEntity.ok(productoService.listarActivos());
    }

    @GetMapping("/siguiente-codigo")
    public ResponseEntity<Map<String, String>> siguienteCodigo(@RequestParam Long idCategoria) {
        String codigo = productoService.generarSiguienteCodigo(idCategoria);
        return ResponseEntity.ok(Map.of("codigo", codigo));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'CAJERO', 'SUPERADMIN')")
    public ResponseEntity<ProductoDTO> obtenerPorId(@PathVariable Long id) {
        return ResponseEntity.ok(productoService.obtenerPorId(id));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<ProductoDTO> crear(@Valid @RequestBody ProductoDTO dto) {
        return new ResponseEntity<>(productoService.crear(dto), HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<ProductoDTO> actualizar(@PathVariable Long id, @Valid @RequestBody ProductoDTO dto) {
        return ResponseEntity.ok(productoService.actualizar(id, dto));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<Void> desactivar(@PathVariable Long id) {
        productoService.desactivar(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping(value = "/exportar-csv", produces = "text/csv; charset=UTF-8")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN')")
    public ResponseEntity<byte[]> exportarCsv() {
        byte[] csv = productoService.exportarCsv();
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"catalogo_productos.csv\"")
                .header(HttpHeaders.CONTENT_TYPE, "text/csv; charset=UTF-8")
                .body(csv);
    }

    private static final int MAX_IMAGE_BYTES = 5 * 1024 * 1024; // 5 MB max
    private static final java.util.Set<String> ALLOWED_IMAGE_TYPES = java.util.Set.of(
        "image/jpeg", "image/png", "image/webp", "image/gif", "image/svg+xml", "image/avif"
    );

    /**
     * Validador defensivo anti-SSRF (Server-Side Request Forgery).
     * Bloquea terminantemente consultas a localhost, IPs privadas (RFC 1918),
     * enlace local (APIPA/Cloud Metadata 169.254.169.254) y dominios internos.
     */
    private boolean isSafeExternalHost(String host) {
        if (host == null || host.isBlank()) {
            return false;
        }
        String lowerHost = host.trim().toLowerCase();
        if (lowerHost.equals("localhost") || lowerHost.endsWith(".localhost") ||
            lowerHost.equals("127.0.0.1") || lowerHost.equals("0.0.0.0") ||
            lowerHost.equals("::1") || lowerHost.equals("169.254.169.254") ||
            lowerHost.endsWith(".internal") || lowerHost.endsWith(".local") || lowerHost.endsWith(".lan")) {
            return false;
        }
        try {
            java.net.InetAddress[] addresses = java.net.InetAddress.getAllByName(host);
            for (java.net.InetAddress addr : addresses) {
                if (addr.isLoopbackAddress() || addr.isAnyLocalAddress() ||
                    addr.isLinkLocalAddress() || addr.isSiteLocalAddress() ||
                    addr.isMulticastAddress()) {
                    return false;
                }
                byte[] raw = addr.getAddress();
                if (raw.length == 4) {
                    int b0 = raw[0] & 0xFF;
                    int b1 = raw[1] & 0xFF;
                    if (b0 == 10) return false; // 10.0.0.0/8
                    if (b0 == 172 && (b1 >= 16 && b1 <= 31)) return false; // 172.16.0.0/12
                    if (b0 == 192 && b1 == 168) return false; // 192.168.0.0/16
                    if (b0 == 169 && b1 == 254) return false; // 169.254.0.0/16 (Metadata AWS/GCP/Render)
                    if (b0 == 127) return false; // 127.0.0.0/8
                    if (b0 == 0) return false;
                }
            }
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * Proxy seguro de imágenes con defensas anti-SSRF, verificación estricta de Content-Type
     * y límite de tamaño en memoria para prevenir saturación y fugas de infraestructura.
     */
    @GetMapping("/proxy-image")
    public ResponseEntity<byte[]> proxyImage(@RequestParam("url") String targetUrl) {
        try {
            if (targetUrl == null || targetUrl.isBlank()) {
                return ResponseEntity.badRequest().build();
            }
            java.net.URI uri = new java.net.URI(targetUrl.trim());
            String scheme = uri.getScheme();
            if (scheme == null || (!scheme.equalsIgnoreCase("http") && !scheme.equalsIgnoreCase("https"))) {
                return ResponseEntity.badRequest().build();
            }

            String host = uri.getHost();
            if (!isSafeExternalHost(host)) {
                return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
            }

            // Client anti-SSRF: followRedirects DESHABILITADO para prevenir bypass por redirección 302
            java.net.http.HttpClient client = java.net.http.HttpClient.newBuilder()
                    .followRedirects(java.net.http.HttpClient.Redirect.NEVER)
                    .connectTimeout(java.time.Duration.ofSeconds(4))
                    .build();

            java.net.http.HttpRequest req = java.net.http.HttpRequest.newBuilder(uri)
                    .header("User-Agent", "CajaYa-POS-ImageProxy/1.4")
                    .timeout(java.time.Duration.ofSeconds(6))
                    .GET()
                    .build();

            java.net.http.HttpResponse<byte[]> res = client.send(req, java.net.http.HttpResponse.BodyHandlers.ofByteArray());
            if (res.statusCode() == 200) {
                // Validación estricta de tipo MIME: Solo formatos de imagen autorizados
                String rawContentType = res.headers().firstValue("content-type").orElse("").toLowerCase();
                String baseType = rawContentType.split(";")[0].trim();
                if (!ALLOWED_IMAGE_TYPES.contains(baseType) && !baseType.startsWith("image/")) {
                    return ResponseEntity.status(HttpStatus.UNSUPPORTED_MEDIA_TYPE).build();
                }

                byte[] body = res.body();
                if (body != null && body.length > MAX_IMAGE_BYTES) {
                    return ResponseEntity.status(HttpStatus.PAYLOAD_TOO_LARGE).build();
                }

                return ResponseEntity.ok()
                        .header(HttpHeaders.CONTENT_TYPE, baseType)
                        .header(HttpHeaders.CACHE_CONTROL, "public, max-age=604800, immutable")
                        .header("X-Content-Type-Options", "nosniff")
                        .body(body);
            }
            return ResponseEntity.status(res.statusCode()).build();
        } catch (Exception e) {
            return ResponseEntity.notFound().build();
        }
    }
}
