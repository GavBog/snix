module RevList where

import Data.Semigroup qualified as Semigroup
import PossehlAnalyticsPrelude

-- | A reversed list; `:` adds to the end of the list, and '(<>)' is reversed (i.e. @longList <> [oneElement]@ will be O(1) instead of O(n))
--
-- Invariant: the inner list is already reversed.
newtype RevList a = RevList [a]
  deriving stock (Eq)
  deriving (Semigroup, Monoid) via (Semigroup.Dual [a])

empty :: RevList a
empty = RevList []

singleton :: a -> RevList a
singleton a = RevList [a]

-- | (@O(n)@) Turn the list into a reversed list (by reversing)
revList :: [a] -> RevList a
revList xs = RevList $ reverse xs

-- | (@O(n)@) Turn the reversed list into a list (by reversing)
revListToList :: RevList a -> [a]
revListToList (RevList rev) = reverse rev

instance (Show a) => Show (RevList a) where
  show (RevList rev) = rev & show
