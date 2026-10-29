package com.bodega.backend.service;







import com.bodega.backend.dto.ActualizarBodegaDTO;



import com.bodega.backend.dto.BodegaDTO;



import com.bodega.backend.dto.ProvisionarBodegaDTO;



import com.bodega.backend.entity.Bodega;



import com.bodega.backend.repository.BodegaRepository;



import com.bodega.backend.repository.CategoriaRepository;



import com.bodega.backend.repository.CompraRepository;



import com.bodega.backend.repository.MovimientoInventarioRepository;



import com.bodega.backend.repository.PagoSuscripcionRepository;



import com.bodega.backend.repository.ProductoRepository;



import com.bodega.backend.repository.UsuarioRepository;



import com.bodega.backend.repository.VentaRepository;



import com.bodega.backend.security.UserSecurityCacheService;



import org.springframework.security.crypto.password.PasswordEncoder;



import org.springframework.stereotype.Service;



import org.springframework.transaction.annotation.Transactional;







@Service



public class BodegaService {







    private final BodegaRepository bodegaRepository;



    private final TenantService tenantService;



    private final UserSecurityCacheService userSecurityCacheService;



    private final PagoSuscripcionRepository pagoSuscripcionRepository;



    private final UsuarioRepository usuarioRepository;



    private final VentaRepository ventaRepository;



    private final ProductoRepository productoRepository;



    private final CompraRepository compraRepository;



    private final MovimientoInventarioRepository movimientoInventarioRepository;



    private final CategoriaRepository categoriaRepository;



    private final PasswordEncoder passwordEncoder;







    private final java.util.concurrent.atomic.AtomicReference<java.util.Map<String, Object>> anuncioGlobal =



            new java.util.concurrent.atomic.AtomicReference<>(null);







    private final StarterPackService starterPackService;



    private final com.bodega.backend.repository.YapeTransaccionRecibidaRepository yapeTransaccionRecibidaRepository;







    public BodegaService(BodegaRepository bodegaRepository,



                         TenantService tenantService,



                         UserSecurityCacheService userSecurityCacheService,



                         PagoSuscripcionRepository pagoSuscripcionRepository,



                         UsuarioRepository usuarioRepository,



                         VentaRepository ventaRepository,



                         ProductoRepository productoRepository,



                         CompraRepository compraRepository,



                         MovimientoInventarioRepository movimientoInventarioRepository,



                         CategoriaRepository categoriaRepository,



                         PasswordEncoder passwordEncoder,



                         StarterPackService starterPackService,

                          com.bodega.backend.repository.YapeTransaccionRecibidaRepository yapeTransaccionRecibidaRepository) {



        this.bodegaRepository = bodegaRepository;



        this.tenantService = tenantService;



        this.userSecurityCacheService = userSecurityCacheService;



        this.pagoSuscripcionRepository = pagoSuscripcionRepository;



        this.usuarioRepository = usuarioRepository;



        this.ventaRepository = ventaRepository;



        this.productoRepository = productoRepository;



        this.compraRepository = compraRepository;



        this.movimientoInventarioRepository = movimientoInventarioRepository;



        this.categoriaRepository = categoriaRepository;



        this.passwordEncoder = passwordEncoder;



        this.starterPackService = starterPackService;



        this.yapeTransaccionRecibidaRepository = yapeTransaccionRecibidaRepository;



    }







    @Transactional(readOnly = true)



    public BodegaDTO obtenerMiBodega() {



        Bodega bodega = tenantService.getCurrentBodega();



        return mapToDTO(bodega);



    }







    @Transactional(readOnly = true)



    public java.util.List<BodegaDTO> listarTodas() {



        java.util.Map<Long, Long> countsMap = new java.util.HashMap<>();



        if (productoRepository != null) {



            try {



                java.util.List<Object[]> counts = productoRepository.countActiveProductsGroupedByBodega();



                if (counts != null) {



                    for (Object[] row : counts) {



                        if (row != null && row.length >= 2 && row[0] != null && row[1] != null) {



                            countsMap.put(((Number) row[0]).longValue(), ((Number) row[1]).longValue());



                        }



                    }



                }



            } catch (Exception ignored) {}



        }







        return bodegaRepository.findAll(org.springframework.data.domain.Sort.by(org.springframework.data.domain.Sort.Direction.ASC, "idBodega"))



                .stream()



                .map(b -> mapToDTO(b, countsMap.getOrDefault(b.getIdBodega(), 0L)))



                .collect(java.util.stream.Collectors.toList());



    }







    @Transactional(readOnly = true)



    public BodegaDTO obtenerPorId(Long idBodega) {



        var auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();



        boolean isSuperAdmin = auth != null && auth.getAuthorities() != null && 



                auth.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals("ROLE_SUPERADMIN"));



        if (!isSuperAdmin) {



            Long currentBodegaId = tenantService.getCurrentBodegaId();



            if (currentBodegaId == null || !currentBodegaId.equals(idBodega)) {



                throw new org.springframework.security.access.AccessDeniedException(



                        "No tienes permisos para ver información de otra bodega."



                );



            }



        }



        Bodega b = bodegaRepository.findById(idBodega)



                .orElseThrow(() -> new RuntimeException("Bodega con ID " + idBodega + " no encontrada"));



        return mapToDTO(b);



    }







    @Transactional



    public BodegaDTO actualizarConfiguracion(ActualizarBodegaDTO dto) {



        Bodega bodega = tenantService.getCurrentBodega();







        // Nivel 1: Identidad básica comercial



        if (dto.getNombreComercial() != null && !dto.getNombreComercial().isBlank()) {



            bodega.setNombreComercial(dto.getNombreComercial().trim());



        }



        bodega.setRucDni(dto.getRucDni() != null && !dto.getRucDni().isBlank() ? dto.getRucDni().trim() : null);



        bodega.setDireccion(dto.getDireccion() != null && !dto.getDireccion().isBlank() ? dto.getDireccion().trim() : null);



        bodega.setTelefono(dto.getTelefono() != null && !dto.getTelefono().isBlank() ? dto.getTelefono().trim() : null);



        bodega.setLemaComercial(dto.getLemaComercial() != null && !dto.getLemaComercial().isBlank() ? dto.getLemaComercial().trim() : null);



        if (dto.getRegimenTributario() != null && !dto.getRegimenTributario().isBlank()) {



            bodega.setRegimenTributario(dto.getRegimenTributario().trim().toUpperCase());



        }







        String plan = (bodega.getPlan() != null) ? bodega.getPlan().toUpperCase() : "BASICO";







        // Nivel 2: Paleta de acento & Branding (Exclusivo Plan PRO)



        if (dto.getColorPrimario() != null && !dto.getColorPrimario().isBlank()) {



            String nuevoColor = dto.getColorPrimario().trim();



            // Si el color es diferente al azul por defecto de CajaYa (#2563EB) y no es Plan PRO



            boolean esDefault = "#2563EB".equalsIgnoreCase(nuevoColor);



            if (!esDefault && !"PRO".equalsIgnoreCase(plan)) {



                throw new RuntimeException("La personalización exclusiva de paleta de colores requiere el Plan Minimarket Pro. " +



                        "En el Plan Bodega se utiliza la paleta estándar de CajaYa.");



            }



            bodega.setColorPrimario(nuevoColor);



        }







        if (dto.getLogoUrl() != null && !dto.getLogoUrl().isBlank()) {



            if (!"PRO".equalsIgnoreCase(plan)) {



                throw new RuntimeException("La incorporación de logotipo personalizado en comprobantes y pantalla requiere el Plan Minimarket Pro.");



            }



            bodega.setLogoUrl(dto.getLogoUrl().trim());



        } else if (dto.getLogoUrl() != null && dto.getLogoUrl().isBlank()) {



            bodega.setLogoUrl(null);



        }







        Bodega guardada = bodegaRepository.save(bodega);



        // Invalidar caché de perfiles para que todos los usuarios de la bodega reflejen la nueva configuración de inmediato



        userSecurityCacheService.evictAll();







        return mapToDTO(guardada);



    }







    /**



     * Solución 1: Renovación Directa de Suscripción vía Yape / Plin (0% Comisiones)



     */



    @Transactional



    public BodegaDTO registrarPagoYape(com.bodega.backend.dto.PagoYapeDTO dto) {



        Bodega bodega = tenantService.getCurrentBodega();







        String codOp = dto.getCodigoOperacion() != null ? dto.getCodigoOperacion().trim() : "";



        String billetera = dto.getBilletera() != null ? dto.getBilletera().trim().toUpperCase() : "YAPE";







        // 1. Blindaje Anti-Fraude: Prevención estricta de vouchers/códigos reutilizados en historial



        if (pagoSuscripcionRepository.existsByBilleteraIgnoreCaseAndCodigoOperacion(billetera, codOp)) {



            throw new RuntimeException("El código de operación '" + codOp + "' de " + billetera + 



                    " ya fue registrado y procesado previamente. Los comprobantes de pago no pueden reutilizarse.");



        }







        // 2. Validar coherencia de montos oficiales solicitados



        String planSolicitado = dto.getPlan().trim().toUpperCase();



        java.math.BigDecimal montoEsperado = "PRO".equals(planSolicitado) 



                ? new java.math.BigDecimal("100.00") 



                : new java.math.BigDecimal("50.00");







        if (dto.getMonto().compareTo(montoEsperado) < 0) {



            throw new RuntimeException("El monto enviado (S/ " + dto.getMonto() + 



                    ") es inferior a la tarifa oficial del Plan " + planSolicitado + " (S/ " + montoEsperado + ").");



        }







        // 3. Validación Real con Conciliación Autónoma (Opción B: Bot Notifier Webhook en celular de Luis T.)



        java.util.Optional<com.bodega.backend.entity.YapeTransaccionRecibida> txOpt =



                yapeTransaccionRecibidaRepository.findByCodigoOperacionForUpdate(codOp);







        if (txOpt.isEmpty()) {



            var yaCanjeadoOpt = yapeTransaccionRecibidaRepository.findFirstByCodigoOperacion(codOp);



            if (yaCanjeadoOpt.isPresent() && yaCanjeadoOpt.get().isUsado()) {



                throw new RuntimeException("El comprobante con código de operación '" + codOp + 



                        "' ya fue validado y canjeado previamente para activar otra suscripción.");



            }



            throw new RuntimeException("No se encontró ningún abono de " + billetera + 



                    " por S/ " + montoEsperado + " con el código de operación '" + codOp + "'. " +



                    "Si acabas de realizar la transferencia, espera unos 30 segundos a que ingrese a la cuenta y vuelve a presionar Confirmar.");



        }







        com.bodega.backend.entity.YapeTransaccionRecibida tx = txOpt.get();



        if (tx.getMonto().compareTo(montoEsperado) < 0) {



            throw new RuntimeException("El abono bancario recibido con la operación '" + codOp + 



                    "' fue de S/ " + tx.getMonto() + ", monto insuficiente para el Plan " + planSolicitado + " (S/ " + montoEsperado + ").");



        }







        // Marcar la transacción real como usada y asociarla a la bodega para auditoría inmutable



        tx.setUsado(true);



        tx.setIdBodegaAsignada(bodega.getIdBodega());



        tx.setFechaUso(java.time.OffsetDateTime.now());



        yapeTransaccionRecibidaRepository.save(tx);







        // Extensión acumulativa: Si el plan aún está vigente, suma 30 días al vencimiento actual; si no, 30 días desde hoy



        java.time.OffsetDateTime baseTime = (bodega.getFechaVencimientoPlan() != null && bodega.getFechaVencimientoPlan().isAfter(java.time.OffsetDateTime.now()))



                ? bodega.getFechaVencimientoPlan()



                : java.time.OffsetDateTime.now();







        bodega.setFechaVencimientoPlan(baseTime.plusDays(30));



        bodega.setPlan(planSolicitado);



        bodega.setEstado(true);







        Bodega guardada = bodegaRepository.save(bodega);







        // Registro de Auditoría en Libro Mayor de Suscripciones (Zero Data Loss)



        var auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();



        String usuarioActual = (auth != null && auth.isAuthenticated() && !"anonymousUser".equals(auth.getName())) 



                ? auth.getName() : "ADMIN";







        com.bodega.backend.entity.PagoSuscripcion pago = new com.bodega.backend.entity.PagoSuscripcion();



        pago.setBodega(guardada);



        pago.setCodigoOperacion(codOp);



        pago.setBilletera(billetera);



        pago.setPlan(planSolicitado);



        pago.setMonto(dto.getMonto());



        pago.setUsuarioRegistro(usuarioActual);



        pago.setEstado("CONFIRMADO");



        pagoSuscripcionRepository.save(pago);







        userSecurityCacheService.evictAll();







        return mapToDTO(guardada);



    }







    /**



     * Solución 2: Activación y Configuración del Módulo SUNAT



     * REGLA DE SEGURIDAD ESTRICTA: Solo el Administrador de la bodega puede activar,



     * desactivar o configurar credenciales de facturación. Los cajeros tienen acceso denegado.



     */



    @Transactional



    public BodegaDTO actualizarConfiguracionSunat(com.bodega.backend.dto.ConfiguracionSunatDTO dto) {



        // Validación de Rol en Contexto de Seguridad



        var auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();



        boolean esAdmin = auth != null && auth.getAuthorities().stream().anyMatch(



                a -> a.getAuthority().equals("ROLE_ADMIN") || a.getAuthority().equals("ROLE_SUPERADMIN")



        );







        if (!esAdmin) {



            throw new RuntimeException("Acceso Denegado: Solo el Administrador de la bodega puede activar o modificar la Facturación Electrónica SUNAT. Los cajeros no tienen permisos para alterar este módulo.");



        }







        Bodega bodega = tenantService.getCurrentBodega();







        if (dto.getRegimenTributario() != null && !dto.getRegimenTributario().isBlank()) {



            bodega.setRegimenTributario(dto.getRegimenTributario().trim().toUpperCase());



        }







        if (dto.getFacturacionSunatActiva() != null) {



            bodega.setFacturacionSunatActiva(dto.getFacturacionSunatActiva());



        }







        if (dto.getSunatProveedor() != null && !dto.getSunatProveedor().isBlank()) {



            bodega.setSunatProveedor(dto.getSunatProveedor().trim());



        }







        if (dto.getSunatRucEmisor() != null) {



            bodega.setSunatRucEmisor(dto.getSunatRucEmisor().isBlank() ? null : dto.getSunatRucEmisor().trim());



        }







        if (dto.getSunatUsuarioSol() != null) {



            bodega.setSunatUsuarioSol(dto.getSunatUsuarioSol().isBlank() ? null : dto.getSunatUsuarioSol().trim());



        }







        if (dto.getSunatTokenApi() != null) {



            bodega.setSunatTokenApi(dto.getSunatTokenApi().isBlank() ? null : dto.getSunatTokenApi().trim());



        }







        if (dto.getSerieBoleta() != null && !dto.getSerieBoleta().isBlank()) {



            String serieB = dto.getSerieBoleta().trim().toUpperCase();



            if (!serieB.matches("^[B][A-Z0-9]{3}$")) {



                throw new RuntimeException("La serie de boleta debe tener 4 caracteres e iniciar con 'B' (ej: B001)");



            }



            bodega.setSerieBoleta(serieB);



        }







        if (dto.getSerieFactura() != null && !dto.getSerieFactura().isBlank()) {



            String serieF = dto.getSerieFactura().trim().toUpperCase();



            if (!serieF.matches("^[F][A-Z0-9]{3}$")) {



                throw new RuntimeException("La serie de factura debe tener 4 caracteres e iniciar con 'F' (ej: F001)");



            }



            bodega.setSerieFactura(serieF);



        }







        Bodega guardada = bodegaRepository.save(bodega);



        userSecurityCacheService.evictAll();







        return mapToDTO(guardada);



    }







    private BodegaDTO mapToDTO(Bodega b) {



        long totalActivos = (productoRepository != null && b.getIdBodega() != null)



                ? productoRepository.countByBodega_IdBodegaAndEstadoTrue(b.getIdBodega())



                : 0L;



        return mapToDTO(b, totalActivos);



    }







    private BodegaDTO mapToDTO(Bodega b, long totalActivos) {



        BodegaDTO dto = new BodegaDTO();



        dto.setIdBodega(b.getIdBodega());



        dto.setNombreComercial(b.getNombreComercial());



        dto.setRucDni(b.getRucDni());



        dto.setDireccion(b.getDireccion());



        dto.setTelefono(b.getTelefono());



        dto.setLogoUrl(b.getLogoUrl());



        dto.setColorPrimario(b.getColorPrimario() != null ? b.getColorPrimario() : "#2563EB");



        dto.setLemaComercial(b.getLemaComercial());



        dto.setPlan(b.getPlan());



        dto.setEstado(b.getEstado());



        dto.setFechaRegistro(b.getFechaRegistro());



        dto.setFechaVencimientoPlan(b.getFechaVencimientoPlan());



        dto.setRegimenTributario(b.getRegimenTributario() != null ? b.getRegimenTributario() : "NUEVO_RUS");







        // Campos Módulo SUNAT



        dto.setFacturacionSunatActiva(Boolean.TRUE.equals(b.getFacturacionSunatActiva()));



        dto.setSunatProveedor(b.getSunatProveedor());



        dto.setSunatRucEmisor(b.getSunatRucEmisor());



        dto.setSunatUsuarioSol(b.getSunatUsuarioSol());



        dto.setSerieBoleta(b.getSerieBoleta());



        dto.setSerieFactura(b.getSerieFactura());



        dto.setUltimoCorrelativoBoleta(b.getUltimoCorrelativoBoleta());



        dto.setUltimoCorrelativoFactura(b.getUltimoCorrelativoFactura());







        // Cuotas SaaS por Plan



        dto.setTotalProductosActivos(totalActivos);



        if ("BASICO".equalsIgnoreCase(b.getPlan())) {



            dto.setLimiteProductos(150);



            dto.setLimiteAlcanzado(totalActivos >= 150);



        } else {



            dto.setLimiteProductos(null); // Ilimitado para PRO y otros planes superiores



            dto.setLimiteAlcanzado(false);



        }







        return dto;



    }







    @Transactional



    public BodegaDTO cambiarEstadoBodega(Long idBodega, boolean activo) {



        Bodega bodega = bodegaRepository.findById(idBodega)



                .orElseThrow(() -> new RuntimeException("Bodega con ID " + idBodega + " no encontrada"));



        bodega.setEstado(activo);



        Bodega guardada = bodegaRepository.save(bodega);



        userSecurityCacheService.evictAll();



        return mapToDTO(guardada);



    }







    @Transactional



    public BodegaDTO cambiarPlanBodega(Long idBodega, String nuevoPlan, Integer diasVigencia) {



        Bodega bodega = bodegaRepository.findById(idBodega)



                .orElseThrow(() -> new RuntimeException("Bodega con ID " + idBodega + " no encontrada"));



        if (nuevoPlan != null && !nuevoPlan.isBlank()) {



            bodega.setPlan(nuevoPlan.trim().toUpperCase());



        }



        int dias = (diasVigencia != null && diasVigencia > 0) ? diasVigencia : 30;



        bodega.setFechaVencimientoPlan(java.time.OffsetDateTime.now().plusDays(dias));



        Bodega guardada = bodegaRepository.save(bodega);



        userSecurityCacheService.evictAll();



        return mapToDTO(guardada);



    }







    @Transactional(readOnly = true)



    public java.util.Map<String, Object> obtenerMetricasSistema() {



        java.util.Map<String, Object> metricas = new java.util.HashMap<>();



        long totalBodegas = bodegaRepository != null ? bodegaRepository.count() : 0;



        long bodegasActivas = bodegaRepository != null ? bodegaRepository.countByEstadoTrue() : 0;



        long bodegasInactivas = Math.max(0, totalBodegas - bodegasActivas);



        long bodegasPro = bodegaRepository != null ? bodegaRepository.countByPlanIgnoreCase("PRO") : 0;



        long bodegasBasico = Math.max(0, totalBodegas - bodegasPro);







        long totalUsuarios = usuarioRepository != null ? usuarioRepository.count() : 0;



        long totalVentas = ventaRepository != null ? ventaRepository.count() : 0;



        long totalProductos = productoRepository != null ? productoRepository.count() : 0;



        long totalCompras = compraRepository != null ? compraRepository.count() : 0;



        long totalMovimientos = movimientoInventarioRepository != null ? movimientoInventarioRepository.count() : 0;



        long totalCategorias = categoriaRepository != null ? categoriaRepository.count() : 0;







        long totalPagos = pagoSuscripcionRepository != null ? pagoSuscripcionRepository.count() : 0;



        java.math.BigDecimal totalRecaudado = pagoSuscripcionRepository != null 



                ? pagoSuscripcionRepository.sumarTotalRecaudado() 



                : java.math.BigDecimal.ZERO;



        if (totalRecaudado == null) {



            totalRecaudado = java.math.BigDecimal.ZERO;



        }







        metricas.put("totalBodegas", totalBodegas);



        metricas.put("bodegasActivas", bodegasActivas);



        metricas.put("bodegasInactivas", bodegasInactivas);



        metricas.put("bodegasPro", bodegasPro);



        metricas.put("bodegasBasico", bodegasBasico);



        metricas.put("totalUsuarios", totalUsuarios);



        metricas.put("totalVentas", totalVentas);



        metricas.put("totalProductos", totalProductos);



        metricas.put("totalCompras", totalCompras);



        metricas.put("totalMovimientos", totalMovimientos);



        metricas.put("totalCategorias", totalCategorias);



        metricas.put("totalPagos", totalPagos);



        metricas.put("totalRecaudado", totalRecaudado);







        return metricas;



    }







    @Transactional



    public BodegaDTO provisionarBodega(ProvisionarBodegaDTO dto) {



        String username = dto.getAdminUsername() != null ? dto.getAdminUsername().trim().toLowerCase() : "";



        if (username.isBlank()) {



            throw new RuntimeException("El nombre de usuario administrador no puede estar vacío.");



        }



        if (!username.matches("^[a-zA-Z0-9._-]+$")) {



            throw new RuntimeException("El nombre de usuario solo puede contener letras, números, puntos (.), guiones (-) y guiones bajos (_).");



        }



        if (usuarioRepository.existsByUsernameIgnoreCase(username)) {



            throw new RuntimeException("El nombre de usuario '" + username + "' ya está registrado. Por favor elija otro.");



        }



        if (dto.getAdminPassword() == null || dto.getAdminPassword().trim().length() < 4) {



            throw new RuntimeException("La contraseña inicial debe tener al menos 4 caracteres.");



        }







        Bodega bodega = new Bodega();



        bodega.setNombreComercial(dto.getNombreComercial().trim());



        bodega.setRucDni(dto.getRucDni() != null && !dto.getRucDni().isBlank() ? dto.getRucDni().trim() : null);



        bodega.setDireccion(dto.getDireccion() != null && !dto.getDireccion().isBlank() ? dto.getDireccion().trim() : null);



        bodega.setTelefono(dto.getTelefono() != null && !dto.getTelefono().isBlank() ? dto.getTelefono().trim() : null);



        bodega.setColorPrimario(dto.getColorPrimario() != null && !dto.getColorPrimario().isBlank() ? dto.getColorPrimario().trim() : "#2563EB");



        bodega.setLemaComercial(dto.getLemaComercial() != null && !dto.getLemaComercial().isBlank() ? dto.getLemaComercial().trim() : null);







        String regimen = (dto.getRegimenTributario() != null && !dto.getRegimenTributario().isBlank())



                ? dto.getRegimenTributario().trim().toUpperCase() : "NUEVO_RUS";



        bodega.setRegimenTributario(regimen);







        String plan = (dto.getPlan() != null && !dto.getPlan().isBlank()) ? dto.getPlan().trim().toUpperCase() : "PRO";



        bodega.setPlan("BASICO".equals(plan) ? "BASICO" : "PRO");



        bodega.setEstado(true);







        int dias = (dto.getDiasVigencia() != null && dto.getDiasVigencia() > 0) ? dto.getDiasVigencia() : 30;



        bodega.setFechaVencimientoPlan(java.time.OffsetDateTime.now().plusDays(dias));







        Bodega guardada = bodegaRepository.save(bodega);







        // Crear Administrador Inicial de la Bodega



        com.bodega.backend.entity.Usuario admin = new com.bodega.backend.entity.Usuario();



        admin.setUsername(username);



        admin.setPassword(passwordEncoder.encode(dto.getAdminPassword().trim()));



        admin.setNombreCompleto(dto.getNombreComercial().trim());



        admin.setRol("ADMIN");



        admin.setEstado(true);



        admin.setFechaCambioClave(java.time.OffsetDateTime.now());



        admin.setBodega(guardada);



        usuarioRepository.save(admin);







        // Clonar catálogo estándar y Starter Pack con stock inicial en 0



        starterPackService.provisionarStarterPackParaBodega(guardada);







        userSecurityCacheService.evictAll();







        return mapToDTO(guardada);



    }







    private void clonarCategoriasMaestras(Bodega bodega) {



        if (categoriaRepository == null) return;



        String[][] categoriasDefault = {



            {"Gaseosas y Bebidas", "Gaseosas, aguas minerales, jugos, energizantes e hidratantes"},



            {"Bebidas Alcohólicas", "Cervezas, piscos, rones, vinos y licores"},



            {"Snacks y Piqueos", "Papas fritas, chizitos, tortillas, platanitos y frutos secos"},



            {"Lácteos y Derivados", "Leche evaporada, fresca, yogures, mantequillas y quesos"},



            {"Embutidos y Fiambrería", "Hot dogs, jamonadas, salchichas, tocinos y embutidos"},



            {"Abarrotes y Fideos", "Arroz, azúcar, fideos, aceites, conservas y condimentos"},



            {"Helados y Postres", "Helados en paleta, conos, bombones y potes familiares"},



            {"Golosinas y Chocolates", "Chocolates, galletas dulces, caramelos y confitería"},



            {"Cuidado Personal y Dental", "Cremas dentales, jabones, champús y papel"},



            {"Limpieza y Cuidado del Hogar", "Detergentes, lejías, lavavajillas, suavizantes y esponjas"},



            {"Cigarrillos y Tabacos", "Cigarrillos en cajetilla, fósforos y encendedores"},



            {"Panadería y Desayuno", "Pan de molde, mermeladas, café, avena e infusiones"}



        };







        java.util.List<com.bodega.backend.entity.Categoria> cats = new java.util.ArrayList<>();



        for (String[] catData : categoriasDefault) {



            com.bodega.backend.entity.Categoria cat = new com.bodega.backend.entity.Categoria();



            cat.setNombre(catData[0]);



            cat.setDescripcion(catData[1]);



            cat.setEstado(true);



            cat.setBodega(bodega);



            cats.add(cat);



        }



        categoriaRepository.saveAll(cats);



    }







    @Transactional



    public com.bodega.backend.dto.PagoSuscripcionDTO cambiarEstadoPago(Long idPago, String nuevoEstado) {



        com.bodega.backend.entity.PagoSuscripcion pago = pagoSuscripcionRepository.findById(idPago)



                .orElseThrow(() -> new RuntimeException("Pago de suscripción con ID " + idPago + " no encontrado"));



        String estadoNorm = (nuevoEstado != null && !nuevoEstado.isBlank()) ? nuevoEstado.trim().toUpperCase() : "CONFIRMADO";



        pago.setEstado(estadoNorm);



        com.bodega.backend.entity.PagoSuscripcion guardado = pagoSuscripcionRepository.save(pago);



        return mapPagoToDTO(guardado);



    }







    public java.util.Map<String, Object> obtenerAnuncioGlobal() {



        java.util.Map<String, Object> a = anuncioGlobal.get();



        return (a != null) ? a : java.util.Collections.emptyMap();



    }







    public java.util.Map<String, Object> publicarAnuncioGlobal(java.util.Map<String, Object> req) {



        java.util.Map<String, Object> datos = new java.util.HashMap<>(req);



        datos.put("fechaEmision", java.time.OffsetDateTime.now().toString());



        datos.put("activo", true);



        anuncioGlobal.set(datos);



        return datos;



    }







    public void eliminarAnuncioGlobal() {



        anuncioGlobal.set(null);



    }







    @Transactional(readOnly = true)



    public java.util.List<com.bodega.backend.dto.PagoSuscripcionDTO> listarMisPagos() {



        Bodega bodega = tenantService.getCurrentBodega();



        return pagoSuscripcionRepository.findByBodega_IdBodegaOrderByFechaPagoDesc(bodega.getIdBodega())



                .stream()



                .map(this::mapPagoToDTO)



                .collect(java.util.stream.Collectors.toList());



    }







    @Transactional(readOnly = true)



    public java.util.List<com.bodega.backend.dto.PagoSuscripcionDTO> listarTodosLosPagos() {



        return pagoSuscripcionRepository.findAllByOrderByFechaPagoDesc()



                .stream()



                .map(this::mapPagoToDTO)



                .collect(java.util.stream.Collectors.toList());



    }







    private com.bodega.backend.dto.PagoSuscripcionDTO mapPagoToDTO(com.bodega.backend.entity.PagoSuscripcion p) {



        com.bodega.backend.dto.PagoSuscripcionDTO dto = new com.bodega.backend.dto.PagoSuscripcionDTO();



        dto.setIdPago(p.getIdPago());



        if (p.getBodega() != null) {



            dto.setIdBodega(p.getBodega().getIdBodega());



            dto.setNombreBodega(p.getBodega().getNombreComercial());



        }



        dto.setCodigoOperacion(p.getCodigoOperacion());



        dto.setBilletera(p.getBilletera());



        dto.setPlan(p.getPlan());



        dto.setMonto(p.getMonto());



        dto.setFechaPago(p.getFechaPago());



        dto.setUsuarioRegistro(p.getUsuarioRegistro());



        dto.setEstado(p.getEstado());



        return dto;



    }



}



