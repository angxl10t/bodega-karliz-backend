package com.bodega.backend.entity;
import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.CreationTimestamp;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Data
@Entity
@Table(name = "compras")
public class Compra {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_compra")
    private Long idCompra;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "id_proveedor", nullable = false)
    private Proveedor proveedor;

    @Column(length = 50)
    private String comprobante;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal total;

    @CreationTimestamp
    @Column(name = "fecha_compra", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaCompra;

    @Column(name = "usuario_registro", length = 50)
    private String usuarioRegistro;
}
