package com.bodega.backend.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class AjusteInventarioDTO {

    @NotNull(message = "El ID del producto es obligatorio.")
    private Long idProducto;

    @NotNull(message = "La cantidad a ajustar es obligatoria.")
    @DecimalMin(value = "0.001", message = "La cantidad debe ser mayor a cero.")
    private BigDecimal cantidad;

    /**
     * Categoría / Tipo de ajuste:
     * - MERMA: Pérdida o deterioro (frutas, verduras, productos dañados)
     * - ROTURA: Envase quebrado, rotura física o daño en anaquel
     * - VENCIMIENTO: Producto caducado / fecha de vencimiento cumplida
     * - CONSUMO_INTERNO: Uso interno del negocio (degustación, limpieza, etc.)
     * - SOBRANTE: Excedente o sobrante encontrado en recuento físico
     */
    @NotBlank(message = "El tipo de ajuste es obligatorio (MERMA, ROTURA, VENCIMIENTO, CONSUMO_INTERNO, SOBRANTE).")
    private String tipoAjuste;

    @NotBlank(message = "El motivo o justificación del ajuste es obligatorio.")
    @Size(max = 200, message = "El motivo no puede exceder los 200 caracteres.")
    private String motivo;
}
