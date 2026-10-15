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

    public MovimientoService(MovimientoInventarioRepository movimientoRepository) {
        this.movimientoRepository = movimientoRepository;
    }

    @Transactional(readOnly = true)
    public List<MovimientoInventarioDTO> listarTodos() {
        return movimientoRepository.findAllByOrderByFechaMovimientoDesc()
                .stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<MovimientoInventarioDTO> listarPorProducto(Long idProducto) {
        return movimientoRepository.findByProducto_IdProductoOrderByFechaMovimientoDesc(idProducto)
                .stream()
                .map(this::mapToDTO)
                .collect(Collectors.toList());
    }

    private MovimientoInventarioDTO mapToDTO(MovimientoInventario mov) {
        MovimientoInventarioDTO dto = new MovimientoInventarioDTO();
        dto.setIdMovimiento(mov.getIdMovimiento());
        dto.setIdProducto(mov.getProducto().getIdProducto());
        dto.setNombreProducto(mov.getProducto().getNombre());
        dto.setTipoMovimiento(mov.getTipoMovimiento());
        dto.setCantidad(mov.getCantidad());
        dto.setMotivo(mov.getMotivo());
        dto.setFechaMovimiento(mov.getFechaMovimiento());
        dto.setUsuarioResponsable(mov.getUsuarioResponsable());
        return dto;
    }
}
