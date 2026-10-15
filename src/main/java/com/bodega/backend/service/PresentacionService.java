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

    public PresentacionService(PresentacionRepository presentacionRepository, ProductoRepository productoRepository) {
        this.presentacionRepository = presentacionRepository;
        this.productoRepository = productoRepository;
    }

    @Transactional(readOnly = true)
    public List<PresentacionDTO> listarPorProducto(Long idProducto) {
        return presentacionRepository.findByProducto_IdProductoAndEstadoTrue(idProducto)
                .stream().map(this::mapToDTO).collect(Collectors.toList());
    }

    @Transactional
    public PresentacionDTO crear(PresentacionDTO dto) {
        Producto producto = productoRepository.findById(dto.getIdProducto())
                .orElseThrow(() -> new RuntimeException("El producto al que intentas asignar la presentación no existe."));

        if (Boolean.FALSE.equals(producto.getEstado())) {
            throw new RuntimeException("No se puede asignar una presentación a un producto inactivo o dado de baja: " + producto.getNombre());
        }

        String nombreTrim = dto.getNombre() != null ? dto.getNombre().trim() : "";
        if (nombreTrim.isBlank()) {
            throw new RuntimeException("El nombre de la presentación es obligatorio.");
        }

        if (presentacionRepository.existsByProducto_IdProductoAndNombreIgnoreCaseAndEstadoTrue(dto.getIdProducto(), nombreTrim)) {
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
        Presentacion presentacion = presentacionRepository.findById(idPresentacion)
                .orElseThrow(() -> new RuntimeException("Presentación no encontrada"));
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
