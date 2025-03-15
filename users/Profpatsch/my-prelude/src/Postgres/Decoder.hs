module Postgres.Decoder where

import Control.Applicative (Alternative)
import Data.Aeson qualified as Json
import Data.Aeson.BetterErrors qualified as Json
import Data.Error.Tree
import Data.Typeable (Typeable)
import Database.PostgreSQL.Simple (Binary (fromBinary))
import Database.PostgreSQL.Simple.FromField qualified as PG
import Database.PostgreSQL.Simple.FromRow qualified as PG
import FieldParser (FieldParser)
import FieldParser qualified as Field
import Json qualified
import Label
import Parse (Parse, runParse)
import PossehlAnalyticsPrelude

-- | A Decoder of postgres values. Allows embedding more complex parsers (like a 'Json.ParseT').
newtype Decoder a = Decoder (PG.RowParser a)
  deriving newtype (Functor, Applicative, Alternative, Monad)

-- | Parse a `bytea` field, equivalent to @Binary ByteString@ but avoids the pitfall of having to use 'Binary'.
bytea :: Decoder ByteString
bytea = fromField @(Binary ByteString) <&> (.fromBinary)

-- | Parse a nullable `bytea` field, equivalent to @Binary ByteString@ but avoids the pitfall of having to use 'Binary'.
byteaMay :: Decoder (Maybe ByteString)
byteaMay = fromField @(Maybe (Binary ByteString)) <&> fmap (.fromBinary)

-- | Parse a `text` field.
text :: Decoder Text
text = fromField @Text

-- | Parse a nullable `text` field.
textMay :: Decoder (Maybe Text)
textMay = fromField @(Maybe Text)

-- | Parse a `text` field, and then use a 'FieldParser' to convert the result further.
textParse :: (Typeable to) => FieldParser Text to -> Decoder to
textParse = parseField @Text

-- | Parse a nullable `text` field, and then use a 'FieldParser' to convert the result further.
textParseMay :: (Typeable to) => FieldParser Text to -> Decoder (Maybe to)
textParseMay = parseFieldMay @Text

-- | Parse a type implementing 'FromField', and then use a 'FieldParser' to convert the result further.
parseField ::
  forall from to.
  ( PG.FromField from,
    Typeable to
  ) =>
  FieldParser from to ->
  Decoder to
parseField parser = Decoder $ PG.fieldWith $ \field bytes -> do
  val <- PG.fromField @from field bytes
  case Field.runFieldParser parser val of
    Left err ->
      PG.returnError
        PG.ConversionFailed
        field
        (err & prettyError & textToString)
    Right a -> pure a

-- | Parse a nullable type implementing 'FromField', and then use a 'FieldParser' to convert the result further.
parseFieldMay ::
  forall from to.
  ( PG.FromField from,
    Typeable to
  ) =>
  FieldParser from to ->
  Decoder (Maybe to)
parseFieldMay parser = Decoder $ PG.fieldWith $ \field bytes -> do
  val <- PG.fromField @(Maybe from) field bytes
  case Field.runFieldParser parser <$> val of
    Nothing -> pure Nothing
    Just (Left err) ->
      PG.returnError
        PG.ConversionFailed
        field
        (err & prettyError & textToString)
    Just (Right a) -> pure (Just a)

-- | Parse a type implementing 'FromField', and then use a 'Parse' to convert the result further.
parse ::
  forall from to.
  ( PG.FromField from,
    Typeable to
  ) =>
  Parse from to ->
  Decoder to
parse parser = Decoder $ PG.fieldWith $ \field bytes -> do
  val <- PG.fromField @from field bytes
  case Parse.runParse "Cannot parse field" parser val of
    Left err ->
      PG.returnError
        PG.ConversionFailed
        field
        (err & prettyErrorTree & textToString)
    Right a -> pure a

-- | Parse a nullable type implementing 'FromField', and then use a 'Parse' to convert the result further.
parseMay ::
  forall from to.
  ( PG.FromField from,
    Typeable to
  ) =>
  Parse from to ->
  Decoder (Maybe to)
parseMay parser = Decoder $ PG.fieldWith $ \field bytes -> do
  val <- PG.fromField @(Maybe from) field bytes
  case Parse.runParse "Cannot parse field" parser <$> val of
    Nothing -> pure Nothing
    Just (Left err) ->
      PG.returnError
        PG.ConversionFailed
        field
        (err & prettyErrorTree & textToString)
    Just (Right a) -> pure (Just a)

-- | Turn any type that implements 'PG.fromField' into a 'Decoder'. Use type applications to prevent accidental conversions:
--
-- @
-- fromField @Text :: Decoder Text
-- @
fromField :: (PG.FromField a) => Decoder a
fromField = Decoder $ PG.fieldWith PG.fromField

-- | Turn any type that implements 'PG.fromField' into a 'Decoder' and wrap the result into the given 'Label'. Use type applications to prevent accidental conversions:
--
-- @
-- fromField @"myField" @Text :: Decoder (Label "myField" Text)
-- @
fromFieldLabel :: forall lbl a. (PG.FromField a) => Decoder (Label lbl a)
fromFieldLabel = label @lbl <$> fromField

-- | Parse fields out of a json value returned from the database.
--
-- ATTN: The whole json record has to be transferred before it is parsed,
-- so if you only need a tiny bit of it, use `->` and `->>` in your SQL statement
-- and return only the fields you need from the query.
--
-- In that case pay attention to NULL though:
--
-- @
-- SELECT '{"foo": {}}'::jsonb->>'foo' IS NULL
-- → TRUE
-- @
--
-- Also note: `->>` will coerce the json value to @text@, regardless of the content.
-- So the JSON object @{"foo": {}}"@ would be returned as the text: @"{\"foo\": {}}"@.
json :: (Typeable a) => Json.ParseT ErrorTree Identity a -> Decoder a
json parser = Decoder $ PG.fieldWith $ \field bytes -> do
  val <- PG.fromField @Json.Value field bytes
  case Json.parseValue parser val of
    Left err ->
      PG.returnError
        PG.ConversionFailed
        field
        (err & Json.parseErrorTree "Cannot decode jsonb column" & prettyErrorTree & textToString)
    Right a -> pure a

-- | Parse fields out of a nullable json value returned from the database.
--
-- ATTN: The whole json record has to be transferred before it is parsed,
-- so if you only need a tiny bit of it, use `->` and `->>` in your SQL statement
-- and return only the fields you need from the query.
--
-- In that case pay attention to NULL though:
--
-- @
-- SELECT '{"foo": {}}'::jsonb->>'foo' IS NULL
-- → TRUE
-- @
--
-- Also note: `->>` will coerce the json value to @text@, regardless of the content.
-- So the JSON object @{"foo": {}}"@ would be returned as the text: @"{\"foo\": {}}"@.
jsonMay :: (Typeable a) => Json.ParseT ErrorTree Identity a -> Decoder (Maybe a)
jsonMay parser = Decoder $ PG.fieldWith $ \field bytes -> do
  val <- PG.fromField @(Maybe Json.Value) field bytes
  case Json.parseValue parser <$> val of
    Nothing -> pure Nothing
    Just (Left err) ->
      PG.returnError
        PG.ConversionFailed
        field
        (err & Json.parseErrorTree "Cannot decode jsonb column" & prettyErrorTree & textToString)
    Just (Right a) -> pure (Just a)
