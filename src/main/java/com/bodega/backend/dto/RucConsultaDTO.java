package com.bodega.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder(toBuilder = true)
@NoArgsConstructor
@AllArgsConstructor
public class RucConsultaDTO {
    private String numero;
    private String razonSocial;
    private String estado;        // "ACTIVO", "BAJA", etc.
    private String condicion;     // "HABIDO", "NO HABIDO", "NO HALLADO"
    private String direccion;
    private String departamento;
    private String provincia;
    private String distrito;
    private String ubigeo;
    private boolean esActivo;
    private boolean esHabido;
    private boolean encontrado;
    private String mensaje;
    private String fuente;        // "SUNAT_APIS_PERU", "CACHE", "FALLBACK"
}
