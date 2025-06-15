package api

import (
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func InicializarServidor() *gin.Engine {
	router := gin.Default()
	router.MaxMultipartMemory = 50 << 20 // 50 MB para imágenes grandes

	// Middleware CORS para Angular
	router.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"http://localhost:4200"},
		AllowMethods:     []string{"POST", "GET", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
	}))

	// Servir archivos estáticos (imágenes)
	router.Static("/recursos", "./recursos")

	// =====================
	// RUTAS PÚBLICAS
	// =====================
	router.POST("/usuarios", RegistrarUsuario)
	router.POST("/login", LoginUsuario)
	router.POST("/citas/invitado", CrearCitaInvitado)
	router.GET("/citas/invitado/:cedula", ObtenerUltimaCitaInvitado)
	router.GET("/citas/invitado/:cedula/todas", ObtenerCitasPorCedulaInvitado)
	router.GET("/servicios", ListarServicios)
	router.GET("/servicios/:id", ObtenerServicio)
	router.GET("/productos", ListarProductos)
	router.GET("/productos/:id", ObtenerProducto)
	router.POST("/productos", CrearProducto)
	router.PUT("/productos/:id", ActualizarProducto)
	router.DELETE("/productos/:id", EliminarProducto)

	// =====================
	// RUTAS PROTEGIDAS (requieren token)
	// =====================

	autorizado := router.Group("/")
	autorizado.Use(Autenticar())

	// Citas protegidas
	autorizado.POST("/citas", CrearCita)
	autorizado.GET("/citas/:id", ObtenerCita)
	autorizado.PUT("/citas/:id", ActualizarCita)
	autorizado.PUT("/citas/:id/confirmar", ConfirmarCita)
	autorizado.PUT("/citas/:id/rechazar", RechazarCita)
	autorizado.PUT("/citas/:id/cancelar", CancelarCitaConMotivo)

	// Servicios protegidos
	autorizado.POST("/servicios", CrearServicio)
	autorizado.PUT("/servicios/:id", ActualizarServicio)
	autorizado.DELETE("/servicios/:id", EliminarServicio)

	// Reportes, notificaciones y perfil
	autorizado.POST("/notificaciones/:id", EnviarNotificacion)
	autorizado.GET("/reporte/citas-por-fechas", ReporteCitasPorFechas)
	autorizado.GET("/mi-perfil", VerMiPerfil)
	autorizado.GET("/mis-citas", MisCitasCliente)

	// Admin puede registrar usuarios
	autorizado.POST("/admin/usuarios", RegistrarUsuarioComoAdmin)

	// NUEVOS LISTADOS DE CITAS (usuarios + invitados)
	autorizado.GET("/citas/usuarios", ListarCitasUsuarios)
	autorizado.GET("/citas/invitados", ListarCitasInvitados)

	// Facturación pública (por ahora)
	router.GET("/facturas/:id", GenerarFacturaPDF)

	return router
}
