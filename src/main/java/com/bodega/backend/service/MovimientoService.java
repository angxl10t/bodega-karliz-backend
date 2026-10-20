package com.bodega.backend.service;

import com.bodega.backend.dto.AjusteInventarioDTO;
import com.bodega.backend.dto.MovimientoInventarioDTO;
import com.bodega.backend.entity.MovimientoInventario;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.repository.MovimientoInventarioRepository;
import com.bodega.backend.repository.ProductoRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class MovimientoService {

    private final MovimientoInventarioRepository movimientoRepository;
    private final ProductoRepository productoRepository;
    private final TenantService tenantService;

    public MovimientoService(MovimientoInventarioRepository movimientoRepository,
                             ProductoRepository productoRepository,
                             TenantService tenantService) {
        this.movimientoRepository = movimientoRepository;
        this.productoRepository = productoRepository;
        this.tenantService = tenantService;
    }

    @Transactional(readOnly = true)
    public List<MovimientoInventarioDTO> listarTodos() {
        Long idBodega = tenantService.getCurrentBodegaId();
        return movimientoRepository.findTop200ByBodega_IdBodegaOrderByFechaMovimientoDesc(idBodega)
                .stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<MovimientoInventarioDTO> listarPorProducto(Long idProducto) {
        if (idProducto == null || idProducto <= 0) {
            return java.util.Collections.emptyList();
        }
        Long idBodega = tenantService.getCurrentBodegaId();
        List<MovimientoInventario> lista = movimientoRepository.findTop100ByBodega_IdBodegaAndProducto_IdProductoOrderByFechaMovimientoDesc(idBodega, idProducto);
        if (lista.isEmpty()) {
            lista = movimientoRepository.findTop100ByProducto_IdProductoAndProducto_Bodega_IdBodegaOrderByFechaMovimientoDesc(idProducto, idBodega);
        }
        return lista.stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
    }

    @Transactional
    public MovimientoInventarioDTO registrarAjuste(AjusteInventarioDTO dto) {
        if (dto == null || dto.getIdProducto() == null) {
            throw new RuntimeException("El producto es obligatorio para registrar el ajuste de inventario.");
        }
        if (dto.getCantidad() == null || dto.getCantidad().compareTo(BigDecimal.ZERO) <= 0) {
            throw new RuntimeException("La cantidad debe ser mayor a cero.");
        }
        if (dto.getTipoAjuste() == null || dto.getTipoAjuste().isBlank()) {
            throw new RuntimeException("El tipo de ajuste es obligatorio (MERMA, ROTURA, VENCIMIENTO, CONSUMO_INTERNO, SOBRANTE).");
        }
        if (dto.getMotivo() == null || dto.getMotivo().trim().isBlank()) {
            throw new RuntimeException("El motivo o justificación del ajuste es obligatorio.");
        }

        Long idBodega = tenantService.getCurrentBodegaId();

        // Bloqueo pesimista para evitar colisiones con ventas concurrentes
        Producto producto = productoRepository.findByIdForUpdateAndBodega(dto.getIdProducto(), idBodega)
                .orElseThrow(() -> new RuntimeException("Producto no encontrado en su bodega con ID: " + dto.getIdProducto()));

        if (Boolean.FALSE.equals(producto.getEstado())) {
            throw new RuntimeException("No se puede ajustar el inventario de un producto inactivo o dado de baja.");
        }

        String tipoAjusteNormalizado = dto.getTipoAjuste().trim().toUpperCase();
        BigDecimal stockAnterior = producto.getStockActual() != null ? producto.getStockActual() : BigDecimal.ZERO;
        BigDecimal nuevoStock;
        String tipoMovimiento;

        boolean esSalida = tipoAjusteNormalizado.contains("MERMA")
                || tipoAjusteNormalizado.contains("ROTURA")
                || tipoAjusteNormalizado.contains("VENCID")
                || tipoAjusteNormalizado.contains("VENCIMIENTO")
                || tipoAjusteNormalizado.contains("CONSUMO")
                || tipoAjusteNormalizado.contains("SALIDA");

        if (esSalida) {
            if (stockAnterior.compareTo(dto.getCantidad()) < 0) {
                throw new RuntimeException("Stock insuficiente para realizar el ajuste. Stock actual: "
                        + stockAnterior + ", cantidad a descontar: " + dto.getCantidad());
            }
            nuevoStock = stockAnterior.subtract(dto.getCantidad());
            tipoMovimiento = "SALIDA";
        } else if (tipoAjusteNormalizado.contains("SOBRANTE") || tipoAjusteNormalizado.contains("ENTRADA")) {
            nuevoStock = stockAnterior.add(dto.getCantidad());
            tipoMovimiento = "ENTRADA";
        } else {
            throw new RuntimeException("Tipo de ajuste no reconocido: " + dto.getTipoAjuste()
                    + ". Tipos válidos: MERMA, ROTURA, VENCIMIENTO, CONSUMO_INTERNO, SOBRANTE.");
        }

        producto.setStockActual(nuevoStock);
        productoRepository.save(producto);

        String motivoLimpio = dto.getMotivo().trim();
        String motivoKardex = String.format("[%s] %s (Stock: %s -> %s)",
                tipoAjusteNormalizado, motivoLimpio, stockAnterior, nuevoStock);
        if (motivoKardex.length() > 255) {
            motivoKardex = motivoKardex.substring(0, 255);
        }

        MovimientoInventario mov = new MovimientoInventario();
        mov.setProducto(producto);
        mov.setTipoMovimiento(tipoMovimiento);
        mov.setCantidad(dto.getCantidad());
        mov.setMotivo(motivoKardex);
        mov.setUsuarioResponsable(obtenerUsuarioActual());
        mov.setBodega(producto.getBodega());

        MovimientoInventario guardado = movimientoRepository.save(mov);
        return mapToDTO(guardado);
    }

    private String obtenerUsuarioActual() {
        var auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.isAuthenticated() && !"anonymousUser".equals(auth.getName())) {
            return auth.getName();
        }
        return "ADMIN";
    }

    private MovimientoInventarioDTO mapToDTO(MovimientoInventario mov) {
        MovimientoInventarioDTO dto = new MovimientoInventarioDTO();
        dto.setIdMovimiento(mov.getIdMovimiento());
        if (mov.getProducto() != null) {
            dto.setIdProducto(mov.getProducto().getIdProducto());
            dto.setNombreProducto(mov.getProducto().getNombre());
        }
        dto.setTipoMovimiento(mov.getTipoMovimiento());
        dto.setCantidad(mov.getCantidad());
        dto.setMotivo(mov.getMotivo());
        dto.setFechaMovimiento(mov.getFechaMovimiento());
        dto.setUsuarioResponsable(mov.getUsuarioResponsable());
        return dto;
    }
}
