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
        String rucTrim = dto.getRuc() != null ? dto.getRuc().trim() : "";
        java.util.Optional<Proveedor> existente = proveedorRepository.findByRuc(rucTrim);
        if (existente.isPresent()) {
            Proveedor p = existente.get();
            if (Boolean.FALSE.equals(p.getEstado())) {
                // Reactivación segura de proveedor previamente dado de baja lógica
                p.setEstado(true);
                p.setRazonSocial(dto.getRazonSocial());
                p.setDireccion(dto.getDireccion());
                p.setTelefono(dto.getTelefono());
                Proveedor reactivado = proveedorRepository.save(p);
                return mapToDTO(reactivado);
            }
            throw new RuntimeException("Ya existe un proveedor activo registrado con el RUC: " + rucTrim);
        }

        Proveedor proveedor = new Proveedor();
        proveedor.setRuc(rucTrim);
        proveedor.setRazonSocial(dto.getRazonSocial());
        proveedor.setDireccion(dto.getDireccion());
        proveedor.setTelefono(dto.getTelefono());

        Proveedor guardado = proveedorRepository.save(proveedor);
        return mapToDTO(guardado);
    }

    @Transactional
    public ProveedorDTO actualizar(Long idProveedor, ProveedorDTO dto) {
        Proveedor proveedor = proveedorRepository.findById(idProveedor)
                .orElseThrow(() -> new RuntimeException("Proveedor no encontrado con ID: " + idProveedor));

        if (dto.getRuc() != null && !dto.getRuc().trim().equalsIgnoreCase(proveedor.getRuc())) {
            String rucTrim = dto.getRuc().trim();
            java.util.Optional<Proveedor> otro = proveedorRepository.findByRuc(rucTrim);
            if (otro.isPresent() && !otro.get().getIdProveedor().equals(idProveedor)) {
                throw new RuntimeException("Ya existe otro proveedor con el RUC: " + rucTrim);
            }
            proveedor.setRuc(rucTrim);
        }

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
                .orElseThrow(() -> new RuntimeException("Proveedor no encontrado con ID: " + idProveedor));
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
