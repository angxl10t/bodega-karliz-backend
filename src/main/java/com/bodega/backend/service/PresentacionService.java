package com.bodega.backend.service;

import com.bodega.backend.dto.PresentacionDTO;
import com.bodega.backend.entity.Presentacion;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.repository.PresentacionRepository;
import com.bodega.backend.repository.ProductoRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class PresentacionService {

    private final PresentacionRepository presentacionRepository;
    private final ProductoRepository productoRepository;
    private final TenantService tenantService;

    public PresentacionService(PresentacionRepository presentacionRepository, 
                               ProductoRepository productoRepository,
                               TenantService tenantService) {
        this.presentacionRepository = presentacionRepository;
        this.productoRepository = productoRepository;
        this.tenantService = tenantService;
    }

    @Transactional(readOnly = true)
    public List<PresentacionDTO> listarPorProducto(Long idProducto) {
        Long idBodega = tenantService.getCurrentBodegaId();
        productoRepository.findByIdProductoAndBodega_IdBodega(idProducto, idBodega)
                .orElseThrow(() -> new RuntimeException("Producto no encontrado en esta bodega con ID: " + idProducto));
        return presentacionRepository.findByProducto_IdProductoAndProducto_Bodega_IdBodegaAndEstadoTrue(idProducto, idBodega)
                .stream().map(this::mapToDTO).collect(Collectors.toList());
    }

    @Transactional
    public PresentacionDTO crear(PresentacionDTO dto) {
        Long idBodega = tenantService.getCurrentBodegaId();
        Producto producto = productoRepository.findByIdProductoAndBodega_IdBodega(dto.getIdProducto(), idBodega)
                .orElseThrow(() -> new RuntimeException("El producto al que intentas asignar la presentación no existe en tu bodega."));

        if (Boolean.FALSE.equals(producto.getEstado())) {
            throw new RuntimeException("No se puede asignar una presentación a un producto inactivo o dado de baja: " + producto.getNombre());
        }

        String nombreTrim = dto.getNombre() != null ? dto.getNombre().trim() : "";
        if (nombreTrim.isBlank()) {
            throw new RuntimeException("El nombre de la presentación es obligatorio.");
        }

        if (dto.getFactorConversion() == null || dto.getFactorConversion().compareTo(java.math.BigDecimal.ZERO) <= 0) {
            throw new RuntimeException("El factor de conversión debe ser mayor a 0.");
        }

        java.util.Optional<Presentacion> existente = presentacionRepository
                .findByProducto_IdProductoAndNombreIgnoreCase(dto.getIdProducto(), nombreTrim);
        if (existente.isPresent()) {
            Presentacion pres = existente.get();
            if (Boolean.FALSE.equals(pres.getEstado())) {
                pres.setEstado(true);
                pres.setFactorConversion(dto.getFactorConversion());
                Presentacion reactivada = presentacionRepository.save(pres);
                return mapToDTO(reactivada);
            }
            throw new RuntimeException("Ya existe una presentación activa con el nombre '" + nombreTrim + "' para este producto.");
        }

        Presentacion presentacion = new Presentacion();
        presentacion.setProducto(producto);
        presentacion.setNombre(nombreTrim);
        presentacion.setFactorConversion(dto.getFactorConversion());

        Presentacion guardada = presentacionRepository.save(presentacion);
        return mapToDTO(guardada);
    }

    // ACCIDENTAL DATA LOSS PREVENTION: Borrado Lógico en lugar de Delete físico
    @Transactional
    public void desactivar(Long idPresentacion) {
        Long idBodega = tenantService.getCurrentBodegaId();
        Presentacion presentacion = presentacionRepository.findByIdPresentacionAndProducto_Bodega_IdBodega(idPresentacion, idBodega)
                .orElseThrow(() -> new RuntimeException("Presentación no encontrada en tu bodega con ID: " + idPresentacion));
        if (Boolean.FALSE.equals(presentacion.getEstado())) {
            return;
        }
        presentacion.setEstado(false);
        presentacionRepository.save(presentacion);
    }

    private PresentacionDTO mapToDTO(Presentacion presentacion) {
        PresentacionDTO dto = new PresentacionDTO();
        dto.setIdPresentacion(presentacion.getIdPresentacion());
        dto.setIdProducto(presentacion.getProducto().getIdProducto());
        dto.setNombreProducto(presentacion.getProducto().getNombre());
        dto.setNombre(presentacion.getNombre());
        dto.setFactorConversion(presentacion.getFactorConversion());
        dto.setEstado(presentacion.getEstado());
        return dto;
    }
}
