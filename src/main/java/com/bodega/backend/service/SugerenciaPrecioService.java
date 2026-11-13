package com.bodega.backend.service;

import com.bodega.backend.dto.CrearSugerenciaSuperadminDTO;
import com.bodega.backend.dto.SugerenciaPrecioDTO;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.entity.SugerenciaPrecioSuperadmin;
import com.bodega.backend.repository.ProductoRepository;
import com.bodega.backend.repository.SugerenciaPrecioRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.NoSuchElementException;
import java.util.Optional;

@Service
public class SugerenciaPrecioService {

    private static final Logger log = LoggerFactory.getLogger(SugerenciaPrecioService.class);

    private final SugerenciaPrecioRepository sugerenciaPrecioRepository;
    private final ProductoRepository productoRepository;
    private final TenantService tenantService;
    private final AnalyticsService analyticsService;

    public SugerenciaPrecioService(
            SugerenciaPrecioRepository sugerenciaPrecioRepository,
            ProductoRepository productoRepository,
            TenantService tenantService,
            @org.springframework.beans.factory.annotation.Autowired(required = false) AnalyticsService analyticsService) {
        this.sugerenciaPrecioRepository = sugerenciaPrecioRepository;
        this.productoRepository = productoRepository;
        this.tenantService = tenantService;
        this.analyticsService = analyticsService;
    }

    @Transactional
    public int difundirSugerencia(CrearSugerenciaSuperadminDTO dto) {
        String ean = dto.getCodigoBarras().trim();
        List<Producto> productos = productoRepository.findByCodigoBarrasAndEstadoTrue(ean);

        if (dto.getIdBodegaEspecifica() != null) {
            productos = productos.stream()
                    .filter(p -> p.getBodega() != null && p.getBodega().getIdBodega().equals(dto.getIdBodegaEspecifica()))
                    .toList();
        }

        int notificadas = 0;
        String motivo = (dto.getMotivo() != null && !dto.getMotivo().isBlank())
                ? dto.getMotivo().trim()
                : "Actualización de precios sugerida por el SuperAdmin de CajaYa";

        for (Producto producto : productos) {
            if (producto.getBodega() == null) continue;
            Long idBodega = producto.getBodega().getIdBodega();

            Optional<SugerenciaPrecioSuperadmin> existenteOpt =
                    sugerenciaPrecioRepository.findByBodega_IdBodegaAndCodigoBarrasAndEstado(idBodega, ean, "PENDIENTE");

            SugerenciaPrecioSuperadmin sugerencia;
            if (existenteOpt.isPresent()) {
                sugerencia = existenteOpt.get();
                sugerencia.setPrecioVentaSugerido(dto.getPrecioVentaSugerido());
                if (dto.getPrecioCostoSugerido() != null) {
                    sugerencia.setPrecioCostoSugerido(dto.getPrecioCostoSugerido());
                }
                if (dto.getNombreSugerido() != null && !dto.getNombreSugerido().isBlank()) {
                    sugerencia.setNombreSugerido(dto.getNombreSugerido().trim());
                }
                if (dto.getMarcaSugerida() != null && !dto.getMarcaSugerida().isBlank()) {
                    sugerencia.setMarcaSugerida(dto.getMarcaSugerida().trim());
                }
                sugerencia.setMotivo(motivo);
            } else {
                sugerencia = SugerenciaPrecioSuperadmin.builder()
                        .bodega(producto.getBodega())
                        .producto(producto)
                        .codigoBarras(ean)
                        .nombreActual(producto.getNombre())
                        .nombreSugerido(dto.getNombreSugerido() != null && !dto.getNombreSugerido().isBlank() ? dto.getNombreSugerido().trim() : null)
                        .marcaActual(producto.getMarca())
                        .marcaSugerida(dto.getMarcaSugerida() != null && !dto.getMarcaSugerida().isBlank() ? dto.getMarcaSugerida().trim() : null)
                        .precioVentaActual(producto.getPrecioVenta())
                        .precioVentaSugerido(dto.getPrecioVentaSugerido())
                        .precioCostoActual(producto.getPrecioCosto())
                        .precioCostoSugerido(dto.getPrecioCostoSugerido())
                        .motivo(motivo)
                        .estado("PENDIENTE")
                        .build();
            }

            sugerenciaPrecioRepository.save(sugerencia);
            notificadas++;
        }

        log.info("[SugerenciaPrecioService] Sugerencia de producto '{}' difundida a {} bodegas.", ean, notificadas);
        return notificadas;
    }

    @Transactional(readOnly = true)
    public long contarBodegasConProducto(String codigoBarras) {
        if (codigoBarras == null || codigoBarras.isBlank()) return 0;
        return sugerenciaPrecioRepository.countBodegasConProducto(codigoBarras.trim());
    }

    @Transactional(readOnly = true)
    public List<SugerenciaPrecioDTO> listarParaSuperadmin(String estado) {
        List<SugerenciaPrecioSuperadmin> lista;
        if (estado != null && !estado.isBlank() && !"TODOS".equalsIgnoreCase(estado)) {
            lista = sugerenciaPrecioRepository.findByEstadoOrderByFechaCreacionDesc(estado.toUpperCase().trim());
        } else {
            lista = sugerenciaPrecioRepository.findAllByOrderByFechaCreacionDesc();
        }
        return lista.stream().map(this::mapToDTO).toList();
    }

    @Transactional(readOnly = true)
    public List<SugerenciaPrecioDTO> listarParaBodegaActual(String estado) {
        Long idBodega = tenantService.getCurrentBodegaId();
        List<SugerenciaPrecioSuperadmin> lista;
        if (estado != null && !estado.isBlank() && !"TODOS".equalsIgnoreCase(estado)) {
            lista = sugerenciaPrecioRepository.findByBodega_IdBodegaAndEstadoOrderByFechaCreacionDesc(idBodega, estado.toUpperCase().trim());
        } else {
            lista = sugerenciaPrecioRepository.findByBodega_IdBodegaOrderByFechaCreacionDesc(idBodega);
        }
        return lista.stream().map(this::mapToDTO).toList();
    }

    @Transactional(readOnly = true)
    public long contarPendientesParaBodegaActual() {
        Long idBodega = tenantService.getCurrentBodegaId();
        return sugerenciaPrecioRepository.countByBodega_IdBodegaAndEstado(idBodega, "PENDIENTE");
    }

    @Transactional
    public SugerenciaPrecioDTO aceptarSugerencia(Long idSugerencia) {
        SugerenciaPrecioSuperadmin sug = sugerenciaPrecioRepository.findById(idSugerencia)
                .orElseThrow(() -> new NoSuchElementException("Sugerencia no encontrada con ID: " + idSugerencia));

        validarPertenenciaBodega(sug);

        if (!"PENDIENTE".equalsIgnoreCase(sug.getEstado())) {
            throw new IllegalStateException("La sugerencia ya se encuentra en estado: " + sug.getEstado());
        }

        Producto producto = sug.getProducto();
        if (producto != null) {
            producto.setPrecioVenta(sug.getPrecioVentaSugerido());
            if (sug.getPrecioCostoSugerido() != null) {
                producto.setPrecioCosto(sug.getPrecioCostoSugerido());
            }
            if (sug.getNombreSugerido() != null && !sug.getNombreSugerido().isBlank()) {
                producto.setNombre(sug.getNombreSugerido().trim());
            }
            if (sug.getMarcaSugerida() != null && !sug.getMarcaSugerida().isBlank()) {
                producto.setMarca(sug.getMarcaSugerida().trim());
            }
            productoRepository.save(producto);

            if (analyticsService != null && producto.getBodega() != null) {
                analyticsService.invalidateCache(producto.getBodega().getIdBodega());
            }
        }

        sug.setEstado("ACEPTADA");
        sug.setFechaResolucion(OffsetDateTime.now());
        sug.setUsuarioResolucion(obtenerUsuarioActual());
        return mapToDTO(sugerenciaPrecioRepository.save(sug));
    }

    @Transactional
    public SugerenciaPrecioDTO rechazarSugerencia(Long idSugerencia) {
        SugerenciaPrecioSuperadmin sug = sugerenciaPrecioRepository.findById(idSugerencia)
                .orElseThrow(() -> new NoSuchElementException("Sugerencia no encontrada con ID: " + idSugerencia));

        validarPertenenciaBodega(sug);

        if (!"PENDIENTE".equalsIgnoreCase(sug.getEstado())) {
            throw new IllegalStateException("La sugerencia ya se encuentra en estado: " + sug.getEstado());
        }

        sug.setEstado("RECHAZADA");
        sug.setFechaResolucion(OffsetDateTime.now());
        sug.setUsuarioResolucion(obtenerUsuarioActual());
        return mapToDTO(sugerenciaPrecioRepository.save(sug));
    }

    @Transactional
    public int aceptarTodasParaBodegaActual() {
        Long idBodega = tenantService.getCurrentBodegaId();
        List<SugerenciaPrecioSuperadmin> pendientes =
                sugerenciaPrecioRepository.findByBodega_IdBodegaAndEstadoOrderByFechaCreacionDesc(idBodega, "PENDIENTE");

        int aceptadas = 0;
        for (SugerenciaPrecioSuperadmin sug : pendientes) {
            aceptarSugerencia(sug.getIdSugerencia());
            aceptadas++;
        }
        return aceptadas;
    }

    @Transactional
    public int rechazarTodasParaBodegaActual() {
        Long idBodega = tenantService.getCurrentBodegaId();
        List<SugerenciaPrecioSuperadmin> pendientes =
                sugerenciaPrecioRepository.findByBodega_IdBodegaAndEstadoOrderByFechaCreacionDesc(idBodega, "PENDIENTE");

        int rechazadas = 0;
        for (SugerenciaPrecioSuperadmin sug : pendientes) {
            rechazarSugerencia(sug.getIdSugerencia());
            rechazadas++;
        }
        return rechazadas;
    }

    private void validarPertenenciaBodega(SugerenciaPrecioSuperadmin sug) {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        boolean esSuperAdmin = auth != null && auth.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_SUPERADMIN"));

        if (!esSuperAdmin) {
            Long currentBodegaId = tenantService.getCurrentBodegaId();
            if (sug.getBodega() == null || !sug.getBodega().getIdBodega().equals(currentBodegaId)) {
                throw new SecurityException("No tienes permisos para modificar sugerencias de otra bodega.");
            }
        }
    }

    private String obtenerUsuarioActual() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.isAuthenticated() && !"anonymousUser".equals(auth.getName())) {
            return auth.getName();
        }
        return "SISTEMA";
    }

    private SugerenciaPrecioDTO mapToDTO(SugerenciaPrecioSuperadmin s) {
        return SugerenciaPrecioDTO.builder()
                .idSugerencia(s.getIdSugerencia())
                .idBodega(s.getBodega() != null ? s.getBodega().getIdBodega() : null)
                .nombreBodega(s.getBodega() != null ? s.getBodega().getNombreComercial() : null)
                .idProducto(s.getProducto() != null ? s.getProducto().getIdProducto() : null)
                .codigoBarras(s.getCodigoBarras())
                .nombreActual(s.getNombreActual())
                .nombreSugerido(s.getNombreSugerido())
                .marcaActual(s.getMarcaActual())
                .marcaSugerida(s.getMarcaSugerida())
                .precioVentaActual(s.getPrecioVentaActual())
                .precioVentaSugerido(s.getPrecioVentaSugerido())
                .precioCostoActual(s.getPrecioCostoActual())
                .precioCostoSugerido(s.getPrecioCostoSugerido())
                .imagenUrl(s.getProducto() != null ? s.getProducto().getImagenUrl() : null)
                .motivo(s.getMotivo())
                .estado(s.getEstado())
                .fechaCreacion(s.getFechaCreacion())
                .fechaResolucion(s.getFechaResolucion())
                .usuarioResolucion(s.getUsuarioResolucion())
                .build();
    }
}
