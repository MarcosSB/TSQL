
CREATE FUNCTION [dbo].[fn_CalculaLetraDni] (@DNI varchar(9))

RETURNS varchar(1) as

BEGIN
	DECLARE @salida AS VARCHAR(1)
	
	DECLARE @letra AS VARCHAR(1)

	IF LEFT(@DNI,1) IN ('0','1','2','3','4','5','6','7','8','9')
	BEGIN
				SET @letra = SUBSTRING('TRWAGMYFPDXBNJZSQVHLCKE', LEFT(@DNI,8) % 23 + 1, 1)
				SET @salida=@letra
	END
	ELSE			
			SET @salida = '0'

	RETURN @salida

END
GO

