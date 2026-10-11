package com.bodega.backend.controller;

import com.bodega.backend.dto.AuthDTO;
import com.bodega.backend.entity.Usuario;
import com.bodega.backend.repository.UsuarioRepository;
import com.bodega.backend.security.JwtUtil;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthenticationManager authenticationManager;
    private final JwtUtil jwtUtil;
    private final UsuarioRepository usuarioRepository;
    private final PasswordEncoder passwordEncoder;

    public AuthController(AuthenticationManager authenticationManager, JwtUtil jwtUtil, 
                          UsuarioRepository usuarioRepository, PasswordEncoder passwordEncoder) {
        this.authenticationManager = authenticationManager;
        this.jwtUtil = jwtUtil;
        this.usuarioRepository = usuarioRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @PostMapping("/login")
    public ResponseEntity<Map<String, String>> login(@RequestBody AuthDTO authDTO) {
        // 1. Valida usuario y contraseña en BD automáticamente
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(authDTO.getUsername(), authDTO.getPassword())
        );

        // 2. Si es correcto, genera el JWT
        Usuario usuario = usuarioRepository.findByUsername(authDTO.getUsername()).get();
        String jwt = jwtUtil.generateToken(usuario.getUsername(), usuario.getRol());

        // 3. Lo entrega a Flutter
        Map<String, String> response = new HashMap<>();
        response.put("token", jwt);
        response.put("rol", usuario.getRol());
        return ResponseEntity.ok(response);
    }

    // Endpoint mágico temporal para poder crear tu primera cuenta de administrador
    @PostMapping("/crear-admin")
    public ResponseEntity<String> crearAdmin() {
        if (usuarioRepository.findByUsername("admin").isPresent()) {
            return ResponseEntity.badRequest().body("El admin ya existe en la base de datos.");
        }
        Usuario admin = new Usuario();
        admin.setUsername("admin");
        admin.setPassword(passwordEncoder.encode("123456")); // Bcrypt encriptará el 123456
        admin.setRol("ADMIN");
        usuarioRepository.save(admin);
        return ResponseEntity.ok("Primer Usuario ADMIN creado con éxito. Clave: 123456");
    }
}
