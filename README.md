# 🛒 Bodega KARLIZ — Core Backend API

![Java 17](https://img.shields.io/badge/Java-17-orange?logo=openjdk)
![Spring Boot](https://img.shields.io/badge/Spring_Boot-4.1.1-brightgreen?logo=springboot)
![PostgreSQL](https://img.shields.io/badge/Database-PostgreSQL_Supabase-blue?logo=postgresql)
![Docker](https://img.shields.io/badge/Container-Docker-2496ED?logo=docker)
![Render](https://img.shields.io/badge/Deployment-Render_Cloud-46E3B7?logo=render)
![Security](https://img.shields.io/badge/Auth-JWT_%26_BCrypt-red?logo=jsonwebtokens)

API RESTful robusta y de alto rendimiento desarrollada en **Java 17** con el framework **Spring Boot**, diseñada como el núcleo transaccional para la terminal de Punto de Venta (POS) y control integral de inventario de **Bodega KARLIZ**.

---

## 📐 Arquitectura del Sistema

El sistema implementa una **Arquitectura en Capas (Layered Architecture)** siguiendo los principios de alta cohesión, desacoplamiento y responsabilidad única:

```
src/main/java/com/bodega/backend/
├── config/          # Configuraciones generales (CORS, JPA, OpenApi)
├── controller/      # Controladores RESTful y validación de peticiones (@Valid)
├── dto/             # Objetos de Transferencia de Datos desacoplados de la DB
├── entity/          # Entidades JPA (PostgreSQL) con alta precisión decimal
├── exception/       # Manejo global centralizado de excepciones (GlobalExceptionHandler)
├── repository/      # Capa de persistencia con Spring Data JPA
├── security/        # Autenticación JWT, filtros de seguridad y encriptación BCrypt
└── service/         # Lógica de negocio, reglas de validación y control transaccional (@Transactional)
```

---

## 🚀 Tecnologías Principales

- **Lenguaje:** Java 17 (LTS)
- **Framework:** Spring Boot 4.1.1
- **Persistencia:** Spring Data JPA / Hibernate ORM
- **Base de Datos:** PostgreSQL en la nube administrado mediante **Supabase**
- **Seguridad:** Spring Security + JSON Web Tokens (JWT) + BCrypt
- **Validación:** Jakarta Bean Validation (`@NotNull`, `@Positive`, etc.)
- **Contenedores:** Docker (Multi-stage build sobre Alpine Linux)
- **Infraestructura Cloud:** Render Cloud / Containerized Hosting

---

## 📡 Catálogo de Endpoints REST

Todas las respuestas del API utilizan formato JSON estándar.

### 🔐 Autenticación
| Método | Endpoint | Descripción | Acceso |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/auth/login` | Autenticación de usuario y emisión de token JWT | Público |
| `POST` | `/api/auth/register` | Registro de nuevos usuarios o colaboradores | Requiere Admin |

### 📦 Productos e Inventario
| Método | Endpoint | Descripción |
| :--- | :--- | :--- |
| `GET` | `/api/productos` | Lista el catálogo completo de productos con existencias |
| `GET` | `/api/productos/{id}` | Obtiene el detalle técnico y stock de un producto específico |
| `POST` | `/api/productos` | Registra un nuevo producto en el catálogo |
| `PUT` | `/api/productos/{id}` | Actualiza datos (nombre, precio, stock mínimo) |
| `DELETE` | `/api/productos/{id}` | Desactiva o elimina un producto del catálogo |

### 🏷️ Categorías
| Método | Endpoint | Descripción |
| :--- | :--- | :--- |
| `GET` | `/api/categorias` | Lista las familias y categorías comerciales |
| `POST` | `/api/categorias` | Crea una nueva categoría |

### 💵 Ventas (Terminal POS)
| Método | Endpoint | Descripción |
| :--- | :--- | :--- |
| `GET` | `/api/ventas` | Historial de transacciones y cierres de caja |
| `POST` | `/api/ventas` | Registra una venta en mostrador (descuenta stock en tiempo real) |

### 🚚 Compras y Abastecimiento
| Método | Endpoint | Descripción |
| :--- | :--- | :--- |
| `GET` | `/api/compras` | Historial de ingresos de mercadería de distribuidores |
| `POST` | `/api/compras` | Registra compra a proveedor (incrementa stock automáticamente) |

### 🏢 Proveedores
| Método | Endpoint | Descripción |
| :--- | :--- | :--- |
| `GET` | `/api/proveedores` | Lista de distribuidores y empresas mayoristas |
| `POST` | `/api/proveedores` | Registro de nuevo distribuidor con RUC y razón social |

---

## ⚙️ Variables de Entorno Requeridas

Para ejecutar la aplicación (tanto en local como en la nube), se requieren las siguientes variables:

| Variable | Descripción | Ejemplo / Valor |
| :--- | :--- | :--- |
| `DB_URL` | URL de conexión JDBC a PostgreSQL | `jdbc:postgresql://aws-1-us-west-2.pooler.supabase.com:5432/postgres` |
| `DB_USERNAME` | Usuario de la base de datos | `postgres.rmdbcmnoanyqumjlfphy` |
| `DB_PASSWORD` | Contraseña asignada en Supabase | `[TU_CONTRASEÑA]` |
| `JWT_SECRET` | Clave criptográfica para firma de tokens | *(Clave alfanumérica de 256 bits)* |
| `PORT` | Puerto de escucha HTTP | `8080` |

---

## ☁️ Despliegue en Render (Paso a Paso)

Este repositorio incluye un `Dockerfile` optimizado con recolección de basura `SerialGC` y límites de memoria adaptados al entorno gratuito de 512 MB de Render.

1. **Crear Servicio Web:**
   - En [Render Dashboard](https://dashboard.render.com/), haz clic en **"New +"** y selecciona **"Web Service"**.
   - Conecta tu cuenta de **GitHub** y selecciona el repositorio `angxl10t/bodega-karliz-backend`.
2. **Configuración de Build:**
   - Nombre: `bodega-karliz-backend` (o el de tu preferencia).
   - Runtime / Environment: **Docker** (detectará automáticamente el `Dockerfile`).
   - Plan: **Free** (512 MB RAM / 0.1 CPU).
3. **Variables de Entorno (Environment Variables):**
   - Agrega las variables requeridas:
     * `DB_URL` = `jdbc:postgresql://aws-1-us-west-2.pooler.supabase.com:5432/postgres`
     * `DB_USERNAME` = `postgres.rmdbcmnoanyqumjlfphy`
     * `DB_PASSWORD` = `[TU_CONTRASEÑA_SUPABASE]`
     * `JWT_SECRET` = `karliz_pos_secure_production_secret_key_2026_998877`
4. **Despliegue y URL Pública:**
   - Haz clic en **"Create Web Service"**.
   - Render compilará la imagen Docker y en pocos minutos generará tu dominio HTTPS público (ej. `https://bodega-karliz-backend.onrender.com`).

---

## 💻 Ejecución Local

### Opción 1: Con Maven Wrapper
```bash
# En Windows (PowerShell)
$env:DB_URL="jdbc:postgresql://aws-1-us-west-2.pooler.supabase.com:5432/postgres"
$env:DB_USERNAME="postgres.rmdbcmnoanyqumjlfphy"
$env:DB_PASSWORD="TU_CONTRASEÑA"
.\mvnw spring-boot:run
```

### Opción 2: Con Docker
```bash
docker build -t bodega-karliz-backend .
docker run -p 8080:8080 \
  -e DB_URL="jdbc:postgresql://..." \
  -e DB_USERNAME="postgres..." \
  -e DB_PASSWORD="TU_CONTRASEÑA" \
  bodega-karliz-backend
```

---

## 📄 Licencia y Créditos
Desarrollado para el sistema comercial y terminal de caja de **Bodega KARLIZ**.  
Todos los derechos reservados © 2026.
