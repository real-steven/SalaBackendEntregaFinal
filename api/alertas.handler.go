package api

import (
	"fmt"
	"net/http"
	"restapi/dto"

	"github.com/gin-gonic/gin"
)

// GET /alertas/inventario - Obtener alertas de inventario bajo
func ObtenerAlertasInventario(c *gin.Context) {
	rol, existe := c.Get("rol")
	if !existe || (rol != "admin" && rol != "empleado") {
		c.JSON(http.StatusForbidden, gin.H{"error": "Solo administradores y empleados pueden ver alertas"})
		return
	}

	query := `
		SELECT 
			id, producto_id, producto_nombre, cantidad_actual, 
			fecha_alerta, estado
		FROM alertas_inventario 
		WHERE estado = 'PENDIENTE'
		ORDER BY fecha_alerta DESC
	`

	rows, err := dto.DB.Query(query)
	if err != nil {
		fmt.Printf("❌ Error al obtener alertas de inventario: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener alertas"})
		return
	}
	defer rows.Close()

	var alertas []map[string]interface{}
	for rows.Next() {
		var alerta map[string]interface{} = make(map[string]interface{})
		var id, productoID, cantidadActual int
		var productoNombre, estado string
		var fechaAlerta string

		err := rows.Scan(&id, &productoID, &productoNombre, &cantidadActual, &fechaAlerta, &estado)
		if err == nil {
			alerta["id"] = id
			alerta["producto_id"] = productoID
			alerta["producto_nombre"] = productoNombre
			alerta["cantidad_actual"] = cantidadActual
			alerta["fecha_alerta"] = fechaAlerta
			alerta["estado"] = estado
			alertas = append(alertas, alerta)
		}
	}

	fmt.Printf("✅ Se encontraron %d alertas de inventario\n", len(alertas))
	c.JSON(http.StatusOK, alertas)
}

// PUT /alertas/inventario/:id/resolver - Marcar alerta como resuelta
func ResolverAlertaInventario(c *gin.Context) {
	rol, existe := c.Get("rol")
	if !existe || (rol != "admin" && rol != "empleado") {
		c.JSON(http.StatusForbidden, gin.H{"error": "Solo administradores y empleados pueden resolver alertas"})
		return
	}

	id := c.Param("id")

	query := `UPDATE alertas_inventario SET estado = 'RESUELTO', fecha_alerta = GETDATE() WHERE id = @p1`
	_, err := dto.DB.Exec(query, id)
	if err != nil {
		fmt.Printf("❌ Error al resolver alerta: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al resolver alerta"})
		return
	}

	fmt.Printf("✅ Alerta %s marcada como resuelta\n", id)
	c.JSON(http.StatusOK, gin.H{"mensaje": "Alerta resuelta correctamente"})
}

// GET /auditoria/usuarios - Obtener historial de cambios de usuarios
func ObtenerAuditoriaUsuarios(c *gin.Context) {
	rol, existe := c.Get("rol")
	if !existe || rol != "admin" {
		c.JSON(http.StatusForbidden, gin.H{"error": "Solo administradores pueden ver la auditoría"})
		return
	}

	query := `
		SELECT 
			id, usuario_id, accion, campo_modificado, 
			valor_anterior, valor_nuevo, fecha_modificacion, usuario_modificador
		FROM auditoria_usuarios 
		ORDER BY fecha_modificacion DESC
	`

	rows, err := dto.DB.Query(query)
	if err != nil {
		fmt.Printf("❌ Error al obtener auditoría: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener auditoría"})
		return
	}
	defer rows.Close()

	var auditoria []map[string]interface{}
	for rows.Next() {
		var registro map[string]interface{} = make(map[string]interface{})
		var id, usuarioID int
		var accion, campoModificado, valorAnterior, valorNuevo, fechaModificacion, usuarioModificador string

		err := rows.Scan(&id, &usuarioID, &accion, &campoModificado, &valorAnterior, &valorNuevo, &fechaModificacion, &usuarioModificador)
		if err == nil {
			registro["id"] = id
			registro["usuario_id"] = usuarioID
			registro["accion"] = accion
			registro["campo_modificado"] = campoModificado
			registro["valor_anterior"] = valorAnterior
			registro["valor_nuevo"] = valorNuevo
			registro["fecha_modificacion"] = fechaModificacion
			registro["usuario_modificador"] = usuarioModificador
			auditoria = append(auditoria, registro)
		}
	}

	fmt.Printf("✅ Se encontraron %d registros de auditoría\n", len(auditoria))
	c.JSON(http.StatusOK, auditoria)
}

// GET /estadisticas/clientes - Obtener estadísticas de clientes
func ObtenerEstadisticasClientes(c *gin.Context) {
	rol, existe := c.Get("rol")
	if !existe || (rol != "admin" && rol != "empleado") {
		c.JSON(http.StatusForbidden, gin.H{"error": "Solo administradores y empleados pueden ver estadísticas"})
		return
	}

	query := `
		SELECT 
			ec.cliente_id,
			u.nombre,
			u.email,
			ec.total_citas,
			ec.citas_completadas,
			ec.citas_canceladas,
			ec.gasto_total,
			ec.ultima_cita,
			ec.fecha_registro
		FROM estadisticas_clientes ec
		INNER JOIN usuarios u ON ec.cliente_id = u.id
		ORDER BY ec.gasto_total DESC
	`

	rows, err := dto.DB.Query(query)
	if err != nil {
		fmt.Printf("❌ Error al obtener estadísticas: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener estadísticas"})
		return
	}
	defer rows.Close()

	var estadisticas []map[string]interface{}
	for rows.Next() {
		var stats map[string]interface{} = make(map[string]interface{})
		var clienteID, totalCitas, citasCompletadas, citasCanceladas int
		var nombre, email string
		var gastoTotal float64
		var ultimaCita, fechaRegistro string

		err := rows.Scan(&clienteID, &nombre, &email, &totalCitas, &citasCompletadas, &citasCanceladas, &gastoTotal, &ultimaCita, &fechaRegistro)
		if err == nil {
			stats["cliente_id"] = clienteID
			stats["nombre"] = nombre
			stats["email"] = email
			stats["total_citas"] = totalCitas
			stats["citas_completadas"] = citasCompletadas
			stats["citas_canceladas"] = citasCanceladas
			stats["gasto_total"] = gastoTotal
			stats["ultima_cita"] = ultimaCita
			stats["fecha_registro"] = fechaRegistro
			estadisticas = append(estadisticas, stats)
		}
	}

	fmt.Printf("✅ Se encontraron estadísticas de %d clientes\n", len(estadisticas))
	c.JSON(http.StatusOK, estadisticas)
}

// GET /historial/precios-servicios - Obtener historial de cambios de precios
func ObtenerHistorialPreciosServicios(c *gin.Context) {
	rol, existe := c.Get("rol")
	if !existe || (rol != "admin" && rol != "empleado") {
		c.JSON(http.StatusForbidden, gin.H{"error": "Solo administradores y empleados pueden ver el historial"})
		return
	}

	query := `
		SELECT 
			id, servicio_id, servicio_nombre, precio_anterior, 
			precio_nuevo, porcentaje_cambio, fecha_cambio, motivo
		FROM historial_precios_servicios 
		ORDER BY fecha_cambio DESC
	`

	rows, err := dto.DB.Query(query)
	if err != nil {
		fmt.Printf("❌ Error al obtener historial de precios: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener historial"})
		return
	}
	defer rows.Close()

	var historial []map[string]interface{}
	for rows.Next() {
		var registro map[string]interface{} = make(map[string]interface{})
		var id, servicioID int
		var servicioNombre, fechaCambio, motivo string
		var precioAnterior, precioNuevo, porcentajeCambio float64

		err := rows.Scan(&id, &servicioID, &servicioNombre, &precioAnterior, &precioNuevo, &porcentajeCambio, &fechaCambio, &motivo)
		if err == nil {
			registro["id"] = id
			registro["servicio_id"] = servicioID
			registro["servicio_nombre"] = servicioNombre
			registro["precio_anterior"] = precioAnterior
			registro["precio_nuevo"] = precioNuevo
			registro["porcentaje_cambio"] = porcentajeCambio
			registro["fecha_cambio"] = fechaCambio
			registro["motivo"] = motivo
			historial = append(historial, registro)
		}
	}

	fmt.Printf("✅ Se encontraron %d cambios de precios\n", len(historial))
	c.JSON(http.StatusOK, historial)
}
