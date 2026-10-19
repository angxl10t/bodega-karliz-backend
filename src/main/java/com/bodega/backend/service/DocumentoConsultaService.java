package com.bodega.backend.service;

import com.bodega.backend.dto.DniConsultaDTO;
import com.bodega.backend.dto.RucConsultaDTO;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Servicio BFF (Backend For Frontend) para consultas de RENIEC y SUNAT.
 * Centraliza las peticiones a APIs externas, protege las credenciales mediante
 * variables de entorno en el servidor y optimiza las cuotas con caché en memoria.
 */
@Service
public class DocumentoConsultaService {

    private static final Logger log = LoggerFactory.getLogger(DocumentoConsultaService.class);

    @Value("${peru.api.token:}")
    private String apiToken;

    @Value("${peru.api.url.dni:https://api.apis.net.pe/v2/reniec/dni}")
    private String apiUrlDni;

    @Value("${peru.api.url.ruc:https://api.apis.net.pe/v2/sunat/ruc}")
    private String apiUrlRuc;

    private final RestTemplate restTemplate;

    // Caché en memoria para evitar consultas duplicadas y ahorrar cuotas de peticiones
    private final Map<String, CacheEntry<DniConsultaDTO>> cacheDni = new ConcurrentHashMap<>();
    private final Map<String, CacheEntry<RucConsultaDTO>> cacheRuc = new ConcurrentHashMap<>();
    private static final long CACHE_TTL_MS = 24 * 60 * 60 * 1000L; // 24 horas

    public DocumentoConsultaService() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(4000);
        factory.setReadTimeout(6000);
        this.restTemplate = new RestTemplate(factory);
    }

    /**
     * Consulta de DNI mediante RENIEC / Proxy BFF
     */
    public DniConsultaDTO consultarDni(String numero) {
        if (numero == null || !numero.trim().matches("^[0-9]{8}$")) {
            throw new RuntimeException("El DNI debe contener exactamente 8 dígitos numéricos.");
        }
        String dni = numero.trim();

        // 1. Revisar caché en memoria
        CacheEntry<DniConsultaDTO> cached = cacheDni.get(dni);
        if (cached != null && !cached.isExpired(CACHE_TTL_MS)) {
            DniConsultaDTO dto = cached.data;
            dto.setFuente("CACHE_LOCAL");
            return dto;
        }

        // 2. Si hay token de API configurado, consultar servicio externo (apis.net.pe)
        if (apiToken != null && !apiToken.isBlank()) {
            try {
                HttpHeaders headers = new HttpHeaders();
                headers.setBearerAuth(apiToken.trim());
                headers.set("Accept", "application/json");
                HttpEntity<Void> entity = new HttpEntity<>(headers);

                String url = apiUrlDni.contains("?") 
                        ? apiUrlDni + "&numero=" + dni 
                        : apiUrlDni + "?numero=" + dni;

                ResponseEntity<Map> response = restTemplate.exchange(url, HttpMethod.GET, entity, Map.class);
                if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                    Map<?, ?> body = response.getBody();
                    if (body.get("data") instanceof Map) {
                        body = (Map<?, ?>) body.get("data");
                    }
                    String nombres = getStr(body, "nombres");
                    if (nombres == null) nombres = getStr(body, "nombre");
                    if (nombres == null) nombres = getStr(body, "first_name");

                    String apePat = getStr(body, "apellidoPaterno");
                    if (apePat == null) apePat = getStr(body, "apellido_paterno");
                    if (apePat == null) apePat = getStr(body, "paterno");

                    String apeMat = getStr(body, "apellidoMaterno");
                    if (apeMat == null) apeMat = getStr(body, "apellido_materno");
                    if (apeMat == null) apeMat = getStr(body, "materno");

                    String nombreCompleto = getStr(body, "nombreCompleto");
                    if (nombreCompleto == null) nombreCompleto = getStr(body, "nombre_completo");

                    if ((nombreCompleto == null || nombreCompleto.isBlank()) && (nombres != null)) {
                        nombreCompleto = (nombres + " " + (apePat != null ? apePat : "") + " " + (apeMat != null ? apeMat : "")).trim();
                    }

                    DniConsultaDTO dto = DniConsultaDTO.builder()
                            .numero(dni)
                            .nombres(nombres)
                            .apellidoPaterno(apePat)
                            .apellidoMaterno(apeMat)
                            .nombreCompleto(nombreCompleto != null ? nombreCompleto.toUpperCase() : "")
                            .tipoDocumento("1")
                            .encontrado(true)
                            .mensaje("Consulta exitosa vía RENIEC")
                            .fuente("RENIEC_API")
                            .build();

                    guardarEnCacheDni(dni, dto);
                    return dto;
                }
            } catch (Exception e) {
                log.warn("[DocumentoConsultaService] Error al consultar DNI {} en API externa: {}", dni, e.getMessage());
            }
        }

        // 3. Fallback Resiliente: Formato válido sin conexión a API externa
        return DniConsultaDTO.builder()
                .numero(dni)
                .nombreCompleto("")
                .encontrado(false)
                .mensaje("Consulta externa no configurada o no disponible. Digite el nombre manualmente.")
                .fuente("FALLBACK_OFFLINE")
                .build();
    }

    /**
     * Consulta de RUC mediante SUNAT / Proxy BFF
     */
    public RucConsultaDTO consultarRuc(String numero) {
        if (numero == null || !numero.trim().matches("^[0-9]{11}$")) {
            throw new RuntimeException("El RUC debe contener exactamente 11 dígitos numéricos.");
        }
        String ruc = numero.trim();

        // 1. Revisar caché en memoria
        CacheEntry<RucConsultaDTO> cached = cacheRuc.get(ruc);
        if (cached != null && !cached.isExpired(CACHE_TTL_MS)) {
            RucConsultaDTO dto = cached.data;
            dto.setFuente("CACHE_LOCAL");
            return dto;
        }

        // 2. Si hay token de API configurado, consultar servicio externo (apis.net.pe o apiperu.dev)
        if (apiToken != null && !apiToken.isBlank()) {
            try {
                HttpHeaders headers = new HttpHeaders();
                headers.setBearerAuth(apiToken.trim());
                headers.set("Accept", "application/json");
                HttpEntity<Void> entity = new HttpEntity<>(headers);

                String url = apiUrlRuc.contains("?") 
                        ? apiUrlRuc + "&numero=" + ruc 
                        : apiUrlRuc + "?numero=" + ruc;

                ResponseEntity<Map> response = restTemplate.exchange(url, HttpMethod.GET, entity, Map.class);
                if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                    Map<?, ?> body = response.getBody();
                    if (body.get("data") instanceof Map) {
                        body = (Map<?, ?>) body.get("data");
                    }
                    String razonSocial = getStr(body, "razonSocial");
                    if (razonSocial == null) razonSocial = getStr(body, "razon_social");
                    if (razonSocial == null) razonSocial = getStr(body, "nombre_o_razon_social");
                    if (razonSocial == null) razonSocial = getStr(body, "nombre");

                    String estado = getStr(body, "estado");
                    if (estado == null) estado = getStr(body, "estado_del_contribuyente");

                    String condicion = getStr(body, "condicion");
                    if (condicion == null) condicion = getStr(body, "condicion_de_domicilio");

                    String direccion = getStr(body, "direccion");
                    if (direccion == null) direccion = getStr(body, "direccion_completa");
                    if (direccion == null) direccion = getStr(body, "domicilio_fiscal");

                    String departamento = getStr(body, "departamento");
                    String provincia = getStr(body, "provincia");
                    String distrito = getStr(body, "distrito");
                    String ubigeo = getStr(body, "ubigeo");

                    boolean esActivo = "ACTIVO".equalsIgnoreCase(estado);
                    boolean esHabido = "HABIDO".equalsIgnoreCase(condicion);

                    RucConsultaDTO dto = RucConsultaDTO.builder()
                            .numero(ruc)
                            .razonSocial(razonSocial != null ? razonSocial.toUpperCase() : "")
                            .estado(estado != null ? estado.toUpperCase() : "DESCONOCIDO")
                            .condicion(condicion != null ? condicion.toUpperCase() : "DESCONOCIDO")
                            .direccion(direccion)
                            .departamento(departamento)
                            .provincia(provincia)
                            .distrito(distrito)
                            .ubigeo(ubigeo)
                            .esActivo(esActivo)
                            .esHabido(esHabido)
                            .encontrado(true)
                            .mensaje(esActivo && esHabido ? "RUC activo y habido" : "RUC requiere atención: " + estado + " / " + condicion)
                            .fuente("SUNAT_API")
                            .build();

                    guardarEnCacheRuc(ruc, dto);
                    return dto;
                }
            } catch (Exception e) {
                log.warn("[DocumentoConsultaService] Error al consultar RUC {} en API externa: {}", ruc, e.getMessage());
            }
        }

        // 3. Fallback Resiliente con validación algorítmica Módulo 11
        boolean checksumValido = validarRucAlgoritmo(ruc);
        return RucConsultaDTO.builder()
                .numero(ruc)
                .razonSocial("")
                .estado(checksumValido ? "ACTIVO" : "NO_VALIDO")
                .condicion(checksumValido ? "HABIDO" : "NO_HABIDO")
                .esActivo(checksumValido)
                .esHabido(checksumValido)
                .encontrado(false)
                .mensaje(checksumValido 
                        ? "Formato de RUC válido. Digite la Razón Social manualmente." 
                        : "El número no cumple con el algoritmo Módulo 11 de la SUNAT.")
                .fuente(checksumValido ? "VALIDACION_LOCAL_MODULO11" : "FORMATO_INVALIDO")
                .build();
    }

    private void guardarEnCacheDni(String dni, DniConsultaDTO dto) {
        if (cacheDni.size() >= 5000) {
            cacheDni.entrySet().removeIf(e -> e.getValue().isExpired(CACHE_TTL_MS));
            if (cacheDni.size() >= 5000) cacheDni.clear();
        }
        cacheDni.put(dni, new CacheEntry<>(dto));
    }

    private void guardarEnCacheRuc(String ruc, RucConsultaDTO dto) {
        if (cacheRuc.size() >= 5000) {
            cacheRuc.entrySet().removeIf(e -> e.getValue().isExpired(CACHE_TTL_MS));
            if (cacheRuc.size() >= 5000) cacheRuc.clear();
        }
        cacheRuc.put(ruc, new CacheEntry<>(dto));
    }

    /**
     * Validador algorítmico Módulo 11 para RUC peruano:
     * Prefijos permitidos: 10 (persona natural), 15, 17, 20 (persona jurídica)
     */
    public static boolean validarRucAlgoritmo(String ruc) {
        if (ruc == null || ruc.length() != 11 || !ruc.matches("^[0-9]{11}$")) {
            return false;
        }
        String prefijo = ruc.substring(0, 2);
        if (!prefijo.equals("10") && !prefijo.equals("15") && !prefijo.equals("17") && !prefijo.equals("20")) {
            return false;
        }

        int[] factores = {5, 4, 3, 2, 7, 6, 5, 4, 3, 2};
        int suma = 0;
        for (int i = 0; i < 10; i++) {
            suma += Character.getNumericValue(ruc.charAt(i)) * factores[i];
        }

        int residuo = 11 - (suma % 11);
        int digitoVerificador = (residuo == 10) ? 0 : ((residuo == 11) ? 1 : residuo);

        return digitoVerificador == Character.getNumericValue(ruc.charAt(10));
    }

    private String getStr(Map<?, ?> map, String key) {
        Object val = map.get(key);
        return val != null ? val.toString().trim() : null;
    }

    private static class CacheEntry<T> {
        final T data;
        final long timestamp;

        CacheEntry(T data) {
            this.data = data;
            this.timestamp = System.currentTimeMillis();
        }

        boolean isExpired(long ttlMs) {
            return System.currentTimeMillis() - timestamp > ttlMs;
        }
    }
}
