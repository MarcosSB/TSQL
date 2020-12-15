
/*******************************************
MASANCHEZB (201708)
Función basada en fnSplitParameters que devuelve el n elemento de una cadena separada por el delimitador @sDelimiter.
Es habitual en algunas cargas que te mande, por ejemplo, la dirección así:
AL;SAN SEBASTIAN;1;;;;SAN SEBASTIAN (GONDOMAR);PONTEVEDRA;36388
Y para cargar el elemento correctamente en base se utiliza esta función.
*******************************************/
CREATE FUNCTION [dbo].[fn_ParserIndexed](
    @sInputList VARCHAR(1000), -- List of delimited items
    @sIndex INT 
) RETURNS NVARCHAR(150)

BEGIN
	DECLARE @sItem VARCHAR(1000)
	DECLARE @sDelimiter VARCHAR(1)
	DECLARE @List TABLE (item VARCHAR(1000),Order INT IDENTITY(1,1) NOT NULL)

	SET  @sDelimiter = ';'
	WHILE CHARINDEX(@sDelimiter,@sInputList,0) <> 0
		BEGIN
			SELECT
				@sItem=RTRIM(LTRIM(SUBSTRING(@sInputList,1,CHARINDEX(@sDelimiter,@sInputList,0)-1))),
				@sInputList=RTRIM(LTRIM(SUBSTRING(@sInputList,CHARINDEX(@sDelimiter,@sInputList,0)+LEN(@sDelimiter),LEN(@sInputList))))
 
			IF LEN(@sItem) > 0
				INSERT INTO @List SELECT @sItem
			ELSE  
				INSERT INTO @List SELECT ''
		END

	IF LEN(@sInputList) > 0
		INSERT INTO @List SELECT @sInputList -- Put the last item in
		
	RETURN
		(
			SELECT item
			FROM @List
			WHERE Order=@sIndex
		)

END
GO

