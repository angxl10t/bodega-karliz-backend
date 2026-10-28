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
    public void run(ApplicationArguments args) {
        log.info("[DataInitializer] Verificando e inicializando estructura multi-tenant y usuarios...");

        // 0. Asegurar columnas de la tabla bodegas para prevenir errores de mapeo JPA
        asegurarColumnasBodegas();

        // 1. Asegurar que Bodega 1 (Bodega KARLIZ) exista
        Bodega bodegaKarliz = inicializarBodegaKarliz();

        // 2. Vincular registros huérfanos a Bodega Karliz
        vincularRegistrosHuerfanos(bodegaKarliz);

        // 3. Configurar usuarios del sistema (Superadmin desvinculado, Admin de Karliz, Cajero)
        inicializarUsuarios(bodegaKarliz);

        // 4. Sembrar categorías maestras si Bodega 1 no tiene ninguna
        inicializarCategoriasYProductos(bodegaKarliz);

        log.info("[DataInitializer] Inicialización multi-tenant completada exitosamente.");
    }

    private void asegurarColumnasBodegas() {
        String[] alterStatements = {
            "ALTER TABLE bodegas ADD COLUMN IF NOT EXISTS color_primario VARCHAR(20) DEFAULT '#2563EB'",
            "ALTER TABLE bodegas ADD COLUMN IF NOT EXISTS lema_comercial VARCHAR(255)",
            "ALTER TABLE bodegas ADD COLUMN IF NOT EXISTS facturacion_sunat_activa BOOLEAN DEFAULT FALSE",
            "ALTER TABLE bodegas ADD COLUMN IF NOT EXISTS sunat_proveedor VARCHAR(50) DEFAULT 'SUNAT_DIRECTO_GRATUITO'",
            "ALTER TABLE bodegas ADD COLUMN IF NOT EXISTS sunat_ruc_emisor VARCHAR(11)",
            "ALTER TABLE bodegas ADD COLUMN IF NOT EXISTS sunat_usuario_sol VARCHAR(50)",
            "ALTER TABLE bodegas ADD COLUMN IF NOT EXISTS sunat_token_api VARCHAR(255)",
            "ALTER TABLE bodegas ADD COLUMN IF NOT EXISTS serie_boleta VARCHAR(10) DEFAULT 'B001'",
            "ALTER TABLE bodegas ADD COLUMN IF NOT EXISTS serie_factura VARCHAR(10) DEFAULT 'F001'",
            "ALTER TABLE bodegas ADD COLUMN IF NOT EXISTS ultimo_correlativo_boleta BIGINT DEFAULT 0",
            "ALTER TABLE bodegas ADD COLUMN IF NOT EXISTS ultimo_correlativo_factura BIGINT DEFAULT 0"
        };
        for (String sql : alterStatements) {
            try {
                jdbcTemplate.execute(sql);
            } catch (Exception e) {
                log.debug("[DataInitializer] Alter column omitido o ya existente: {}", e.getMessage());
            }
        }
    }

    private Bodega inicializarBodegaKarliz() {
        try {
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
        } catch (Exception e) {
            log.warn("[DataInitializer] Búsqueda por ID falló: {}", e.getMessage());
        }

        try {
            Optional<Bodega> bodegaPorNombre = bodegaRepository.findAll().stream()
                    .filter(b -> "Bodega KARLIZ".equalsIgnoreCase(b.getNombreComercial()))
                    .findFirst();

            if (bodegaPorNombre.isPresent()) {
                return bodegaPorNombre.get();
            }
        } catch (Exception e) {
            log.warn("[DataInitializer] Búsqueda por nombre falló: {}", e.getMessage());
        }

        // Intento 1: Inserción directa con OVERRIDING SYSTEM VALUE para PostgreSQL IDENTITY
        try {
            jdbcTemplate.execute(
                    "INSERT INTO bodegas (id_bodega, nombre_comercial, ruc_dni, direccion, telefono, plan, color_primario, lema_comercial, estado) " +
                    "OVERRIDING SYSTEM VALUE " +
                    "VALUES (1, 'Bodega KARLIZ', '10712345678', 'Av. Principal 123', '987654321', 'PRO', '#2563EB', 'Atención cálida, rápida y surtido completo', TRUE) " +
                    "ON CONFLICT (id_bodega) DO UPDATE SET nombre_comercial = 'Bodega KARLIZ', plan = 'PRO'"
            );
        } catch (Exception ex1) {
            log.warn("[DataInitializer] Inserción OVERRIDING falló, intentando estándar: {}", ex1.getMessage());
            try {
                jdbcTemplate.execute(
                        "INSERT INTO bodegas (id_bodega, nombre_comercial, ruc_dni, direccion, telefono, plan, color_primario, lema_comercial, estado) " +
                        "VALUES (1, 'Bodega KARLIZ', '10712345678', 'Av. Principal 123', '987654321', 'PRO', '#2563EB', 'Atención cálida, rápida y surtido completo', TRUE) " +
                        "ON CONFLICT DO NOTHING"
                );
            } catch (Exception ex2) {
                log.warn("[DataInitializer] Inserción estándar falló: {}", ex2.getMessage());
            }
        }

        try {
            jdbcTemplate.execute("SELECT setval(pg_get_serial_sequence('bodegas', 'id_bodega'), GREATEST((SELECT COALESCE(MAX(id_bodega), 1) FROM bodegas), 1))");
        } catch (Exception ignored) {}

        try {
            return bodegaRepository.findById(1L).orElseGet(() -> {
                Bodega fallback = new Bodega();
                fallback.setNombreComercial("Bodega KARLIZ");
                fallback.setPlan("PRO");
                fallback.setColorPrimario("#2563EB");
                fallback.setEstado(true);
                return bodegaRepository.save(fallback);
            });
        } catch (Exception ex) {
            log.warn("[DataInitializer] Creación fallback JPA: {}", ex.getMessage());
            Bodega fallback = new Bodega();
            fallback.setNombreComercial("Bodega KARLIZ");
            fallback.setPlan("PRO");
            fallback.setColorPrimario("#2563EB");
            fallback.setEstado(true);
            return bodegaRepository.save(fallback);
        }
    }

    private void vincularRegistrosHuerfanos(Bodega bodegaKarliz) {
        if (bodegaKarliz == null || bodegaKarliz.getIdBodega() == null) return;
        Long id = bodegaKarliz.getIdBodega();
        try {
            jdbcTemplate.update("UPDATE productos SET id_bodega = ? WHERE id_bodega IS NULL", id);
            jdbcTemplate.update("UPDATE categorias SET id_bodega = ? WHERE id_bodega IS NULL", id);
            jdbcTemplate.update("UPDATE proveedores SET id_bodega = ? WHERE id_bodega IS NULL", id);
            jdbcTemplate.update("UPDATE ventas SET id_bodega = ? WHERE id_bodega IS NULL", id);
            jdbcTemplate.update("UPDATE compras SET id_bodega = ? WHERE id_bodega IS NULL", id);
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
            // SEGURIDAD: Preservar la contraseña configurada por el usuario
            if (superadmin.getPassword() == null || superadmin.getPassword().isBlank()) {
                superadmin.setPassword(passwordEncoder.encode("123456"));
            }
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
            if (adminKarliz.getPassword() == null || adminKarliz.getPassword().isBlank()) {
                adminKarliz.setPassword(passwordEncoder.encode("123456"));
            }
            usuarioRepository.save(adminKarliz);
        }

        // C. Asegurar que cajero_karlizzz esté asignado a Bodega Karliz
        Optional<Usuario> cajeroOpt = usuarioRepository.findByUsernameIgnoreCase("cajero_karlizzz");
        if (cajeroOpt.isPresent()) {
            Usuario cajero = cajeroOpt.get();
            cajero.setBodega(bodegaKarliz);
            cajero.setRol("CAJERO");
            if (cajero.getPassword() == null || cajero.getPassword().isBlank()) {
                cajero.setPassword(passwordEncoder.encode("1234"));
            }
            usuarioRepository.save(cajero);
            log.info("[DataInitializer] Cajero 'cajero_karlizzz' vinculado a Bodega Karliz.");
        }

        // D. Asegurar que admin_sanmartin tenga contraseña si no existe
        Optional<Usuario> sanmartinOpt = usuarioRepository.findByUsernameIgnoreCase("admin_sanmartin");
        if (sanmartinOpt.isPresent()) {
            Usuario sanmartin = sanmartinOpt.get();
            if (sanmartin.getPassword() == null || sanmartin.getPassword().isBlank()) {
                sanmartin.setPassword(passwordEncoder.encode("123456"));
                usuarioRepository.save(sanmartin);
            }
        }
    }

    private void inicializarCategoriasYProductos(Bodega bodegaKarliz) {
        String[][] categoriasDefault = {
            {"Bebidas y Gaseosas", "Gaseosas, aguas minerales, jugos, energizantes e hidratantes"},
            {"Licores y Cervezas", "Cervezas nacionales e importadas, vinos, piscos y licores"},
            {"Lácteos y Huevos", "Leche evaporada, fresca, yogures, mantequillas, quesos y huevos"},
            {"Abarrotes y Despensa", "Arroz, azúcar, fideos, aceites, conservas, salsas y condimentos"},
            {"Snacks y Golosinas", "Papas fritas, galletas dulces y saladas, chocolates y caramelos"},
            {"Embutidos y Fiambrería", "Jamones, salchichas, tocinos, chorizos y quesos empaquetados"},
            {"Panadería y Desayuno", "Pan de molde, mermeladas, avenas, café, té e infusiones"},
            {"Limpieza del Hogar", "Detergentes, lejías, lavavajillas, desinfectantes y esponjas"},
            {"Cuidado Personal", "Jabones de tocador, champús, cremas dentales y papel higiénico"},
            {"Helados y Congelados", "Helados Donofrio, paletas, conos, bombones y postres fríos"},
            {"Cigarrillos y Tabaco", "Cajetillas Lucky Strike, Pall Mall, Hamilton y encendedores"}
        };

        for (Bodega b : bodegaRepository.findAll()) {
            if (b == null || b.getIdBodega() == null) continue;
            Long idBodega = b.getIdBodega();

            for (String[] c : categoriasDefault) {
                if (categoriaRepository.findByBodega_IdBodegaAndNombreIgnoreCase(idBodega, c[0]).isEmpty()) {
                    Categoria cat = new Categoria();
                    cat.setNombre(c[0]);
                    cat.setDescripcion(c[1]);
                    cat.setEstado(true);
                    cat.setBodega(b);
                    categoriaRepository.save(cat);
                }
            }
        }

        String[][] productosBase = {
            {"7750106001010", "Inca Kola 500ml", "Inca Kola", "Bebidas y Gaseosas", "3.50", "48.000", "packshots/inka_kola.png"},
            {"7751234567890", "Coca Cola 3 Litros", "Coca Cola", "Bebidas y Gaseosas", "13.50", "36.000", "packshots/coca_cola.png"},
            {"7750106000025", "Coca Cola 500ml", "Coca Cola", "Bebidas y Gaseosas", "3.50", "36.000", "packshots/coca_cola.png"},
            {"7750106003014", "Agua San Luis 625ml Sin Gas", "San Luis", "Bebidas y Gaseosas", "2.00", "48.000", "packshots/agua_san_luis.png"},
            {"775117011953", "Agua San Mateo 600ml Sin Gas", "San Mateo", "Bebidas y Gaseosas", "2.00", "48.000", "packshots/agua_san_mateo.png"},
            {"7750111006014", "Cerveza Pilsen Callao 630ml", "Pilsen Callao", "Licores y Cervezas", "7.50", "60.000", "packshots/cerveza_pilsen.png"},
            {"7750111006021", "Cerveza Cristal 650ml", "Cristal", "Licores y Cervezas", "7.50", "60.000", "packshots/cerveza_cristal.png"},
            {"7750106006015", "Cerveza Cusqueña Trigo 310ml", "Cusqueña", "Licores y Cervezas", "6.50", "36.000", "packshots/cerveza_cusquena.png"},
            {"7750108003013", "Leche Gloria Azul Evaporada 400g", "Gloria", "Lácteos y Huevos", "4.50", "72.000", "packshots/leche_gloria_azul.png"},
            {"7750108003044", "Leche Gloria Sin Lactosa 400g", "Gloria", "Lácteos y Huevos", "4.50", "36.000", "packshots/leche_gloria_sin_lactosa.png"},
            {"7750108003068", "Yogur Gloria Fresa 1 Litro", "Gloria", "Lácteos y Huevos", "7.20", "24.000", "packshots/yogur_gloria_fresa.png"},
            {"7750109004041", "Arroz Extra Costeño Bolsa 1kg", "Costeño", "Abarrotes y Despensa", "4.90", "80.000", "packshots/arroz_costeno.png"},
            {"7750109004065", "Aceite Vegetal Primor Premium 900ml", "Primor", "Abarrotes y Despensa", "9.50", "40.000", "packshots/aceite_primor.png"},
            {"7750109004010", "Fideos Don Vittorio Spaghetti 450g", "Don Vittorio", "Abarrotes y Despensa", "3.20", "50.000", "packshots/fideos_don_vittorio.png"},
            {"7750109004072", "Atún Trozos de Atún Primor 170g", "Primor", "Abarrotes y Despensa", "6.00", "48.000", "packshots/trozos_atun_primor.png"},
            {"7750109004140", "Crema de Ají Tarí Alacena Doypack 400g", "Alacena", "Abarrotes y Despensa", "5.50", "30.000", "packshots/mayonesa_alacena.png"},
            {"7750106009999", "Papas Lays Clásicas 160g", "Lays", "Snacks y Golosinas", "2.50", "40.000", "packshots/lays_clasicas.png"},
            {"7750115010011", "Chocolate Sublime Clásico 30g", "Nestlé", "Snacks y Golosinas", "2.50", "60.000", "packshots/chocolate_sublime.png"},
            {"7750115010059", "Galleta Casino Fresa 68g", "Victoria", "Snacks y Golosinas", "1.50", "50.000", "packshots/galleta_casino.png"},
            {"7750115010035", "Galleta Cua Cua Chocolate 18g", "Field", "Snacks y Golosinas", "1.50", "60.000", "packshots/galleta_cua_cua.png"},
            {"7750107002016", "Hot Dog de Pollo San Fernando 500g", "San Fernando", "Embutidos y Fiambrería", "6.80", "20.000", "packshots/hot_dog_san_fernando.png"},
            {"7750107002078", "Queso Fresco Bonlé Gloria 400g", "Gloria", "Embutidos y Fiambrería", "7.50", "20.000", "packshots/queso_fresco_bonle.png"},
            {"7750116011018", "Pan de Molde Blanco Bimbo Chico 400g", "Bimbo", "Panadería y Desayuno", "6.50", "25.000", "packshots/pan_bimbo_blanco.png"},
            {"7750116011049", "Café Soluble Nescafé Tradición Frasco 50g", "Nescafé", "Panadería y Desayuno", "9.50", "24.000", "packshots/cafe_nescafe.png"},
            {"7750114009015", "Detergente Bolívar Blanco Activo 850g", "Bolívar", "Limpieza del Hogar", "9.90", "30.000", "packshots/detergente_bolivar.png"},
            {"7750114009060", "Lejía Clorox Tradicional 1 Litro", "Clorox", "Limpieza del Hogar", "4.50", "40.000", "packshots/lejia_clorox.png"},
            {"7750113008025", "Crema Dental Colgate Total 12 Limpieza 75ml", "Colgate", "Cuidado Personal", "5.50", "36.000", "packshots/colgate_total12.png"},
            {"7750113008117", "Papel Higiénico Suave Rindemax x4 rollos", "Suave", "Cuidado Personal", "6.50", "40.000", "packshots/papel_higienico_suave.png"},
            {"7750110005017", "Helado Sublime D'Onofrio Paleta", "D'Onofrio", "Helados y Congelados", "3.00", "30.000", "packshots/helado_sublime.png"},
            {"7750112007028", "Cigarros Lucky Strike Double Click Box x20", "Lucky Strike", "Cigarrillos y Tabaco", "18.00", "20.000", "packshots/helado_jet.png"}
        };

        if (bodegaKarliz != null && bodegaKarliz.getIdBodega() != null) {
            Long idKarliz = bodegaKarliz.getIdBodega();
            long prodCount = productoRepository.findByBodega_IdBodegaAndEstadoTrue(idKarliz).size();
            if (prodCount < 10) {
                for (String[] pData : productosBase) {
                    String codigoBarras = pData[0];
                    String nombre = pData[1];
                    String marca = pData[2];
                    String catNombre = pData[3];
                    BigDecimal venta = new BigDecimal(pData[4]);
                    BigDecimal stock = new BigDecimal(pData[5]);
                    String imagenUrl = pData[6];

                    Categoria cat = categoriaRepository.findByBodega_IdBodegaAndNombreIgnoreCase(idKarliz, catNombre)
                            .orElseGet(() -> categoriaRepository.findByBodega_IdBodegaAndEstadoTrue(idKarliz).stream().findFirst().orElse(null));

                    if (cat != null) {
                        crearProducto(codigoBarras, nombre, marca, venta, stock, cat, bodegaKarliz, imagenUrl);
                    }
                }
                log.info("[DataInitializer] Sembrado catálogo de productos comerciales con códigos de barras oficiales para Bodega KARLIZ.");
            }
        }
    }

    private void crearProducto(String codigoBarras, String nombre, String marca,
                               BigDecimal venta, BigDecimal stock,
                               Categoria categoria, Bodega bodega, String imagenUrl) {
        if (bodega == null || bodega.getIdBodega() == null || categoria == null) return;

        Optional<Producto> existenteOpt = productoRepository.findByBodega_IdBodegaAndCodigoBarras(bodega.getIdBodega(), codigoBarras);
        if (existenteOpt.isPresent()) {
            Producto p = existenteOpt.get();
            boolean updated = false;
            if (imagenUrl != null && !imagenUrl.isBlank() && (p.getImagenUrl() == null || p.getImagenUrl().isBlank())) {
                p.setImagenUrl(imagenUrl);
                updated = true;
            }
            if (marca != null && !marca.isBlank() && (p.getMarca() == null || p.getMarca().isBlank())) {
                p.setMarca(marca);
                updated = true;
            }
            if (updated) {
                productoRepository.save(p);
            }
            return;
        }

        String codigo = "PROD-" + codigoBarras;
        if (productoRepository.findByBodega_IdBodegaAndCodigo(bodega.getIdBodega(), codigo).isPresent()) {
            codigo = codigo + "-" + (System.currentTimeMillis() % 1000);
        }

        Producto p = new Producto();
        p.setCodigo(codigo);
        p.setCodigoBarras(codigoBarras);
        p.setNombre(nombre);
        p.setMarca(marca);
        p.setPrecioVenta(venta);
        p.setPrecioCosto(venta.multiply(new BigDecimal("0.78")).setScale(2, java.math.RoundingMode.HALF_UP));
        p.setStockActual(stock);
        p.setStockMinimo(new BigDecimal("5.000"));
        p.setControlaVencimiento(false);
        p.setImagenUrl(imagenUrl);
        p.setCategoria(categoria);
        p.setBodega(bodega);
        p.setEstado(true);
        productoRepository.save(p);
    }
}
