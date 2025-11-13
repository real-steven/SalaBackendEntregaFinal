// Steven: Manejador de usuarios (registro, login, gestión de perfiles, crear usuarios siendo admin).

package api

import (
	"database/sql"
	"fmt"
	"net/http"
	"restapi/dto"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v4"
	"golang.org/x/crypto/bcrypt"
)

var secretKey = []byte("clave_secreta_super_segura")

// Registro de usuarios (cliente por defecto)
func RegistrarUsuario(c *gin.Context) {
	var usuario struct {
		Nombre     string `json:"nombre"`
		Correo     string `json:"correo"`
		Cedula     string `json:"cedula"`
		Telefono   string `json:"telefono"`
		Contrasena string `json:"contrasena"`
	}

	if err := c.ShouldBindJSON(&usuario); err != nil {
		fmt.Println("Error al bindear JSON:", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Datos inválidos", "detalle": err.Error()})
		return
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(usuario.Contrasena), bcrypt.DefaultCost)
	if err != nil {
		fmt.Println("Error al hashear contraseña:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al procesar la contraseña", "detalle": err.Error()})
		return
	}

	_, err = dto.DB.Exec(
		"INSERT INTO usuarios(nombre, correo, cedula, telefono, contrasena, rol) VALUES(@nombre, @correo, @cedula, @telefono, @contrasena, @rol)",
		sql.Named("nombre", usuario.Nombre),
		sql.Named("correo", usuario.Correo),
		sql.Named("cedula", usuario.Cedula),
		sql.Named("telefono", usuario.Telefono),
		sql.Named("contrasena", string(hashedPassword)),
		sql.Named("rol", "cliente"),
	)

	if err != nil {
		fmt.Println("Error al ejecutar INSERT usuarios:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al registrar usuario", "detalle": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"mensaje": "Usuario registrado correctamente"})
}

// Login de usuario (todos los roles)
func LoginUsuario(c *gin.Context) {
	var input struct {
		Correo     string `json:"correo"`
		Contrasena string `json:"contrasena"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var usuario dto.Usuario
	err := dto.DB.QueryRow("SELECT id, nombre, contrasena, rol FROM usuarios WHERE correo=@correo", sql.Named("correo", input.Correo)).
		Scan(&usuario.ID, &usuario.Nombre, &usuario.Contrasena, &usuario.Rol)

	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Correo o contraseña incorrectos"})
		return
	}

	err = bcrypt.CompareHashAndPassword([]byte(usuario.Contrasena), []byte(input.Contrasena))
	if err != nil {
		fmt.Println("🔴 Error al comparar bcrypt:", err)
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Correo o contraseña incorrectos"})
		return
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"id":     usuario.ID,
		"nombre": usuario.Nombre,
		"rol":    usuario.Rol,
		"exp":    time.Now().Add(99999 * time.Minute).Unix(), //Para modificar el tiempo (para efectos de prueba se pondra mucho)
	})

	tokenString, err := token.SignedString(secretKey)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al generar token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"token": tokenString,
		"usuario": gin.H{
			"id":     usuario.ID,
			"nombre": usuario.Nombre,
			"rol":    usuario.Rol,
		},
	})

}

// Registro manual de usuarios (clientes o empleados) por parte de un administrador
func RegistrarUsuarioComoAdmin(c *gin.Context) {
	rol, existe := c.Get("rol")
	if !existe || rol != "admin" {
		c.JSON(http.StatusForbidden, gin.H{"error": "Solo administradores pueden registrar usuarios manualmente"})
		return
	}

	var input struct {
		Nombre     string `json:"nombre"`
		Correo     string `json:"correo"`
		Cedula     string `json:"cedula"`
		Telefono   string `json:"telefono"`
		Contrasena string `json:"contrasena"`
		Rol        string `json:"rol"` // cliente, empleado, admin
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Datos inválidos"})
		return
	}

	if input.Rol != "cliente" && input.Rol != "empleado" && input.Rol != "admin" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Rol inválido"})
		return
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(input.Contrasena), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al encriptar la contraseña"})
		return
	}

	_, err = dto.DB.Exec(`
		INSERT INTO usuarios (nombre, correo, cedula, telefono, contrasena, rol)
		VALUES (@nombre, @correo, @cedula, @telefono, @contrasena, @rol)`,
		sql.Named("nombre", input.Nombre),
		sql.Named("correo", input.Correo),
		sql.Named("cedula", input.Cedula),
		sql.Named("telefono", input.Telefono),
		sql.Named("contrasena", string(hashedPassword)),
		sql.Named("rol", input.Rol))

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "No se pudo crear el usuario"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"mensaje": "Usuario creado correctamente"})
}

// Ver el perfil del usuario autenticado
func VerMiPerfil(c *gin.Context) {
	usuarioID, _ := c.Get("usuarioID")

	var usuario struct {
		ID       int32  `json:"id"`
		Nombre   string `json:"nombre"`
		Correo   string `json:"correo"`
		Cedula   string `json:"cedula"`
		Telefono string `json:"telefono"`
		Rol      string `json:"rol"`
	}

	err := dto.DB.QueryRow("SELECT id, nombre, correo, cedula, telefono, rol FROM usuarios WHERE id = @id", sql.Named("id", usuarioID)).
		Scan(&usuario.ID, &usuario.Nombre, &usuario.Correo, &usuario.Cedula, &usuario.Telefono, &usuario.Rol)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "No se pudo obtener el perfil"})
		return
	}

	c.JSON(http.StatusOK, usuario)
}

// ListarUsuarios - Obtener lista de usuarios/clientes usando stored procedure
func ListarUsuarios(c *gin.Context) {
	fmt.Println("=== INICIO ListarUsuarios ===")

	// Verificar permisos (solo admin y empleados pueden ver lista completa)
	rol, _ := c.Get("rol")
	if rol != "admin" && rol != "empleado" {
		fmt.Printf("Acceso denegado - Rol: %v", rol)
		c.JSON(http.StatusForbidden, gin.H{"error": "Solo administradores o empleados pueden listar usuarios"})
		return
	}

	// Ejecutar stored procedure ListarUsuarios
	query := "EXEC ListarUsuarios"
	fmt.Printf("Ejecutando query: %s", query)

	rows, err := dto.DB.Query(query)
	if err != nil {
		fmt.Printf("Error ejecutando stored procedure ListarUsuarios: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al obtener usuarios", "detalle": err.Error()})
		return
	}
	defer rows.Close()

	var usuarios []gin.H

	for rows.Next() {
		var id int
		var nombre, correo, cedula, contrasena, rol string
		var creadoEn, actualizadoEn sql.NullTime

		// El SP devuelve: id, nombre, correo, cedula, contrasena, rol, creado_en, actualizado_en
		err := rows.Scan(&id, &nombre, &correo, &cedula, &contrasena, &rol, &creadoEn, &actualizadoEn)
		if err != nil {
			fmt.Printf("Error al escanear fila: %v", err)
			continue
		}

		// Solo incluir información segura (sin contraseña)
		usuario := gin.H{
			"id":        id,
			"nombre":    nombre,
			"correo":    correo,
			"cedula":    cedula,
			"rol":       rol,
			"creado_en": creadoEn.Time,
		}

		usuarios = append(usuarios, usuario)
	}

	fmt.Printf("Usuarios listados exitosamente - Total: %d", len(usuarios))

	c.JSON(http.StatusOK, usuarios)
}
