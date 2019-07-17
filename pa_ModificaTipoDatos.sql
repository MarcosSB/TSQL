CREATE PROCEDURE [dbo].[pa_ModificaTipoDatos]			
AS
BEGIN	
--//Debido a que no se puede hacer un ALTER TABLE ALTER COLUMN y modificar la CONSTRAINT DEFAULT en el mismo paso lo que haremos será lo siguiente:
--	 i)DROP FK, DROP PK, DROP DF
--	ii)ALTER TABLE ALTER COLUMN de las columnas afectadas cambiando NVARCHAR por VARCHAR
-- iii)ADD DF, PK, FK (orden inverso que en el punto i)

/*******************************************
* DEFAULT CONSTRAINTS
--//Buscamos en las tablas de sistema las DEFAULT CONSTRAINTS que nos puedan afectar (para columnas tipo nvarchar) y las almacenamos en un tabla variable.
*******************************************/	
	DECLARE @DefaultConstraints TABLE
			(	 ConstraintNombre VARCHAR(200)
				,TablaNombre VARCHAR(100)
				,ColumnaNombre VARCHAR(100)
				,SchemaNombre VARCHAR(20)
				,ValorDefecto VARCHAR(20)
				,DropConstrain VARCHAR(1000)
				,AddConstrain VARCHAR(1000)
			)	
	INSERT @DefaultConstraints 		
	SELECT	
			dc.name AS ConstraintNombre,
			t.name AS TablaNombre,
			ac.name AS ColumnaNombre,
			sch.name AS SchemaNombre,
			dc.definition AS ValorDefecto,
			'ALTER TABLE ['+sch.name+'].['+t.name+'] DROP CONSTRAINT ['+dc.name+']'    AS DropConstrain, 
			'ALTER TABLE ['+sch.name+'].['+t.name+'] ADD CONSTRAINT ['+dc.name+'] DEFAULT '+dc.definition+' FOR ['+ac.name	+']' AS AddConstrain 
	FROM sys.all_columns ac
	INNER JOIN sys.tables t 
		ON ac.object_id = t.object_id
	INNER JOIN sys.schemas sch
		ON t.schema_id = sch.schema_id
	INNER JOIN sys.default_constraints dc
		ON ac.default_object_id = dc.object_id
	INNER JOIN sys.types ty
		ON ac.system_type_id=ty.system_type_id
	WHERE ty.name='nvarchar'	

/*******************************************
* PRIMARY KEYS
--//Buscamos las PRIMARY KEYS que nos puenda afectar (que estén en columnas NVARCHAR) y las almacenamos en una tabla variable
*******************************************/	
	DECLARE @ClavesPrimarias TABLE
			(	 ClaveNombre VARCHAR(200)
				,TablaNombre VARCHAR(100)
				,ColumnaNombre VARCHAR(100)
				,EsquemaNombre VARCHAR(20)
				,DropClavePrimaria VARCHAR(1000)
				,AddClavePrimaria VARCHAR(1000)
			)	
	INSERT @ClavesPrimarias 	
	SELECT	tcc.CONSTRAINT_NAME AS ClaveNombre,
			tcc.TABLE_NAME AS TablaNombre,
			tcc.COLUMN_NAME AS ColumnaNombre,
			tcc.TABLE_SCHEMA AS EsquemaNombre,	
			'ALTER TABLE [' + tcc.TABLE_SCHEMA + '].[' + tcc.TABLE_NAME + '] DROP CONSTRAINT [' + tcc.CONSTRAINT_NAME + ']' AS DropClavePrimaria,
			'ALTER TABLE [' + tcc.TABLE_SCHEMA + '].[' + tcc.TABLE_NAME + '] ADD CONSTRAINT [' + tcc.CONSTRAINT_NAME + ']' +' PRIMARY KEY ('+tcc.COLUMN_NAME+')'  AS AddClavePrimaria
	FROM INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE tcc
	INNER JOIN INFORMATION_SCHEMA.[COLUMNS] c
		ON c.COLUMN_NAME=tcc.COLUMN_NAME
	WHERE tcc.TABLE_NAME<>'sysdiagrams'
	AND c.DATA_TYPE='NVARCHAR'
	AND tcc.CONSTRAINT_NAME LIKE 'PK_%'
	
/*******************************************
* FOREIGN KEYS
--//Buscamos las FOREIGN KEYS que nos puenda afectar (que estén en columnas NVARCHAR) y las almacenamos en una tabla variable
*******************************************/	
	DECLARE @ClavesAjenas TABLE
			(	 ClaveNombre VARCHAR(200)
				,EsquemaNombre VARCHAR(20)
				,TablaNombre VARCHAR(100)
				,ColumnaNombre VARCHAR(100)
				,TablaAjenaNombre VARCHAR(100)
				,ColumnaAjenaNombre VARCHAR(100)
				,DropClaveAjena VARCHAR(1000)
				,AddClaveAjena VARCHAR(1000)
			)	
	INSERT @ClavesAjenas 	
	SELECT  
		fk.ForeignKeyName,
        fk.ForeignTableSchema,
        fk.ForeignTableName,
        fk.ForeignTableColumn,
        ob.[name] AS TablaAjenaNombre,
        c.[name] AS ColumnaAjenaNombre,
        'ALTER TABLE [' + fk.ForeignTableSchema + '].[' + fk.ForeignTableName + '] DROP CONSTRAINT [' + fk.ForeignKeyName + '] 'AS DropClaveAjena,
        'ALTER TABLE ['+ fk.ForeignTableSchema + '].[' + fk.ForeignTableName +'] WITH CHECK ADD CONSTRAINT [' + fk.ForeignKeyName  + '] FOREIGN KEY([' + fk.ForeignTableColumn + ']) REFERENCES [' + fk.ForeignTableSchema + '].[' + ob.[name] + ']([' + c.[name] + '])' AS AddClaveAjena
        FROM    sys.objects ob
        INNER JOIN sys.columns c ON ( c.[object_id] = ob.[object_id] )
        INNER JOIN 
                  ( SELECT fks.[name] AS ForeignKeyName,
                           SCHEMA_NAME(o.schema_id) AS ForeignTableSchema,
                           o.[name] AS ForeignTableName,
                           col.[name] AS ForeignTableColumn,
                           t.name AS TypeName,
                           fks.referenced_object_id AS referenced_object_id,
                           fkc.referenced_column_id AS referenced_column_id
                     FROM   sys.foreign_keys fks
                            INNER JOIN sys.foreign_key_columns fkc 
                                 ON ( fkc.constraint_object_id = fks.[object_id] )
                            INNER JOIN sys.objects o 
                                 ON ( o.[object_id] = fks.parent_object_id )
                            INNER JOIN sys.columns col 
                                 ON ( col.[object_id] = o.[object_id] )
                                 AND ( col.column_id = fkc.parent_column_id )
                            INNER JOIN sys.types t
								ON t.system_type_id=col.system_type_id	 
                   ) fk
                     ON ( fk.referenced_object_id = ob.[object_id] )
                     AND ( fk.referenced_column_id = c.column_id )
        WHERE  ( ob.[type] = 'U' )  
        AND ( ob.[name] NOT IN ( 'sysdiagrams' ) ) 
       AND fk.TypeName='nvarchar'
		
	
/*******************************************
* COLUMNAS NVARCHAR
--//Buscamos Buscamos en las tablas de sistema las columnas NVARCHAR de las tablas que sea
*******************************************/
	DECLARE @ColumnasNvarchar TABLE
		(	 SchemaNombre VARCHAR(20)
			,TablaNombre VARCHAR(100)
			,ColumnaNombre VARCHAR(100)
			,ColumnaAncho VARCHAR(20)
			,Nullable VARCHAR(20)
			,AlterTable VARCHAR(1000)
		)
	INSERT @ColumnasNvarchar	
	SELECT	col.TABLE_SCHEMA AS Esquema,
			tab.TABLE_NAME AS TablaNombre,
			col.COLUMN_NAME AS ColumnaNombre,
			col.CHARACTER_MAXIMUM_LENGTH AS ColumnaAnchoCaracteres,
			CASE WHEN col.IS_NULLABLE='NO' THEN 'NOT NULL' ELSE 'NULL' END AS ColumnaNullable,
			'ALTER TABLE ['   + LTRIM(RTRIM(col.TABLE_SCHEMA)) +'].['+ LTRIM(RTRIM(col.TABLE_NAME)) +'] ALTER COLUMN [' + LTRIM(RTRIM(COLUMN_NAME)) + '] VARCHAR(' + LTRIM(RTRIM(CHARACTER_MAXIMUM_LENGTH)) + ') ' +  (CASE WHEN IS_NULLABLE='YES' THEN 'NULL' WHEN IS_NULLABLE='NO' THEN 'NOT NULL' ELSE '' END) AS AlterTable
	FROM INFORMATION_SCHEMA.COLUMNS  col
	INNER JOIN INFORMATION_SCHEMA.TABLES tab 
		ON col.TABLE_NAME=tab.TABLE_NAME
	WHERE DATA_TYPE='NVARCHAR'
	AND tab.TABLE_NAME<> 'sysdiagrams'
	AND tab.TABLE_TYPE='BASE TABLE'	
	ORDER BY col.TABLE_NAME
	
/*******************************************
* TABLA CON INSTRUCCIONES GENERICAS. Aquí se extraen las colsultas dinámicas ya generadas en los pasos anteriores 
* con el orden y la lógica descrita en los primeros comentarios. i),ii) y iii)
*******************************************/	
	DECLARE @ConsultasALTER TABLE
		(	 CodigoAlter VARCHAR(2000)
			,Orden INT
		)
	INSERT @ConsultasALTER
	SELECT Consultas.CodigoAlter,Consultas.Orden
	FROM
	(	
		SELECT DropClaveAjena AS CodigoAlter,'DropClaveAjena' AS Tipo,1 AS Orden			
		FROM @ClavesAjenas
			UNION
		SELECT DropClavePrimaria AS CodigoAlter,'DropClavePrimaria' AS Tipo,2 AS Orden			
		FROM @ClavesPrimarias		
			UNION
		SELECT DropConstrain AS CodigoAlter,'DropConstrain' AS Tipo,3 AS Orden			
		FROM @DefaultConstraints	
			UNION
		SELECT AlterTable AS CodigoAlter,'AlterTable' AS Tipo,4 AS Orden				
		FROM @ColumnasNvarchar
			UNION
		SELECT AddConstrain AS CodigoAlter,'AddConstrain' AS Tipo,5 AS Orden			
		FROM @DefaultConstraints	
			UNION
		SELECT AddClavePrimaria AS CodigoAlter,'AddClavePrimaria' AS Tipo,6 AS Orden			
		FROM @ClavesPrimarias	
			UNION
		SELECT AddClaveAjena AS CodigoAlter,'AddClaveAjena' AS Tipo,7 AS Orden			
		FROM @ClavesAjenas
	) AS Consultas
	ORDER BY Consultas.Orden ASC														--/El orden de ejecucion de las consultas es CRITICO!!

	--SELECT c.CodigoAlter,c.Orden FROM @ConsultasALTER c ORDER BY c.Orden									--Consulta final
	
/*******************************************
* CURSOR QUE EJECUTA EN ORDEN TODAS LAS CONSULTAS GENERADAS
--//Ejecutamos las consultas generadas anteriormente con un cursor
*******************************************/	

	DECLARE @CodigoALTER NVARCHAR(1000)
	DECLARE @CodigoOrden INT
	DECLARE curALTERS CURSOR LOCAL FOR 	SELECT c.CodigoAlter,c.Orden
										FROM @ConsultasALTER c
										ORDER BY c.Orden
	OPEN curALTERS
	FETCH NEXT FROM curALTERS INTO @CodigoALTER,@CodigoOrden
		WHILE  @@FETCH_STATUS = 0
			BEGIN
				EXECUTE sp_executesql @CodigoALTER
				--PRINT @CodigoALTER
				FETCH NEXT FROM curALTERS INTO @CodigoALTER,@CodigoOrden
			END
	CLOSE curALTERS
	DEALLOCATE curALTERS	
	

END	
