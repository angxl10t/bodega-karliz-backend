package com.bodega.backend.integration;

import com.bodega.backend.entity.Bodega;
import com.bodega.backend.entity.Categoria;
import com.bodega.backend.entity.Cliente;
import com.bodega.backend.entity.PagoSuscripcion;
import com.bodega.backend.entity.Producto;
import com.bodega.backend.repository.BodegaRepository;
import com.bodega.backend.repository.CategoriaRepository;
import com.bodega.backend.repository.ClienteRepository;
import com.bodega.backend.repository.PagoSuscripcionRepository;
import com.bodega.backend.repository.ProductoRepository;
import com.bodega.backend.repository.UsuarioRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.math.BigDecimal;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Validaciones end-to-end contra PostgreSQL 16 real:
 * - Aplicación limpia de migraciones SQL (v1..v27) e índices críticos
 * - Políticas Row Level Security (RLS) multi-tenant bajo rol sin BYPASSRLS
 * - Índice único parcial de códigos de operación en pagos_suscripciones
 * - Serialización real de concurrencia mediante PESSIMISTIC_WRITE (SELECT ... FOR UPDATE)
 */
class PostgresSecurityAndLockingIntegrationTest extends AbstractPostgresIntegrationTest {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @Autowired
    private BodegaRepository bodegaRepository;

    @Autowired
    private CategoriaRepository categoriaRepository;

    @Autowired
    private ProductoRepository productoRepository;

    @Autowired
    private ClienteRepository clienteRepository;

    @Autowired
    private PagoSuscripcionRepository pagoSuscripcionRepository;

    @Autowired
    private UsuarioRepository usuarioRepository;

    @Test
    void verificaMigracionesV1aV27YIndicesEnPostgresqlReal() {
        Integer tenantFnCount = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM pg_proc WHERE proname IN ('app_current_tenant_id', 'app_is_superadmin')",
                Integer.class
        );
        assertEquals(2, tenantFnCount, "Las funciones RLS de v2 deben existir en PostgreSQL.");

        Boolean productosRls = jdbcTemplate.queryForObject(
                "SELECT rowsecurity FROM pg_tables WHERE schemaname = 'public' AND tablename = 'productos'",
                Boolean.class
        );
        Boolean clientesRls = jdbcTemplate.queryForObject(
                "SELECT rowsecurity FROM pg_tables WHERE schemaname = 'public' AND tablename = 'clientes'",
                Boolean.class
        );
        Boolean pagosRls = jdbcTemplate.queryForObject(
                "SELECT rowsecurity FROM pg_tables WHERE schemaname = 'public' AND tablename = 'pagos_suscripciones'",
                Boolean.class
        );
        assertEquals(Boolean.TRUE, productosRls);
        assertEquals(Boolean.TRUE, clientesRls);
        assertEquals(Boolean.TRUE, pagosRls);

        Integer v27Indexes = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'pagos_suscripciones' " +
                "AND indexname IN ('uq_pagos_suscripcion_codigo_op', 'idx_pagos_suscripcion_bodega_fecha')",
                Integer.class
        );
        assertEquals(2, v27Indexes, "Los 2 índices de v27 sobre pagos_suscripciones deben existir.");

        var superadminOpt = usuarioRepository.findByUsernameIgnoreCase("admin");
        assertTrue(superadminOpt.isPresent(), "DataInitializer debe inicializar 'admin'.");
        assertEquals("SUPERADMIN", superadminOpt.get().getRol());
    }

    @Test
    void verificaAislamientoRlsMultiTenantEnKernelPostgresql() {
        String suffix = UUID.randomUUID().toString().substring(0, 8);

        Bodega bodegaA = crearBodega("Bodega Alfa " + suffix);
        Bodega bodegaB = crearBodega("Bodega Beta " + suffix);

        Categoria catA = crearCategoria(bodegaA, "Bebidas " + suffix);
        Categoria catB = crearCategoria(bodegaB, "Snacks " + suffix);

        Producto prodA = crearProducto(bodegaA, catA, "SKU-A-" + suffix, "Prod A " + suffix, new BigDecimal("10.000"));
        Producto prodB = crearProducto(bodegaB, catB, "SKU-B-" + suffix, "Prod B " + suffix, new BigDecimal("20.000"));

        Cliente cliA = crearCliente(bodegaA, "Cliente A " + suffix, "1000" + suffix.substring(0, 4));
        Cliente cliB = crearCliente(bodegaB, "Cliente B " + suffix, "2000" + suffix.substring(0, 4));

        // Rol sin privilegio de superusuario ni BYPASSRLS para que PostgreSQL haga cumplir RLS
        jdbcTemplate.execute(
                "DO $$ BEGIN " +
                "IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cajaya_rls_tester') THEN " +
                "CREATE ROLE cajaya_rls_tester NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS; " +
                "END IF; END $$;"
        );
        jdbcTemplate.execute("GRANT USAGE ON SCHEMA public TO cajaya_rls_tester");
        jdbcTemplate.execute("GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE productos, clientes TO cajaya_rls_tester");

        TransactionTemplate tx = new TransactionTemplate(transactionManager);
        tx.executeWithoutResult(status -> {
            jdbcTemplate.execute("SET LOCAL ROLE cajaya_rls_tester");

            // 1. Sin app.current_tenant_id activo, clientes con política estricta v14 no expone ninguna fila
            jdbcTemplate.queryForObject("SELECT set_config('app.current_tenant_id', '', true)", String.class);
            Integer clientesSinTenant = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM clientes WHERE id_cliente IN (?, ?)",
                    Integer.class,
                    cliA.getIdCliente(), cliB.getIdCliente()
            );
            assertEquals(0, clientesSinTenant, "Sin tenant activo en sesión, RLS debe ocultar los clientes.");

            // 2. Con Tenant A activo, solo se ven datos de Bodega A
            jdbcTemplate.queryForObject("SELECT set_config('app.current_tenant_id', ?, true)", String.class, String.valueOf(bodegaA.getIdBodega()));
            Integer prodsVisiblesParaA = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM productos WHERE id_producto IN (?, ?)",
                    Integer.class,
                    prodA.getIdProducto(), prodB.getIdProducto()
            );
            Integer clientesVisiblesParaA = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM clientes WHERE id_cliente IN (?, ?)",
                    Integer.class,
                    cliA.getIdCliente(), cliB.getIdCliente()
            );
            assertEquals(1, prodsVisiblesParaA);
            assertEquals(1, clientesVisiblesParaA);

            // 3. Intentar modificar un producto de Bodega B estando bajo sesión de Tenant A no afecta filas
            int filasAfectadasCruzadas = jdbcTemplate.update(
                    "UPDATE productos SET nombre = 'HACKED' WHERE id_producto = ?",
                    prodB.getIdProducto()
            );
            assertEquals(0, filasAfectadasCruzadas, "RLS debe impedir modificar filas de otra bodega.");

            // 4. Modo SUPERADMIN sí observa ambos inquilinos
            jdbcTemplate.queryForObject("SELECT set_config('app.current_tenant_id', 'SUPERADMIN', true)", String.class);
            Integer prodsParaSuperadmin = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM productos WHERE id_producto IN (?, ?)",
                    Integer.class,
                    prodA.getIdProducto(), prodB.getIdProducto()
            );
            assertEquals(2, prodsParaSuperadmin);
        });
    }

    @Test
    void verificaIndiceUnicoParcialPagosSuscripcionesCaseInsensitive() {
        String code = "op-" + UUID.randomUUID().toString().substring(0, 8).toLowerCase();
        Bodega bodega = crearBodega("Bodega Pagos " + code);

        PagoSuscripcion p1 = new PagoSuscripcion();
        p1.setBodega(bodega);
        p1.setCodigoOperacion("  " + code + " ");
        p1.setBilletera("YAPE");
        p1.setPlan("PRO");
        p1.setMonto(new BigDecimal("49.00"));
        p1.setEstado("CONFIRMADO");
        pagoSuscripcionRepository.saveAndFlush(p1);

        PagoSuscripcion duplicado = new PagoSuscripcion();
        duplicado.setBodega(bodega);
        duplicado.setCodigoOperacion(code.toUpperCase());
        duplicado.setBilletera("PLIN");
        duplicado.setPlan("PRO");
        duplicado.setMonto(new BigDecimal("49.00"));
        duplicado.setEstado("CONFIRMADO");

        assertThrows(DataIntegrityViolationException.class, () -> pagoSuscripcionRepository.saveAndFlush(duplicado));
    }

    @Test
    void verificaBloqueoPesimistaPessimisticWriteEnStockConcurrente() throws Exception {
        String suffix = UUID.randomUUID().toString().substring(0, 8);
        Bodega bodega = crearBodega("Bodega Lock " + suffix);
        Categoria cat = crearCategoria(bodega, "Lock Cat " + suffix);
        Producto prod = crearProducto(bodega, cat, "LOCK-" + suffix, "Producto Concurrente", new BigDecimal("10.000"));

        CountDownLatch tx1LockedLatch = new CountDownLatch(1);
        CountDownLatch tx2StartedLatch = new CountDownLatch(1);

        ExecutorService executor = Executors.newFixedThreadPool(2);
        try {
            Future<BigDecimal> future1 = executor.submit(() -> {
                TransactionTemplate tx = new TransactionTemplate(transactionManager);
                return tx.execute(status -> {
                    Producto locked = productoRepository.findByIdForUpdateAndBodega(prod.getIdProducto(), bodega.getIdBodega())
                            .orElseThrow();
                    tx1LockedLatch.countDown();
                    try {
                        tx2StartedLatch.await(3, TimeUnit.SECONDS);
                        Thread.sleep(250);
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                    }
                    BigDecimal updated = locked.getStockActual().subtract(new BigDecimal("3.000"));
                    locked.setStockActual(updated);
                    productoRepository.saveAndFlush(locked);
                    return updated;
                });
            });

            assertTrue(tx1LockedLatch.await(5, TimeUnit.SECONDS));

            Future<BigDecimal> future2 = executor.submit(() -> {
                TransactionTemplate tx = new TransactionTemplate(transactionManager);
                return tx.execute(status -> {
                    tx2StartedLatch.countDown();
                    // Debe bloquearse en PostgreSQL hasta que future1 confirme la transacción
                    Producto locked = productoRepository.findByIdForUpdateAndBodega(prod.getIdProducto(), bodega.getIdBodega())
                            .orElseThrow();
                    assertEquals(0, new BigDecimal("7.000").compareTo(locked.getStockActual()),
                            "PESSIMISTIC_WRITE debe leer el stock confirmado tras liberar el candado (7.000), nunca el stale (10.000).");
                    BigDecimal updated = locked.getStockActual().subtract(new BigDecimal("2.000"));
                    locked.setStockActual(updated);
                    productoRepository.saveAndFlush(locked);
                    return updated;
                });
            });

            assertEquals(0, new BigDecimal("7.000").compareTo(future1.get(10, TimeUnit.SECONDS)));
            assertEquals(0, new BigDecimal("5.000").compareTo(future2.get(10, TimeUnit.SECONDS)));

            Producto refreshed = productoRepository.findById(prod.getIdProducto()).orElseThrow();
            assertEquals(0, new BigDecimal("5.000").compareTo(refreshed.getStockActual()));
        } finally {
            executor.shutdownNow();
        }
    }

    private Bodega crearBodega(String nombre) {
        Bodega b = new Bodega();
        b.setNombreComercial(nombre);
        b.setPlan("PRO");
        b.setEstado(true);
        return bodegaRepository.saveAndFlush(b);
    }

    private Categoria crearCategoria(Bodega bodega, String nombre) {
        Categoria c = new Categoria();
        c.setBodega(bodega);
        c.setNombre(nombre);
        c.setEstado(true);
        return categoriaRepository.saveAndFlush(c);
    }

    private Producto crearProducto(Bodega bodega, Categoria cat, String codigo, String nombre, BigDecimal stock) {
        Producto p = new Producto();
        p.setBodega(bodega);
        p.setCategoria(cat);
        p.setCodigo(codigo);
        p.setNombre(nombre);
        p.setPrecioVenta(new BigDecimal("5.00"));
        p.setStockActual(stock);
        p.setStockMinimo(new BigDecimal("2.000"));
        p.setEstado(true);
        return productoRepository.saveAndFlush(p);
    }

    private Cliente crearCliente(Bodega bodega, String nombre, String doc) {
        Cliente cl = new Cliente();
        cl.setBodega(bodega);
        cl.setNombreCompleto(nombre);
        cl.setDocumento(doc);
        cl.setEstado(true);
        return clienteRepository.saveAndFlush(cl);
    }
}
