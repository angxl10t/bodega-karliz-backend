package com.bodega.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.core.Ordered;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.transaction.annotation.EnableTransactionManagement;

@SpringBootApplication
@EnableTransactionManagement(order = Ordered.HIGHEST_PRECEDENCE + 10)
@EnableScheduling
@EnableAsync
public class BodegaBackendApplication {

	public static void main(String[] args) {
		SpringApplication.run(BodegaBackendApplication.class, args);
	}
}
