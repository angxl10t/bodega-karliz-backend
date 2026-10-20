package com.bodega.backend.service;

import com.bodega.backend.dto.CierreCajaDTO;
import com.bodega.backend.dto.EgresoCajaDTO;
import com.bodega.backend.dto.FondoCajaDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.EgresoCaja;
import com.bodega.backend.entity.FondoCaja;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.EgresoCajaRepository;
import com.bodega.backend.repository.FondoCajaRepository;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class CajaService {

    private static final ZoneId ZONE_PERU = ZoneId.of("America/Lima");

    private final EgresoCajaRepository egresoCajaRepository;
    private final FondoCajaRepository fondoCajaRepository;
    private final BodegaRepository bodegaRepository;
    private final TenantService tenantService;
    private final VentaService ventaService;

    public CajaService(EgresoCajaRepository egresoCajaRepository,
                       FondoCajaRepository fondoCajaRepository,
                       BodegaRepository bodegaRepository,
                       TenantService tenantService,
                       VentaService ventaService) {
        this.egresoCajaRepository = egresoCajaRepository;
        this.fondoCajaRepository = fondoCajaRepository;
        this.bodegaRepository = bodegaRepository;
        this.tenantService = tenantService;
        this.ventaService = ventaService;
    }

    private String getUsuarioActual() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        return (auth != null && auth.getName() != null && !auth.getName().isBlank())
                ? auth.getName().trim()
                : "SISTEMA";
    }

    private String sanitizarTexto(String input, int maxLen, String defaultValue) {
        if (input == null || input.isBlank()) {
            return defaultValue;
        }
        String clean = input.replaceAll("[\\r\\n\\t]", " ").replaceAll("\\s+", " ").trim();
        if (clean.length() > maxLen) {
            clean = clean.substring(0, maxLen).trim();
        }
        return clean.isEmpty() ? defaultValue : clean;
    }

    @Transactional
    public EgresoCajaDTO registrarEgreso(EgresoCajaDTO dto) {
        if (dto.getMonto() == null || dto.getMonto().compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("El monto del egreso debe ser mayor a cero");
        }

        Long idBodega = tenantService.getCurrentBodegaId();
        Bodega bodega = bodegaRepository.findById(idBodega)
                .orElseThrow(() -> new RuntimeException("Bodega no encontrada con ID: " + idBodega));

        EgresoCaja egreso = new EgresoCaja();
        egreso.setBodega(bodega);
        egreso.setMonto(dto.getMonto());
        egreso.setMotivo(sanitizarTexto(dto.getMotivo(), 255, "Gasto menor de caja chica"));
        egreso.setCategoriaGasto(sanitizarTexto(dto.getCategoriaGasto(), 50, "VARIOS").toUpperCase());
        egreso.setUsuarioRegistro(getUsuarioActual());
        egreso.setEstado(true);
        egreso.setFechaEgreso(OffsetDateTime.now(ZONE_PERU));

        EgresoCaja guardado = egresoCajaRepository.save(egreso);
        return mapToEgresoDTO(guardado);
    }

    @Transactional(readOnly = true)
    public List<EgresoCajaDTO> listarEgresos(LocalDate fecha) {
        Long idBodega = tenantService.getCurrentBodegaId();
        LocalDate targetFecha = (fecha != null) ? fecha : LocalDate.now(ZONE_PERU);

        OffsetDateTime inicio = targetFecha.atStartOfDay(ZONE_PERU).toOffsetDateTime();
        OffsetDateTime fin = targetFecha.atTime(23, 59, 59, 999999999).atZone(ZONE_PERU).toOffsetDateTime();

        return egresoCajaRepository
                .findByBodega_IdBodegaAndFechaEgresoBetweenAndEstadoTrueOrderByFechaEgresoDesc(idBodega, inicio, fin)
                .stream()
                .map(this::mapToEgresoDTO)
                .collect(Collectors.toList());
    }

    @Transactional
    public void anularEgreso(Long idEgreso, String motivo) {
        Long idBodega = tenantService.getCurrentBodegaId();
        EgresoCaja egreso = egresoCajaRepository.findByIdEgresoAndBodega_IdBodega(idEgreso, idBodega)
                .orElseThrow(() -> new RuntimeException("Egreso de caja no encontrado con ID: " + idEgreso));

        if (Boolean.FALSE.equals(egreso.getEstado())) {
            throw new IllegalStateException("El egreso ya fue anulado previamente");
        }

        egreso.setEstado(false);
        egreso.setUsuarioAnulacion(getUsuarioActual());
        egreso.setMotivoAnulacion(sanitizarTexto(motivo, 255, "Anulación administrativa"));
        egreso.setFechaAnulacion(OffsetDateTime.now(ZONE_PERU));

        egresoCajaRepository.save(egreso);
    }

    @Transactional
    public FondoCajaDTO registrarFondoInicial(FondoCajaDTO dto) {
        if (dto.getMontoInicial() == null || dto.getMontoInicial().compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("El monto inicial no puede ser negativo");
        }

        Long idBodega = tenantService.getCurrentBodegaId();
        Bodega bodega = bodegaRepository.findById(idBodega)
                .orElseThrow(() -> new RuntimeException("Bodega no encontrada con ID: " + idBodega));

        LocalDate targetFecha = (dto.getFecha() != null) ? dto.getFecha() : LocalDate.now(ZONE_PERU);

        FondoCaja fondo = fondoCajaRepository.findByBodega_IdBodegaAndFecha(idBodega, targetFecha)
                .orElseGet(() -> {
                    FondoCaja f = new FondoCaja();
                    f.setBodega(bodega);
                    f.setFecha(targetFecha);
                    return f;
                });

        fondo.setMontoInicial(dto.getMontoInicial());
        fondo.setUsuarioRegistro(getUsuarioActual());
        fondo.setFechaRegistro(OffsetDateTime.now(ZONE_PERU));

        FondoCaja guardado = fondoCajaRepository.save(fondo);
        return mapToFondoDTO(guardado);
    }

    @Transactional(readOnly = true)
    public FondoCajaDTO obtenerFondoInicial(LocalDate fecha) {
        Long idBodega = tenantService.getCurrentBodegaId();
        LocalDate targetFecha = (fecha != null) ? fecha : LocalDate.now(ZONE_PERU);

        return fondoCajaRepository.findByBodega_IdBodegaAndFecha(idBodega, targetFecha)
                .map(this::mapToFondoDTO)
                .orElseGet(() -> {
                    FondoCajaDTO dto = new FondoCajaDTO();
                    dto.setMontoInicial(BigDecimal.ZERO);
                    dto.setFecha(targetFecha);
                    return dto;
                });
    }

    @Transactional(readOnly = true)
    public CierreCajaDTO obtenerArqueoCompleto(LocalDate fecha) {
        LocalDate targetFecha = (fecha != null) ? fecha : LocalDate.now(ZONE_PERU);
        CierreCajaDTO cierre = ventaService.obtenerCierreCajaPorFecha(targetFecha);

        FondoCajaDTO fondoDTO = obtenerFondoInicial(targetFecha);
        List<EgresoCajaDTO> egresos = listarEgresos(targetFecha);

        BigDecimal totalEgresos = egresos.stream()
                .map(EgresoCajaDTO::getMonto)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        BigDecimal fondoInicial = fondoDTO.getMontoInicial() != null ? fondoDTO.getMontoInicial() : BigDecimal.ZERO;
        BigDecimal efectivoVentas = cierre.getTotalEfectivo() != null ? cierre.getTotalEfectivo() : BigDecimal.ZERO;
        BigDecimal totalEfectivoEsperado = fondoInicial.add(efectivoVentas).subtract(totalEgresos);

        cierre.setFondoInicial(fondoInicial);
        cierre.setTotalEgresos(totalEgresos);
        cierre.setTotalEfectivoEsperado(totalEfectivoEsperado);
        cierre.setEgresos(egresos);

        return cierre;
    }

    private EgresoCajaDTO mapToEgresoDTO(EgresoCaja entity) {
        EgresoCajaDTO dto = new EgresoCajaDTO();
        dto.setIdEgreso(entity.getIdEgreso());
        dto.setMonto(entity.getMonto());
        dto.setMotivo(entity.getMotivo());
        dto.setCategoriaGasto(entity.getCategoriaGasto());
        dto.setFechaEgreso(entity.getFechaEgreso());
        dto.setUsuarioRegistro(entity.getUsuarioRegistro());
        dto.setEstado(entity.getEstado());
        dto.setUsuarioAnulacion(entity.getUsuarioAnulacion());
        dto.setMotivoAnulacion(entity.getMotivoAnulacion());
        dto.setFechaAnulacion(entity.getFechaAnulacion());
        return dto;
    }

    private FondoCajaDTO mapToFondoDTO(FondoCaja entity) {
        FondoCajaDTO dto = new FondoCajaDTO();
        dto.setIdFondoCaja(entity.getIdFondoCaja());
        dto.setMontoInicial(entity.getMontoInicial());
        dto.setFecha(entity.getFecha());
        dto.setUsuarioRegistro(entity.getUsuarioRegistro());
        dto.setFechaRegistro(entity.getFechaRegistro());
        return dto;
    }
}
