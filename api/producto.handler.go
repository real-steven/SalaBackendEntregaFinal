package api

import (
	"database/sql"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"restapi/dto"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// GET /productos
func ListarProductos(c *gin.Context) {
	busqueda := strings.ToLower(c.Query("buscar"))

	query := "SELECT id, nombre, descripcion, precio, imagen, cantidad_disponible FROM productos"
	var args []interface{}

	if busqueda != "" {
		query += " WHERE LOWER(nombre) LIKE @p1"
		args = append(args, "%"+busqueda+"%")
	}

	rows, err := dto.DB.Query(query, args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener productos"})
		return
	}
	defer rows.Close()

	var productos []dto.Producto
	for rows.Next() {
		var p dto.Producto
		var imagen sql.NullString
		err := rows.Scan(&p.ID, &p.Nombre, &p.Descripcion, &p.Precio, &imagen, &p.CantidadDisponible)
		if err == nil {
			if imagen.Valid {
				p.Imagen = imagen.String
			} else {
				p.Imagen = ""
			}
			productos = append(productos, p)
		}
	}
	c.JSON(http.StatusOK, productos)
}

// GET /productos/:id
func ObtenerProducto(c *gin.Context) {
	id := c.Param("id")

	var p dto.Producto
	var imagen sql.NullString
	err := dto.DB.QueryRow("SELECT id, nombre, descripcion, precio, imagen, cantidad_disponible FROM productos WHERE id = @p1", id).
		Scan(&p.ID, &p.Nombre, &p.Descripcion, &p.Precio, &imagen, &p.CantidadDisponible)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Producto no encontrado"})
		return
	}

	if imagen.Valid {
		p.Imagen = imagen.String
	} else {
		p.Imagen = ""
	}

	c.JSON(http.StatusOK, p)
}

// POST /productos
func CrearProducto(c *gin.Context) {
	rol, existe := c.Get("rol")
	fmt.Printf("🔐 Rol obtenido del token: %v (existe: %v)\n", rol, existe)
	if !existe || rol != "admin" {
		fmt.Println("❌ Error de autorización: Rol no es admin")
		c.JSON(http.StatusForbidden, gin.H{"error": "Solo administradores pueden crear productos"})
		return
	}

	nombre := c.PostForm("nombre")
	descripcion := c.PostForm("descripcion")
	precioStr := c.PostForm("precio")
	cantidadStr := c.PostForm("cantidad")

	fmt.Printf("📝 Datos recibidos: Nombre='%s', Precio='%s', Cantidad='%s'\n", nombre, precioStr, cantidadStr)

	precio, err := strconv.ParseFloat(precioStr, 64)
	if err != nil {
		fmt.Printf("❌ Error parseando precio: %v\n", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Precio inválido"})
		return
	}

	cantidad, err := strconv.Atoi(cantidadStr)
	if err != nil {
		fmt.Printf("❌ Error parseando cantidad: %v\n", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cantidad inválida"})
		return
	}

	file, err := c.FormFile("imagen")
	var rutaImagen string
	if err == nil {
		filename := strconv.FormatInt(time.Now().UnixNano(), 10) + filepath.Ext(file.Filename)
		rutaImagen = "recursos/" + filename
		err = c.SaveUploadedFile(file, rutaImagen)
		if err != nil {
			fmt.Printf("❌ Error guardando imagen: %v\n", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "No se pudo guardar la imagen"})
			return
		}
		fmt.Printf("✅ Imagen guardada en: %s\n", rutaImagen)
	} else {
		fmt.Printf("⚠️ No se recibió imagen: %v\n", err)
	}

	query := "INSERT INTO productos (nombre, descripcion, precio, imagen, cantidad_disponible) VALUES (@p1, @p2, @p3, @p4, @p5)"
	fmt.Printf("🚀 Ejecutando query de inserción\n")
	result, err := dto.DB.Exec(query, nombre, descripcion, precio, rutaImagen, cantidad)
	if err != nil {
		fmt.Printf("❌ Error al insertar producto en DB: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "No se pudo crear el producto"})
		return
	}

	id, _ := result.LastInsertId()
	fmt.Printf("✅ Producto creado exitosamente con ID: %d\n", id)
	c.JSON(http.StatusCreated, gin.H{"id": id, "nombre": nombre, "descripcion": descripcion, "precio": precio, "imagen": rutaImagen, "cantidad_disponible": cantidad})
}

// PUT /productos/:id
func ActualizarProducto(c *gin.Context) {
	rol, existe := c.Get("rol")
	fmt.Printf("🔐 [ACTUALIZAR] Rol obtenido del token: %v (existe: %v)\n", rol, existe)
	if !existe || rol != "admin" {
		fmt.Println("❌ Error de autorización: Rol no es admin")
		c.JSON(http.StatusForbidden, gin.H{"error": "Solo administradores pueden actualizar productos"})
		return
	}

	id := c.Param("id")
	nombre := c.PostForm("nombre")
	descripcion := c.PostForm("descripcion")
	precioStr := c.PostForm("precio")
	cantidadStr := c.PostForm("cantidad")

	fmt.Printf("📝 [ACTUALIZAR] ID=%s, Nombre='%s', Precio='%s', Cantidad='%s'\n", id, nombre, precioStr, cantidadStr)

	precio, err := strconv.ParseFloat(precioStr, 64)
	if err != nil {
		fmt.Printf("❌ Error parseando precio: %v\n", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Precio inválido"})
		return
	}

	cantidad, err := strconv.Atoi(cantidadStr)
	if err != nil {
		fmt.Printf("❌ Error parseando cantidad: %v\n", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cantidad inválida"})
		return
	}

	file, err := c.FormFile("imagen")
	rutaImagen := ""
	if err == nil {
		filename := strconv.FormatInt(time.Now().UnixNano(), 10) + filepath.Ext(file.Filename)
		rutaImagen = "recursos/" + filename
		err = c.SaveUploadedFile(file, rutaImagen)
		if err != nil {
			fmt.Printf("❌ Error guardando imagen: %v\n", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "No se pudo guardar la imagen"})
			return
		}
		fmt.Printf("✅ Imagen actualizada: %s\n", rutaImagen)
	} else {
		fmt.Printf("⚠️ No se actualiza imagen\n")
	}

	var query string
	var args []interface{}
	if rutaImagen != "" {
		query = `UPDATE productos SET nombre = @p1, descripcion = @p2, precio = @p3, imagen = @p4, cantidad_disponible = @p5 WHERE id = @p6`
		args = []interface{}{nombre, descripcion, precio, rutaImagen, cantidad, id}
	} else {
		query = `UPDATE productos SET nombre = @p1, descripcion = @p2, precio = @p3, cantidad_disponible = @p4 WHERE id = @p5`
		args = []interface{}{nombre, descripcion, precio, cantidad, id}
	}

	fmt.Printf("🚀 Ejecutando query de actualización\n")
	_, err = dto.DB.Exec(query, args...)
	if err != nil {
		fmt.Printf("❌ Error al actualizar producto en DB: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al actualizar producto"})
		return
	}

	fmt.Printf("✅ Producto actualizado exitosamente\n")
	c.JSON(http.StatusOK, gin.H{"mensaje": "Producto actualizado correctamente"})
}

// DELETE /productos/:id
func EliminarProducto(c *gin.Context) {
	rol, existe := c.Get("rol")
	fmt.Printf("🔐 [ELIMINAR] Rol obtenido del token: %v (existe: %v)\n", rol, existe)
	if !existe || rol != "admin" {
		fmt.Println("❌ Error de autorización: Rol no es admin")
		c.JSON(http.StatusForbidden, gin.H{"error": "Solo administradores pueden eliminar productos"})
		return
	}

	id := c.Param("id")
	fmt.Printf("🗑️ Intentando eliminar producto con ID: %s\n", id)

	var imagen sql.NullString
	err := dto.DB.QueryRow("SELECT imagen FROM productos WHERE id = @p1", id).Scan(&imagen)
	if err == nil && imagen.Valid {
		fmt.Printf("🗑️ Eliminando archivo de imagen: %s\n", imagen.String)
		_ = os.Remove(imagen.String) // eliminar archivo si existe
	}

	_, err = dto.DB.Exec("DELETE FROM productos WHERE id = @p1", id)
	if err != nil {
		fmt.Printf("❌ Error al eliminar producto de DB: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al eliminar el producto"})
		return
	}

	fmt.Printf("✅ Producto eliminado exitosamente\n")
	c.JSON(http.StatusOK, gin.H{"mensaje": "Producto eliminado exitosamente"})
}
