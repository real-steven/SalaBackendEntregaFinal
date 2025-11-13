// Steven: Manejador de facturas (generar desde citas, obtener, previsualizar, PDF).

package api

import (
	"database/sql"
	"fmt"
	"net/http"
	"restapi/dto"
	"strconv"

	"github.com/gin-gonic/gin"
)

// Estructura para factura completa
type Factura struct {
	ID              int              `json:"id"`
	CitaID          int              `json:"cita_id"`
	UsuarioID       *int             `json:"usuario_id"`
	NombreCliente   string           `json:"nombre_cliente"`
	CedulaCliente   string           `json:"cedula_cliente"`
	TelefonoCliente *string          `json:"telefono_cliente"`
	CorreoCliente   *string          `json:"correo_cliente"`
	FechaFactura    string           `json:"fecha_factura"`
	Subtotal        float64          `json:"subtotal"`
	Impuestos       float64          `json:"impuestos"`
	Total           float64          `json:"total"`
	Estado          string           `json:"estado"`
	Observaciones   *string          `json:"observaciones"`
	FechaCita       *string          `json:"fecha_cita"`
	Detalles        []DetalleFactura `json:"detalles"`
}

type DetalleFactura struct {
	ID                   int     `json:"id"`
	ProductoID           *int    `json:"producto_id"`
	ServicioID           *int    `json:"servicio_id"`
	Cantidad             int     `json:"cantidad"`
	PrecioUnitario       float64 `json:"precio_unitario"`
	Subtotal             float64 `json:"subtotal"`
	DetallePersonalizado *string `json:"detalle_personalizado"`
	Descripcion          *string `json:"descripcion"`
	NombreItem           *string `json:"nombre_item"`
	TipoItem             string  `json:"tipo_item"`
}

// Generar factura desde cita finalizada
func GenerarFacturaDesdeCita(c *gin.Context) {
	rol, _ := c.Get("rol")
	if rol != "admin" && rol != "empleado" {
		c.JSON(http.StatusForbidden, gin.H{"error": "Solo administradores y empleados pueden generar facturas"})
		return
	}

	citaIDStr := c.Param("id")
	citaID, err := strconv.Atoi(citaIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de cita inválido"})
		return
	}

	// Ejecutar stored procedure para generar factura
	var facturaID int
	err = dto.DB.QueryRow("EXEC GenerarFacturaDesdeCita @cita_id", sql.Named("cita_id", citaID)).Scan(&facturaID)
	if err != nil {
		fmt.Printf("Error al generar factura: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al generar factura", "detalle": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"mensaje": "Factura generada correctamente", "factura_id": facturaID})
}

// Obtener factura completa por ID
func ObtenerFactura(c *gin.Context) {
	facturaIDStr := c.Param("id")
	facturaID, err := strconv.Atoi(facturaIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de factura inválido"})
		return
	}

	// Obtener datos principales de la factura
	var factura Factura
	err = dto.DB.QueryRow(`
		SELECT 
			f.idFact, f.idCita, COALESCE(c.usuario_id, 0), 
			COALESCE(u.nombre, c.nombre_invitado) as nombre_cliente, 
			COALESCE(u.cedula, c.cedula_invitado) as cedula_cliente,
			COALESCE(u.telefono, c.telefono_invitado) as telefono_cliente, 
			COALESCE(u.correo, 'No disponible') as correo_cliente, 
			f.fecha, f.subtotal, f.impuesto, f.total, 'activa' as estado, 
			f.observaciones, c.fecha_hora
		FROM factura f
		INNER JOIN citas c ON f.idCita = c.id
		LEFT JOIN usuarios u ON c.usuario_id = u.id
		WHERE f.idFact = @factura_id
	`, sql.Named("factura_id", facturaID)).Scan(
		&factura.ID, &factura.CitaID, &factura.UsuarioID, &factura.NombreCliente, &factura.CedulaCliente,
		&factura.TelefonoCliente, &factura.CorreoCliente, &factura.FechaFactura, &factura.Subtotal,
		&factura.Impuestos, &factura.Total, &factura.Estado, &factura.Observaciones, &factura.FechaCita,
	)

	if err != nil {
		fmt.Printf("Error al obtener factura: %v\n", err)
		c.JSON(http.StatusNotFound, gin.H{"error": "Factura no encontrada"})
		return
	}

	// Obtener detalles de la factura
	rows, err := dto.DB.Query(`
		SELECT 
			df.idDetalle, df.idProducto, df.idServicio, df.cant, df.precio,
			df.subtotal, df.detallePersonalizado, df.descripcion,
			COALESCE(p.nombre, s.nombre, df.descripcion) as nombre_item,
			CASE 
				WHEN df.idProducto IS NOT NULL THEN 'producto'
				WHEN df.idServicio IS NOT NULL THEN 'servicio'
				ELSE 'personalizado'
			END as tipo_item
		FROM detallefactura df
		LEFT JOIN productos p ON df.idProducto = p.id
		LEFT JOIN servicios s ON df.idServicio = s.id
		WHERE df.idFact = @factura_id
	`, sql.Named("factura_id", facturaID))

	if err != nil {
		fmt.Printf("Error al obtener detalles de factura: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener detalles de factura"})
		return
	}
	defer rows.Close()

	var detalles []DetalleFactura
	for rows.Next() {
		var detalle DetalleFactura
		err := rows.Scan(
			&detalle.ID, &detalle.ProductoID, &detalle.ServicioID, &detalle.Cantidad,
			&detalle.PrecioUnitario, &detalle.Subtotal, &detalle.DetallePersonalizado,
			&detalle.Descripcion, &detalle.NombreItem, &detalle.TipoItem,
		)
		if err != nil {
			fmt.Printf("Error al escanear detalle: %v\n", err)
			continue
		}
		detalles = append(detalles, detalle)
	}

	factura.Detalles = detalles
	c.JSON(http.StatusOK, factura)
}

// Obtener factura por cita ID
func ObtenerFacturaPorCita(c *gin.Context) {
	citaIDStr := c.Param("id")
	citaID, err := strconv.Atoi(citaIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de cita inválido"})
		return
	}

	var facturaID int
	err = dto.DB.QueryRow("SELECT id FROM facturas WHERE cita_id = @cita_id", sql.Named("cita_id", citaID)).Scan(&facturaID)
	if err != nil {
		fmt.Printf("Error al buscar factura para cita %d: %v\n", citaID, err)
		c.JSON(http.StatusNotFound, gin.H{"error": "No existe factura para esta cita"})
		return
	}

	// Obtener información completa de la factura
	var factura Factura
	err = dto.DB.QueryRow(`
		SELECT 
			f.id, f.cita_id, f.nombre_cliente, f.cedula_cliente, f.telefono_cliente,
			f.fecha_factura, f.total
		FROM facturas f
		WHERE f.id = @factura_id
	`, sql.Named("factura_id", facturaID)).Scan(
		&factura.ID, &factura.CitaID, &factura.NombreCliente,
		&factura.CedulaCliente, &factura.TelefonoCliente,
		&factura.FechaFactura, &factura.Total,
	)

	if err != nil {
		fmt.Printf("Error al obtener factura %d: %v\n", facturaID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener factura"})
		return
	}

	// Establecer valores por defecto
	factura.Estado = "activa"

	// Obtener detalles de la factura
	rows, err := dto.DB.Query(`
		SELECT 
			df.cant, df.precUnit, df.subtotal,
			COALESCE(p.nombre, s.nombre, df.descripcion) as nombre_item,
			CASE 
				WHEN df.idProducto IS NOT NULL THEN 'producto'
				WHEN df.idServicio IS NOT NULL THEN 'servicio'
				ELSE 'personalizado'
			END as tipo_item
		FROM detallefactura df
		LEFT JOIN productos p ON df.idProducto = p.id
		LEFT JOIN servicios s ON df.idServicio = s.id
		WHERE df.idFact = @factura_id
	`, sql.Named("factura_id", facturaID))

	if err != nil {
		fmt.Printf("Error al obtener detalles de factura: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener detalles de factura"})
		return
	}
	defer rows.Close()

	var detalles []DetalleFactura
	for rows.Next() {
		var detalle DetalleFactura
		err := rows.Scan(&detalle.Cantidad, &detalle.PrecioUnitario, &detalle.Subtotal, &detalle.NombreItem, &detalle.TipoItem)
		if err != nil {
			fmt.Printf("Error al leer detalle de factura: %v\n", err)
			continue
		}
		detalles = append(detalles, detalle)
	}

	factura.Detalles = detalles
	c.JSON(http.StatusOK, factura)
}

// Listar facturas (solo admin)
func ListarFacturas(c *gin.Context) {
	rol, _ := c.Get("rol")
	if rol != "admin" {
		c.JSON(http.StatusForbidden, gin.H{"error": "Solo administradores pueden listar facturas"})
		return
	}

	rows, err := dto.DB.Query(`
		SELECT 
			f.idFact, f.idCita, COALESCE(u.nombre, c.nombre_invitado) as nombre_cliente, 
			COALESCE(u.cedula, c.cedula_invitado) as cedula_cliente,
			f.fecha, f.total, 'activa' as estado
		FROM factura f
		INNER JOIN citas c ON f.idCita = c.id
		LEFT JOIN usuarios u ON c.usuario_id = u.id
		ORDER BY f.fecha DESC
	`)

	if err != nil {
		fmt.Printf("Error al listar facturas: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener facturas"})
		return
	}
	defer rows.Close()

	var facturas []gin.H
	for rows.Next() {
		var id, citaID int
		var nombreCliente, cedulaCliente, fechaFactura, estado string
		var total float64

		err := rows.Scan(&id, &citaID, &nombreCliente, &cedulaCliente, &fechaFactura, &total, &estado)
		if err != nil {
			fmt.Printf("Error al escanear factura: %v\n", err)
			continue
		}

		facturas = append(facturas, gin.H{
			"id":             id,
			"cita_id":        citaID,
			"nombre_cliente": nombreCliente,
			"cedula_cliente": cedulaCliente,
			"fecha_factura":  fechaFactura,
			"total":          total,
			"estado":         estado,
		})
	}

	c.JSON(http.StatusOK, gin.H{"facturas": facturas})
}

// Descargar factura como PDF
func DescargarFacturaPDF(c *gin.Context) {
	facturaIDStr := c.Param("id")
	facturaID, err := strconv.Atoi(facturaIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "ID de factura inválido"})
		return
	}

	// Por ahora, generar un PDF simple o devolver la factura como JSON
	// En una implementación real, aquí usarías una librería como gofpdf

	// Obtener la factura completa
	var factura Factura
	err = dto.DB.QueryRow(`
		SELECT 
			f.id, f.cita_id, f.nombre_cliente, f.cedula_cliente, f.telefono_cliente,
			f.fecha_factura, f.total
		FROM facturas f
		WHERE f.id = @factura_id
	`, sql.Named("factura_id", facturaID)).Scan(
		&factura.ID, &factura.CitaID, &factura.NombreCliente,
		&factura.CedulaCliente, &factura.TelefonoCliente,
		&factura.FechaFactura, &factura.Total,
	)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Factura no encontrada"})
		return
	}

	// Obtener detalles
	rows, err := dto.DB.Query(`
		SELECT 
			df.cant, df.precUnit, df.subtotal,
			COALESCE(p.nombre, s.nombre, df.descripcion) as nombre_item
		FROM detallefactura df
		LEFT JOIN productos p ON df.idProducto = p.id
		LEFT JOIN servicios s ON df.idServicio = s.id
		WHERE df.idFact = @factura_id
	`, sql.Named("factura_id", facturaID))

	if err == nil {
		defer rows.Close()
		var detalles []DetalleFactura
		for rows.Next() {
			var detalle DetalleFactura
			err := rows.Scan(&detalle.Cantidad, &detalle.PrecioUnitario, &detalle.Subtotal, &detalle.NombreItem)
			if err == nil {
				detalles = append(detalles, detalle)
			}
		}
		factura.Detalles = detalles
	}

	// Por ahora generar un PDF simple como texto plano
	// En producción aquí usarías una librería como gofpdf

	pdfContent := fmt.Sprintf(`%%PDF-1.4
1 0 obj
<<
/Type /Catalog
/Pages 2 0 R
>>
endobj
2 0 obj
<<
/Type /Pages
/Kids [3 0 R]
/Count 1
>>
endobj
3 0 obj
<<
/Type /Page
/Parent 2 0 R
/MediaBox [0 0 612 792]
/Contents 4 0 R
>>
endobj
4 0 obj
<<
/Length 200
>>
stream
BT
/F1 12 Tf
72 720 Td
(FACTURA #%d) Tj
0 -20 Td
(Cliente: %s) Tj
0 -20 Td
(Cedula: %s) Tj
0 -20 Td
(Fecha: %s) Tj
0 -20 Td
(Total: $%.2f) Tj
ET
endstream
endobj
xref
0 5
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000204 00000 n 
trailer
<<
/Size 5
/Root 1 0 R
>>
startxref
452
%%%%EOF`,
		factura.ID,
		factura.NombreCliente,
		factura.CedulaCliente,
		factura.FechaFactura,
		factura.Total)

	c.Header("Content-Type", "application/pdf")
	c.Header("Content-Disposition", "attachment; filename=factura_"+facturaIDStr+".pdf")
	c.String(http.StatusOK, pdfContent)
}
