package com.bodega.backend.controller;

import com.bodega.backend.dto.DashboardBiDTO;
import com.bodega.backend.service.AnalyticsService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/analytics")
public class AnalyticsController {

    private final AnalyticsService analyticsService;

    public AnalyticsController(AnalyticsService analyticsService) {
        this.analyticsService = analyticsService;
    }

    @GetMapping("/dashboard-bi")
    @PreAuthorize("hasAnyRole('ADMIN', 'SUPERADMIN', 'CAJERO')")
    public ResponseEntity<DashboardBiDTO> obtenerDashboardBi(
            @RequestParam(defaultValue = "30") int dias) {
        return ResponseEntity.ok(analyticsService.obtenerDashboardBi(dias));
    }
}
