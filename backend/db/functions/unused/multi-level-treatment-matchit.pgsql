CREATE OR REPLACE FUNCTION matchit(
  sourceTable TEXT,        -- input table name
  primaryKey TEXT,         -- source table's primary key
  treatment TEXT,                -- treatment column name (prefixed with it's table name - `tableName.columnName`)
  treatmentLevels INTEGER,
  covariatesArr TEXT[],          -- space separated covariate column names (prefixed with their table names - `tableName.columnName`)
  output_table TEXT              -- output table name
) RETURNS TEXT AS $func$
DECLARE
  commandString TEXT;
  numGroups INTEGER;
  numDiscarded INTEGER;
  covariate TEXT;
  columnName TEXT;
BEGIN
  -- SELECT regexp_split_to_array(covariates, '\s+') INTO covariatesArr;
  -- SELECT regexp_split_to_array(sourceTables, '\s+') INTO sourceTable;
  -- SELECT regexp_split_to_array(primary_keys, '\s+') INTO primaryKey;
  commandString := 'WITH subclasses as (SELECT '
    || ' max(' || primaryKey || ') AS subclass_' || primaryKey;

  FOREACH covariate IN ARRAY covariatesArr LOOP
    commandString = commandString || ', ' || quote_ident(covariate) || ' AS ' || quote_ident(covariate) || '_matched';
  END LOOP;

  commandString = commandString || ' FROM ' || quote_ident(sourceTable) || ' GROUP BY ';

  FOREACH covariate IN ARRAY covariatesArr LOOP
    commandString = commandString || quote_ident(covariate) || '_matched, ';
  END LOOP;

  -- use substring here to chop off last comma
  commandString = substring( commandString from 0 for (char_length(commandString) - 1) );
    
  commandString = commandString || ' HAVING count(distinct ' || treatment || ') = ' || treatmentLevels
    || ') SELECT * FROM subclasses, ' || quote_ident(sourceTable) || ' st WHERE';

  FOREACH covariate IN ARRAY covariatesArr LOOP
    commandString = commandString || ' subclasses.' || quote_ident(covariate) || '_matched = st.' || quote_ident(covariate) || ' AND';
  END LOOP;

  -- use substring here to chop off last `AND`
  commandString = substring( commandString from 0 for (char_length(commandString) - 3) );

  -- EXECUTE format('DROP MATERIALIZED VIEW IF EXISTS %s', output_table);

  commandString = 'CREATE MATERIALIZED VIEW ' || output_table
    || ' AS ' || commandString || ' WITH DATA;';
  RAISE NOTICE '%', commandString;
  EXECUTE commandString;

  RETURN 'Match successful and materialized in ' || output_table || '!';
END;
$func$ LANGUAGE plpgsql;

DROP MATERIALIZED VIEW IF EXISTS test_flight;

SELECT matchit('demo_test_1000', 'fid', 'thunder', 2, ARRAY['fog', 'hail'], 'test_flight');

SELECT * FROM test_flight;

DROP FUNCTION matchit(text,text,text,integer,text[],text);

SELECT column_name FROM information_schema.columns WHERE table_name = 'demo_test_1000';