package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.CreationTimestamp;

import java.time.OffsetDateTime;

@Data
@Entity
@Table(name = "terminal_codigos_pairing", indexes = {
    @Index(name = "idx_pairing_codigo_usado", columnList = "codigo, usado"),
    @Index(name = "idx_pairing_bodega", columnList = "id_bodega")
})
public class TerminalPairingCode {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_bodega", nullable = false)
    private Bodega bodega;

    @Column(nullable = false, length = 12)
    private String codigo;

    @Column(name = "fecha_expiracion", nullable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaExpiracion;

    @Column(nullable = false)
    private Boolean usado = false;

    @CreationTimestamp
    @Column(name = "fecha_creacion", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaCreacion;

    @Column(name = "creado_por_username", length = 100)
    private String creadoPorUsername;
}
