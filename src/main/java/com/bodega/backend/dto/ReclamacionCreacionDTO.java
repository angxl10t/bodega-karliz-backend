package com.bodega.backend.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReclamacionCreacionDTO {

    private Long idBodega;

    @NotBlank(message = "El nombre del consumidor o reclamante es obligatorio")
    @Size(max = 150)
    private String nombreReclamante;

    @NotBlank(message = "El tipo de documento es obligatorio (DNI, CE, PASAPORTE, RUC)")
    private String tipoDocumento;

    @NotBlank(message = "El número de documento es obligatorio")
    @Size(max = 30)
    private String numeroDocumento;

    @Size(max = 50)
    private String telefono;

    @NotBlank(message = "El correo electrónico es obligatorio para el envío de la copia legal")
    @Email(message = "El formato de correo no es válido")
    @Size(max = 150)
    private String email;

    @Size(max = 250)
    private String direccion;

    @NotBlank(message = "Debe especificar si es RECLAMO o QUEJA")
    private String tipo; // 'RECLAMO' o 'QUEJA'

    @Builder.Default
    private String tipoBien = "PRODUCTO"; // 'PRODUCTO' o 'SERVICIO'

    private BigDecimal montoReclamado;

    private String descripcionBien;

    @NotBlank(message = "El detalle de la reclamación es obligatorio")
    private String detalleReclamacion;

    @NotBlank(message = "El pedido o pretensión concreta del consumidor es obligatorio")
    private String pedidoReclamante;
}
