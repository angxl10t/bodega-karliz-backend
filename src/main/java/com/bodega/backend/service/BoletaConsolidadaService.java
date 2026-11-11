package com.bodega.backend.service;

import com.bodega.backend.dto.BoletaConsolidadaDTO;
import com.bodega.backend.dto.RegistrarBoletaConsolidadaDTO;
import com.bodega.backend.dto.ResumenVentasMenoresDTO;
import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.BoletaConsolidada;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.BoletaConsolidadaRepository;
import com.bodega.backend.repository.VentaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class BoletaConsolidadaService {

    private final BoletaConsolidadaRepository boletaConsolidadaRepository;
    private final VentaRepository ventaRepository;
    private final BodegaRepository bodegaRepository;
    private final TenantService tenantService;

    private static final ZoneId ZONE_LIMA = ZoneId.of("America/Lima");
    private static final BigDecimal LIMITE_MENOR = new BigDecimal("5.00");
    private static final String BASE_LEGAL = "Res. de Superintendencia N° 007-99/SUNAT (Art. 8, Num 3.2): " +
            "En operaciones con consumidores finales <= S/ 5.00 sin comprobante individual, se emite una sola Boleta de Venta al final del día.";

    /**
     * Obtiene el resumen del día para orientar al bodeguero:
     * Calcula la suma y conteo de tickets <= S/ 5.00 del día y verifica si ya se registró la boleta.
     */
    @Transactional(readOnly = true)
    public ResumenVentasMenoresDTO obtenerSugerencia(LocalDate fechaParam) {
        Long idBodega = tenantService.getCurrentBodegaId();
        LocalDate fecha = (fechaParam != null) ? fechaParam : LocalDate.now(ZONE_LIMA);

        OffsetDateTime start = fecha.atStartOfDay(ZONE_LIMA).toOffsetDateTime();
        OffsetDateTime end = fecha.plusDays(1).atStartOfDay(ZONE_LIMA).toOffsetDateTime();

        BigDecimal montoSugerido = ventaRepository.sumVentasMenores(idBodega, LIMITE_MENOR, start, end);
        if (montoSugerido == null) {
            montoSugerido = BigDecimal.ZERO;
        }
        long countSugerido = ventaRepository.countVentasMenores(idBodega, LIMITE_MENOR, start, end);

        Optional<BoletaConsolidada> optExistente = boletaConsolidadaRepository.findByBodega_IdBodegaAndFechaEmision(idBodega, fecha);

        if (optExistente.isPresent()) {
            BoletaConsolidada bc = optExistente.get();
            return ResumenVentasMenoresDTO.builder()
                    .fecha(fecha)
                    .yaRegistrada(true)
                    .idBoletaConsolidada(bc.getIdBoletaConsolidada())
                    .serieCorrelativo(bc.getSerieCorrelativo())
                    .tipoEmision(bc.getTipoEmision())
                    .montoRegistrado(bc.getMontoTotal())
                    .cantidadOperacionesRegistradas(bc.getCantidadOperaciones())
                    .observaciones(bc.getObservaciones())
                    .usuarioRegistro(bc.getUsuarioRegistro())
                    .fechaRegistro(bc.getFechaRegistro())
                    .montoSugerido(montoSugerido.setScale(2, RoundingMode.HALF_UP))
                    .cantidadOperacionesSugeridas((int) countSugerido)
                    .baseLegal(BASE_LEGAL)
                    .build();
        } else {
            return ResumenVentasMenoresDTO.builder()
                    .fecha(fecha)
                    .yaRegistrada(false)
                    .montoSugerido(montoSugerido.setScale(2, RoundingMode.HALF_UP))
                    .cantidadOperacionesSugeridas((int) countSugerido)
                    .baseLegal(BASE_LEGAL)
                    .build();
        }
    }

    /**
     * Permite al bodeguero registrar manualmente o actualizar la Boleta Consolidada de un día específico.
     */
    @Transactional
    public BoletaConsolidadaDTO registrarBoletaConsolidada(RegistrarBoletaConsolidadaDTO dto) {
        Long idBodega = tenantService.getCurrentBodegaId();
        Bodega bodega = bodegaRepository.findById(idBodega)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Bodega no encontrada"));

        String usuarioActual = obtenerUsuarioActual();

        // Buscar si ya existe una boleta para esa fecha para actualizarla o crear nueva
        BoletaConsolidada bc = boletaConsolidadaRepository.findByBodegaAndFechaEmisionForUpdate(idBodega, dto.getFecha())
                .or(() -> boletaConsolidadaRepository.findByBodega_IdBodegaAndFechaEmision(idBodega, dto.getFecha()))
                .orElse(new BoletaConsolidada());

        bc.setBodega(bodega);
        bc.setFechaEmision(dto.getFecha());
        bc.setMontoTotal(dto.getMontoTotal().setScale(2, RoundingMode.HALF_UP));
        bc.setCantidadOperaciones(dto.getCantidadOperaciones());
        bc.setSerieCorrelativo(dto.getSerieCorrelativo().trim().toUpperCase());
        bc.setTipoEmision(dto.getTipoEmision() != null && !dto.getTipoEmision().isBlank()
                ? dto.getTipoEmision().trim().toUpperCase()
                : "TALONARIO_FISICO");
        bc.setObservaciones(dto.getObservaciones() != null ? dto.getObservaciones().trim() : null);
        bc.setUsuarioRegistro(usuarioActual);

        BoletaConsolidada guardada = boletaConsolidadaRepository.save(bc);
        log.info("Boleta Consolidada Diaria registrada exitosamente [bodega={}, fecha={}, serie={}, monto=S/ {}]",
                idBodega, guardada.getFechaEmision(), guardada.getSerieCorrelativo(), guardada.getMontoTotal());

        return mapToDTO(guardada);
    }

    /**
     * Lista el historial de boletas consolidadas de la bodega.
     */
    @Transactional(readOnly = true)
    public List<BoletaConsolidadaDTO> listarHistorial(Integer limit) {
        Long idBodega = tenantService.getCurrentBodegaId();
        List<BoletaConsolidada> lista;
        if (limit != null && limit > 0 && limit <= 30) {
            lista = boletaConsolidadaRepository.findTop30ByBodega_IdBodegaOrderByFechaEmisionDesc(idBodega);
        } else {
            lista = boletaConsolidadaRepository.findByBodega_IdBodegaOrderByFechaEmisionDesc(idBodega);
        }
        return lista.stream().map(this::mapToDTO).collect(Collectors.toList());
    }

    private BoletaConsolidadaDTO mapToDTO(BoletaConsolidada bc) {
        return BoletaConsolidadaDTO.builder()
                .idBoletaConsolidada(bc.getIdBoletaConsolidada())
                .idBodega(bc.getBodega() != null ? bc.getBodega().getIdBodega() : null)
                .fechaEmision(bc.getFechaEmision())
                .montoTotal(bc.getMontoTotal())
                .cantidadOperaciones(bc.getCantidadOperaciones())
                .serieCorrelativo(bc.getSerieCorrelativo())
                .tipoEmision(bc.getTipoEmision())
                .observaciones(bc.getObservaciones())
                .usuarioRegistro(bc.getUsuarioRegistro())
                .fechaRegistro(bc.getFechaRegistro())
                .build();
    }

    private String obtenerUsuarioActual() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.isAuthenticated() && !"anonymousUser".equals(auth.getName())) {
            return auth.getName();
        }
        return "Cajero Mostrador";
    }
}
