-- Agregar estado 'finalizada' a las citas
-- Actualizar restricción de estado para incluir 'finalizada'

-- Verificar restricciones existentes
SELECT name, definition 
FROM sys.check_constraints 
WHERE parent_object_id = OBJECT_ID('citas');

-- Agregar restricción para estados si no existe
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints 
    WHERE parent_object_id = OBJECT_ID('citas') 
      AND definition LIKE '%finalizada%'
)
BEGIN
    -- Eliminar restricción existente si hay alguna sobre estado
    DECLARE @constraint_name NVARCHAR(128)
    SELECT @constraint_name = name 
    FROM sys.check_constraints 
    WHERE parent_object_id = OBJECT_ID('citas') 
      AND definition LIKE '%estado%'
    
    IF @constraint_name IS NOT NULL
    BEGIN
        EXEC('ALTER TABLE citas DROP CONSTRAINT ' + @constraint_name)
        PRINT 'Restricción de estado anterior eliminada: ' + @constraint_name
    END
    
    -- Agregar nueva restricción con todos los estados incluyendo 'finalizada'
    ALTER TABLE citas ADD CONSTRAINT CHK_citas_estado_completo 
    CHECK (estado IN ('pendiente', 'confirmada', 'rechazada', 'cancelada', 'atendida', 'finalizada'))
    
    PRINT 'Estado finalizada agregado a las citas'
END
ELSE
BEGIN
    PRINT 'El estado finalizada ya existe en las citas'
END