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

    @GetMapping("/proxy-image")
    public ResponseEntity<byte[]> proxyImage(@RequestParam("url") String targetUrl) {
        try {
            if (targetUrl == null || !targetUrl.startsWith("http")) {
                return ResponseEntity.badRequest().build();
            }
            java.net.URI uri = new java.net.URI(targetUrl.trim());
            java.net.http.HttpClient client = java.net.http.HttpClient.newBuilder()
                    .followRedirects(java.net.http.HttpClient.Redirect.NORMAL)
                    .connectTimeout(java.time.Duration.ofSeconds(6))
                    .build();
            java.net.http.HttpRequest req = java.net.http.HttpRequest.newBuilder(uri)
                    .header("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
                    .timeout(java.time.Duration.ofSeconds(8))
                    .GET()
                    .build();
            java.net.http.HttpResponse<byte[]> res = client.send(req, java.net.http.HttpResponse.BodyHandlers.ofByteArray());
            if (res.statusCode() == 200) {
                String contentType = res.headers().firstValue("content-type").orElse("image/jpeg");
                return ResponseEntity.ok()
                        .header(HttpHeaders.CONTENT_TYPE, contentType)
                        .header(HttpHeaders.CACHE_CONTROL, "public, max-age=604800")
                        .header("Access-Control-Allow-Origin", "*")
                        .header("Access-Control-Allow-Methods", "GET, OPTIONS")
                        .body(res.body());
            }
            return ResponseEntity.status(res.statusCode()).build();
        } catch (Exception e) {
            return ResponseEntity.notFound().build();
        }
    }
}
