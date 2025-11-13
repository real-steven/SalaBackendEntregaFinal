package api

import (
	"database/sql"
	"fmt"
	"net/http"
	"restapi/dto"
	"strconv"

	"github.com/gin-gonic/gin"
)

type ServicioInput struct {
	Nombre      string  `json:"nombre"`
	Descripcion string  `json:"descripcion"`
	Precio      float64 `json:"precio"`
}

func CrearServicio(c *gin.Context) {
	rol, _ := c.Get("rol")
	fmt.Printf("🔐 Rol obtenido del token: %v\n", rol)
	if rol != "admin" {
		fmt.Println("❌ Error de autorización: Rol no es admin")
		c.JSON(http.StatusForbidden, gin.H{"error": "Solo administradores pueden crear servicios"})
		return
	}

	var input ServicioInput
	if err := c.ShouldBindJSON(&input); err != nil {
		fmt.Println("❌ Error al parsear JSON:", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Datos inválidos"})
		return
	}

	fmt.Printf("📝 Datos recibidos: Nombre='%s', Descripcion='%s', Precio=%f\n", input.Nombre, input.Descripcion, input.Precio)

	if input.Nombre == "" || input.Precio <= 0 {
		fmt.Printf("❌ Validación fallida: Nombre='%s', Precio=%f\n", input.Nombre, input.Precio)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Nombre y precio válidos son obligatorios"})
		return
	}

	// 🔥 USANDO STORED PROCEDURE: CrearServicio
	fmt.Println("🚀 Ejecutando stored procedure: CrearServicio")
	// 📌 CONEXIÓN AL STORED PROCEDURE: Aquí se ejecuta el SP con parámetros
	_, err := dto.DB.Exec(
		"EXEC CrearServicio @p1, @p2, @p3", // ← Llamada directa al SP en SQL Server
		input.Nombre,                       // @p1 - Parámetro nombre
		input.Descripcion,                  // @p2 - Parámetro descripción
		input.Precio,                       // @p3 - Parámetro precio
	)

	if err != nil {
		fmt.Println("❌ Error al ejecutar stored procedure CrearServicio:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al crear servicio"})
		return
	}

	fmt.Println("✅ Stored procedure CrearServicio ejecutado exitosamente")
	c.JSON(http.StatusCreated, gin.H{"mensaje": "Servicio creado exitosamente"})
}

func ObtenerServicio(c *gin.Context) {
	id := c.Param("id")

	var servicio struct {
		ID          int     `json:"id"`
		Nombre      string  `json:"nombre"`
		Descripcion string  `json:"descripcion"`
		Precio      float64 `json:"precio"`
	}

	// 🔥 USANDO STORED PROCEDURE: ObtenerServicioPorId
	fmt.Printf("🚀 Ejecutando stored procedure: ObtenerServicioPorId con ID=%s\n", id)
	// 📌 CONEXIÓN AL STORED PROCEDURE: QueryRow ejecuta SP y retorna una fila
	err := dto.DB.QueryRow(
		"EXEC ObtenerServicioPorId @p1", // ← Llamada al SP de consulta individual
		id,                              // @p1 - Parámetro ID del servicio a buscar
	).Scan(&servicio.ID, &servicio.Nombre, &servicio.Descripcion, &servicio.Precio)

	if err != nil {
		if err == sql.ErrNoRows {
			fmt.Printf("❌ Stored procedure ObtenerServicioPorId: Servicio ID=%s no encontrado\n", id)
			c.JSON(http.StatusNotFound, gin.H{"error": "Servicio no encontrado"})
			return
		}
		fmt.Println("❌ Error al ejecutar stored procedure ObtenerServicioPorId:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener servicio"})
		return
	}

	fmt.Printf("✅ Stored procedure ObtenerServicioPorId ejecutado exitosamente para ID=%s\n", id)
	c.JSON(http.StatusOK, servicio)
}

func ActualizarServicio(c *gin.Context) {
	rol, _ := c.Get("rol")
	if rol != "admin" {
		c.JSON(http.StatusForbidden, gin.H{"error": "Solo administradores pueden actualizar servicios"})
		return
	}

	idStr := c.Param("id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
		return
	}

	// Verificar si hay citas asociadas a este servicio
	var count int
	err = dto.DB.QueryRow("SELECT COUNT(*) FROM citas WHERE servicio_id = @id", sql.Named("id", id)).Scan(&count)
	if err != nil {
		fmt.Println("❌ Error al verificar citas relacionadas:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al verificar dependencias"})
		return
	}
	if count > 0 {
		c.JSON(http.StatusConflict, gin.H{"error": "No se puede actualizar el servicio porque está vinculado a citas existentes"})
		return
	}

	var input ServicioInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Datos inválidos"})
		return
	}

	// 🔥 USANDO STORED PROCEDURE: ActualizarServicio
	fmt.Printf("🚀 Ejecutando stored procedure: ActualizarServicio para ID=%d\n", id)
	// 📌 CONEXIÓN AL STORED PROCEDURE: Ejecuta SP de actualización con múltiples parámetros
	_, err = dto.DB.Exec(
		"EXEC ActualizarServicio @p1, @p2, @p3, @p4", // ← Llamada al SP de actualización
		id,                // @p1 - ID del servicio a actualizar
		input.Nombre,      // @p2 - Nuevo nombre
		input.Descripcion, // @p3 - Nueva descripción
		input.Precio,      // @p4 - Nuevo precio
	)

	if err != nil {
		fmt.Println("❌ Error al ejecutar stored procedure ActualizarServicio:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al actualizar servicio"})
		return
	}

	fmt.Printf("✅ Stored procedure ActualizarServicio ejecutado exitosamente para ID=%d\n", id)
	c.JSON(http.StatusOK, gin.H{"mensaje": "Servicio actualizado correctamente"})
}

func EliminarServicio(c *gin.Context) {
	rol, _ := c.Get("rol")
	if rol != "admin" {
		c.JSON(http.StatusForbidden, gin.H{"error": "Solo administradores pueden eliminar servicios"})
		return
	}

	idStr := c.Param("id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID inválido"})
		return
	}

	fmt.Println("🗑️ Intentando eliminar servicio con ID:", id)

	// 🔥 USANDO STORED PROCEDURE: EliminarServicio
	fmt.Printf("🚀 Ejecutando stored procedure: EliminarServicio para ID=%d\n", id)
	// 📌 CONEXIÓN AL STORED PROCEDURE: Ejecuta SP de eliminación con ID específico
	_, err = dto.DB.Exec("EXEC EliminarServicio @p1", id) // ← Llamada al SP de eliminación
	if err != nil {
		fmt.Println("❌ Error al ejecutar stored procedure EliminarServicio:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "No se pudo eliminar el servicio. Verifica si está en uso."})
		return
	}

	fmt.Printf(" Stored procedure EliminarServicio ejecutado exitosamente para ID=%d\n", id)
	c.JSON(http.StatusOK, gin.H{"mensaje": "Servicio eliminado correctamente"})
}

func ListarServicios(c *gin.Context) {
	//  USANDO STORED PROCEDURE: ListarServicios
	fmt.Println("🚀 Ejecutando stored procedure: ListarServicios")
	// CONEXIÓN AL STORED PROCEDURE: Query ejecuta SP sin parámetros y retorna múltiples filas
	rows, err := dto.DB.Query("EXEC ListarServicios") // ← Llamada al SP de listado completo
	if err != nil {
		fmt.Println("❌ Error al ejecutar stored procedure ListarServicios:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener servicios"})
		return
	}
	defer rows.Close()

	var servicios []map[string]interface{}
	for rows.Next() {
		var (
			id            int
			nombre        string
			descripcion   string
			precio        float64
			creadoEn      sql.NullTime
			actualizadoEn sql.NullTime
		)

	
		if err := rows.Scan(&id, &nombre, &descripcion, &precio, &creadoEn, &actualizadoEn); err == nil {
			servicio := map[string]interface{}{
				"id":          id,
				"nombre":      nombre,
				"descripcion": descripcion,
				"precio":      precio,
			}
			servicios = append(servicios, servicio)
		} else {
			fmt.Println("❌ Error al hacer Scan de fila:", err)
		}
	}

	fmt.Printf("✅ Stored procedure ListarServicios ejecutado exitosamente - %d servicios encontrados\n", len(servicios))

	// 🔥 DEMOSTRACIÓN DE STORED PROCEDURE: Enviamos array directo para compatibilidad con frontend
	// pero los logs muestran que estamos usando stored procedures
	c.JSON(http.StatusOK, servicios)
}
