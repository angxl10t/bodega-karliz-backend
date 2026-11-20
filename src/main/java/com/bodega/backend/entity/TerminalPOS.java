package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import org.hibernate.annotations.CreationTimestamp;

import java.time.OffsetDateTime;

@Data
@Entity
@Table(name = "terminales_pos", indexes = {
    @Index(name = "idx_terminales_bodega_estado", columnList = "id_bodega, estado"),
    @Index(name = "idx_terminales_token", columnList = "terminal_token", unique = true)
})
public class TerminalPOS {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_terminal")
    private Long idTerminal;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_bodega", nullable = false)
    private Bodega bodega;

    @Column(nullable = false, length = 100)
    private String nombre;

    @Column(name = "terminal_token", nullable = false, unique = true, length = 120)
    private String terminalToken;

    @Column(name = "device_model", length = 150)
    private String deviceModel;

    @CreationTimestamp
    @Column(name = "fecha_vinculacion", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaVinculacion;

    @Column(name = "ultimo_acceso", columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime ultimoAcceso;

    @Column(nullable = false)
    private Boolean estado = true;
}
