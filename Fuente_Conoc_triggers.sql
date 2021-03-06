--------------------------------------------------------------TRIGGERS
--Estudiantes table trigger
CREATE OR ALTER TRIGGER TRG_EST_ESTATUS
ON ESTUDIANTES
AFTER DELETE 
AS
	DECLARE @CARNET INT
	SELECT @CARNET = CARNET FROM deleted
	IF EXISTS(SELECT 1 FROM MATRICULAS WHERE CARNET= @CARNET)
		BEGIN
			UPDATE MATRICULAS
			SET ESTADO_M = 'INA'
			WHERE CARNET = @CARNET
		END
GO

--MATRICULAS TABLE TRIGGER
CREATE OR ALTER TRIGGER TRG_MATRI_DEL
ON MATRICULAS
INSTEAD OF DELETE 
AS
	DECLARE @N_MATRICULA INT
	SELECT @N_MATRICULA = NUM_MATRICULA FROM inserted
	IF EXISTS(SELECT 1 FROM PAGOS WHERE NUM_MATRICULA = @N_MATRICULA AND ESTADO_PAGO = 'PENDIENTE') 
		BEGIN
			PRINT 'Esta matricula tiene pagos activos'
		END
	ELSE
		BEGIN
			DELETE FROM MATRICULAS
			WHERE NUM_MATRICULA = @N_MATRICULA
		END
GO

--PAGO TABLE TRIGGER
CREATE OR ALTER TRIGGER TRG_UPD_PAGO
ON PAGOS
FOR UPDATE
AS
	DECLARE @N_MATRICULA INT, @COSTO DECIMAL , @COD_MAT INT, @CARNET INT,@ESTADO_PAGO VARCHAR(10),@ESTADO_ANT VARCHAR(10)
	SELECT @COD_MAT = COD_MATERIA_ABIERTA FROM inserted
	SELECT @COSTO = COSTO_MATERIA FROM MATERIAS_ABIERTAS MA INNER JOIN MATERIAS M ON MA.COD_MATERIA= M.COD_MATERIA WHERE COD_MATERIA_ABIERTA = @COD_MAT  
	SELECT @N_MATRICULA = NUM_MATRICULA FROM inserted
	SELECT @CARNET = E.CARNET FROM ESTUDIANTES E INNER JOIN MATRICULAS M ON E.CARNET=M.CARNET WHERE NUM_MATRICULA = @N_MATRICULA
	SELECT @ESTADO_ANT = ESTADO_PAGO FROM deleted
	SELECT @ESTADO_PAGO = ESTADO_PAGO FROM inserted
	IF @ESTADO_PAGO = 'CANCELADO' AND @ESTADO_ANT = 'PENDIENTE'
		BEGIN
			UPDATE ESTUDIANTES
			SET DEUDA = DEUDA - @COSTO
			WHERE CARNET = @CARNET
		END				
GO

--MATERIAS_ABIERTAS trigger que evita que se inserten datos con los comandos insert into para realizar dicho proceso
--en un procedimiento almacenado
CREATE OR ALTER TRIGGER TRG_MAT_ABI
ON MATERIAS_ABIERTAS
INSTEAD OF INSERT
AS	
	ROLLBACK TRAN
	PRINT 'Contacte al administrador para conocer el procedimiento para abrir materias'
GO

--CERTIFICACIONES PROFESORES
CREATE OR ALTER TRIGGER TRG_DEL_CERT
ON CERTIFICACIONES_PROFESORES
INSTEAD OF DELETE
AS
	DECLARE @COD_PROF INT
	DECLARE @CERT VARCHAR(4)
	DECLARE @MSJ VARCHAR(100)
	SELECT @CERT = COD_CERTIFICACION_P FROM deleted
	SELECT @COD_PROF = COD_PROF FROM deleted
	IF EXISTS(SELECT 1 FROM PROFESORES WHERE COD_PROF = @COD_PROF)
		BEGIN
			SET @MSJ= 'Este certificado corresponde a un profesor que aun se encuentra en registro'
		END
	ELSE
		BEGIN
			DELETE FROM CERTIFICACIONES_PROFESORES
			WHERE COD_CERTIFICACION_P = @CERT
			SET @MSJ = 'Borrado realizado'
		END
	PRINT @MSJ
GO



--PROFESORES
CREATE OR ALTER TRIGGER TRG_DEL_PROF
ON PROFESORES
INSTEAD OF DELETE
AS	
	DECLARE @COD_PROF INT
	DECLARE @MSJ VARCHAR(100)
	SELECT #COD_PROF = COD_PROF FROM deleted	
		IF EXISTS(SELECT 1 FROM MATERIAS_ABIERTAS WHERE COD_PROF = @COD_PROF)
			BEGIN
				SET @MSJ = 'Este profesor tiene Materias abiertas'
			END
		ELSE
			BEGIN
				DELETE FROM PROFESORES
				WHERE COD_PROF = @COD_PROF
				SET @MSJ = 'Borrado realizado'
			END	
	PRINT @MSJ
GO

--PROGRAMAS--Este trigger actualiza el numero de hora de duracion del programa en base a las materias
CREATE OR ALTER TRIGGER TRG_UPD_PROGRAMA
ON PROGRAMAS
FOR UPDATE
AS
	DECLARE @ID_PROG INT
	DECLARE @NUM_HORAS INT
	SELECT @ID_PROG = ID_PROGRAMA FROM inserted
	SELECT @NUM_HORAS = SUM(DURACION) FROM MATERIAS WHERE ID_PROGRAMA = @ID_PROG
	
	UPDATE PROGRAMAS
	SET DURACION_HORAS = @NUM_HORAS
	WHERE ID_PROGRAMA=@ID_PROG
GO	

--HORARIOS trigger que evita que se inserten horarios fuera del horario de la universidad
CREATE OR ALTER TRIGGER TRG_HORARIO_ADMITIDO
ON HORARIOS
INSTEAD OF INSERT
AS
	DECLARE @COD_MAT INT
	DECLARE @HORA_INICIO TIME
	DECLARE @HORA_FIN TIME
	SELECT @COD_MAT = COD_MATERIA_ABIERTA FROM inserted
	SELECT @HORA_INICIO = HORA_INICIO FROM inserted
	SELECT @HORA_FIN = HORA_FIN FROM inserted
	IF @HORA_INICIO < '07:00:00.0' AND @HORA_INICIO > '18:00:00.0'
		BEGIN
			ROLLBACK TRANSACTION
		END
	ELSE
		IF @HORA_FIN < '07:00:00.0' AND @HORA_FIN > '18:00:00.0'
			BEGIN
				ROLLBACK TRANSACTION
			END
	PRINT 'Se ha insertado correctamente el horario'
	
GO


--TRIGGER AGENDAS_ANIOS
CREATE OR ALTER TRIGGER TRG_INSERT_ANIOS_AGENDA
ON AGENDAS_ANIOS
FOR INSERT
AS
	DECLARE @ANIO SMALLINT, @NUM_FER INT
	SELECT @ANIO = ANIO FROM inserted
	
	SELECT @NUM_FER = COUNT(ANIO) FROM AGENDA_FERIADOS 
	WHERE ANIO= @ANIO

	UPDATE AGENDAS_ANIOS 
	SET CANTIDAD_FERIADOS = @NUM_FER
	WHERE ANIO = @ANIO
GO

--TRIGGER_MATERIAS 
CREATE OR ALTER TRIGGER TRG_INS_MATERIAS
ON MATERIAS
FOR INSERT
AS
	DECLARE @COD_MAT INT, @NUM_HORAS INT, @ID_PROG INT
	SELECT @ID_PROG = ID_PROGRAMA FROM inserted
	SELECT @COD_MAT= COD_MATERIA FROM inserted
	SELECT @NUM_HORAS = DURACION FROM inserted
	UPDATE PROGRAMAS
	SET DURACION_HORAS = DURACION_HORAS + @NUM_HORAS
	WHERE ID_PROGRAMA = @ID_PROG
GO


--TRIGGER LABORATORIOS
CREATE OR ALTER TRIGGER TRG_DEL_LAB
ON LABORATORIOS
INSTEAD OF DELETE
AS
	DECLARE @ID_LAB INT
	SELECT @ID_LAB = ID_LABORATORIO FROM deleted
	IF NOT EXISTS(SELECT 1 FROM MATERIAS_ABIERTAS WHERE ID_LABORATORIO = @ID_LAB)
		DELETE FROM LABORATORIOS
		WHERE ID_LABORATORIO = @ID_LAB
GO
--TRIGGER CERTIFICACIONES
CREATE OR ALTER TRIGGER TRG_DEL_CERT
ON CERTIFICACIONES
INSTEAD OF DELETE
AS
	DECLARE @COD_CERT VARCHAR(10)
	SELECT @COD_CERT = COD_CERTIFICACION FROM inserted
	IF NOT EXISTS(SELECT 1 FROM MATERIAS WHERE COD_CERTIFICACION = @COD_CERT)
		DELETE FROM CERTIFICACIONES
		WHERE COD_CERTIFICACION = @COD_CERT
GO

--TRIGGER AGENDA FERIADOS
CREATE OR ALTER TRIGGER TRG_DEL_AGENDA_FER
ON AGENDA_FERIADOS
INSTEAD OF DELETE
AS
	DECLARE @FECHA DATE, @ANIO SMALLINT
	SELECT @ANIO = ANIO FROM deleted
	SELECT @FECHA = FECHA FROM deleted
	IF NOT EXISTS(SELECT 1 FROM AGENDAS_ANIOS WHERE ANIO = @ANIO)
		DELETE FROM AGENDA_FERIADOS
		WHERE ANIO = @ANIO
GO









