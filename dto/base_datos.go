// Configuración de conexión a la base de datos.

package dto

import (
	"database/sql"
	"fmt"
	"log"
	"os"

	_ "github.com/denisenkom/go-mssqldb"
)

var DB *sql.DB

// Conecta a Azure SQL Database usando SQL Server Authentication
func ConectarBaseDatos() {
	var err error
	
	// Obtener la contraseña de variables de entorno
	password := os.Getenv("AZURE_DB_PASSWORD")
	if password == "" {
		log.Fatal("Variable de entorno AZURE_DB_PASSWORD no está configurada")
	}
	
	// String de conexión para Azure SQL Database
	connString := fmt.Sprintf("server=salabelleza.database.windows.net;port=1433;database=salonbelleza;user id=AdminSteven;password=%s;encrypt=true;TrustServerCertificate=false", password)
	DB, err = sql.Open("sqlserver", connString)
	if err != nil {
		log.Printf("Error al conectar a SQL Server: %v", err)
		return
	}
	err = DB.Ping()
	if err != nil {
		log.Printf("No se pudo hacer ping a SQL Server: %v", err)
		return
	}
	fmt.Println("Conexión a SQL Server exitosa.")
}
