
CREATE FUNCTION [dbo].[fn_CalculaDC] (@Banco AS VARCHAR(4), @Sucursal AS VARCHAR(4), @Cuenta AS VARCHAR(10))

RETURNS VARCHAR(2)
	
	BEGIN
			DECLARE @DC_OK AS VARCHAR(2)
			DECLARE @DC_1 AS VARCHAR(2)
			DECLARE @DC_2 AS VARCHAR(2)
			
			SET @DC_1= 
			CONVERT(VARCHAR,(11 -( 
			CONVERT(INTEGER,SUBSTRING(@Banco,1,1))*4 + 
			CONVERT(INTEGER,SUBSTRING(@Banco,2,1))*8 + 
			CONVERT(INTEGER,SUBSTRING(@Banco,3,1))*5 + 
			CONVERT(INTEGER,SUBSTRING(@Banco,4,1))*10 + 
			CONVERT(INTEGER,SUBSTRING(@Sucursal,1,1))*9 + 
			CONVERT(INTEGER,SUBSTRING(@Sucursal,2,1))*7 + 
			CONVERT(INTEGER,SUBSTRING(@Sucursal,3,1))*3 + 
			CONVERT(INTEGER,SUBSTRING(@Sucursal,4,1))*6) % 11 ))
		
			SET @DC_2=
			CONVERT(VARCHAR,(11 - (
			CONVERT(INTEGER,SUBSTRING(@Cuenta,1,1))*1 + 
			CONVERT(INTEGER,SUBSTRING(@Cuenta,2,1))*2 + 
			CONVERT(INTEGER,SUBSTRING(@Cuenta,3,1))*4 + 
			CONVERT(INTEGER,SUBSTRING(@Cuenta,4,1))*8 + 
			CONVERT(INTEGER,SUBSTRING(@Cuenta,5,1))*5 + 
			CONVERT(INTEGER,SUBSTRING(@Cuenta,6,1))*10 + 
			CONVERT(INTEGER,SUBSTRING(@Cuenta,7,1))*9 + 
			CONVERT(INTEGER,SUBSTRING(@Cuenta,8,1))*7 + 
			CONVERT(INTEGER,SUBSTRING(@Cuenta,9,1))*3 + 
			CONVERT(INTEGER,SUBSTRING(@Cuenta,10,1))*6) % 11))
			
			IF @DC_1='11'
					SET @DC_1='0'			
			ELSE
				IF @DC_1='10'
					SET @DC_1='1'		
			IF @DC_2='11'
					SET @DC_2='0'			
			ELSE
				IF @DC_2='10'
					SET @DC_2='1'		


			SET @DC_OK= @DC_1 + @DC_2
			
			RETURN @DC_OK
	END


GO

