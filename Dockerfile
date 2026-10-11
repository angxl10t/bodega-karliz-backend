# ==========================================
# Fase 1: Build de la aplicación con Maven
# ==========================================
FROM maven:3.9.6-eclipse-temurin-17-alpine AS builder
WORKDIR /app

# Copiar configuración y código fuente
COPY pom.xml .
COPY src ./src

# Compilar jar empaquetado omitiendo tests
RUN mvn clean package -DskipTests

# ==========================================
# Fase 2: Runtime ligero optimizado (512MB RAM)
# ==========================================
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Certificados SSL para conexiones seguras a PostgreSQL/Supabase
RUN apk add --no-cache ca-certificates

# Crear usuario no root por seguridad
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Copiar el jar compilado desde la fase de build
COPY --from=builder /app/target/*.jar app.jar

# Puerto por defecto
ENV PORT=8080
EXPOSE 8080

# Optimización de JVM para entornos restringidos
ENV JAVA_OPTS="-XX:+UseSerialGC -XX:MaxRAMPercentage=70.0 -XX:+TieredCompilation -XX:TieredStopAtLevel=1 -Xss256k"

# Arrancar Spring Boot asegurando que escuche en el puerto asignado por Render ($PORT)
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -Dserver.port=${PORT} -jar app.jar"]

