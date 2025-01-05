{-# LANGUAGE AllowAmbiguousTypes #-}

module Divisive where

import Data.Functor.Contravariant
import Data.Functor.Contravariant.Divisible
import GHC.Records (HasField (getField))
import Label

-- | Combine two divisibles into a struct with any two labelled fields.
divide2 ::
  forall l1 l2 t1 t2 d r.
  (Divisible d, HasField l1 r t1, HasField l2 r t2) =>
  d t1 ->
  d t2 ->
  d r
divide2 = divide (\r -> (getField @l1 r, getField @l2 r))

-- | Combine two divisibles into a 'T2' with any two labelled fields.
dt2 ::
  forall l1 l2 t1 t2 d.
  (Divisible d) =>
  d t1 ->
  d t2 ->
  d (T2 l1 t1 l2 t2)
dt2 = divide (\(T2 a b) -> (getField @l1 a, getField @l2 b))

-- | Combine three divisibles into a struct with any three labelled fields.
divide3 :: forall l1 l2 l3 t1 t2 t3 d r. (Divisible d, HasField l1 r t1, HasField l2 r t2, HasField l3 r t3) => d t1 -> d t2 -> d t3 -> d r
divide3 a b c = adapt >$< a `divided` b `divided` c
  where
    adapt r = ((getField @l1 r, getField @l2 r), getField @l3 r)

-- | Combine three divisibles into a 'T3' with any three labelled fields.
dt3 ::
  forall l1 l2 l3 t1 t2 t3 d.
  (Divisible d) =>
  d t1 ->
  d t2 ->
  d t3 ->
  d (T3 l1 t1 l2 t2 l3 t3)
dt3 a b c = adapt >$< a `divided` b `divided` c
  where
    adapt (T3 a' b' c') = ((getField @l1 a', getField @l2 b'), getField @l3 c')
