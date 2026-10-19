package com.bodega.backend.service;

import com.bodega.backend.dto.MovimientoInventarioDTO;
import com.bodega.backend.entity.MovimientoInventario;
import com.bodega.backend.repository.MovimientoInventarioRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class MovimientoService {

    private final MovimientoInventarioRepository movimientoRepository;
    private final TenantService tenantService;

    public MovimientoService(MovimientoInventarioRepository movimientoRepository, TenantService tenantService) {
        this.movimientoRepository = movimientoRepository;
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
        return movimientoRepository.findTop100ByProducto_IdProductoAndProducto_Bodega_IdBodegaOrderByFechaMovimientoDesc(idProducto, idBodega)
                .stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
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
