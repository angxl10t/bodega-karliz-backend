package com.bodega.backend;

import com.bodega.backend.entity.Usuario;
import com.bodega.backend.repository.UsuarioRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.security.crypto.password.PasswordEncoder;

@SpringBootApplication
public class BodegaBackendApplication {

	public static void main(String[] args) {
		SpringApplication.run(BodegaBackendApplication.class, args);
	}

	@Bean
	public CommandLineRunner inicializarAdminSeguro(UsuarioRepository usuarioRepository, PasswordEncoder passwordEncoder) {
		return args -> {
			usuarioRepository.findByUsername("admin").ifPresentOrElse(admin -> {
				if (admin.getEstado() == null) {
					admin.setEstado(true);
					usuarioRepository.save(admin);
					System.out.println(">>> [SEGURIDAD] Estado de usuario 'admin' asegurado como activo (true).");
				}
			}, () -> {
				Usuario admin = new Usuario();
				admin.setUsername("admin");
				admin.setPassword(passwordEncoder.encode("123456"));
				admin.setRol("ADMIN");
				admin.setEstado(true);
				usuarioRepository.save(admin);
				System.out.println(">>> [SEGURIDAD] Usuario inicial 'admin' creado automáticamente con contraseña por defecto.");
			});
		};
	}
}
