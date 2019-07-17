
CREATE FUNCTION [dbo].[fn_DATEADD_DiasLaborales](		@DiasDiff INT,
														@Fecha DATETIME)
RETURNS DATETIME
AS
BEGIN
DECLARE @Multiplicador INT	--/Direccion de avanzar o retrasar en las fechas
DECLARE @DiasHabiles INT				--/Indice del bluce

	--/Obtenemos la dirección de sumar o restar fechas en función del signo de los dias
IF @DiasDiff >= 0	
	SET @Multiplicador=1
ELSE IF @DiasDiff < 0
	SET @Multiplicador=-1

	--/Se hace el bucle con el numero de dias hábiles a recorrer
SET @DiasHabiles=ABS(@DiasDiff)

WHILE @DiasHabiles > 0
	BEGIN
			--/Añades o restas un dia según la direccion que marque el signo de @Multiplicador
		SET @Fecha=DATEADD(d,1*@Multiplicador,@Fecha)		
			--/Si la fecha actual es sabado o domingo se añade o resta un dia a la fecha de salida
			--/Se hace dos veces para ignorar primero sabado o domingo en funcion de la dirección del @Multiplicador
		IF DATEPART(DW,@Fecha) IN (6,7) SET @Fecha=DATEADD(d,1*@Multiplicador,@Fecha)
		IF DATEPART(DW,@Fecha) IN (6,7) SET @Fecha=DATEADD(d,1*@Multiplicador,@Fecha)
			--//Se actualiza el contador siempre desde numero natural hacia abajo
		SET @DiasHabiles=@DiasHabiles-1												
	END
	   
RETURN CAST(@Fecha AS DATETIME)
/*******************************************
Como mejora a este codigo habría que cambiar los días 6,7 ya que en paises anglosajones pueden cambiar.
Quizá añadiendo DATENAME(DW,@Fecha)='saturday' y DATENAME(DW,@Fecha)='sunday'
*******************************************/

END
GO

