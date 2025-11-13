package main

import (
	"database/sql"
	"fmt"
	"log"

	_ "github.com/denisenkom/go-mssqldb"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	// Configurar conexión a SQL Server
	connString := "server=localhost;port=1433;database=salonbelleza;trusted_connection=yes"

	db, err := sql.Open("sqlserver", connString)
	if err != nil {
		log.Fatal("Error al conectar a SQL Server:", err)
	}
	defer db.Close()

	// Probar conexión
	err = db.Ping()
	if err != nil {
		log.Fatal("No se pudo conectar a la base de datos:", err)
	}
	fmt.Println("✅ Conexión a SQL Server exitosa")

	// Generar hash de la contraseña "admin"
	password := "admin"
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		log.Fatal("Error al generar hash:", err)
	}

	fmt.Printf("Hash generado para 'admin': %s\n", string(hashedPassword))

	// Verificar si el usuario ya existe
	var count int
	err = db.QueryRow("SELECT COUNT(*) FROM usuarios WHERE correo = @correo", sql.Named("correo", "admin@admin")).Scan(&count)
	if err != nil {
		log.Fatal("Error al verificar usuario existente:", err)
	}

	if count > 0 {
		fmt.Println("El usuario admin@admin ya existe. Actualizando contraseña...")
		_, err = db.Exec(`
			UPDATE usuarios 
			SET contrasena = @contrasena, rol = @rol 
			WHERE correo = @correo`,
			sql.Named("contrasena", string(hashedPassword)),
			sql.Named("rol", "admin"),
			sql.Named("correo", "admin@admin"))
		if err != nil {
			log.Fatal("Error al actualizar usuario:", err)
		}
		fmt.Println("✅ Usuario admin@admin actualizado correctamente")
	} else {
		fmt.Println("Creando nuevo usuario admin@admin...")
		_, err = db.Exec(`
			INSERT INTO usuarios (nombre, correo, cedula, contrasena, rol, creado_en) 
			VALUES (@nombre, @correo, @cedula, @contrasena, @rol, GETDATE())`,
			sql.Named("nombre", "Administrador"),
			sql.Named("correo", "admin@admin"),
			sql.Named("cedula", "12345678"),
			sql.Named("contrasena", string(hashedPassword)),
			sql.Named("rol", "admin"))
		if err != nil {
			log.Fatal("Error al crear usuario:", err)
		}
		fmt.Println("✅ Usuario admin@admin creado correctamente")
	}

	fmt.Println("\n🎉 Credenciales de acceso:")
	fmt.Println("📧 Email: admin@admin")
	fmt.Println("🔑 Contraseña: admin")
	fmt.Println("👑 Rol: admin")
}
