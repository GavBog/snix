{-# LANGUAGE QuasiQuotes #-}

module Parse where

import Control.Category qualified
import Control.Selective (Selective)
import Data.Error.Tree
import Data.Functor.Compose
import Data.List qualified as List
import Data.Map.Strict qualified as Map
import Data.Monoid (First (..))
import Data.Semigroup.Traversable
import Data.Semigroupoid qualified as Semigroupoid
import Data.Text qualified as Text
import FieldParser (FieldParser)
import FieldParser qualified as Field
import PossehlAnalyticsPrelude
import Validation (partitionValidations)
import Prelude hiding (init, maybe)
import Prelude qualified

-- | A generic applicative “vertical” parser.
-- Similar to `FieldParser`, but made for parsing whole structures and collect all errors in an `ErrorTree`.
newtype Parse from to = Parse ((Context, from) -> Validation (NonEmpty ErrorTree) (Context, to))
  deriving
    (Functor, Applicative, Selective)
    via ( Compose
            ( Compose
                ((->) (Context, from))
                (Validation (NonEmpty ErrorTree))
            )
            ((,) Context)
        )

-- | Every parser can add to the context, like e.g. an element parser will add the name of the element it should be parsing.
-- This should be added to the error message of each parser, with `showContext`.
newtype Context = Context (Maybe [Text])
  deriving stock (Show)
  deriving (Semigroup, Monoid) via (First [Text])

instance Semigroupoid Parse where
  o p2 p1 = Parse $ \from -> case runParse' p1 from of
    Failure err -> Failure err
    Success to1 -> runParse' p2 to1

instance Category Parse where
  (.) = Semigroupoid.o
  id = Parse $ \t -> Success t

instance Profunctor Parse where
  lmap f (Parse p) = Parse $ lmap (second f) p
  rmap = (<$>)

runParse :: Error -> Parse from to -> from -> Either ErrorTree to
runParse errMsg parser t =
  (Context (Just ["$"]), t)
    & runParse' parser
    <&> snd
    & first (nestedMultiError errMsg)
    & validationToEither

runParse' :: Parse from to -> (Context, from) -> Validation (NonEmpty ErrorTree) (Context, to)
runParse' (Parse f) from = f from

showContext :: Context -> Text
showContext (Context context) = context & fromMaybe [] & List.reverse & Text.intercalate "."

addContext :: Text -> Context -> Context
addContext x (Context mxs) = Context (Just $ x : (mxs & fromMaybe []))

mkParsePushContext :: Text -> ((Context, from) -> Either ErrorTree to) -> Parse from to
mkParsePushContext toPush f = Parse $ \(ctx, from) -> case f (ctx, from) of
  Right to -> Success (addContext toPush ctx, to)
  Left err -> Failure $ singleton err

mkParseNoContext :: ((Context, from) -> Either ErrorTree to) -> Parse from to
mkParseNoContext f = Parse $ \(ctx, from) -> case f (ctx, from) of
  Right to -> Success (ctx, to)
  Left err -> Failure $ singleton err

-- | Accept only exactly the given value
exactly :: (Eq from) => (from -> Text) -> from -> Parse from from
exactly errDisplay from = Parse $ \(ctx, from') ->
  if from == from'
    then Success (ctx, from')
    else Failure $ singleton [fmt|Field has to be exactly {errDisplay from}, was: {errDisplay from'} at {showContext ctx}|]

-- | Make a parser to parse the whole list
multiple :: Parse a1 a2 -> Parse [a1] [a2]
multiple inner = dimap nonEmpty (Prelude.maybe [] toList) (maybe $ multipleNE inner)

-- | Make a parser to parse the whole non-empty list
multipleNE :: Parse from to -> Parse (NonEmpty from) (NonEmpty to)
multipleNE inner = Parse $ \(ctx, from) ->
  from
    & zipIndex
    & traverse (\(idx, f) -> runParse' inner (ctx, f) & first (singleton . nestedMultiError [fmt|{idx}|]))
    -- we assume that, since the same parser is used everywhere, the context will be the same as well (TODO: correct?)
    & second (\((ctx', y) :| ys) -> (ctx', y :| (snd <$> ys)))

-- | Like '(>>>)', but returns the intermediate result alongside the final parse result.
andParse :: Parse to to2 -> Parse from to -> Parse from (to, to2)
andParse outer inner = Parse $ \from -> case runParse' inner from of
  Failure err -> Failure err
  Success (ctx, to) -> runParse' outer (ctx, to) <&> (second (to,))

-- | Lift a parser into an optional value
maybe :: Parse from to -> Parse (Maybe from) (Maybe to)
maybe inner = Parse $ \(ctx, m) -> case m of
  Nothing -> Success (ctx, Nothing)
  Just a -> runParse' inner (ctx, a) & second (fmap Just)

-- | Assert that there is exactly one element in the list
exactlyOne :: Parse [from] from
exactlyOne = Parse $ \(ctx, xs) -> case xs of
  [] -> Failure $ singleton [fmt|Expected exactly 1 element, but got 0, at {ctx & showContext}|]
  [one] -> Success (ctx, one)
  _more -> Failure $ singleton [fmt|Expected exactly 1 element, but got 2, at {ctx & showContext}|]

-- | Assert that there is exactly zero or one element in the list
zeroOrOne :: Parse [from] (Maybe from)
zeroOrOne = Parse $ \(ctx, xs) -> case xs of
  [] -> Success (ctx, Nothing)
  [one] -> Success (ctx, Just one)
  _more -> Failure $ singleton [fmt|Expected exactly 1 element, but got 2, at {ctx & showContext}|]

-- | Find the first element on which the sub-parser succeeds; if there was no match, return all error messages.
find :: Parse from to -> Parse [from] to
find inner = Parse $ \(ctx, xs) -> case xs of
  [] -> failure [fmt|Wanted to get the first sub-parser that succeeds, but there were no elements in the list, at {ctx & showContext}|]
  (y : ys) -> runParse' (findNE' inner) (ctx, y :| ys)

-- | Find the first element on which the sub-parser succeeds; if there was no match, return all error messages.
findNE' :: Parse from to -> Parse (NonEmpty from) to
findNE' inner = Parse $ \(ctx, xs) ->
  xs
    <&> (\x -> runParse' inner (ctx, x))
    & traverse1
      ( \case
          Success a -> Left a
          Failure e -> Right e
      )
    & \case
      Left a -> Success a
      Right errs ->
        errs
          & zipIndex
          <&> (\(idx, errs') -> nestedMultiError [fmt|{idx}|] errs')
          & nestedMultiError [fmt|None of these sub-parsers succeeded|]
          & singleton
          & Failure

-- | Find all elements on which the sub-parser succeeds; if there was no match, return an empty list
findAll :: Parse from to -> Parse [from] [to]
findAll inner = Parse $ \(ctx, xs) ->
  xs
    <&> (\x -> runParse' inner (ctx, x))
    & partitionValidations
    & \case
      (_miss, []) ->
        -- in this case we just arbitrarily forward the original context …
        Success (ctx, [])
      (_miss, (hitCtx, hit) : hits) -> Success (hitCtx, hit : (hits <&> snd))

-- | Find the given element in the map, and parse it with the given parser.
mapLookup :: (Coercible Text key, Ord key) => key -> Parse from to -> Parse (Map key from) to
mapLookup key inner = do
  let keyT :: Text = coerce key
  Parse $ \(ctx, m) -> case Map.lookup (coerce key) m of
    Nothing -> Failure $ singleton [fmt|Key "{keyT}" not found in map at {showContext ctx}|]
    Just a -> runParse' inner (addContext keyT ctx, a)

-- | Find the given element in the map, and parse it with the given parser.
--
-- Use this instead of `rmap` to add the map key to the error context.
mapLookupMay :: (Coercible Text key, Ord key) => key -> Parse from to -> Parse (Map key from) (Maybe to)
mapLookupMay key inner = do
  let keyT :: Text = coerce key
  Parse $ \(ctx, m) -> case Map.lookup (coerce key) m of
    Nothing -> Success (addContext keyT ctx, Nothing)
    Just a -> runParse' (Just <$> inner) (addContext keyT ctx, a)

-- | convert a 'FieldParser' into a 'Parse'.
fieldParser :: FieldParser from to -> Parse from to
fieldParser fp = Parse $ \(ctx, from) -> case Field.runFieldParser fp from of
  Right a -> Success (ctx, a)
  Left err -> Failure $ singleton (singleError err)

zipNonEmpty :: NonEmpty a -> NonEmpty b -> NonEmpty (a, b)
zipNonEmpty (x :| xs) (y :| ys) = (x, y) :| zip xs ys

zipIndex :: NonEmpty b -> NonEmpty (Natural, b)
zipIndex = zipNonEmpty (1 :| [2 :: Natural ..])
