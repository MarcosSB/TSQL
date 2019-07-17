
CREATE FUNCTION [dbo].[fn_FormatoHora] (@entrada integer)

RETURNS varchar(10) as 

BEGIN

	DECLARE @hh AS integer
	DECLARE @mm AS integer
	DECLARE @ss AS integer
	DECLARE @fhora AS varchar(10)

	SET @hh = (@entrada/3600)
	SET @mm = (@entrada-(@hh*3600))/60
	SET @ss = (@entrada-((@hh*3600)+(@mm*60)))

	IF LEN(@hh) > 2
	BEGIN
		SET @fhora =	RIGHT('0000'+CONVERT(varchar,@hh),4)+':'+
						RIGHT('00'+CONVERT(varchar,@mm),2)+':'+
						RIGHT('00'+CONVERT(varchar,@ss),2)
	END
	ELSE
		BEGIN
			SET @fhora =	RIGHT('00'+CONVERT(varchar,@hh),2)+':'+
							RIGHT('00'+CONVERT(varchar,@mm),2)+':'+
							RIGHT('00'+CONVERT(varchar,@ss),2)
		END

	

RETURN 
	@fhora

END
GO

