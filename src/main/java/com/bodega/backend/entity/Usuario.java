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

    @Column(nullable = false, length = 50)
    private String rol;

    @Column(nullable = false)
    private Boolean estado = true;

    // Control de revocación de sesiones JWT al cambiar de contraseña
    @Column(name = "fecha_cambio_clave", columnDefinition = "TIMESTAMP WITH TIME ZONE")
    private OffsetDateTime fechaCambioClave;
}
