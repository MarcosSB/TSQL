
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<MASANCHEZB>
-- Create date: <>
-- Description:	<QUERY GENÉRICA PARA VACIAR LAS TABLAS DE UNA BASE SIN ALTERAR LA ESTRUCTURA
--				INCLUYE EL MODIFICADOR QUE PERMITE SELECCIONAR LAS TABLA A INCLUIR O A EXCLUIR>
-- =============================================
CREATE PROCEDURE [dbo].[pa_LimpiarBase]
			
AS

BEGIN

	USE --XXXXX

	/************************************************************
			   COMPROBAR SI EXISTEN VISTAS INDEXADAS
	************************************************************/
	IF EXISTS(SELECT COUNT(1) FROM sys.objects o
	INNER JOIN sys.indexes i ON i.[object_id] = o.[object_id]
	WHERE o.[type]='v'
		GROUP BY o.name)
	BEGIN
	PRINT 'EXISTEN VISTAS INDEXADAS'

	/************************************************************
			   OBTENCION DE LAS VISTAS INDEXADAS
	************************************************************/
	SET NOCOUNT ON;
	SELECT o.name AS Vistas_Indexadas,max(i.index_id) AS Cant_índices FROM sys.objects o
	INNER JOIN sys.indexes i ON i.[object_id] = o.[object_id]
	WHERE o.[type]='v'
		GROUP BY o.name
    
	/************************************************************
			   OBTENCION DE LAS DEPENDENCIAS
	************************************************************/
	DECLARE @ID_OBJECT VARCHAR(50)
			,@MAXINDEX VARCHAR(100)
	DECLARE DEPENDENTS CURSOR READ_ONLY

	FOR
			SELECT o.[OBJECT_ID],max(i.index_id) 
			FROM sys.objects o
			INNER JOIN sys.indexes i 
				ON i.[object_id] = o.[object_id]
			WHERE o.[type]='v'
			GROUP BY o.name,o.OBJECT_ID          
	OPEN DEPENDENTS
	FETCH NEXT FROM DEPENDENTS INTO @ID_OBJECT,@MAXINDEX
	WHILE @@FETCH_STATUS = 0
	BEGIN
	   DECLARE @QUERY_DEP AS NVARCHAR(MAX)
				SET @QUERY_DEP =  
				'SET NOCOUNT ON;
				  SELECT ''Tablas de las que depende'' = (s.name+ ''.'' + o.name)
						,MAX(d.depnumber) AS Dependencias
					   FROM   sys.objects o
					   INNER JOIN sysdepends d ON o.object_id = d.depid
						  INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
					   WHERE d.id = '+ @ID_OBJECT +'
				  GROUP BY (s.name+ ''.'' + o.name)'
		EXECUTE sp_executesql @QUERY_DEP
		   FETCH NEXT FROM DEPENDENTS INTO @ID_OBJECT,@MAXINDEX
		  END
	CLOSE DEPENDENTS
	DEALLOCATE DEPENDENTS

	/************************************************************
	   GENERAR SCRIPT PARA BORRAR INDICES DE VISTAS INDEXADAS
	************************************************************/
	SELECT 
	o.name AS VIEWNAME,
	i.name AS INDEXNAME,
	SCHEMA_NAME(o.schema_id) AS SCHEMANAME,
	i.type_desc AS TIPO,
	CASE WHEN i.is_unique = 1 THEN 'SI'
		 WHEN i.is_unique = 0 THEN 'NO' END
		 AS UNICO,
	c.name AS COLUMNA ,
	CASE WHEN ic.is_included_column = 1 THEN 'COLUMNA INCLUIDA' 
		 WHEN ic.is_included_column = 0 THEN ''  END
		 AS COL_INCLUIDA
	INTO #INDEX
	FROM 
	sys.columns c
	INNER JOIN  sys.indexes i ON c.object_id = i.object_id
	INNER JOIN  sys.index_columns ic 
		ON c.object_id = ic.object_id 
		AND c.column_id = ic.column_id 
		AND i.index_id = ic.index_id
	INNER JOIN sys.objects o 
		ON o.[object_id]=ic.[object_id]
	WHERE 
	o.[type]='v'

	DECLARE @INDEXNAME VARCHAR(50)
			,@SCHEMANAME VARCHAR(100)
			,@VIEWNAME VARCHAR(100)
			DECLARE DROPIND CURSOR READ_ONLY
	FOR
			SELECT  INDEXNAME,SCHEMANAME ,VIEWNAME
			FROM    #INDEX
        
	OPEN DROPIND
	FETCH NEXT FROM DROPIND INTO @INDEXNAME,@SCHEMANAME,@VIEWNAME
	WHILE @@FETCH_STATUS = 0
		  BEGIN
				 DECLARE @QUERY_DROPIND VARCHAR (2000)
				 SET @QUERY_DROPIND = 'DROP INDEX [' + @INDEXNAME + '] ON [' + @SCHEMANAME + '].[' + @VIEWNAME + '] WITH ( ONLINE = OFF )'
				 PRINT  @QUERY_DROPIND
				 EXECUTE sp_executesql @QUERY_DROPIND
				 FETCH NEXT FROM DROPIND INTO @INDEXNAME,@SCHEMANAME,@VIEWNAME
		  END
	CLOSE DROPIND
	DEALLOCATE DROPIND
	SELECT * FROM #INDEX
	DROP TABLE #INDEX
	END
	ELSE
       
	/************************************************************
			 PROCESO DE TRUNCADO DE LAS TABLAS DE LA DB
	************************************************************/
	BEGIN
	DECLARE @FOREIGNKEYS TABLE
			(
			 SCHEMATABLE VARCHAR(20)
			,TABLENAME VARCHAR(100)
			,FOREIGNKEYNAME VARCHAR(100)
			,FOREIGNTABLECOLUMN VARCHAR(200)
			,SCHEMATABLEFK VARCHAR(200)
			,TABLENAMEFK  VARCHAR(200)
			,COLUMNNAMEFK VARCHAR(200)
			)
        
	INSERT  @FOREIGNKEYS
			SELECT  
			fk.ForeignTableSchema, 
			fk.ForeignTableName, 
			fk.ForeignKeyName,
			fk.ForeignTableColumn,
			SCHEMA_NAME(ob.schema_id),
			ob.[name],
			c.[name] 
			FROM    sys.objects ob
			INNER JOIN sys.columns c ON ( c.[object_id] = ob.[object_id] )
			INNER JOIN 
					  ( SELECT fks.[name] AS ForeignKeyName,
							   SCHEMA_NAME(o.schema_id) AS ForeignTableSchema,
							   o.[name] AS ForeignTableName,
							   col.[name] AS ForeignTableColumn,
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
					   ) fk
						 ON ( fk.referenced_object_id = ob.[object_id] )
						 AND ( fk.referenced_column_id = c.column_id )
			WHERE   ( ob.[type] = 'U' )  AND ( ob.[name] NOT IN ( 'sysdiagrams','sysrscols' ) ) 
			---PODEMOS EXCLUIR LAS TABLAS QUE NO NECESITEMOS TRUNCAR.
			---O INCLUIR SÓLO LAS QUE NECESITEMOS TRUNCAR
			AND ob.name  
			IN
			(
							---PODEMOS EXCLUIR LAS TABLAS QUE NO NECESITEMOS TRUNCAR.
							---O INCLUIR SÓLO LAS QUE NECESITEMOS TRUNCAR
			)         
               
	/************************************************************
				ELIMINAMOS LAS LLAVES FORANEAS(FOREIGN KEY)
	************************************************************/
	DECLARE @SCHEMATABLE VARCHAR(50)
			,@TABLENAME VARCHAR(100)
			,@FOREIGNKEYNAME VARCHAR(100)

	DECLARE DROPFK CURSOR READ_ONLY
	FOR
			SELECT  SCHEMATABLE ,TABLENAME ,ForeignKeyName
			FROM    @FOREIGNKEYS
        
	OPEN DROPFK
	FETCH NEXT FROM DROPFK INTO @SCHEMATABLE,@TABLENAME,@FOREIGNKEYNAME 
	WHILE @@FETCH_STATUS = 0
		  BEGIN
			  DECLARE @QUERY_DROPFK AS NVARCHAR(MAX)
				SET @QUERY_DROPFK =  'ALTER TABLE [' + @SCHEMATABLE + '].[' + @TABLENAME + '] DROP CONSTRAINT [' + @FOREIGNKEYNAME + ']; '
				PRINT  @QUERY_DROPFK
				EXECUTE sp_executesql @QUERY_DROPFK
				FETCH NEXT FROM DROPFK INTO @SCHEMATABLE,@TABLENAME,@FOREIGNKEYNAME 
		  END
	CLOSE DROPFK
	DEALLOCATE DROPFK

	/************************************************************
		  TRUNCAMOS LAS TABLAS QUE QUEREMOS
	************************************************************/

	DECLARE @SCHEMATRUNCATE VARCHAR(50)
			,@TABLENAMETRUNCATE VARCHAR(100)
        
	DECLARE TRUNCATETABLE CURSOR READ_ONLY
	FOR
			SELECT s.name,o.name 
			FROM SYS.objects o
			INNER JOIN sys.schemas s 
				ON s.[schema_id] = o.[schema_id]
			---PODEMOS EXCLUIR LAS TABLAS QUE NO NECESITEMOS TRUNCAR.
			---O INCLUIR SÓLO LAS QUE NECESITEMOS TRUNCAR            
			WHERE o.[type]='U' AND o.NAME 
			IN
			(
							---PODEMOS EXCLUIR LAS TABLAS QUE NO NECESITEMOS TRUNCAR.
							---O INCLUIR SÓLO LAS QUE NECESITEMOS TRUNCAR
			)     
        
	OPEN TRUNCATETABLE
	FETCH NEXT FROM TRUNCATETABLE INTO @SCHEMATRUNCATE, @TABLENAMETRUNCATE
	WHILE @@FETCH_STATUS = 0
	BEGIN
				 DECLARE @QUERY_TRUNCATE AS NVARCHAR(MAX)
			  SET @QUERY_TRUNCATE =  'TRUNCATE TABLE [' + @SCHEMATRUNCATE + '].[' + @TABLENAMETRUNCATE + ']; '
			  PRINT  @QUERY_TRUNCATE
			  EXECUTE sp_executesql @QUERY_TRUNCATE
			  FETCH NEXT FROM TRUNCATETABLE INTO @SCHEMATRUNCATE, @TABLENAMETRUNCATE
		  END
	CLOSE TRUNCATETABLE
	DEALLOCATE TRUNCATETABLE

	/************************************************************
				CREAMOS LAS LLAVES FORANEAS(FOREIGN KEY)
	************************************************************/

	DECLARE @SCHEMATABLECR VARCHAR(50)
			,@TABLENAMECR VARCHAR(100)
			,@FOREIGNKEYNAMECR VARCHAR(100)
			,@FOREIGNTABLECOLUMNCR VARCHAR(100)
			,@SCHEMATABLEFK VARCHAR(100)
			,@TABLENAMEFK VARCHAR(100)
			,@COLUMNNAMEFK VARCHAR(200)
	DECLARE CREATEFK CURSOR READ_ONLY
	FOR
			SELECT  SCHEMATABLE ,TABLENAME ,FOREIGNKEYNAME,FOREIGNTABLECOLUMN,SCHEMATABLEFK,TABLENAMEFK,COLUMNNAMEFK 
			FROM    @FOREIGNKEYS
        
	OPEN CREATEFK
	FETCH NEXT FROM CREATEFK INTO @SCHEMATABLECR,@TABLENAMECR,@FOREIGNKEYNAMECR,@FOREIGNTABLECOLUMNCR,@SCHEMATABLEFK,@TABLENAMEFK,@COLUMNNAMEFK
	WHILE @@FETCH_STATUS = 0
		  BEGIN
			   DECLARE @QUERY_CREATE AS NVARCHAR(MAX)
			   SET @QUERY_CREATE =  'ALTER TABLE ['+ @SCHEMATABLECR + '].[' + @TABLENAMECR +'] WITH CHECK ADD CONSTRAINT [' + @FOREIGNKEYNAMECR 
				+ '] FOREIGN KEY([' + @FOREIGNTABLECOLUMNCR + ']) REFERENCES [' + @SCHEMATABLEFK + '].[' + @TABLENAMEFK + ']([' + @COLUMNNAMEFK + ']); '
			   PRINT  @QUERY_CREATE
			   EXECUTE sp_executesql @QUERY_CREATE
			   FETCH NEXT FROM CREATEFK INTO @SCHEMATABLECR,@TABLENAMECR,@FOREIGNKEYNAMECR,@FOREIGNTABLECOLUMNCR,@SCHEMATABLEFK,@TABLENAMEFK,@COLUMNNAMEFK
		  END
	CLOSE CREATEFK
	DEALLOCATE CREATEFK
	END

END
GO

