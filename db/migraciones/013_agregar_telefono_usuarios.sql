-- Agregar columna telefono a tabla usuarios
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('usuarios') AND name = 'telefono')
BEGIN
    ALTER TABLE usuarios 
    ADD telefono NVARCHAR(20) NULL;
    
    PRINT 'Columna telefono agregada a tabla usuarios';
END
ELSE
BEGIN
    PRINT 'La columna telefono ya existe';
END

-- Actualizar usuarios existentes con telefono por defecto
UPDATE usuarios 
SET telefono = '0000-0000' 
WHERE telefono IS NULL;