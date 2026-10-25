package com.bodega.backend.controller;

import com.bodega.backend.dto.*;
import com.bodega.backend.service.ClienteService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/clientes")
public class ClienteController {

    private final ClienteService clienteService;

    public ClienteController(ClienteService clienteService) {
        this.clienteService = clienteService;
    }

    @GetMapping
    public ResponseEntity<List<ClienteDTO>> listar(
            @RequestParam(required = false) String query,
            @RequestParam(required = false) Boolean soloDeudores) {
        return ResponseEntity.ok(clienteService.listar(query, soloDeudores));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ClienteDTO> obtenerPorId(@PathVariable Long id) {
        return ResponseEntity.ok(clienteService.obtenerPorId(id));
    }

    @PostMapping
    public ResponseEntity<ClienteDTO> crear(@Valid @RequestBody ClienteDTO dto) {
        return new ResponseEntity<>(clienteService.crear(dto), HttpStatus.CREATED);
    }

    @PutMapping("/{id}")
    public ResponseEntity<ClienteDTO> actualizar(@PathVariable Long id, @Valid @RequestBody ClienteDTO dto) {
        return ResponseEntity.ok(clienteService.actualizar(id, dto));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable Long id) {
        clienteService.eliminar(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{id}/estado-cuenta")
    public ResponseEntity<EstadoCuentaClienteDTO> obtenerEstadoCuenta(@PathVariable Long id) {
        return ResponseEntity.ok(clienteService.obtenerEstadoCuenta(id));
    }

    @PostMapping("/{id}/abonos")
    public ResponseEntity<AbonoCreditoDTO> registrarAbono(
            @PathVariable Long id,
            @Valid @RequestBody RegistrarAbonoDTO dto) {
        return new ResponseEntity<>(clienteService.registrarAbono(id, dto), HttpStatus.CREATED);
    }

    @GetMapping("/resumen-creditos")
    public ResponseEntity<ResumenCreditosDTO> obtenerResumenCreditos() {
        return ResponseEntity.ok(clienteService.obtenerResumenCreditos());
    }
}
