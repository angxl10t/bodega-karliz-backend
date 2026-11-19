package com.bodega.backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import java.time.OffsetDateTime;

@Data
@Entity
@Table(name = "usuarios")
public class Usuario {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id_usuario")
    private Long idUsuario;

    @Column(nullable = false, unique = true, length = 50)
    private String username;

    @Column(nullable = false, length = 255)
    private String password;

    // PIN numérico de 4 a 6 dígitos para cajeros/mozos en terminales POS (BCrypt hash)
    @Column(name = "pin", length = 100)
    private String pin;

    @Column(nullable = false, length = 50)
    private String rol;

    @Column(nullable = false)
    private Boolean estado = true;

    @Column(name = "nombre_completo", length = 150)
    private String nombreCompleto;

    @Column(name = "email", length = 150)
    private String email;

    // Control de revocación de sesiones JWT al cambiar de contraseña
    @Column(name = "fecha_cambio_clave", columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaCambioClave;

    @org.hibernate.annotations.CreationTimestamp
    @Column(name = "fecha_creacion", updatable = false, columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaCreacion;

    @org.hibernate.annotations.UpdateTimestamp
    @Column(name = "fecha_actualizacion", columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaActualizacion;

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "id_bodega")
    private Bodega bodega;
}
