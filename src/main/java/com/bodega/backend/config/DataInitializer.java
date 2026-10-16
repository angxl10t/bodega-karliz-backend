package com.bodega.backend.config;

import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Categoria;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.entity.Usuario;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.CategoriaRepository;
import com.bodega.backend.repository.ProductoRepository;
import com.bodega.backend.repository.UsuarioRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.Optional;

@Component
public class DataInitializer implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(DataInitializer.class);

    private final JdbcTemplate jdbcTemplate;
    private final BodegaRepository bodegaRepository;
    private final UsuarioRepository usuarioRepository;
    private final CategoriaRepository categoriaRepository;
    private final ProductoRepository productoRepository;
    private final PasswordEncoder passwordEncoder;

    public DataInitializer(JdbcTemplate jdbcTemplate,
                           BodegaRepository bodegaRepository,
                           UsuarioRepository usuarioRepository,
                           CategoriaRepository categoriaRepository,
                           ProductoRepository productoRepository,
                           PasswordEncoder passwordEncoder) {
        this.jdbcTemplate = jdbcTemplate;
        this.bodegaRepository = bodegaRepository;
        this.usuarioRepository = usuarioRepository;
        this.categoriaRepository = categoriaRepository;
        this.productoRepository = productoRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        try {
            log.info("[DataInitializer] Verificando e inicializando estructura multi-tenant y usuarios...");

            // 1. Asegurar que Bodega 1 (Bodega KARLIZ) exista
            Bodega bodegaKarliz = inicializarBodegaKarliz();

            // 2. Vincular registros huérfanos a Bodega 1
            vincularRegistrosHuerfanos();

            // 3. Configurar usuarios del sistema (Superadmin desvinculado, Admin de Karliz, Cajero)
            inicializarUsuarios(bodegaKarliz);

            // 4. Sembrar categorías maestras si Bodega 1 no tiene ninguna
            inicializarCategoriasYProductos(bodegaKarliz);

            log.info("[DataInitializer] Inicialización multi-tenant completada exitosamente.");
        } catch (Exception e) {
            log.error("[DataInitializer] Advertencia al inicializar datos: {}", e.getMessage(), e);
        }
    }

    private Bodega inicializarBodegaKarliz() {
        Optional<Bodega> bodegaOpt = bodegaRepository.findById(1L);
        if (bodegaOpt.isPresent()) {
            Bodega b = bodegaOpt.get();
            if (b.getNombreComercial() == null || b.getNombreComercial().isBlank()) {
                b.setNombreComercial("Bodega KARLIZ");
            }
            if (b.getPlan() == null) {
                b.setPlan("PRO");
            }
            return bodegaRepository.save(b);
        }

        Optional<Bodega> bodegaPorNombre = bodegaRepository.findAll().stream()
                .filter(b -> "Bodega KARLIZ".equalsIgnoreCase(b.getNombreComercial()))
                .findFirst();

        if (bodegaPorNombre.isPresent()) {
            return bodegaPorNombre.get();
        }

        try {
            jdbcTemplate.update(
                    "INSERT INTO bodegas (id_bodega, nombre_comercial, ruc_dni, direccion, telefono, plan, color_primario, lema_comercial, estado) " +
                    "VALUES (1, 'Bodega KARLIZ', '10712345678', 'Av. Principal 123', '987654321', 'PRO', '#2563EB', 'Atención cálida, rápida y surtido completo', TRUE) " +
                    "ON CONFLICT (id_bodega) DO UPDATE SET nombre_comercial = 'Bodega KARLIZ', plan = 'PRO'"
            );
            try {
                jdbcTemplate.execute(
                        "SELECT setval(pg_get_serial_sequence('bodegas', 'id_bodega'), GREATEST((SELECT COALESCE(MAX(id_bodega), 1) FROM bodegas), 1))"
                );
            } catch (Exception ignored) {}
            return bodegaRepository.findById(1L).orElseGet(() -> {
                Bodega fallback = new Bodega();
                fallback.setNombreComercial("Bodega KARLIZ");
                fallback.setPlan("PRO");
                fallback.setColorPrimario("#2563EB");
                fallback.setEstado(true);
                return bodegaRepository.save(fallback);
            });
        } catch (Exception ex) {
            log.warn("[DataInitializer] Inserción JDBC falló, creando vía JPA: {}", ex.getMessage());
            Bodega nueva = new Bodega();
            nueva.setNombreComercial("Bodega KARLIZ");
            nueva.setRucDni("10712345678");
            nueva.setDireccion("Av. Principal 123");
            nueva.setTelefono("987654321");
            nueva.setPlan("PRO");
            nueva.setColorPrimario("#2563EB");
            nueva.setLemaComercial("Atención cálida, rápida y surtido completo");
            nueva.setEstado(true);
            return bodegaRepository.save(nueva);
        }
    }

    private void vincularRegistrosHuerfanos() {
        try {
            jdbcTemplate.update("UPDATE productos SET id_bodega = 1 WHERE id_bodega IS NULL");
            jdbcTemplate.update("UPDATE categorias SET id_bodega = 1 WHERE id_bodega IS NULL");
            jdbcTemplate.update("UPDATE proveedores SET id_bodega = 1 WHERE id_bodega IS NULL");
            jdbcTemplate.update("UPDATE ventas SET id_bodega = 1 WHERE id_bodega IS NULL");
            jdbcTemplate.update("UPDATE compras SET id_bodega = 1 WHERE id_bodega IS NULL");
        } catch (Exception e) {
            log.debug("[DataInitializer] Vincular huérfanos omitido: {}", e.getMessage());
        }
    }

    private void inicializarUsuarios(Bodega bodegaKarliz) {
        // A. Configurar SUPERADMIN ('admin') desvinculado de Karliz
        Optional<Usuario> adminOpt = usuarioRepository.findByUsernameIgnoreCase("admin");
        if (adminOpt.isPresent()) {
            Usuario superadmin = adminOpt.get();
            superadmin.setRol("SUPERADMIN");
            superadmin.setBodega(null); // Desvinculado explícitamente
            usuarioRepository.save(superadmin);
            log.info("[DataInitializer] Usuario 'admin' configurado como SUPERADMIN global (sin bodega asociada).");
        } else {
            Usuario superadmin = new Usuario();
            superadmin.setUsername("admin");
            superadmin.setPassword(passwordEncoder.encode("123456"));
            superadmin.setRol("SUPERADMIN");
            superadmin.setEstado(true);
            superadmin.setBodega(null);
            superadmin.setFechaCambioClave(OffsetDateTime.now());
            usuarioRepository.save(superadmin);
            log.info("[DataInitializer] Usuario 'admin' creado como SUPERADMIN global.");
        }

        // B. Crear / Asegurar ADMIN de Bodega KARLIZ ('admin_karliz')
        Optional<Usuario> adminKarlizOpt = usuarioRepository.findByUsernameIgnoreCase("admin_karliz");
        if (adminKarlizOpt.isEmpty()) {
            Usuario adminKarliz = new Usuario();
            adminKarliz.setUsername("admin_karliz");
            adminKarliz.setPassword(passwordEncoder.encode("123456"));
            adminKarliz.setRol("ADMIN");
            adminKarliz.setEstado(true);
            adminKarliz.setBodega(bodegaKarliz);
            adminKarliz.setFechaCambioClave(OffsetDateTime.now());
            usuarioRepository.save(adminKarliz);
            log.info("[DataInitializer] Creado administrador dedicado para Bodega KARLIZ ('admin_karliz').");
        } else {
            Usuario adminKarliz = adminKarlizOpt.get();
            adminKarliz.setBodega(bodegaKarliz);
            adminKarliz.setRol("ADMIN");
            usuarioRepository.save(adminKarliz);
        }

        // C. Asegurar que cajero_karlizzz esté asignado a Bodega Karliz
        Optional<Usuario> cajeroOpt = usuarioRepository.findByUsernameIgnoreCase("cajero_karlizzz");
        if (cajeroOpt.isPresent()) {
            Usuario cajero = cajeroOpt.get();
            if (cajero.getBodega() == null) {
                cajero.setBodega(bodegaKarliz);
                usuarioRepository.save(cajero);
            }
        }
    }

    private void inicializarCategoriasYProductos(Bodega bodegaKarliz) {
        if (bodegaKarliz == null || bodegaKarliz.getIdBodega() == null) return;
        Long idBodega = bodegaKarliz.getIdBodega();

        long catCount = categoriaRepository.findByBodega_IdBodegaAndEstadoTrue(idBodega).size();
        if (catCount == 0) {
            String[][] categoriasDefault = {
                {"Bebidas y Gaseosas", "Gaseosas, aguas minerales, jugos, energizantes e hidratantes"},
                {"Snacks y Golosinas", "Papas fritas, galletas dulces, chocolates y caramelos"},
                {"Lácteos y Huevos", "Leche evaporada, fresca, yogures, mantequillas y quesos"},
                {"Abarrotes y Despensa", "Arroz, azúcar, fideos, aceites, conservas y condimentos"},
                {"Limpieza del Hogar", "Detergentes, lejías, lavavajillas, suavizantes y esponjas"},
                {"Cuidado Personal", "Jabones, champús, cremas dentales y papel higiénico"}
            };

            for (String[] c : categoriasDefault) {
                Categoria cat = new Categoria();
                cat.setNombre(c[0]);
                cat.setDescripcion(c[1]);
                cat.setEstado(true);
                cat.setBodega(bodegaKarliz);
                categoriaRepository.save(cat);
            }
            log.info("[DataInitializer] Sembradas categorías base para Bodega KARLIZ.");
        }

        long prodCount = productoRepository.findByBodega_IdBodegaAndEstadoTrue(idBodega).size();
        if (prodCount == 0) {
            Categoria catBebidas = categoriaRepository.findByBodega_IdBodegaAndNombreIgnoreCase(idBodega, "Bebidas y Gaseosas").orElse(null);
            Categoria catLacteos = categoriaRepository.findByBodega_IdBodegaAndNombreIgnoreCase(idBodega, "Lácteos y Huevos").orElse(null);
            Categoria catAbarrotes = categoriaRepository.findByBodega_IdBodegaAndNombreIgnoreCase(idBodega, "Abarrotes y Despensa").orElse(null);

            if (catBebidas != null) {
                crearProducto("7750106000018", "Inca Kola 500ml", "Inca Kola", new BigDecimal("3.50"), new BigDecimal("48.000"), catBebidas, bodegaKarliz);
                crearProducto("7750106000025", "Coca Cola 500ml", "Coca Cola", new BigDecimal("3.50"), new BigDecimal("36.000"), catBebidas, bodegaKarliz);
            }
            if (catLacteos != null) {
                crearProducto("7750243000012", "Leche Gloria Azul 400g", "Gloria", new BigDecimal("4.50"), new BigDecimal("24.000"), catLacteos, bodegaKarliz);
            }
            if (catAbarrotes != null) {
                crearProducto("7750350000010", "Arroz Costeño Extra 1kg", "Costeño", new BigDecimal("5.00"), new BigDecimal("50.000"), catAbarrotes, bodegaKarliz);
                crearProducto("7750350000027", "Aceite Primor Clásico 1L", "Primor", new BigDecimal("9.80"), new BigDecimal("20.000"), catAbarrotes, bodegaKarliz);
            }
            log.info("[DataInitializer] Sembrado inventario inicial demostrativo para Bodega KARLIZ.");
        }
    }

    private void crearProducto(String codigoBarras, String nombre, String marca,
                               BigDecimal venta, BigDecimal stock,
                               Categoria categoria, Bodega bodega) {
        Producto p = new Producto();
        p.setCodigo("PROD-" + codigoBarras);
        p.setCodigoBarras(codigoBarras);
        p.setNombre(nombre);
        p.setMarca(marca);
        p.setPrecioVenta(venta);
        p.setStockActual(stock);
        p.setStockMinimo(new BigDecimal("5.000"));
        p.setControlaVencimiento(false);
        p.setCategoria(categoria);
        p.setBodega(bodega);
        p.setEstado(true);
        productoRepository.save(p);
    }
}
