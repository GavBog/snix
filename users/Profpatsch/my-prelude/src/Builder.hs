module Builder
  ( TextBuilder (..),
    BytesBuilder (..),
    buildText,
    buildTextLazy,
    buildBytes,
    buildBytesLazy,
    textT,
    textLazyT,
    bytesB,
    bytesLazyB,
    utf8B,
    utf8LazyB,
    utf8LenientT,
    utf8LenientLazyT,
    intDecimalT,
    intDecimalB,
    integerDecimalT,
    integerDecimalB,
    naturalDecimalT,
    naturalDecimalB,
    scientificDecimalT,
    scientificDecimalB,
    intersperseT,
    intersperseB,
  )
where

import Data.ByteString.Builder qualified as Bytes
import Data.ByteString.Builder.Scientific qualified as Scientific.Bytes
import Data.ByteString.Lazy qualified as Bytes.Lazy
import Data.Functor.Contravariant
import Data.Functor.Contravariant.Divisible
import Data.String
import Data.Text.Lazy qualified as Text.Lazy
import Data.Text.Lazy.Builder qualified as Text
import Data.Text.Lazy.Builder.Int qualified as Text
import Data.Text.Lazy.Builder.Scientific qualified as Scientific.Text
import MyPrelude

newtype TextBuilder a = TextBuilder {unTextBuilder :: a -> Text.Builder}
  deriving newtype (Semigroup, Monoid)

instance IsString (TextBuilder a) where
  fromString s = TextBuilder $ \_ -> s & fromString

instance Contravariant TextBuilder where
  contramap f (TextBuilder g) = TextBuilder $ g . f

instance Divisible TextBuilder where
  divide f (TextBuilder bb) (TextBuilder bc) =
    TextBuilder $ \a -> let (b, c) = f a in bb b <> bc c
  conquer = TextBuilder $ \_ -> mempty

-- | Convert a 'TextBuilder' to a strict 'Text' by applying it to a value.
buildText :: TextBuilder a -> a -> Text
buildText (TextBuilder f) a = f a & Text.toLazyText & toStrict

-- | Convert a 'TextBuilder' to a lazy 'Text' by applying it to a value.
buildTextLazy :: TextBuilder a -> a -> Text.Lazy.Text
buildTextLazy (TextBuilder f) a = f a & Text.toLazyText

newtype BytesBuilder a = BytesBuilder {unBytesBuilder :: a -> Bytes.Builder}

instance IsString (BytesBuilder a) where
  fromString s = BytesBuilder $ \_ -> s & fromString

instance Contravariant BytesBuilder where
  contramap f (BytesBuilder g) = BytesBuilder $ g . f

instance Divisible BytesBuilder where
  divide f (BytesBuilder bb) (BytesBuilder bc) =
    BytesBuilder $ \a -> let (b, c) = f a in bb b <> bc c
  conquer = BytesBuilder $ \_ -> mempty

-- | Convert a 'BytesBuilder' to a strict 'ByteString' by applying it to a value.
buildBytes :: BytesBuilder a -> a -> ByteString
buildBytes (BytesBuilder b) a = b a & Bytes.toLazyByteString & toStrictBytes

-- | Convert a 'BytesBuilder' to a lazy 'ByteString' by applying it to a value.
buildBytesLazy :: BytesBuilder a -> a -> Bytes.Lazy.ByteString
buildBytesLazy (BytesBuilder b) a = b a & Bytes.toLazyByteString

textT :: TextBuilder Text
textT = TextBuilder Text.fromText

textLazyT :: TextBuilder Text.Lazy.Text
textLazyT = TextBuilder Text.fromLazyText

bytesB :: BytesBuilder ByteString
bytesB = BytesBuilder Bytes.byteString

bytesLazyB :: BytesBuilder Bytes.Lazy.ByteString
bytesLazyB = BytesBuilder Bytes.lazyByteString

utf8LenientT :: TextBuilder ByteString
utf8LenientT = bytesToTextUtf8Lenient >$< textT

utf8LenientLazyT :: TextBuilder Bytes.Lazy.ByteString
utf8LenientLazyT = bytesToTextUtf8LenientLazy >$< textLazyT

utf8B :: BytesBuilder Text
utf8B = textToBytesUtf8 >$< bytesB

utf8LazyB :: BytesBuilder Text.Lazy.Text
utf8LazyB = textToBytesUtf8Lazy >$< bytesLazyB

intDecimalT :: TextBuilder Int
intDecimalT = TextBuilder Text.decimal

intDecimalB :: BytesBuilder Int
intDecimalB = BytesBuilder Bytes.intDec

integerDecimalT :: TextBuilder Integer
integerDecimalT = TextBuilder Text.decimal

integerDecimalB :: BytesBuilder Integer
integerDecimalB = BytesBuilder Bytes.integerDec

naturalDecimalT :: TextBuilder Natural
naturalDecimalT = TextBuilder Text.decimal

naturalDecimalB :: BytesBuilder Natural
naturalDecimalB = toInteger >$< integerDecimalB

scientificDecimalT :: TextBuilder Scientific
scientificDecimalT = TextBuilder Scientific.Text.scientificBuilder

scientificDecimalB :: BytesBuilder Scientific
scientificDecimalB = BytesBuilder Scientific.Bytes.scientificBuilder

-- TODO: can these be abstracted over Divisible & Semigroup? Or something?

intersperseT :: (forall b. TextBuilder b) -> TextBuilder a -> TextBuilder [a]
intersperseT sep a = ((),) >$< intersperseT' sep a

intersperseT' :: TextBuilder b -> TextBuilder a -> TextBuilder (b, [a])
intersperseT' (TextBuilder sep) (TextBuilder a) = TextBuilder $ \(b, as) -> mintersperse (sep b) (fmap a as)

intersperseB :: (forall b. BytesBuilder b) -> BytesBuilder a -> BytesBuilder [a]
intersperseB sep a = ((),) >$< intersperseB' sep a

intersperseB' :: BytesBuilder b -> BytesBuilder a -> BytesBuilder (b, [a])
intersperseB' (BytesBuilder sep) (BytesBuilder a) = BytesBuilder $ \(b, as) -> mintersperse (sep b) (fmap a as)
