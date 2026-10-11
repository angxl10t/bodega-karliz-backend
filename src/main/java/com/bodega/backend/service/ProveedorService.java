package com.bodega.backend.service;

import com.bodega.backend.dto.ProveedorDTO;
import com.bodega.backend.entity.Proveedor;
import com.bodega.backend.repository.ProveedorRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class ProveedorService {

    private final ProveedorRepository proveedorRepository;

    public ProveedorService(ProveedorRepository proveedorRepository) {
        this.proveedorRepository = proveedorRepository;
    }

    @Transactional(readOnly = true)
    public List<ProveedorDTO> listarActivos() {
        return proveedorRepository.findByEstadoTrue().stream().map(this::mapToDTO).collect(Collectors.toList());
    }

    @Transactional
    public ProveedorDTO crear(ProveedorDTO dto) {
        if (proveedorRepository.findByRuc(dto.getRuc()).isPresent()) {
            throw new RuntimeException("Ya existe un proveedor registrado con el RUC: " + dto.getRuc());
        }

        Proveedor proveedor = new Proveedor();
        proveedor.setRuc(dto.getRuc());
        proveedor.setRazonSocial(dto.getRazonSocial());
        proveedor.setDireccion(dto.getDireccion());
        proveedor.setTelefono(dto.getTelefono());

        Proveedor guardado = proveedorRepository.save(proveedor);
        return mapToDTO(guardado);
    }

    // ACCIDENTAL DATA LOSS PREVENTION: Borrado Lógico
    @Transactional
    public void desactivar(Long idProveedor) {
        Proveedor proveedor = proveedorRepository.findById(idProveedor)
                .orElseThrow(() -> new RuntimeException("Proveedor no encontrado"));
        proveedor.setEstado(false);
        proveedorRepository.save(proveedor);
    }

    private ProveedorDTO mapToDTO(Proveedor proveedor) {
        ProveedorDTO dto = new ProveedorDTO();
        dto.setIdProveedor(proveedor.getIdProveedor());
        dto.setRuc(proveedor.getRuc());
        dto.setRazonSocial(proveedor.getRazonSocial());
        dto.setDireccion(proveedor.getDireccion());
        dto.setTelefono(proveedor.getTelefono());
        dto.setEstado(proveedor.getEstado());
        return dto;
    }
}
