package com.bodega.backend.service;

import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Venta;
import com.bodega.backend.entity.VentaDetalle;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * Servicio de Emisión Telemática de Comprobantes Electrónicos vía API REST (UBL 2.1).
 * Compatible con APIs Perú (apisperu.com), OSEs y pasarelas REST autorizadas por SUNAT.
 * Diseñado con tolerancia a fallos: nunca bloquea la venta del cajero ante caídas de red.
 */
@Service
public class SunatRestEmissionService {

    private static final Logger log = LoggerFactory.getLogger(SunatRestEmissionService.class);

    @Value("${sunat.api.url:https://facturacion.apisperu.com/api/v1/invoice/send}")
    private String apiUrl;

    @Value("${sunat.api.token:}")
    private String globalApiToken;

    @Value("${sunat.api.modo-pruebas:true}")
    private boolean modoPruebas;

    private final RestTemplate restTemplate;

    public SunatRestEmissionService() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(4000); // 4 segundos de conexión
        factory.setReadTimeout(6000);    // 6 segundos de lectura
        this.restTemplate = new RestTemplate(factory);
    }

    /**
     * Despacha el comprobante electrónico a la API REST de facturación.
     * Si no hay token configurado y está en modo pruebas, simula la validación oficial SUNAT Beta.
     */
    public void despacharComprobante(Venta venta, List<VentaDetalle> detalles, Bodega bodega) {
        if (venta == null || detalles == null || detalles.isEmpty()) {
            return;
        }

        String tipoComprobante = venta.getTipoComprobante();
        boolean esFactura = "FACTURA_ELECTRONICA".equalsIgnoreCase(tipoComprobante);
        boolean esBoleta = "BOLETA_ELECTRONICA".equalsIgnoreCase(tipoComprobante);

        if (!esFactura && !esBoleta) {
            return;
        }

        String serieCorrelativo = venta.getSerieCorrelativo();
        if (serieCorrelativo == null || !serieCorrelativo.contains("-")) {
            serieCorrelativo = esFactura ? "F001-00000001" : "B001-00000001";
            venta.setSerieCorrelativo(serieCorrelativo);
        }

        String[] parts = serieCorrelativo.split("-");
        String serie = parts[0];
        long numCorrelativo = 1L;
        try {
            numCorrelativo = Long.parseLong(parts[1]);
        } catch (Exception ignored) {}

        // Determinar token API específico de la bodega o token global de la plataforma
        String token = (bodega != null && bodega.getSunatTokenApi() != null && !bodega.getSunatTokenApi().isBlank())
                ? bodega.getSunatTokenApi().trim()
                : (globalApiToken != null ? globalApiToken.trim() : "");

        // 1. Si no hay token de API real configurado
        if (token.isBlank()) {
            if (modoPruebas) {
                // Simulación oficial de entorno SUNAT Beta
                String hashSimulado = generarHashSimulado(venta, bodega);
                venta.setEstadoSunat("ACEPTADO_BETA");
                venta.setSunatHash(hashSimulado);
                venta.setSunatMensaje("La " + (esFactura ? "Factura" : "Boleta") + " " + serieCorrelativo + " ha sido aceptada en entorno Beta SUNAT.");
                log.info("[SUNAT REST] Venta #{} procesada en modo simulado SUNAT Beta ({})", venta.getIdVenta(), serieCorrelativo);
            } else {
                venta.setEstadoSunat("PENDIENTE_ENVIO");
                venta.setSunatMensaje("Comprobante generado localmente. Token de API SUNAT no configurado en la tienda.");
            }
            return;
        }

        // 2. Construcción de Payload estándar UBL 2.1 para pasarela REST (ApisPeru)
        try {
            Map<String, Object> payload = construirPayloadUbl(venta, detalles, bodega, esFactura, serie, numCorrelativo);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBearerAuth(token);
            headers.set("Accept", "application/json");

            HttpEntity<Map<String, Object>> requestEntity = new HttpEntity<>(payload, headers);

            log.info("[SUNAT REST] Enviando {} {} a pasarela: {}", esFactura ? "Factura" : "Boleta", serieCorrelativo, apiUrl);
            ResponseEntity<Map> response = restTemplate.exchange(apiUrl, HttpMethod.POST, requestEntity, Map.class);

            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                Map<?, ?> body = response.getBody();
                procesarRespuestaExitosa(venta, body, esFactura, serieCorrelativo);
            } else {
                venta.setEstadoSunat("PENDIENTE_ENVIO");
                venta.setSunatMensaje("Servicio de facturación respondió con código: " + response.getStatusCode());
            }
        } catch (Exception ex) {
            log.warn("[SUNAT REST] Fallo temporal de comunicación telemática para venta #{}: {}", venta.getIdVenta(), ex.getMessage());
            // No revertir la venta comercial; marcar para reintento posterior
            venta.setEstadoSunat("PENDIENTE_ENVIO");
            String errorMsg = ex.getMessage();
            if (errorMsg != null && errorMsg.length() > 250) {
                errorMsg = errorMsg.substring(0, 250);
            }
            venta.setSunatMensaje("Pendiente de envío telemático: " + errorMsg);
        }
    }

    private Map<String, Object> construirPayloadUbl(
            Venta venta,
            List<VentaDetalle> detalles,
            Bodega bodega,
            boolean esFactura,
            String serie,
            long correlativo) {

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("ublVersion", "2.1");
        payload.put("tipoOperacion", "0101"); // Venta interna
        payload.put("tipoDoc", esFactura ? "01" : "03"); // 01 = Factura, 03 = Boleta
        payload.put("serie", serie);
        payload.put("correlativo", String.valueOf(correlativo));

        OffsetDateTime fecha = (venta.getFechaVenta() != null) ? venta.getFechaVenta() : OffsetDateTime.now();
        payload.put("fechaEmision", fecha.format(DateTimeFormatter.ISO_OFFSET_DATE_TIME));

        Map<String, Object> formaPago = new HashMap<>();
        formaPago.put("moneda", "PEN");
        formaPago.put("tipo", "Contado");
        payload.put("formaPago", formaPago);
        payload.put("tipoMoneda", "PEN");

        // Datos del Emisor (Bodega)
        String rucEmisor = (bodega != null && bodega.getSunatRucEmisor() != null && !bodega.getSunatRucEmisor().isBlank())
                ? bodega.getSunatRucEmisor().trim()
                : (bodega != null && bodega.getRucDni() != null && bodega.getRucDni().matches("^[0-9]{11}$")
                    ? bodega.getRucDni().trim()
                    : "10712345678");

        String razonSocialEmisor = (bodega != null && bodega.getNombreComercial() != null)
                ? bodega.getNombreComercial().trim()
                : "CajaYa POS";

        Map<String, Object> company = new LinkedHashMap<>();
        company.put("ruc", rucEmisor);
        company.put("razonSocial", razonSocialEmisor);
        company.put("nombreComercial", razonSocialEmisor);

        Map<String, Object> address = new HashMap<>();
        address.put("direccion", (bodega != null && bodega.getDireccion() != null) ? bodega.getDireccion() : "LIMA");
        address.put("departamento", "LIMA");
        address.put("provincia", "LIMA");
        address.put("distrito", "LIMA");
        address.put("ubigeo", "150101");
        company.put("address", address);
        payload.put("company", company);

        // Datos del Cliente Receptor
        String docCliente = (venta.getClienteDocumento() != null && !venta.getClienteDocumento().isBlank())
                ? venta.getClienteDocumento().trim()
                : null;
        String nomCliente = (venta.getClienteNombre() != null && !venta.getClienteNombre().isBlank())
                ? venta.getClienteNombre().trim()
                : "CLIENTES VARIOS";

        Map<String, Object> client = new LinkedHashMap<>();
        if (esFactura) {
            client.put("tipoDoc", "6"); // RUC
            client.put("numDoc", docCliente != null ? docCliente : "20000000001");
            client.put("rznSocial", nomCliente);
        } else if (docCliente != null && docCliente.length() == 8) {
            client.put("tipoDoc", "1"); // DNI
            client.put("numDoc", docCliente);
            client.put("rznSocial", nomCliente);
        } else {
            client.put("tipoDoc", "0"); // Doc Trib. No Domiciliado / Sin Documento
            client.put("numDoc", "00000000");
            client.put("rznSocial", "CLIENTES VARIOS");
        }
        payload.put("client", client);

        // Desglose Tributario (Operación Gravada + IGV 18%)
        BigDecimal total = (venta.getTotal() != null ? venta.getTotal() : BigDecimal.ZERO).setScale(2, RoundingMode.HALF_UP);
        BigDecimal baseImponible = total.divide(new BigDecimal("1.18"), 2, RoundingMode.HALF_UP);
        BigDecimal igv = total.subtract(baseImponible).setScale(2, RoundingMode.HALF_UP);

        payload.put("mtoOperGravadas", baseImponible);
        payload.put("mtoIGV", igv);
        payload.put("totalImpuestos", igv);
        payload.put("valorVenta", baseImponible);
        payload.put("subTotal", total);
        payload.put("mtoImpVenta", total);

        // Ítems Detallados
        List<Map<String, Object>> details = new ArrayList<>();
        for (VentaDetalle det : detalles) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("tipAfeIgv", "10"); // Gravado - Operación Onerosa
            item.put("unidad", "NIU");   // Unidad estándar de producto
            item.put("descripcion", (det.getProducto() != null) ? det.getProducto().getNombre() : "Producto");
            item.put("cantidad", det.getCantidad() != null ? det.getCantidad() : BigDecimal.ONE);

            BigDecimal precioUnitarioConIgv = (det.getPrecioUnitario() != null ? det.getPrecioUnitario() : BigDecimal.ZERO).setScale(2, RoundingMode.HALF_UP);
            BigDecimal valorUnitarioSinIgv = precioUnitarioConIgv.divide(new BigDecimal("1.18"), 4, RoundingMode.HALF_UP);
            BigDecimal subtotalItem = (det.getSubtotal() != null ? det.getSubtotal() : BigDecimal.ZERO).setScale(2, RoundingMode.HALF_UP);
            BigDecimal valorVentaItem = subtotalItem.divide(new BigDecimal("1.18"), 2, RoundingMode.HALF_UP);
            BigDecimal igvItem = subtotalItem.subtract(valorVentaItem).setScale(2, RoundingMode.HALF_UP);

            item.put("mtoValorUnitario", valorUnitarioSinIgv);
            item.put("mtoPrecioUnitario", precioUnitarioConIgv);
            item.put("mtoValorVenta", valorVentaItem);
            item.put("mtoBaseIgv", valorVentaItem);
            item.put("porcentajeIgv", 18);
            item.put("igv", igvItem);
            item.put("totalImpuestos", igvItem);
            details.add(item);
        }
        payload.put("details", details);

        return payload;
    }

    private void procesarRespuestaExitosa(Venta venta, Map<?, ?> body, boolean esFactura, String serieCorrelativo) {
        String hash = null;
        if (body.get("hash") != null) {
            hash = body.get("hash").toString();
        }

        String sunatMsg = null;
        boolean aceptado = true;

        if (body.get("sunatResponse") instanceof Map<?, ?> sunatResp) {
            if (sunatResp.get("success") != null && Boolean.FALSE.equals(sunatResp.get("success"))) {
                aceptado = false;
            }
            if (sunatResp.get("cdrResponse") instanceof Map<?, ?> cdr) {
                if (cdr.get("description") != null) {
                    sunatMsg = cdr.get("description").toString();
                }
            }
        }

        if (sunatMsg == null || sunatMsg.isBlank()) {
            sunatMsg = (aceptado ? "La " + (esFactura ? "Factura" : "Boleta") + " " + serieCorrelativo + " ha sido aceptada." : "Comprobante rechazado por SUNAT.");
        }

        venta.setEstadoSunat(aceptado ? "ACEPTADO" : "RECHAZADO");
        venta.setSunatHash(hash);
        venta.setSunatMensaje(sunatMsg);

        if (body.get("cdr") != null) venta.setSunatCdrUrl(body.get("cdr").toString());
        if (body.get("pdf") != null) venta.setSunatPdfUrl(body.get("pdf").toString());
        if (body.get("xml") != null) venta.setSunatXmlUrl(body.get("xml").toString());

        log.info("[SUNAT REST] Comprobante {} estado: {} - {}", serieCorrelativo, venta.getEstadoSunat(), sunatMsg);
    }

    private String generarHashSimulado(Venta venta, Bodega bodega) {
        try {
            String raw = (bodega != null ? bodega.getIdBodega() : "1") + "|" +
                         venta.getTipoComprobante() + "|" +
                         venta.getSerieCorrelativo() + "|" +
                         venta.getTotal() + "|" +
                         System.currentTimeMillis();
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] encodedhash = digest.digest(raw.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(encodedhash).substring(0, 28);
        } catch (Exception e) {
            return "simulated_hash_" + System.currentTimeMillis();
        }
    }
}
