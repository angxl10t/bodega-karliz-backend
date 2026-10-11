# ==========================================
# Fase 1: Build de la aplicación con Maven
# ==========================================
FROM maven:3.9.6-eclipse-temurin-17-alpine AS builder
WORKDIR /app

# Copiamos pom.xml para aprovechar la caché de dependencias
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copiamos el código fuente y empaquetamos el proyecto
COPY src ./src
RUN mvn clean package -DskipTests

# ==========================================
# Fase 2: Runtime ligero optimizado para Koyeb (512MB RAM)
# ==========================================
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Crear usuario no root por seguridad
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Copiar el jar compilado desde la fase de build
COPY --from=builder /app/target/*.jar app.jar

# Puerto de la aplicación
EXPOSE 8080

# Optimización de JVM para entornos restringidos (Koyeb Free Tier)
# -XX:+UseSerialGC: Recolector ligero en memoria
# -XX:MaxRAMPercentage=70.0: Límite seguro del 70% de la RAM del contenedor
# -XX:+TieredCompilation -XX:TieredStopAtLevel=1: Reduce uso de RAM por compilación JIT
# -Xss256k: Tamaño de stack optimizado
ENV JAVA_OPTS="-XX:+UseSerialGC -XX:MaxRAMPercentage=70.0 -XX:+TieredCompilation -XX:TieredStopAtLevel=1 -Xss256k"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
