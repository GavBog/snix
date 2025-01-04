-- | Helper module for working better with 'Comparison' contravariants.
module Comparison
  ( module Data.Functor.Contravariant,
    Comparison (..),
    defaultComparison1,
    down,
    down1,
    maybeDown,
    groupAllWithComparison,
    listIndexComparison,
  )
where

import Data.Functor.Classes
import Data.Functor.Contravariant
import Data.List qualified as List
import Data.List.NonEmpty
import Data.List.NonEmpty qualified as NonEmpty

-- | Unlift an Ord1 to a `Comparison` function. Analogous to `defaultComparison`.
defaultComparison1 :: (Ord1 f) => Comparison a -> Comparison (f a)
defaultComparison1 = Comparison . liftCompare . getComparison

-- | Invert the ordering of the comparison
down :: Comparison a -> Comparison a
down c = Comparison $ \a b -> case getComparison c a b of
  LT -> GT
  EQ -> EQ
  GT -> LT

-- | Invert the ordering of the outer comparison function but not the inner one
--
-- Can be used to e.g. change the ordering of `Maybe` values, but not the ordering of the inner values.
-- Example:
--
-- > maybeDown = down1 (defaultComparison1 @Maybe)
-- > maybeDown (Just 1) (Just 2) == LT
-- > maybeDown (Just 1) Nothing == LT
-- > maybeDown Nothing (Just 2) == GT
down1 :: (Comparison a -> Comparison b) -> Comparison a -> Comparison b
down1 inner = down . inner . down

-- | Sort every Nothing behind every Just
maybeDown :: Comparison a -> Comparison (Maybe a)
maybeDown = down1 (defaultComparison1 @Maybe)

-- | Group all items in the list that are equal according to the comparison function. Sort the list first so every equivalence class has at most one list in the output.
groupAllWithComparison :: Comparison a -> [a] -> [NonEmpty a]
groupAllWithComparison c xs =
  NonEmpty.groupBy
    (getEquivalence $ comparisonEquivalence c)
    $ List.sortBy (getComparison c) xs

-- | Everything in the list is ordered in the order of equality in the list.
--
-- Any item is not in the list is automatically GT to every item in the list,
-- and EQ to every item not in the list.
listIndexComparison :: (Eq a) => [a] -> Comparison a
listIndexComparison xs =
  (\x -> List.elemIndex x xs)
    >$< maybeDown (defaultComparison @Int)
